extends Area3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export var gate_path: NodePath = NodePath("../ConcurrencyGate")

@onready var gate: Node = get_node(gate_path)

@onready var gm: Node = get_tree().get_first_node_in_group("game_manager")

@onready var visual = $Visual
@onready var light = $OmniLight3D
@onready var grab_audio = $GrabAudio
@onready var cooldown = grab_audio.stream.get_length()

var lock_owner_id: int = -1

@export var life_time: float = 10.0
var _picked: bool = false	# controllo se il player ha preso o no il powerup\


func _ready() -> void:
	_start_auto_despawn()
	if anim_player != null:
		anim_player.play("rotating_burger")


func _on_body_entered(body: Node) -> void:	# body è il Player
	if _picked:
		return
	if not body.is_in_group("player"):
		return

	var ok: bool = gate.player_try_acquire_mutex(body.get_instance_id())
	print("Player try_lock:", ok)
	if not ok:
		return
	
	_picked = true	# se siamo qui allora siamo sicuri che ha lockato il mutex
	
	var playerPlusAmmo := body as CharacterBody3D
	if playerPlusAmmo:
		playerPlusAmmo.change_ammo_amount(gm.amountAmmoIncrement)
	
	visual.visible = false
	light.visible = false
	grab_audio.play()
	
	# disabilita subito la pickup area così nessuno altro lo può prendere
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	gate.player_release_mutex(body.get_instance_id())
	print("Player release")

	get_tree().create_timer(cooldown).timeout.connect(func():
		get_parent().queue_free()
	)


func _start_auto_despawn() -> void:
	await get_tree().create_timer(life_time).timeout

	if _picked:
		return

	# elimino il powerup dopo life_time tempo se non è stato preso
	get_parent().queue_free()
