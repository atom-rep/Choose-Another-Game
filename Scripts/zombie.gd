extends CharacterBody3D

const ATTACK_RANGE = 1.5

@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree

@onready var gm: Node = get_tree().get_first_node_in_group("game_manager")

@export var health: int = 5
@export var blend_speed: float = 15.0

@onready var players = get_tree().get_nodes_in_group("alive_player")
@onready var kill_arbiter: Node = get_tree().get_first_node_in_group("kill_arbiter")

var SPEED: float = 5
var damage = 1

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

enum AnimState { IDLE, RUN, ATTACK, DIE }
var cur_anim: AnimState = AnimState.IDLE

var run_val: float = 0.0
var attack_active: bool = false
var dying: bool = false

@export var pizza_powerup_scene: PackedScene
@export var burger_powerup_scene: PackedScene
@onready var powerups_root: Node = $"../../../PowerUps"

@onready var attack_audio1: AudioStreamPlayer = $AttackAudios/AttackAudio1
@onready var attack_audio2: AudioStreamPlayer = $AttackAudios/AttackAudio2


func _ready() -> void:
	# disabiliti _physics_process(), poi defer una chiamata di dump_first_physics_frame() fino al termine dell'elaborazione di questo fotogramma
	set_physics_process(false)
	call_deferred("dump_first_physics_frame")
	
	
func dump_first_physics_frame() -> void:
	# attendi fino a prima che il secondo physics_frame (dopo l'aggiunta del menù è il terzo frame) sia pronto per l'esecuzione, poi riattivi _physics_process()
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_physics_process(true)


