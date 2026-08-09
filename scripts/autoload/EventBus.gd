extends Node

# --- Santé / Sang (relayé par HealthComponent) ---
signal health_changed(current: float, max: float)
signal consume_blood(blood_cost: float, allow_lethal: bool, response: Dictionary)
signal player_died

# --- Armes (relayé par WeaponManager / WeaponBase) ---
signal weapon_changed(weapon: WeaponBase)
signal ammo_changed(current_ammo: int, max_ammo: int, blood_mode: bool, blood_cost: float)
signal shot_fired(weapon_name: String)
signal shot_failed(weapon_name: String)
signal morph_failed(weapon_name: String, required_blood: float)

# --- Tir secondaire "Extraction" (Phase 1, relayé par WeaponBase) ---
signal extraction_fired(weapon_name: String)
signal extraction_failed(weapon_name: String)

# --- Projectile Sanguin Direct (Phase 1, relayé par Player.gd) ---
signal projectile_charge_started
signal projectile_charging(ratio: float)
signal projectile_fired(blood_cost: float, damage: float)
signal projectile_failed(required_blood: float)

# --- Combat (relayé par HurtboxComponent / DummyEnemy) ---
signal entity_damaged(hurtbox: HurtboxComponent, amount: float, hit_position: Vector3)
signal entity_died(entity: Node)
