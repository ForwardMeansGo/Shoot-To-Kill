extends Node2D

@export var player_path: NodePath

@onready var outer_sprite: Sprite2D = $Outer
@onready var dot_sprite: Sprite2D = $Dot

var player: Node = null

func _ready() -> void:
	if player_path != NodePath(""):
		player = get_node(player_path)


func _process(delta: float) -> void:
	# 1) Outer cross follows the mouse (world position)
	var mouse_world: Vector2 = get_global_mouse_position()
	global_position = mouse_world

	# 2) Inner dot placeholder
	if dot_sprite != null:
		# For now, inner dot stays centered. No aim logic at all.
		dot_sprite.position = Vector2.ZERO
