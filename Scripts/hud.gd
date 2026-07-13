extends CanvasLayer

@export var cell_size: Vector2 = Vector2(80, 60)
@export var cell_gap: int = 6
@export var color_full: Color = Color(0.794, 0.022, 0.176)   # colore quando hai la vita
@export var color_empty: Color = Color(0.326, 0.021, 0.049)  # colore quando la perdi
@onready var hp_box: HBoxContainer = $MarginContainer/HBoxContainer

@onready var gm: Node = get_tree().get_first_node_in_group("game_manager")
@onready var rm = get_tree().get_first_node_in_group("round_manager")
@onready var pn = get_tree().get_first_node_in_group("pause_node")

@onready var round_label: Label = $roundNumber
@onready var ammo_label: Label = $ammoLabel
@onready var points_label: Label = $pointsLabel
@onready var show_button_burg_label: Label = $showButtonBurgLabel
@onready var ammo_left_burg_label: Label = $showButtonBurgLabel/ammoLeftBurgLabel
@onready var miraCentrale = $CenterContainer/Control
@onready var local_panel: Control = $DefeatLocalPanel
@onready var show_button_enter_house: Label = $showButtonEnterHouse
@onready var pause_label: Label = $PauseLabel
@onready var pap_label: Label = $PackAPunchLabel
@onready var lvl_gun: Label = $GunLvl

var mioPlayer: CharacterBody3D


func _ready() -> void:
	local_panel.visible = false
	show_button_burg_label.visible = false
	show_button_enter_house.visible = false
	pause_label.visible = false
	pap_label.visible = false

	if gm == null:
		push_error("HUD: GameManager non trovato nella scena corrente (nodo 'GameManager').")
		return

	pn.pause_game.connect(_on_pause_game)
	
	gm.player_defeated.connect(_on_player_defeated)
	
	gm.ammo_shop_changed.connect(_on_ammo_shop_changed)
	_on_ammo_shop_changed(gm.ammoInShop)
	
	rm.round_changed.connect(_on_round_changed)
	_on_round_changed(rm.get_round()) # aggiorna subito
	
	_build_cells()
	set_hp_bar(mioPlayer.hpMax)
	
	mioPlayer.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(mioPlayer.hp)
	
	mioPlayer.ammo_changed.connect(_on_ammo_changed)
	_on_ammo_changed(mioPlayer.ammo)
	
	mioPlayer.points_changed.connect(_on_points_changed)
	_on_points_changed(mioPlayer.points)

	mioPlayer.papped.connect(_on_papped)
	_on_papped(mioPlayer.damage)


func _build_cells() -> void:
	# pulizia
	for c in hp_box.get_children():
		c.queue_free()

	# crea i quadratini
	for i in range(mioPlayer.hpMax):
		var cell := ColorRect.new()
		cell.custom_minimum_size = cell_size
		cell.color = color_empty
		hp_box.add_child(cell)


func set_hp_bar(value: int) -> void:
	mioPlayer.hp = clamp(value, 0, mioPlayer.hpMax)
	for i in range(mioPlayer.hpMax):
		var cell := hp_box.get_child(i) as ColorRect
		cell.color = color_full if i < mioPlayer.hp else color_empty	# se ho effettivamente quel hp allora lo mostro altrimenti no


func _on_pause_game() -> void:
	pause_label.visible = !pause_label.visible


func _on_hp_changed(hp: int) -> void:
	set_hp_bar(hp)


func _on_ammo_changed(ammo: int) -> void:
	ammo_label.text = str(ammo) + " : AMMO"


func _on_round_changed(r: int) -> void:
	round_label.text = str(r)


func _on_points_changed(points: int) -> void:
	points_label.text = "POINTS\n" + str(points)


func _on_ammo_shop_changed(ammoInShop: int) -> void:
	ammo_left_burg_label.text = str(ammoInShop) + " : ammo left"


func _on_papped(boost_damage: int) -> void:
	lvl_gun.text = str(boost_damage) +  " : LVL"


func _on_player_defeated(pid: int) -> void:
	# mostra intermedia SOLO sul player sconfitto
	if mioPlayer.get_instance_id() == pid:
		# se è single-player, salta la intermedia (arriverà subito la finale)
		if gm.has_method("get_player_count") and gm.get_player_count() <= 1:
			return
		local_panel.visible = true	# mostro il pannello intermedio


func set_my_player(player_taken: CharacterBody3D):
	mioPlayer = player_taken
