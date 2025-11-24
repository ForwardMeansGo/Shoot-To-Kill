extends Node2D

func _on_AutoFreeTimer_timeout() -> void:
	queue_free()
