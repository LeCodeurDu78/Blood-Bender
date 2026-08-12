extends Node3D
class_name WeaponBase

@export var weapon_name: String = "Weapon"
@export var base_damage: float = 10.0
@export var max_ammo: int = 0
@export var blood_cost_per_shot: float = 0.0
@export var morph_cost: float = 5.0
@export var fire_cooldown: float = 0.15

@export_group("Extraction (Tir Secondaire)")
@export var extraction_cooldown: float = 0.3
@export var extraction_ammo_cost: int = 0
@export var extraction_blood_cost: float = 0.0

@export_group("Combat")
@export var weapon_range: float = 60.0
@export_flags_3d_physics var hit_mask: int = 0b101

@export_group("Input Feel")
@export var allow_held_fire: bool = true
@export var allow_held_extraction: bool = true

@export_group("Dopage")
## Les armes de mêlée profitent du multiplicateur de dégâts CàC de la
## Sérotonine BERSERK ; désactivé pour les armes à distance (Shotgun).
@export var is_melee: bool = true

var current_ammo: int = 0
var health_component: HealthComponent
var doping_component: DopingManager
var camera: Camera3D
var player: Node3D

var _fire_timer: float = 0.0
var _extraction_timer: float = 0.0


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if _extraction_timer > 0.0:
		_extraction_timer -= delta


func set_health_component(hc: HealthComponent) -> void:
	health_component = hc


func set_doping_component(dm: DopingManager) -> void:
	doping_component = dm


func set_camera(cam: Camera3D) -> void:
	camera = cam


func set_player(p: Node3D) -> void:
	player = p


func shoot() -> bool:
	if _fire_timer > 0.0:
		return false

	var success: bool = false

	if current_ammo > 0:
		current_ammo -= 1
		success = true
		_emit_ammo_state()
	else:
		success = _consume_blood_shot()

	if success:
		_fire_timer = fire_cooldown * _get_fire_cooldown_multiplier()
		EventBus.shot_fired.emit(weapon_name)
		_on_shoot_effect()
	else:
		EventBus.shot_failed.emit(weapon_name)

	return success


func extraction() -> bool:
	if _extraction_timer > 0.0:
		return false

	var success: bool = false

	if extraction_ammo_cost > 0 and current_ammo >= extraction_ammo_cost:
		current_ammo -= extraction_ammo_cost
		success = true
		_emit_ammo_state()
	elif extraction_blood_cost > 0.0:
		success = _consume_blood_extraction()
	else:
		success = true

	if success:
		_extraction_timer = extraction_cooldown
		EventBus.extraction_fired.emit(weapon_name)
		_on_extraction_effect()
	else:
		EventBus.extraction_failed.emit(weapon_name)

	return success


func reload_ammo(amount: int) -> void:
	if max_ammo <= 0:
		return
	current_ammo = clampi(current_ammo + amount, 0, max_ammo)
	_emit_ammo_state()


func _consume_blood_shot() -> bool:
	if health_component == null:
		push_warning("%s: aucun HealthComponent assigné." % weapon_name)
		return false
	return health_component.consume_blood(blood_cost_per_shot)


func _consume_blood_extraction() -> bool:
	if health_component == null:
		push_warning("%s: aucun HealthComponent assigné." % weapon_name)
		return false
	return health_component.consume_blood(extraction_blood_cost)


func _emit_ammo_state() -> void:
	var blood_mode: bool = max_ammo > 0 and current_ammo == 0
	EventBus.ammo_changed.emit(current_ammo, max_ammo, blood_mode, blood_cost_per_shot)


## Attaque/impulsion automatique déclenchée lors d'un Morph Attack
## réussi (voir WeaponManager.try_switch_weapon). À surcharger.
func perform_morph_attack() -> void:
	pass


## Hook visuel/sonore à surcharger (VFX, recul caméra, animation...).
func _on_shoot_effect() -> void:
	pass


## Hook du tir secondaire à surcharger par les armes qui laissent
## WeaponBase.extraction() gérer l'économie de ressource (ex: Shotgun).
func _on_extraction_effect() -> void:
	pass


func _get_fire_cooldown_multiplier() -> float:
	if doping_component != null:
		return doping_component.get_fire_cooldown_multiplier()
	return 1.0


