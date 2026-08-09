extends Node3D
class_name TraumaComponent

signal trauma_changed(current: float, max_value: float)
signal staggered
signal stagger_ended


@export var decay_rate: float = 40.0
@export var decay_delay: float = 5.0
@export var stagger_duration: float = 3.0

const MAX_TRAUMA: float = 100.0
var current_trauma: float = 0.0
var is_staggered: bool = false
var _time_since_last_hit: float = 0.0
var _stagger_timer: float = 0.0
var owner_entity: Node


func _process(delta: float) -> void:
	if is_staggered:
		_process_stagger(delta)
		return

	if current_trauma <= 0.0:
		return

	_time_since_last_hit += delta

	if _time_since_last_hit >= decay_delay:
		_apply_decay(delta)


func _process_stagger(delta: float) -> void:
	_stagger_timer -= delta
	if _stagger_timer <= 0.0:
		_end_stagger()


func _apply_decay(delta: float) -> void:
	current_trauma = max(current_trauma - decay_rate * delta, 0.0)
	trauma_changed.emit(current_trauma, MAX_TRAUMA)
	if owner_entity != null:
		EventBus.enemy_trauma_changed.emit(owner_entity, get_trauma_ratio())


func add_trauma(amount: float) -> void:
	if is_staggered or amount <= 0.0:
		return

	_time_since_last_hit = 0.0
	current_trauma = clamp(current_trauma + amount, 0.0, MAX_TRAUMA)
	trauma_changed.emit(current_trauma, MAX_TRAUMA)
	if owner_entity != null:
		EventBus.enemy_trauma_changed.emit(owner_entity, get_trauma_ratio())

	if current_trauma >= MAX_TRAUMA:
		_start_stagger()


func _start_stagger() -> void:
	is_staggered = true
	current_trauma = MAX_TRAUMA
	_stagger_timer = stagger_duration
	staggered.emit()
	if owner_entity != null:
		EventBus.enemy_staggered.emit(owner_entity)


func _end_stagger() -> void:
	is_staggered = false
	current_trauma = 0.0
	_time_since_last_hit = 0.0
	trauma_changed.emit(current_trauma, MAX_TRAUMA)
	stagger_ended.emit()
	if owner_entity != null:
		EventBus.enemy_stagger_ended.emit(owner_entity)
		EventBus.enemy_trauma_changed.emit(owner_entity, 0.0)


func consume_stagger() -> void:
	if not is_staggered:
		return
	is_staggered = false
	current_trauma = 0.0
	_time_since_last_hit = 0.0
	trauma_changed.emit(current_trauma, MAX_TRAUMA)
	if owner_entity != null:
		EventBus.enemy_trauma_changed.emit(owner_entity, 0.0)


func get_trauma_ratio() -> float:
	return current_trauma / MAX_TRAUMA


func reset() -> void:
	current_trauma = 0.0
	is_staggered = false
	_time_since_last_hit = 0.0
	_stagger_timer = 0.0
	trauma_changed.emit(current_trauma, MAX_TRAUMA)
