extends Node

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)

const ENEMY_BASIC_SCENE := preload("res://Scenes/EnemyBasic.tscn")

@export var base_break_duration: float = 15.0
@export var base_target_concurrent: int = 4
@export var max_target_concurrent: int = 25
@export var base_total_basic: int = 6
@export var total_basic_per_wave: int = 3
@export var max_total_basic: int = 80
@export var base_spawn_interval: float = 0.8
@export var min_spawn_interval: float = 0.25
@export var spawn_interval_decay_per_wave: float = 0.03

var current_wave_index: int = 0
var _current_wave_def: Dictionary = {}
var _spawn_queue: Array = []  # each entry: { "scene": PackedScene, "spawn_group": String }
var _spawn_index: int = 0
var _active_enemies: int = 0
var _spawn_points_by_group: Dictionary = {}  # String -> Array[Node2D]
var _player: Node2D = null
var _total_kills: int = 0

@onready var _spawn_timer: Timer = Timer.new()
@onready var _break_timer: Timer = Timer.new()

func _ready() -> void:
	# Configure spawn timer
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	# Configure break timer
	_break_timer.one_shot = true
	_break_timer.timeout.connect(_on_break_timer_timeout)
	add_child(_break_timer)

	# Scan the tree for spawn points
	var root := get_tree().current_scene
	if root != null and root.has_node("WaveSpawnPoints"):
		var spawn_points_parent := root.get_node("WaveSpawnPoints")
		for child in spawn_points_parent.get_children():
			# Check if this child has the spawn_group property (indicates wave_spawn_point.gd script)
			if "spawn_group" in child:
				var group_name: String = str(child.spawn_group)
				
				if not _spawn_points_by_group.has(group_name):
					_spawn_points_by_group[group_name] = []
				_spawn_points_by_group[group_name].append(child)
	
	if _spawn_points_by_group.is_empty():
		push_warning("WaveManager: No spawn points found! Add WaveSpawnPoints node with children that have wave_spawn_point.gd script.")

	# Cache player reference for enemy AI
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		_player = players[0]
	else:
		_player = null
		push_warning("WaveManager: No player found in 'player' group; enemies will not move towards the player.")

	# Start the first wave automatically
	_start_next_wave()

func _build_wave_definition(wave_index: int) -> Dictionary:
	var wave_name: String = "Wave %d" % wave_index

	var target_concurrent: int = clamp(
		base_target_concurrent + wave_index,
		base_target_concurrent,
		max_target_concurrent
	)

	var total_basic: int = clamp(
		base_total_basic + (wave_index - 1) * total_basic_per_wave,
		base_total_basic,
		max_total_basic
	)

	var spawn_interval: float = max(
		base_spawn_interval - (wave_index - 1) * spawn_interval_decay_per_wave,
		min_spawn_interval
	)

	var enemy_defs: Array = [
		{
			"scene": ENEMY_BASIC_SCENE,
			"total_count": total_basic,
			"spawn_group": "default",
			"early_ratio": 0.6,
			"mid_ratio": 0.25,
			"late_ratio": 0.15,
		}
	]

	return {
		"name": wave_name,
		"target_concurrent": target_concurrent,
		"spawn_interval": spawn_interval,
		"break_duration": base_break_duration,
		"enemies": enemy_defs,
	}

func _generate_spawn_queue(wave_def: Dictionary) -> Array:
	var early: Array = []
	var mid: Array = []
	var late: Array = []

	var enemies_variant = wave_def.get("enemies", [])
	var enemies: Array = enemies_variant if enemies_variant is Array else []

	for e_variant in enemies:
		if typeof(e_variant) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_variant

		var scene: PackedScene = e.get("scene", null)
		if scene == null:
			continue

		var total_count: int = int(e.get("total_count", 0))
		if total_count <= 0:
			continue

		var group_name: String = str(e.get("spawn_group", "default"))

		var early_ratio: float = float(e.get("early_ratio", 0.6))
		var mid_ratio: float = float(e.get("mid_ratio", 0.25))

		var early_count: int = int(round(total_count * early_ratio))
		var mid_count: int = int(round(total_count * mid_ratio))
		var used: int = early_count + mid_count
		var late_count: int = max(total_count - used, 0)

		for i in range(early_count):
			early.append({ "scene": scene, "spawn_group": group_name })
		for i in range(mid_count):
			mid.append({ "scene": scene, "spawn_group": group_name })
		for i in range(late_count):
			late.append({ "scene": scene, "spawn_group": group_name })

	early.shuffle()
	mid.shuffle()
	late.shuffle()

	var result: Array = []
	result.append_array(early)
	result.append_array(mid)
	result.append_array(late)
	return result

