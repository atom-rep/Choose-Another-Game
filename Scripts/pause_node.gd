extends Node

signal pause_game

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		get_tree().paused = !get_tree().paused
		pause_game.emit()
