extends Area2D

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()

	position += direction * speed * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(_body: Node) -> void:
	queue_free()
