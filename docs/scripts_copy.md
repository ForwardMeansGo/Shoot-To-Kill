# Scripts Copy — Shoot To Kill

This document contains copies of all scripts in the project, organized by script name and function.

---

## Player Scripts

### `player.gd`
**Location:** `game/Scripts/player.gd`  
**Extends:** `CharacterBody2D`  
**Function:** Main player controller handling movement, health, shooting, animation, aiming, weapon bob, and visual kickback.

```gdscript
extends CharacterBody2D

@onready var weapon_holder: Node2D = $WeaponHolder
@onready var weapon_bob_offset: Node2D = $WeaponHolder/WeaponBobOffset
@onready var gun: Node2D = $WeaponHolder/WeaponBobOffset/Gun
@onready var arm_sprite: Sprite2D = $WeaponHolder/WeaponBobOffset/ArmSprite
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cam: Camera2D = $Camera2D
@onready var crosshair = $"../Crosshair"

const SPEED: float = 75.0
const JUMP_FORCE: float = -275
const GRAVITY: float = 1200.0

@export var max_health: int = 100
@export var invulnerability_time: float = 0.5
@export var starting_gold: float = 0.0

signal health_changed(current_health: int, max_health: int)
signal died
signal gold_changed(current_gold: float)

var weapon_base_offset: Vector2
var current_health: int
var invuln_timer: float = 0.0
var default_aim_dot_lerp_speed: float = 10.0
var facing_dir: int = 1  # +1 = facing right, -1 = facing left
var was_on_floor: bool = true
var is_landing: bool = false
var gold: float = 0.0

# Per-frame weapon bob offsets for different animations (tweak these values in code as needed)
var weapon_bob_idle := [0.0, 1.0, 1.0, 0.0]
var weapon_bob_run := [0.0, 0.0, -2.0, 0.0, 0.0, -1.0]
var weapon_bob_run_backwards := [-1.0, 0.0, 0.0, -2.0, 0.0, 0.0]
var weapon_bob_jump := [0.0, -1.0, -2.0, -1.0]  # basic jump bob, optional

# Visual weapon kickback (purely cosmetic)
var kick_offset: Vector2 = Vector2.ZERO
@export var kick_strength: float = 4.0
@export var kick_return_speed: float = 20.0

func _ready() -> void:
	weapon_base_offset = weapon_holder.position

	# Add player to group for coin pickup detection
	add_to_group("player")

	# Hide system mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Connect weapon fired signal -> camera shake and crosshair pulse
	if gun != null and gun.has_signal("fired"):
		gun.connect("fired", Callable(self, "_on_weapon_fired"))

		if crosshair != null and crosshair.has_method("on_weapon_fired"):
			gun.connect("fired", Callable(crosshair, "on_weapon_fired"))

	# Initialize health
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

	# Initialize gold
	gold = starting_gold
	emit_signal("gold_changed", gold)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	# Horizontal input
	var input_dir := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	velocity.x = input_dir * SPEED

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE

	move_and_slide()
	
	_update_animation()

func _process(delta: float) -> void:
	# Update invulnerability timer
	if invuln_timer > 0.0:
		invuln_timer -= delta
		if invuln_timer < 0.0:
			invuln_timer = 0.0
	
	if gun != null:
		var mouse_pos: Vector2 = get_global_mouse_position()

		# Make the crosshair follow the mouse
		if crosshair != null:
			crosshair.global_position = mouse_pos

		# Facing based on player center vs mouse X (GLOBAL)
		var facing_left := mouse_pos.x < global_position.x
		facing_dir = -1 if facing_left else 1  # store for animation logic

		if facing_left:
			# Flip body
			anim_sprite.scale.x = -1.0
			# Per-side tweak for arm+gun pivot (8 right, 0 up)
			weapon_holder.position = weapon_base_offset + Vector2(8,0)
		else:
			anim_sprite.scale.x = 1.0
			weapon_holder.position = weapon_base_offset

		# Get weighted dot world position
		var aim_point: Vector2
		if crosshair != null and crosshair.has_method("get_dot_world_position"):
			aim_point = crosshair.get_dot_world_position()
		else:
			aim_point = mouse_pos  # Fallback to mouse if crosshair unavailable

		# Gun rotation
		gun.aim_at(aim_point)

		if arm_sprite:
			# Arm rotation based on aim point
			var origin: Vector2 = arm_sprite.global_position
			var to_aim: Vector2 = aim_point - origin
			if to_aim.length() > 0.001:
				var aim_dir: Vector2 = to_aim.normalized()
				var target_angle: float = aim_dir.angle()
				arm_sprite.global_rotation = target_angle
			
			if self.has_method("_update_arm_visual_flip"):
				_update_arm_visual_flip()
			
			# Gun hand offset (KEEP YOUR EXISTING LEFT/RIGHT TUNED VALUES)
			if gun:
				var hand_offset: Vector2
				
				if facing_left:
					hand_offset = Vector2(8, 2)   # your tuned left values
				else:
					hand_offset = Vector2(8, -2)    # your tuned right values
				
				gun.global_position = arm_sprite.global_position + hand_offset.rotated(arm_sprite.global_rotation)

		# Tell the weapon which way we're facing so it can flip its sprite
		if gun.has_method("set_facing_left"):
			gun.set_facing_left(facing_left)

		# Gun firing should use the SAME aim_point
		if Input.is_action_just_pressed("shoot"):
			if gun.has_method("try_shoot"):
				gun.try_shoot(aim_point)

				# VISUAL KICKBACK: push the weapon back along the shot direction
				var shot_dir: Vector2 = (aim_point - get_aim_origin_global()).normalized()
				if shot_dir.length() > 0.0:
					kick_offset = shot_dir * -kick_strength
	
	# Update visual weapon kickback, then bob
	_update_kickback(delta)
	_update_weapon_bob()

func _update_animation() -> void:
	var on_floor_now: bool = is_on_floor()
	var is_moving: bool = abs(velocity.x) > 1.0
	var move_dir: int = sign(velocity.x)  # -1, 0, or 1

	# 1) Detect landing transition: was in air, now on floor
	if on_floor_now and not was_on_floor and not is_landing:
		is_landing = true
		anim_sprite.play("land")
		was_on_floor = on_floor_now
		return

	# 2) If we're currently playing the landing animation, let it finish
	if is_landing:
		if anim_sprite.animation == "land" and not anim_sprite.is_playing():
			# Landing animation finished, go back to normal logic next frame
			is_landing = false
		else:
			was_on_floor = on_floor_now
			return

	# 3) Normal ground movement
	if on_floor_now and is_moving:
		# Moving opposite to where we're facing = backwards
		var is_backwards := move_dir != 0 and move_dir != facing_dir

		var desired_anim := "run_backwards" if is_backwards else "run"
		if anim_sprite.animation != desired_anim:
			anim_sprite.play(desired_anim)

	# 4) In air: choose jump vs fall based on vertical velocity
	elif not on_floor_now:
		var desired_anim := "jump" if velocity.y < 0.0 else "fall"
		if anim_sprite.animation != desired_anim:
			anim_sprite.play(desired_anim)

	# 5) Idle on ground
	else:
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")

	# 6) Update floor state for next frame
	was_on_floor = on_floor_now

func _get_weapon_bob_for_current_frame() -> float:
	if weapon_bob_offset == null or anim_sprite == null:
		return 0.0

	var frame_index: int = anim_sprite.frame
	var anim_name: String = anim_sprite.animation

	var offsets: Array = []

	match anim_name:
		"idle":
			offsets = weapon_bob_idle
		"run":
			offsets = weapon_bob_run
		"run_backwards":
			offsets = weapon_bob_run_backwards
		"jump", "fall":
			offsets = weapon_bob_jump
		_:
			return 0.0

	if frame_index >= 0 and frame_index < offsets.size():
		return float(offsets[frame_index])

	return 0.0

func _update_weapon_bob() -> void:
	if weapon_bob_offset == null:
		return

	var bob_y: float = _get_weapon_bob_for_current_frame()
	# Base bob position (local to WeaponHolder)
	var base_pos: Vector2 = Vector2(0.0, bob_y)
	# Add visual kickback offset on top
	weapon_bob_offset.position = base_pos + kick_offset

func _update_kickback(delta: float) -> void:
	# Smoothly return kick_offset back to zero
	kick_offset = kick_offset.lerp(Vector2.ZERO, kick_return_speed * delta)

func _update_arm_visual_flip() -> void:
	if arm_sprite == null:
		return

	var angle := wrapf(arm_sprite.global_rotation, -PI, PI)
	if angle > PI / 2.0 or angle < -PI / 2.0:
		arm_sprite.scale.y = -1.0
	else:
		arm_sprite.scale.y = 1.0
		
func get_aim_origin_global() -> Vector2:
	if arm_sprite != null:
		return arm_sprite.global_position
	elif gun != null:
		return gun.global_position
	return global_position

func get_current_dot_lerp_speed() -> float:
	if gun != null and gun.has_method("get_aim_dot_lerp_speed"):
		return gun.get_aim_dot_lerp_speed()
	return default_aim_dot_lerp_speed

func _on_weapon_fired(strength: float, duration: float) -> void:
	if cam != null:
		cam.start_shake(strength, duration)

func take_damage(amount: int) -> void:
	if invuln_timer > 0.0:
		return
	
	current_health = max(current_health - amount, 0)
	invuln_timer = invulnerability_time
	
	emit_signal("health_changed", current_health, max_health)
	print("Player took damage: ", amount, " -> HP: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	emit_signal("died")
	print("Player died, reloading scene...")
	get_tree().reload_current_scene()

func add_gold(amount: float) -> void:
	gold += amount
	emit_signal("gold_changed", gold)
	print("Player picked up gold: ", amount, " -> total gold: ", gold)
```

