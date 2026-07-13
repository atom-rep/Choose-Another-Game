extends Node

const num_player_allowed: int = 2

@export var player_scene: PackedScene
@export var hud_scene: PackedScene

@onready var livello: Node3D = $World/Livello

@onready var cameras: Array[Camera3D] = [
	$SplitScreen/VSplitContainer/Top/SubViewport/CamSplit1/Camera3D,
	$SplitScreen/VSplitContainer/Bottom/SubViewport/CamSplit2/Camera3D
]

@onready var viewports: Array[SubViewport] = [
	$SplitScreen/VSplitContainer/Top/SubViewport,
	$SplitScreen/VSplitContainer/Bottom/SubViewport
]

var players: Array[CharacterBody3D] = []
var huds: Array[CanvasLayer] = []


func _ready() -> void:
	var world: World3D = livello.get_world_3d()

	var pads: Array[int] = Input.get_connected_joypads()
	if pads.size() < num_player_allowed:
		#push_error("servono 2 controller connessi per lo split screen")
		get_tree().quit()
		return
	
	$World/Livello.get_viewport().disable_3d = true

	for i in range(num_player_allowed):
		var p := player_scene.instantiate() as CharacterBody3D
		p.name = "Player" + str(i + 1)
		
		var h = hud_scene.instantiate() as CanvasLayer
		h.set_my_player(p)
		p.set_my_hud(h)

		# lo aggiungo al livello (non al GameSplit)
		livello.add_child(p)
		viewports[i].add_child(h)
		players.append(p)

		# lo metto sul suo spawn
		var sp: Marker3D = livello.get_node("PlayerSpawn" + str(i + 1)) as Marker3D
		p.global_transform = sp.global_transform

		# assegno il suo controller
		p.call("set_device_id", pads[i])

		# ogni subviewport deve renderizzare lo stesso mondo
		viewports[i].world_3d = world
		cameras[i].current = true
		
		# disabilito le camere interne ai player (altrimenti renderizzano nel viewport principale, quello su)
		p.call("set_player_camera_enabled", false)
		
		p.call("set_camera", cameras[i]) # assegna cameraSplitScreen
		
		get_node("World/Livello/Player" + str(i + 1) + "/CameraPivot/CameraOffset/SpringArm3D/Camera3D").current = false

	set_process(true)

func _process(_delta: float) -> void:
	for i in range(num_player_allowed):
		# copia la trasformazione finale della camera del player (pivot+springarm inclusi)
		cameras[i].global_transform = players[i].call("get_player_camera_transform")
		players[i].call("copy_player_camera_settings_to", cameras[i])
		
