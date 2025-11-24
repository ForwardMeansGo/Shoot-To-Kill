extends CanvasLayer

@onready var health_bar: TextureProgressBar = $PlayerHealthBar
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
