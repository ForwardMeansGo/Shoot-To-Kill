# Scripts Copy — Shoot To Kill

This document contains copies of all scripts in the project, organized by script name and function.

---

## Player Scripts

### `player.gd`
**Location:** `game/Scripts/player.gd`  
**Extends:** `CharacterBody2D`  
**Function:** Main player controller handling movement, health, shooting, weapon switching (primary/secondary), animation, aiming, weapon bob, visual kickback, debug input blocking, and UI mouse mode management.

```gdscript
extends CharacterBody2D

@onready var weapon_holder: Node2D = $WeaponHolder
@onready var weapon_bob_offset: Node2D = $WeaponHolder/WeaponBobOffset
@onready var gun: Node2D = $WeaponHolder/WeaponBobOffset/Gun
@onready var arm_sprite: Sprite2D = $WeaponHolder/WeaponBobOffset/ArmSprite
@onready var back_arm_sprite: Sprite2D = $WeaponHolder/WeaponBobOffset/BackArmSprite
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
var godmode_enabled: bool = false

@export var primary_weapon_scene: PackedScene
@export var secondary_weapon_scene: PackedScene

var current_weapon_slot: int = 0  # 0 = unspecified, 1 = primary, 2 = secondary

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

	# Initialize health
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

	# Initialize gold
	gold = starting_gold
	emit_signal("gold_changed", gold)

	# Weapon setup:
	# If a primary weapon scene is assigned, equip it.
	# Otherwise, just connect signals to whichever gun is already in the scene.
	if primary_weapon_scene != null:
		_equip_weapon_scene(primary_weapon_scene)
		current_weapon_slot = 1
	else:
		_connect_weapon_signals()

	# Initialize back arm sprite visibility
	if back_arm_sprite != null:
		back_arm_sprite.visible = false

func _connect_weapon_signals() -> void:
	if gun == null:
		return

	if gun.has_signal("fired"):
		if not gun.is_connected("fired", Callable(self, "_on_weapon_fired")):
			gun.connect("fired", Callable(self, "_on_weapon_fired"))

		if crosshair != null and crosshair.has_method("on_weapon_fired"):
			if not gun.is_connected("fired", Callable(crosshair, "on_weapon_fired")):
				gun.connect("fired", Callable(crosshair, "on_weapon_fired"))


func _disconnect_weapon_signals() -> void:
	if gun == null:
		return

	if gun.has_signal("fired"):
		if gun.is_connected("fired", Callable(self, "_on_weapon_fired")):
			gun.disconnect("fired", Callable(self, "_on_weapon_fired"))

		if crosshair != null and crosshair.has_method("on_weapon_fired"):
			if gun.is_connected("fired", Callable(crosshair, "on_weapon_fired")):
				gun.disconnect("fired", Callable(crosshair, "on_weapon_fired"))


func _equip_weapon_scene(scene: PackedScene) -> void:
	if scene == null:
		return

	var parent: Node2D = weapon_bob_offset
	var new_transform: Transform2D

	# If we already have a gun instance, use its transform as the anchor
	if gun != null and gun.is_inside_tree():
		new_transform = gun.global_transform
		_disconnect_weapon_signals()
		gun.queue_free()
	else:
		# Fallback: use the WeaponBobOffset transform
		new_transform = parent.global_transform

	# Instance and attach new weapon
	var new_weapon: Node2D = scene.instantiate()
	parent.add_child(new_weapon)

	gun = new_weapon
	gun.global_transform = new_transform

	_connect_weapon_signals()


func _switch_to_primary() -> void:
	if primary_weapon_scene == null:
		return
	_equip_weapon_scene(primary_weapon_scene)
	current_weapon_slot = 1


func _switch_to_secondary() -> void:
	if secondary_weapon_scene == null:
		return
	_equip_weapon_scene(secondary_weapon_scene)
	current_weapon_slot = 2

func _physics_process(delta: float) -> void:
	if GameManager.has_method("is_debug_input_blocked") and GameManager.is_debug_input_blocked():
		# Stop movement while debug input is blocked
		if "velocity" in self:
			velocity = Vector2.ZERO
		return

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

func _input(_event: InputEvent) -> void:
	if GameManager.has_method("is_debug_input_blocked") and GameManager.is_debug_input_blocked():
		# Debug console is open: ignore input here, but don't consume it,
		# so UI elements (like the console) can still process it.
		return
	# We intentionally do NOT handle anything else here so normal input continues when debug is not blocked.

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
			
			# Gun hand offset (per-weapon, with fallback to old constants)
			if gun:
				var hand_offset: Vector2 = Vector2.ZERO

				if gun is WeaponBase:
					if facing_left:
						hand_offset = gun.hand_offset_left
					else:
						hand_offset = gun.hand_offset_right
				else:
					# Fallback: keep old pistol-tuned values
					if facing_left:
						hand_offset = Vector2(8, 2)
					else:
						hand_offset = Vector2(8, -2)

				gun.global_position = arm_sprite.global_position + hand_offset.rotated(arm_sprite.global_rotation)

		# Back arm follows the gun for two-handed weapons
		if back_arm_sprite != null:
			back_arm_sprite.visible = false

			if gun != null and gun is WeaponBase and gun.is_two_handed:
				# Choose support offset based on facing
				var support_offset: Vector2 = Vector2.ZERO
				if facing_left:
					support_offset = gun.support_hand_offset_left
				else:
					support_offset = gun.support_hand_offset_right

				var gun_pos: Vector2 = gun.global_position
				var gun_rot: float = gun.global_rotation
				var rotated_support: Vector2 = support_offset.rotated(gun_rot)

				back_arm_sprite.global_position = gun_pos + rotated_support
				back_arm_sprite.rotation = gun_rot
				back_arm_sprite.visible = true

		# Tell the weapon which way we're facing so it can flip its sprite
		if gun.has_method("set_facing_left"):
			gun.set_facing_left(facing_left)

		# Gun input (switching + firing) should use the SAME aim_point
		# Block gameplay input when debug console is open
		if not (GameManager.has_method("is_debug_input_blocked") and GameManager.is_debug_input_blocked()):
			# Weapon switching: 1 = primary, 2 = secondary
			if Input.is_action_just_pressed("weapon_1") and primary_weapon_scene != null and current_weapon_slot != 1:
				_switch_to_primary()
				return

			if Input.is_action_just_pressed("weapon_2") and secondary_weapon_scene != null and current_weapon_slot != 2:
				_switch_to_secondary()
				return

			# Shooting
			var shoot_pressed: bool = Input.is_action_pressed("shoot")
			var shoot_just_pressed: bool = Input.is_action_just_pressed("shoot")

			var wants_to_shoot: bool = false

			if gun is WeaponBase and gun.is_full_auto:
				# Full-auto weapons can fire while held
				wants_to_shoot = shoot_pressed
			else:
				# Semi-auto weapons fire on click only
				wants_to_shoot = shoot_just_pressed

			if wants_to_shoot and gun.has_method("try_shoot"):
				var did_shoot: bool = gun.try_shoot(aim_point)
				if did_shoot:
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

		var desired_anim: String = ""

		if is_backwards:
			# Backwards run
			var backwards_name := "run_backwards"
			if _is_current_weapon_two_handed():
				if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("run_backwards_noarms"):
					backwards_name = "run_backwards_noarms"
			desired_anim = backwards_name
		else:
			# Forward run
			var can_use_noarms := false
			if _is_current_weapon_two_handed():
				if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("run_noarms"):
					can_use_noarms = true

			if can_use_noarms:
				desired_anim = "run_noarms"
			else:
				desired_anim = "run"

		if anim_sprite.animation != desired_anim:
			anim_sprite.play(desired_anim)

	# 4) In air: choose jump vs fall based on vertical velocity
	elif not on_floor_now:
		var desired_anim := "jump" if velocity.y < 0.0 else "fall"
		if anim_sprite.animation != desired_anim:
			anim_sprite.play(desired_anim)

	# 5) Idle on ground
	else:
		var idle_name := "idle"
		if _is_current_weapon_two_handed():
			if anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation("idle_noarms"):
				idle_name = "idle_noarms"

		if anim_sprite.animation != idle_name:
			anim_sprite.play(idle_name)

	# 6) Update floor state for next frame
	was_on_floor = on_floor_now

func _get_weapon_bob_for_current_frame() -> float:
	if weapon_bob_offset == null or anim_sprite == null:
		return 0.0

	var frame_index: int = anim_sprite.frame
	var anim_name: String = anim_sprite.animation

	var offsets: Array = []

	match anim_name:
		"idle", "idle_noarms":
			offsets = weapon_bob_idle
		"run", "run_noarms":
			offsets = weapon_bob_run
		"run_backwards", "run_backwards_noarms":
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

func _is_current_weapon_two_handed() -> bool:
	if gun != null and gun is WeaponBase:
		return gun.is_two_handed
	return false

func set_ui_mouse_mode(is_ui_open: bool) -> void:
	# When a full-screen UI like the shop is open, we want the OS cursor visible
	# and the in-game crosshair hidden. When the UI closes, we go back to
	# hidden OS cursor + crosshair.
	if is_ui_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if crosshair != null:
			crosshair.visible = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		if crosshair != null:
			crosshair.visible = true

func _on_weapon_fired(_strength: float, _duration: float) -> void:
	if cam != null:
		cam.start_shake(_strength, _duration)

func take_damage(amount: int) -> void:
	if godmode_enabled:
		return
	if invuln_timer > 0.0:
		return
	
	current_health = max(current_health - amount, 0)
	invuln_timer = invulnerability_time
	
	emit_signal("health_changed", current_health, max_health)
	print("Player took damage: ", amount, " -> HP: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	# Notify any listeners
	emit_signal("died")

	# Let GameManager handle what happens on death (e.g. go to Tavern)
	if GameManager != null and GameManager.has_method("on_player_died"):
		GameManager.on_player_died()
	else:
		push_warning("GameManager autoload not available; cannot handle player death centrally.")

	# Do not reload the scene here; GameManager is responsible for transitions.

func add_gold(amount: float) -> void:
	if amount == 0.0:
		return

	# Forward run-gold gains into the central GameManager autoload.
	# GameManager is configured as an AutoLoad singleton in Project Settings.
	if GameManager != null and GameManager.has_method("add_gold_run"):
		GameManager.add_gold_run(amount)
	else:
		push_warning("GameManager autoload not available; cannot add gold.")
```

