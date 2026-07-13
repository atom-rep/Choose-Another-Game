extends CharacterBody3D

signal defeated(player_id: int)	# emetto il segnale quando vengo sconfitto
signal hp_changed(hp: int)	# emetto il segnale quando varia il mio hp per HUD
signal ammo_changed(ammo: int)
signal points_changed(points: int)
signal papped(boost_damage: int)

const SPEED: float = 6.0
var speedSprint: float = SPEED
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.0015
const hpMax = 5

@export var hit_effect_flare: PackedScene

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

@export var blend_speed: float = 15.0

var is_defeated: bool = false
var hp = hpMax
var ammo = 30	# quanti munizioni ha
var amountAmmoShooted = -1	# quanti proiettili spreca ad ogni colpo
var points = 50000
var damage = 1
var enemy_group = "zombie"

var _default_collision_layer: int
var _default_collision_mask: int

enum AnimState { IDLE, RUN, JUMP }
var cur_anim: AnimState = AnimState.IDLE

var run_val: float = 0.0
var jump_active: bool = 0

var spine_idx: int = -1
var chest_idx: int = -1
var aim_pitch: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot	# nodo che ruota su/giù, è separato dal player per evitare che inclini tutto il corpo
@onready var camera_player: Camera3D = $CameraPivot/CameraOffset/SpringArm3D/Camera3D

@onready var anim_tree: AnimationTree = $playerDonna/AnimationTree
@onready var skeleton: Skeleton3D = $playerDonna/Armature/Skeleton3D

@onready var target = $"."

@onready var spring_arm: SpringArm3D = $CameraPivot/CameraOffset/SpringArm3D
@onready var miraRayCast = $CameraPivot/CameraOffset/SpringArm3D/Camera3D/RayCast3D
@onready var gun_sound: AudioStreamPlayer = $"playerDonna/Armature/Skeleton3D/BoneAttachment3D/Rifle/SoundGun"
@onready var no_ammo_sound: AudioStreamPlayer = $"playerDonna/Armature/Skeleton3D/BoneAttachment3D/Rifle/NoAmmoSound"
var can_shoot = true
@onready var cooldown = gun_sound.stream.get_length() - 0.55 # 550 ms prima della fine, utile per avere un rateo di fuoco controllato e non spammare (sia con e senza ammo)

@export var aim_max_deg_up: float = 15.0	#quanto si piega il player verso l'alto quando alza la visuale
@export var aim_max_deg_down: float = 20.0
@export var spine_factor: float = 0.15	# somma ad 1 delle ossa, chi si piega di più
@export var chest_factor: float = 0.85

@export var player_id: int = get_instance_id()

var random_time_speech = randf_range(8.0, 15.0)
@onready var running_effect: AudioStreamPlayer = $RunningEffect
@onready var low_ammo_audio: AudioStreamPlayer = $SpeechAudios/lowAmmoAudio
var lowAmmoPlayed = false
var can_speech = true
@onready var kill_audio1: AudioStreamPlayer = $SpeechAudios/KillAudio1
@onready var kill_audio2: AudioStreamPlayer = $SpeechAudios/KillAudio2
@onready var kill_audio3: AudioStreamPlayer = $SpeechAudios/KillAudio3
@onready var kill_audio4: AudioStreamPlayer = $SpeechAudios/KillAudio4

# SPLIT SCREEN
const PAD_LOOK_SENS: float = 2.5
var temp_sens_pad: float = PAD_LOOK_SENS
const DEADZONE: float = 0.2
var use_gamepad: bool = false
var device_id: int = -1
var cameraSplitScreen: Camera3D

var wants_enter = false

var _jump_requested: bool = false
var _shoot_requested: bool = false
var shoot_held: bool = false	# per automatizzare i colpi

var mioHud: CanvasLayer


func _ready() -> void:
	spring_arm.add_excluded_object(get_rid())	# non collide con se stesso
	spine_idx = skeleton.find_bone("spine")	# cerca l'osso spine, se non lo trova rimane -1 e la funzione di mira busto non fa nulla
	chest_idx = skeleton.find_bone("chest")
	jump_active = bool(anim_tree["parameters/Jumpshot/active"])	# inizializzo la variabile utilizzata per attivare il salto
	
	miraRayCast.add_exception(self)	# non rileva se stesso
	
	# utili per respawn, me li salvo in advance
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask


