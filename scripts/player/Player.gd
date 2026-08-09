extends CharacterBody3D
class_name Player

## ============================================================
## Player.gd
## ------------------------------------------------------------
## Contrôleur Fast-FPS : déplacement, caméra souris, gravité,
## saut, et Dash de Phase Sanguine (consomme du sang via
## HealthComponent).
## ============================================================

# --- Déplacement ---
@export_group("Movement")
@export var walk_speed: float = 7.0
@export var acceleration: float = 12.0
@export var air_acceleration: float = 4.0
@export var jump_velocity: float = 5.2
@export var gravity_multiplier: float = 1.0

# --- Caméra ---
@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_deg: float = -89.0
@export var max_pitch_deg: float = 89.0

# --- Dash de Phase Sanguine ---
@export_group("Blood Dash")
@export var dash_blood_cost: float = 5.0
@export var dash_speed: float = 24.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.6

# --- Nœuds enfants ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_component: WeaponComponent = $Head/Camera3D/WeaponComponent

# --- État interne ---
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pitch: float = 0.0

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_component.player_died.connect(_on_player_died)
	# Le WeaponManager a besoin du HealthComponent pour le coût des
	# Morph Attacks et la conversion munitions -> sang de chaque arme.
	weapon_component.set_health_component(health_component)


func _unhandled_input(event: InputEvent) -> void:
	# Rotation caméra à la souris.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event

		# Rotation horizontale : on tourne le corps entier (yaw).
		rotate_y(-motion.relative.x * mouse_sensitivity)

		# Rotation verticale : uniquement la tête/caméra (pitch), avec clamp.
		_pitch -= motion.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		head.rotation.x = _pitch

	# Libérer/recapturer la souris (pratique en debug).
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_dash_input()

	if _is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta)

	move_and_slide()


# --- Gravité ---
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta


# --- Saut ---
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


# --- Déplacement classique WASD / ZQSD ---
func _process_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var current_speed: float = walk_speed
	var accel: float = acceleration if is_on_floor() else air_acceleration

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, accel * delta * current_speed)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, accel * delta * current_speed)
	else:
		# Frottement / décélération.
		velocity.x = move_toward(velocity.x, 0.0, accel * delta * current_speed)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta * current_speed)


# --- Dash de Phase Sanguine ---
func _handle_dash_input() -> void:
	if _is_dashing or _dash_cooldown_timer > 0.0:
		return

	if Input.is_action_just_pressed("blood_dash"):
		_try_start_dash()


func _try_start_dash() -> void:
	# On tente de consommer le sang AVANT de lancer le dash.
	# consume_blood() refuse la dépense si elle doit tuer le joueur (< 1 PV restant).
	var success: bool = health_component.consume_blood(dash_blood_cost)

	if not success:
		# Pas assez de sang : le dash échoue silencieusement (à toi d'ajouter
		# un feedback UI/son "dash refusé" plus tard).
		return

	# Direction du dash = direction actuelle des inputs, sinon direction du regard.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var local_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)

	if local_dir == Vector3.ZERO:
		local_dir = Vector3.FORWARD

	_dash_direction = (transform.basis * local_dir).normalized()
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown

	# On annule la gravité verticale pendant le dash pour un mouvement franc et lisible.
	velocity.y = 0.0


func _process_dash(delta: float) -> void:
	velocity.x = _dash_direction.x * dash_speed
	velocity.z = _dash_direction.z * dash_speed
	velocity.y = 0.0

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_is_dashing = false
		# On coupe la vitesse horizontale à la sortie du dash pour éviter
		# un "glissement" excessif ; ajuste selon le feeling voulu.
		velocity.x *= 0.4
		velocity.z *= 0.4


func _update_timers(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta


# --- Mort ---
func _on_player_died() -> void:
	# Placeholder Phase 1 : à remplacer par un écran de mort / reload de checkpoint.
	print("Player died — Blood fully drained.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(false)
