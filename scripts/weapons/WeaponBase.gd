extends Node3D
class_name WeaponBase

## ============================================================
## WeaponBase.gd
## ------------------------------------------------------------
## Classe parente pour toutes les armes de SANGUINE.
## Gère la double économie de ressource :
##   1. Munitions physiques en priorité (`current_ammo`).
##   2. Une fois le chargeur vide, chaque tir consomme directement
##      `blood_cost_per_shot` PV via le HealthComponent du joueur.
## Le changement d'arme (Morph) est géré par le WeaponManager, qui
## consulte `morph_cost` avant d'équiper cette arme.
## ============================================================

@export var weapon_name: String = "Weapon"
@export var base_damage: float = 10.0
@export var max_ammo: int = 0
@export var blood_cost_per_shot: float = 0.0
@export var morph_cost: float = 5.0
@export var fire_cooldown: float = 0.15

@export_group("Combat")
## Portée du raycast de dégâts (hitscan), en mètres.
@export var weapon_range: float = 60.0
## Couches physiques touchées par le raycast : Layer 1 (Monde, pour que
## les murs bloquent le tir) + Layer 3 (Enemy Hurtbox, pour la détection
## des dégâts). Modifiable directement dans l'Inspecteur.
@export_flags_3d_physics var hit_mask: int = 0b101 # Layer 1 + Layer 3

var current_ammo: int = 0
var health_component: HealthComponent
var camera: Camera3D

var _fire_timer: float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta


## Injecté par le WeaponManager au moment de la constitution du deck.
func set_health_component(hc: HealthComponent) -> void:
	health_component = hc


## Injecté par le WeaponManager : la Camera3D du joueur sert d'origine
## et de direction pour le raycast de dégâts (_hitscan).
func set_camera(cam: Camera3D) -> void:
	camera = cam


## Tente de tirer/attaquer.
## Priorité aux munitions physiques ; une fois à 0, conversion directe
## en Sang. Retourne `false` si le tir est impossible (cooldown, ou
## ni munitions ni Sang suffisant).
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
		_fire_timer = fire_cooldown
		EventBus.shot_fired.emit(weapon_name)
		_on_shoot_effect()
	else:
		EventBus.shot_failed.emit(weapon_name)

	return success


## Recharge les munitions physiques (pickup au sol, palier de
## récupération, glyphe de rechargement, etc.).
func reload_ammo(amount: int) -> void:
	if max_ammo <= 0:
		return
	current_ammo = clampi(current_ammo + amount, 0, max_ammo)
	_emit_ammo_state()


## Consomme le sang pour un tir "à vide". Séparé de shoot() pour
## être facilement testable/surchargeable.
func _consume_blood_shot() -> bool:
	if health_component == null:
		push_warning("%s: aucun HealthComponent assigné." % weapon_name)
		return false
	return health_component.consume_blood(blood_cost_per_shot)


## Diffuse l'état de munitions courant, avec un flag "mode sang"
## pour que le HUD sache quand afficher l'alerte rouge.
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


## Tire un rayon depuis le centre de la caméra et applique `damage` à la
## première HurtboxComponent touchée. `range_override` permet de réduire
## la portée pour une arme de mêlée (ex: Katana) sans toucher à
## `weapon_range`. Retourne le dictionnaire de résultat brut du raycast
## (vide si rien n'a été touché), utile pour un futur VFX d'impact.
func _hitscan(damage: float, range_override: float = -1.0) -> Dictionary:
	if camera == null:
		push_warning("%s: aucune Camera3D assignée, hitscan ignoré." % weapon_name)
		return {}

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
		hurtbox.take_damage(damage, result.get("position", Vector3.ZERO))

	return result


## Appelé par le WeaponManager quand cette arme devient active.
## `trigger_morph_attack` = false pour le tout premier équipement au
## démarrage (pas de Morph Attack "gratuite" en début de partie).
func on_equip(trigger_morph_attack: bool = true) -> void:
	visible = true
	set_process(true)
	current_ammo = max_ammo
	_emit_ammo_state()
	if trigger_morph_attack:
		perform_morph_attack()


## Appelé par le WeaponManager quand cette arme est remplacée.
func on_unequip() -> void:
	visible = false
	set_process(false)
