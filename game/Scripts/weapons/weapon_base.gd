extends Node2D

class_name WeaponBase

signal fired(shake_strength: float, shake_duration: float)

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

# Per-weapon camera shake tuning (override in inspector per weapon)
@export var shake_strength: float = 1.0
@export var shake_duration: float = 0.06

# Weapon damage and crit stats
@export var base_damage_min: float = 8.0
@export var base_damage_max: float = 12.0
@export var crit_chance: float = 0.1  # 10% crit as a default
@export var crit_multiplier: float = 2.0  # 2x damage on crit by default

# Per-weapon aim dot smoothing (gunAimDelay)
@export var aim_dot_lerp_speed: float = 10.0

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
	# Roll damage and crit
	var dmg_info := _roll_damage()
	var dmg_value: int = dmg_info["damage"]
	var is_crit: bool = dmg_info["is_crit"]
	
	var muzzle_global: Vector2 = $Muzzle.global_position
	var dir: Vector2 = (target_global_pos - muzzle_global).normalized()

	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle_global
	bullet.direction = dir
	bullet.rotation = dir.angle()
	
	# Set damage and crit info on bullet
	if "damage" in bullet:
		bullet.damage = dmg_value
	if "is_crit" in bullet:
		bullet.is_crit = is_crit

	get_tree().current_scene.add_child(bullet)

	_play_shot_sound(muzzle_global)

	emit_signal("fired", shake_strength, shake_duration)

func _roll_damage() -> Dictionary:
	var base := randf_range(base_damage_min, base_damage_max)
	var crit := randf() < crit_chance
	if crit:
		base *= crit_multiplier
	return {
		"damage": roundi(base),
		"is_crit": crit
	}

func get_aim_dot_lerp_speed() -> float:
	return aim_dot_lerp_speed

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
