extends Node

signal wave_spawn_finished

@export var zombie_scene: PackedScene
@export var zombies_container_path: NodePath = NodePath("../Zombies")

@onready var zombies_container: Node = get_node(zombies_container_path)


func _ready() -> void:
	# aspetta 1 frame per sicurezza
	await get_tree().physics_frame


func spawn_wave(count: int, spawn_interval: float) -> void:
	if zombie_scene == null:
		push_error("ZombieSpawner: zombie_scene non assegnata")
		return

	var points: Array[Marker3D] = _get_spawn_points()	# dove spawnano gli zombies
	if points.is_empty():
		push_error("ZombieSpawner: nessun Marker3D trovato sotto lo spawner")
		return

	var num_spawner: int = points.size()
	var remaining: int = count
	var i: int = 0
	var spawn_index: int = 1

	while remaining > 0:
		_spawn_one(points[i], spawn_index)	# indice progressivo per il nome dello zombie
		remaining -= 1
		spawn_index += 1

		i = (i + 1) % num_spawner	# giro tutti gli spawner in round robin
		# spawno a intervalli, non di continuo
		await get_tree().create_timer(spawn_interval).timeout
		
	wave_spawn_finished.emit()


func _spawn_one(point: Marker3D, index: int) -> void:
	var z: Node3D = zombie_scene.instantiate() as Node3D
	z.name = "Zombie%d" % index
	zombies_container.add_child(z)
	z.global_transform = point.global_transform	# stessa posiz e rotaz dello spawn


func _get_spawn_points() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c in get_children():
		if c is Marker3D:
			out.append(c)
	
	return out
