extends WeaponBase
class_name Katana

## ============================================================
## Katana.gd
## ============================================================

## Portée du coup de lame (mètres) — bien plus courte que weapon_range.
@export var melee_range: float = 2.5

@export_group("Extraction — Estoc Chirurgical")
## Portée de l'estoc (légèrement supérieure au coup de lame standard).
@export var extraction_range: float = 3.0
## Multiplicateur de dégâts de l'estoc par rapport à base_damage.
@export var extraction_damage_multiplier: float = 1.6
## Vol de vie (PV) si l'estoc touche un point faible (coup critique).
@export var extraction_weak_point_heal_min: float = 15.0
@export var extraction_weak_point_heal_max: float = 25.0

func _ready() -> void:
	weapon_name = "Katana"
	base_damage = 18.0
	max_ammo = 0
	blood_cost_per_shot = 0.0
	morph_cost = 5.0
	fire_cooldown = 0.25
	melee_range = 2.5

	# L'estoc est une action délibérée : un clic droit = un coup, pas de
	# spam en maintenant le bouton (contrairement aux coups de lame normaux).
	extraction_cooldown = 0.5
	extraction_ammo_cost = 0
	extraction_blood_cost = 0.0
	allow_held_fire = true
	allow_held_extraction = false

	super._ready()


## Surcharge complète : on court-circuite l'économie munitions/sang
## de la classe parente. Un coup de Katana est toujours gratuit.
func shoot() -> bool:
	if _fire_timer > 0.0:
		return false

	_fire_timer = fire_cooldown
	EventBus.shot_fired.emit(weapon_name)
	_on_shoot_effect()
	_perform_melee_hit()
	return true


func _on_shoot_effect() -> void:
	# TODO (Phase 3 - Combat) : animation de coup, particules de sang, secousse caméra.
	pass


func _perform_melee_hit() -> void:
	# Coup de lame : hitscan de très courte portée (melee_range) appliquant
	# base_damage à la première HurtboxComponent touchée. Suffisant pour
	# un Fast-FPS (pas besoin de hitbox physique à balayage pour la Phase 3).
	_hitscan(base_damage, melee_range)


## Extraction (clic droit) : Estoc chirurgical, entièrement gratuit
## comme le coup de lame standard (surcharge complète, cohérent avec
## la philosophie "Katana = illimité" de la classe).
func extraction() -> bool:
	if _extraction_timer > 0.0:
		return false

	_extraction_timer = extraction_cooldown
	EventBus.extraction_fired.emit(weapon_name)
	_perform_extraction_thrust()
	return true


func _perform_extraction_thrust() -> void:
	var result: Dictionary = _hitscan(base_damage * extraction_damage_multiplier, extraction_range)
	if result.is_empty():
		return

	var collider: Object = result.get("collider")
	if collider is HurtboxComponent and (collider as HurtboxComponent).is_weak_point:
		var heal: float = randf_range(extraction_weak_point_heal_min, extraction_weak_point_heal_max)
		if health_component != null:
			health_component.heal_blood(heal)
		# TODO (Phase 3 - VFX) : flash critique + son distinct pour le coup sur point faible.


## Attaque automatique instantanée déclenchée lors du Morph vers la Katana.
func perform_morph_attack() -> void:
	_perform_melee_hit()
