extends Area2D

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.ZERO
@export var lifetime: float = 1.5
@export var damage: int = 10
@export var hit_effect_scene: PackedScene

var previous_position: Vector2
var is_crit: bool = false
var penetration_power: int = 0
var penetration_damage_drop_per_pen: float = 0.20
var _hit_enemy_ids: Dictionary = {} # instance_id -> true
const MAX_HITS_PER_FRAME := 8
const PIERCE_EPSILON := 1.0
var max_range: float = INF
var _distance_travelled: float = 0.0
var _enemies_damaged: int = 0
var knockback_strength: float = 0.0
var knockback_drop_per_pen: float = 0.20
var crit_knockback_multiplier: float = 1.0

func _ready() -> void:
	previous_position = global_position
	_distance_travelled = 0.0
	_enemies_damaged = 0

func _resolve_enemy_from_collider(collider: Object) -> Node:
	if collider == null:
		return null
	if collider is Node:
		var n := collider as Node
		if n.is_in_group("enemy"):
			return n
		if n.get_parent() != null and n.get_parent().is_in_group("enemy"):
			return n.get_parent()
	return null

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

	# Track distance traveled for max range check
	var segment_distance: float = previous_position.distance_to(target_pos)
	_distance_travelled += segment_distance
	
	# Check if bullet has exceeded max range
	if _distance_travelled >= max_range:
		queue_free()
		return

	# Add a small extra margin in the same direction to be safe
	var ray_to: Vector2 = target_pos + direction * 2.0

	# Multi-hit penetration loop
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var segment_from: Vector2 = previous_position
	var segment_to: Vector2 = ray_to
	var exclude_list: Array = [self]
	var hit_count: int = 0
	var base_damage: int = damage

	while hit_count < MAX_HITS_PER_FRAME:
		# Create raycast query for this segment
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(segment_from, segment_to)
		query.collision_mask = collision_mask
		query.exclude = exclude_list
		query.hit_from_inside = true

		var result: Dictionary = space_state.intersect_ray(query)

		# No hit - move to target position and continue
		if result.is_empty():
			global_position = target_pos
			previous_position = target_pos
			return

		# Hit something
		var hit_pos: Vector2 = result["position"]
		var collider: Object = result["collider"]

		# Exclude this collider from subsequent raycasts using RID
		if collider is CollisionObject2D:
			exclude_list.append((collider as CollisionObject2D).get_rid())

		if collider is Node:
			var node: Node = collider as Node

			# Ignore player
			if node.is_in_group("player"):
				# Hit player - stop penetration, but don't damage
				global_position = hit_pos
				queue_free()
				return

		# Resolve enemy from collider (checks collider and parent)
		var enemy := _resolve_enemy_from_collider(collider)
		
		if enemy != null and enemy.has_method("take_damage"):
			var enemy_id := enemy.get_instance_id()
			
			# Check if we already hit this enemy (persists for bullet lifetime)
			if _hit_enemy_ids.has(enemy_id):
				# Already hit this enemy - exclude it and continue
				# Advance segment slightly to continue
				segment_from = hit_pos + direction.normalized() * PIERCE_EPSILON
				continue

			# Apply damage to this enemy
			var damage_to_deal: int = base_damage
			
			# Apply cumulative damage drop based on number of enemies already damaged
			if _enemies_damaged > 0:
				var step: float = 1.0 - penetration_damage_drop_per_pen
				if step < 0.0:
					step = 0.0
				var damage_multiplier: float = pow(step, float(_enemies_damaged))
				damage_to_deal = max(1, int(round(float(base_damage) * damage_multiplier)))

			enemy.take_damage(damage_to_deal, is_crit)

			# Apply knockback with crit bonus and penetration reduction
			var kb: float = knockback_strength

			# Apply crit bonus before penetration scaling
			if is_crit:
				kb *= crit_knockback_multiplier

			# Apply penetration-based knockback reduction
			if _enemies_damaged > 0:
				var step: float = 1.0 - knockback_drop_per_pen
				if step < 0.0:
					step = 0.0
				kb *= pow(step, float(_enemies_damaged))

			if kb > 0.0 and enemy.has_method("apply_knockback"):
				enemy.apply_knockback(direction, kb)

			# Spawn hit impact effect if assigned (only on first hit)
			if _enemies_damaged == 0 and hit_effect_scene != null:
				var hit_effect = hit_effect_scene.instantiate()
				hit_effect.global_position = hit_pos
				get_tree().current_scene.add_child(hit_effect)

			# Get resistance from enemy (default to 1 if not found)
			var resistance: int = 1
			if "penetration_resistance" in enemy:
				resistance = enemy.penetration_resistance

			# Record this enemy as hit (persists for bullet lifetime)
			_hit_enemy_ids[enemy_id] = true
			
			# Increment enemies damaged counter
			_enemies_damaged += 1

			# Reduce penetration power
			penetration_power -= resistance

			# Check if we can continue penetrating
			if penetration_power >= 1:
				# Continue piercing - advance segment start past this hit
				segment_from = hit_pos + direction.normalized() * PIERCE_EPSILON
				hit_count += 1
				continue
			else:
				# Out of penetration power - stop at this hit
				global_position = hit_pos
				queue_free()
				return
		elif result.collider is Node:
			# Hit a Node collider but it's not an enemy (world/props/etc) - stop
			global_position = hit_pos
			queue_free()
			return
		else:
			# Hit non-node collider - stop
			global_position = hit_pos
			queue_free()
			return

	# Reached max hits per frame - move to target and continue next frame
	global_position = target_pos
	previous_position = target_pos
