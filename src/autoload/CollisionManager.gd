# CollisionManager.gd — Autoload singleton managing hitbox pool
# Implements ADR-ARCH-002: Area2D Spawn-in/Spawn-out collision detection
# Layer/Mask configuration will be applied to project.godot separately
extends Node

## Hitbox pool autoload for the 2D brawler combat system.
## Manages spawn/despawn of Area2D hitboxes with a pre-allocated object pool.
## All collision events route through this manager.

# ─── Collision Layer Constants ──────────────────────────────────────────────────
## 6-layer collision strategy from ADR-ARCH-002
## These correspond to project.godot physics_layer_* properties (1-indexed)
const LAYER_WORLD: int = 1        ## Static world geometry (platforms, walls)
const LAYER_PLAYER: int = 2       ## Player CharacterBody2D
const LAYER_PLAYER_HITBOX: int = 3 ## Player attack hitbox (activated during attacks)
const LAYER_BOSS: int = 4         ## Boss CharacterBody2D
const LAYER_BOSS_HITBOX: int = 5   ## Boss attack hitbox (activated during attacks)
const LAYER_SENSOR: int = 6       ## AI sensors, RayCast2D detectors

# ─── Pool Configuration ─────────────────────────────────────────────────────────
const POOL_SIZE: int = 20           ## Pre-allocated Area2D count (ADR-ARCH-002)
const MAX_CONCURRENT_HITBOXES: int = 13  ## Hard limit from ADR-ARCH-002

# ─── Hitbox Size Formula Constants (collision-006) ──────────────────────────────
## Base hitbox size for all attacks
const HITBOX_BASE_SIZE: Vector2 = Vector2(64, 64)

## Attack type size multipliers per GDD F1-01 to F1-04
const ATTACK_TYPE_MULTIPLIER: Dictionary = {
	"LIGHT": 0.6,
	"MEDIUM": 1.0,
	"HEAVY": 1.5,
	"SPECIAL": 2.0
}

## Entity scale multipliers per GDD Section 3.1
const ENTITY_SCALE_MULTIPLIER: Dictionary = {
	"PLAYER": 1.0,
	"BOSS": 2.0
}

## Max concurrent hitbox calculation constants (collision-006)
const MAX_PLAYER_HITBOXES: int = 4
const MAX_BOSS_HITBOXES: int = 6
const GLOBAL_RESERVE: int = 2
const SAFE_MAX_CONCURRENT: int = 13

# ─── Hitbox State Machine ───────────────────────────────────────────────────────
## UNSPAWNED: Not yet activated (in pool)
## ACTIVE: Spawned and detecting collisions
## HIT_REGISTERED: Has registered a hit this activation
## DESTROYED: Despawning — still participates this frame, freed next physics step
enum HitboxState { UNSPAWNED = 0, ACTIVE = 1, HIT_REGISTERED = 2, DESTROYED = 3 }

# ─── Signals ───────────────────────────────────────────────────────────────────
## Emitted when a hitbox confirms a hit.
## Routes: CollisionManager → Events.attack_hit → ComboSystem, BossAI
signal attack_hit(attack_id: int, is_grounded: bool, hit_count: int)

## Emitted per collision detection (collision-003 AC-1)
## hit_confirmed fires when a hitbox overlaps a hurtbox
signal hit_confirmed(hitbox: Area2D, hurtbox: Area2D, attack_id: int)

## Boss AI perception signals (direct routing — low latency required)
signal player_detected(player: Node2D)
signal player_lost(player: Node2D)
signal player_hurt(player: Node2D, damage: float)

# ─── Private State ─────────────────────────────────────────────────────────────
var _pool: Array[Area2D] = []
var _active_hitboxes: Array[Area2D] = []

## Hitboxes marked DESTROYED — kept in scene this frame, freed next physics step
## Per collision-003 AC-4 and AC-5: DESTROYED frame N still detects, queue_free at N+1
var _pending_free: Array[Area2D] = []

# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_pool()

func _physics_process(_delta: float) -> void:
	## Process deferred queue_free for DESTROYED hitboxes
	## Per collision-003 AC-4/AC-5: DESTROYED hitbox stays in scene frame N,
	## queue_free executes at frame N+1
	for hitbox in _pending_free:
		if is_instance_valid(hitbox) and hitbox.get_parent() != null:
			hitbox.get_parent().remove_child(hitbox)
		_reset_hitbox_for_pool(hitbox)
		_pool.append(hitbox)
	_pending_free.clear()

func _init_pool() -> void:
	## Pre-allocate POOL_SIZE Area2D hitboxes
	for i in range(POOL_SIZE):
		var hitbox := _create_hitbox_instance()
		_pool.append(hitbox)

func _create_hitbox_instance() -> Area2D:
	## Factory method to create a single Area2D hitbox
	## Shape and monitoring are configured at spawn time
	var hitbox := Area2D.new()
	hitbox.set_script(load("res://src/collision/hitbox_resource.gd"))
	hitbox.state = HitboxState.UNSPAWNED
	hitbox.set_monitoring(false)
	hitbox.set_pickable(false)
	return hitbox

func _reset_hitbox_for_pool(hitbox: Area2D) -> void:
	## Reset a hitbox to UNSPAWNED state for return to pool
	## Delegates to the hitbox's own reset method
	var hitbox_res := hitbox as HitboxResource
	if hitbox_res and hitbox_res.has_method("reset_for_pool"):
		hitbox_res.reset_for_pool()
	else:
		## Fallback: manual reset
		hitbox.state = HitboxState.UNSPAWNED
		hitbox.set("hit_count", 0)
		hitbox.set("owner", null)
		hitbox.set("attack_id", -1)
		hitbox.set_monitoring(false)

# ─── Public API ────────────────────────────────────────────────────────────────
## Spawn a hitbox from the pool.
##
## config dictionary keys:
##   - owner: Node2D — the character (player or boss) spawning this hitbox
##   - attack_id: int — unique identifier for this attack instance
##   - layer: int — collision layer (use LAYER_PLAYER_HITBOX or LAYER_BOSS_HITBOX)
##   - size: Vector2 — collision shape extents
##   - offset: Vector2 — position offset from owner
##   - collision_mask: int — which layers this hitbox detects
##   - is_grounded: bool — whether attack is grounded (for combo system)
##
## Returns: Area2D the spawned hitbox, or null if pool exhausted or at max concurrent
func spawn_hitbox(config: Dictionary) -> Area2D:
	## Guard: enforce hard concurrent limit
	if _active_hitboxes.size() >= MAX_CONCURRENT_HITBOXES:
		push_warning("CollisionManager: max concurrent hitboxes (%d) reached" % MAX_CONCURRENT_HITBOXES)
		return null

	## Guard: pool exhausted
	if _pool.is_empty():
		push_warning("CollisionManager: hitbox pool exhausted")
		return null

	## Checkout hitbox from pool
	var hitbox: Area2D = _pool.pop_back()

	## Configure hitbox
	var owner_ref: Node2D = config.get("owner")
	var attack_id_val: int = config.get("attack_id", -1)
	var layer_val: int = config.get("layer", LAYER_PLAYER_HITBOX)
	var size_val: Vector2 = config.get("size", Vector2(64, 64))
	var offset_val: Vector2 = config.get("offset", Vector2.ZERO)
	var mask_val: int = config.get("collision_mask", 0)
	var is_grounded_val: bool = config.get("is_grounded", true)

	# Set collision layer (which layer this hitbox occupies)
	hitbox.set_collision_layer_value(layer_val, true)

	# Create collision shape
	var shape := RectangleShape2D.new()
	shape.set_size(size_val)
	var collision_shape := CollisionShape2D.new()
	collision_shape.set_shape(shape)
	collision_shape.set_position(offset_val)
	hitbox.add_child(collision_shape)

	# Configure hitbox resource script
	var script_instance = hitbox.get_script() as GDScript
	if script_instance:
		hitbox.set("owner", owner_ref)
		hitbox.set("attack_id", attack_id_val)
		hitbox.set("is_grounded", is_grounded_val)
		hitbox.set("state", HitboxState.ACTIVE)

	# Set collision mask (which layers this hitbox detects)
	hitbox.set_collision_mask(mask_val)

	# Connect area_entered for hit detection — bind hitbox so handler knows which hitbox triggered
	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered.bind(hitbox))

	# Add to active set
	_active_hitboxes.append(hitbox)

	# Add to scene tree under parent (defaults to root)
	var parent: Node = config.get("parent")
	if parent == null:
		parent = get_tree().root
	parent.add_child(hitbox)

	# Set world position if owner has a global position
	if is_instance_valid(owner_ref):
		hitbox.global_position = owner_ref.global_position + offset_val

	return hitbox

