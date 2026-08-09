extends Area3D
class_name HurtboxComponent

## ============================================================
## HurtboxComponent.gd
## ------------------------------------------------------------
## Récepteur de dégâts générique, sous forme d'Area3D. À placer
## sur toute entité pouvant être touchée par une arme (ennemis,
## objets destructibles, futurs boss...).
##
## Ce composant ne connaît PAS son "propriétaire" par défaut :
## l'entité qui le possède (ex: DummyEnemy) doit lui assigner
## `health_component` après instanciation, dans son propre _ready().
## Cette séparation Hitbox (l'arme qui tire) / Hurtbox (l'entité qui
## encaisse) permet de placer plusieurs Hurtbox sur une même entité
## plus tard (ex: zone "tête" avec `damage_multiplier` supérieur).
## ============================================================

## Multiplicateur de dégâts propre à cette zone (ex: 2.0 pour une
## Hurtbox "tête" sur un ennemi plus détaillé en Phase 4+).
@export var damage_multiplier: float = 1.0

## PHASE 1 : marque cette Hurtbox comme "point faible". Utilisé par
## l'Estoc chirurgical du Katana (extraction) : un coup porté sur un
## point faible déclenche un vol de vie critique (15-25 PV) au lieu
## d'un simple dégât. Placer plusieurs HurtboxComponent sur une même
## entité (ex: "tête") avec ce flag à `true` pour créer des zones
## critiques ciblables.
@export var is_weak_point: bool = false

## Émis quand une attaque avec repoussement (ex: Moulinet 360° de la
## Faux) touche cette Hurtbox. L'entité propriétaire (DummyEnemy,
## futurs ennemis avec physique) s'y connecte pour appliquer une
## impulsion réelle sur son propre corps physique.
signal knockback_requested(direction: Vector3, force: float)

var health_component: HealthComponent


func _ready() -> void:
	# Une Hurtbox n'a pas besoin de détecter quoi que ce soit elle-même :
	# elle est seulement CIBLÉE par les raycasts des armes.
	monitoring = false
	monitorable = true


## Appelé directement par le code des armes (WeaponBase._hitscan) au
## moment de l'impact. Retourne `true` si les dégâts ont bien été
## appliqués (false si aucun HealthComponent n'est assigné).
func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> bool:
	if health_component == null:
		push_warning("HurtboxComponent (%s): aucun HealthComponent assigné." % get_parent().name)
		return false

	var final_damage: float = amount * damage_multiplier
	# allow_lethal = true : contrairement aux dépenses volontaires du joueur
	# (Dash, Morph...), les dégâts de combat DOIVENT pouvoir tuer la cible.
	var applied: bool = health_component.consume_blood(final_damage, true)

	if applied:
		EventBus.entity_damaged.emit(self, final_damage, hit_position)

	return applied


## Appelé par WeaponBase._cone_attack() (ex: Moulinet 360° de la Faux) pour
## repousser cette cible. Ne fait qu'émettre le signal : le déplacement
## physique réel (RigidBody impulse, CharacterBody knockback...) reste à
## la charge de l'entité propriétaire, qui n'existe pas encore pour les
## ennemis en Phase 1 (DummyEnemy est un StaticBody3D immobile).
## TODO (Phase 3 - IA/Physique) : brancher ce signal sur un vrai déplacement.
func apply_knockback(direction: Vector3, force: float) -> void:
	knockback_requested.emit(direction, force)
