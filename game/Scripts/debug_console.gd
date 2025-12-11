extends CanvasLayer

@onready var log_label: RichTextLabel = $Panel/Margin/VBox/Log
@onready var input_line: LineEdit = $Panel/Margin/VBox/Input

var _gm: Node = null

func _ready() -> void:
	# Remove the console entirely in non-debug builds
	if not OS.is_debug_build():
		queue_free()
		return

	_gm = GameManager
	visible = false

	# Basic setup
	log_label.clear()
	log_label.mouse_filter = Control.MOUSE_FILTER_STOP

	# Click in the log focuses the input
	if not log_label.gui_input.is_connected(_on_log_gui_input):
		log_label.gui_input.connect(_on_log_gui_input)

	# Enter submits commands
	if not input_line.text_submitted.is_connected(_on_input_submitted):
		input_line.text_submitted.connect(_on_input_submitted)

	# ESC while typing closes the console
	if not input_line.gui_input.is_connected(_on_input_gui_input):
		input_line.gui_input.connect(_on_input_gui_input)

	print_line("Debug console ready. Press F2 to toggle. Type 'help' for commands.")

func _toggle() -> void:
	visible = not visible

	# Block/unblock gameplay input while console is visible
	if _gm == null:
		_gm = GameManager
	if _gm != null and _gm.has_method("set_debug_input_blocked"):
		_gm.set_debug_input_blocked(visible)

	if visible:
		# Reset and focus input when opening
		input_line.text = ""
		input_line.grab_focus()
		input_line.caret_column = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_toggle()
			get_viewport().set_input_as_handled()
			return

		if not visible:
			return

		if event.keycode == KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()
			return

func _on_log_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		input_line.grab_focus()
		input_line.caret_column = input_line.text.length()

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()

func _on_input_submitted(text: String) -> void:
	var cmd_line := text.strip_edges()

	if cmd_line.is_empty():
		# Keep console open and ready even on empty submit
		input_line.text = ""
		input_line.grab_focus()
		input_line.caret_column = 0
		return

	print_line("> " + cmd_line)
	input_line.text = ""

	_execute_command(cmd_line)

	# Best-effort: keep input ready for the next command
	input_line.grab_focus()
	input_line.caret_column = 0

func print_line(text: String) -> void:
	if log_label != null:
		log_label.append_text(text + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)
	print("[DebugConsole] " + text)

# -------------------------------------------------------------------
# Command parsing
# -------------------------------------------------------------------

func _execute_command(cmd_line: String) -> void:
	var parts: Array = cmd_line.split(" ", false)
	if parts.is_empty():
		return

	var cmd: String = parts[0].to_lower()

	match cmd:
		"help":
			_print_help()
		"give_gold":
			_cmd_give_gold(parts)
		"give_essence":
			_cmd_give_essence(parts)
		"set_level":
			_cmd_set_level(parts)
		"set_xp":
			_cmd_set_xp(parts)
		"unlock_all":
			_cmd_unlock_all()
		"give", "set":
			_cmd_friendly_alias(parts)
		_:
			print_line("Error: Unknown command. Type 'help' for commands.")

func _print_help() -> void:
	print_line("Available commands:")
	print_line("  help")
	print_line("  give_gold <amount>")
	print_line("  give_essence <amount>")
	print_line("  set_level <level>")
	print_line("  set_xp <amount>")
	print_line("  unlock_all")
	print_line("")
	print_line("Aliases:")
	print_line("  give gold <amount>")
	print_line("  give essence <amount>")
	print_line("  set level <level>")
	print_line("  set xp <amount>")

func _parse_int(parts: Array, index: int, default_value: int) -> int:
	if index >= parts.size():
		return default_value
	var s: String = str(parts[index])
	if not s.is_valid_int():
		return default_value
	return int(s)

func _parse_float(parts: Array, index: int, default_value: float) -> float:
	if index >= parts.size():
		return default_value
	var s: String = str(parts[index])
	if not s.is_valid_float():
		return default_value
	return float(s)

# -------------------------------------------------------------------
# Individual commands
# -------------------------------------------------------------------

func _cmd_give_gold(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var amount: float = _parse_float(parts, 1, 0.0)
	if amount <= 0.0:
		print_line("Usage: give_gold <amount>")
		return

	if not gm.has_method("add_gold_run"):
		print_line("Error: GameManager.add_gold_run() not found. Command failed.")
		return

	gm.add_gold_run(amount)
	print_line("Success: Gave gold_run: %.2f" % amount)

func _cmd_give_essence(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var amount: int = _parse_int(parts, 1, 0)
	if amount <= 0:
		print_line("Usage: give_essence <amount>")
		return

	if not gm.has_method("add_essence"):
		print_line("Error: GameManager.add_essence() not found. Command failed.")
		return

	gm.add_essence(amount)
	print_line("Success: Gave essence: %d" % amount)

func _cmd_set_level(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var lvl: int = _parse_int(parts, 1, -1)
	if lvl <= 0:
		print_line("Usage: set_level <level>")
		return

	lvl = max(1, lvl)
	gm.level = lvl
	if gm.has_signal("xp_changed"):
		gm.xp_changed.emit(gm.xp, gm.level)

	print_line("Success: Set level to %d" % lvl)

func _cmd_set_xp(parts: Array) -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var amount: int = _parse_int(parts, 1, -1)
	if amount < 0:
		print_line("Usage: set_xp <amount>")
		return

	gm.xp = amount
	if gm.has_signal("xp_changed"):
		gm.xp_changed.emit(gm.xp, gm.level)

	print_line("Success: Set XP to %d" % amount)

func _cmd_unlock_all() -> void:
	var gm = GameManager
	if gm == null:
		print_line("Error: GameManager not available.")
		return

	var items: Array = ItemDatabase.get_all_items()
	var count := 0

	for item in items:
		var id: String = item.get("id", "")
		var category: String = item.get("category", "")
		if id == "" or category == "":
			continue

		if gm.has_method("owns_item") and gm.owns_item(category, id):
			continue

		if gm.has_method("unlock_item"):
			gm.unlock_item(category, id)
			count += 1
		if gm.has_signal("item_unlocked"):
			gm.item_unlocked.emit(id, category)

	print_line("Success: Unlocked %d items." % count)

func _cmd_friendly_alias(parts: Array) -> void:
	if parts.is_empty():
		return

	var root: String = parts[0].to_lower()

	if root == "give":
		if parts.size() < 3:
			print_line("Usage: give gold <amount> | give essence <amount>")
			return
		var target: String = parts[1].to_lower()
		match target:
			"gold":
				_cmd_give_gold(["give_gold", parts[2]])
			"essence":
				_cmd_give_essence(["give_essence", parts[2]])
			_:
				print_line("Error: Unknown give target. Use 'gold' or 'essence'.")
	elif root == "set":
		if parts.size() < 3:
			print_line("Usage: set level <value> | set xp <value>")
			return
		var target: String = parts[1].to_lower()
		match target:
			"level":
				_cmd_set_level(["set_level", parts[2]])
			"xp":
				_cmd_set_xp(["set_xp", parts[2]])
			_:
				print_line("Error: Unknown set target. Use 'level' or 'xp'.")
