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

func _input(event: InputEvent) -> void:
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