---

## Enemy Scripts

### `enemy.gd`
**Location:** `game/Scripts/enemies/enemy.gd`  
**Extends:** `CharacterBody2D`  
**Function:** Enemy AI controller with state machine, health, contact damage, flash effects, and health bars.

```gdscript
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
@export var silver_coin_scene: PackedScene
@export var gold_coin_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var silver_drop_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var gold_drop_chance: float = 0.25

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

func _drop_loot() -> void:
	if silver_coin_scene != null and randf() < silver_drop_chance:
		var c = silver_coin_scene.instantiate()
		c.global_position = global_position
		get_tree().current_scene.add_child(c)

	if gold_coin_scene != null and randf() < gold_drop_chance:
		var c = gold_coin_scene.instantiate()
		c.global_position = global_position
		get_tree().current_scene.add_child(c)

func die() -> void:
	# Prevent death logic from running multiple times
	if state == State.DEAD:
		return
	
	state = State.DEAD
	_drop_loot()
	queue_free()
```

---

## Weapon Scripts

### `weapon_base.gd`
**Location:** `game/Scripts/weapons/weapon_base.gd`  
**Extends:** `Node2D`  
**Class Name:** `WeaponBase`  
**Function:** Base class for all weapons, handling damage rolling, crit system, bullet spawning, audio, and aim dot smoothing.

