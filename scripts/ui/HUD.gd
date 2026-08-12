extends Control
class_name HUD


@onready var damage_flash      : ColorRect     = $DamageFlash
@onready var blood_bar         : ProgressBar   = $BloodPanel/BloodBar
@onready var blood_label       : Label         = $BloodPanel/BloodLabel
@onready var weapon_label      : Label         = $WeaponPanel/WeaponLabel
@onready var ammo_label        : Label         = $WeaponPanel/AmmoLabel
@onready var charge_panel      : VBoxContainer = $ChargePanel
@onready var charge_bar        : ProgressBar   = $ChargePanel/ChargeBar
@onready var parry_flash       : ColorRect     = $ParryFlash
@onready var block_panel       : Control       = $BlockPanel
@onready var glory_kill_prompt : Label         = $GloryKillPrompt
@onready var doping_status_panel : VBoxContainer = $DopingStatusPanel
@onready var doping_status_label : Label         = $DopingStatusPanel/DopingStatusLabel

const COLOR_NORMAL_AMMO: Color = Color(1, 0.95, 0.9, 1)
const COLOR_BLOOD_AMMO: Color = Color(0.9, 0.1, 0.15, 1)
const COLOR_FLASH_DENIED: Color = Color(1, 0.2, 0.2, 1)
const COLOR_DOPING_BOOST: Color = Color(0.4, 1.0, 0.55, 1)
const COLOR_DOPING_CRASH: Color = Color(1.0, 0.35, 0.3, 1)

const DAMAGE_FLASH_ALPHA: float = 0.28
const DAMAGE_FLASH_FADE_TIME: float = 0.35

const PARRY_FLASH_ALPHA: float = 0.35
const PARRY_FLASH_FADE_TIME: float = 0.25
const COLOR_PARRY_FLASH: Color = Color(1.0, 0.85, 0.4, 1.0)
const COLOR_SURVIVAL_FLASH: Color = Color(0.3, 1.0, 0.5, 1.0)

var _last_health: float = -1.0
var _damage_flash_tween: Tween
var _parry_flash_tween: Tween


func _ready() -> void:
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.morph_failed.connect(_on_morph_failed)
	EventBus.shot_failed.connect(_on_shot_failed)
	EventBus.extraction_failed.connect(_on_extraction_failed)
	EventBus.projectile_charging.connect(_on_projectile_charging)
	EventBus.projectile_fired.connect(_on_projectile_fired)
	EventBus.projectile_failed.connect(_on_projectile_failed)

	EventBus.parry_success.connect(_on_parry_success)
	EventBus.survival_parry_triggered.connect(_on_survival_parry_triggered)
	EventBus.block_started.connect(_on_block_started)
	EventBus.block_ended.connect(_on_block_ended)

	EventBus.grapple_failed.connect(_on_grapple_failed)

	EventBus.doping_activated.connect(_on_doping_activated)
	EventBus.doping_boost_ended.connect(_on_doping_boost_ended)
	EventBus.doping_crash_ended.connect(_on_doping_crash_ended)
	EventBus.doping_denied.connect(_on_doping_denied)

	EventBus.glory_kill_available.connect(_on_glory_kill_available)
	EventBus.glory_kill_unavailable.connect(_on_glory_kill_unavailable)
	EventBus.glory_kill_started.connect(_on_glory_kill_started)


func _on_health_changed(current: float, maximum: float) -> void:
	blood_bar.max_value = maximum
	blood_bar.value = current
	if blood_label:
		blood_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]

	if _last_health >= 0.0 and current < _last_health:
		_trigger_damage_flash()

	_last_health = current


func _on_weapon_changed(weapon: WeaponBase) -> void:
	weapon_label.text = weapon.weapon_name.to_upper()


func _on_ammo_changed(current: int, maximum: int, blood_mode: bool, blood_cost: float) -> void:
	if maximum <= 0:
		ammo_label.text = "MELEE"
		ammo_label.modulate = COLOR_NORMAL_AMMO
		return

	if blood_mode:
		ammo_label.text = "SANG (-%d)" % int(blood_cost)
		ammo_label.modulate = COLOR_BLOOD_AMMO
	else:
		ammo_label.text = "%d / %d" % [current, maximum]
		ammo_label.modulate = COLOR_NORMAL_AMMO


func _on_morph_failed(_weapon_name: String, _required_blood: float) -> void:
	_flash_denied()


func _on_shot_failed(_weapon_name: String) -> void:
	_flash_denied()


func _on_extraction_failed(_weapon_name: String) -> void:
	_flash_denied()


func _on_projectile_charging(ratio: float) -> void:
	charge_panel.visible = true
	charge_bar.value = ratio * 100.0


func _on_projectile_fired(_blood_cost: float, _damage: float) -> void:
	charge_panel.visible = false
	charge_bar.value = 0.0


func _on_projectile_failed(_required_blood: float) -> void:
	charge_panel.visible = false
	charge_bar.value = 0.0
	_flash_denied()


func _flash_denied() -> void:
	var tween: Tween = create_tween()
	ammo_label.modulate = COLOR_FLASH_DENIED
	tween.tween_property(ammo_label, "modulate", COLOR_BLOOD_AMMO, 0.25)


func _trigger_damage_flash() -> void:
	if _damage_flash_tween != null and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()

	damage_flash.color.a = DAMAGE_FLASH_ALPHA
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(damage_flash, "color:a", 0.0, DAMAGE_FLASH_FADE_TIME)


func _on_parry_success(_attacker: Node) -> void:
	_trigger_parry_flash(COLOR_PARRY_FLASH)


func _on_survival_parry_triggered(_healed_amount: float) -> void:
	_trigger_parry_flash(COLOR_SURVIVAL_FLASH)


func _trigger_parry_flash(color: Color) -> void:
	if parry_flash == null:
		return
	if _parry_flash_tween != null and _parry_flash_tween.is_valid():
		_parry_flash_tween.kill()

	parry_flash.color = color
	parry_flash.color.a = PARRY_FLASH_ALPHA
	_parry_flash_tween = create_tween()
	_parry_flash_tween.tween_property(parry_flash, "color:a", 0.0, PARRY_FLASH_FADE_TIME)


func _on_block_started() -> void:
	if block_panel != null:
		block_panel.visible = true


func _on_block_ended() -> void:
	if block_panel != null:
		block_panel.visible = false


func _on_grapple_failed(_required_blood: float) -> void:
	_flash_denied()


func _on_doping_activated(serum_type: String, _boost_duration: float) -> void:
	doping_status_panel.visible = true
	doping_status_label.text = "%s — BOOST" % serum_type.to_upper()
	doping_status_label.modulate = COLOR_DOPING_BOOST


func _on_doping_boost_ended(serum_type: String) -> void:
	doping_status_panel.visible = true
	doping_status_label.text = "%s — CRASH" % serum_type.to_upper()
	doping_status_label.modulate = COLOR_DOPING_CRASH


func _on_doping_crash_ended(_serum_type: String) -> void:
	doping_status_panel.visible = false


func _on_doping_denied(_required_blood: float) -> void:
	_flash_denied()


func _on_glory_kill_available(_enemy: Node) -> void:
	if glory_kill_prompt != null:
		glory_kill_prompt.visible = true


func _on_glory_kill_unavailable() -> void:
	if glory_kill_prompt != null:
		glory_kill_prompt.visible = false


func _on_glory_kill_started(_enemy: Node) -> void:
	_trigger_parry_flash(COLOR_PARRY_FLASH)