---

## Enemy Scripts

### `enemy.gd`
**Location:** `game/Scripts/enemies/enemy.gd`  
**Extends:** `CharacterBody2D`  
**Function:** Enemy AI controller with state machine, health, contact damage, flash effects, health bars, died signal, set_player method, penetration resistance, and knockback system.

```gdscript
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
@export var penetration_resistance: int = 1
@export var knockback_decay: float = 18.0
@export var knockback_max_speed: float = 220.0

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
var knockback_velocity: Vector2 = Vector2.ZERO

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

	# --- Knockback (snappy, low-ice) ---
	# Apply knockback as a short-lived horizontal impulse blended into velocity.
	# The multiplier makes recovery faster without needing new exports.
	velocity.x += knockback_velocity.x

	# Stronger decay so knockback stops quickly (prevents "ice sliding").
	knockback_velocity.x = move_toward(
		knockback_velocity.x,
		0.0,
		knockback_decay * 3.5 * delta
	)

	# If knockback is tiny, snap to zero to stop micro-sliding.
	if abs(knockback_velocity.x) < 2.0:
		knockback_velocity.x = 0.0

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

func apply_knockback(dir: Vector2, strength: float) -> void:
	if strength <= 0.0:
		return
	var d := dir
	if d == Vector2.ZERO:
		return
	d = d.normalized()

	# Horizontal knockback only
	var impulse := d.x * strength

	# If we're already being knocked back in the same direction, add less (prevents long skating).
	if sign(knockback_velocity.x) == sign(impulse):
		impulse *= 0.55

	knockback_velocity.x += impulse
	knockback_velocity.x = clamp(knockback_velocity.x, -knockback_max_speed, knockback_max_speed)

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
```

---

## Weapon Scripts

### `weapon_base.gd`
**Location:** `game/Scripts/weapons/weapon_base.gd`  
**Extends:** `Node2D`  
**Class Name:** `WeaponBase`  
**Function:** Base class for all weapons, handling damage rolling, crit system, fire rate, full-auto, bullet spread, bullet spawning, audio, aim dot smoothing, and per-weapon hand offsets.

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

# Fire control
# fire_rate: shots per second. 0 or less = no internal cooldown.
@export var fire_rate: float = 0.0
# If true, player input can hold the trigger to keep firing.
@export var is_full_auto: bool = false

@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0
# Max random angular deviation for each shot.
# 0 = perfectly accurate. Higher = more inaccurate.

# Per-weapon hand offsets (relative to the arm sprite)
@export var hand_offset_right: Vector2 = Vector2(8, -2)
@export var hand_offset_left: Vector2 = Vector2(8, 2)

# Two-handed weapon support
@export var is_two_handed: bool = false
@export var support_hand_offset_right: Vector2 = Vector2.ZERO
@export var support_hand_offset_left: Vector2 = Vector2.ZERO

# Bullet penetration system
@export var penetration_min: int = 0
@export var penetration_max: int = 0
@export_range(0.0, 1.0, 0.01) var penetration_chance: float = 1.0
@export var penetration_damage_drop_per_pen: float = 0.10 # 10% per extra enemy

# Bullet range
@export var max_range: float = 300

# Bullet speed
@export var bullet_speed: float = 450

# Bullet knockback
@export var bullet_knockback: float = 15
@export var knockback_drop_per_pen: float = 0.4
@export var crit_knockback_multiplier: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $GunAudio

var facing_left: bool = false
var _time_until_next_shot: float = 0.0

func _process(delta: float) -> void:
	# Cooldown timer for fire rate
	if _time_until_next_shot > 0.0:
		_time_until_next_shot = max(_time_until_next_shot - delta, 0.0)

func set_facing_left(is_left: bool) -> void:
	facing_left = is_left
	# Grip always points "down" when on the left side
	sprite.flip_v = is_left

func aim_at(target_global_pos: Vector2) -> void:
	# Rotate the weapon so its +X axis points towards the mouse
	look_at(target_global_pos)

func can_fire() -> bool:
	# If fire_rate <= 0, weapon can always fire (no internal cooldown)
	return _time_until_next_shot <= 0.0

func _apply_fire_cooldown() -> void:
	if fire_rate <= 0.0:
		_time_until_next_shot = 0.0
	else:
		_time_until_next_shot = 1.0 / fire_rate

func spawn_bullet(target_global_pos: Vector2) -> void:
	# Roll damage and crit
	var dmg_info := _roll_damage()
	var dmg_value: int = dmg_info["damage"]
	var is_crit: bool = dmg_info["is_crit"]
	
	var muzzle_global: Vector2 = $Muzzle.global_position
	var dir: Vector2 = (target_global_pos - muzzle_global).normalized()

	# Apply random spread (angle in degrees)
	if spread_degrees > 0.0:
		var half := spread_degrees
		var random_angle := deg_to_rad(randf_range(-half, half))
		dir = dir.rotated(random_angle)

	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle_global
	bullet.direction = dir
	bullet.rotation = dir.angle()
	
	# Set damage and crit info on bullet
	if "damage" in bullet:
		bullet.damage = dmg_value
	if "is_crit" in bullet:
		bullet.is_crit = is_crit
	
	# Set penetration properties on bullet
	if "penetration_power" in bullet:
		bullet.penetration_power = roll_penetration_power()
	if "penetration_damage_drop_per_pen" in bullet:
		bullet.penetration_damage_drop_per_pen = penetration_damage_drop_per_pen
	
	# Set max range on bullet
	if "max_range" in bullet:
		bullet.max_range = max_range
	
	# Set bullet speed
	if "speed" in bullet:
		bullet.speed = bullet_speed
	
	# Set bullet knockback
	if "knockback_strength" in bullet:
		bullet.knockback_strength = bullet_knockback
	if "knockback_drop_per_pen" in bullet:
		bullet.knockback_drop_per_pen = knockback_drop_per_pen
	if "crit_knockback_multiplier" in bullet:
		bullet.crit_knockback_multiplier = crit_knockback_multiplier

	get_tree().current_scene.add_child(bullet)

	_play_shot_sound(muzzle_global)

	emit_signal("fired", shake_strength, shake_duration)
	_apply_fire_cooldown()

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

func roll_penetration_power() -> int:
	if penetration_max <= 0:
		return 0
	if randf() > penetration_chance:
		return 0
	var lo: int = mini(penetration_min, penetration_max)
	var hi: int = maxi(penetration_min, penetration_max)
	return randi_range(lo, hi)

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
**Function:** Pistol weapon implementation with semi-auto firing that respects WeaponBase cooldown.

```gdscript
extends WeaponBase

func try_shoot(target_global_pos: Vector2) -> bool:
	# Semi-auto pistol: respect WeaponBase cooldown, but no hold-to-fire.
	if not can_fire():
		return false

	spawn_bullet(target_global_pos)
	return true
```

### `weapon_assault_rifle.gd`
**Location:** `game/Scripts/weapons/weapon_assault_rifle.gd`  
**Extends:** `WeaponBase`  
**Function:** Assault Rifle weapon implementation capable of full-auto firing when configured.

```gdscript
extends WeaponBase

"""
Assault Rifle weapon implementation.

For now this behaves like a semi-auto weapon:
- One shot per click (same as pistol).
- All behaviour (damage, crit, shake, aim dot smoothing) is driven
  by the exported properties on WeaponBase and tuned per-scene.

Later we can extend this script with:
- Internal fire rate / cooldown.
- Proper full-auto behaviour when the shoot button is held.
- Per-weapon recoil patterns if needed.
"""

func try_shoot(target_global_pos: Vector2) -> bool:
	# Full-auto capable: WeaponBase handles cooldown.
	if not can_fire():
		return false

	spawn_bullet(target_global_pos)
	return true
```

### `bullet.gd`
**Location:** `game/Scripts/weapons/bullet.gd`  
**Extends:** `Area2D`  
**Function:** Bullet physics with continuous collision detection, multi-hit penetration, range tracking, speed control, damage handling with cumulative reduction, and knockback application.

