extends Node

const TAVERN_SCENE_PATH := "res://Scenes/Tavern.tscn"
const RUN_SCENE_PATH := "res://Scenes/level_01.tscn"

signal gold_run_changed(current_gold: float)

signal essence_changed(current_essence: int)

signal xp_changed(current_xp: int, current_level: int)

# Run-only currency: reset when a new run starts or on death

var gold_run: float = 0.0

# Permanent currency: kept between runs (we'll hook saving later)

var essence_total: int = 0

# XP / Level system

var xp: int = 0

var level: int = 1

@export var base_xp_to_level: int = 100

@export var xp_growth_factor: float = 1.4

func _ready() -> void:
	# Placeholder for future initialization / save-loading
	pass

# --------------------------
# Run currency (Gold)
# --------------------------

func reset_run_state() -> void:
	# Reset all run-only data here
	gold_run = 0.0
	emit_signal("gold_run_changed", gold_run)

func add_gold_run(amount: float) -> void:
	if amount == 0.0:
		return
	gold_run += amount
	emit_signal("gold_run_changed", gold_run)
	print("GOLD (run): +", amount, " -> ", gold_run)

func spend_gold_run(amount: float) -> bool:
	if amount <= 0.0:
		return true  # spending 0 is fine
	if gold_run < amount:
		return false
	gold_run -= amount
	emit_signal("gold_run_changed", gold_run)
	print("GOLD (run): -", amount, " -> ", gold_run)
	return true

# --------------------------
# Permanent currency (Essence)
# --------------------------

func add_essence(amount: int) -> void:
	if amount <= 0:
		return
	essence_total += amount
	emit_signal("essence_changed", essence_total)
	print("ESSENCE: +", amount, " -> ", essence_total)

func spend_essence(amount: int) -> bool:
	if amount <= 0:
		return true
	if essence_total < amount:
		return false
	essence_total -= amount
	emit_signal("essence_changed", essence_total)
	print("ESSENCE: -", amount, " -> ", essence_total)
	return true

# --------------------------
# XP / Level
# --------------------------

func get_xp_required_for_next_level() -> int:
	# Basic exponential growth: 100, 140, 196, ...
	var required := base_xp_to_level * pow(xp_growth_factor, level - 1)
	return int(round(required))

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var leveled_up: bool = false
	while true:
		var needed := get_xp_required_for_next_level()
		if xp < needed:
			break
		xp -= needed
		level += 1
		leveled_up = true
	emit_signal("xp_changed", xp, level)
	if leveled_up:
		print("LEVEL UP! Now level ", level)

func go_to_tavern() -> void:
	var scene := load(TAVERN_SCENE_PATH) as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		push_warning("GameManager: TAVERN_SCENE_PATH is invalid: %s" % TAVERN_SCENE_PATH)

func start_new_run() -> void:
	var scene := load(RUN_SCENE_PATH) as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		push_warning("GameManager: RUN_SCENE_PATH is invalid: %s" % RUN_SCENE_PATH)

func on_player_died() -> void:
	# Called when the player dies.
	# For now, just transition to the Tavern scene.
	print("GameManager: on_player_died() called -> going to Tavern")
	go_to_tavern()

