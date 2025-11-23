extends Node2D

@export var damage: int = 0
@export var lifetime: float = 0.3
@export var float_distance: float = 30.0
@export var arc_distance: float = 20.0
@export var is_crit: bool = false

@onready var label: RichTextLabel = $Label

var t: float = 0.0
var start_pos: Vector2
var direction_sign: float

func _ready() -> void:
	# Set the label text to the damage value
	label.text = str(damage)
	
	# Apply crit styling if this is a crit
	if is_crit:
		# Make crit numbers stand out
		scale = Vector2(1.2, 1.2)
		label.modulate = Color(1.0, 0.9, 0.2)  # a yellowish tone
	
	# Apply a very small random horizontal offset
	var random_x_offset: float = randf_range(-2.0, 2.0)
	global_position.x += random_x_offset
	
	# Store starting position for arc calculation
	start_pos = global_position
	
	# Randomly choose left or right arc direction
	direction_sign = 1.0 if randf() > 0.5 else -1.0
	
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
