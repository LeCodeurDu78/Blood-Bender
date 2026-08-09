extends WeaponBase
class_name Katana

## ============================================================
## Katana.gd
## ------------------------------------------------------------
## Arme de mêlée rapide : attaques ILLIMITÉES, ne consomme jamais
## de Sang pour attaquer. Seul l'équipement (Morph) coûte du sang,
## via `morph_cost`, géré par WeaponManager. Les dégâts sont
## appliqués via un hitscan de très courte portée (`melee_range`).
## ============================================================

## Portée du coup de lame (mètres) — bien plus courte que weapon_range.
@export var melee_range: float = 2.5

func _ready() -> void:
	weapon_name = "Katana"
	base_damage = 18.0
	max_ammo = 0
	blood_cost_per_shot = 0.0
	morph_cost = 5.0
	fire_cooldown = 0.25
	melee_range = 2.5
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


## Attaque automatique instantanée déclenchée lors du Morph vers la Katana.
func perform_morph_attack() -> void:
	_perform_melee_hit()