```gdscript
extends Area2D

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5
@export var damage: int = 10
@export var hit_effect_scene: PackedScene

var previous_position: Vector2
var is_crit: bool = false
var penetration_power: int = 0
var penetration_damage_drop_per_pen: float = 0.20
var _hit_enemy_ids: Dictionary = {} # instance_id -> true
const MAX_HITS_PER_FRAME := 8
const PIERCE_EPSILON := 1.0
var max_range: float = INF
var _distance_travelled: float = 0.0
var _enemies_damaged: int = 0
var knockback_strength: float = 0.0
var knockback_drop_per_pen: float = 0.20
var crit_knockback_multiplier: float = 1.0

func _ready() -> void:
	previous_position = global_position
	_distance_travelled = 0.0
	_enemies_damaged = 0

func _resolve_enemy_from_collider(collider: Object) -> Node:
	if collider == null:
		return null
	if collider is Node:
		var n := collider as Node
		if n.is_in_group("enemy"):
			return n
		if n.get_parent() != null and n.get_parent().is_in_group("enemy"):
			return n.get_parent()
	return null

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

	# Track distance traveled for max range check
	var segment_distance: float = previous_position.distance_to(target_pos)
	_distance_travelled += segment_distance
	
	# Check if bullet has exceeded max range
	if _distance_travelled >= max_range:
		queue_free()
		return

	# Add a small extra margin in the same direction to be safe
	var ray_to: Vector2 = target_pos + direction * 2.0

	# Multi-hit penetration loop
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var segment_from: Vector2 = previous_position
	var segment_to: Vector2 = ray_to
	var exclude_list: Array = [self]
	var hit_count: int = 0
	var base_damage: int = damage

	while hit_count < MAX_HITS_PER_FRAME:
		# Create raycast query for this segment
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(segment_from, segment_to)
		query.collision_mask = collision_mask
		query.exclude = exclude_list
		query.hit_from_inside = true

		var result: Dictionary = space_state.intersect_ray(query)

		# No hit - move to target position and continue
		if result.is_empty():
			global_position = target_pos
			previous_position = target_pos
			return

		# Hit something
		var hit_pos: Vector2 = result["position"]
		var collider: Object = result["collider"]

		# Exclude this collider from subsequent raycasts using RID
		if collider is CollisionObject2D:
			exclude_list.append((collider as CollisionObject2D).get_rid())

		if collider is Node:
			var node: Node = collider as Node

			# Ignore player
			if node.is_in_group("player"):
				# Hit player - stop penetration, but don't damage
				global_position = hit_pos
				queue_free()
				return

		# Resolve enemy from collider (checks collider and parent)
		var enemy := _resolve_enemy_from_collider(collider)
		
		if enemy != null and enemy.has_method("take_damage"):
			var enemy_id := enemy.get_instance_id()
			
			# Check if we already hit this enemy (persists for bullet lifetime)
			if _hit_enemy_ids.has(enemy_id):
				# Already hit this enemy - exclude it and continue
				# Advance segment slightly to continue
				segment_from = hit_pos + direction.normalized() * PIERCE_EPSILON
				continue

			# Apply damage to this enemy
			var damage_to_deal: int = base_damage
			
			# Apply cumulative damage drop based on number of enemies already damaged
			if _enemies_damaged > 0:
				var step: float = 1.0 - penetration_damage_drop_per_pen
				if step < 0.0:
					step = 0.0
				var damage_multiplier: float = pow(step, float(_enemies_damaged))
				damage_to_deal = max(1, int(round(float(base_damage) * damage_multiplier)))

			enemy.take_damage(damage_to_deal, is_crit)

			# Apply knockback with crit bonus and penetration reduction
			var kb: float = knockback_strength

			# Apply crit bonus before penetration scaling
			if is_crit:
				kb *= crit_knockback_multiplier

			# Apply penetration-based knockback reduction
			if _enemies_damaged > 0:
				var step: float = 1.0 - knockback_drop_per_pen
				if step < 0.0:
					step = 0.0
				kb *= pow(step, float(_enemies_damaged))

			if kb > 0.0 and enemy.has_method("apply_knockback"):
				enemy.apply_knockback(direction, kb)

			# Spawn hit impact effect if assigned (only on first hit)
			if _enemies_damaged == 0 and hit_effect_scene != null:
				var hit_effect = hit_effect_scene.instantiate()
				hit_effect.global_position = hit_pos
				get_tree().current_scene.add_child(hit_effect)

			# Get resistance from enemy (default to 1 if not found)
			var resistance: int = 1
			if "penetration_resistance" in enemy:
				resistance = enemy.penetration_resistance

			# Record this enemy as hit (persists for bullet lifetime)
			_hit_enemy_ids[enemy_id] = true
			
			# Increment enemies damaged counter
			_enemies_damaged += 1

			# Reduce penetration power
			penetration_power -= resistance

			# Check if we can continue penetrating
			if penetration_power >= 1:
				# Continue piercing - advance segment start past this hit
				segment_from = hit_pos + direction.normalized() * PIERCE_EPSILON
				hit_count += 1
				continue
			else:
				# Out of penetration power - stop at this hit
				global_position = hit_pos
				queue_free()
				return
		elif result.collider is Node:
			# Hit a Node collider but it's not an enemy (world/props/etc) - stop
			global_position = hit_pos
			queue_free()
			return
		else:
			# Hit non-node collider - stop
			global_position = hit_pos
			queue_free()
			return

	# Reached max hits per frame - move to target and continue next frame
	global_position = target_pos
	previous_position = target_pos
```

---

## UI Scripts

### `hud.gd`
**Location:** `game/Scripts/hud.gd`  
**Extends:** `CanvasLayer`  
**Function:** HUD manager for player health bar with smooth tweening, and currency/XP display panel.

```gdscript
extends CanvasLayer

@onready var health_bar: TextureProgressBar = $PlayerHealthBar
@onready var gold_label: Label = $InfoPanel/GoldBox/GoldLabel
@onready var essence_label: Label = $InfoPanel/EssenceBox/EssenceLabel
@onready var xp_label: Label = $InfoPanel/XPBox/XPLabel
@onready var wave_label: Label = $InfoPanel/WaveBox/WaveLabel
@onready var stats_box: Node = $InfoPanel/StatsBox
@onready var monsters_killed_label: Label = $InfoPanel/StatsBox/MonstersKilledLabel
@onready var monsters_remaining_label: Label = $InfoPanel/StatsBox/MonstersRemainingLabel
@export var player_path: NodePath = ^"../Player"

var player: Node = null
var hp_tween: Tween = null
var _wave_manager: Node = null

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

	# Hook into GameManager for gold, essence, and XP/level
	if GameManager != null:
		# Connect signals if available
		if GameManager.has_signal("gold_run_changed") and not GameManager.gold_run_changed.is_connected(_on_gold_run_changed):
			GameManager.gold_run_changed.connect(_on_gold_run_changed)

		if GameManager.has_signal("essence_changed") and not GameManager.essence_changed.is_connected(_on_essence_changed):
			GameManager.essence_changed.connect(_on_essence_changed)

		if GameManager.has_signal("xp_changed") and not GameManager.xp_changed.is_connected(_on_xp_changed):
			GameManager.xp_changed.connect(_on_xp_changed)

		# Initialize from current GameManager state
		_on_gold_run_changed(GameManager.gold_run)
		_on_essence_changed(GameManager.essence_total)
		_on_xp_changed(GameManager.xp, GameManager.level)
	else:
		push_warning("HUD: GameManager autoload not available; currency/XP HUD will not update.")

	# Hook into WaveManager for wave + monster stats
	var root := get_tree().current_scene
	if root != null and root.has_node("WaveManager"):
		_wave_manager = root.get_node("WaveManager")

		if _wave_manager.has_signal("wave_started") and not _wave_manager.wave_started.is_connected(_on_wave_started):
			_wave_manager.wave_started.connect(_on_wave_started)
	else:
		_wave_manager = null

func _on_player_health_changed(current: int, max_health: int) -> void:
	if health_bar == null:
		return

	health_bar.max_value = max

	# Kill any existing tween so they don't fight
	if hp_tween and hp_tween.is_valid():
		hp_tween.kill()

	# Create a new tween to animate from current bar value to the new HP
	hp_tween = create_tween()
	hp_tween.tween_property(health_bar, "value", current, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_gold_run_changed(current_gold: float) -> void:
	if gold_label == null:
		return

	# Gold is a float (can be 0.5 etc). Show with at most 1 decimal place.
	var display_value: float = snapped(current_gold, 0.1)
	gold_label.text = str(display_value)

func _on_essence_changed(current_essence: int) -> void:
	if essence_label == null:
		return

	essence_label.text = str(current_essence)

func _on_xp_changed(current_xp: int, current_level: int) -> void:
	if xp_label == null:
		return

	# Show both level and XP so the player sees progression.
	# Example: "Lv 3  XP 42"
	xp_label.text = "Lv %d  XP %d" % [current_level, current_xp]

func _on_wave_started(wave_index: int) -> void:
	if wave_label == null:
		return
	wave_label.text = "WAVE: %d" % wave_index

func _process(_delta: float) -> void:
	if _wave_manager == null:
		return

	# Update monsters killed
	if monsters_killed_label != null and _wave_manager.has_method("get_total_kills"):
		var total_kills: int = _wave_manager.get_total_kills()
		monsters_killed_label.text = "KILLS: %d" % total_kills

	# Update monsters remaining in current wave
	if monsters_remaining_label != null and _wave_manager.has_method("get_monsters_remaining"):
		var remaining: int = _wave_manager.get_monsters_remaining()
		monsters_remaining_label.text = "REMAINING: %d" % remaining
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

## Wave System Scripts

### `wave_manager.gd`
**Location:** `game/Scripts/wave_manager.gd`  
**Extends:** `Node`  
**Function:** Endless wave system with difficulty scaling, off-screen enemy spawning, kill tracking, and automatic wave progression.

```gdscript
extends Node

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)

const ENEMY_BASIC_SCENE := preload("res://Scenes/EnemyBasic.tscn")

@export var base_break_duration: float = 15.0
@export var base_target_concurrent: int = 4
@export var max_target_concurrent: int = 25
@export var base_total_basic: int = 6
@export var total_basic_per_wave: int = 3
@export var max_total_basic: int = 80
@export var base_spawn_interval: float = 0.8
@export var min_spawn_interval: float = 0.25
@export var spawn_interval_decay_per_wave: float = 0.03

var current_wave_index: int = 0
var _current_wave_def: Dictionary = {}
var _spawn_queue: Array = []  # each entry: { "scene": PackedScene, "spawn_group": String }
var _spawn_index: int = 0
var _active_enemies: int = 0
var _spawn_points_by_group: Dictionary = {}  # String -> Array[Node2D]
var _player: Node2D = null
var _total_kills: int = 0

