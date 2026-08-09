extends StaticBody3D
class_name DummyEnemy

## ============================================================
## DummyEnemy.gd
## ------------------------------------------------------------
## Cible d'entraînement statique pour valider le système de combat.
## Encaisse les dégâts via HurtboxComponent -> HealthComponent,
## flashe blanc à l'impact, "meurt" (désactivée visuellement et
## physiquement), puis se réinitialise après un délai -- comme un
## vrai mannequin de stand de tir, pas un ennemi qui reste mort.
## ============================================================

enum EnemyWeightClass { LIGHT, HEAVY }

@export var respawns: bool = true
@export var respawn_delay: float = 3.0
@export var weight_class: EnemyWeightClass = EnemyWeightClass.LIGHT

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _material: StandardMaterial3D
var _base_color: Color = Color(0.55, 0.15, 0.15)
var _is_dead: bool = false
var _flash_tween: Tween


func _ready() -> void:
	# Liaison Hurtbox -> HealthComponent : c'est le propriétaire (cette
	# entité) qui fait cette liaison, la Hurtbox reste générique/réutilisable.
	hurtbox.health_component = health_component

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	_setup_material()


func _setup_material() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	mesh.set_surface_override_material(0, _material)


func _on_health_changed(current: float, max: float) -> void:
	if _is_dead or current >= max:
		return
	_flash_hit()


## Flash blanc bref à chaque impact, pour un feedback de dégâts immédiat
## et lisible, indépendant de tout système de dégâts numériques affiché.
func _flash_hit() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_material.albedo_color = Color(1, 1, 1)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_material, "albedo_color", _base_color, 0.15)


func _on_died() -> void:
	_is_dead = true
	EventBus.entity_died.emit(self)

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

	visible = true
	collision_shape.disabled = false
	hurtbox.set_deferred("monitorable", true)
	_material.albedo_color = _base_color
