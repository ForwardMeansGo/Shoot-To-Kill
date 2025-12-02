extends Node2D

signal door_used(player: Node)

@onready var area: Area2D = $InteractionArea

@onready var prompt_label: Label = $PromptLabel

var _player_in_range: Node = null

func _ready() -> void:
	# Ensure prompt starts hidden
	if prompt_label:
		prompt_label.visible = false
	
	# Connect area signals
	if area:
		if not area.body_entered.is_connected(_on_area_body_entered):
			area.body_entered.connect(_on_area_body_entered)
		if not area.body_exited.is_connected(_on_area_body_exited):
			area.body_exited.connect(_on_area_body_exited)

func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("interact"):
		emit_signal("door_used", _player_in_range)
		print("RunDoor: door used by ", _player_in_range.name)

		# Ask GameManager to start a new run (load the run scene)
		if GameManager != null and GameManager.has_method("start_new_run"):
			GameManager.start_new_run()
		else:
			push_warning("RunDoor: GameManager autoload not available; cannot start new run.")

func _on_area_body_entered(body: Node) -> void:
	var target := body
	
	# Handle cases where colliders are child nodes of the player
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target.is_in_group("player"):
		_player_in_range = target
		if prompt_label:
			prompt_label.visible = true

func _on_area_body_exited(body: Node) -> void:
	var target := body
	
	if not target.is_in_group("player") and target.get_parent() and target.get_parent().is_in_group("player"):
		target = target.get_parent()
	
	if target == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false
