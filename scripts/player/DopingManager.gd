extends Node3D
class_name DopingManager

## Système de Dopage & Roue de Sérums (Phase 3).
##
## Tant que l'action "doping" (Tab / Flèche Bas manette) est maintenue, le
## temps ralentit et une roue de sélection propose 4 sérums. Au relâchement,
## le sérum survolé est injecté (coût en sang) et déclenche un cycle
## Boost (5s) / Crash (10s).
##
## Les autres systèmes (Player, WeaponComponent, WeaponBase, ShieldComponent,
## PlayerHurtboxComponent) n'implémentent pas eux-mêmes la logique des
## sérums : ils interrogent simplement les getters ci-dessous (get_speed_
## multiplier, get_damage_taken_multiplier, etc.) à chaque frame/action.

enum Serum {
	ADRENALINE,
	COAGULANT,
	SEROTONIN,
	HYPER_PRESSION,
}

const SERUM_NAMES: Dictionary = {
	Serum.ADRENALINE: "Adrénaline Hématique",
	Serum.COAGULANT: "Coagulant de Fer",
	Serum.SEROTONIN: "Sérotonine BERSERK",
	Serum.HYPER_PRESSION: "Hyper-Pression",
}

@export_group("Activation & Coût")
@export var injection_cost: float = 20.0
@export var slow_mo_time_scale: float = 0.15  # 85% de ralenti pendant la roue.

@export_group("Durées des effets")
@export var boost_duration: float = 5.0
@export var crash_duration: float = 10.0

@export_group("Roue de Sélection")
@export var wheel_deadzone_px: float = 14.0

@export_group("Sérum 1 — Adrénaline Hématique")
@export var adrenaline_boost_speed_mult: float = 1.6      # +60% vitesse
@export var adrenaline_boost_fire_rate_mult: float = 1.5  # +50% cadence (indicatif, cooldown déjà annulé)
@export var adrenaline_crash_speed_mult: float = 0.6      # -40% vitesse
@export var adrenaline_crash_switch_cost_mult: float = 2.0  # coût de switch doublé

@export_group("Sérum 2 — Coagulant de Fer")
@export var coagulant_boost_damage_taken_mult: float = 0.2   # -80% dégâts subis
@export var coagulant_crash_damage_taken_mult: float = 1.5   # +50% dégâts subis

@export_group("Sérum 3 — Sérotonine BERSERK")
@export var serotonin_boost_melee_mult: float = 3.0          # x3 dégâts CàC / vol de sang
@export var serotonin_crash_bleed_per_second: float = 2.0    # -2 PV/s

@export_group("Sérum 4 — Hyper-Pression")
@export var hyperpression_boost_time_scale: float = 0.4      # ralenti mondial pendant le Boost
@export var hyperpression_crash_action_mult: float = 0.7     # -30% vitesse des actions (cooldowns x1.43)


var health_component: HealthComponent

# --- État de la roue ---
var is_wheel_open: bool = false
var hovered_serum: int = Serum.ADRENALINE
var _wheel_pointer_offset: Vector2 = Vector2.ZERO

# --- État Boost/Crash ---
var active_serum: int = -1
var is_boost_active: bool = false
var is_crash_active: bool = false


func set_health_component(hc: HealthComponent) -> void:
	health_component = hc


