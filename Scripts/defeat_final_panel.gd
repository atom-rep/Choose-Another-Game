extends CanvasLayer

@onready var gm: Node = get_tree().get_first_node_in_group("game_manager")
@onready var rm: Node = get_tree().get_first_node_in_group("round_manager")
@onready var panel: Control = $DefeatFinalPanel
@onready var lose_audio: AudioStreamPlayer = $"../StartEndAudios/EndGameAudio"
@onready var lose_video: VideoStreamPlayer = $DefeatFinalPanel/EndGameVideo


func _ready() -> void:
	panel.visible = false

	if gm == null:
		push_error("ui finale non trovata")
		return

	gm.all_players_defeated.connect(_on_all_players_defeated)


func _on_all_players_defeated() -> void:
	rm._running = false
	panel.visible = true
	
	# sblocca il mouse per poter cliccare i bottoni
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	lose_video.play()
	lose_audio.play()
	
	# blocca il gioco quando tutti hanno perso
	get_tree().paused = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_to_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://native/concurrency_gate/godot-cpp/Scenes/Main_menu.tscn")
