extends WeaponBase
class_name Shotgun


@export_group("Extraction — Rappel d'éclats")
@export var extraction_pierce_targets: int = 4
@export var extraction_damage_per_target: float = 20.0
@export var extraction_drain_per_target: float = 6.0

func _ready() -> void:
	weapon_name = "Shotgun"
	base_damage = 35.0
	max_ammo = 6
	blood_cost_per_shot = 12.0
	morph_cost = 8.0
	fire_cooldown = 0.6

	extraction_cooldown = 0.9
	extraction_ammo_cost = 1
	extraction_blood_cost = 12.0
	allow_held_fire = false
	allow_held_extraction = false
	is_melee = false

	super._ready()


func _on_shoot_effect() -> void:
	_hitscan(base_damage)


func _on_extraction_effect() -> void:
	var hits: Array[HurtboxComponent] = _hitscan_pierce(
		extraction_damage_per_target,
		weapon_range,
		extraction_pierce_targets
	)
	if not hits.is_empty() and health_component != null:
		health_component.heal_blood(_apply_lifesteal(extraction_drain_per_target * hits.size()))


func perform_morph_attack() -> void:
	pass