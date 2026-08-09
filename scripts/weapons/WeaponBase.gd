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
##
## PHASE 1 — AJOUTS :
##   - Tir secondaire "Extraction" (clic droit) : même logique
##     d'économie (ammo puis sang), sur un cooldown indépendant
##     (`extraction_cooldown`). Chaque arme surcharge `extraction()`
##     (armes CàC gratuites) ou `_on_extraction_effect()` (armes à
##     munitions, cf. Shotgun).
##   - Deux helpers de dégâts réutilisables par les sous-classes :
##       `_cone_attack()`   : balayage en cône (Faux).
##       `_hitscan_pierce()`: rayon perçant multi-cibles (Shotgun).
##   - Référence optionnelle au joueur (`player`), injectée par le
##     WeaponManager, pour les Morph Attacks qui déplacent/tournent
##     le joueur (ex: dash tranchant des Lames Doubles).
##   - Flags `allow_held_fire` / `allow_held_extraction` : permettent
##     à chaque arme de définir si maintenir le clic déclenche un tir
##     en continu (rafale/CàC rapide) ou exige un clic par coup
##     (arme à pompe, estoc chirurgical...).
## ============================================================

@export var weapon_name: String = "Weapon"
@export var base_damage: float = 10.0
@export var max_ammo: int = 0
@export var blood_cost_per_shot: float = 0.0
@export var morph_cost: float = 5.0
@export var fire_cooldown: float = 0.15

@export_group("Extraction (Tir Secondaire)")
## Cooldown propre au tir secondaire, indépendant de `fire_cooldown`.
@export var extraction_cooldown: float = 0.3
## Coût en munitions physiques pour UNE extraction (0 = n'utilise pas les munitions).
@export var extraction_ammo_cost: int = 0
## Coût en Sang si les munitions sont épuisées ou non utilisées (0 = gratuit).
@export var extraction_blood_cost: float = 0.0

@export_group("Combat")
## Portée du raycast de dégâts (hitscan), en mètres.
@export var weapon_range: float = 60.0
## Couches physiques touchées par le raycast : Layer 1 (Monde, pour que
## les murs bloquent le tir) + Layer 3 (Enemy Hurtbox, pour la détection
## des dégâts). Modifiable directement dans l'Inspecteur.
@export_flags_3d_physics var hit_mask: int = 0b101 # Layer 1 + Layer 3

@export_group("Input Feel")
## Si `true`, maintenir le clic gauche (`attack`) déclenche un tir à
## chaque frame (gaté par `fire_cooldown`). Si `false`, un clic = un tir.
@export var allow_held_fire: bool = true
## Idem pour le clic droit (`extraction`), gaté par `extraction_cooldown`.
@export var allow_held_extraction: bool = true

var current_ammo: int = 0
var health_component: HealthComponent
var camera: Camera3D

## Référence au CharacterBody3D du joueur, injectée par WeaponManager.
## Utile pour les Morph Attacks qui déplacent le joueur (dash tranchant).
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


## Injecté par le WeaponManager au moment de la constitution du deck.
func set_health_component(hc: HealthComponent) -> void:
	health_component = hc


## Injecté par le WeaponManager : la Camera3D du joueur sert d'origine
## et de direction pour le raycast de dégâts (_hitscan).
func set_camera(cam: Camera3D) -> void:
	camera = cam


## Injecté par le WeaponManager : référence au CharacterBody3D du joueur,
## utilisée par les Morph Attacks qui déplacent le joueur dans l'espace
## (ex: dash tranchant derrière la cible des Lames Doubles).
func set_player(p: Node3D) -> void:
	player = p


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


## Tente de déclencher le tir secondaire "Extraction" (clic droit).
## Même logique d'économie que `shoot()` (munitions physiques d'abord,
## puis Sang), mais sur un cooldown et un coût indépendants
## (`extraction_cooldown` / `extraction_ammo_cost` / `extraction_blood_cost`).
## Les armes CàC gratuites (Katana, Lames Doubles, Faux) surchargent
## généralement cette méthode entièrement (comme `shoot()`) ; les armes
## à munitions (Shotgun) la laissent telle quelle et ne surchargent que
## `_on_extraction_effect()`.
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


## Consomme le sang pour une extraction "à vide" (munitions épuisées ou
## arme n'utilisant pas de munitions pour son tir secondaire).
func _consume_blood_extraction() -> bool:
	if health_component == null:
		push_warning("%s: aucun HealthComponent assigné." % weapon_name)
		return false
	return health_component.consume_blood(extraction_blood_cost)


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


## Hook du tir secondaire à surcharger par les armes qui laissent
## WeaponBase.extraction() gérer l'économie de ressource (ex: Shotgun).
func _on_extraction_effect() -> void:
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


## Rayon PERÇANT : traverse plusieurs HurtboxComponent d'affilée (jusqu'à
## `max_targets`), en excluant les collisions déjà résolues à chaque
## itération. S'arrête dès qu'il touche un obstacle solide (mur/décor)
## qui n'est pas une HurtboxComponent. Utilisé par le tir secondaire du
## Shotgun ("Rappel d'éclats" qui draine toutes les cibles traversées).
## Retourne la liste des HurtboxComponent touchées, dans l'ordre.
func _hitscan_pierce(damage: float, range_override: float = -1.0, max_targets: int = 5) -> Array[HurtboxComponent]:
	var hit_list: Array[HurtboxComponent] = []

	if camera == null:
		push_warning("%s: aucune Camera3D assignée, hitscan perçant ignoré." % weapon_name)
		return hit_list

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
			hurtbox.take_damage(damage, result.get("position", Vector3.ZERO))
			hit_list.append(hurtbox)
		else:
			# Obstacle solide (mur/décor) : la traversée s'arrête ici.
			break

	return hit_list


## Balayage en CÔNE autour de l'axe de la caméra : détecte toutes les
## HurtboxComponent dans `range_override` mètres et `angle_deg` degrés
## d'ouverture, leur applique `damage`, et déclenche optionnellement un
## repoussement (`knockback_force` > 0). Utilisé par la Faux (attaque
## principale 180°, extraction en cône plus étroit, Morph 360°).
## Retourne la liste des HurtboxComponent touchées — utile pour calculer
## un rendement de vol de vie proportionnel au nombre d'ennemis touchés.
func _cone_attack(damage: float, angle_deg: float, range_override: float = -1.0, knockback_force: float = 0.0) -> Array[HurtboxComponent]:
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

		hurtbox.take_damage(damage, hurtbox.global_transform.origin)

		if knockback_force > 0.0:
			var push_dir: Vector3 = hurtbox.global_transform.origin - origin
			push_dir = push_dir.normalized() if push_dir.length() > 0.001 else forward
			hurtbox.apply_knockback(push_dir, knockback_force)

		hit_list.append(hurtbox)

	return hit_list


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
