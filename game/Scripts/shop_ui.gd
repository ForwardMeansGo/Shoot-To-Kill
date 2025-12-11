extends CanvasLayer

@onready var panel: TextureRect = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var essence_label: Label = $Panel/Margin/VBox/EssenceLabel
@onready var item_list: ItemList = $Panel/Margin/VBox/ItemList
@onready var details_label: Label = $Panel/Margin/VBox/DetailsLabel
@onready var buy_button: Button = $Panel/Margin/VBox/Buttons/BuyButton
@onready var close_button: Button = $Panel/Margin/VBox/Buttons/CloseButton

var _item_ids: Array[String] = []
var _current_index: int = -1
var _player: Node = null

func _ready() -> void:
	visible = false
	panel.visible = true

	title_label.text = "Bartender's Shop"

	# Connect UI signals
	if not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not item_list.item_selected.is_connected(_on_item_selected):
		item_list.item_selected.connect(_on_item_selected)

	# Connect to GameManager signals (autoload)
	var gm = GameManager
	if gm.has_signal("essence_changed") and not gm.essence_changed.is_connected(_on_essence_changed):
		gm.essence_changed.connect(_on_essence_changed)
	if gm.has_signal("item_unlocked") and not gm.item_unlocked.is_connected(_on_item_unlocked):
		gm.item_unlocked.connect(_on_item_unlocked)

	# Initialize essence label from current state if fields exist
	if "essence_total" in gm:
		_on_essence_changed(gm.essence_total)

	_refresh_items()

func _apply_mouse_mode_for_ui(opening: bool) -> void:
	# Find and cache the player in the "player" group
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
		else:
			_player = null

	# Prefer the player's helper, but fall back to direct Input calls
	if _player != null and _player.has_method("set_ui_mouse_mode"):
		_player.set_ui_mouse_mode(opening)
	else:
		if opening:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func open() -> void:
	visible = true
	_apply_mouse_mode_for_ui(true)

	# Refresh list in case state changed while closed
	_refresh_items()

	if item_list.item_count > 0:
		item_list.select(0)
		_on_item_selected(0)

	# Optional: give focus to ItemList for keyboard navigation
	item_list.grab_focus()

func close() -> void:
	visible = false
	_apply_mouse_mode_for_ui(false)

func _on_close_pressed() -> void:
	close()

func _on_essence_changed(current_essence: int) -> void:
	essence_label.text = "Essence: %d" % current_essence

func _on_item_unlocked(_item_id: String, _category: String) -> void:
	# Simply refresh the list when something is unlocked
	_refresh_items()

func _refresh_items() -> void:
	var gm = GameManager
	var items: Array = ItemDatabase.get_all_items()

	_item_ids.clear()
	item_list.clear()

	# Stable sort: by required_level ascending, then by name
	items.sort_custom(func(a, b):
		var lvl_a: int = int(a.get("required_level", 1))
		var lvl_b: int = int(b.get("required_level", 1))
		if lvl_a == lvl_b:
			var name_a: String = str(a.get("display_name", a.get("id", "")))
			var name_b: String = str(b.get("display_name", b.get("id", "")))
			return name_a < name_b
		return lvl_a < lvl_b
	)

	for item in items:
		var id: String = item.get("id", "")
		if id == "":
			continue

		var item_name: String = str(item.get("display_name", id))
		var category: String = str(item.get("category", ""))
		var required_level: int = int(item.get("required_level", 1))
		var cost: int = int(item.get("essence_cost", 0))

		var owned: bool = gm.owns_item(category, id)
		var player_level: int = int(gm.level) if "level" in gm else 1
		var essence: int = int(gm.essence_total) if "essence_total" in gm else 0

		var status: String

		if owned:
			status = "[OWNED]"
		elif player_level < required_level:
			status = "[LOCKED Lv %d]" % required_level
		elif essence < cost:
			status = "[NEEDS %d]" % cost
		else:
			status = "[BUY]"

		var display_text := "%s %s  -  %d Essence (Lv %d)" % [status, item_name, cost, required_level]
		item_list.add_item(display_text)
		_item_ids.append(id)

	_current_index = -1
	_update_buy_button_state()

func _on_item_selected(index: int) -> void:
	_current_index = index
	_update_details_label()
	_update_buy_button_state()

func _update_details_label() -> void:
	details_label.text = ""

	if _current_index < 0 or _current_index >= _item_ids.size():
		return

	var id: String = _item_ids[_current_index]
	var item: Dictionary = ItemDatabase.get_item(id)

	var item_name: String = str(item.get("display_name", id))
	var description: String = str(item.get("description", ""))
	var required_level: int = int(item.get("required_level", 1))
	var cost: int = int(item.get("essence_cost", 0))

	details_label.text = "%s\n\nCost: %d Essence\nRequired Level: %d\n\n%s" % [
		item_name,
		cost,
		required_level,
		description
	]

func _update_buy_button_state() -> void:
	if _current_index < 0 or _current_index >= _item_ids.size():
		buy_button.disabled = true
		return

	var gm = GameManager
	var id: String = _item_ids[_current_index]
	var item: Dictionary = ItemDatabase.get_item(id)
	var category: String = str(item.get("category", ""))

	var required_level: int = int(item.get("required_level", 1))
	var cost: int = int(item.get("essence_cost", 0))

	var owned: bool = gm.owns_item(category, id)
	var player_level: int = int(gm.level) if "level" in gm else 1
	var essence: int = int(gm.essence_total) if "essence_total" in gm else 0

	var can_buy: bool = (not owned) and (player_level >= required_level) and (essence >= cost)
	buy_button.disabled = not can_buy

func _on_buy_pressed() -> void:
	if _current_index < 0 or _current_index >= _item_ids.size():
		return

	var id: String = _item_ids[_current_index]

	# Attempt purchase. We don't rely on return shape; we just refresh UI afterward.
	GameManager.purchase_item_with_essence(id)

	_refresh_items()
	_update_details_label()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
