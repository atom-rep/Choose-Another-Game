extends Area3D

var list_players_id: Array[CharacterBody3D] = []
var pap_prize = 5000
var boost_damage = 1
var can_pap = true
@onready var pap_audio: AudioStreamPlayer = $"../PapAudio"
@onready var cooldown = pap_audio.stream.get_length()	# aspetto la durata dell'audio per poter rifare il pap


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.mioHud.pap_label.visible = true
	list_players_id.append(body)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_pap:
		for plr in list_players_id:
			if plr.use_gamepad:
				if plr.device_id == event.device:	# matcho il device che ha clickato con i player che ho
					if plr.points >= pap_prize:
						can_pap = false
						plr.change_points_amount(-pap_prize)
						pap_audio.play()
						plr.pap_gun(boost_damage)
						get_tree().create_timer(cooldown).timeout.connect(func():
							can_pap = true
						)
			else:	# se non sono da pad sono da solo
				if plr.points >= pap_prize:
					can_pap = false
					plr.change_points_amount(-pap_prize)
					pap_audio.play()
					plr.pap_gun(boost_damage)
					get_tree().create_timer(cooldown).timeout.connect(func():
						can_pap = true
					)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	body.mioHud.pap_label.visible = false
	list_players_id.erase(body)
