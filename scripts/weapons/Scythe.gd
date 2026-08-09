extends WeaponBase
class_name Scythe

## ============================================================
## Scythe.gd (Faux Hématique)
## ------------------------------------------------------------
## Arme de mêlée à ZONE : chaque coup principal balaie un cône de
## 180° devant le joueur (WeaponBase._cone_attack) et draine du sang
## pour CHAQUE ennemi touché — plus il y a d'ennemis dans le cône,
## plus le rendement est élevé. Entièrement gratuite (comme Katana
## et Lames Doubles).
##
## EXTRACTION (clic droit) : "Balayage fendeur" — cône plus étroit
## mais légèrement plus puissant, pensé pour achever une cible isolée
## sans gaspiller l'ouverture à 180° du coup principal.
##
## MORPH ATTACK : "Moulinet circulaire 360°" — cône complet (360°)
## qui touche TOUT ce qui est à portée et repousse chaque cible
## touchée (voir HurtboxComponent.apply_knockback).
## ============================================================

@export var melee_range: float = 3.0
@export var cone_angle_deg: float = 180.0
## Sang rendu au joueur PAR ennemi touché (rendement proportionnel).
@export var heal_per_enemy_hit: float = 3.0

@export_group("Extraction — Balayage Fendeur")
@export var extraction_cone_angle_deg: float = 70.0
@export var extraction_damage_multiplier: float = 1.3

@export_group("Morph — Moulinet 360°")
@export var morph_knockback_force: float = 9.0
@export var morph_damage_multiplier: float = 1.0

func _ready() -> void:
	weapon_name = "Faux Hématique"
	base_damage = 14.0
	max_ammo = 0
	blood_cost_per_shot = 0.0
	morph_cost = 6.0
	fire_cooldown = 0.55
	melee_range = 3.0
	cone_angle_deg = 180.0

	extraction_cooldown = 0.7
	extraction_ammo_cost = 0
	extraction_blood_cost = 0.0

	allow_held_fire = true
	allow_held_extraction = true

	super._ready()


## Surcharge complète (arme CàC gratuite).
func shoot() -> bool:
	if _fire_timer > 0.0:
		return false

	_fire_timer = fire_cooldown
	EventBus.shot_fired.emit(weapon_name)
	_on_shoot_effect()
	_perform_cone_slash(base_damage, cone_angle_deg, melee_range, 0.0)
	return true


func _on_shoot_effect() -> void:
	# TODO (Phase 3 - Combat) : animation de balayage large, particules de sang en arc.
	pass


## Exécute une attaque en cône et applique le rendement d'extraction :
## `heal_per_enemy_hit` PV par ennemi touché (proportionnel au nombre
## de cibles dans le cône). Retourne la liste des cibles touchées.
func _perform_cone_slash(damage: float, angle_deg: float, range_value: float, knockback_force: float) -> Array[HurtboxComponent]:
	var hits: Array[HurtboxComponent] = _cone_attack(damage, angle_deg, range_value, knockback_force)
	if not hits.is_empty() and health_component != null:
		health_component.heal_blood(heal_per_enemy_hit * hits.size())
	return hits


## Extraction (clic droit) : Balayage fendeur — cône plus étroit,
## légèrement plus puissant. Entièrement gratuit, comme le reste de l'arme.
func extraction() -> bool:
	if _extraction_timer > 0.0:
		return false

	_extraction_timer = extraction_cooldown
	EventBus.extraction_fired.emit(weapon_name)
	_perform_cone_slash(
		base_damage * extraction_damage_multiplier,
		extraction_cone_angle_deg,
		melee_range * 0.9,
		0.0
	)
	return true


## Morph Attack : Moulinet circulaire 360° — cône complet, repousse
## toutes les cibles touchées.
func perform_morph_attack() -> void:
	_perform_cone_slash(
		base_damage * morph_damage_multiplier,
		360.0,
		melee_range,
		morph_knockback_force
	)
	# TODO (Phase 3 - VFX) : anneau de sang tournoyant + secousse caméra.
