extends Node

signal round_changed(round: int)

@export var zombie_spawner_path: NodePath
@export var enemy_group: StringName = &"zombie"

@export var start_round: int = 1
@export var base_zombies: int = 5
@export var zombies_per_round: int = 2
@export var spawn_interval: float = 1.0
@export var inter_round_delay: float = 3.0

@onready var gm: Node = get_tree().get_first_node_in_group("game_manager")
@onready var zombie_spawner: Node = get_node(zombie_spawner_path)

var _round: int = 1
var _running: bool = true


func _ready() -> void:
	_round = start_round
	call_deferred("_loop_rounds")


func _exit_tree() -> void:
	_running = false


func _zombies_for_round(r: int) -> int:
	return base_zombies + (r - 1) * zombies_per_round


func _alive_enemies() -> int:
	return get_tree().get_nodes_in_group(enemy_group).size()


func _loop_rounds() -> void:
	await get_tree().process_frame

	while _running:
		var players = get_tree().get_nodes_in_group("player")
		
		var count: int = _zombies_for_round(_round)
		round_changed.emit(_round)
		
		await get_tree().create_timer(inter_round_delay).timeout

		# fai spawnare allo spawner (lui gestisce tempi di spawn e distribuzione di dove spawnano)
		zombie_spawner.spawn_wave(count, spawn_interval)

		# aspetta che lo spawner finisca di spawnare tutti quelli del round
		await zombie_spawner.wave_spawn_finished

		# aspetta che muoiano tutti gli enemy
		while _running and _alive_enemies() > 0:
			await get_tree().process_frame
		
		_round += 1
		
		gm.respawn_reset()
		for i in range(players.size()):	# respawn di chi ha perso
			if players[i].is_defeated == true:
				var spawn_point: Marker3D = get_node("../PlayerSpawn" + str(i + 1)) as Marker3D
				players[i].respawn(spawn_point.global_transform)


func get_round() -> int:
	return _round
