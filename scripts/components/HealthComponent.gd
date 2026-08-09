extends Node3D
class_name HealthComponent

signal invulnerability_changed(is_invulnerable: bool)
signal health_changed(current: float, max: float)
signal player_died
signal died


@export var max_health: float = 100.0
@export var is_player_health: bool = false

# --- État interne ---
var current_health: float
var _is_dead: bool = false
var is_invulnerable: bool = false
var _invuln_timer_id: int = 0


func _ready() -> void:
	current_health = max_health
	_broadcast_health()


func set_invulnerable(duration: float) -> void:
	is_invulnerable = true
	invulnerability_changed.emit(true)

	_invuln_timer_id += 1
	var this_call_id: int = _invuln_timer_id

	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		if this_call_id == _invuln_timer_id:
			clear_invulnerability()


func clear_invulnerability() -> void:
	if not is_invulnerable:
		return
	is_invulnerable = false
	invulnerability_changed.emit(false)


func consume_blood(amount: float, allow_lethal: bool = false) -> bool:
	if amount <= 0.0:
		return true

	if allow_lethal and is_invulnerable:
		return false

	if not allow_lethal and (current_health - amount) < 1.0:
		return false

	current_health -= amount
	current_health = max(current_health, 0.0)
	_broadcast_health()

	if current_health <= 0.0 and not _is_dead:
		_is_dead = true
		player_died.emit()
		died.emit()
		if is_player_health:
			EventBus.player_died.emit()

	return true


func heal_blood(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return

	current_health = clamp(current_health + amount, 0.0, max_health)
	_broadcast_health()


func reset() -> void:
	current_health = max_health
	_is_dead = false
	clear_invulnerability()
	_broadcast_health()


func get_health_ratio() -> float:
	return current_health / max_health


func can_afford(amount: float) -> bool:
	return (current_health - amount) >= 1.0


func _broadcast_health() -> void:
	health_changed.emit(current_health, max_health)
	if is_player_health:
		EventBus.health_changed.emit(current_health, max_health)
