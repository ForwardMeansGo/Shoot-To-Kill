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
