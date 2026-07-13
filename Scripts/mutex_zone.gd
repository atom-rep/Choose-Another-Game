extends Area3D

@export var wall_path: NodePath = NodePath("../Muro")
@export var gate_path: NodePath = NodePath("..")

@onready var wall: StaticBody3D = get_node(wall_path) as StaticBody3D
@onready var gate: Node = get_node(gate_path)
@onready var wall_shape: CollisionShape3D = wall.get_node("CollisionShape3D") as CollisionShape3D
@onready var not_allowed_teleport: Marker3D = $"../NotAllowedTeleport"
@onready var secure_zone_timer: Timer = $"../SecureZoneTimer"
var time_allowed_in = 20
var current_player_in = null
var lock_owner_id: int = -1
var zone_protected_cost = 1000


func _ready() -> void:
	_set_wall_enabled(false)
	secure_zone_timer.wait_time = time_allowed_in	# setto il tempo massimo che puoi stare nella zona
	secure_zone_timer.one_shot = true


func _set_wall_enabled(enabled: bool) -> void:
	# collisione
	wall_shape.set_deferred("disabled", not enabled)


func _on_secure_zone_timer_timeout() -> void:
	print("timer SCADUTO")
	current_player_in.global_transform = not_allowed_teleport.global_transform
	reset_secure_zone(current_player_in)
	current_player_in = null


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var ok: bool = gate.player_try_acquire_mutex(body.get_instance_id())
	if not ok:
		body.global_transform = not_allowed_teleport.global_transform
		return

	if body.points < zone_protected_cost:
		body.global_transform = not_allowed_teleport.global_transform
		reset_secure_zone(body)
		return

	body.change_points_amount(-zone_protected_cost)

	lock_owner_id = body.get_instance_id()
	_set_wall_enabled(true)
	current_player_in = body
	secure_zone_timer.start()


func reset_secure_zone(bodyPlayer: CharacterBody3D):
	gate.player_release_mutex(bodyPlayer.get_instance_id())
	print("Player release")
	lock_owner_id = -1
	_set_wall_enabled(false)


func _on_body_exited(body: Node) -> void:
	if lock_owner_id == -1:
		return
	if body.get_instance_id() != lock_owner_id:
		return
	
	if not secure_zone_timer.is_stopped():
		secure_zone_timer.stop()
		print("timer stoppato sei uscito PRIMA")
	
	reset_secure_zone(body)
