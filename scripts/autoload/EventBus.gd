extends Node

# --- Health ---
signal health_changed(current: float, max: float)
signal consume_blood(blood_cost: float, allow_lethal: bool, response: Dictionary)
signal player_died

# --- Weapons ---
signal weapon_changed(weapon: WeaponBase)
signal ammo_changed(current_ammo: int, max_ammo: int, blood_mode: bool, blood_cost: float)
signal shot_fired(weapon_name: String)
signal shot_failed(weapon_name: String)
signal morph_failed(weapon_name: String, required_blood: float)

# --- Extraction ---
signal extraction_fired(weapon_name: String)
signal extraction_failed(weapon_name: String)

# --- Projectile ---
signal projectile_charge_started
signal projectile_charging(ratio: float)
signal projectile_fired(blood_cost: float, damage: float)
signal projectile_failed(required_blood: float)

# --- Combat ---
signal entity_damaged(hurtbox: HurtboxComponent, amount: float, hit_position: Vector3)
signal entity_died(entity: Node)

# --- Shield ---
signal parry_started
signal parry_success(attacker: Node)
signal parry_failed
signal survival_parry_triggered(healed_amount: float)
signal block_started
signal block_ended

# --- Grapple ---
signal grapple_fired(target_type: String)
signal grapple_failed(required_blood: float)
signal grapple_hit(target_type: String, target: Node)
signal grapple_finished

# --- Trauma ---
signal enemy_trauma_changed(enemy: Node, ratio: float)
signal enemy_staggered(enemy: Node)     ## Entrée en Cristallisation Rouge (100% Trauma).
signal enemy_stagger_ended(enemy: Node)

# --- Glory Kills ---
signal glory_kill_available(enemy: Node)   ## Un ennemi staggeré est à portée d'exécution.
signal glory_kill_unavailable
signal quick_extraction_performed(enemy: Node, healed_amount: float)
signal full_glory_kill_started(enemy: Node)
signal full_glory_kill_finished(enemy: Node)