func _process(delta: float) -> void:
	_handle_wheel_input()

	if is_crash_active and active_serum == Serum.SEROTONIN:
		_process_serotonin_bleed(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_wheel_open:
		return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_wheel_pointer_offset += motion.relative
		_update_hovered_serum()


func _exit_tree() -> void:
	# Sécurité anti-blocage : si le composant disparaît pendant que la roue
	# est ouverte ou que le monde est ralenti par Hyper-Pression, on ne
	# laisse jamais le jeu bloqué en time_scale != 1.0.
	if is_wheel_open or (is_boost_active and active_serum == Serum.HYPER_PRESSION):
		Engine.time_scale = 1.0


## À appeler depuis un futur menu pause / écran de fin pour garantir que le
## ralenti ne reste jamais actif pendant que le jeu est en pause.
func force_reset_time_scale() -> void:
	if is_wheel_open:
		is_wheel_open = false
		EventBus.doping_wheel_closed.emit()
	Engine.time_scale = 1.0


# ------------------------------------------------------------------
# Roue de sélection & Slow-Mo
# ------------------------------------------------------------------

func _handle_wheel_input() -> void:
	if Input.is_action_just_pressed("doping") and not is_wheel_open:
		_open_wheel()

	if is_wheel_open and Input.is_action_just_released("doping"):
		_close_wheel_and_inject()


func _open_wheel() -> void:
	is_wheel_open = true
	_wheel_pointer_offset = Vector2.ZERO
	hovered_serum = Serum.ADRENALINE

	Engine.time_scale = slow_mo_time_scale

	EventBus.doping_wheel_opened.emit()
	EventBus.doping_wheel_hover_changed.emit(SERUM_NAMES[hovered_serum])


func _update_hovered_serum() -> void:
	if _wheel_pointer_offset.length() < wheel_deadzone_px:
		return

	# Roue à 4 secteurs de 90° : droite = Adrénaline, bas = Coagulant,
	# gauche = Sérotonine, haut = Hyper-Pression. angle() : 0 = droite,
	# +PI/2 = bas (le Y souris augmente vers le bas de l'écran).
	var angle: float = _wheel_pointer_offset.angle()
	var new_hover: int

	if angle > -PI * 0.25 and angle <= PI * 0.25:
		new_hover = Serum.ADRENALINE
	elif angle > PI * 0.25 and angle <= PI * 0.75:
		new_hover = Serum.COAGULANT
	elif angle > PI * 0.75 or angle <= -PI * 0.75:
		new_hover = Serum.SEROTONIN
	else:
		new_hover = Serum.HYPER_PRESSION

	if new_hover != hovered_serum:
		hovered_serum = new_hover
		EventBus.doping_wheel_hover_changed.emit(SERUM_NAMES[hovered_serum])


func _close_wheel_and_inject() -> void:
	is_wheel_open = false
	Engine.time_scale = 1.0
	EventBus.doping_wheel_closed.emit()
	_try_inject(hovered_serum)


# ------------------------------------------------------------------
# Injection & cycle Boost / Crash
# ------------------------------------------------------------------

func _try_inject(serum: int) -> void:
	if health_component == null:
		return

	# Règle de sécurité à 1 PV : refusé si le joueur n'a pas au moins
	# injection_cost + 1 PV (donc < 21 PV pour un coût de 20).
	if not health_component.can_afford(injection_cost):
		EventBus.doping_denied.emit(injection_cost)
		return

	var success: bool = health_component.consume_blood(injection_cost)
	if not success:
		EventBus.doping_denied.emit(injection_cost)
		return

	_start_boost(serum)


func _start_boost(serum: int) -> void:
	active_serum = serum
	is_boost_active = true
	is_crash_active = false

	if serum == Serum.HYPER_PRESSION:
		Engine.time_scale = hyperpression_boost_time_scale

	EventBus.doping_activated.emit(SERUM_NAMES[serum], boost_duration)

	# ignore_time_scale=true : ce minuteur compte toujours en secondes
	# réelles, qu'il soit affecté par la roue ou par le ralenti mondial
	# du Hyper-Pression qu'il vient lui-même de déclencher.
	var boost_timer: SceneTreeTimer = get_tree().create_timer(boost_duration, true, false, true)
	boost_timer.timeout.connect(_on_boost_timeout.bind(serum))


func _on_boost_timeout(serum: int) -> void:
	if active_serum != serum:
		return  # Un nouveau sérum a déjà pris le relais entre-temps.

	is_boost_active = false

	if serum == Serum.HYPER_PRESSION:
		Engine.time_scale = 1.0

	EventBus.doping_boost_ended.emit(SERUM_NAMES[serum])
	_start_crash(serum)


func _start_crash(serum: int) -> void:
	is_crash_active = true

	var crash_timer: SceneTreeTimer = get_tree().create_timer(crash_duration, true, false, true)
	crash_timer.timeout.connect(_on_crash_timeout.bind(serum))


func _on_crash_timeout(serum: int) -> void:
	if active_serum != serum:
		return

	is_crash_active = false
	active_serum = -1
	EventBus.doping_crash_ended.emit(SERUM_NAMES[serum])


func _process_serotonin_bleed(delta: float) -> void:
	if health_component == null:
		return
	# consume_blood respecte déjà la règle de sécurité à 1 PV : le
	# saignement passif ne peut jamais tuer le joueur.
	health_component.consume_blood(serotonin_crash_bleed_per_second * delta)


# ------------------------------------------------------------------
# API consultée par les autres systèmes
# ------------------------------------------------------------------

func get_speed_multiplier() -> float:
	if is_boost_active and active_serum == Serum.ADRENALINE:
		return adrenaline_boost_speed_mult
	if is_crash_active and active_serum == Serum.ADRENALINE:
		return adrenaline_crash_speed_mult
	return 1.0


## Multiplicateur appliqué au fire_cooldown d'une arme après un tir.
## 0.0 -> cooldown annulé (tir illimité pendant le Boost Adrénaline).
func get_fire_cooldown_multiplier() -> float:
	if is_boost_active and active_serum == Serum.ADRENALINE:
		return 0.0
	if is_crash_active and active_serum == Serum.HYPER_PRESSION:
		return 1.0 / hyperpression_crash_action_mult
	return 1.0


func get_weapon_switch_cost_multiplier() -> float:
	if is_crash_active and active_serum == Serum.ADRENALINE:
		return adrenaline_crash_switch_cost_mult
	return 1.0


func get_damage_taken_multiplier() -> float:
	if is_boost_active and active_serum == Serum.COAGULANT:
		return coagulant_boost_damage_taken_mult
	if is_crash_active and active_serum == Serum.COAGULANT:
		return coagulant_crash_damage_taken_mult
	return 1.0


func is_knockback_immune() -> bool:
	return is_boost_active and active_serum == Serum.COAGULANT


func can_parry_or_block() -> bool:
	return not (is_crash_active and active_serum == Serum.COAGULANT)


func get_melee_damage_multiplier() -> float:
	if is_boost_active and active_serum == Serum.SEROTONIN:
		return serotonin_boost_melee_mult
	return 1.0


func get_lifesteal_multiplier() -> float:
	if is_boost_active and active_serum == Serum.SEROTONIN:
		return serotonin_boost_melee_mult
	return 1.0


## Compense le ralenti mondial du Hyper-Pression pour que le JOUEUR
## continue de se déplacer à vitesse normale pendant que le reste du monde
## (ennemis, projectiles, animations) tourne au ralenti. À multiplier avec
## la vélocité du joueur juste avant move_and_slide().
func get_bullet_time_correction() -> float:
	if is_boost_active and active_serum == Serum.HYPER_PRESSION and Engine.time_scale > 0.0:
		return 1.0 / Engine.time_scale
	return 1.0
