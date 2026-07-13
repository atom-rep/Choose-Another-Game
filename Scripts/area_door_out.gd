extends Area3D

@onready var door: Node = $"../SpiritHouse"
@onready var outside_spawn: Marker3D = $"../SpawnOut"

var waiting_players_id: Array[CharacterBody3D] = []
var device_players_id: Array[int] = []


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.wants_enter = false
		door.free_house(body.get_instance_id())
		body.add_to_group("alive_player")
		body.global_transform = outside_spawn.global_transform
