extends Node3D
class_name WeaponComponent

@export var MAX_WEAPONS: int = 4
@export var weapon_scenes: Array[PackedScene] = []

var weapons: Array[WeaponBase] = []
var current_index: int = -1
var health_component: HealthComponent
var doping_component: DopingManager
var camera: Camera3D
var player: Node3D


func _ready() -> void:
	camera = get_parent() as Camera3D
	
	var head: Node = camera.get_parent()
	player = head.get_parent() as Node3D
	
	_instantiate_weapons()
	_equip_index(0, false)


func set_health_component(hc: HealthComponent) -> void:
	health_component = hc
	for weapon in weapons:
		weapon.set_health_component(hc)


func set_doping_component(dm: DopingManager) -> void:
	doping_component = dm
	for weapon in weapons:
		weapon.set_doping_component(dm)


func _instantiate_weapons() -> void:
	var count: int = mini(weapon_scenes.size(), MAX_WEAPONS)
	
	for i in range(count):
		var scene: PackedScene = weapon_scenes[i]
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
	var next_index: int = (current_index + direction + weapons.size()) % weapons.size()
	try_switch_weapon(next_index)


func try_switch_weapon(index: int) -> bool:
	if index == current_index:
		return false

	var new_weapon: WeaponBase = weapons[index]
	var cost_multiplier: float = doping_component.get_weapon_switch_cost_multiplier() if doping_component != null else 1.0
	var switch_cost: float = new_weapon.morph_cost * cost_multiplier

	var success: bool = health_component.consume_blood(switch_cost)

	if not success:
		EventBus.morph_failed.emit(new_weapon.weapon_name, switch_cost)
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


func fire_current_extraction() -> void:
	if current_index < 0 or current_index >= weapons.size():
		return
	weapons[current_index].extraction()


func get_current_weapon() -> WeaponBase:
	if current_index < 0 or current_index >= weapons.size():
		return null
	return weapons[current_index]