func _process(_delta: float) -> void:	# gira ogni frame
	_apply_upper_body_aim()	# pieghi il busto e petto in base a come si muove la visuale, modifica le animazioni
	get_tree().call_group("zombie", "target_position", target.global_transform.origin)
	
	if use_gamepad:
		var rx := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)

		if abs(rx) < DEADZONE: rx = 0.0
		if abs(ry) < DEADZONE: ry = 0.0

		rotate_y(-rx * temp_sens_pad * _delta)

		camera_pivot.rotate_x(-ry * temp_sens_pad * _delta)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))	# muove max 80 e -80 gradi
		aim_pitch = camera_pivot.rotation.x
		
		if miraRayCast.is_colliding():	# per la mira assistita, solo da pad ovviamente
			var obj = miraRayCast.get_collider()	# prendo cosa sto mirando tramite raycast
			if obj.is_in_group("zombie") and Input.is_action_pressed("aiming"):
				temp_sens_pad = PAD_LOOK_SENS/5	# valuto se farlo anche con la velocità, non voglio rendere il gioco troppo facile
			else:
				if temp_sens_pad != PAD_LOOK_SENS:
					temp_sens_pad = PAD_LOOK_SENS


func set_device_id(id: int) -> void:
	device_id = id
	use_gamepad = true


func set_camera(c: Camera3D) -> void:
	cameraSplitScreen = c


func set_my_hud(hud_taken: CanvasLayer):
	mioHud = hud_taken


func _get_aim_camera() -> Camera3D:
	return cameraSplitScreen if cameraSplitScreen != null else camera_player	# se non è nullo allora siamo in splitscreen, prendo quelle camere


