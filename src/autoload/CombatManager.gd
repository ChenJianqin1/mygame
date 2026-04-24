# CombatManager.gd — Autoload for combat system
# Implements damage calculation per ADR-ARCH-003
# TR-ID: TR-combat-002

class_name CombatManager
extends Node

## Description
Autoload singleton managing combat damage calculations and related signals.
Handles attack type multipliers, combo multipliers, and damage formulas.

# ===== TUNING KNOBS =====

## Base damage value (default when not specified)
const BASE_DAMAGE: int = 15

## Attack type damage multipliers
## LIGHT=0.8, MEDIUM=1.0, HEAVY=1.5, SPECIAL=2.0
const ATTACK_TYPE_MULTIPLIER: Dictionary = {
	"LIGHT": 0.8,
	"MEDIUM": 1.0,
	"HEAVY": 1.5,
	"SPECIAL": 2.0
}

## Combo damage increment per hit (0.05 per ADR-ARCH-003)
const COMBO_DAMAGE_INCREMENT: float = 0.05

## Maximum combo multiplier (solo cap per ADR-ARCH-003)
const MAX_COMBO_MULTIPLIER: float = 3.0

## Maximum combo multiplier for sync attacks (higher cap per combo-002)
const SYNC_MAX_COMBO_MULTIPLIER: float = 4.0

## Base knockback force per attack type (pixels, per ADR-ARCH-003)
const BASE_KNOCKBACK: Dictionary = {
	"LIGHT": 50.0,
	"MEDIUM": 100.0,
	"HEAVY": 200.0,
	"SPECIAL": 300.0
}

## Base hitstop frames per attack type (combat-003)
const BASE_HITSTOP: Dictionary = {
	"LIGHT": 3,
	"MEDIUM": 5,
	"HEAVY": 8,
	"SPECIAL": 12
}

## Bonus hitstop frames per target type (combat-003)
const BONUS_HITSTOP: Dictionary = {
	"PLAYER": 0,
	"BOSS": 2,
	"ELITE": 1
}

## Frame window for co-op hitstop stacking (combat-003)
const HITSTOP_STACK_WINDOW: int = 3

## Maximum defense rating (80% damage reduction cap, combat-004)
const MAX_DEFENSE_RATING: float = 0.8

## Dodge duration in frames (combat-005)
const DODGE_DURATION: int = 12

## Dodge cooldown in frames (combat-005)
const DODGE_COOLDOWN: int = 24

## Base boss HP (combat-006)
const BASE_BOSS_HP: int = 500

## Boss index HP multipliers (combat-006): boss 1=1.0, boss 2=1.3, boss 3=1.6, boss 4=2.0
const BOSS_INDEX_MULTIPLIER: Array = [1.0, 1.0, 1.3, 1.6, 2.0]

## Co-op HP scaling multiplier (combat-006)
const COOP_HP_SCALING: float = 1.5

## ===== SIGNALS =====

## Emitted when a hit lands during combo
## attack_type: String (LIGHT/MEDIUM/HEAVY/SPECIAL)
## combo_count: int current combo count after this hit
## is_grounded: bool whether the attacker is grounded
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)

## Emitted when damage is dealt to a target
## damage: int final calculated damage
## target_id: int unique identifier of the target
## is_critical: bool whether this was a critical hit
signal damage_dealt(damage: int, target_id: int, is_critical: bool)

## Emitted when hitstop starts (frame freeze begins)
## frames: int — number of hitstop frames
signal hitstop_started(frames: int)

## Emitted when hitstop ends (frame freeze completes)
signal hitstop_ended()

## Emitted when a defense successfully blocks damage
## blocker_id: int — player who blocked
## damage_reduced: int — amount of damage reduced
signal defense_successful(blocker_id: int, damage_reduced: int)

## Emitted when a player starts dodging (invincibility begins)
signal dodge_started(player_id: int)

## Emitted when a player's dodge invincibility ends
signal dodge_ended(player_id: int)

