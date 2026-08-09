extends StaticBody3D
class_name DummyEnemy


enum EnemyWeightClass { LIGHT, HEAVY }

@export var respawns: bool = true
@export var respawn_delay: float = 3.0
@export var weight_class: EnemyWeightClass = EnemyWeightClass.LIGHT

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var trauma_component: TraumaComponent = $TraumaComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const COLOR_STAGGER: Color = Color(0.95, 0.05, 0.08)

var _material: StandardMaterial3D
var _base_color: Color = Color(0.55, 0.15, 0.15)
var _is_dead: bool = false
var _flash_tween: Tween
var _stagger_tween: Tween


func _ready() -> void:
	hurtbox.health_component = health_component
	hurtbox.trauma_component = trauma_component
	trauma_component.owner_entity = self

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	trauma_component.staggered.connect(_on_staggered)
	trauma_component.stagger_ended.connect(_on_stagger_ended)

	_setup_material()


func _setup_material() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	mesh.set_surface_override_material(0, _material)


func _on_health_changed(current: float, maximum: float) -> void:
	if _is_dead or current >= maximum:
		return
	_flash_hit()


func _flash_hit() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	var base: Color = COLOR_STAGGER if trauma_component.is_staggered else _base_color
	_material.albedo_color = Color(1, 1, 1)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_material, "albedo_color", base, 0.15)


func _on_staggered() -> void:
	if _stagger_tween != null and _stagger_tween.is_valid():
		_stagger_tween.kill()

	_material.albedo_color = COLOR_STAGGER
	_material.emission_enabled = true
	_material.emission = COLOR_STAGGER
	_material.emission_energy_multiplier = 1.0

	_stagger_tween = create_tween()
	_stagger_tween.set_loops()
	_stagger_tween.tween_property(_material, "emission_energy_multiplier", 2.2, 0.4)
	_stagger_tween.tween_property(_material, "emission_energy_multiplier", 1.0, 0.4)


func _on_stagger_ended() -> void:
	if _stagger_tween != null and _stagger_tween.is_valid():
		_stagger_tween.kill()

	_material.emission_enabled = false
	_material.albedo_color = _base_color


func is_executable() -> bool:
	return not _is_dead and trauma_component.is_staggered
	

func perform_glory_kill() -> void:
	trauma_component.consume_stagger()
	if not _is_dead:
		health_component.consume_blood(health_component.max_health, true)


func _on_died() -> void:
	_is_dead = true
	EventBus.entity_died.emit(self)

	if _stagger_tween != null and _stagger_tween.is_valid():
		_stagger_tween.kill()
	_material.emission_enabled = false

	visible = false
	collision_shape.disabled = true
	hurtbox.set_deferred("monitorable", false)

	if respawns:
		await get_tree().create_timer(respawn_delay).timeout
		_respawn()
	else:
		queue_free()


func _respawn() -> void:
	_is_dead = false
	health_component.reset()
	trauma_component.reset()

	visible = true
	collision_shape.disabled = false
	hurtbox.set_deferred("monitorable", true)
	_material.emission_enabled = false
	_material.albedo_color = _base_color
