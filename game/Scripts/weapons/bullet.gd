extends Area2D

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5
@export var damage: int = 10

var previous_position: Vector2
var is_crit: bool = false

func _ready() -> void:
	previous_position = global_position

func _physics_process(delta: float) -> void:
	# Handle lifetime first
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	if direction == Vector2.ZERO:
		previous_position = global_position
		return

	rotation = direction.angle()

	# Get current position and compute target position
	var current_pos: Vector2 = global_position
	var target_pos: Vector2 = current_pos + direction * speed * delta

	# Add a small extra margin in the same direction to be safe
	var ray_to: Vector2 = target_pos + direction * 2.0

	# Create raycast query from previous_position to ray_to
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(previous_position, ray_to)
	query.collision_mask = collision_mask
	query.exclude = [self]
	query.hit_from_inside = true

	var result: Dictionary = space_state.intersect_ray(query)

	# If we hit something this frame
	if result.size() > 0:
		var hit_pos: Vector2 = result["position"]
		var collider: Object = result["collider"]

		global_position = hit_pos
		_handle_hit(collider)
		queue_free()
		return

	# No hit – move normally to target position
	global_position = target_pos
	
	# Update previous_position for next frame
	previous_position = global_position

func _handle_hit(body: Object) -> void:
	if body is Node:
		var node: Node = body as Node

		# Ignore player, just in case
		if node.is_in_group("player"):
			return

		# Damage enemies
		if node.is_in_group("enemy") and node.has_method("take_damage"):
			node.take_damage(damage, is_crit)
