extends Node

signal player_defeated(player_id: int)
signal all_players_defeated
signal ammo_shop_changed

@onready var shop_path: NodePath = NodePath("Shop")
@onready var shop: Node = get_node(shop_path)
@onready var rm = get_tree().get_first_node_in_group("round_manager")

var ammoInShopConst = 70

var _alive: Dictionary = {}        # player_id -> bool
var _player_count: int = 0
var _game_over: bool = false
var amountAmmoIncrement = 2
var amountHpIncrement = 1
var drop_chanche_powerup: float = 0.1	# non è una const siccome potrebbe variare in base alla situazione in gioco
var pointsWon = 50	# dalla sconfitta di uno zombie si guadagnano questi punti
var ammoInShop = ammoInShopConst # ogni round aggiorna il numero di munizioni
var ammo_prize = 100
var qnty_ammo = 10

@onready var audio_zombie_scream1: AudioStreamPlayer = $AudioZombieScream1
@onready var audio_zombie_scream2: AudioStreamPlayer = $AudioZombieScream2
@onready var audioBuyAmmo: AudioStreamPlayer = $AudioBuyAmmo
var random_time_screaming = randf_range(10.0, 15.0)	# tempo randomico per far partire l'audio (con probabilità)
var can_scream = false
var just_started = true
var wait_scream_at_start = 10


func _ready() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	_player_count = players.size()

	for p in players:	# registro quelli già presenti (se ce ne sono)
		var pid: int = p.get_instance_id()
		_alive[pid] = true
		if p.has_signal("defeated"):
			p.defeated.connect(_on_player_defeated)

	# registra i player che verranno istanziati dopo
	get_tree().node_added.connect(_on_node_added)
	
	rm.round_changed.connect(_on_round_changed)
	
	await get_tree().create_timer(wait_scream_at_start).timeout	# facciamo partire le urla dopo 10 sec dall'inizio
	can_scream = true


func _physics_process(_delta: float) -> void:
	if can_scream and get_tree().get_nodes_in_group("alive_player").size() > 0:
		can_scream = false
		match randi_range(0, 1):
			0:
				audio_zombie_scream1.play()
			1:
				audio_zombie_scream2.play()
		random_time_screaming = randf_range(10.0, 15.0)
		get_tree().create_timer(random_time_screaming).timeout.connect(func():
			can_scream = true
		)


func _on_node_added(n: Node) -> void:	# cosi anche se i player arrivano dopo vengono lo stesso registrati
	# quando entra un nuovo nodo nello scene tree, se è un player lo registri
	if n.is_in_group("player"):
		_register_player(n)


func _register_player(p: Node) -> void:
	var pid: int = p.get_instance_id()
	if _alive.has(pid):
		return # già registrato

	_alive[pid] = true
	_player_count += 1

	if p.has_signal("defeated"):
		p.defeated.connect(_on_player_defeated)
	else:
		push_warning("GameManager: player senza segnale 'defeated': %s" % p.name)


func get_player_count() -> int:
	return _player_count


func _on_player_defeated(pid: int) -> void:
	if _game_over:
		return
	if not _alive.has(pid) or _alive[pid] == false:
		return

	_alive[pid] = false
	player_defeated.emit(pid)	# vado da hud

	# se tutti sono sconfitti vado al finale
	for k in _alive.keys():
		if _alive[k] == true:
			return

	_game_over = true
	all_players_defeated.emit()	# se sono tutti sconfitti vado al defeat_final_panel


func _on_round_changed(_r: int) -> void:	# locko il mutex per aggiornare le ammo nello shop, magari qualcuno compra in mezzo
	var free: bool = shop.lock_mutex()
	if free:
		ammoInShop = ammoInShopConst
		ammo_shop_changed.emit(ammoInShop)
		shop.unlock_mutex()


func respawn_reset():	# resetto le impostazioni al respawn
	_game_over = false
	for pid in _alive.keys():
		_alive[pid] = true


func try_shop(playerHasInteracted: CharacterBody3D):
	# lock mutex
	var free: bool = shop.lock_mutex()
	if free:
		if playerHasInteracted.points >= ammo_prize and ammoInShop >= qnty_ammo:
			audioBuyAmmo.play()
			playerHasInteracted.change_points_amount(-ammo_prize)
			playerHasInteracted.change_ammo_amount(qnty_ammo)
			ammoInShop -= qnty_ammo
			ammo_shop_changed.emit(ammoInShop)
		else:
			print("punti insufficienti")
		shop.unlock_mutex()
		# unlock mutex
