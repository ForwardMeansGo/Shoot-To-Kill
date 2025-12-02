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
