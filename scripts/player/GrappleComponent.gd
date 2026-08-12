extends Node3D
class_name GrappleComponent

@export_group("Coût & Portée")
@export var blood_cost: float = 8.0
@export var max_range: float = 30.0
@export_flags_3d_physics var grapple_mask: int = 0b101

@export_group("Validation de Surface")
## Normale d'impact (result.normal) au-delà de laquelle la surface est
## considérée comme un sol/pente douce et donc refusée. 0.5 ≈ 60° depuis
## la verticale (≈ 30° d'inclinaison depuis l'horizontale). Seules les
## surfaces avec normal.y <= ce seuil (murs, pans verticaux) sont acceptées.
@export_range(0.0, 1.0, 0.01) var floor_normal_threshold: float = 0.5

@export_group("Cinématique")
@export var travel_speed: float = 45.0
@export var travel_duration: float = 0.5
@export var arrival_distance: float = 1.5

@export_group("Ennemi Léger")
@export var enemy_pull_speed: float = 18.0
@export var enemy_pull_duration: float = 0.4

var health_component: HealthComponent
var camera: Camera3D
var player: Node3D

# --- État interne : trajet du JOUEUR (décor ou ennemi lourd) ---
var is_active: bool = false
var _travel_target: Vector3 = Vector3.ZERO
var _travel_timer: float = 0.0

# --- État interne : traction d'un ennemi LÉGER vers le joueur ---
var _is_pulling_enemy: bool = false
var _pulled_enemy: Node3D = null
var _pulled_enemy_hurtbox: HurtboxComponent = null
var _pull_timer: float = 0.0


func set_health_component(hc: HealthComponent) -> void:
	health_component = hc


func set_camera(cam: Camera3D) -> void:
	camera = cam


func set_player(p: Node3D) -> void:
	player = p


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("grapple_hook"):
		_try_fire()

	if _is_pulling_enemy:
		_process_enemy_pull(delta)


func _try_fire() -> void:
	if is_active or _is_pulling_enemy:
		return  # Un grappin est déjà en cours.

	if not health_component.can_afford(blood_cost):
		EventBus.grapple_failed.emit(blood_cost)
		return

	var result: Dictionary = _raycast_target()
	if result.is_empty() or not _is_valid_target(result):
		# Cible invalide (rien touché, ou sol/pente douce) : aucun coût,
		# feedback d'échec via le même signal que pour le sang insuffisant.
		EventBus.grapple_failed.emit(blood_cost)
		return

	var success: bool = health_component.consume_blood(blood_cost)
	if not success:
		EventBus.grapple_failed.emit(blood_cost)
		return

	_resolve_target(result)


func _is_valid_target(result: Dictionary) -> bool:
	var collider: Object = result.get("collider")

	# Les ennemis (hurtbox) sont toujours des cibles valides, quelle que
	# soit l'orientation de leur collision shape.
	if collider is HurtboxComponent:
		return true

	# Décor/environnement : on rejette le sol et les pentes douces en
	# regardant la normale de la surface touchée. Une normale pointant
	# fortement vers le haut (normal.y élevé) signifie un sol/pente ;
	# on n'autorise que les surfaces verticales (murs) ou proches.
	var normal: Vector3 = result.get("normal", Vector3.UP)
	return normal.y <= floor_normal_threshold


func _raycast_target() -> Dictionary:
	var from: Vector3 = camera.global_transform.origin
	var to: Vector3 = from - camera.global_transform.basis.z * max_range

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = grapple_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	return space_state.intersect_ray(query)


func _resolve_target(result: Dictionary) -> void:
	var collider: Object = result.get("collider")
	var hit_position: Vector3 = result.get("position", Vector3.ZERO)

	# Cas 1 : Hurtbox d'ennemi -> comportement dépend du gabarit.
	if collider is HurtboxComponent:
		var hurtbox: HurtboxComponent = collider
		var enemy: Node3D = hurtbox.get_parent() as Node3D

		if enemy != null and enemy.has_method("is_executable") and "weight_class" in enemy:
			if enemy.weight_class == DummyEnemy.EnemyWeightClass.HEAVY:
				_start_player_travel(enemy.global_transform.origin, "enemy_heavy")
				EventBus.grapple_hit.emit("enemy_heavy", enemy)
				return
			else:
				_start_enemy_pull(enemy, hurtbox)
				EventBus.grapple_hit.emit("enemy_light", enemy)
				return

	_start_player_travel(hit_position, "world")
	EventBus.grapple_hit.emit("world", null)


func _start_player_travel(target: Vector3, target_type: String) -> void:
	is_active = true
	_travel_target = target
	_travel_timer = travel_duration
	EventBus.grapple_fired.emit(target_type)


func get_travel_velocity(delta: float, current_position: Vector3) -> Vector3:
	if not is_active:
		return Vector3.ZERO

	_travel_timer -= delta

	var to_target: Vector3 = _travel_target - current_position
	var distance: float = to_target.length()

	if distance <= arrival_distance or _travel_timer <= 0.0:
		is_active = false
		EventBus.grapple_finished.emit()
		return Vector3.ZERO

	return to_target.normalized() * travel_speed


func _start_enemy_pull(enemy: Node3D, hurtbox: HurtboxComponent) -> void:
	_is_pulling_enemy = true
	_pulled_enemy = enemy
	_pulled_enemy_hurtbox = hurtbox
	_pull_timer = enemy_pull_duration
	EventBus.grapple_fired.emit("enemy_light")


func _process_enemy_pull(delta: float) -> void:
	if _pulled_enemy == null or not is_instance_valid(_pulled_enemy) or player == null:
		_end_enemy_pull()
		return

	_pull_timer -= delta

	var to_player: Vector3 = player.global_transform.origin - _pulled_enemy.global_transform.origin
	var distance: float = to_player.length()

	if distance <= arrival_distance or _pull_timer <= 0.0:
		_end_enemy_pull()
		return

	var step: Vector3 = to_player.normalized() * enemy_pull_speed * delta
	if step.length() > distance:
		step = to_player

	_pulled_enemy.global_transform.origin += step


func _end_enemy_pull() -> void:
	_is_pulling_enemy = false
	_pulled_enemy = null
	_pulled_enemy_hurtbox = null
	EventBus.grapple_finished.emit()