@onready var _spawn_timer: Timer = Timer.new()
@onready var _break_timer: Timer = Timer.new()

func _ready() -> void:
	# Configure spawn timer
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	# Configure break timer
	_break_timer.one_shot = true
	_break_timer.timeout.connect(_on_break_timer_timeout)
	add_child(_break_timer)

	# Scan the tree for spawn points
	var root := get_tree().current_scene
	if root != null and root.has_node("WaveSpawnPoints"):
		var spawn_points_parent := root.get_node("WaveSpawnPoints")
		for child in spawn_points_parent.get_children():
			# Check if this child has the spawn_group property (indicates wave_spawn_point.gd script)
			if "spawn_group" in child:
				var group_name: String = str(child.spawn_group)
				
				if not _spawn_points_by_group.has(group_name):
					_spawn_points_by_group[group_name] = []
				_spawn_points_by_group[group_name].append(child)
	
	if _spawn_points_by_group.is_empty():
		push_warning("WaveManager: No spawn points found! Add WaveSpawnPoints node with children that have wave_spawn_point.gd script.")

	# Cache player reference for enemy AI
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		_player = players[0]
	else:
		_player = null
		push_warning("WaveManager: No player found in 'player' group; enemies will not move towards the player.")

	# Start the first wave automatically
	_start_next_wave()

func _build_wave_definition(wave_index: int) -> Dictionary:
	var wave_name: String = "Wave %d" % wave_index

	var target_concurrent: int = clamp(
		base_target_concurrent + wave_index,
		base_target_concurrent,
		max_target_concurrent
	)

	var total_basic: int = clamp(
		base_total_basic + (wave_index - 1) * total_basic_per_wave,
		base_total_basic,
		max_total_basic
	)

	var spawn_interval: float = max(
		base_spawn_interval - (wave_index - 1) * spawn_interval_decay_per_wave,
		min_spawn_interval
	)

	var enemy_defs: Array = [
		{
			"scene": ENEMY_BASIC_SCENE,
			"total_count": total_basic,
			"spawn_group": "default",
			"early_ratio": 0.6,
			"mid_ratio": 0.25,
			"late_ratio": 0.15,
		}
	]

	return {
		"name": wave_name,
		"target_concurrent": target_concurrent,
		"spawn_interval": spawn_interval,
		"break_duration": base_break_duration,
		"enemies": enemy_defs,
	}

func _generate_spawn_queue(wave_def: Dictionary) -> Array:
	var early: Array = []
	var mid: Array = []
	var late: Array = []

	var enemies_variant = wave_def.get("enemies", [])
	var enemies: Array = enemies_variant if enemies_variant is Array else []

	for e_variant in enemies:
		if typeof(e_variant) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_variant

		var scene: PackedScene = e.get("scene", null)
		if scene == null:
			continue

		var total_count: int = int(e.get("total_count", 0))
		if total_count <= 0:
			continue

		var group_name: String = str(e.get("spawn_group", "default"))

		var early_ratio: float = float(e.get("early_ratio", 0.6))
		var mid_ratio: float = float(e.get("mid_ratio", 0.25))

		var early_count: int = int(round(total_count * early_ratio))
		var mid_count: int = int(round(total_count * mid_ratio))
		var used: int = early_count + mid_count
		var late_count: int = max(total_count - used, 0)

		for i in range(early_count):
			early.append({ "scene": scene, "spawn_group": group_name })
		for i in range(mid_count):
			mid.append({ "scene": scene, "spawn_group": group_name })
		for i in range(late_count):
			late.append({ "scene": scene, "spawn_group": group_name })

	early.shuffle()
	mid.shuffle()
	late.shuffle()

	var result: Array = []
	result.append_array(early)
	result.append_array(mid)
	result.append_array(late)
	return result

func _start_next_wave() -> void:
	current_wave_index += 1

	_current_wave_def = _build_wave_definition(current_wave_index)
	_spawn_queue = _generate_spawn_queue(_current_wave_def)
	_spawn_index = 0
	_active_enemies = 0

	var interval: float = float(_current_wave_def.get("spawn_interval", 0.5))
	_spawn_timer.wait_time = max(interval, 0.01)
	_spawn_timer.start()

	emit_signal("wave_started", current_wave_index)

func _is_offscreen(global_pos: Vector2) -> bool:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if camera == null:
		# No camera, assume off-screen (safer for spawning)
		return true
	
	# Get the camera's visible area in world space
	var viewport_size := viewport.get_visible_rect().size
	var world_size := viewport_size / camera.zoom
	var camera_center := camera.global_position
	var world_rect := Rect2(
		camera_center - world_size / 2.0,
		world_size
	)
	
	# Add a margin to ensure enemies spawn well off-screen
	var margin := 100.0
	var expanded_rect := Rect2(
		world_rect.position - Vector2(margin, margin),
		world_rect.size + Vector2(margin * 2, margin * 2)
	)
	
	return not expanded_rect.has_point(global_pos)

func _try_spawn_entry(entry: Dictionary) -> bool:
	var scene: PackedScene = entry.get("scene")
	if scene == null:
		return false

	var group_name: String = str(entry.get("spawn_group", "default"))
	var points: Array = _spawn_points_by_group.get(group_name, [])
	if points.is_empty():
		return false

	var shuffled_points := points.duplicate()
	shuffled_points.shuffle()

	for p in shuffled_points:
		if not (p is Node2D):
			continue
		var pos: Vector2 = (p as Node2D).global_position
		if _is_offscreen(pos):
			var enemy = scene.instantiate()

			# Spawn slightly above the spawn point, with small horizontal jitter
			var jitter_x: float = randf_range(-8.0, 8.0)
			var vertical_offset: float = -16.0  # 16 pixels above the spawn point (upwards in Godot's Y)
			enemy.global_position = pos + Vector2(jitter_x, vertical_offset)

			# Assign player reference if possible
			if _player != null and enemy.has_method("set_player"):
				enemy.set_player(_player)

			# Add to current scene
			get_tree().current_scene.add_child(enemy)

			# Connect died signal if present
			if enemy.has_signal("died"):
				if not enemy.died.is_connected(_on_enemy_died):
					enemy.died.connect(_on_enemy_died)

			_active_enemies += 1
			return true

	# Could not find valid off-screen point
	return false

func _on_spawn_timer_timeout() -> void:
	# Already no queue and no enemies? Wave is done.
	if _spawn_index >= _spawn_queue.size() and _active_enemies <= 0:
		_on_wave_cleared()
		return

	var target_concurrent: int = int(_current_wave_def.get("target_concurrent", 5))

	if _active_enemies >= target_concurrent:
		return

	if _spawn_index >= _spawn_queue.size():
		# No more units to schedule, just wait for kills
		return

	var entry: Dictionary = _spawn_queue[_spawn_index]
	var spawned: bool = _try_spawn_entry(entry)
	if spawned:
		_spawn_index += 1

func _on_enemy_died() -> void:
	_active_enemies = max(_active_enemies - 1, 0)
	_total_kills += 1

func _on_wave_cleared() -> void:
	_spawn_timer.stop()
	emit_signal("wave_cleared", current_wave_index)

	var break_duration: float = float(_current_wave_def.get("break_duration", base_break_duration))
	_break_timer.wait_time = max(break_duration, 0.0)
	_break_timer.start()

func _on_break_timer_timeout() -> void:
	_start_next_wave()

func get_total_kills() -> int:
	return _total_kills

func get_monsters_remaining() -> int:
	# Remaining = not yet spawned from the queue + currently alive
	var total: int = _spawn_queue.size()
	if total <= 0:
		return _active_enemies

	var spawned_so_far: int = min(_spawn_index, total)
	var pending: int = max(total - spawned_so_far, 0)

	return pending + _active_enemies
```

### `wave_spawn_point.gd`
**Location:** `game/Scripts/wave_spawn_point.gd`  
**Extends:** `Node2D`  
**Function:** Simple spawn point marker script for wave system.

```gdscript
extends Node2D

@export var spawn_group: String = "default"
```

---

## Effect Scripts

### `damage_number.gd`
**Location:** `game/Scripts/damage_number.gd`  
**Extends:** `Node2D`  
**Function:** Floating damage number popup with color coding and pop + fade animation.

```gdscript
extends Node2D

@export var normal_color: Color = Color.WHITE
@export var crit_color: Color = Color(1.0, 1.0, 0.2) # yellow-ish
@export var kill_color: Color = Color(1.0, 0.201, 0.059, 1.0) # red-ish

@export var damage: int = 0
@export var is_crit: bool = false
var is_killing_blow: bool = false

@onready var label: RichTextLabel = $Label

const HOLD_TIME := 0.22
const FADE_TIME := 0.14
const TOTAL_TIME := HOLD_TIME + FADE_TIME

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
	
	# Apply small random offset
	global_position += Vector2(
		randf_range(-5.0, 5.0),
		randf_range(-3.0, 3.0)
	)
	
	# Set initial scale smaller than normal
	var base_scale: float = 0.7
	
	# Apply crit/kill scale multiplier (multiply base scale)
	if is_killing_blow or is_crit:
		base_scale *= 1.5
	
	scale = Vector2(base_scale, base_scale)
	
	# Ensure starts fully visible
	modulate.a = 1.0
	
	# Create tween for pop + fade animation
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Pop: scale up to 1.15, then ease back to 1.0
	var final_scale: float = 1.0
	if is_killing_blow or is_crit:
		final_scale = 2
	
	tween.tween_property(self, "scale", Vector2(final_scale * 1.15, final_scale * 1.15), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(final_scale, final_scale), 0.10).set_delay(0.08)
	
	# Drift for total time
	tween.tween_property(self, "global_position:y", global_position.y - 8.0, TOTAL_TIME)
	
	# Fade starts after hold
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME).set_delay(HOLD_TIME)
	
	tween.set_parallel(false)
	tween.tween_interval(TOTAL_TIME)
	tween.tween_callback(queue_free)
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
**Function:** Coin pickup system with arc-to-ground landing using ground detection, then hover/bob animation (motion simulated; no physics body).

