extends Camera2D

var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _original_offset: Vector2

func _ready() -> void:
	_original_offset = offset

func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta

		var t := _shake_time / _shake_duration
		var current_strength := _shake_strength * t

		offset = _original_offset + Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * current_strength

		if _shake_time <= 0.0:
			offset = _original_offset

func start_shake(strength: float = 4.0, duration: float = 0.1) -> void:
	_shake_strength = strength
	_shake_duration = max(duration, 0.0001)
	_shake_time = _shake_duration