## Despawn a hitbox, marking it DESTROYED.
## The hitbox remains in the scene and active this frame (for final collision detection),
## then is queue_free'd on the next physics step.
func despawn_hitbox(hitbox: Area2D) -> void:
	if not is_instance_valid(hitbox):
		return

	if not _active_hitboxes.has(hitbox):
		push_warning("CollisionManager: despawn called on non-active hitbox")
		return

	## Set state to DESTROYED — hitbox stays in scene this frame (collision-003 AC-4)
	hitbox.set("state", HitboxState.DESTROYED)
	## monitoring stays true this frame so final collisions register

	## Remove from active list
	var idx := _active_hitboxes.find(hitbox)
	if idx >= 0:
		_active_hitboxes.remove_at(idx)

	## Defer scene removal to _physics_process (collision-003 AC-5)
	_pending_free.append(hitbox)

## Cleanup all hitboxes for a specific owner and attack_id.
## Called when an attack is interrupted or cancelled.
func cleanup_by_owner(owner: Node2D, attack_id: int) -> void:
	var to_despawn: Array[Area2D] = []
	for hitbox in _active_hitboxes:
		if hitbox.get("owner") == owner and hitbox.get("attack_id") == attack_id:
			to_despawn.append(hitbox)
	for hitbox in to_despawn:
		despawn_hitbox(hitbox)

## Get count of currently active hitboxes
func get_active_count() -> int:
	return _active_hitboxes.size()

## Get maximum allowed concurrent hitboxes
func get_max_concurrent() -> int:
	return MAX_CONCURRENT_HITBOXES

# ─── Collision Handling ────────────────────────────────────────────────────────
func _on_hitbox_area_entered(hitbox: Area2D, area: Area2D) -> void:
	## Route hit events: hitbox → CollisionManager → Events.attack_hit
	## `hitbox` is passed via bind() so we read properties from the correct object
	var attack_id_val: int = hitbox.get("attack_id") as int if hitbox.get("attack_id") != null else -1
	var is_grounded_val: bool = hitbox.get("is_grounded") as bool if hitbox.get("is_grounded") != null else true

	## Emit hit_confirmed per collision-003 AC-1
	hit_confirmed.emit(hitbox, area, attack_id_val)

	## Track hit count per attack for combo system
	var hit_count := _count_hits_for_attack(attack_id_val)
	hit_count += 1
	hitbox.set("hit_count", hit_count)

	## Route through Events autoload (Events.attack_hit → ComboSystem, BossAI)
	Events.attack_hit.emit(attack_id_val, is_grounded_val, hit_count)

	## Also emit local signal for systems directly connected to CollisionManager
	attack_hit.emit(attack_id_val, is_grounded_val, hit_count)

func _count_hits_for_attack(attack_id: int) -> int:
	## Count hits registered by this attack_id across all active hitboxes
	var count := 0
	for hitbox in _active_hitboxes:
		if hitbox.get("attack_id") == attack_id:
			count += hitbox.get("hit_count") as int if hitbox.get("hit_count") != null else 0
	return count

