extends CharacterBody3D
class_name Player


@export_group("Movement")
@export var walk_speed: float = 7.0
@export var acceleration: float = 12.0
@export var air_acceleration: float = 4.0
@export var jump_velocity: float = 5.2
@export var gravity_multiplier: float = 1.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_deg: float = -89.0
@export var max_pitch_deg: float = 89.0

@export_group("Blood Dash")
@export var dash_blood_cost: float = 5.0
@export var dash_speed: float = 24.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.6

@export_group("Blood Projectile")
@export var projectile_scene: PackedScene
@export var projectile_max_charge_time: float = 1.2
@export var projectile_min_blood_cost: float = 10.0
@export var projectile_max_blood_cost: float = 25.0
@export var projectile_min_damage: float = 25.0
@export var projectile_max_damage: float = 70.0
@export var projectile_speed: float = 40.0
@export var projectile_spawn_offset: float = 1.0

@export_group("Glory Kills")
@export var glory_kill_range: float = 3.5
@export var glory_kill_angle_deg: float = 20.0
@export var glory_kill_iframes_duration: float = 1.2


@onready var head              : Node3D                  = $Head
@onready var camera            : Camera3D                = $Head/Camera3D
@onready var health_component  : HealthComponent         = $HealthComponent
@onready var weapon_component  : WeaponComponent         = $Head/Camera3D/WeaponComponent
@onready var shield_component  : ShieldComponent         = $ShieldComponent
@onready var grapple_component : GrappleComponent        = $GrappleComponent
@onready var doping_component  : DopingManager           = $DopingManager
@onready var hurtbox           : PlayerHurtboxComponent  = $HurtboxComponent


var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch: float = 0.0

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO

var _is_charging_projectile: bool = false
var _projectile_charge_timer: float = 0.0

var _current_executable_enemy: Node3D = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_component.player_died.connect(_on_player_died)
	
	weapon_component.set_health_component(health_component)
	weapon_component.set_doping_component(doping_component)

	shield_component.set_health_component(health_component)
	shield_component.set_doping_component(doping_component)

	grapple_component.set_health_component(health_component)
	grapple_component.set_camera(camera)
	grapple_component.set_player(self)

	doping_component.set_health_component(health_component)

	hurtbox.health_component = health_component
	hurtbox.shield_component = shield_component
	hurtbox.doping_component = doping_component


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _is_doping_wheel_open():
		var motion: InputEventMouseMotion = event

		rotate_y(-motion.relative.x * mouse_sensitivity)

		_pitch -= motion.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		head.rotation.x = _pitch

	# Libérer/recapturer la souris (pratique en debug)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_glory_kill_detection()
	_handle_glory_kill_input()

	if grapple_component.is_active:
		velocity = grapple_component.get_travel_velocity(delta, global_transform.origin)
		move_and_slide()
		return

	_apply_gravity(delta)
	_handle_jump()
	_handle_dash_input()
	_handle_projectile_charge(delta)

	if _is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	_move_with_bullet_time_correction()


func _is_doping_wheel_open() -> bool:
	return doping_component != null and doping_component.is_wheel_open


func _move_with_bullet_time_correction() -> void:
	## Le Boost "Hyper-Pression" ralentit Engine.time_scale pour TOUT le
	## monde (ennemis, projectiles, animations). On compense la vélocité du
	## joueur UNIQUEMENT pour l'appel à move_and_slide() (qui déplace le
	## joueur sur la durée réelle de la frame), puis on la ramène aussitôt
	## à sa valeur "normale" avant de la stocker.
	##
	## IMPORTANT : `velocity` est un état persistant (accumulation de la
	## gravité, base du move_toward de _process_movement). Le multiplier de
	## façon permanente le ferait grossir de façon exponentielle frame après
	## frame (chaque frame appliquerait la correction PAR-DESSUS la
	## correction déjà stockée la frame précédente), jusqu'à dépasser les
	## limites du float (NaN/Inf) — d'où le franchissement des murs et le
	## crash "instance_set_transform". On ne scale donc jamais `velocity`
	## de façon durable : seule la frame courante, au moment précis de
	## l'appel à move_and_slide(), est affectée.
	var correction: float = 1.0
	if doping_component != null:
		correction = doping_component.get_bullet_time_correction()

	if correction == 1.0:
		move_and_slide()
		return

	velocity *= correction
	move_and_slide()
	# Retour immédiat en espace "normal" : la gravité et les calculs de
	# mouvement de la frame suivante repartent d'une base saine.
	velocity /= correction
	_sanitize_velocity()


func _sanitize_velocity() -> void:
	## Filet de sécurité : si un cumul de multiplicateurs (dopage, dash,
	## etc.) produit un jour une vélocité non-finie (NaN/Inf), on la
	## réinitialise plutôt que de laisser Godot planter sur
	## instance_set_transform au frame suivant.
	if not (is_finite(velocity.x) and is_finite(velocity.y) and is_finite(velocity.z)):
		push_warning("Player: vélocité non-finie détectée, réinitialisation à zéro.")
		velocity = Vector3.ZERO


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func _process_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed_multiplier: float = doping_component.get_speed_multiplier() if doping_component != null else 1.0
	var current_speed: float = walk_speed * speed_multiplier
	var accel: float = acceleration if is_on_floor() else air_acceleration

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta * current_speed)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta * current_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta * current_speed)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta * current_speed)


