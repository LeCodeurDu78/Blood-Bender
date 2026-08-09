extends Area3D
class_name BloodProjectile

## ============================================================
## BloodProjectile.gd
## ------------------------------------------------------------
## Projectile sanguin lourd tiré via Player._fire_blood_projectile()
## (touche R / clic molette). Vole en ligne droite à vitesse
## constante, inflige de gros dégâts à la première HurtboxComponent
## touchée, et se détruit à l'impact (mur, décor ou cible) — ou après
## `lifetime` secondes si rien n'est touché.
##
## Le coût en Sang (10-25 PV, selon la charge) et les dégâts infligés
## sont décidés et prélevés par Player.gd AVANT l'instanciation :
## ce script ne gère que la physique/collision du projectile en vol.
## ============================================================

## Durée de vie max avant auto-destruction si rien n'est touché.
@export var lifetime: float = 4.0

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0.0
var _has_hit: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)


## Appelé par Player.gd juste après l'instanciation, avant tout ajout
## à l'arbre de scène n'est requis mais fonctionne aussi après.
func launch(direction: Vector3, speed: float, damage: float) -> void:
	var dir: Vector3 = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	_velocity = dir * speed
	_damage = damage

	var look_target: Vector3 = global_transform.origin + dir
	if not look_target.is_equal_approx(global_transform.origin):
		look_at(look_target, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	global_transform.origin += _velocity * delta


func _on_body_entered(_body: Node3D) -> void:
	# Corps solide (mur, décor Layer 1) : le projectile s'arrête net.
	_resolve_impact()


func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		(area as HurtboxComponent).take_damage(_damage, global_transform.origin)
	_resolve_impact()


func _resolve_impact() -> void:
	if _has_hit:
		return
	_has_hit = true
	# TODO (Phase 3 - VFX) : éclaboussure de sang + son d'impact lourd.
	queue_free()


func _on_lifetime_expired() -> void:
	if not _has_hit:
		queue_free()
