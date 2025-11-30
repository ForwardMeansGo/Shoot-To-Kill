extends CharacterBody2D

@onready var weapon_holder: Node2D = $WeaponHolder
@onready var gun: Node2D = $WeaponHolder/Gun
@onready var arm_sprite: Sprite2D = $WeaponHolder/ArmSprite
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cam: Camera2D = $Camera2D
@onready var crosshair = $"../Crosshair"

const SPEED: float = 75.0
const JUMP_FORCE: float = -275
const GRAVITY: float = 1200.0

@export var max_health: int = 100
@export var invulnerability_time: float = 0.5

signal health_changed(current_health: int, max_health: int)
signal died

var weapon_base_offset: Vector2
var current_health: int
var invuln_timer: float = 0.0
var default_aim_dot_lerp_speed: float = 10.0

func _ready() -> void:
	weapon_base_offset = weapon_holder.position

	# Connect weapon fired signal -> camera shake
	if gun != null and gun.has_signal("fired"):
		gun.connect("fired", Callable(self, "_on_weapon_fired"))
	
	# Initialize health
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

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
	
	if gun == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()

	# Facing based on player center vs mouse X (GLOBAL)
	var facing_left := mouse_pos.x < global_position.x

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

func _update_animation() -> void:
	var is_moving: bool = abs(velocity.x) > 1.0

	if is_on_floor() and is_moving:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
	else:
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")

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