```gdscript
extends Node2D

class_name WeaponBase

signal fired(shake_strength: float, shake_duration: float)

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

# Per-weapon camera shake tuning (override in inspector per weapon)
@export var shake_strength: float = 1.0
@export var shake_duration: float = 0.06

# Weapon damage and crit stats
@export var base_damage_min: float = 8.0
@export var base_damage_max: float = 12.0
@export var crit_chance: float = 0.1  # 10% crit as a default
@export var crit_multiplier: float = 2.0  # 2x damage on crit by default

# Per-weapon aim dot smoothing (gunAimDelay)
@export var aim_dot_lerp_speed: float = 10.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $GunAudio

var facing_left: bool = false

func _process(delta: float) -> void:
	# Placeholder for recoil/sway later
	pass

func set_facing_left(is_left: bool) -> void:
	facing_left = is_left
	# Grip always points "down" when on the left side
	sprite.flip_v = is_left

func aim_at(target_global_pos: Vector2) -> void:
	# Rotate the weapon so its +X axis points towards the mouse
	look_at(target_global_pos)

func spawn_bullet(target_global_pos: Vector2) -> void:
	# Roll damage and crit
	var dmg_info := _roll_damage()
	var dmg_value: int = dmg_info["damage"]
	var is_crit: bool = dmg_info["is_crit"]
	
	var muzzle_global: Vector2 = $Muzzle.global_position
	var dir: Vector2 = (target_global_pos - muzzle_global).normalized()

	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle_global
	bullet.direction = dir
	bullet.rotation = dir.angle()
	
	# Set damage and crit info on bullet
	if "damage" in bullet:
		bullet.damage = dmg_value
	if "is_crit" in bullet:
		bullet.is_crit = is_crit

	get_tree().current_scene.add_child(bullet)

	_play_shot_sound(muzzle_global)

	emit_signal("fired", shake_strength, shake_duration)

func _roll_damage() -> Dictionary:
	var base := randf_range(base_damage_min, base_damage_max)
	var crit := randf() < crit_chance
	if crit:
		base *= crit_multiplier
	return {
		"damage": roundi(base),
		"is_crit": crit
	}

func get_aim_dot_lerp_speed() -> float:
	return aim_dot_lerp_speed

func _play_shot_sound(at_position: Vector2) -> void:
	# If there's no template audio player or stream, bail out
	if audio_player == null or audio_player.stream == null:
		return

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = audio_player.stream
	sfx.global_position = at_position

	# Slight random pitch variation for feel
	var new_pitch: float = randf_range(0.95, 1.05)
	sfx.pitch_scale = new_pitch

	get_tree().current_scene.add_child(sfx)
	sfx.play()

	# Free the one-shot player when the sound is done
	sfx.connect("finished", Callable(sfx, "queue_free"))
```