```gdscript
extends Area2D

@export var value: float = 1.0

# Ground detection / arc-to-ground constants
const GROUND_MASK := 1 << 0
const RAY_LENGTH := 2000.0

const TRAVEL_TIME := 0.6
const MIN_DX := 14.0
const MAX_DX := 34.0
const ARC_HEIGHT := 22.0

const GROUND_CLEARANCE := 8.0  # IMPORTANT: bigger than before to avoid clipping
const HOVER_HEIGHT := 2.0
const HOVER_SPEED := 4.0

@onready var sprite: Node2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $PickupAudio

var _picked_up := false
var _t := 0.0
var _start_pos: Vector2
var _landing_pos: Vector2
var _landed := false
var _bob_time := 0.0

func _find_ground_y(from_pos: Vector2) -> float:
	var space := get_world_2d().direct_space_state
	var to_pos := from_pos + Vector2(0, RAY_LENGTH)

	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = GROUND_MASK
	query.hit_from_inside = true

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return from_pos.y
	return float(hit.position.y)

func _ready() -> void:
	# Connect to body_entered so we can detect the player
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_start_pos = global_position

	var dir_sign: float = 1.0 if randf() > 0.5 else -1.0
	var dx: float = randf_range(MIN_DX, MAX_DX) * dir_sign

	# Find ground at landing X, not at spawn X
	var ground_y: float = _find_ground_y(_start_pos + Vector2(dx, 0))
	_landing_pos = Vector2(_start_pos.x + dx, ground_y - GROUND_CLEARANCE)

	# Animate _t from 0.0 to 1.0 over TRAVEL_TIME using a Tween
	_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_t", 1.0, TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_arc_finished)

func _process(delta: float) -> void:
	if _picked_up:
		return

	if not _landed:
		var x: float = lerp(_start_pos.x, _landing_pos.x, _t)
		var y: float = lerp(_start_pos.y, _landing_pos.y, _t) - sin(_t * PI) * ARC_HEIGHT
		global_position = Vector2(x, y)
	else:
		_bob_time += delta * HOVER_SPEED
		global_position = _landing_pos + Vector2(0.0, sin(_bob_time) * HOVER_HEIGHT)

func _on_arc_finished() -> void:
	_landed = true
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

## Core System Scripts

### `game_manager.gd`
**Location:** `game/Scripts/game_manager.gd`  
**Extends:** `Node`  
**Function:** Centralized autoload singleton for currency management, XP/level system, permanent progression (stash/loadout), item purchases, scene transitions, and debug input blocking.

```gdscript
extends Node

const TAVERN_SCENE_PATH := "res://Scenes/Tavern.tscn"
const RUN_SCENE_PATH := "res://Scenes/level_01.tscn"
const GOLD_TO_ESSENCE_RATE: float = 100.0

signal gold_run_changed(current_gold: float)
signal essence_changed(current_essence: int)
signal xp_changed(current_xp: int, current_level: int)
signal item_unlocked(item_id: String, category: String)

# Run-only currency: reset when a new run starts or on death
var gold_run: float = 0.0

# Permanent currency: kept between runs
var essence_total: int = 0

# Permanent inventory (Stash)
var stash_weapons: Array[String] = []
var stash_throwables: Array[String] = []
var stash_gear_feet: Array[String] = []
var stash_gear_back: Array[String] = []
var stash_gear_head: Array[String] = []

# Loadout (per-run equipment)
var loadout_primary_weapon: String = ""
var loadout_secondary_weapon: String = ""
var loadout_throwable: String = ""
var loadout_gear_feet: String = ""
var loadout_gear_back: String = ""
var loadout_gear_head: String = ""

# XP / Level system
var xp: int = 0
var level: int = 1

# When true, gameplay input (movement, abilities, etc.) should be blocked.
var debug_input_blocked: bool = false

@export var base_xp_to_level: int = 100
@export var xp_growth_factor: float = 1.4

# -------------------------------------------------------------------
# TESTING OVERRIDES — exported values (ignored in final build)
# -------------------------------------------------------------------
@export var start_level: int = 1
@export var start_xp: int = 0
@export var start_essence: int = 0
@export var start_gold_run: float = 0.0

func _ready() -> void:
	# Apply testing overrides
	level = max(1, start_level)
	xp = max(0, start_xp)
	essence_total = max(0, start_essence)
	gold_run = max(0.0, start_gold_run)
	
	# Emit signals so UI stays in sync
	emit_signal("xp_changed", xp, level)
	emit_signal("essence_changed", essence_total)
	emit_signal("gold_run_changed", gold_run)
	
	_initialize_default_stash_and_loadout()
	
	if OS.is_debug_build():
		var console_scene: PackedScene = load("res://Scenes/DebugConsole.tscn")
		if console_scene:
			var console_instance := console_scene.instantiate()
			get_tree().root.call_deferred("add_child", console_instance)

# --------------------------
# Run currency (Gold)
# --------------------------

func reset_run_state() -> void:
	# Reset all run-only data here
	gold_run = 0.0
	emit_signal("gold_run_changed", gold_run)

func add_gold_run(amount: float) -> void:
	if amount == 0.0:
		return
	gold_run += amount
	emit_signal("gold_run_changed", gold_run)
	print("GOLD (run): +", amount, " -> ", gold_run)

func spend_gold_run(amount: float) -> bool:
	if amount <= 0.0:
		return true  # spending 0 is fine
	if gold_run < amount:
		return false
	gold_run -= amount
	emit_signal("gold_run_changed", gold_run)
	print("GOLD (run): -", amount, " -> ", gold_run)
	return true

# --------------------------
# Permanent currency (Essence)
# --------------------------

func add_essence(amount: int) -> void:
	if amount <= 0:
		return
	essence_total += amount
	emit_signal("essence_changed", essence_total)
	print("ESSENCE: +", amount, " -> ", essence_total)

func spend_essence(amount: int) -> bool:
	if amount <= 0:
		return true
	if essence_total < amount:
		return false
	essence_total -= amount
	emit_signal("essence_changed", essence_total)
	print("ESSENCE: -", amount, " -> ", essence_total)
	return true

# --------------------------
# XP / Level
# --------------------------

func get_xp_required_for_next_level() -> int:
	# Basic exponential growth: 100, 140, 196, ...
	var required := base_xp_to_level * pow(xp_growth_factor, level - 1)
	return int(round(required))

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var leveled_up: bool = false
	while true:
		var needed := get_xp_required_for_next_level()
		if xp < needed:
			break
		xp -= needed
		level += 1
		leveled_up = true
	emit_signal("xp_changed", xp, level)
	if leveled_up:
		print("LEVEL UP! Now level ", level)

func go_to_tavern() -> void:
	var scene := load(TAVERN_SCENE_PATH) as PackedScene
	if scene:
		get_tree().call_deferred("change_scene_to_packed", scene)
	else:
		push_warning("GameManager: TAVERN_SCENE_PATH is invalid: %s" % TAVERN_SCENE_PATH)

func start_new_run() -> void:
	var scene := load(RUN_SCENE_PATH) as PackedScene
	if scene:
		get_tree().call_deferred("change_scene_to_packed", scene)
	else:
		push_warning("GameManager: RUN_SCENE_PATH is invalid: %s" % RUN_SCENE_PATH)

func on_player_died() -> void:
	# Called when the player dies.
	# Convert gold to essence before returning to tavern.
	finalize_run_and_convert_gold()
	print("GameManager: on_player_died() called -> going to Tavern")
	go_to_tavern()

# --------------------------
# Stash and Loadout System
# --------------------------

func owns_item(category: String, id: String) -> bool:
	match category:
		"weapon":
			return id in stash_weapons
		"throwable":
			return id in stash_throwables
		"gear_feet":
			return id in stash_gear_feet
		"gear_back":
			return id in stash_gear_back
		"gear_head":
			return id in stash_gear_head
		_:
			return false

func unlock_item(category: String, id: String) -> void:
	if owns_item(category, id):
		return
	
	match category:
		"weapon":
			stash_weapons.append(id)
		"throwable":
			stash_throwables.append(id)
		"gear_feet":
			stash_gear_feet.append(id)
		"gear_back":
			stash_gear_back.append(id)
		"gear_head":
			stash_gear_head.append(id)

func set_loadout_item(slot: String, id: String) -> bool:
	# Safety: cannot equip items not in stash
	var category := ""
	match slot:
		"primary", "secondary":
			category = "weapon"
		"throwable":
			category = "throwable"
		"gear_feet":
			category = "gear_feet"
		"gear_back":
			category = "gear_back"
		"gear_head":
			category = "gear_head"
		_:
			return false
	
	if not owns_item(category, id):
		return false
	
	match slot:
		"primary":
			loadout_primary_weapon = id
		"secondary":
			loadout_secondary_weapon = id
		"throwable":
			loadout_throwable = id
		"gear_feet":
			loadout_gear_feet = id
		"gear_back":
			loadout_gear_back = id
		"gear_head":
			loadout_gear_head = id
	
	return true

func set_debug_input_blocked(blocked: bool) -> void:
	debug_input_blocked = blocked

func is_debug_input_blocked() -> bool:
	return debug_input_blocked

