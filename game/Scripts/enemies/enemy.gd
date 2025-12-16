extends CharacterBody2D

signal died

@export var move_speed: float = 45.0
@export var attack_move_multiplier: float = 0.35
@export var gravity: float = 1200.0
@export var max_health: int = 100
@export var player: CharacterBody2D
@export var damage_number_scene: PackedScene
@export var contact_damage: int = 10
@export var contact_cooldown: float = 0.5
@export var flash_duration: float = 0.09
@export var flash_intensity: float = 1.0  # 0.0–1.0, how white the flash is
@export var damage_bar_lag_duration: float = 0.2
@export var silver_coin_scene: PackedScene
@export var gold_coin_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var silver_drop_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var gold_drop_chance: float = 0.25
@export var xp_reward: int = 10
@export var face_deadzone_px: float = 8.0  # Distance threshold before flipping sprite
@export var separation_strength: float = 120.0
@export var separation_max_push: float = 70.0
@export var separation_max_neighbors: int = 6
@export var separation_min_dist_px: float = 1.0

enum State {
	CHASE,
	ATTACK,
	DEAD,
}

const COIN_SPAWN_OFFSET := Vector2(0, -15)

var state: State = State.CHASE
var facing_left: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var damage_bar: TextureProgressBar = $HealthBar/DamageBar
@onready var damage_area: Area2D = $DamageArea
@onready var separation_area: Area2D = $SeparationArea

var is_flashing: bool = false
var flash_material: ShaderMaterial

var current_health: int
var contact_timer: float = 0.0
var damage_bar_tween: Tween

func _ready() -> void:
	current_health = max_health
	add_to_group("enemy") # so bullets can recognise this as an enemy
	_update_health_bar()
	
	# Assign per-instance flash shader material to this enemy sprite
	var flash_shader := preload("res://shaders/enemy_flash.gdshader")
	flash_material = ShaderMaterial.new()
	flash_material.shader = flash_shader
	sprite.material = flash_material
	
	state = State.CHASE
	
	# Connect DamageArea safely
	if damage_area != null:
		var da: Area2D = damage_area
		if not da.body_entered.is_connected(_on_damage_area_body_entered):
			da.body_entered.connect(_on_damage_area_body_entered)
			if OS.is_debug_build():
				print("DamageArea connected for ", name)
		if not da.body_exited.is_connected(_on_damage_area_body_exited):
			da.body_exited.connect(_on_damage_area_body_exited)

func _physics_process(delta: float) -> void:
	# If the enemy is dead, don't apply gravity or movement anymore
	if state == State.DEAD:
		return
	
	# Update contact timer
	contact_timer = max(contact_timer - delta, 0.0)
	
	# Handle repeated contact damage while in ATTACK state
	if state == State.ATTACK and contact_timer <= 0.0 and player != null:
		if player.is_in_group("player") and player.has_method("take_damage"):
			player.take_damage(contact_damage)
			contact_timer = contact_cooldown
			# If player died from this damage, return early to avoid move_and_slide() on destroyed physics space
			if "current_health" in player and player.current_health <= 0:
				return
	
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	var dir_x: float = 0.0

	if player != null:
		dir_x = sign(player.global_position.x - global_position.x)

	match state:
		State.CHASE:
			velocity.x = dir_x * move_speed
			# Apply separation force to flow around other enemies
			_apply_separation(delta)
		State.ATTACK:
			# Keep pressing toward the player slightly while attacking
			if player != null:
				velocity.x = dir_x * move_speed * attack_move_multiplier
			else:
				velocity.x = 0.0

	# Update facing with deadzone to prevent jitter
	if player != null:
		var distance_x: float = abs(player.global_position.x - global_position.x)
		if distance_x > face_deadzone_px:
			var should_face_left: bool = player.global_position.x < global_position.x
			if facing_left != should_face_left:
				facing_left = should_face_left
				sprite.flip_h = facing_left

	move_and_slide()

func _apply_separation(delta: float) -> void:
	# Only apply separation during CHASE state
	if state != State.CHASE:
		return
	
	# Get separation area
	if separation_area == null:
		return
	
	# Get overlapping bodies
	var overlapping_bodies := separation_area.get_overlapping_bodies()
	if overlapping_bodies.is_empty():
		return
	
	var separation_push: float = 0.0
	var neighbor_count: int = 0
	
	# Process up to separation_max_neighbors enemies
	for overlapping_body: Node2D in overlapping_bodies:
		if neighbor_count >= separation_max_neighbors:
			break
		
		# Only process enemies (ignore player, world, etc.)
		if not overlapping_body.is_in_group("enemy"):
			continue
		
		# Skip self
		if overlapping_body == self:
			continue
		
		# Compute horizontal distance
		var dx: float = global_position.x - overlapping_body.global_position.x
		var abs_dx: float = abs(dx)
		
		# Skip if too close (prevents division by zero and jitter)
		if abs_dx < separation_min_dist_px:
			continue
		
		# Push direction: away from neighbor
		var push_dir: float = sign(dx)
		
		# Weight by closeness (closer = stronger push)
		# Inverse distance weighting: stronger when closer
		var weight: float = separation_strength / abs_dx
		separation_push += push_dir * weight
		
		neighbor_count += 1
	
	# Convert to velocity adjustment and clamp
	if neighbor_count > 0:
		# Average the push across neighbors
		separation_push /= float(neighbor_count)
		# Clamp to max push
		separation_push = clamp(separation_push, -separation_max_push, separation_max_push)
		# Apply to velocity (X only, no vertical movement)
		velocity.x += separation_push

