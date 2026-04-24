# Story 003: Rescue Execution + I-frames + OUT State

> **Epic**: coop
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/coop-system.md`
**Requirement**: `TR-coop-003`, `TR-coop-004`, `TR-coop-013` — rescue execution, i-frames, OUT state, life respawn

**ADR Governing Implementation**: ADR-ARCH-005: Coop System HP Pools & Rescue
**ADR Decision Summary**:
```
RESCUED_IFRAMES_DURATION = 1.5 seconds
Rescue instantly revives with invincibility
OUT state persists until next life
Player returns to ACTIVE on next life
```

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-03, AC-04, AC-09, AC-13:

- [ ] **AC-03**: P1 DOWNTIME, P2 approaches within 175px → P2 presses rescue → P1 instantly revives with 1.5s i-frames
- [ ] **AC-04**: P1 DOWNTIME, timer reaches 0 → without rescue → P1 is OUT
- [ ] **AC-09**: P1 is DOWNTIME, rescue in progress → Boss attacks P1 → P1 takes damage (vulnerable)
- [ ] **AC-13**: Player OUT → next life begins → player returns to ACTIVE state

---

## Implementation Notes

### 1. RESCUED State I-frames

```gdscript
## Check if player has invincibility frames (RESCUED state)
func has_iframes(player_id: int) -> bool:
    var idx = player_id - 1
    if _player_state[idx] == CoopState.RESCUED:
        return Time.get_ticks_msec() / 1000.0 < _rescued_iframe_end_time[idx]
    return false

## Get remaining i-frame time
func get_iframe_remaining(player_id: int) -> float:
    var idx = player_id - 1
    if _player_state[idx] != CoopState.RESCUED:
        return 0.0
    var current_time = Time.get_ticks_msec() / 1000.0
    return max(0.0, _rescued_iframe_end_time[idx] - current_time)

## Called by CombatSystem before applying damage — returns true if damage should be blocked
func should_block_damage(player_id: int) -> bool:
    return has_iframes(player_id)
```

### 2. DOWNTIME Vulnerability (Confirmed)

Per AC-09: DOWNTIME players CAN be hit. This is intentional urgency mechanic.

```gdscript
## DOWNTIME players are vulnerable — damage goes through
## This is by design per AC-09
func apply_damage_to_down_player(player_id: int, damage: int) -> void:
    var idx = player_id - 1
    if _player_state[idx] != CoopState.DOWNTIME:
        return
    
    _player_hp[idx] = max(0, _player_hp[idx] - damage)
    # Player stays in DOWNTIME — they can be hit but rescue window continues
```

### 3. OUT State Management

```gdscript
## OUT players cannot be rescued — they persist until life reset
func is_player_out(player_id: int) -> bool:
    return _player_state[player_id - 1] == CoopState.OUT

## Called when a life is lost (team wipe or timeout)
## Resets both players to ACTIVE state with full HP
func trigger_life_loss() -> void:
    _player_hp[0] = PLAYER_MAX_HP
    _player_hp[1] = PLAYER_MAX_HP
    _player_state[0] = CoopState.ACTIVE
    _player_state[1] = CoopState.ACTIVE
    _downtime_start_time[0] = -1.0
    _downtime_start_time[1] = -1.0
    _rescued_iframe_end_time[0] = -1.0
    _rescued_iframe_end_time[1] = -1.0

## Called when player respawns at checkpoint (AC-13)
func respawn_player(player_id: int) -> void:
    var idx = player_id - 1
    _player_hp[idx] = PLAYER_MAX_HP
    _player_state[idx] = CoopState.ACTIVE
    _downtime_start_time[idx] = -1.0
    _rescued_iframe_end_time[idx] = -1.0
```

### 4. Full State Transition Table

| State | Entry Condition | Exit Condition |
|-------|----------------|----------------|
| ACTIVE | Default / respawn / life_loss | HP reaches 0 → DOWNTIME |
| DOWNTIME | HP reaches 0 | Rescue → RESCUED / Timer expires → OUT |
| RESCUED | Rescue triggered | I-frames end → ACTIVE |
| CRISIS | Both < 30% HP | Either >= 30% → ACTIVE |
| OUT | Rescue window expires | Life loss → ACTIVE (both) |

---

## Out of Scope

- CoopManager Autoload creation (Story 001)
- DOWNTIME timer countdown (Story 002)
- CRISIS state detection (Story 004)
- UI/VFX/Audio signal consumers (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_rescued_has_iframes**: Given P1 rescued → has_iframes(P1) = true
- **test_iframes_expire**: Given 1.5s after rescue → has_iframes(P1) = false
- **test_iframe_remaining**: Given 0.5s after rescue → get_iframe_remaining(P1) ≈ 1.0
- **test_block_damage_when_rescued**: Given P1 RESCUED → should_block_damage(P1) = true
- **test_allow_damage_when_active**: Given P1 ACTIVE → should_block_damage(P1) = false
- **test_down_player_takes_damage**: Given P1 DOWNTIME at 10 HP → apply_damage_to_down_player(P1, 20) → P1 still DOWNTIME at 0 HP
- **test_out_state_persists**: Given P1 is OUT → _player_state[P1] remains OUT until life_loss
- **test_respawn_clears_out**: Given P1 OUT → respawn_player(P1) → P1 state = ACTIVE, HP = 100
- **test_life_loss_resets_both**: Given P1 OUT, P2 ACTIVE → trigger_life_loss() → both ACTIVE with 100 HP

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/coop/rescue_iframes_out_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Stories 004, 005, 006

---

## Technical Notes

### Why DOWNTIME Players Are Vulnerable (AC-09)

This is intentional. From GDD:
> "This creates urgency: the rescuing player needs to be fast"

The downed player is lying on the ground (paper debris visual) and can be hit by Boss attacks. This creates tension — the rescuer must act quickly.

### I-frames Are Real-time

The i-frame timer uses `Time.get_ticks_msec()`, same as rescue timer. This means:
- I-frames continue during hitstop
- I-frames continue when game is paused
- I-frames are consistent regardless of frame rate