## Emitted when invincibility starts (dodge or other source)
signal invincibility_started(player_id: int)

## Emitted when invincibility ends
signal invincibility_ended(player_id: int)

# ─── Per-Player Dodge State ──────────────────────────────────────────────────────
var _dodge_timers: Dictionary = {1: 0, 2: 0}   ## Remaining invincibility frames per player
var _dodge_cooldowns: Dictionary = {1: 0, 2: 0}  ## Remaining cooldown frames per player

## ===== PUBLIC METHODS =====

## Calculate final damage using the damage formula
## Formula: final_damage = base_damage * attack_type_multiplier * combo_multiplier
## combo_multiplier = min(1.0 + combo_count * COMBO_DAMAGE_INCREMENT, MAX_COMBO_MULTIPLIER)
##
## Parameters:
## - base: int base damage value (e.g., 15)
## - attack_type: String attack type key (LIGHT/MEDIUM/HEAVY/SPECIAL)
## - combo_count: int current combo hit count
##
## Returns: int final calculated damage, clamped to valid range
func calculate_damage(base: int, attack_type: String, combo_count: int) -> int:
	var type_mult: float = ATTACK_TYPE_MULTIPLIER.get(attack_type, 1.0)
	var combo_mult: float = get_combo_multiplier(combo_count)
	var final_damage: float = base * type_mult * combo_mult
	return int(round(final_damage))


## Calculate combo multiplier from combo count
## Solo: min(1.0 + combo_count * 0.05, 3.0)
## Sync:  min(1.0 + combo_count * 0.05, 4.0)
##
## Parameters:
## - combo_count: int current combo count
## - is_sync: bool whether this is a sync attack (higher cap)
##
## Returns: float combo multiplier, clamped to appropriate cap
func get_combo_multiplier(combo_count: int, is_sync: bool = false) -> float:
	var multiplier: float = 1.0 + (combo_count * COMBO_DAMAGE_INCREMENT)
	var cap: float = SYNC_MAX_COMBO_MULTIPLIER if is_sync else MAX_COMBO_MULTIPLIER
	return minf(multiplier, cap)


## Calculate knockback vector for a target hit by an attack
## knockback_force = base_knockback[attack_type] × normalize(target_position - attacker_position)
## Direction is always **away from attacker**.
##
## Parameters:
## - target: Node2D — the target being knocked back
## - attacker_position: Vector2 — position of the attacker
## - attack_type: String — attack type key (LIGHT/MEDIUM/HEAVY/SPECIAL)
##
## Returns: Vector2 knockback force vector (caller applies to target's velocity)
func apply_knockback(target: Node2D, attacker_position: Vector2, attack_type: String) -> Vector2:
	var base_force: float = BASE_KNOCKBACK.get(attack_type, 50.0)
	var direction: Vector2
	if is_instance_valid(target):
		direction = (target.global_position - attacker_position).normalized()
	else:
		# Fallback: attacker and target at same position
		direction = Vector2(1, 0)
	var knockback_vector := direction * base_force
	return knockback_vector


## Calculate hitstop frames for a given attack against a target type.
## Formula: hitstop_frames = base_hitstop[attack_type] + bonus_hitstop[target_type]
##
## Parameters:
## - attack_type: String — LIGHT/MEDIUM/HEAVY/SPECIAL
## - target_type: String — PLAYER/BOSS/ELITE
##
## Returns: int total hitstop frames
func calculate_hitstop(attack_type: String, target_type: String) -> int:
	var base: int = BASE_HITSTOP.get(attack_type, 0)
	var bonus: int = BONUS_HITSTOP.get(target_type, 0)
	return base + bonus


