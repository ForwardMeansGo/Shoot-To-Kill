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

# Fire control
# fire_rate: shots per second. 0 or less = no internal cooldown.
@export var fire_rate: float = 0.0
# If true, player input can hold the trigger to keep firing.
@export var is_full_auto: bool = false

@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0
# Max random angular deviation for each shot.
# 0 = perfectly accurate. Higher = more inaccurate.

# Per-weapon hand offsets (relative to the arm sprite)
@export var hand_offset_right: Vector2 = Vector2(8, -2)
@export var hand_offset_left: Vector2 = Vector2(8, 2)

# Two-handed weapon support
@export var is_two_handed: bool = false
@export var support_hand_offset_right: Vector2 = Vector2.ZERO
@export var support_hand_offset_left: Vector2 = Vector2.ZERO

# Bullet penetration system
@export var penetration_min: int = 0
@export var penetration_max: int = 0
@export_range(0.0, 1.0, 0.01) var penetration_chance: float = 1.0
@export var penetration_damage_drop_per_pen: float = 0.10 # 10% per extra enemy

# Bullet range
@export var max_range: float = 300

# Bullet speed
@export var bullet_speed: float = 450

# Bullet knockback
@export var bullet_knockback: float = 15
@export var knockback_drop_per_pen: float = 0.4
@export var crit_knockback_multiplier: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer2D = $GunAudio

var facing_left: bool = false
var _time_until_next_shot: float = 0.0

func _process(delta: float) -> void:
	# Cooldown timer for fire rate
	if _time_until_next_shot > 0.0:
		_time_until_next_shot = max(_time_until_next_shot - delta, 0.0)

func set_facing_left(is_left: bool) -> void:
	facing_left = is_left
	# Grip always points "down" when on the left side
	sprite.flip_v = is_left

func aim_at(target_global_pos: Vector2) -> void:
	# Rotate the weapon so its +X axis points towards the mouse
	look_at(target_global_pos)

func can_fire() -> bool:
	# If fire_rate <= 0, weapon can always fire (no internal cooldown)
	return _time_until_next_shot <= 0.0

func _apply_fire_cooldown() -> void:
	if fire_rate <= 0.0:
		_time_until_next_shot = 0.0
	else:
		_time_until_next_shot = 1.0 / fire_rate

func spawn_bullet(target_global_pos: Vector2) -> void:
	# Roll damage and crit
	var dmg_info := _roll_damage()
	var dmg_value: int = dmg_info["damage"]
	var is_crit: bool = dmg_info["is_crit"]
	
	var muzzle_global: Vector2 = $Muzzle.global_position
	var dir: Vector2 = (target_global_pos - muzzle_global).normalized()

	# Apply random spread (angle in degrees)
	if spread_degrees > 0.0:
		var half := spread_degrees
		var random_angle := deg_to_rad(randf_range(-half, half))
		dir = dir.rotated(random_angle)

	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle_global
	bullet.direction = dir
	bullet.rotation = dir.angle()
	
	# Set damage and crit info on bullet
	if "damage" in bullet:
		bullet.damage = dmg_value
	if "is_crit" in bullet:
		bullet.is_crit = is_crit
	
	# Set penetration properties on bullet
	if "penetration_power" in bullet:
		bullet.penetration_power = roll_penetration_power()
	if "penetration_damage_drop_per_pen" in bullet:
		bullet.penetration_damage_drop_per_pen = penetration_damage_drop_per_pen
	
	# Set max range on bullet
	if "max_range" in bullet:
		bullet.max_range = max_range
	
	# Set bullet speed
	if "speed" in bullet:
		bullet.speed = bullet_speed
	
	# Set bullet knockback
	if "knockback_strength" in bullet:
		bullet.knockback_strength = bullet_knockback
	if "knockback_drop_per_pen" in bullet:
		bullet.knockback_drop_per_pen = knockback_drop_per_pen
	if "crit_knockback_multiplier" in bullet:
		bullet.crit_knockback_multiplier = crit_knockback_multiplier

	get_tree().current_scene.add_child(bullet)

	_play_shot_sound(muzzle_global)

	emit_signal("fired", shake_strength, shake_duration)
	_apply_fire_cooldown()

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

func roll_penetration_power() -> int:
	if penetration_max <= 0:
		return 0
	if randf() > penetration_chance:
		return 0
	var lo: int = mini(penetration_min, penetration_max)
	var hi: int = maxi(penetration_min, penetration_max)
	return randi_range(lo, hi)

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