# ─── Boss AI Perception ───────────────────────────────────────────────────────
## Player detection — called when boss sensor detects a player
func notify_player_detected(player: Node2D) -> void:
	player_detected.emit(player)

## Player lost — called when boss sensor loses a player
func notify_player_lost(player: Node2D) -> void:
	player_lost.emit(player)

## Player hurt — called when a player's hurtbox takes damage
func notify_player_hurt(player: Node2D, damage: float) -> void:
	player_hurt.emit(player)


# ─── Hitbox Formulas (collision-006) ────────────────────────────────────────────

## Calculate hitbox size using the hitbox formula.
## Formula: hitbox_size = base_size * attack_type_multiplier * entity_scale_multiplier
##
## Parameters:
##   - base_size: Vector2 — base collision size (default 64x64)
##   - attack_type: String — LIGHT/MEDIUM/HEAVY/SPECIAL
##   - entity_type: String — PLAYER/BOSS
##
## Returns: Vector2 calculated hitbox size
##
## Examples per GDD:
##   F1-01: 64*64 * LIGHT(0.6) * PLAYER(1.0) = (38.4, 38.4)
##   F1-02: 64*64 * HEAVY(1.5) * BOSS(2.0) = (192, 192)
func calculate_hitbox_size(base_size: Vector2, attack_type: String, entity_type: String) -> Vector2:
	var at_mult: float = ATTACK_TYPE_MULTIPLIER.get(attack_type, 1.0)
	var es_mult: float = ENTITY_SCALE_MULTIPLIER.get(entity_type, 1.0)
	return base_size * at_mult * es_mult


## Calculate maximum concurrent hitboxes for given player and boss counts.
## Formula: max = player_count * MAX_PLAYER_HITBOXES + boss_count * MAX_BOSS_HITBOXES + GLOBAL_RESERVE
##
## Parameters:
##   - player_count: int — number of players (1 or 2)
##   - boss_count: int — number of bosses (typically 1)
##
## Returns: int maximum concurrent hitboxes allowed
##
## Examples per GDD:
##   F4-01: 1*4 + 1*6 + 2 = 12
##   F4-02: 2*4 + 1*6 + 2 = 16 (exceeds SAFE_MAX_CONCURRENT=13, triggers warning)
func calculate_max_hitboxes(player_count: int, boss_count: int) -> int:
	return player_count * MAX_PLAYER_HITBOXES + boss_count * MAX_BOSS_HITBOXES + GLOBAL_RESERVE


## Check if spawning a new hitbox is allowed given current active count.
## Returns true if spawn is allowed, false if at or over limit.
func check_spawn_allowed() -> bool:
	return _active_hitboxes.size() < SAFE_MAX_CONCURRENT


# ─── AI Perception System (collision-005) ────────────────────────────────────────────

## Base detection radius (pixels)
const BASE_DETECTION_RADIUS: float = 256.0

## Alertness multipliers per boss state
## IDLE=0.75 (passive), PATROL=1.0, ALERTED=1.5, CHASING=2.0
const ALERTNESS_MULTIPLIER: Dictionary = {
	"IDLE": 0.75,
	"PATROL": 1.0,
	"ALERTED": 1.5,
	"CHASING": 2.0
}

## Hysteresis thresholds for detection state machine
## Inner threshold (0.8R): certain detection
## Outer threshold (1.2R): certain lost
const INNER_THRESHOLD: float = 0.8
const OUTER_THRESHOLD: float = 1.2

## Debounce time for boundary region (seconds)
const DETECTION_DEBOUNCE_TIME: float = 0.2

## Player proximity tracking: player_id -> {state: LOST/DETECTED, debounce_timer: float}
var _proximity_state: Dictionary = {}