func finalize_run_and_convert_gold() -> void:
	var essence_gain: int = int(floor(gold_run / GOLD_TO_ESSENCE_RATE))
	if essence_gain > 0:
		essence_total += essence_gain
		emit_signal("essence_changed", essence_total)
	
	gold_run = 0.0
	emit_signal("gold_run_changed", gold_run)
	reset_run_state()

# -------------------------------------------------------------------
# Item purchase helpers (shop uses Essence + level + stash)
# -------------------------------------------------------------------

func _build_purchase_result(success: bool, reason: String, item: Dictionary) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"item": item,
	}

func can_purchase_item(item_id: String) -> Dictionary:
	# Validate that the item exists in the ItemDatabase
	if not ItemDatabase.item_exists(item_id):
		return _build_purchase_result(false, "unknown_item", {})

	var item: Dictionary = ItemDatabase.get_item(item_id)

	# Category is required so we know which stash bucket it belongs to
	var category: String = item.get("category", "")
	if category == "":
		return _build_purchase_result(false, "missing_category", item)

	# If the player already owns this item in their stash, block purchase
	if owns_item(category, item_id):
		return _build_purchase_result(false, "already_owned", item)

	# Level gating
	var required_level: int = int(item.get("required_level", 1))
	if level < required_level:
		return _build_purchase_result(false, "level_too_low", item)

	# Essence cost check
	var cost: int = int(item.get("essence_cost", 0))
	if cost < 0:
		cost = 0

	if essence_total < cost:
		return _build_purchase_result(false, "insufficient_essence", item)

	# If we get here, everything is OK to purchase
	return _build_purchase_result(true, "ok", item)

func purchase_item_with_essence(item_id: String) -> Dictionary:
	# First run validation without mutating any state
	var check := can_purchase_item(item_id)

	if not check.get("success", false):
		# Just forward the failure information
		return check

	var item: Dictionary = check.get("item", {})
	var category: String = item.get("category", "")
	var cost: int = int(item.get("essence_cost", 0))
	if cost < 0:
		cost = 0

	# Spend Essence (double-checking we actually can)
	var spent := spend_essence(cost)
	if not spent:
		# In theory this shouldn't happen because can_purchase_item checks first,
		# but we guard against race conditions / future changes.
		return _build_purchase_result(false, "insufficient_essence", item)

	# Unlock in stash using existing helper
	unlock_item(category, item_id)

	# Emit signal so UI / shop / stash screens can react
	item_unlocked.emit(item_id, category)

	return _build_purchase_result(true, "purchased", item)

# --------------------------
# Initialization
# --------------------------

func _initialize_default_stash_and_loadout() -> void:
	# Sync stash with default items from ItemDatabase (autoload)
	var starter_items: Array = ItemDatabase.get_items_unlocked_by_default()
	
	for item in starter_items:
		var id: String = item.get("id", "")
		var category: String = item.get("category", "")
		
		if id != "" and category != "":
			if not owns_item(category, id):
				unlock_item(category, id)
	
	# Initialize loadout with defaults if empty
	# Primary weapon
	if loadout_primary_weapon == "" or not ItemDatabase.item_exists(loadout_primary_weapon):
		if ItemDatabase.item_exists("weapon_pistol"):
			loadout_primary_weapon = "weapon_pistol"
	
	# Secondary weapon and throwable - leave empty for now
	# (loadout_secondary_weapon and loadout_throwable remain empty)
	
	# Gear slots
	if loadout_gear_feet == "" or not ItemDatabase.item_exists(loadout_gear_feet):
		if ItemDatabase.item_exists("gear_feet_boots_basic"):
			loadout_gear_feet = "gear_feet_boots_basic"
	
	if loadout_gear_back == "" or not ItemDatabase.item_exists(loadout_gear_back):
		if ItemDatabase.item_exists("gear_back_harness_basic"):
			loadout_gear_back = "gear_back_harness_basic"
	
	if loadout_gear_head == "" or not ItemDatabase.item_exists(loadout_gear_head):
		if ItemDatabase.item_exists("gear_head_cap_basic"):
			loadout_gear_head = "gear_head_cap_basic"
```

---

## Progression System Scripts

### `item_database.gd`
**Location:** `game/Scripts/item_database.gd`  
**Extends:** `Node`  
**Function:** Centralized item metadata database autoload. Defines all game items (weapons, throwables, gear) with their properties.

```gdscript
extends Node

# This script is used as an Autoload singleton named "ItemDatabase"

const CATEGORY_WEAPON := "weapon"
const CATEGORY_THROWABLE := "throwable"
const CATEGORY_GEAR_FEET := "gear_feet"
const CATEGORY_GEAR_BACK := "gear_back"
const CATEGORY_GEAR_HEAD := "gear_head"

# Items are deliberately simple for now. We only have a pistol implemented,
# but we define a few future items so the systems are ready.
#
# Fields:
# - id: string key
# - category: one of the CATEGORY_* constants above
# - display_name: UI name
# - description: flavour text
# - essence_cost: cost in permanent Essence
# - required_level: minimum player level to unlock
# - slot: which loadout slot it conceptually occupies (primary, secondary, throwable, gear_feet, gear_back, gear_head)
# - unlocked_by_default: whether the player should start with this item already in their stash
const ITEMS := {
	# Weapons
	"weapon_pistol": {
		"id": "weapon_pistol",
		"category": CATEGORY_WEAPON,
		"display_name": "Standard Pistol",
		"description": "Reliable sidearm with decent damage and crit chance.",
		"essence_cost": 0,
		"required_level": 1,
		"slot": "primary",
		"unlocked_by_default": true,
	},

	# Throwables (placeholder – logic will come later)
	"throwable_grenade_basic": {
		"id": "throwable_grenade_basic",
		"category": CATEGORY_THROWABLE,
		"display_name": "Basic Grenade",
		"description": "Simple explosive. Placeholder stats for now.",
		"essence_cost": 5,
		"required_level": 2,
		"slot": "throwable",
		"unlocked_by_default": false,
	},

	# Gear – Feet
	"gear_feet_boots_basic": {
		"id": "gear_feet_boots_basic",
		"category": CATEGORY_GEAR_FEET,
		"display_name": "Worn Boots",
		"description": "Basic boots. Future home for movement buffs.",
		"essence_cost": 3,
		"required_level": 1,
		"slot": "gear_feet",
		"unlocked_by_default": true,
	},

	# Gear – Back (future wings live here)
	"gear_back_harness_basic": {
		"id": "gear_back_harness_basic",
		"category": CATEGORY_GEAR_BACK,
		"display_name": "Simple Harness",
		"description": "Back slot placeholder. Will support wings later.",
		"essence_cost": 4,
		"required_level": 1,
		"slot": "gear_back",
		"unlocked_by_default": false,
	},

	# Gear – Head
	"gear_head_cap_basic": {
		"id": "gear_head_cap_basic",
		"category": CATEGORY_GEAR_HEAD,
		"display_name": "Worn Cap",
		"description": "Basic headgear. Future crit/movement buffs etc.",
		"essence_cost": 3,
		"required_level": 1,
		"slot": "gear_head",
		"unlocked_by_default": false,
	},
}

func item_exists(id: String) -> bool:
	return id in ITEMS

func get_item(id: String) -> Dictionary:
	if id in ITEMS:
		return ITEMS[id]
	return {}

func get_all_items() -> Array:
	var out: Array = []
	for item in ITEMS.values():
		out.append(item)
	return out

func get_items_for_category(category: String) -> Array:
	var out: Array = []
	for item in ITEMS.values():
		if item.get("category", "") == category:
			out.append(item)
	return out

func get_items_unlocked_by_default() -> Array:
	var out: Array = []
	for item in ITEMS.values():
		if item.get("unlocked_by_default", false):
			out.append(item)
	return out
```

### `shop_ui.gd`
**Location:** `game/Scripts/shop_ui.gd`  
**Extends:** `CanvasLayer`  
**Function:** Shop UI manager for purchasing items with Essence currency and level gating.

```gdscript
extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var essence_label: Label = $Panel/Margin/VBox/EssenceLabel
@onready var item_list: ItemList = $Panel/Margin/VBox/ItemList
@onready var details_label: Label = $Panel/Margin/VBox/DetailsLabel
@onready var buy_button: Button = $Panel/Margin/VBox/Buttons/BuyButton
@onready var close_button: Button = $Panel/Margin/VBox/Buttons/CloseButton

var _item_ids: Array[String] = []
var _current_index: int = -1
var _player: Node = null

func _ready() -> void:
	visible = false
	panel.visible = true

	title_label.text = "Bartender's Shop"

	# Connect UI signals
	if not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not item_list.item_selected.is_connected(_on_item_selected):
		item_list.item_selected.connect(_on_item_selected)

	# Connect to GameManager signals (autoload)
	var gm = GameManager
	if gm.has_signal("essence_changed") and not gm.essence_changed.is_connected(_on_essence_changed):
		gm.essence_changed.connect(_on_essence_changed)
	if gm.has_signal("item_unlocked") and not gm.item_unlocked.is_connected(_on_item_unlocked):
		gm.item_unlocked.connect(_on_item_unlocked)

	# Initialize essence label from current state if fields exist
	if "essence_total" in gm:
		_on_essence_changed(gm.essence_total)

	_refresh_items()

func _apply_mouse_mode_for_ui(opening: bool) -> void:
	# Find and cache the player in the "player" group
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
		else:
			_player = null

	# Prefer the player's helper, but fall back to direct Input calls
	if _player != null and _player.has_method("set_ui_mouse_mode"):
		_player.set_ui_mouse_mode(opening)
	else:
		if opening:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func open() -> void:
	visible = true
	_apply_mouse_mode_for_ui(true)

	# Refresh list in case state changed while closed
	_refresh_items()

	if item_list.item_count > 0:
		item_list.select(0)
		_on_item_selected(0)

	# Optional: give focus to ItemList for keyboard navigation
	item_list.grab_focus()

