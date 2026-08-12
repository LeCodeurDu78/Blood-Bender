extends Node3D
class_name ShieldComponent

@export_group("Parade Parfaite")
@export var parry_window: float = 0.2

@export_group("Parade de Survie")
@export var survival_threshold: float = 1.0
@export var survival_heal_min: float = 15.0
@export var survival_heal_max: float = 20.0

@export_group("Blocage d'Urgence")
@export var block_blood_cost_per_second: float = 2.0

var health_component: HealthComponent
var doping_component: DopingManager

# --- État interne ---
var _is_holding: bool = false
var _hold_timer: float = 0.0
var _is_parry_window_open: bool = false
var _is_blocking: bool = false


func set_health_component(hc: HealthComponent) -> void:
	health_component = hc


func set_doping_component(dm: DopingManager) -> void:
	doping_component = dm


func _process(delta: float) -> void:
	_handle_input(delta)


func _handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("shield_parry"):
		_start_hold()

	if _is_holding:
		_hold_timer += delta

		if _is_parry_window_open and _hold_timer > parry_window:
			_is_parry_window_open = false
			_try_start_block()

		if _is_blocking:
			_process_block(delta)

	if Input.is_action_just_released("shield_parry"):
		_release_hold()


func _start_hold() -> void:
	# Coagulant de Fer (Crash) : parades et blocages impossibles.
	if doping_component != null and not doping_component.can_parry_or_block():
		EventBus.parry_failed.emit()
		return

	_is_holding = true
	_hold_timer = 0.0
	_is_parry_window_open = true
	EventBus.parry_started.emit()


func _release_hold() -> void:
	if _is_parry_window_open:
		EventBus.parry_failed.emit()

	if _is_blocking:
		_end_block()

	_is_holding = false
	_is_parry_window_open = false


func _try_start_block() -> void:
	if health_component == null:
		return

	if health_component.current_health <= survival_threshold:
		return

	_is_blocking = true
	EventBus.block_started.emit()


func _process_block(delta: float) -> void:
	if health_component == null:
		_end_block()
		return

	var cost: float = block_blood_cost_per_second * delta
	var success: bool = health_component.consume_blood(cost)

	if not success:
		_end_block()


func _end_block() -> void:
	if not _is_blocking:
		return
	_is_blocking = false
	EventBus.block_ended.emit()


func resolve_incoming_attack(attacker: Node = null) -> Dictionary:
	if _is_parry_window_open:
		return _resolve_perfect_parry(attacker)

	if _is_blocking:
		return { "absorbed": true, "damage_multiplier": 0.0 }

	return { "absorbed": false, "damage_multiplier": 1.0 }


func _resolve_perfect_parry(attacker: Node) -> Dictionary:
	_is_parry_window_open = false

	EventBus.parry_success.emit(attacker)
	_stagger_attacker(attacker)
	_check_survival_parry()

	return { "absorbed": true, "damage_multiplier": 0.0 }


func _stagger_attacker(attacker: Node) -> void:
	if attacker == null:
		return

	var trauma: TraumaComponent = attacker.get_node_or_null("TraumaComponent") as TraumaComponent
	if trauma != null:
		trauma.add_trauma(trauma.MAX_TRAUMA)  # Remplissage instantané -> Stagger immédiat.


func _check_survival_parry() -> void:
	if health_component == null:
		return

	if health_component.current_health > survival_threshold:
		return

	var heal_amount: float = randf_range(survival_heal_min, survival_heal_max)
	health_component.heal_blood(heal_amount)
	EventBus.survival_parry_triggered.emit(heal_amount)


func is_defended() -> bool:
	return _is_parry_window_open or _is_blocking