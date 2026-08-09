extends Node3D
class_name WeaponComponent

## ============================================================
## WeaponManager.gd
## ------------------------------------------------------------
## Attaché sous la Camera3D du joueur. Gère un deck de 4 armes
## maximum (Katana, Shotgun, Lames Doubles, Faux), le changement
## d'arme (touches 1-4 / molette) et le tir de l'arme active.
##
## PHASE 1 :
##   - Tir principal (`attack`) ET tir secondaire (`extraction`) sont
##     maintenant pilotés via les actions d'input (clic gauche / clic
##     droit) plutôt qu'un test brut sur MOUSE_BUTTON_LEFT, pour rester
##     cohérent avec le reste du projet (blood_dash, weapon_1-4...).
##   - Chaque arme décide elle-même, via `allow_held_fire` /
##     `allow_held_extraction`, si maintenir le bouton déclenche un tir
##     en continu (cadence rapide type Lames Doubles) ou si un clic ne
##     produit qu'un seul coup (arme à pompe, estoc chirurgical...).
##   - `set_player()` : la référence CharacterBody3D du joueur est
##     désormais transmise à chaque arme, pour les Morph Attacks qui
##     déplacent le joueur dans l'espace (dash tranchant des Lames
##     Doubles).
##
## MÉCANIQUE "MORPH ATTACK" :
## Chaque changement d'arme consomme `morph_cost` PV via le
## HealthComponent. Si le joueur n'a pas assez de Sang, le
## changement est annulé (l'arme actuelle reste équipée). En cas
## de succès, l'ancienne arme est masquée, la nouvelle est activée
## et déclenche automatiquement une attaque instantanée
## (`perform_morph_attack`).
## ============================================================

const MAX_WEAPONS: int = 4

## Scènes d'armes assignées dans l'inspecteur (max 4, ordre = slots 1-4).
## Deck de référence Phase 1 : Katana, Shotgun, Lames Doubles, Faux.
@export var weapon_scenes: Array[PackedScene] = []

var weapons: Array[WeaponBase] = []
var current_index: int = -1
var health_component: HealthComponent
var camera: Camera3D
var player: Node3D


func _ready() -> void:
	# Le WeaponManager est attaché directement sous la Camera3D du joueur
	# (voir arborescence Player.tscn) : son parent EST la caméra, et le
	# parent de la caméra (Head) a pour parent le CharacterBody3D du joueur.
	camera = get_parent() as Camera3D
	if camera == null:
		push_warning("WeaponManager: doit être un enfant direct d'une Camera3D.")
	else:
		var head: Node = camera.get_parent()
		player = head.get_parent() as Node3D if head != null else null
		if player == null:
			push_warning("WeaponManager: impossible de résoudre la référence au joueur (Camera3D/Head/Player).")

	_instantiate_weapons()
	if not weapons.is_empty():
		# Premier équipement : gratuit, sans Morph Attack automatique.
		_equip_index(0, false)


## Injecté par Player.gd juste après l'instanciation.
func set_health_component(hc: HealthComponent) -> void:
	health_component = hc
	for weapon in weapons:
		weapon.set_health_component(hc)


func _instantiate_weapons() -> void:
	var count: int = mini(weapon_scenes.size(), MAX_WEAPONS)
	if weapon_scenes.size() > MAX_WEAPONS:
		push_warning("WeaponManager: deck limité à %d armes, %d fournies." % [MAX_WEAPONS, weapon_scenes.size()])

	for i in range(count):
		var scene: PackedScene = weapon_scenes[i]
		if scene == null:
			continue
		var weapon: WeaponBase = scene.instantiate()
		add_child(weapon)
		weapon.set_camera(camera)
		weapon.set_player(player)
		weapon.visible = false
		weapon.set_process(false)
		weapons.append(weapon)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("weapon_1"):
		try_switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		try_switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"):
		try_switch_weapon(2)
	elif Input.is_action_just_pressed("weapon_4"):
		try_switch_weapon(3)

	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_cycle_weapon(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_weapon(-1)


## Le tir (principal et secondaire) est piloté ici en continu, plutôt
## que dans _unhandled_input, pour permettre à chaque arme de choisir
## un comportement "auto-fire tant que maintenu" ou "un clic = un coup"
## via ses flags `allow_held_fire` / `allow_held_extraction`.
func _process(_delta: float) -> void:
	var weapon: WeaponBase = get_current_weapon()
	if weapon == null:
		return

	if weapon.allow_held_fire:
		if Input.is_action_pressed("attack"):
			fire_current_weapon()
	elif Input.is_action_just_pressed("attack"):
		fire_current_weapon()

	if weapon.allow_held_extraction:
		if Input.is_action_pressed("extraction"):
			fire_current_extraction()
	elif Input.is_action_just_pressed("extraction"):
		fire_current_extraction()


func _cycle_weapon(direction: int) -> void:
	if weapons.is_empty():
		return
	var next_index: int = (current_index + direction + weapons.size()) % weapons.size()
	try_switch_weapon(next_index)


## Point d'entrée public pour changer d'arme (touches, molette, futurs
## pickups/glyphes...). Applique la mécanique de Morph Attack : coûte
## du sang, annulé si insuffisant.
func try_switch_weapon(index: int) -> bool:
	if index < 0 or index >= weapons.size():
		return false
	if index == current_index:
		return false

	var new_weapon: WeaponBase = weapons[index]

	if health_component == null:
		push_warning("WeaponManager: aucun HealthComponent assigné.")
		return false

	var success: bool = health_component.consume_blood(new_weapon.morph_cost)

	if not success:
		EventBus.morph_failed.emit(new_weapon.weapon_name, new_weapon.morph_cost)
		return false

	_equip_index(index, true)
	return true


func _equip_index(index: int, trigger_morph_attack: bool) -> void:
	if current_index >= 0 and current_index < weapons.size():
		weapons[current_index].on_unequip()

	current_index = index
	var weapon: WeaponBase = weapons[current_index]
	weapon.on_equip(trigger_morph_attack)

	EventBus.weapon_changed.emit(weapon)


func fire_current_weapon() -> void:
	if current_index < 0 or current_index >= weapons.size():
		return
	weapons[current_index].shoot()


## Déclenche le tir secondaire ("Extraction") de l'arme active.
func fire_current_extraction() -> void:
	if current_index < 0 or current_index >= weapons.size():
		return
	weapons[current_index].extraction()


func get_current_weapon() -> WeaponBase:
	if current_index < 0 or current_index >= weapons.size():
		return null
	return weapons[current_index]