## Calculate effective detection radius based on boss state and LOS.
## Formula: detection_radius = base_radius * alertness_multiplier * los_modifier
##
## Parameters:
##   - boss_state: String — IDLE/PATROL/ALERTED/CHASING
##   - los_modifier: float — 1.0 for clear LOS, 0.5 for occluded
##
## Returns: float effective detection radius in pixels
func calculate_detection_radius(boss_state: String, los_modifier: float = 1.0) -> float:
	var alert_mult: float = ALERTNESS_MULTIPLIER.get(boss_state, 1.0)
	return BASE_DETECTION_RADIUS * alert_mult * los_modifier


## Get inner radius for immediate detection threshold.
## Below this radius = immediately DETECTED (no debounce).
func get_inner_radius(boss_state: String, los_modifier: float = 1.0) -> float:
	return calculate_detection_radius(boss_state, los_modifier) * INNER_THRESHOLD


## Get outer radius for certain lost threshold.
## Beyond this radius = certain LOST after debounce.
func get_outer_radius(boss_state: String, los_modifier: float = 1.0) -> float:
	return calculate_detection_radius(boss_state, los_modifier) * OUTER_THRESHOLD


## Update proximity detection for a player relative to a boss.
## Call this each frame from boss AI _process().
## Returns: String — "DETECTED" or "LOST"
##
## Parameters:
##   - player: Node2D — the player to check
##   - boss_position: Vector2 — current boss position
##   - boss_state: String — current boss AI state (IDLE/PATROL/ALERTED/CHASING)
##   - los_modifier: float — 1.0 for clear, 0.5 for occluded
##   - delta: float — time since last call (for debounce timer)
func update_proximity_detection(player: Node2D, boss_position: Vector2, boss_state: String, los_modifier: float = 1.0, delta: float = 0.0) -> String:
	var player_id: int = player.get_instance_id()
	var dist: float = player.global_position.distance_to(boss_position)
	var detection_radius: float = calculate_detection_radius(boss_state, los_modifier)
	var inner_radius: float = detection_radius * INNER_THRESHOLD
	var outer_radius: float = detection_radius * OUTER_THRESHOLD

	# Get or create state for this player
	if not _proximity_state.has(player_id):
		_proximity_state[player_id] = {"state": "LOST", "debounce_timer": 0.0}

	var state_data: Dictionary = _proximity_state[player_id]
	var current_state: String = state_data["state"]
	var debounce_timer: float = state_data["debounce_timer"]

	match current_state:
		"LOST":
			if dist < inner_radius:
				# Enter inner radius → immediately DETECTED
				_proximity_state[player_id] = {"state": "DETECTED", "debounce_timer": 0.0}
				player_detected.emit(player)
				return "DETECTED"
			# In boundary region — start debounce but stay LOST
			elif dist < outer_radius:
				debounce_timer += delta
		"DETECTED":
			if dist > outer_radius:
				# Outside outer radius → start LOST debounce
				debounce_timer += delta
				if debounce_timer >= DETECTION_DEBOUNCE_TIME:
					_proximity_state[player_id] = {"state": "LOST", "debounce_timer": 0.0}
					player_lost.emit(player)
					return "LOST"
			else:
				# Within outer radius — reset debounce, stay DETECTED
				debounce_timer = 0.0

	# Update state with current debounce timer
	_proximity_state[player_id] = {"state": current_state, "debounce_timer": debounce_timer}
	return current_state


## Clear proximity state for a player (e.g., when player dies).
func clear_proximity_state(player: Node2D) -> void:
	var player_id: int = player.get_instance_id()
	_proximity_state.erase(player_id)


## Get current proximity state for a player.
## Returns: String — "DETECTED", "LOST", or "UNKNOWN" if not tracked.
func get_proximity_state(player: Node2D) -> String:
	var player_id: int = player.get_instance_id()
	if _proximity_state.has(player_id):
		return _proximity_state[player_id]["state"]
	return "UNKNOWN"