## Multiplicateur de dégâts appliqué aux attaques CàC (Sérotonine BERSERK).
## N'affecte pas les armes marquées is_melee = false (ex: Shotgun).
func _get_damage_multiplier() -> float:
	if is_melee and doping_component != null:
		return doping_component.get_melee_damage_multiplier()
	return 1.0


## À utiliser à la place d'un appel direct à health_component.heal_blood()
## pour tout vol de sang lié à une attaque, afin de profiter du x3 de la
## Sérotonine BERSERK pendant son Boost.
func _apply_lifesteal(amount: float) -> float:
	if doping_component != null:
		return amount * doping_component.get_lifesteal_multiplier()
	return amount


func _hitscan(damage: float, range_override: float = -1.0) -> Dictionary:
	var final_damage: float = damage * _get_damage_multiplier()
	var ray_range: float = range_override if range_override > 0.0 else weapon_range
	var from: Vector3 = camera.global_transform.origin
	var to: Vector3 = from - camera.global_transform.basis.z * ray_range

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = hit_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return {}

	var collider: Object = result.get("collider")
	if collider is HurtboxComponent:
		var hurtbox: HurtboxComponent = collider
		hurtbox.take_damage(final_damage, result.get("position", Vector3.ZERO))

	return result


func _hitscan_pierce(damage: float, range_override: float = -1.0, max_targets: int = 5) -> Array[HurtboxComponent]:
	var final_damage: float = damage * _get_damage_multiplier()
	var hit_list: Array[HurtboxComponent] = []
	var ray_range: float = range_override if range_override > 0.0 else weapon_range
	var from: Vector3 = camera.global_transform.origin
	var to: Vector3 = from - camera.global_transform.basis.z * ray_range
	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var excluded: Array[RID] = []

	for i in range(max_targets):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = hit_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = excluded

		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			break

		var collider: Object = result.get("collider")
		var rid: RID = result.get("rid")
		if rid != null:
			excluded.append(rid)

		if collider is HurtboxComponent:
			var hurtbox: HurtboxComponent = collider
			hurtbox.take_damage(final_damage, result.get("position", Vector3.ZERO))
			hit_list.append(hurtbox)
		else:
			# Obstacle solide (mur/décor) : la traversée s'arrête ici.
			break

	return hit_list


func _cone_attack(damage: float, angle_deg: float, range_override: float = -1.0, knockback_force: float = 0.0) -> Array[HurtboxComponent]:
	var final_damage: float = damage * _get_damage_multiplier()
	var hit_list: Array[HurtboxComponent] = []

	if camera == null:
		push_warning("%s: aucune Camera3D assignée, cone attack ignoré." % weapon_name)
		return hit_list

	var attack_range: float = range_override if range_override > 0.0 else weapon_range
	var origin: Vector3 = camera.global_transform.origin
	var forward: Vector3 = -camera.global_transform.basis.z
	# 360° = cercle complet : tout ce qui est dans la portée est touché,
	# on évite tout risque d'imprécision flottante sur l'angle limite.
	var half_angle_rad: float = deg_to_rad(angle_deg * 0.5)
	var is_full_circle: bool = angle_deg >= 359.9

	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = attack_range

	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), origin)
	params.collision_mask = hit_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(params, 32)

	for hit in results:
		var collider: Object = hit.get("collider")
		if not (collider is HurtboxComponent):
			continue

		var hurtbox: HurtboxComponent = collider
		if hurtbox in hit_list:
			continue

		if not is_full_circle:
			var to_target: Vector3 = hurtbox.global_transform.origin - origin
			if to_target.length() > 0.001:
				var angle: float = forward.angle_to(to_target.normalized())
				if angle > half_angle_rad:
					continue

		hurtbox.take_damage(final_damage, hurtbox.global_transform.origin)

		if knockback_force > 0.0:
			var push_dir: Vector3 = hurtbox.global_transform.origin - origin
			push_dir = push_dir.normalized() if push_dir.length() > 0.001 else forward
			hurtbox.apply_knockback(push_dir, knockback_force)

		hit_list.append(hurtbox)

	return hit_list


func on_equip(trigger_morph_attack: bool = true) -> void:
	visible = true
	set_process(true)
	current_ammo = max_ammo
	_emit_ammo_state()
	if trigger_morph_attack:
		perform_morph_attack()


func on_unequip() -> void:
	visible = false
	set_process(false)
