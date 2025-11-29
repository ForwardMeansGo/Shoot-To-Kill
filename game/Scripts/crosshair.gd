extends Node2D

@export var player_path: NodePath
var default_dot_lerp_speed: float = 10.0

@onready var outer_sprite: Sprite2D = $Outer
@onready var dot_sprite: Sprite2D = $Dot

var player: Node = null
var dot_screen_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	if player_path != NodePath(""):
		player = get_node(player_path)
	
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	dot_screen_pos = mouse_screen

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