func _unhandled_input(event: InputEvent) -> void:
	if use_gamepad:
		if event is InputEventJoypadButton and event.device == device_id:
			if event.is_action_pressed("jump"):
				_jump_requested = true
			if event.is_action_pressed("shoot"):
				_shoot_requested = true
				shoot_held = true
			if event.is_action_released("shoot"):
				shoot_held = false
	else:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)	# ruota il player dx e sx

			camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)	# ruota il player su e giu
			camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))	# ruota il player su e giu, clapf è una funzione che limita un valore float tra un min e max, limita il 1o argomento tra il 2o e 3o
			aim_pitch = camera_pivot.rotation.x	# salvi il valore che usi in _apply_spine_aim()

		if event.is_action_pressed("ui_cancel"):	# per liberare il mouse con ESC
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:	# se il mouse era libero lo ricattura, ma non spara
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				return

		if Input.is_action_pressed("shoot"):	# spara
			_shoot_requested = true
			shoot_held = true
		if event.is_action_released("shoot"):
			shoot_held = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():	# se il player è in aria aggiunge la gravità
		velocity.y -= gravity * delta

	# input_dir da gamepad o tastiera
	var input_dir: Vector2
	if use_gamepad:
		var lx := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		if abs(lx) < DEADZONE: lx = 0.0
		if abs(ly) < DEADZONE: ly = 0.0
		input_dir = Vector2(lx, ly)
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")	# restituisce un Vector2, per muoversi avanti, indietro, dx e sx, es. se premi W input_dir = Vector2(0, -1), es. se premi W+D input_dir = Vector2(1, -1) (diagonale)

	# direzione 3D
	var direction: Vector3 = transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)	# converti l'input 2d in 3d, asse X e Z, non Y (siccome cammini); transform basis: se il player ruota a dx o sx col mouse, anche W cambia direzione nel mondo quindi ti fa andare avanti col personaggio, non verso nord
	direction.y = 0.0
	direction = direction.normalized()	# normalizzo per avere la stessa velocità anche in diagonale, es. se premi W+D, il vettore grezzo è (1,0,-1) che ha lunghezza ~1.414, normalizzandolo diventa lungo 1, quindi stessa velocità

	# salto : con tastiera qui; per il pad gestiscilo con _jump_requested
	if not use_gamepad:
		if Input.is_action_just_pressed("jump") and is_on_floor() and not jump_active:	# se sei a terra e salti ti aggiunge velocità verticale
			velocity.y = JUMP_VELOCITY
			anim_tree.set("parameters/Jumpshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# movimento (per entrambi)
	if direction.length() > 0.0:	# controlla se c'è un input
		velocity.x = direction.x * speedSprint
		velocity.z = direction.z * speedSprint
	else:	# se non c'è input rallenti gradualmente
		velocity.x = move_toward(velocity.x, 0.0, speedSprint)	# move_toward(current, target, amount) avvicina current a target di amount per frame
		velocity.z = move_toward(velocity.z, 0.0, speedSprint)

	jump_active = bool(anim_tree.get("parameters/Jumpshot/active"))
	
	if Input.is_action_just_pressed("sprint"):	# per sprintare
		speedSprint = SPEED * 1.5
	if Input.is_action_just_released("sprint"):
		speedSprint = SPEED

	if use_gamepad:
		if _jump_requested and is_on_floor() and not jump_active:
			velocity.y = JUMP_VELOCITY
			anim_tree.set("parameters/Jumpshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_jump_requested = false

		if (_shoot_requested or shoot_held) and can_shoot:
			can_shoot = false
			_shoot_hitscan()
		_shoot_requested = false
	else:	# stessa logica di sparo anche da tastiera
		if (_shoot_requested or shoot_held) and can_shoot:
			can_shoot = false
			_shoot_hitscan()
		_shoot_requested = false	#serve se spari un colpo, così lo prende subito l'input

	_update_crosshair_raycast()
	move_and_slide()	# usa velocity per muovere il CharacterBody3D, gestisce collisioni e scivolamenti e aggiorna informazioni come is_on_floor(), funzione dell'editor

	# stato animazioni
	if jump_active:
		cur_anim = AnimState.JUMP
		if running_effect.is_playing():
			running_effect.stop()
	elif input_dir.length() > 0.0:
		cur_anim = AnimState.RUN
		if not running_effect.is_playing():
			running_effect.play()
	else:
		cur_anim = AnimState.IDLE
		if running_effect.is_playing():
			running_effect.stop()

	_handle_animations(delta)	# usa cur_anim per portare gradualmente i valori run_val a 0 o 1 e li scrive nell’AnimationTree


func _handle_animations(delta: float) -> void:
	match cur_anim:	# cambio di animazione più smussato, in base a blend_speed
		AnimState.IDLE:
			run_val = lerpf(run_val, 0.0, blend_speed * delta)
		AnimState.RUN:
			run_val = lerpf(run_val, 1.0, blend_speed * delta)
		AnimState.JUMP:
			run_val = lerpf(run_val, 0.0, blend_speed * delta)

	# aggiorni i valori all'AnimationTree
	anim_tree["parameters/Run/blend_amount"] = run_val


func _apply_upper_body_aim() -> void:
	var pitch: float = clampf(aim_pitch, deg_to_rad(-aim_max_deg_down), deg_to_rad(aim_max_deg_up))	# il busto non deve piegarsi tanto quanto la camera, quindi solo un tot di gradi

	# se uno dei due non esiste, semplicemente salta quell’override
	if spine_idx != -1:
		_apply_bone_pitch(spine_idx, -pitch * spine_factor)

	if chest_idx != -1:
		_apply_bone_pitch(chest_idx, -pitch * chest_factor)


func _apply_bone_pitch(bone_idx: int, amount: float) -> void:
	var t: Transform3D = skeleton.get_bone_global_pose_no_override(bone_idx)	# prende la posa delle animazioni senza gli override, così non le cumula all'infinito
	t.basis = t.basis * Basis(Vector3.RIGHT, amount) # il meno è se va al contrario, è la rotazione attorno all’asse x
	skeleton.set_bone_global_pose_override(bone_idx, t, 1.0, true)	# applica l’override con peso 1 (massimo) e persistente (rimane finché non è aggiornato)


# è un raycast dal centro schermo, se colpisce un nodo appartenente (o che ha un parent) nel gruppo "zombie" lo elimina
func _shoot_hitscan() -> void:
	if ammo == 0:
		if not lowAmmoPlayed:	# evito di spammare l'audio
			low_ammo_audio.play()
			lowAmmoPlayed = true
		no_ammo_sound.play()
		get_tree().create_timer(max(cooldown, 0.0)).timeout.connect(func():
			can_shoot = true
		)
		return
	
	lowAmmoPlayed = false	# quando ricarica e poi finisce le ammo nuovamente allora può ripartire questo audio
	gun_sound.play()
	get_tree().create_timer(max(cooldown, 0.0)).timeout.connect(func():	# il rateo di fuoco è dato da la lunghezza dell'audio
		can_shoot = true
	)
	
	change_ammo_amount(amountAmmoShooted)
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state	# prendo accesso al motore fisico del mondo 3d, prendo il mondo3d.mi permette di capire cosa colpisco con un raggio

	var cam: Camera3D = _get_aim_camera()	# prendo la camera

	# prendo la posizione schermo del mirino (pixel reali)
	var screen_pos: Vector2
	if mioHud.miraCentrale != null:
		# in split-screen il Control può non essere nello stesso viewport della camera, quindi è più sicuro usare il centro del viewport della camera
		var vp: Viewport = cam.get_viewport()	# il viewport in cui quella camera sta renderizzando
		screen_pos = vp.get_visible_rect().size * 0.5	# metà larghezza e metà altezza = centro in pixel

	# costruisco il raggio 3D dalla camera passando per quel pixel
	var origin: Vector3 = cam.project_ray_origin(screen_pos)	# punto di partenza del raggio in 3d, la posizione della camera
	var dir: Vector3 = cam.project_ray_normal(screen_pos)	# direzione in 3D del raggio che passa per quel pixel
	var end: Vector3 = origin + dir * float(miraRayCast.target_position.length()) # il punto finale del raggio è 100, spari fino a 100 metri, il punto finale del raycast e length() dà quanti metri è lungo il raycast

	# raycast
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)	# una query dal punto origin al punto end
	query.exclude = [self]	# evita che il raggio colpisca il player stesso

	var hit: Dictionary = space_state.intersect_ray(query)	# è un raycast istantaneo fatto via codice (utile per lo sparo siccome non dipende dall'aggiornamento del nodo raycast che già ho), ti ritorna un dizionario con le info
	if hit.is_empty():	# se non colpisci nulla esci
		return
	
	var fx := hit_effect_flare.instantiate() as Node3D
	get_tree().current_scene.add_child(fx)
	fx.global_position = hit["position"]	# istanzio l'effetto flare nel punto dove colpisco
	get_tree().create_timer(0.3).timeout.connect(func():	# 0.3 durata del hit effect
		fx.queue_free()
	)

	# prendo il collider (l'oggetto colpito) e cerco lo zombie risalendo i parent
	var collider_node: Node = hit["collider"] as Node
	if collider_node == null:
		return

	var nemico: Node = collider_node
	while nemico != null and not nemico.is_in_group(enemy_group):	# risalgo i parent fino a che non lo trovo, perch magari colpisco un nodo figlio ad es. la collisionshape
		nemico = nemico.get_parent()

	if nemico == null:	# non hai preso lo zombie, diventa null siccome arrivi alla root, ad es. quando colpisci un muro (non è uno zombie)
		return

	# l'ho preso e applico danno hp
	nemico.call("take_damage", damage, player_id)
	var speech_rand = randf()
	if speech_rand <= 0.20 and can_speech:	# se può parlare ha 20% di possibilità di farlo ad ogni colpo preso
		can_speech = false
		
		match randi_range(0, 3):
			0:
				kill_audio1.play()
			1:
				kill_audio2.play()
			2:
				kill_audio3.play()
			3:
				kill_audio4.play()
		
		get_tree().create_timer(random_time_speech).timeout.connect(func():
			random_time_speech = randf_range(8.0, 15.0)	# aspetto un tempo random per poter riparlare, evita di parlare di continuo
			can_speech = true
		)


func _update_crosshair_raycast() -> void:	# qui non stai sparando: stai solo allineando il nodo RayCast3D alla direzione del mirino/camera
	var cam: Camera3D = _get_aim_camera()

	# centro reale del mirino in pixel
	var vp: Viewport = cam.get_viewport()
	var screen_pos: Vector2 = vp.get_visible_rect().size * 0.5

	# raggio 3D che passa esattamente per quel pixel
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)

	# posiziona il raycast all'origine del raggio e orientalo verso la direzione
	miraRayCast.global_position = origin
	miraRayCast.look_at(origin + dir, Vector3.UP)


