extends Area2D

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5
@export var damage: int = 1

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	if direction == Vector2.ZERO:
		return

	rotation = direction.angle()

	var from: Vector2 = global_position
	var to: Vector2 = from + direction * speed * delta

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = collision_mask
	query.exclude = [self]

	var result: Dictionary = space_state.intersect_ray(query)

	# If we hit something this frame
	if result.size() > 0:
		var hit_pos: Vector2 = result["position"]
		var collider: Object = result["collider"]

		global_position = hit_pos
		_handle_hit(collider)
		queue_free()
		return

	# No hit – just move normally
	global_position = to

func _handle_hit(body: Object) -> void:
	if body is Node:
		var node: Node = body as Node

		# Ignore player, just in case
		if node.is_in_group("player"):
			return

		# Damage enemies
		if node.is_in_group("enemy") and node.has_method("take_damage"):
			node.take_damage(damage)
