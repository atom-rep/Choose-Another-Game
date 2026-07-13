extends Area3D

@onready var door: Node = $"../SpiritHouse"
@onready var inside_spawn: Marker3D = $"../SpawnIn"

var waiting_players: Array[CharacterBody3D] = []
var device_players_id: Array[int] = []


func _ready() -> void:
	door.enter_allowed.connect(_on_enter_allowed)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		waiting_players.append(body)
		device_players_id.append(body.device_id)
		body.mioHud.show_button_enter_house.visible = true
		body.wants_enter = false
		print(body.get_instance_id())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		for playerHasInteracted in waiting_players:
			playerHasInteracted.wants_enter = true
			if playerHasInteracted.use_gamepad:
				if playerHasInteracted.device_id == event.device:
					door.request_house(playerHasInteracted.get_instance_id())
			else:	# se sei da tastiera ci sei solo tu
				door.request_house(playerHasInteracted.get_instance_id())


func _on_enter_allowed(id: int):
	var remove_player = null
	
	for player in waiting_players:
		if player.get_instance_id() == id:
			player.mioHud.show_button_enter_house.visible = false
			player.global_transform = inside_spawn.global_transform
			remove_player = player
	waiting_players.erase(remove_player)
	
	remove_player.remove_from_group("alive_player")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.mioHud.show_button_enter_house.visible = false
		if body.wants_enter == false:
			waiting_players.erase(body)
