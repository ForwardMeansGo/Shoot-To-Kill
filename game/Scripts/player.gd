extends CharacterBody2D

@onready var weapon_holder: Node2D = $WeaponHolder
@onready var gun: Node2D = $WeaponHolder/Gun
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var cam: Camera2D = $Camera2D

const SPEED: float = 75.0
const JUMP_FORCE: float = -250.0
const GRAVITY: float = 1200.0

var weapon_base_offset: Vector2

func _ready() -> void:
	weapon_base_offset = weapon_holder.position

	# Connect weapon fired signal -> camera shake
	if gun != null and gun.has_signal("fired"):
		gun.connect("fired", Callable(self, "_on_weapon_fired"))

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

func _process(delta: float) -> void:
	if gun == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	gun.aim_at(mouse_pos)

	# Facing based on player center vs mouse X (GLOBAL)
	var facing_left := mouse_pos.x < global_position.x

	if facing_left:
		# Flip body
		sprite_2d.scale.x = -1.0
		# Move gun holder to LEFT side
		weapon_holder.position.x = -abs(weapon_base_offset.x)
	else:
		sprite_2d.scale.x = 1.0
		# Move gun holder to RIGHT side
		weapon_holder.position.x = abs(weapon_base_offset.x)

	# Tell the weapon which way we're facing so it can flip its sprite
	if gun.has_method("set_facing_left"):
		gun.set_facing_left(facing_left)

	# Semi-auto pistol: one shot per click
	if Input.is_action_just_pressed("shoot"):
		if gun.has_method("try_shoot"):
			gun.try_shoot(mouse_pos)

func _on_weapon_fired(strength: float, duration: float) -> void:
	if cam != null:
		cam.start_shake(strength, duration)
