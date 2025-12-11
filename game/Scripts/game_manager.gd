extends Node

const TAVERN_SCENE_PATH := "res://Scenes/Tavern.tscn"
const RUN_SCENE_PATH := "res://Scenes/level_01.tscn"
const GOLD_TO_ESSENCE_RATE: float = 100.0

signal gold_run_changed(current_gold: float)

signal essence_changed(current_essence: int)

signal xp_changed(current_xp: int, current_level: int)

signal item_unlocked(item_id: String, category: String)

# Run-only currency: reset when a new run starts or on death

var gold_run: float = 0.0

# Permanent currency: kept between runs (we'll hook saving later)

var essence_total: int = 0

# Permanent inventory (Stash)

var stash_weapons: Array[String] = []

var stash_throwables: Array[String] = []

var stash_gear_feet: Array[String] = []

var stash_gear_back: Array[String] = []

var stash_gear_head: Array[String] = []

# Loadout (per-run equipment)

var loadout_primary_weapon: String = ""

var loadout_secondary_weapon: String = ""

var loadout_throwable: String = ""

var loadout_gear_feet: String = ""

var loadout_gear_back: String = ""

var loadout_gear_head: String = ""

# XP / Level system

var xp: int = 0

var level: int = 1

# When true, gameplay input (movement, abilities, etc.) should be blocked.
var debug_input_blocked: bool = false

@export var base_xp_to_level: int = 100

@export var xp_growth_factor: float = 1.4

# -------------------------------------------------------------------
# TESTING OVERRIDES — exported values (ignored in final build)
# -------------------------------------------------------------------

@export var start_level: int = 1

@export var start_xp: int = 0

@export var start_essence: int = 0

@export var start_gold_run: float = 0.0

func _ready() -> void:
	# Placeholder for future initialization / save-loading
	# Apply testing overrides
	level = max(1, start_level)
	xp = max(0, start_xp)
	essence_total = max(0, start_essence)
	gold_run = max(0.0, start_gold_run)
	
	# Emit signals so UI stays in sync
	emit_signal("xp_changed", xp, level)
	emit_signal("essence_changed", essence_total)
	emit_signal("gold_run_changed", gold_run)
	
	_initialize_default_stash_and_loadout()
	
	if OS.is_debug_build():
		var console_scene: PackedScene = load("res://Scenes/DebugConsole.tscn")
		if console_scene:
			var console_instance := console_scene.instantiate()
			get_tree().root.call_deferred("add_child", console_instance)

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
	# Convert gold to essence before returning to tavern.
	finalize_run_and_convert_gold()
	print("GameManager: on_player_died() called -> going to Tavern")
	go_to_tavern()

# --------------------------
# Stash and Loadout System
# --------------------------

func owns_item(category: String, id: String) -> bool:
	match category:
		"weapon":
			return id in stash_weapons
		"throwable":
			return id in stash_throwables
		"gear_feet":
			return id in stash_gear_feet
		"gear_back":
			return id in stash_gear_back
		"gear_head":
			return id in stash_gear_head
		_:
			return false

func unlock_item(category: String, id: String) -> void:
	if owns_item(category, id):
		return
	
	match category:
		"weapon":
			stash_weapons.append(id)
		"throwable":
			stash_throwables.append(id)
		"gear_feet":
			stash_gear_feet.append(id)
		"gear_back":
			stash_gear_back.append(id)
		"gear_head":
			stash_gear_head.append(id)

func set_loadout_item(slot: String, id: String) -> bool:
	# Safety: cannot equip items not in stash
	var category := ""
	match slot:
		"primary", "secondary":
			category = "weapon"
		"throwable":
			category = "throwable"
		"gear_feet":
			category = "gear_feet"
		"gear_back":
			category = "gear_back"
		"gear_head":
			category = "gear_head"
		_:
			return false
	
	if not owns_item(category, id):
		return false
	
	match slot:
		"primary":
			loadout_primary_weapon = id
		"secondary":
			loadout_secondary_weapon = id
		"throwable":
			loadout_throwable = id
		"gear_feet":
			loadout_gear_feet = id
		"gear_back":
			loadout_gear_back = id
		"gear_head":
			loadout_gear_head = id
	
	return true

func set_debug_input_blocked(blocked: bool) -> void:
	debug_input_blocked = blocked

