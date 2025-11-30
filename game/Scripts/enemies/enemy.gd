extends CharacterBody2D

@export var move_speed: float = 45.0
@export var gravity: float = 1200.0
@export var max_health: int = 100
@export var player: CharacterBody2D
@export var damage_number_scene: PackedScene
@export var contact_damage: int = 10
@export var contact_cooldown: float = 0.5
@export var flash_duration: float = 0.09
@export var flash_intensity: float = 1.0  # 0.0–1.0, how white the flash is
@export var damage_bar_lag_duration: float = 0.2

enum State {
	CHASE,
	ATTACK,
	DEAD,
}

var state: State = State.CHASE

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var damage_bar: TextureProgressBar = $HealthBar/DamageBar

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
	if has_node("DamageArea"):
		var da: Area2D = $DamageArea
		if not da.body_entered.is_connected(_on_damage_area_body_entered):
			da.body_entered.connect(_on_damage_area_body_entered)
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
		State.ATTACK:
			# While attacking / in contact range, don't try to push through the player
			velocity.x = 0.0
		State.DEAD:
			velocity.x = 0.0

	# Flip sprite based on intended direction of movement (still want to face the player)
	if dir_x != 0.0:
		sprite.flip_h = dir_x < 0.0

	move_and_slide()

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
		dmg.global_position = global_position + Vector2(15, -10)
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
	
	# Keep it white for ~0.5 seconds
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
	
	print("DamageArea entered by: ", body, " name=", body.name, " groups=", body.get_groups())
	
	var target := body
	
	# if the collider isn't in the player group but their parent is, use parent
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player") and target.has_method("take_damage"):
		print("Player entered DamageArea: ", target.name)
		state = State.ATTACK

func _on_damage_area_body_exited(body: Node) -> void:
	if state == State.DEAD:
		return
	
	var target := body
	
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player"):
		# Player is no longer in contact range; go back to chasing
		state = State.CHASE

func die() -> void:
	# Prevent death logic from running multiple times
	if state == State.DEAD:
		return
	
	state = State.DEAD
	
	# Temporary placeholder: just remove the enemy
	queue_free()
