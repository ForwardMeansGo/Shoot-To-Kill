extends Node

# This script is used as an Autoload singleton named "ItemDatabase"

const CATEGORY_WEAPON := "weapon"
const CATEGORY_THROWABLE := "throwable"
const CATEGORY_GEAR_FEET := "gear_feet"
const CATEGORY_GEAR_BACK := "gear_back"
const CATEGORY_GEAR_HEAD := "gear_head"

# Items are deliberately simple for now. We only have a pistol implemented,
# but we define a few future items so the systems are ready.
#
# Fields:
# - id: string key
# - category: one of the CATEGORY_* constants above
# - display_name: UI name
# - description: flavour text
# - essence_cost: cost in permanent Essence
# - required_level: minimum player level to unlock
# - slot: which loadout slot it conceptually occupies (primary, secondary, throwable, gear_feet, gear_back, gear_head)
# - unlocked_by_default: whether the player should start with this item already in their stash
const ITEMS := {
	# Weapons
	"weapon_pistol": {
		"id": "weapon_pistol",
		"category": CATEGORY_WEAPON,
		"display_name": "Standard Pistol",
		"description": "Reliable sidearm with decent damage and crit chance.",
		"essence_cost": 0,
		"required_level": 1,
		"slot": "primary",
		"unlocked_by_default": true,
	},

	# Throwables (placeholder – logic will come later)
	"throwable_grenade_basic": {
		"id": "throwable_grenade_basic",
		"category": CATEGORY_THROWABLE,
		"display_name": "Basic Grenade",
		"description": "Simple explosive. Placeholder stats for now.",
		"essence_cost": 5,
		"required_level": 2,
		"slot": "throwable",
		"unlocked_by_default": false,
	},

	# Gear – Feet
	"gear_feet_boots_basic": {
		"id": "gear_feet_boots_basic",
		"category": CATEGORY_GEAR_FEET,
		"display_name": "Worn Boots",
		"description": "Basic boots. Future home for movement buffs.",
		"essence_cost": 3,
		"required_level": 1,
		"slot": "gear_feet",
		"unlocked_by_default": true,
	},

	# Gear – Back (future wings live here)
	"gear_back_harness_basic": {
		"id": "gear_back_harness_basic",
		"category": CATEGORY_GEAR_BACK,
		"display_name": "Simple Harness",
		"description": "Back slot placeholder. Will support wings later.",
		"essence_cost": 4,
		"required_level": 1,
		"slot": "gear_back",
		"unlocked_by_default": false,
	},

	# Gear – Head
	"gear_head_cap_basic": {
		"id": "gear_head_cap_basic",
		"category": CATEGORY_GEAR_HEAD,
		"display_name": "Worn Cap",
		"description": "Basic headgear. Future crit/movement buffs etc.",
		"essence_cost": 3,
		"required_level": 1,
		"slot": "gear_head",
		"unlocked_by_default": false,
	},
}

func item_exists(id: String) -> bool:
	return id in ITEMS

func get_item(id: String) -> Dictionary:
	if id in ITEMS:
		return ITEMS[id]
	return {}

func get_all_items() -> Array:
	# Returns an array of item dictionaries
	var out: Array = []
	for item in ITEMS.values():
		out.append(item)
	return out

func get_items_for_category(category: String) -> Array:
	var out: Array = []
	for item in ITEMS.values():
		if item.get("category", "") == category:
			out.append(item)
	return out

func get_items_unlocked_by_default() -> Array:
	var out: Array = []
	for item in ITEMS.values():
		if item.get("unlocked_by_default", false):
			out.append(item)
	return out
