extends Node2D

@export var normal_color: Color = Color.WHITE
@export var crit_color: Color = Color(1.0, 1.0, 0.2) # yellow-ish
@export var kill_color: Color = Color(0.692, 0.105, 0.0, 1.0) # red-ish

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
