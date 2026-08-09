extends Area3D
class_name HurtboxComponent

signal knockback_requested(direction: Vector3, force: float)


@export var damage_multiplier: float = 1.0
@export var is_weak_point: bool = false
@export var trauma_per_damage: float = 1.5

var health_component: HealthComponent
var trauma_component: TraumaComponent


func _ready() -> void:
	monitoring = false
	monitorable = true


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> bool:
	var final_damage: float = amount * damage_multiplier
	var applied: bool = health_component.consume_blood(final_damage, true)

	if applied:
		EventBus.entity_damaged.emit(self, final_damage, hit_position)
		if trauma_component != null:
			trauma_component.add_trauma(final_damage * trauma_per_damage)

	return applied


func apply_trauma(amount: float) -> void:
	if trauma_component != null:
		trauma_component.add_trauma(amount)


func apply_knockback(direction: Vector3, force: float) -> void:
	knockback_requested.emit(direction, force)