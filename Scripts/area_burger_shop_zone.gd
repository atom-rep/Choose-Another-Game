extends Area3D

@onready var gm: Node = get_tree().get_first_node_in_group("game_manager")

var entered_players_id: Array[CharacterBody3D] = []
var device_players_id: Array[int] = []
var can_buy_ammo = true


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		entered_players_id.append(body)
		device_players_id.append(body.device_id)	# anche se è con mouse e tastiera non cambia nulla
		body.mioHud.show_button_burg_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		entered_players_id.erase(body)
		device_players_id.erase(body.device_id)
		body.mioHud.show_button_burg_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_buy_ammo:
		for playerHasInteracted in entered_players_id:
			if playerHasInteracted.use_gamepad:
				if playerHasInteracted.device_id == event.device:
					print("puoi")
					can_buy_ammo = false
					# chiama la funzione gm
					gm.try_shop(playerHasInteracted)
					get_tree().create_timer(2).timeout.connect(func():	# aspettiamo 3 secondi prima di consentire un successivo acquisto
						can_buy_ammo = true
					)
			else:
				print("puoi")
				can_buy_ammo = false
				# chiama la funzione gm
				gm.try_shop(playerHasInteracted)
				get_tree().create_timer(2).timeout.connect(func():	# aspettiamo 3 secondi prima di consentire un successivo acquisto
					can_buy_ammo = true
				)
