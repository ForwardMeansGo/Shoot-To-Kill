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
