extends WeaponBase
class_name Shotgun

## ============================================================
## Shotgun.gd
## ============================================================

@export_group("Extraction — Rappel d'éclats")
## Nombre maximum de cibles traversées par le rappel d'éclats.
@export var extraction_pierce_targets: int = 4
## Dégâts infligés à CHAQUE cible traversée (généralement < base_damage,
## l'arme perd en puissance brute ce qu'elle gagne en portée d'effet).
@export var extraction_damage_per_target: float = 20.0
## Sang drainé (rendu au joueur) pour CHAQUE cible traversée.
@export var extraction_drain_per_target: float = 6.0

func _ready() -> void:
	weapon_name = "Shotgun"
	base_damage = 35.0
	max_ammo = 6
	blood_cost_per_shot = 12.0
	morph_cost = 8.0
	fire_cooldown = 0.6

	# Arme à pompe : un tir = un clic, pas d'auto-fire en maintenant le bouton.
	extraction_cooldown = 0.9
	extraction_ammo_cost = 1
	extraction_blood_cost = 12.0
	allow_held_fire = false
	allow_held_extraction = false

	super._ready()


func _on_shoot_effect() -> void:
	# Dégâts appliqués via hitscan à la portée normale de l'arme (weapon_range).
	_hitscan(base_damage)
	# TODO (Phase 3 - Combat, VFX) : recul caméra, flash de bouche, particules, son.


## Rappel d'éclats de sang/os : rayon perçant qui traverse jusqu'à
## `extraction_pierce_targets` cibles alignées, inflige des dégâts à
## chacune, et draine de la santé proportionnellement au nombre de
## cibles traversées (soin cumulatif, comme une moisson en ligne).
func _on_extraction_effect() -> void:
	var hits: Array[HurtboxComponent] = _hitscan_pierce(
		extraction_damage_per_target,
		weapon_range,
		extraction_pierce_targets
	)
	if not hits.is_empty() and health_component != null:
		health_component.heal_blood(extraction_drain_per_target * hits.size())
	# TODO (Phase 3 - VFX) : traînée d'éclats sanglants rappelée vers le joueur.


## Petite impulsion d'intimidation lors du Morph (le coût du Morph
## a déjà été prélevé par le WeaponManager, pas de coût supplémentaire ici).
func perform_morph_attack() -> void:
	# TODO (Phase 3) : jouer une animation de "pump" / re-chambrage.
	pass
