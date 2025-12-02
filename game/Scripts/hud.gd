extends CanvasLayer

@onready var health_bar: TextureProgressBar = $PlayerHealthBar
@onready var gold_label: Label = $CurrencyPanel/GoldBox/GoldLabel
@onready var essence_label: Label = $CurrencyPanel/EssenceBox/EssenceLabel
@onready var xp_label: Label = $CurrencyPanel/XPBox/XPLabel
@export var player_path: NodePath = ^"../Player"

var player: Node = null
var hp_tween: Tween = null

func _ready() -> void:
	# Find the player
	if player_path != NodePath():
		if has_node(player_path):
			player = get_node(player_path)
		else:
			push_error("HUD: player_path is set but node not found: " + str(player_path))
			return
	else:
		if get_parent().has_node("Player"):
			player = get_parent().get_node("Player")
		else:
			push_error("HUD: Could not find Player as sibling of HUD")
			return
	
	if player == null:
		push_error("HUD: Player is null")
		return
	
	# Connect to health_changed signal if it exists
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	else:
		push_warning("HUD: Player has no 'health_changed' signal")
	
	# Initialize bar from current player health (if fields exist)
	var max_h := 100
	var cur_h := 100
	
	if "max_health" in player:
		max_h = player.max_health
	if "current_health" in player:
		cur_h = player.current_health

	if health_bar:
		health_bar.visible = true
		health_bar.max_value = max_h
		health_bar.value = cur_h
		health_bar.step = 1.0
		print("HUD: Initialized health bar -> ", cur_h, "/", max_h)
	else:
		push_error("HUD: health_bar (PlayerHealthBar) not found under HUD")

	# Hook into GameManager for gold, essence, and XP/level
	if GameManager != null:
		# Connect signals if available
		if GameManager.has_signal("gold_run_changed") and not GameManager.gold_run_changed.is_connected(_on_gold_run_changed):
			GameManager.gold_run_changed.connect(_on_gold_run_changed)

		if GameManager.has_signal("essence_changed") and not GameManager.essence_changed.is_connected(_on_essence_changed):
			GameManager.essence_changed.connect(_on_essence_changed)

		if GameManager.has_signal("xp_changed") and not GameManager.xp_changed.is_connected(_on_xp_changed):
			GameManager.xp_changed.connect(_on_xp_changed)

		# Initialize from current GameManager state
		_on_gold_run_changed(GameManager.gold_run)
		_on_essence_changed(GameManager.essence_total)
		_on_xp_changed(GameManager.xp, GameManager.level)
	else:
		push_warning("HUD: GameManager autoload not available; currency/XP HUD will not update.")

func _on_player_health_changed(current: int, max: int) -> void:
	if health_bar == null:
		return

	health_bar.max_value = max

	# Kill any existing tween so they don't fight
	if hp_tween and hp_tween.is_valid():
		hp_tween.kill()

	# Create a new tween to animate from current bar value to the new HP
	hp_tween = create_tween()
	hp_tween.tween_property(health_bar, "value", current, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_gold_run_changed(current_gold: float) -> void:
	if gold_label == null:
		return

	# Gold is a float (can be 0.5 etc). Show with at most 1 decimal place.
	var display_value: float = snapped(current_gold, 0.1)
	gold_label.text = str(display_value)

func _on_essence_changed(current_essence: int) -> void:
	if essence_label == null:
		return

	essence_label.text = str(current_essence)

func _on_xp_changed(current_xp: int, current_level: int) -> void:
	if xp_label == null:
		return

	# Show both level and XP so the player sees progression.
	# Example: "Lv 3  XP 42"
	xp_label.text = "Lv %d  XP %d" % [current_level, current_xp]