func close() -> void:
	visible = false
	_apply_mouse_mode_for_ui(false)

func _on_close_pressed() -> void:
	close()

func _on_essence_changed(current_essence: int) -> void:
	essence_label.text = "Essence: %d" % current_essence

func _on_item_unlocked(_item_id: String, _category: String) -> void:
	# Simply refresh the list when something is unlocked
	_refresh_items()

func _refresh_items() -> void:
	var gm = GameManager
	var items: Array = ItemDatabase.get_all_items()

	_item_ids.clear()
	item_list.clear()

	# Stable sort: by required_level ascending, then by name
	items.sort_custom(func(a, b):
		var lvl_a: int = int(a.get("required_level", 1))
		var lvl_b: int = int(b.get("required_level", 1))
		if lvl_a == lvl_b:
			var name_a: String = str(a.get("display_name", a.get("id", "")))
			var name_b: String = str(b.get("display_name", b.get("id", "")))
			return name_a < name_b
		return lvl_a < lvl_b
	)

	for item in items:
		var id: String = item.get("id", "")
		if id == "":
			continue

		var item_name: String = str(item.get("display_name", id))
		var category: String = str(item.get("category", ""))
		var required_level: int = int(item.get("required_level", 1))
		var cost: int = int(item.get("essence_cost", 0))

		var owned: bool = gm.owns_item(category, id)
		var player_level: int = int(gm.level) if "level" in gm else 1
		var essence: int = int(gm.essence_total) if "essence_total" in gm else 0

		var status: String

		if owned:
			status = "[OWNED]"
		elif player_level < required_level:
			status = "[LOCKED Lv %d]" % required_level
		elif essence < cost:
			status = "[NEEDS %d]" % cost
		else:
			status = "[BUY]"

		var display_text := "%s %s  -  %d Essence (Lv %d)" % [status, item_name, cost, required_level]
		item_list.add_item(display_text)
		_item_ids.append(id)

	_current_index = -1
	_update_buy_button_state()

func _on_item_selected(index: int) -> void:
	_current_index = index
	_update_details_label()
	_update_buy_button_state()

func _update_details_label() -> void:
	details_label.text = ""

	if _current_index < 0 or _current_index >= _item_ids.size():
		return

	var id: String = _item_ids[_current_index]
	var item: Dictionary = ItemDatabase.get_item(id)

	var item_name: String = str(item.get("display_name", id))
	var description: String = str(item.get("description", ""))
	var required_level: int = int(item.get("required_level", 1))
	var cost: int = int(item.get("essence_cost", 0))

	details_label.text = "%s\n\nCost: %d Essence\nRequired Level: %d\n\n%s" % [
		item_name,
		cost,
		required_level,
		description
	]

func _update_buy_button_state() -> void:
	if _current_index < 0 or _current_index >= _item_ids.size():
		buy_button.disabled = true
		return

	var gm = GameManager
	var id: String = _item_ids[_current_index]
	var item: Dictionary = ItemDatabase.get_item(id)
	var category: String = str(item.get("category", ""))

	var required_level: int = int(item.get("required_level", 1))
	var cost: int = int(item.get("essence_cost", 0))

	var owned: bool = gm.owns_item(category, id)
	var player_level: int = int(gm.level) if "level" in gm else 1
	var essence: int = int(gm.essence_total) if "essence_total" in gm else 0

	var can_buy: bool = (not owned) and (player_level >= required_level) and (essence >= cost)
	buy_button.disabled = not can_buy

func _on_buy_pressed() -> void:
	if _current_index < 0 or _current_index >= _item_ids.size():
		return

	var id: String = _item_ids[_current_index]

	# Attempt purchase. We don't rely on return shape; we just refresh UI afterward.
	GameManager.purchase_item_with_essence(id)

	_refresh_items()
	_update_details_label()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
```

### `debug_console.gd`
**Location:** `game/Scripts/debug_console.gd`  
**Extends:** `CanvasLayer`  
**Function:** Debug console with command system for testing and modifying game state (debug builds only).

```gdscript
extends CanvasLayer

@onready var log_label: RichTextLabel = $Panel/Margin/VBox/Log
@onready var input_line: LineEdit = $Panel/Margin/VBox/Input

var _gm: Node = null

func _ready() -> void:
	# Remove the console entirely in non-debug builds
	if not OS.is_debug_build():
		queue_free()
		return

	_gm = GameManager
	visible = false

	# Basic setup
	log_label.clear()
	log_label.mouse_filter = Control.MOUSE_FILTER_STOP

	# Click in the log focuses the input
	if not log_label.gui_input.is_connected(_on_log_gui_input):
		log_label.gui_input.connect(_on_log_gui_input)

	# Enter submits commands
	if not input_line.text_submitted.is_connected(_on_input_submitted):
		input_line.text_submitted.connect(_on_input_submitted)

	# ESC while typing closes the console
	if not input_line.gui_input.is_connected(_on_input_gui_input):
		input_line.gui_input.connect(_on_input_gui_input)

	print_line("Debug console ready. Press F2 to toggle. Type 'help' for commands.")

func _toggle() -> void:
	visible = not visible

	# Block/unblock gameplay input while console is visible
	if _gm == null:
		_gm = GameManager
	if _gm != null and _gm.has_method("set_debug_input_blocked"):
		_gm.set_debug_input_blocked(visible)

	if visible:
		# Reset and focus input when opening
		input_line.text = ""
		input_line.grab_focus()
		input_line.caret_column = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_toggle()
			get_viewport().set_input_as_handled()
			return

		if not visible:
			return

		if event.keycode == KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()
			return

func _on_log_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		input_line.grab_focus()
		input_line.caret_column = input_line.text.length()

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()

func _on_input_submitted(text: String) -> void:
	var cmd_line := text.strip_edges()

	if cmd_line.is_empty():
		# Keep console open and ready even on empty submit
		input_line.text = ""
		input_line.grab_focus()
		input_line.caret_column = 0
		return

	print_line("> " + cmd_line)
	input_line.text = ""

	_execute_command(cmd_line)

	# Best-effort: keep input ready for the next command
	input_line.grab_focus()
	input_line.caret_column = 0

func print_line(text: String) -> void:
	if log_label != null:
		log_label.append_text(text + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)
	print("[DebugConsole] " + text)

# -------------------------------------------------------------------
# Command parsing
# -------------------------------------------------------------------

func _execute_command(cmd_line: String) -> void:
	var parts: Array = cmd_line.split(" ", false)
	if parts.is_empty():
		return

	var cmd: String = parts[0].to_lower()

	match cmd:
		"help":
			_print_help()
		"give_gold":
			_cmd_give_gold(parts)
		"give_essence":
			_cmd_give_essence(parts)
		"set_level":
			_cmd_set_level(parts)
		"set_xp":
			_cmd_set_xp(parts)
		"unlock_all":
			_cmd_unlock_all()
		"spawn":
			_cmd_spawn(parts)
		"godmode":
			_cmd_godmode()
		"give", "set":
			_cmd_friendly_alias(parts)
		_:
			print_line("Error: Unknown command. Type 'help' for commands.")

func _print_help() -> void:
	print_line("Available commands:")
	print_line("  help")
	print_line("  give_gold <amount>")
	print_line("  give_essence <amount>")
	print_line("  set_xp <amount>")
	print_line("  unlock_all")
	print_line("  spawn <count> basicenemy [left|right|points]")
	print_line("  godmode")
	print_line("")
	print_line("Aliases:")
	print_line("  give gold <amount>")
	print_line("  give essence <amount>")
	print_line("  set level <level>")
	print_line("  set xp <amount>")

func _parse_int(parts: Array, index: int, default_value: int) -> int:
	if index >= parts.size():
		return default_value
	var s: String = str(parts[index])
	if not s.is_valid_int():
		return default_value
	return int(s)

func _parse_float(parts: Array, index: int, default_value: float) -> float:
	if index >= parts.size():
		return default_value
	var s: String = str(parts[index])
	if not s.is_valid_float():
		return default_value
	return float(s)

# -------------------------------------------------------------------
# Individual commands
# -------------------------------------------------------------------

