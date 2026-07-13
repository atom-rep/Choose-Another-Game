extends Area3D

@onready var door: Node = $"../SpiritHouse"
@onready var outside_spawn: Marker3D = $"../SpawnOut"
var waiting_players_id: Array[CharacterBody3D] = []
var device_players_id: Array[int] = []

@onready var teddy_audio = $"../AudioSpiritHouse/TeddyAudio"
@onready var kill_audio = $"../AudioSpiritHouse/InstaKillAudio"
@onready var kill_length = kill_audio.stream.get_length()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if get_tree().get_nodes_in_group("alive_player").size() > 0:	# controllo che non sia l'ultimo, quando entro in casa viene rimosso da alive_players, quindi parto da 0
			kill_audio.play()
			get_tree().create_timer(kill_length).timeout.connect(func():
				teddy_audio.play()
			)
		body.wants_enter = false
		door.free_house(body.get_instance_id())
		body.add_to_group("alive_player")
		body.global_transform = outside_spawn.global_transform
		body.gotHit(body.hpMax)