### `weapon_pistol.gd`
**Location:** `game/Scripts/weapons/weapon_pistol.gd`  
**Extends:** `WeaponBase`  
**Function:** Pistol weapon implementation with semi-auto firing.

```gdscript
extends WeaponBase

func try_shoot(target_global_pos: Vector2) -> bool:
	# Semi-auto pistol, no internal cooldown
	spawn_bullet(target_global_pos)
	return true
```

### `bullet.gd`
**Location:** `game/Scripts/weapons/bullet.gd`  
**Extends:** `Area2D`  
**Function:** Bullet physics with continuous collision detection, damage handling, and hit effects.

```gdscript
extends Area2D

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5
@export var damage: int = 10
@export var hit_effect_scene: PackedScene

var previous_position: Vector2
var is_crit: bool = false

func _ready() -> void:
	previous_position = global_position

func _physics_process(delta: float) -> void:
	# Handle lifetime first
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	if direction == Vector2.ZERO:
		previous_position = global_position
		return

	rotation = direction.angle()

	# Get current position and compute target position
	var current_pos: Vector2 = global_position
	var target_pos: Vector2 = current_pos + direction * speed * delta

	# Add a small extra margin in the same direction to be safe
	var ray_to: Vector2 = target_pos + direction * 2.0

	# Create raycast query from previous_position to ray_to
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(previous_position, ray_to)
	query.collision_mask = collision_mask
	query.exclude = [self]
	query.hit_from_inside = true

	var result: Dictionary = space_state.intersect_ray(query)

	# If we hit something this frame
	if result.size() > 0:
		var hit_pos: Vector2 = result["position"]
		var collider: Object = result["collider"]

		global_position = hit_pos
		_handle_hit(collider)
		queue_free()
		return

	# No hit – move normally to target position
	global_position = target_pos
	
	# Update previous_position for next frame
	previous_position = global_position

func _handle_hit(body: Object) -> void:
	if body is Node:
		var node: Node = body as Node

		# Ignore player, just in case
		if node.is_in_group("player"):
			return

		# Damage enemies
		if node.is_in_group("enemy") and node.has_method("take_damage"):
			node.take_damage(damage, is_crit)
			
			# Spawn hit impact effect if assigned
			if hit_effect_scene != null:
				var hit_effect = hit_effect_scene.instantiate()
				hit_effect.global_position = global_position
				get_tree().current_scene.add_child(hit_effect)
```

---

## UI Scripts

### `hud.gd`
**Location:** `game/Scripts/hud.gd`  
**Extends:** `CanvasLayer`  
**Function:** HUD manager for player health bar with smooth tweening.

