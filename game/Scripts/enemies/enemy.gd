extends CharacterBody2D

@export var move_speed: float = 45.0
@export var gravity: float = 1200.0
@export var max_health: int = 100
@export var player: CharacterBody2D
@export var damage_number_scene: PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar

var current_health: int

func _ready() -> void:
	current_health = max_health
	add_to_group("enemy") # so bullets can recognise this as an enemy
	_update_health_bar()

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	var dir_x: float = 0.0

	if player != null:
		dir_x = sign(player.global_position.x - global_position.x)

	velocity.x = dir_x * move_speed

	# Flip sprite based on movement direction
	if dir_x != 0.0:
		sprite.flip_h = dir_x < 0.0

	move_and_slide()

func take_damage(amount: int) -> void:
	current_health -= amount
	flash_hit()
	_update_health_bar()
	
	# Spawn damage number if scene is set
	if damage_number_scene != null:
		var dmg = damage_number_scene.instantiate()
		dmg.global_position = global_position + Vector2(15, -10)
		dmg.damage = amount
		get_tree().current_scene.add_child(dmg)

	if current_health <= 0:
		die()

func flash_hit() -> void:
	# Simple hit feedback – quick red flash (can improve later)
	sprite.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.05).timeout
	sprite.modulate = Color(1, 1, 1)

func _update_health_bar() -> void:
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health

func die() -> void:
	# Later: play death animation, spawn particles, drop loot etc.
	queue_free()
