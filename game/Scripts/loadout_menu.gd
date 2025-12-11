extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var info_label: Label = $Panel/MarginContainer/VBoxContainer/InfoScroll/InfoLabel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

var _player: Node = null


func _ready() -> void:
	visible = false
	panel.visible = true

	title_label.text = "Loadout Overview"

	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	# Find player (for cursor/crosshair switching)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _unhandled_input(event: InputEvent) -> void:
	# Toggle menu with input action
	if event.is_action_pressed("open_loadout"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

	# ESC closes when open
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_apply_mouse_mode_for_ui(true)
	_refresh_contents()


func close() -> void:
	visible = false
	_apply_mouse_mode_for_ui(false)


func _on_close_pressed() -> void:
	close()


func _apply_mouse_mode_for_ui(opening: bool) -> void:
	# Use the player's helper if available (handles crosshair hiding)
	if _player != null and _player.has_method("set_ui_mouse_mode"):
		_player.set_ui_mouse_mode(opening)
	else:
		if opening:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


# -----------------------------------------------------------
#  Helper: resolve item IDs to display names safely
# -----------------------------------------------------------
func item_name(id: String) -> String:
	if id == "":
		return "(empty)"

	if ItemDatabase.item_exists(id):
		var item := ItemDatabase.get_item(id)
		return str(item.get("display_name", id))

	return id + " (unknown)"


# -----------------------------------------------------------
#  Refresh UI text
# -----------------------------------------------------------
func _refresh_contents() -> void:
	var gm = GameManager
	var builder := ""

	# Basic info
	builder += "Level: %d\n" % gm.level
	builder += "XP: %d\n" % gm.xp
	builder += "Essence: %d\n" % gm.essence_total
	builder += "Run Gold: %.1f\n\n" % gm.gold_run

	# Loadout
	builder += "Current Loadout:\n"
	builder += "- Primary:   %s\n" % item_name(gm.loadout_primary_weapon)
	builder += "- Secondary: %s\n" % item_name(gm.loadout_secondary_weapon)
	builder += "- Throwable: %s\n" % item_name(gm.loadout_throwable)
	builder += "- Feet:      %s\n" % item_name(gm.loadout_gear_feet)
	builder += "- Back:      %s\n" % item_name(gm.loadout_gear_back)
	builder += "- Head:      %s\n" % item_name(gm.loadout_gear_head)

	info_label.text = builder
