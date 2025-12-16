extends Area2D

@export var value: float = 1.0

# Ground detection / arc-to-ground constants
const GROUND_MASK := 1 << 0
const RAY_LENGTH := 2000.0

const TRAVEL_TIME := 0.6
const MIN_DX := 14.0
const MAX_DX := 34.0
const ARC_HEIGHT := 22.0

const GROUND_CLEARANCE := 8.0  # IMPORTANT: bigger than before to avoid clipping
const HOVER_HEIGHT := 2.0
const HOVER_SPEED := 4.0

@onready var sprite: Node2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $PickupAudio

var _picked_up := false
var _t := 0.0
var _start_pos: Vector2
var _landing_pos: Vector2
var _landed := false
var _bob_time := 0.0

func _find_ground_y(from_pos: Vector2) -> float:
	var space := get_world_2d().direct_space_state
	var to_pos := from_pos + Vector2(0, RAY_LENGTH)

	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = GROUND_MASK
	query.hit_from_inside = true

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return from_pos.y
	return float(hit.position.y)

func _ready() -> void:
	# Connect to body_entered so we can detect the player
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_start_pos = global_position

	var dir_sign: float = 1.0 if randf() > 0.5 else -1.0
	var dx: float = randf_range(MIN_DX, MAX_DX) * dir_sign

	# Find ground at landing X, not at spawn X
	var ground_y: float = _find_ground_y(_start_pos + Vector2(dx, 0))
	_landing_pos = Vector2(_start_pos.x + dx, ground_y - GROUND_CLEARANCE)

	# Animate _t from 0.0 to 1.0 over TRAVEL_TIME using a Tween
	_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_t", 1.0, TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_arc_finished)

func _process(delta: float) -> void:
	if _picked_up:
		return

	if not _landed:
		var x: float = lerp(_start_pos.x, _landing_pos.x, _t)
		var y: float = lerp(_start_pos.y, _landing_pos.y, _t) - sin(_t * PI) * ARC_HEIGHT
		global_position = Vector2(x, y)
	else:
		_bob_time += delta * HOVER_SPEED
		global_position = _landing_pos + Vector2(0.0, sin(_bob_time) * HOVER_HEIGHT)

func _on_arc_finished() -> void:
	_landed = true
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
			collision_shape.set_deferred("disabled", true)
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