func _physics_process(delta: float) -> void:	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1 # valore piccolo per restare al pavimento
		
	if dying:	# se lo zombie muore non fare nulla
		return

	players = get_tree().get_nodes_in_group("alive_player")
	if players.is_empty():	# se non c'è nessuno non corri, stai idle
		cur_anim = AnimState.IDLE
		_handle_animations(delta)
		return
	
	var best: Node3D = players[0] as Node3D	# inizializzo con il primo valore
	var best_d2: float = global_position.distance_squared_to(best.global_position)

	for j in range(1, players.size()):
		var p: Node3D = players[j] as Node3D
		var d2 := global_position.distance_squared_to(p.global_position)
		if d2 < best_d2:	# seguo il player più vicino a me (io zombie)
			best_d2 = d2
			best = p

	nav_agent.set_target_position(best.global_position)	# seguo questo
	
	var next_location = nav_agent.get_next_path_position()	# seguo la prossima posizione del path per raggiungerlo
	var current_location = global_transform.origin

	# la navigazione deve muovere SOLO su X/Z, altrimenti alcuni zombie seguono la Y del path e fluttuano
	var dir = next_location - current_location	# vettore orizzontale che punta dalla posizione attuale dello zombie al prossimo punto del path
	dir.y = 0.0

	var new_velocity := Vector3.ZERO
	if dir.length_squared() > 0.000001:	# muoviti verso il prossimo punto solo se è abbastanza distante, altrimenti resta fermo (un epsilon controllabile da me)
		new_velocity = dir.normalized() * SPEED
	
	var next_nav_point = nav_agent.get_next_path_position()
	
	if next_nav_point.x != global_position.x or next_nav_point.z != global_position.z:	# evito di generare l'errore quando sono uguali
		look_at(Vector3(next_nav_point.x, global_position.y, next_nav_point.z), Vector3.UP)	# lo zombie guarda il prossimo punto per seguire il player quando corre

	# velocità orizzontale
	velocity.x = lerp(velocity.x, new_velocity.x, 0.25)
	velocity.z = lerp(velocity.z, new_velocity.z, 0.25)
	
	move_and_slide()
	
	attack_active = bool(anim_tree.get("parameters/Attackshot/active"))
	for playerCounter in players:
		if global_position.distance_to(playerCounter.global_position) < ATTACK_RANGE:	# se è nel range attacco
			if not attack_active:
				anim_tree.set("parameters/Attackshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			cur_anim = AnimState.ATTACK
		else:
			cur_anim = AnimState.RUN
		
	_handle_animations(delta)


func _handle_animations(delta: float) -> void:
	match cur_anim:
		AnimState.IDLE:
			run_val = lerpf(run_val, 0.0, blend_speed * delta)
		AnimState.RUN:
			run_val = lerpf(run_val, 1.0, blend_speed * delta)
		AnimState.ATTACK:
			run_val = lerpf(run_val, 0.0, blend_speed * delta)
		AnimState.DIE:
			run_val = lerpf(run_val, 0.0, blend_speed * delta)

	anim_tree["parameters/Run/blend_amount"] = run_val


func take_damage(amount: int = 1, attacker_id: int = -1) -> void:
	if dying:
		return

	var prev_hp: int = health
	health -= amount

	# se era già morto prima, non fare niente
	if prev_hp <= 0:
		return

	# quando muore
	if health <= 0:
		dying = true
		velocity = Vector3.ZERO	# velcità 0
		# disabilita collisioni subito
		collision_layer = 0
		collision_mask = 0
		
		var posiz_zombie = global_position

		# qui fai la claim protetta dal mutex
		var zid: int = get_instance_id()
		var claimed: bool = kill_arbiter.try_claim_kill(zid, attacker_id)

		if claimed:
			print("PREMIO al player:", attacker_id)
			var playerWinner: CharacterBody3D = instance_from_id(attacker_id) as CharacterBody3D
			playerWinner.change_points_amount(gm.pointsWon)
		else:
			print("Premio già assegnato")

		# avvia animazione morte e poi queue_free
		anim_tree.set("parameters/Dieshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
		# aspetta fine animazione
		var guard: int = 0
		while guard < 30 and not bool(anim_tree.get("parameters/Dieshot/active")):	# almeno 30 frame per sicurezza
			await get_tree().process_frame
			guard += 1
		
		while is_inside_tree() and bool(anim_tree.get("parameters/Dieshot/active")):	# controlla se è dentro l'albero dei nodi
			await get_tree().process_frame
		
		if randf() <= gm.drop_chanche_powerup:	# 50 e 50 tra pizza e burger
			if randf() <= 0.5:	# spawno la pizza
				spawn_powerup(posiz_zombie, "Pizza")
			else:	# spawno il burger
				spawn_powerup(posiz_zombie, "Burger")
		
		kill_arbiter.forget(zid)	# pulisce la memoria del suo id, utile se c'è riutilizzo dello stesso id
		queue_free()


func attack_player():
	for playerCounter in players:
		if global_position.distance_to(playerCounter.global_position) < ATTACK_RANGE:	# ricontrollo se è nel range prima dell'effettivo attacco, utile se il player scappa mentre lo zombie attacca
			match randi_range(0, 1):
				0:
					attack_audio1.play()
				1:
					attack_audio2.play()
			playerCounter.gotHit(damage)


func spawn_powerup(world_pos: Vector3, oggetto: String) -> void:
	
	var _count = get_instance_id()

	# creo il contenitore pizza o burger e lo piazzo dove era lo zombie
	var wrapper := Node3D.new()
	wrapper.name = oggetto + str(_count)
	powerups_root.add_child(wrapper)
	wrapper.global_position = world_pos

	# creo il ConcurrencyGate come figlio del contenitore
	var gate := ConcurrencyGate.new()
	gate.name = "ConcurrencyGate"
	wrapper.add_child(gate)

	var pickup
	# istanzio la scena del powerup e la metto come figlia del contenitore
	if oggetto == "Pizza":
		pickup = pizza_powerup_scene.instantiate() as Area3D
	if oggetto == "Burger":	
		pickup = burger_powerup_scene.instantiate() as Area3D
	
	pickup.name = "Area" + oggetto + "PowerUp"
	wrapper.add_child(pickup)
	pickup.position = Vector3.ZERO  # sta sul wrapper
