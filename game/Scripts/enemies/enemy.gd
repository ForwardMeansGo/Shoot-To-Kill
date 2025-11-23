extends CharacterBody2D

@export var move_speed: float = 45.0
@export var gravity: float = 1200.0
@export var max_health: int = 100
@export var player: CharacterBody2D
@export var damage_number_scene: PackedScene
@export var contact_damage: int = 10
@export var contact_cooldown: float = 0.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: TextureProgressBar = $HealthBar

var current_health: int
var contact_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	add_to_group("enemy") # so bullets can recognise this as an enemy
	_update_health_bar()
	
	# Connect DamageArea safely
	if has_node("DamageArea"):
		var da: Area2D = $DamageArea
		if not da.body_entered.is_connected(_on_damage_area_body_entered):
			da.body_entered.connect(_on_damage_area_body_entered)
			print("DamageArea connected for ", name)

func _physics_process(delta: float) -> void:
	# Update contact timer
	if contact_timer > 0.0:
		contact_timer -= delta
		if contact_timer < 0.0:
			contact_timer = 0.0
	
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

func take_damage(amount: int, is_crit: bool = false) -> void:
	current_health -= amount
	flash_hit()
	_update_health_bar()
	
	# Spawn damage number if scene is set
	if damage_number_scene != null:
		var dmg = damage_number_scene.instantiate()
		dmg.global_position = global_position + Vector2(15, -10)
		if "damage" in dmg:
			dmg.damage = amount
		if "is_crit" in dmg:
			dmg.is_crit = is_crit
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

func _on_damage_area_body_entered(body: Node) -> void:
	print("DamageArea entered by: ", body, " name=", body.name, " groups=", body.get_groups())
	
	if contact_timer > 0.0:
		return
	
	var target := body
	
	# if the collider isn't in the player group but their parent is, use parent
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player") and target.has_method("take_damage"):
		print("Dealing contact damage to: ", target.name)
		target.take_damage(contact_damage)
		contact_timer = contact_cooldown

func die() -> void:
	# Later: play death animation, spawn particles, drop loot etc.
	queue_free()