func _cmd_give_gold(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var amount: float = _parse_float(parts, 1, 0.0)
	if amount <= 0.0:
		print_line("Usage: give_gold <amount>")
		return

	if not gm.has_method("add_gold_run"):
		print_line("Error: GameManager.add_gold_run() not found. Command failed.")
		return

	gm.add_gold_run(amount)
	print_line("Success: Gave gold_run: %.2f" % amount)

func _cmd_give_essence(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var amount: int = _parse_int(parts, 1, 0)
	if amount <= 0:
		print_line("Usage: give_essence <amount>")
		return

	if not gm.has_method("add_essence"):
		print_line("Error: GameManager.add_essence() not found. Command failed.")
		return

	gm.add_essence(amount)
	print_line("Success: Gave essence: %d" % amount)

func _cmd_set_level(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var lvl: int = _parse_int(parts, 1, -1)
	if lvl <= 0:
		print_line("Usage: set_level <level>")
		return

	lvl = max(1, lvl)
	gm.level = lvl
	if gm.has_signal("xp_changed"):
		gm.xp_changed.emit(gm.xp, gm.level)

	print_line("Success: Set level to %d" % lvl)

func _cmd_set_xp(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var amount: int = _parse_int(parts, 1, -1)
	if amount < 0:
		print_line("Usage: set_xp <amount>")
		return

	gm.xp = amount
	if gm.has_signal("xp_changed"):
		gm.xp_changed.emit(gm.xp, gm.level)

	print_line("Success: Set XP to %d" % amount)

func _cmd_unlock_all() -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var items: Array = ItemDatabase.get_all_items()
	var count := 0

	for item in items:
		var id: String = item.get("id", "")
		var category: String = item.get("category", "")
		if id == "" or category == "":
			continue

		if gm.has_method("owns_item") and gm.owns_item(category, id):
			continue

		if gm.has_method("unlock_item"):
			gm.unlock_item(category, id)
			count += 1
		if gm.has_signal("item_unlocked"):
			gm.item_unlocked.emit(id, category)

	print_line("Success: Unlocked %d items." % count)

# -------------------------------------------------------------------
# Helper functions for spawn command
# -------------------------------------------------------------------

const ENEMY_BASIC_SCENE_PATH := "res://Scenes/EnemyBasic.tscn"

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var p := players[0]
	return p as Node2D

func _get_wave_spawn_points() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var scene := get_tree().current_scene
	if scene == null:
		return result
	if not scene.has_node("WaveSpawnPoints"):
		return result

	var parent := scene.get_node("WaveSpawnPoints")
	for c in parent.get_children():
		if c is Node2D and ("spawn_group" in c):
			result.append(c as Node2D)
	return result

func _spawn_basic_enemy(pos: Vector2, player: Node2D) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false

	var enemy_scene: PackedScene = load(ENEMY_BASIC_SCENE_PATH)
	if enemy_scene == null:
		return false

	var enemy := enemy_scene.instantiate()
	if enemy == null:
		return false

	# Set position
	enemy.global_position = pos

	# Set player ref (enemy.gd uses exported var player)
	if player != null and ("player" in enemy):
		enemy.player = player

	scene.add_child(enemy)
	return true

func _cmd_spawn(parts: Array) -> void:
	# Usage: spawn <count> basicenemy [left|right|points]
	if parts.size() < 3:
		print_line("Usage: spawn <count> basicenemy [left|right|points]")
		return

	var count := _parse_int(parts, 1, 0)
	if count <= 0:
		print_line("Usage: spawn <count> basicenemy [left|right|points]")
		return
	count = clamp(count, 1, 200)

	var enemy_type := str(parts[2]).to_lower()
	if enemy_type != "basicenemy":
		print_line("Unknown enemy type: %s" % enemy_type)
		print_line("Usage: spawn <count> basicenemy [left|right|points]")
		return

	var mode := "near"
	if parts.size() >= 4:
		mode = str(parts[3]).to_lower()
		if mode not in ["left", "right", "points"]:
			print_line("Usage: spawn <count> basicenemy [left|right|points]")
			return

	var player := _get_player()
	if player == null:
		print_line("Error: Player not found in group 'player'")
		return

	var spawned := 0

	if mode == "points":
		var points := _get_wave_spawn_points()
		if points.is_empty():
			print_line("Warning: No WaveSpawnPoints found. Falling back to near-player spawn.")
			mode = "near"
		else:
			for i in range(count):
				var sp := points[i % points.size()]
				var jitter_x := randf_range(-8.0, 8.0)
				var pos := sp.global_position + Vector2(jitter_x, -16.0)
				if _spawn_basic_enemy(pos, player):
					spawned += 1
			print_line("Success: Spawned %d basicenemy at spawn points." % spawned)
			return

	# near-player spawn (default/left/right)
	var spacing := 16.0
	for i in range(count):
		var offset_x := 0.0

		if mode == "left":
			offset_x = -float(i + 1) * spacing
		elif mode == "right":
			offset_x = float(i + 1) * spacing
		else:
			# alternate sides: +, -, +, -, ...
			var side := 1.0 if (i % 2 == 0) else -1.0
			offset_x = side * (float(i / 2) + 1.0) * spacing

		offset_x += randf_range(-6.0, 6.0)
		var pos := Vector2(player.global_position.x + offset_x, player.global_position.y)

		if _spawn_basic_enemy(pos, player):
			spawned += 1

	print_line("Success: Spawned %d basicenemy (%s)." % [spawned, mode])

func _cmd_godmode() -> void:
	var player := _get_player()
	if player == null:
		print_line("Error: Player not found")
		return

	if not ("godmode_enabled" in player):
		print_line("Error: Player does not support godmode")
		return

	player.godmode_enabled = not player.godmode_enabled
	print_line("Godmode: %s" % ("ON" if player.godmode_enabled else "OFF"))

func _cmd_friendly_alias(parts: Array) -> void:
	if parts.is_empty():
		return

	var root: String = parts[0].to_lower()

	if root == "give":
		if parts.size() < 3:
			print_line("Usage: give gold <amount> | give essence <amount>")
			return
		var target: String = parts[1].to_lower()
		match target:
			"gold":
				_cmd_give_gold(["give_gold", parts[2]])
			"essence":
				_cmd_give_essence(["give_essence", parts[2]])
			_:
				print_line("Error: Unknown give target. Use 'gold' or 'essence'.")
	elif root == "set":
		if parts.size() < 3:
			print_line("Usage: set level <value> | set xp <value>")
			return
		var target: String = parts[1].to_lower()
		match target:
			"level":
				_cmd_set_level(["set_level", parts[2]])
			"xp":
				_cmd_set_xp(["set_xp", parts[2]])
			_:
				print_line("Error: Unknown set target. Use 'level' or 'xp'.")
```

---

## Tavern Scripts

### `tavern_bartender.gd`
**Location:** `game/Scripts/tavern_bartender.gd`  
**Extends:** `Node2D`  
**Function:** Bartender interaction script that opens the shop UI when the player interacts.

```gdscript
extends Node2D

signal interacted(player: Node)

@export var shop_ui_path: NodePath

@onready var area: Area2D = $InteractionArea

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: Node = null
var _shop_ui: Node = null

func _ready() -> void:
	# Ensure prompt starts hidden
	if prompt_label:
		prompt_label.visible = false
	
	# Connect area signals
	if area:
		if not area.body_entered.is_connected(_on_area_body_entered):
			area.body_entered.connect(_on_area_body_entered)
		if not area.body_exited.is_connected(_on_area_body_exited):
			area.body_exited.connect(_on_area_body_exited)
	
	# Resolve shop UI reference
	if shop_ui_path != NodePath() and has_node(shop_ui_path):
		_shop_ui = get_node(shop_ui_path)
	else:
		_shop_ui = null

func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("interact"):
		emit_signal("interacted", _player_in_range)
		print("Bartender: interacted with by ", _player_in_range.name)
		
		if _shop_ui != null and _shop_ui.has_method("open"):
			_shop_ui.open()

func _on_area_body_entered(body: Node) -> void:
	var target := body
	
	# Handle cases where colliders are child nodes of the player
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player"):
		_player_in_range = target
		if prompt_label:
			prompt_label.visible = true

func _on_area_body_exited(body: Node) -> void:
	var target := body
	
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false
```

### `tavern_run_door.gd`
**Location:** `game/Scripts/tavern_run_door.gd`  
**Extends:** `Node2D`  
**Function:** Run door interaction script that starts a new run when the player interacts.

```gdscript
extends Node2D

signal door_used(player: Node)

@onready var area: Area2D = $InteractionArea

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: Node = null

func _ready() -> void:
	# Ensure prompt starts hidden
	if prompt_label:
		prompt_label.visible = false
	
	# Connect area signals
	if area:
		if not area.body_entered.is_connected(_on_area_body_entered):
			area.body_entered.connect(_on_area_body_entered)
		if not area.body_exited.is_connected(_on_area_body_exited):
			area.body_exited.connect(_on_area_body_exited)

func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("interact"):
		emit_signal("door_used", _player_in_range)
		print("RunDoor: door used by ", _player_in_range.name)

		# Ask GameManager to start a new run (load the run scene)
		if GameManager != null and GameManager.has_method("start_new_run"):
			GameManager.start_new_run()
		else:
			push_warning("RunDoor: GameManager autoload not available; cannot start new run.")

func _on_area_body_entered(body: Node) -> void:
	var target := body
	
	# Handle cases where colliders are child nodes of the player
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player"):
		_player_in_range = target
		if prompt_label:
			prompt_label.visible = true

func _on_area_body_exited(body: Node) -> void:
	var target := body
	
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false
```

---

## Summary

This document contains all scripts in the Shoot To Kill project, organized by category:

- **Core System Scripts**: GameManager autoload for currency, XP, progression, purchases, scene management, and debug input blocking
- **Player Scripts**: Player controller with movement, health, shooting, weapon switching (primary/secondary), animation, aiming, two-handed weapon support, gold currency, debug input blocking, and UI mouse mode
- **Enemy Scripts**: Enemy AI with state machine, health, contact damage, flash effects, health bars, loot drops, XP rewards, died signal, set_player method, penetration resistance, and knockback system
- **Weapon Scripts**: Base weapon class (with fire rate, full-auto, spread, hand offsets, two-handed support, bullet penetration, range, speed, and knockback), pistol implementation (semi-auto), assault rifle implementation (full-auto capable), and bullet physics with multi-hit penetration
- **Wave System Scripts**: WaveManager for endless waves with difficulty scaling, and WaveSpawnPoint for spawn point markers
- **UI Scripts**: HUD manager (health, currency, XP, wave display, kill/remaining stats), shop UI, debug console, and crosshair system with outer pulse effect
- **Progression System Scripts**: ItemDatabase for item metadata, ShopUI for purchasing items
- **Tavern Scripts**: Bartender interaction (opens shop) and RunDoor interaction (starts new run)
- **Effect Scripts**: Damage numbers with pop + fade animation, hit impacts, blood effects, and coin pickups
- **Camera Scripts**: Camera shake system

All scripts are current as of the latest project state.