func _start_next_wave() -> void:
	current_wave_index += 1

	_current_wave_def = _build_wave_definition(current_wave_index)
	_spawn_queue = _generate_spawn_queue(_current_wave_def)
	_spawn_index = 0
	_active_enemies = 0

	var interval: float = float(_current_wave_def.get("spawn_interval", 0.5))
	_spawn_timer.wait_time = max(interval, 0.01)
	_spawn_timer.start()

	emit_signal("wave_started", current_wave_index)

func _is_offscreen(global_pos: Vector2) -> bool:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if camera == null:
		# No camera, assume off-screen (safer for spawning)
		return true
	
	# Get the camera's visible area in world space
	var viewport_size := viewport.get_visible_rect().size
	var world_size := viewport_size / camera.zoom
	var camera_center := camera.global_position
	var world_rect := Rect2(
		camera_center - world_size / 2.0,
		world_size
	)
	
	# Add a margin to ensure enemies spawn well off-screen
	var margin := 100.0
	var expanded_rect := Rect2(
		world_rect.position - Vector2(margin, margin),
		world_rect.size + Vector2(margin * 2, margin * 2)
	)
	
	return not expanded_rect.has_point(global_pos)

func _try_spawn_entry(entry: Dictionary) -> bool:
	var scene: PackedScene = entry.get("scene")
	if scene == null:
		return false

	var group_name: String = str(entry.get("spawn_group", "default"))
	var points: Array = _spawn_points_by_group.get(group_name, [])
	if points.is_empty():
		return false

	var shuffled_points := points.duplicate()
	shuffled_points.shuffle()

	for p in shuffled_points:
		if not (p is Node2D):
			continue
		var pos: Vector2 = (p as Node2D).global_position
		if _is_offscreen(pos):
			var enemy = scene.instantiate()

			# Spawn slightly above the spawn point, with small horizontal jitter
			var jitter_x: float = randf_range(-8.0, 8.0)
			var vertical_offset: float = -16.0  # 16 pixels above the spawn point (upwards in Godot's Y)
			enemy.global_position = pos + Vector2(jitter_x, vertical_offset)

			# Assign player reference if possible
			if _player != null and enemy.has_method("set_player"):
				enemy.set_player(_player)

			# Add to current scene
			get_tree().current_scene.add_child(enemy)

			# Connect died signal if present
			if enemy.has_signal("died"):
				if not enemy.died.is_connected(_on_enemy_died):
					enemy.died.connect(_on_enemy_died)

			_active_enemies += 1
			return true

	# Could not find valid off-screen point
	return false

func _on_spawn_timer_timeout() -> void:
	# Already no queue and no enemies? Wave is done.
	if _spawn_index >= _spawn_queue.size() and _active_enemies <= 0:
		_on_wave_cleared()
		return

	var target_concurrent: int = int(_current_wave_def.get("target_concurrent", 5))

	if _active_enemies >= target_concurrent:
		return

	if _spawn_index >= _spawn_queue.size():
		# No more units to schedule, just wait for kills
		return

	var entry: Dictionary = _spawn_queue[_spawn_index]
	var spawned: bool = _try_spawn_entry(entry)
	if spawned:
		_spawn_index += 1

func _on_enemy_died() -> void:
	_active_enemies = max(_active_enemies - 1, 0)
	_total_kills += 1

func _on_wave_cleared() -> void:
	_spawn_timer.stop()
	emit_signal("wave_cleared", current_wave_index)

	var break_duration: float = float(_current_wave_def.get("break_duration", base_break_duration))
	_break_timer.wait_time = max(break_duration, 0.0)
	_break_timer.start()

func _on_break_timer_timeout() -> void:
	_start_next_wave()

func get_total_kills() -> int:
	return _total_kills

func get_monsters_remaining() -> int:
	# Remaining = not yet spawned from the queue + currently alive
	var total: int = _spawn_queue.size()
	if total <= 0:
		return _active_enemies

	var spawned_so_far: int = min(_spawn_index, total)
	var pending: int = max(total - spawned_so_far, 0)

	return pending + _active_enemies