```gdscript
extends CanvasLayer

@onready var health_bar: TextureProgressBar = $PlayerHealthBar
@export var player_path: NodePath = ^"../Player"

var player: Node = null
var hp_tween: Tween = null

func _ready() -> void:
	# Find the player
	if player_path != NodePath():
		if has_node(player_path):
			player = get_node(player_path)
		else:
			push_error("HUD: player_path is set but node not found: " + str(player_path))
			return
	else:
		if get_parent().has_node("Player"):
			player = get_parent().get_node("Player")
		else:
			push_error("HUD: Could not find Player as sibling of HUD")
			return
	
	if player == null:
		push_error("HUD: Player is null")
		return
	
	# Connect to health_changed signal if it exists
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	else:
		push_warning("HUD: Player has no 'health_changed' signal")
	
	# Initialize bar from current player health (if fields exist)
	var max_h := 100
	var cur_h := 100
	
	if "max_health" in player:
		max_h = player.max_health
	if "current_health" in player:
		cur_h = player.current_health

	if health_bar:
		health_bar.visible = true
		health_bar.max_value = max_h
		health_bar.value = cur_h
		health_bar.step = 1.0
		print("HUD: Initialized health bar -> ", cur_h, "/", max_h)
	else:
		push_error("HUD: health_bar (PlayerHealthBar) not found under HUD")

func _on_player_health_changed(current: int, max: int) -> void:
	if health_bar == null:
		return

	health_bar.max_value = max

	# Kill any existing tween so they don't fight
	if hp_tween and hp_tween.is_valid():
		hp_tween.kill()

	# Create a new tween to animate from current bar value to the new HP
	hp_tween = create_tween()
	hp_tween.tween_property(health_bar, "value", current, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

### `crosshair.gd`
**Location:** `game/Scripts/crosshair.gd`  
**Extends:** `Node2D`  
**Function:** Crosshair system with outer crosshair (follows mouse) and weighted aim dot (smoothly lags behind).

```gdscript
extends Node2D

@export var player_path: NodePath
var default_dot_lerp_speed: float = 10.0

@onready var outer_sprite: Sprite2D = $Outer
@onready var dot_sprite: Sprite2D = $Dot

@export var outer_pulse_scale: float = 1.25
@export var outer_pulse_duration: float = 0.08

var player: Node = null
var dot_screen_pos: Vector2 = Vector2.ZERO
var outer_base_scale: Vector2 = Vector2.ONE
var outer_pulse_tween: Tween

func _ready() -> void:
	if player_path != NodePath(""):
		player = get_node(player_path)
	
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	dot_screen_pos = mouse_screen

	# Store the base scale of the outer crosshair so we can pulse around it
	if outer_sprite != null:
		outer_base_scale = outer_sprite.scale

func _process(delta: float) -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()

	# Outer crosshair follows the mouse INSTANTLY (world space)
	if outer_sprite != null:
		outer_sprite.global_position = mouse_world

	# --- Screen-space smoothing for the weighted dot ---
	var speed: float = default_dot_lerp_speed
	if player != null and player.has_method("get_current_dot_lerp_speed"):
		speed = player.get_current_dot_lerp_speed()
	
	var t: float = clamp(speed * delta, 0.0, 1.0)
	dot_screen_pos = dot_screen_pos.lerp(mouse_screen, t)

	# Convert the smoothed screen-space dot back to world space
	if dot_sprite != null:
		var canvas_xform := get_viewport().get_canvas_transform()
		var dot_world: Vector2 = canvas_xform.affine_inverse() * dot_screen_pos
		dot_sprite.global_position = dot_world

func get_dot_world_position() -> Vector2:
	return dot_sprite.global_position

