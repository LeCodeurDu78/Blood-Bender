extends WeaponBase
class_name Shotgun

## ============================================================
## Shotgun.gd
## ------------------------------------------------------------
## Arme à munitions limitées (6 cartouches). Une fois le chargeur
## vide, chaque tir draine directement 12 PV via le HealthComponent
## (géré automatiquement par WeaponBase.shoot()).
## ============================================================

func _ready() -> void:
	weapon_name = "Shotgun"
	base_damage = 35.0
	max_ammo = 6
	blood_cost_per_shot = 12.0
	morph_cost = 8.0
	fire_cooldown = 0.6
	super._ready()


func _on_shoot_effect() -> void:
	# Dégâts appliqués via hitscan à la portée normale de l'arme (weapon_range).
	_hitscan(base_damage)
	# TODO (Phase 3 - Combat, VFX) : recul caméra, flash de bouche, particules, son.


## Petite impulsion d'intimidation lors du Morph (le coût du Morph
## a déjà été prélevé par le WeaponManager, pas de coût supplémentaire ici).
func perform_morph_attack() -> void:
	# TODO (Phase 3) : jouer une animation de "pump" / re-chambrage.
	pass