func set_player(p: Node2D) -> void:
	player = p

func take_damage(amount: int, is_crit: bool = false) -> void:
	if state == State.DEAD:
		return
	
	current_health -= amount
	flash_hit()
	_update_health_bar()
	
	var is_killing_blow: bool = current_health <= 0
	
	var move_dir_sign: float = 0.0
	if player != null:
		move_dir_sign = sign(player.global_position.x - global_position.x)
	
	# Spawn damage number if scene is set
	if damage_number_scene != null:
		var dmg = damage_number_scene.instantiate()
		dmg.global_position = global_position + Vector2(2, -19)
		if "damage" in dmg:
			dmg.damage = amount
		if "is_crit" in dmg:
			dmg.is_crit = is_crit
		if "is_killing_blow" in dmg:
			dmg.is_killing_blow = is_killing_blow
		if "movement_dir_sign" in dmg:
			dmg.movement_dir_sign = move_dir_sign
		get_tree().current_scene.add_child(dmg)

	if current_health <= 0:
		die()

func flash_hit() -> void:
	if is_flashing:
		return
	
	is_flashing = true
	
	if flash_material == null:
		is_flashing = false
		return
	
	# Turn flash ON (full white)
	flash_material.set_shader_parameter("flash_amount", clamp(flash_intensity, 0.0, 1.0))
	
	# Keep it white briefly (flash_duration)
	await get_tree().create_timer(flash_duration).timeout
	
	# Turn flash OFF (back to original)
	if state != State.DEAD:
		flash_material.set_shader_parameter("flash_amount", 0.0)
	
	is_flashing = false

func _update_health_bar() -> void:
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if damage_bar != null:
		damage_bar.max_value = max_health
		
		# If healed or starting up, snap up immediately
		if damage_bar.value < current_health:
			damage_bar.value = current_health
		# If taking damage, animate down
		elif damage_bar.value > current_health:
			if damage_bar_tween != null:
				damage_bar_tween.kill()
			damage_bar_tween = create_tween()
			damage_bar_tween.tween_property(
				damage_bar,
				"value",
				current_health,
				damage_bar_lag_duration
			)

func _on_damage_area_body_entered(body: Node) -> void:
	if state == State.DEAD:
		return
	
	if OS.is_debug_build():
		print("DamageArea entered by: ", body, " name=", body.name, " groups=", body.get_groups())
	
	var target := body
	
	# if the collider isn't in the player group but their parent is, use parent
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player") and target.has_method("take_damage"):
		if OS.is_debug_build():
			print("Player entered DamageArea: ", target.name)
		player = target
		state = State.ATTACK

func _on_damage_area_body_exited(body: Node) -> void:
	if state == State.DEAD:
		return
	
	var target := body
	
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player"):
		# Check if player is truly no longer overlapping before switching to CHASE
		if damage_area != null:
			var overlapping_bodies := damage_area.get_overlapping_bodies()
			var player_still_overlapping: bool = false
			
			for overlapping_body: Node2D in overlapping_bodies:
				var check_target: Node = overlapping_body
				# Handle parent/child node relationships
				if not check_target.is_in_group("player") and check_target.get_parent() and check_target.get_parent().is_in_group("player"):
					check_target = check_target.get_parent()
				
				if check_target.is_in_group("player"):
					player_still_overlapping = true
					break
			
			# Only switch to CHASE if player is truly no longer overlapping
			if not player_still_overlapping:
				state = State.CHASE

func _drop_loot() -> void:
	if silver_coin_scene != null and randf() < silver_drop_chance:
		var c = silver_coin_scene.instantiate()
		c.global_position = global_position + COIN_SPAWN_OFFSET + Vector2(randf_range(-3.0, 3.0), 0.0)
		get_tree().current_scene.add_child(c)

	if gold_coin_scene != null and randf() < gold_drop_chance:
		var c = gold_coin_scene.instantiate()
		c.global_position = global_position + COIN_SPAWN_OFFSET + Vector2(randf_range(-3.0, 3.0), 0.0)
		get_tree().current_scene.add_child(c)

func die() -> void:
	# Prevent death logic from running multiple times
	if state == State.DEAD:
		return

	state = State.DEAD
	_drop_loot()

	# Award XP for killing this enemy
	if xp_reward > 0 and GameManager != null and GameManager.has_method("add_xp"):
		GameManager.add_xp(xp_reward)

	# Notify listeners (WaveManager, future systems) that this enemy died
	emit_signal("died")

	queue_free()
