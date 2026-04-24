# hitbox_resource.gd — Custom Area2D script for combat hitboxes
# Implements ADR-ARCH-002: Hitbox/Hurtbox Spawn-in/Spawn-out pattern
# Attach to Area2D nodes spawned by CollisionManager
class_name HitboxResource
extends Area2D

## Hitbox state machine states from ADR-ARCH-002:
## UNSPAWNED → [attack frame] → ACTIVE → [hit] → HIT_REGISTERED → [attack end] → DESTROYED
enum HitboxState { UNSPAWNED = 0, ACTIVE = 1, HIT_REGISTERED = 2, DESTROYED = 3 }

# ─── Exported Properties ───────────────────────────────────────────────────────
## The character (Player or Boss) that owns this hitbox
@export var owner: Node2D = null

## Unique identifier for this attack instance (int, matches Events.attack_hit)
@export var attack_id: int = -1

## Whether this attack is a grounded attack (vs aerial)
@export var is_grounded: bool = true

## Collision layer this hitbox occupies
@export var hitbox_layer: int = 3  ## Default: LAYER_PLAYER_HITBOX

## Collision mask — which layers this hitbox detects
@export var detection_mask: int = 0

# ─── Runtime State ─────────────────────────────────────────────────────────────
## Current hitbox state in the state machine
var state: HitboxState = HitboxState.UNSPAWNED

## Number of hits registered this activation
var hit_count: int = 0

## Set to true once this hitbox has registered a hit (prevents double-hit per attack)
var _has_hit: bool = false

## Tracks hurtboxes already hit by this hitbox — prevents double-hit per pair
## Hitbox-level mutual exclusion per collision-003 AC-2
var _hit_hurtboxes: Array[Area2D] = []

# ─── State Machine ─────────────────────────────────────────────────────────────
## Transition to ACTIVE state when spawned by CollisionManager
func activate() -> void:
	state = HitboxState.ACTIVE
	_has_hit = false
	hit_count = 0
	set_monitoring(true)
	set_pickable(true)

## Called when this hitbox lands a hit on a hurtbox
func register_hit() -> void:
	if state != HitboxState.ACTIVE:
		return
	if _has_hit:
		return  ## Prevent double-hit per activation

	_has_hit = true
	state = HitboxState.HIT_REGISTERED
	hit_count += 1

## Transition to DESTROYED state — still detects collision this frame
func mark_destroyed() -> void:
	state = HitboxState.DESTROYED
	## Monitoring remains true this frame for final collision detection
	## Disable next frame (handled by CollisionManager.despawn_hitbox)

## Check if this hitbox can still register hits
func can_register_hit() -> bool:
	return state == HitboxState.ACTIVE and not _has_hit

## Reset hitbox state for return to pool
## Called by CollisionManager.despawn_hitbox()
func reset_for_pool() -> void:
	state = HitboxState.UNSPAWNED
	hit_count = 0
	_has_hit = false
	_hit_hurtboxes.clear()
	owner = null
	attack_id = -1
	is_grounded = true
	# Remove and free all children (collision shapes) — iterate over a snapshot
	# to avoid issues with modifying the children array during iteration
	var children := get_children()
	for child in children:
		remove_child(child)
		child.free()
	set_collision_layer(0)
	set_collision_mask(0)

# ─── Collision Handling ────────────────────────────────────────────────────────
func _ready() -> void:
	## Ensure monitoring is off until explicitly activated
	set_monitoring(false)
	set_pickable(false)
	## Connect area_entered for hit detection
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	## Verify this is a valid hit
	if not can_register_hit():
		return

	## Hitbox-level mutual exclusion: don't count same hurtbox twice per activation
	## Per collision-003 AC-2 and AC-3
	if area in _hit_hurtboxes:
		return
	_hit_hurtboxes.append(area)

	## Register the hit
	register_hit()

	## Emit hit signal for CollisionManager to route
	## The actual signal routing happens in CollisionManager._on_hitbox_area_entered

# ─── Debug ─────────────────────────────────────────────────────────────────────
func _to_string() -> String:
	return "Hitbox[id=%d state=%s owner=%s]" % [attack_id, HitboxState.keys()[state], owner]
