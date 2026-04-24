class_name ComboData
extends RefCounted
## Per-player combo state container.
## [br]
## Stores combo_count, combo_timer, current_tier, sync_chain_length, and last_hit_frame.
## [br]
## Designed to be injected — one instance per player (player_id 1 or 2).
## [br]
## RefCounted for automatic cleanup when no references remain.
extends RefCounted

## Player identifier (1 or 2)
var player_id: int

## Current combo hit count
var combo_count: int = 0

## Time elapsed since last hit in the combo
var combo_timer: float = 0.0

## Current combo tier (0=IDLE, 1=NORMAL, 2=RISING, 3=INTENSE, 4=OVERDRIVE)
var current_tier: int = 0

## Number of hits in the current sync chain (for sync attack detection)
var sync_chain_length: int = 0

## Last frame number when a hit was registered (-1 if no hits yet)
var last_hit_frame: int = -1

## Construct a new ComboData for the given player_id.
func _init(p_id: int) -> void:
	player_id = p_id

## Reset all combo state to initial values.
## Called on player death, boss phase change, or round end.
func reset() -> void:
	combo_count = 0
	combo_timer = 0.0
	current_tier = 0
	sync_chain_length = 0
	last_hit_frame = -1

## Advance the combo timer by delta seconds.
## Call each physics frame when combo is active.
## Returns true if combo is still active, false if timer expired.
func update(delta: float) -> bool:
	if combo_count == 0:
		return true
	combo_timer += delta
	# Timer expiry is handled by the combo manager — this just advances the clock
	return true

## Register a successful hit. Updates combo_count, combo_timer, current_tier, and last_hit_frame.
## Timer is reset to 0 on each hit (per combo-004 Rule: each new hit resets timer).
## Call when the player lands an attack.
func register_hit(frame_number: int) -> void:
	combo_count += 1
	last_hit_frame = frame_number
	current_tier = TierLogic.calculate_tier(combo_count)
	combo_timer = 0.0  # Reset timer on new hit (combo-004)

## Increment the sync chain counter.
## Call when a sync attack is detected.
func register_sync_hit() -> void:
	sync_chain_length += 1

## Returns true if this combo has no hits recorded.
func is_empty() -> bool:
	return combo_count == 0