func on_weapon_fired(strength: float, duration: float) -> void:
	# Pulse the outer crosshair scale when a shot is actually fired
	if outer_sprite == null:
		return

	# Kill any previous tween so they don't fight each other
	if outer_pulse_tween and outer_pulse_tween.is_valid():
		outer_pulse_tween.kill()

	# Start from the base scale, instantly pop to a larger size,
	# then tween back down to the base scale.
	outer_sprite.scale = outer_base_scale * outer_pulse_scale

	outer_pulse_tween = create_tween()
	outer_pulse_tween.tween_property(
		outer_sprite,
		"scale",
		outer_base_scale,
		outer_pulse_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

---

## Effect Scripts

### `damage_number.gd`
**Location:** `game/Scripts/damage_number.gd`  
**Extends:** `Node2D`  
**Function:** Floating damage number popup with color coding, arc motion, rotation, and dynamic arc distance.

```gdscript
extends Node2D

@export var normal_color: Color = Color.WHITE
@export var crit_color: Color = Color(1.0, 1.0, 0.2) # yellow-ish
@export var kill_color: Color = Color(0.614, 0.088, 0.0, 1.0) # red-ish

@export var damage: int = 0
@export var lifetime: float = 0.3
@export var float_distance: float = 20.0
@export var arc_distance: float = 10
@export var arc_boost_factor: float = 5
@export var is_crit: bool = false
var is_killing_blow: bool = false

@export var min_rot_deg: float = 10.0
@export var max_rot_deg: float = 30.0

@onready var label: RichTextLabel = $Label

var t: float = 0.0
var start_pos: Vector2
var direction_sign: float
var movement_dir_sign: float = 0.0

func _ready() -> void:
	# Set the label text to the damage value
	label.text = str(damage)
	
	# Determine final color based on priority: killing blow > crit > normal
	var final_color: Color = normal_color
	if is_killing_blow:
		final_color = kill_color
	elif is_crit:
		final_color = crit_color
	
	label.modulate = final_color
	
	# Apply crit styling if this is a crit (scale up)
	if is_killing_blow:
		scale = Vector2(1.5, 1.5)
		
	if is_crit:
		scale = Vector2(1.5, 1.5)
	
	# Apply a very small random horizontal offset
	var random_x_offset: float = randf_range(-2.0, 2.0)
	global_position.x += random_x_offset
	
	# Store starting position for arc calculation
	start_pos = global_position
	
	# Decide arc direction and rotation based on hit type and enemy movement
	var base_angle: float = randf_range(min_rot_deg, max_rot_deg)
	
	if is_crit or is_killing_blow:
		# CRIT or FATAL hit:
		# Arc should go OPPOSITE to enemy movement direction if we know it.
		if abs(movement_dir_sign) > 0.01:
			# enemy movement_dir_sign:
			#   > 0 => moving RIGHT
			#   < 0 => moving LEFT
			# We want arc opposite to this:
			direction_sign = -sign(movement_dir_sign)
		else:
			# No clear movement direction, fall back to random arc
			direction_sign = 1.0 if randf() > 0.5 else -1.0
		
		# Rotate in the same direction as the arc (which is already opposite movement)
		rotation_degrees = direction_sign * base_angle
	else:
		# NORMAL hit:
		# Arc can be random, but NO rotation.
		direction_sign = 1.0 if randf() > 0.5 else -1.0
		rotation_degrees = 0.0
	
	# Adjust arc distance based on whether arc is going WITH or AGAINST enemy movement
	var arc_dir = direction_sign
	var move_dir = movement_dir_sign
	
	# Default: use base arc_distance
	if abs(move_dir) > 0.01:
		# Arc goes WITH enemy movement → boost
		if sign(arc_dir) == sign(move_dir):
			arc_distance *= arc_boost_factor
		# Arc goes OPPOSITE enemy movement → leave arc_distance as-is
	# else: enemy is not moving horizontally → do nothing
	
	# Create tween for animation
	var tween: Tween = create_tween()
	
	# Animate t from 0.0 to 0.6 over the full lifetime (only play ~60% of the arc)
	tween.tween_property(self, "t", 0.6, lifetime)
	
	# Animate alpha from 1.0 to 0.0 over the full lifetime
	modulate.a = 1.0
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	
	# When tween finishes, delete the node
	tween.tween_callback(queue_free).set_delay(lifetime)

func _process(_delta: float) -> void:
	# Update position based on parametric arc formula
	# x(t) = start_x + direction_sign * arc_distance * t
	# y(t) = start_y - float_distance * sin(t * PI)
	global_position.x = start_pos.x + direction_sign * arc_distance * t
	global_position.y = start_pos.y - float_distance * sin(t * PI)
```

### `hit_impact.gd`
**Location:** `game/Scripts/hit_impact.gd`  
**Extends:** `Node2D`  
**Function:** Auto-free script for hit impact effects when animation finishes.

```gdscript
extends Node2D

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
```

### `enemy_blood.gd`
**Location:** `game/Scripts/enemy_blood.gd`  
**Extends:** `Node2D`  
**Function:** Auto-free script for enemy blood effects using a timer.

```gdscript
extends Node2D

func _on_AutoFreeTimer_timeout() -> void:
	queue_free()
```

### `coin.gd`
**Location:** `game/Scripts/coin.gd`  
**Extends:** `Area2D`  
**Function:** Coin pickup system with arc motion animation and idle bobbing.

```gdscript
extends Area2D

@export var value: float = 1.0

# Arc motion settings
@export var travel_time: float = 0.4          # Time for the full arc
@export var min_horizontal_distance: float = 20.0
@export var max_horizontal_distance: float = 40.0
@export var min_vertical_drop: float = 8.0    # How far down from spawn the coin ends
@export var max_vertical_drop: float = 16.0
@export var arc_height: float = 25.0          # How high the arc goes at the peak

# Idle bobbing after landing
@export var bob_height: float = 2.0
@export var bob_speed: float = 4.0

@onready var sprite: Node2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $PickupAudio

var _picked_up: bool = false

var _t: float = 0.0
var _start_pos: Vector2
var _end_offset: Vector2
var _landing_pos: Vector2
var _landed: bool = false
var _bob_time: float = 0.0

func _ready() -> void:
	# Connect to body_entered so we can detect the player
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Initialize arc parameters
	_start_pos = global_position

	var dir_sign: float = 1.0 if randf() > 0.5 else -1.0
	var horizontal_dist: float = randf_range(min_horizontal_distance, max_horizontal_distance)
	var vertical_drop: float = randf_range(min_vertical_drop, max_vertical_drop)

	_end_offset = Vector2(dir_sign * horizontal_dist, vertical_drop)
	_landing_pos = _start_pos + _end_offset

	# Animate _t from 0.0 to 1.0 over travel_time using a Tween
	_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_t", 1.0, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_arc_finished)

func _process(delta: float) -> void:
	if _picked_up:
		return

	if not _landed:
		# Arc motion: horizontal lerp + vertical sine-based arc
		var x := _start_pos.x + _end_offset.x * _t
		var linear_y := _start_pos.y + _end_offset.y * _t
		var arc_y := -sin(_t * PI) * arc_height
		global_position = Vector2(x, linear_y + arc_y)
	else:
		# Idle bobbing at landing position
		_bob_time += delta * bob_speed
		var bob_offset_y := sin(_bob_time) * bob_height
		global_position = _landing_pos + Vector2(0.0, bob_offset_y)

func _on_arc_finished() -> void:
	_landed = true
	# Snap exactly to landing position at the end of the tween
	global_position = _landing_pos

func _on_body_entered(body: Node) -> void:
	if _picked_up:
		return

	var target: Node = body

	# Mirror the parent-check pattern from enemy.gd
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()

	if target.is_in_group("player") and target.has_method("add_gold"):
		_picked_up = true

		# Give gold to the player
		target.add_gold(value)

		# Disable collision and hide the sprite so it feels instantly collected
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		if sprite:
			sprite.visible = false

		# Play pickup sound if present, then free
		if audio_player and audio_player.stream:
			audio_player.play()
			if not audio_player.finished.is_connected(_on_audio_finished):
				audio_player.finished.connect(_on_audio_finished)
		else:
			queue_free()

func _on_audio_finished() -> void:
	queue_free()
```

---

## Camera Scripts

### `camera_2d.gd`
**Location:** `game/Scripts/camera_2d.gd`  
**Extends:** `Camera2D`  
**Function:** Camera shake system triggered by weapon fire signals.

```gdscript
extends Camera2D

var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _original_offset: Vector2

func _ready() -> void:
	_original_offset = offset

func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta

		var t := _shake_time / _shake_duration
		var current_strength := _shake_strength * t

		offset = _original_offset + Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * current_strength

		if _shake_time <= 0.0:
			offset = _original_offset

func start_shake(strength: float = 4.0, duration: float = 0.1) -> void:
	_shake_strength = strength
	_shake_duration = max(duration, 0.0001)
	_shake_time = _shake_duration
```

---

## Summary

This document contains all scripts in the Shoot To Kill project, organized by category:

- **Player Scripts**: Player controller with movement, health, shooting, animation, aiming, and gold currency
- **Enemy Scripts**: Enemy AI with state machine, health, contact damage, flash effects, health bars, and loot drops
- **Weapon Scripts**: Base weapon class, pistol implementation, and bullet physics
- **UI Scripts**: HUD manager and crosshair system with outer pulse effect
- **Effect Scripts**: Damage numbers, hit impacts, blood effects, and coin pickups
- **Camera Scripts**: Camera shake system

All scripts are current as of the latest project state.