## Calculate incoming damage after defense reduction.
## Formula: incoming = max(1, floor(final_damage × (1.0 - defense_rating)))
## Minimum return is always 1 (even if 80% reduction would floor to 0).
## Zero damage passes through unchanged.
##
## Parameters:
## - final_damage: int — damage before defense
## - defense_rating: float — 0.0 (no defense) to 0.8 (max defense)
##
## Returns: int damage after defense reduction (minimum 1)
func calculate_incoming_damage(final_damage: int, defense_rating: float) -> int:
	if final_damage == 0:
		return 0
	var reduced := final_damage * (1.0 - minf(defense_rating, MAX_DEFENSE_RATING))
	var result := int(floor(reduced))
	# Minimum 1 point of damage always gets through (per AC-DEF-003 / AC-EDGE-001)
	return maxi(result, 1)


## Start a dodge for a player — grants invincibility for DODGE_DURATION frames.
## Returns true if dodge was started, false if on cooldown.
func start_dodge(player_id: int) -> bool:
	if _dodge_cooldowns.get(player_id, 0) > 0:
		return false  # On cooldown
	_dodge_timers[player_id] = DODGE_DURATION
	dodge_started.emit(player_id)
	invincibility_started.emit(player_id)
	return true


## End dodge invincibility early and start cooldown.
func end_dodge(player_id: int) -> void:
	if _dodge_timers.get(player_id, 0) > 0:
		_dodge_timers[player_id] = 0
		_dodge_cooldowns[player_id] = DODGE_COOLDOWN
		invincibility_ended.emit(player_id)
		dodge_ended.emit(player_id)


## Advance dodge timers by delta frames.
## Call each physics frame for each player.
func update_dodge(player_id: int, delta_frames: int) -> void:
	# Process invincibility timer
	if _dodge_timers.get(player_id, 0) > 0:
		_dodge_timers[player_id] -= delta_frames
		if _dodge_timers[player_id] <= 0:
			_dodge_timers[player_id] = 0
			invincibility_ended.emit(player_id)
			dodge_ended.emit(player_id)

	# Process cooldown timer
	if _dodge_cooldowns.get(player_id, 0) > 0:
		_dodge_cooldowns[player_id] -= delta_frames
		if _dodge_cooldowns[player_id] <= 0:
			_dodge_cooldowns[player_id] = 0


## Returns true if the player is currently invincible (dodge active).
func is_invincible(player_id: int) -> bool:
	return _dodge_timers.get(player_id, 0) > 0


## Returns true if the player can currently dodge (cooldown expired).
func can_dodge(player_id: int) -> bool:
	return _dodge_cooldowns.get(player_id, 0) == 0


## Apply damage to a player, checking invincibility first.
## Returns actual damage taken (0 if invincible).
func apply_damage_to_player(player_id: int, damage: int) -> int:
	if is_invincible(player_id):
		return 0
	return damage


## Called by CollisionManager when a hit is confirmed.
## Emits Events.combo_hit so downstream systems (ComboManager, BossAI) can react.
func on_hit_landed(attack_type: String, combo_count: int, is_grounded: bool) -> void:
	# Emit local signal (for any direct listeners)
	combo_hit.emit(attack_type, combo_count, is_grounded)
	# Emit global Events signal (for Events-based routing)
	Events.combo_hit.emit(attack_type, combo_count, is_grounded)


## Calculate boss HP with scaling factors.
## Formula: floor(BASE_BOSS_HP × progression_multiplier × boss_index_multiplier × coop_scaling)
##
## Parameters:
## - boss_index: int — boss number (1-4)
## - is_coop: bool — whether co-op scaling applies
## - progression: float — progression multiplier (1.0-2.5), defaults to 1.0
##
## Returns: int final boss max HP
func calculate_boss_hp(boss_index: int, is_coop: bool, progression: float = 1.0) -> int:
	var index_mult: float = BOSS_INDEX_MULTIPLIER[boss_index] if boss_index < BOSS_INDEX_MULTIPLIER.size() else 1.0
	var coop_mult: float = COOP_HP_SCALING if is_coop else 1.0
	var result: float = BASE_BOSS_HP * progression * index_mult * coop_mult
	return int(floor(result))
