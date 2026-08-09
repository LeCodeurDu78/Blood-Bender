extends WeaponBase
class_name DualBlades

## ============================================================
## DualBlades.gd (Lames Doubles)
## ------------------------------------------------------------
## Arme de mêlée à cadence TRÈS rapide, entièrement gratuite comme
## le Katana (pas d'ammo, pas de coût en Sang pour attaquer).
##
## VOL DE VIE PASSIF : chaque coup qui touche une cible soigne le
## joueur de 1 à 2 PV via HealthComponent.heal_blood(). C'est la
## signature de l'arme : plus on frappe vite, plus on se régénère
## vite (mais seulement au contact réel d'une cible).
##
## EXTRACTION (clic droit) : "Découpe en rafale" — un déclenchement
## enchaîne plusieurs coups rapprochés en une seule pression (combo
## discret, `allow_held_extraction = false` pour éviter d'empiler
## plusieurs rafales en maintenant le clic).
##
## MORPH ATTACK : dash tranchant qui téléporte le joueur derrière la
## cible visée, avec un coup renforcé et un vol de vie doublé.
## ============================================================

@export var melee_range: float = 2.2
@export var lifesteal_min: float = 1.0
@export var lifesteal_max: float = 2.0

@export_group("Extraction — Découpe en rafale")
@export var extraction_hits: int = 3

@export_group("Morph — Dash Tranchant")
## Distance à laquelle le joueur est replacé derrière la cible touchée.
@export var morph_dash_distance: float = 2.0
@export var morph_damage_multiplier: float = 1.5
@export var morph_lifesteal_multiplier: float = 2.0

func _ready() -> void:
	weapon_name = "Lames Doubles"
	base_damage = 9.0
	max_ammo = 0
	blood_cost_per_shot = 0.0
	morph_cost = 4.0
	# Cadence de tir très rapide au CàC.
	fire_cooldown = 0.09
	melee_range = 2.2

	extraction_cooldown = 0.45
	extraction_ammo_cost = 0
	extraction_blood_cost = 0.0

	allow_held_fire = true          # Maintenir le clic = enchaînement de coups.
	allow_held_extraction = false   # Un clic droit = une rafale complète, pas de spam.

	super._ready()


## Surcharge complète (arme CàC gratuite, comme le Katana).
func shoot() -> bool:
	if _fire_timer > 0.0:
		return false

	_fire_timer = fire_cooldown
	EventBus.shot_fired.emit(weapon_name)
	_on_shoot_effect()
	_perform_slash(base_damage, 1.0)
	return true


func _on_shoot_effect() -> void:
	# TODO (Phase 3 - Combat) : animation de double-lame croisée, traînée sanguine.
	pass


## Applique un coup de lame courte portée et déclenche le vol de vie
## passif si la cible a bien été touchée. `heal_multiplier` permet au
## Morph Attack de réutiliser cette logique avec un soin doublé.
func _perform_slash(damage: float, heal_multiplier: float) -> Dictionary:
	var result: Dictionary = _hitscan(damage, melee_range)
	if not result.is_empty() and health_component != null:
		var heal: float = randf_range(lifesteal_min, lifesteal_max) * heal_multiplier
		health_component.heal_blood(heal)
	return result


## Extraction (clic droit) : "Découpe en rafale" — enchaîne plusieurs
## coups rapprochés en une seule pression. Entièrement gratuit, comme
## le reste de l'arme.
func extraction() -> bool:
	if _extraction_timer > 0.0:
		return false

	_extraction_timer = extraction_cooldown
	EventBus.extraction_fired.emit(weapon_name)
	_perform_burst()
	return true


func _perform_burst() -> void:
	for i in range(extraction_hits):
		_perform_slash(base_damage, 1.0)
		# TODO (Phase 3 - Animation) : chaque itération devrait correspondre
		# à une frame d'anim distincte plutôt qu'à des coups instantanés
		# consécutifs ; prévoir un léger délai via un Tween/AnimationPlayer.


## Morph Attack : dash/téléportation tranchante qui replace le joueur
## derrière la cible visée, avec un coup renforcé et un vol de vie doublé.
func perform_morph_attack() -> void:
	var result: Dictionary = _hitscan(base_damage * morph_damage_multiplier, weapon_range)
	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if not (collider is HurtboxComponent):
		return

	var heal: float = randf_range(lifesteal_min, lifesteal_max) * morph_lifesteal_multiplier
	if health_component != null:
		health_component.heal_blood(heal)

	if player == null:
		return

	var hurtbox: HurtboxComponent = collider
	var target_pos: Vector3 = hurtbox.global_transform.origin

	# Direction "joueur -> cible" à plat (on ignore la hauteur pour ne
	# pas téléporter le joueur en l'air ou sous le sol).
	var approach_dir: Vector3 = target_pos - player.global_transform.origin
	approach_dir.y = 0.0
	if approach_dir.length() < 0.001:
		approach_dir = -player.global_transform.basis.z
	approach_dir = approach_dir.normalized()

	# Nouvelle position : on continue tout droit derrière la cible.
	var behind_pos: Vector3 = target_pos + approach_dir * morph_dash_distance
	behind_pos.y = player.global_transform.origin.y

	player.global_transform.origin = behind_pos

	if player.has_method("look_at_point"):
		player.look_at_point(target_pos)

	# TODO (Phase 3 - VFX) : traînée de dash + effet "après-image" sanglant.