func is_debug_input_blocked() -> bool:
	return debug_input_blocked

func finalize_run_and_convert_gold() -> void:
	var essence_gain: int = int(floor(gold_run / GOLD_TO_ESSENCE_RATE))
	if essence_gain > 0:
		essence_total += essence_gain
		emit_signal("essence_changed", essence_total)
	
	gold_run = 0.0
	emit_signal("gold_run_changed", gold_run)
	reset_run_state()

# -------------------------------------------------------------------
# Item purchase helpers (shop uses Essence + level + stash)
# -------------------------------------------------------------------

func _build_purchase_result(success: bool, reason: String, item: Dictionary) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"item": item,
	}

func can_purchase_item(item_id: String) -> Dictionary:
	# Validate that the item exists in the ItemDatabase
	if not ItemDatabase.item_exists(item_id):
		return _build_purchase_result(false, "unknown_item", {})

	var item: Dictionary = ItemDatabase.get_item(item_id)

	# Category is required so we know which stash bucket it belongs to
	var category: String = item.get("category", "")
	if category == "":
		return _build_purchase_result(false, "missing_category", item)

	# If the player already owns this item in their stash, block purchase
	if owns_item(category, item_id):
		return _build_purchase_result(false, "already_owned", item)

	# Level gating
	var required_level: int = int(item.get("required_level", 1))
	if level < required_level:
		return _build_purchase_result(false, "level_too_low", item)

	# Essence cost check
	var cost: int = int(item.get("essence_cost", 0))
	if cost < 0:
		cost = 0

	if essence_total < cost:
		return _build_purchase_result(false, "insufficient_essence", item)

	# If we get here, everything is OK to purchase
	return _build_purchase_result(true, "ok", item)

func purchase_item_with_essence(item_id: String) -> Dictionary:
	# First run validation without mutating any state
	var check := can_purchase_item(item_id)

	if not check.get("success", false):
		# Just forward the failure information
		return check

	var item: Dictionary = check.get("item", {})
	var category: String = item.get("category", "")
	var cost: int = int(item.get("essence_cost", 0))
	if cost < 0:
		cost = 0

	# Spend Essence (double-checking we actually can)
	var spent := spend_essence(cost)
	if not spent:
		# In theory this shouldn't happen because can_purchase_item checks first,
		# but we guard against race conditions / future changes.
		return _build_purchase_result(false, "insufficient_essence", item)

	# Unlock in stash using existing helper
	unlock_item(category, item_id)

	# Emit signal so UI / shop / stash screens can react
	item_unlocked.emit(item_id, category)

	return _build_purchase_result(true, "purchased", item)

# --------------------------
# Initialization
# --------------------------

func _initialize_default_stash_and_loadout() -> void:
	# Sync stash with default items from ItemDatabase (autoload)
	var starter_items: Array = ItemDatabase.get_items_unlocked_by_default()
	
	for item in starter_items:
		var id: String = item.get("id", "")
		var category: String = item.get("category", "")
		
		if id != "" and category != "":
			if not owns_item(category, id):
				unlock_item(category, id)
	
	# Initialize loadout with defaults if empty
	# Primary weapon
	if loadout_primary_weapon == "" or not ItemDatabase.item_exists(loadout_primary_weapon):
		if ItemDatabase.item_exists("weapon_pistol"):
			loadout_primary_weapon = "weapon_pistol"
	
	# Secondary weapon and throwable - leave empty for now as requested
	# (loadout_secondary_weapon and loadout_throwable remain empty)
	
	# Gear slots
	if loadout_gear_feet == "" or not ItemDatabase.item_exists(loadout_gear_feet):
		if ItemDatabase.item_exists("gear_feet_boots_basic"):
			loadout_gear_feet = "gear_feet_boots_basic"
	
	if loadout_gear_back == "" or not ItemDatabase.item_exists(loadout_gear_back):
		if ItemDatabase.item_exists("gear_back_harness_basic"):
			loadout_gear_back = "gear_back_harness_basic"
	
	if loadout_gear_head == "" or not ItemDatabase.item_exists(loadout_gear_head):
		if ItemDatabase.item_exists("gear_head_cap_basic"):
			loadout_gear_head = "gear_head_cap_basic"
