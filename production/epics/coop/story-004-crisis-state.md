# Story 004: CRISIS State Detection + Damage Reduction

> **Epic**: coop
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/coop-system.md`
**Requirement**: `TR-coop-006`, `TR-coop-007` — CRISIS state activation and deactivation

**ADR Governing Implementation**: ADR-ARCH-005: Coop System HP Pools & Rescue
**ADR Decision Summary**:
```
CRISIS_HP_THRESHOLD = 30%
CRISIS_DAMAGE_REDUCTION = 25%
CRISIS activates when BOTH players < 30% HP
CRISIS deactivates when EITHER player >= 30% HP
CRISIS and SOLO reductions do NOT stack
```

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-06, AC-07:

- [ ] **AC-06**: Both players below 30 HP → both below threshold → CRISIS state activates
- [ ] **AC-07**: CRISIS active, P1 rescued to 50 HP → P1 >= 30% → CRISIS ends (P2 still <30%)

---

## Implementation Notes

### 1. CRISIS State Detection

```gdscript
## CRISIS requires:
## 1. Both players must be alive (ACTIVE or RESCUED)
## 2. Both players must be below CRISIS_HP_THRESHOLD
var _is_crisis_active: bool = false

func _update_crisis_state() -> void:
    # Both must be alive to trigger CRISIS
    var p1_alive = (_player_state[0] == CoopState.ACTIVE or _player_state[0] == CoopState.RESCUED)
    var p2_alive = (_player_state[1] == CoopState.ACTIVE or _player_state[1] == CoopState.RESCUED)
    
    if not (p1_alive and p2_alive):
        if _is_crisis_active:
            _is_crisis_active = false
            crisis_state_changed.emit(false)
        return
    
    # Check HP thresholds
    var p1_hp_percent = float(_player_hp[0]) / float(PLAYER_MAX_HP)
    var p2_hp_percent = float(_player_hp[1]) / float(PLAYER_MAX_HP)
    
    var both_below = (p1_hp_percent < CRISIS_HP_THRESHOLD) and (p2_hp_percent < CRISIS_HP_THRESHOLD)
    
    if both_below and not _is_crisis_active:
        _is_crisis_active = true
        crisis_activated.emit()
        crisis_state_changed.emit(true)
    elif not both_below and _is_crisis_active:
        _is_crisis_active = false
        crisis_state_changed.emit(false)
```

### 2. CRISIS Damage Reduction Query

```gdscript
## CRISIS damage reduction: 25% incoming damage reduction
## Does NOT stack with SOLO reduction — CRISIS takes priority
func get_crisis_damage_multiplier() -> float:
    if _is_crisis_active:
        return 1.0 - CRISIS_DAMAGE_REDUCTION  # Returns 0.75
    return 1.0

## Combined damage multiplier for a player
## Called by CombatSystem when applying damage to a player
func get_incoming_damage_multiplier(player_id: int) -> float:
    var idx = player_id - 1
    
    # CRISIS takes priority — if active, use CRISIS multiplier
    if _is_crisis_active:
        return get_crisis_damage_multiplier()
    
    # Check SOLO mode
    var partner_idx = 1 - idx
    var is_solo = (_player_state[idx] == CoopState.ACTIVE or _player_state[idx] == CoopState.RESCUED) and \
                  (_player_state[partner_idx] == CoopState.DOWNTIME or _player_state[partner_idx] == CoopState.OUT)
    
    if is_solo:
        return 1.0 - SOLO_DAMAGE_REDUCTION  # Returns 0.75 (25% reduction)
    
    return 1.0  # No reduction
```

### 3. Call Integration

CRISIS detection runs in `_process()` from Story 001. This story adds the:
- `crisis_activated` signal emit
- `crisis_state_changed` signal logic
- `get_incoming_damage_multiplier()` method

---

## Out of Scope

- CoopManager Autoload creation (Story 001)
- SOLO damage reduction implementation (Story 005)
- UI edge glow effect (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_crisis_activates**: Given P1 at 29 HP, P2 at 29 HP → is_crisis_active() = true
- **test_crisis_not_active_one_above**: Given P1 at 30 HP, P2 at 29 HP → is_crisis_active() = false
- **test_crisis_deactivates**: Given CRISIS active, P1 healed to 50 HP → is_crisis_active() = false
- **test_crisis_deactivates_on_rescue**: Given P1 DOWNTIME, P2 at 29 HP, P1 rescued to 50 HP → CRISIS ends
- **test_crisis_excludes_out_player**: Given P1 OUT, P2 at 29 HP → is_crisis_active() = false (P1 not alive)
- **test_crisis_excludes_downtime_player**: Given P1 DOWNTIME, P2 at 29 HP → is_crisis_active() = false (P1 not alive)
- **test_crisis_damage_multiplier**: Given CRISIS active → get_crisis_damage_multiplier() = 0.75
- **test_crisis_priority_over_solo**: Given CRISIS active and SOLO mode → get_incoming_damage_multiplier(P1) = 0.75 (CRISIS wins)
- **test_crisis_signal_emitted**: Given P1 at 29 HP, P2 drops to 29 HP → crisis_activated signal emitted once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/coop/crisis_state_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Stories 001, 002, 003
- Unlocks: Stories 005, 006

---

## Technical Notes

### Why CRISIS Excludes DOWNTIME/OUT Players

CRISIS is a state where BOTH players are in danger. A player who is DOWNTIME or OUT cannot contribute to the co-op challenge, so they don't count toward triggering CRISIS.

From GDD Edge Case 8:
> "CRISIS requires BOTH players — a solo player at any HP cannot trigger it"

### CRISIS vs SOLO Priority

Per GDD formula section:
> "CRISIS and SOLO reductions do NOT stack — CRISIS takes priority when both apply."

This means if CRISIS is active, the player gets 25% CRISIS reduction, NOT 25% SOLO reduction + 25% CRISIS stacking.
