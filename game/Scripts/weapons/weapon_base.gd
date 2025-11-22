extends Node2D

signal fired(shake_strength: float, shake_duration: float)

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

# Per-weapon camera shake tuning (override in inspector per weapon)
@export var shake_strength: float = 1.0
@export var shake_duration: float = 0.06

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $GunAudio

var facing_left: bool = false

func _process(delta: float) -> void:
	# Placeholder for recoil/sway later
	pass

func set_facing_left(is_left: bool) -> void:
	facing_left = is_left
	# Grip always points "down" when on the left side
	sprite.flip_v = is_left

func aim_at(target_global_pos: Vector2) -> void:
	# Rotate the weapon so its +X axis points towards the mouse
	look_at(target_global_pos)

func spawn_bullet(target_global_pos: Vector2) -> void:
	var muzzle_global: Vector2 = $Muzzle.global_position
	var dir: Vector2 = (target_global_pos - muzzle_global).normalized()

	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle_global
	bullet.direction = dir
	bullet.rotation = dir.angle()

	get_tree().current_scene.add_child(bullet)

	_play_shot_sound(muzzle_global)

	emit_signal("fired", shake_strength, shake_duration)

func _play_shot_sound(at_position: Vector2) -> void:
	# If there's no template audio player or stream, bail out
	if audio_player == null or audio_player.stream == null:
		return

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = audio_player.stream
	sfx.global_position = at_position

	# Slight random pitch variation for feel
	var new_pitch: float = randf_range(0.95, 1.05)
	sfx.pitch_scale = new_pitch

	get_tree().current_scene.add_child(sfx)
	sfx.play()

	# Free the one-shot player when the sound is done
	sfx.connect("finished", Callable(sfx, "queue_free"))
