extends Area2D

@export var value: float = 1.0

# Arc motion settings
@export var travel_time: float = 0.4          # Time for the full arc
@export var min_horizontal_distance: float = 20.0
@export var max_horizontal_distance: float = 40.0
@export var min_vertical_drop: float = 8.0    # How far down from spawn the coin ends
@export var max_vertical_drop: float = 16.0
@export var arc_height: float = 25.0          # How high the arc goes at the peak

# Idle bobbing after landing
@export var bob_height: float = 2.0
@export var bob_speed: float = 4.0

@onready var sprite: Node2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $PickupAudio

var _picked_up: bool = false

var _t: float = 0.0
var _start_pos: Vector2
var _end_offset: Vector2
var _landing_pos: Vector2
var _landed: bool = false
var _bob_time: float = 0.0

func _ready() -> void:
	# Connect to body_entered so we can detect the player
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Initialize arc parameters
	_start_pos = global_position

	var dir_sign: float = 1.0 if randf() > 0.5 else -1.0
	var horizontal_dist: float = randf_range(min_horizontal_distance, max_horizontal_distance)
	var vertical_drop: float = randf_range(min_vertical_drop, max_vertical_drop)

	_end_offset = Vector2(dir_sign * horizontal_dist, vertical_drop)
	_landing_pos = _start_pos + _end_offset

	# Animate _t from 0.0 to 1.0 over travel_time using a Tween
	_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_t", 1.0, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_arc_finished)

func _process(delta: float) -> void:
	if _picked_up:
		return

	if not _landed:
		# Arc motion: horizontal lerp + vertical sine-based arc
		var x := _start_pos.x + _end_offset.x * _t
		var linear_y := _start_pos.y + _end_offset.y * _t
		var arc_y := -sin(_t * PI) * arc_height
		global_position = Vector2(x, linear_y + arc_y)
	else:
		# Idle bobbing at landing position
		_bob_time += delta * bob_speed
		var bob_offset_y := sin(_bob_time) * bob_height
		global_position = _landing_pos + Vector2(0.0, bob_offset_y)

func _on_arc_finished() -> void:
	_landed = true
	# Snap exactly to landing position at the end of the tween
	global_position = _landing_pos

func _on_body_entered(body: Node) -> void:
	if _picked_up:
		return

	var target: Node = body

	# Mirror the parent-check pattern from enemy.gd
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()

	if target.is_in_group("player") and target.has_method("add_gold"):
		_picked_up = true

		# Give gold to the player
		target.add_gold(value)

		# Disable collision and hide the sprite so it feels instantly collected
		if collision_shape:
			collision_shape.disabled = true
		if sprite:
			sprite.visible = false

		# Play pickup sound if present, then free
		if audio_player and audio_player.stream:
			audio_player.play()
			if not audio_player.finished.is_connected(_on_audio_finished):
				audio_player.finished.connect(_on_audio_finished)
		else:
			queue_free()

func _on_audio_finished() -> void:
	queue_free()
