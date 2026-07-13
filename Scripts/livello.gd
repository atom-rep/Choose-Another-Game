extends Node3D

@export var player_scene: PackedScene
@export var hud_scene: PackedScene

var playerSolo: CharacterBody3D
var hudSolo: CanvasLayer

@onready var dummy_camera: Camera3D = $dummyCamera


func _ready() -> void:
	dummy_camera.cull_mask = 0 # non renderizza niente
	
	if get_parent().name == "root":
		dummy_camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		playerSolo = player_scene.instantiate() as CharacterBody3D
		hudSolo = hud_scene.instantiate() as CanvasLayer
		hudSolo.set_my_player(playerSolo)
		playerSolo.set_my_hud(hudSolo)
		playerSolo.name = "Player1"
		add_child(playerSolo)
		add_child(hudSolo)
		playerSolo.global_transform = get_node("PlayerSpawn1").global_transform
		
	$HUD_livello/Fade_transition/AnimationPlayer.play("fade_out")
	var anim_name = await $HUD_livello/Fade_transition/AnimationPlayer.animation_finished
	if anim_name == "fade_out":	# elimino il nodo quando finisce l'animazione
		$HUD_livello/Fade_transition.queue_free()
	randomize()	# cambia seme per il random
