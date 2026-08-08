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