# tengo queste funzioni separate e non astratte siccome potrebbero subire variazioni significative
func change_hp_amount(amountHp: int):
	hp = min(hp + amountHp, hpMax)	# puoi avere massimo hpMax
	hp_changed.emit(hp)


func change_ammo_amount(amountAmmo: int):
	ammo += amountAmmo
	ammo_changed.emit(ammo)


func change_points_amount(amountPoints: int):
	points += amountPoints
	points_changed.emit(points)


func pap_gun(boost_damage: int):
	damage += boost_damage
	papped.emit(damage)


func gotHit(damage_taken):
	if is_defeated:
		return
	
	hp = max(hp - damage_taken, 0)	# così non vado sotto 0
	hp_changed.emit(hp)
	
	if hp == 0:
		# non targettabile dagli zombie
		remove_from_group("alive_player")
		
		$playerDonna.visible = false
		
		collision_layer = 0
		collision_mask = 0
	
		is_defeated = true
		defeated.emit(get_instance_id())	# vado da game_manager

		# blocca input e movimento
		set_process_input(false)
		set_process_unhandled_input(false)
		set_physics_process(false)
		running_effect.stop()	# tolgo i suoni che potrebbe emettere


func get_player_camera_transform() -> Transform3D:
	return camera_player.global_transform


func copy_player_camera_settings_to(cam: Camera3D) -> void:
	cam.fov = camera_player.fov
	cam.near = camera_player.near
	cam.far = camera_player.far


func set_player_camera_enabled(enabled: bool) -> void:
	camera_player.current = enabled


func respawn(spawn_transform: Transform3D) -> void:
	# ripristino stato
	is_defeated = false

	# HP
	hp = hpMax
	change_hp_amount(hp)

	# torna targettabile
	add_to_group("alive_player")

	# visibilità
	$playerDonna.visible = true

	# collisioni
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask

	# riattiva input e fisica
	set_process_input(true)
	set_process_unhandled_input(true)
	set_physics_process(true)

	# posizione e movimento
	velocity = Vector3.ZERO
	global_transform = spawn_transform
	
	mioHud.local_panel.visible = false
