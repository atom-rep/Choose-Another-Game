extends CanvasLayer

@onready var music: AudioStreamPlayer = $BackgroundAudio

var button_type = null


func fade_out_music(duration: float = 1.0) -> void:	# fade out dell'audio del main menu
	var t := create_tween()
	t.tween_property(music, "volume_db", -40.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)	# in duration secondi porta l'audio a -40db, trams e ease fanno un fade più morbido
	t.tween_callback(Callable(music, "stop"))	# quando il twin ha finito stoppa l'audio


func _on_fade_timer_timeout() -> void:	# al termine del fade_in cambio scena
	if button_type == "start_solo":
		get_tree().change_scene_to_file("res://native/concurrency_gate/godot-cpp/Scenes/Livello.tscn")
	
	if button_type == "start_coop":
		get_tree().change_scene_to_file("res://native/concurrency_gate/godot-cpp/Scenes/GameSplit.tscn")


func _on_start_solo_pressed() -> void:
	button_type = "start_solo"
	fade_out_music(1.0)
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")


func _on_start_coop_pressed() -> void:
	button_type = "start_coop"
	fade_out_music(1.0)
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")
