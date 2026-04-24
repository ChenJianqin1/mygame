class_name TierLogic
extends RefCounted
## Pure functions for combo tier calculations and sync detection.
## [br]
## Tier thresholds per the 5-tier combo system:
##   Tier 0 = IDLE (combo_count = 0)
##   Tier 1 = NORMAL (combo_count 1–9)
##   Tier 2 = RISING (combo_count 10–19)
##   Tier 3 = INTENSE (combo_count 20–39)
##   Tier 4 = OVERDRIVE (combo_count 40+)
## [br]
## Sync detection: 5-frame window, 3-hit chain for burst.

const TIER_THRESHOLDS := {
	0: 0,    # IDLE
	1: 1,    # NORMAL (1–9)
	2: 10,   # RISING (10–19)
	3: 20,   # INTENSE (20–39)
	4: 40    # OVERDRIVE (40+)
}

## Max frames apart for two hits to be considered synchronized (combo-003)
const SYNC_WINDOW_FRAMES: int = 5

## Consecutive SYNC hits required to trigger Sync Burst (combo-003)
const SYNC_CHAIN_THRESHOLD: int = 3

## Returns the combo tier for a given hit count.
## [br]
## Tier 0 = IDLE (combo_count = 0)
## Tier 1 = NORMAL (combo_count 1–9)
## Tier 2 = RISING (combo_count 10–19)
## Tier 3 = INTENSE (combo_count 20–39)
## Tier 4 = OVERDRIVE (combo_count 40+)
static func calculate_tier(combo_count: int) -> int:
	if combo_count == 0:
		return 0  # IDLE
	if combo_count < 10:
		return 1  # NORMAL
	if combo_count < 20:
		return 2  # RISING
	if combo_count < 40:
		return 3  # INTENSE
	return 4      # OVERDRIVE


## Returns true if two hits are within the sync window (within SYNC_WINDOW_FRAMES).
## Per combo-003 AC-09 and AC-10:
##   AC-09: abs(N - (N+3)) = 3 <= 5 → TRUE
##   AC-10: abs(N - (N+7)) = 7 > 5 → FALSE
static func is_sync_hit(p1_frame: int, p2_frame: int) -> bool:
	if p1_frame < 0 or p2_frame < 0:
		return false
	return absi(p1_frame - p2_frame) <= SYNC_WINDOW_FRAMES


## Returns true if the sync chain has reached the threshold to trigger Sync Burst.
## Per combo-003 AC-11:
##   chain >= 3 → TRUE
static func should_trigger_sync_burst(sync_chain_length: int) -> bool:
	return sync_chain_length >= SYNC_CHAIN_THRESHOLD
