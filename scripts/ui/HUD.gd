extends Control
class_name HUD

## ============================================================
## HUD.gd
## ------------------------------------------------------------
## Interface : jauge de sang discrète (bas-gauche) + munitions
## de l'arme équipée (bas-droite) + flash plein écran quand le
## joueur perd du sang (Dash, dégâts, tir "à sang"...).
##
## Écoute exclusivement l'EventBus : aucune référence directe au
## Player/HealthComponent/WeaponManager n'est requise.
## ============================================================

@onready var damage_flash: ColorRect = $DamageFlash
@onready var blood_bar: ProgressBar = $BloodPanel/BloodBar
@onready var blood_label: Label = $BloodPanel/BloodLabel
@onready var weapon_label: Label = $WeaponPanel/WeaponLabel
@onready var ammo_label: Label = $WeaponPanel/AmmoLabel

const COLOR_NORMAL_AMMO: Color = Color(1, 0.95, 0.9, 1)
const COLOR_BLOOD_AMMO: Color = Color(0.9, 0.1, 0.15, 1)
const COLOR_FLASH_DENIED: Color = Color(1, 0.2, 0.2, 1)

## Intensité et durée du flash plein écran lors d'une perte de sang.
const DAMAGE_FLASH_ALPHA: float = 0.28
const DAMAGE_FLASH_FADE_TIME: float = 0.35

var _last_health: float = -1.0 # -1 = pas encore initialisé (évite un flash au lancement)
var _damage_flash_tween: Tween


func _ready() -> void:
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.morph_failed.connect(_on_morph_failed)
	EventBus.shot_failed.connect(_on_shot_failed)


func _on_health_changed(current: float, maximum: float) -> void:
	blood_bar.max_value = maximum
	blood_bar.value = current
	if blood_label:
		blood_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]

	# Flash rouge à chaque perte de sang, qu'elle vienne du Dash, de dégâts
	# ennemis, ou d'un tir "à sang". On ignore le tout premier appel (état
	# initial émis par HealthComponent._ready) pour ne pas flasher à vide.
	if _last_health >= 0.0 and current < _last_health:
		_trigger_damage_flash()

	_last_health = current


func _on_weapon_changed(weapon: WeaponBase) -> void:
	weapon_label.text = weapon.weapon_name.to_upper()


## Affiche "6 / 6" en mode normal, ou "SANG (-12)" en rouge quand
## le chargeur est vide et que chaque tir draine directement le Sang.
## Pour les armes de mêlée (max_ammo == 0, ex: Katana), affiche "MELEE".
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


## Petit flash rouge de feedback sur le texte de munitions quand une
## action est refusée (pas assez de Sang pour tirer ou changer d'arme).
func _flash_denied() -> void:
	var tween: Tween = create_tween()
	ammo_label.modulate = COLOR_FLASH_DENIED
	tween.tween_property(ammo_label, "modulate", COLOR_BLOOD_AMMO, 0.25)


## Flash rouge plein écran : monte instantanément à DAMAGE_FLASH_ALPHA,
## puis retombe à 0 en fondu. On tue le tween précédent pour permettre
## des flashs rapprochés (rafale de dégâts) sans les faire s'accumuler
## bizarrement.
func _trigger_damage_flash() -> void:
	if _damage_flash_tween != null and _damage_flash_tween.is_valid():
		_damage_flash_tween.kill()

	damage_flash.color.a = DAMAGE_FLASH_ALPHA
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(damage_flash, "color:a", 0.0, DAMAGE_FLASH_FADE_TIME)