func _handle_dash_input() -> void:
	if _is_dashing or _dash_cooldown_timer > 0.0:
		return

	if Input.is_action_just_pressed("blood_dash"):
		_try_start_dash()


func _try_start_dash() -> void:
	var success: bool = health_component.consume_blood(dash_blood_cost)

	if not success:
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var local_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)

	if local_dir == Vector3.ZERO:
		local_dir = Vector3.FORWARD

	_dash_direction = (transform.basis * local_dir).normalized()
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown

	velocity.y = 0.0


func _process_dash(delta: float) -> void:
	velocity.x = _dash_direction.x * dash_speed
	velocity.z = _dash_direction.z * dash_speed
	velocity.y = 0.0

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_is_dashing = false
		velocity.x *= 0.4
		velocity.z *= 0.4


func _update_timers(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta


func _handle_projectile_charge(delta: float) -> void:
	if Input.is_action_just_pressed("projectile"):
		_is_charging_projectile = true
		_projectile_charge_timer = 0.0
		EventBus.projectile_charge_started.emit()

	if _is_charging_projectile:
		_projectile_charge_timer = min(_projectile_charge_timer + delta, projectile_max_charge_time)
		var ratio: float = _projectile_charge_timer / projectile_max_charge_time
		EventBus.projectile_charging.emit(ratio)

	if Input.is_action_just_released("projectile") and _is_charging_projectile:
		_fire_blood_projectile()
		_is_charging_projectile = false
		_projectile_charge_timer = 0.0


func _fire_blood_projectile() -> void:
	var ratio: float = _projectile_charge_timer / projectile_max_charge_time
	var blood_cost: float = lerp(projectile_min_blood_cost, projectile_max_blood_cost, ratio)

	if health_component == null or not health_component.can_afford(blood_cost):
		EventBus.projectile_failed.emit(blood_cost)
		return

	var success: bool = health_component.consume_blood(blood_cost)
	if not success:
		EventBus.projectile_failed.emit(blood_cost)
		return

	var damage: float = lerp(projectile_min_damage, projectile_max_damage, ratio)
	_spawn_projectile(damage)
	EventBus.projectile_fired.emit(blood_cost, damage)


func _spawn_projectile(damage: float) -> void:
	var direction: Vector3 = -camera.global_transform.basis.z
	var spawn_origin: Vector3 = camera.global_transform.origin + direction * projectile_spawn_offset

	var projectile: Node3D = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform.origin = spawn_origin

	if projectile.has_method("launch"):
		projectile.launch(direction, projectile_speed, damage)


func look_at_point(target_position: Vector3) -> void:
	var flat_target: Vector3 = Vector3(target_position.x, global_transform.origin.y, target_position.z)
	if flat_target.distance_to(global_transform.origin) < 0.01:
		return
	look_at(flat_target, Vector3.UP)


func _handle_glory_kill_detection() -> void:
	var found: Node3D = _find_executable_enemy_in_view()

	if found != _current_executable_enemy:
		_current_executable_enemy = found
		if found != null:
			EventBus.glory_kill_available.emit(found)
		else:
			EventBus.glory_kill_unavailable.emit()

func _find_executable_enemy_in_view() -> Node3D:
	if camera == null:
		return null

	var ray_range: float = glory_kill_range
	var from: Vector3 = camera.global_transform.origin
	var to: Vector3 = from - camera.global_transform.basis.z * ray_range

	# Utilisation de PhysicsRayQueryParameters3D comme dans _hitscan
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b100  # Layer 3 (Enemy Hurtbox)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	# Récupération du space_state directement depuis la caméra comme dans _hitscan
	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider: Object = result.get("collider")
	if collider is HurtboxComponent:
		var _hurtbox: HurtboxComponent = collider
		var enemy: Node3D = _hurtbox.get_parent() as Node3D
		if enemy != null and enemy.has_method("is_executable") and enemy.is_executable():
			return enemy

	return null


func _handle_glory_kill_input() -> void:
	if Input.is_action_just_pressed("glory_kill"):
		_perform_glory_kill()

func _perform_glory_kill() -> void:
	if _current_executable_enemy == null:
		return

	var enemy: Node3D = _current_executable_enemy

	EventBus.glory_kill_started.emit(enemy)
	health_component.set_invulnerable(glory_kill_iframes_duration)
	health_component.heal_blood(health_component.max_health)

	enemy.perform_glory_kill()

	_current_executable_enemy = null
	EventBus.glory_kill_unavailable.emit()
	EventBus.glory_kill_finished.emit(enemy)


func _on_player_died() -> void:
	print("Player died — Blood fully drained.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(false)
