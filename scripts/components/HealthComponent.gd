extends Node3D
class_name HealthComponent

## ============================================================
## HealthComponent.gd
## ------------------------------------------------------------
## Composant réutilisable gérant la ressource unique du jeu :
## la SANTÉ (= Sang = Énergie). Utilisé par le joueur ET par
## toutes les entités combattantes (DummyEnemy, futurs ennemis).
##
## IMPORTANT (Phase 3) : ce composant est maintenant partagé par
## le joueur ET les ennemis. Seul le HealthComponent DU JOUEUR
## doit alimenter le HUD via l'EventBus global -- sinon la vie
## d'un ennemi touché viendrait écraser la barre de vie affichée
## à l'écran ! Le flag `is_player_health` contrôle ce filtrage.
## ============================================================

# --- Signaux locaux (connexions directes) ---
signal health_changed(current: float, max: float)
signal player_died  ## Conservé pour compat Phase 1/2 (Player.gd s'y connecte).
signal died         ## Alias générique, identique à player_died, à utiliser
                     ## pour toute entité non-joueur (ennemis, PNJ...).

# --- Paramètres exportés ---
@export var max_health: float = 100.0

## Seul le HealthComponent attaché au Player doit avoir ce flag à `true`.
## Contrôle si cette instance relaie ses signaux sur l'EventBus global
## (utilisé par le HUD). Les ennemis doivent le laisser à `false`.
@export var is_player_health: bool = false

# --- État interne ---
var current_health: float

var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	_broadcast_health()


## Consomme de la vie/sang (dégâts volontaires liés aux capacités du joueur :
## Dash, Morph Attack, tir "à sang", etc., ou dégâts de combat subis).
## `allow_lethal` = true pour les dégâts de combat (armes, ennemis), qui
## doivent pouvoir tuer. Les dépenses de capacités du joueur restent
## toujours non-létales (au moins 1 PV restant).
func consume_blood(amount: float, allow_lethal: bool = false) -> bool:
	if amount <= 0.0:
		return true

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


## Soigne l'entité (exécutions, glyphes de sang, kills, régénération...).
func heal_blood(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return

	current_health = clamp(current_health + amount, 0.0, max_health)
	_broadcast_health()


## Réinitialise complètement le composant (PV pleins, plus "mort").
## Utile pour un respawn de joueur à un checkpoint, ou pour un mannequin
## d'entraînement (DummyEnemy) qui se régénère après un délai.
func reset() -> void:
	current_health = max_health
	_is_dead = false
	_broadcast_health()


func get_health_ratio() -> float:
	return current_health / max_health


## Vérifie si une dépense de `amount` PV est possible sans mourir.
## Utile pour griser une icône d'arme/capacité AVANT de tenter l'action.
func can_afford(amount: float) -> bool:
	return (current_health - amount) >= 1.0


func _broadcast_health() -> void:
	health_changed.emit(current_health, max_health)
	if is_player_health:
		EventBus.health_changed.emit(current_health, max_health)
