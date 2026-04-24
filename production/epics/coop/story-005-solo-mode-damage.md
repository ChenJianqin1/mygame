# Story 005: SOLO Mode + Damage Modifiers Integration

> **Epic**: coop
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/coop-system.md`
**Requirement**: `TR-coop-005` — SOLO mode damage reduction when partner is downed

**ADR Governing Implementation**: ADR-ARCH-005: Coop System HP Pools & Rescue
**ADR Decision Summary**:
```
SOLO_DAMAGE_REDUCTION = 25% (when partner is DOWNTIME or OUT)
SOLO mode activates when partner is DOWNTIME or OUT
Solo player does NOT receive co-op passive bonus
```

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-05:

- [ ] **AC-05**: P1 OUT → P2 continues fight → P2 gets SOLO_DAMAGE_REDUCTION = 25%

---

## Implementation Notes

### 1. SOLO Mode Detection

```gdscript
## SOLO mode: one player is ACTIVE/RESCUED while partner is DOWNTIME/OUT
func is_solo_mode(player_id: int) -> bool:
    var idx = player_id - 1
    var partner_idx = 1 - idx
    
    # Player must be alive
    var player_alive = (_player_state[idx] == CoopState.ACTIVE or _player_state[idx] == CoopState.RESCUED)
    if not player_alive:
        return false
    
    # Partner must be downed or out
    var partner_down = (_player_state[partner_idx] == CoopState.DOWNTIME or \
                        _player_state[partner_idx] == CoopState.OUT)
    
    return partner_down
```

### 2. SOLO Damage Reduction

```gdscript
## Get SOLO damage reduction multiplier
## Returns 1.0 if not in SOLO mode, 0.75 if in SOLO mode
func get_solo_damage_multiplier() -> float:
    # Note: This is only called when CRISIS is not active
    # CRISIS takes priority per Story 004
    return 1.0 - SOLO_DAMAGE_REDUCTION  # Returns 0.75
```

### 3. CoopManager Query Interface for CombatSystem

```gdscript
## Full damage query interface for CombatSystem
## Returns combined damage multiplier based on all active modifiers

## Get effective outgoing damage multiplier for a player (for their attacks)
## Used when player attacks boss — applies COOP_BONUS
func get_outgoing_damage_multiplier(player_id: int) -> float:
    var idx = player_id - 1
    
    # Can only get bonus if player is alive
    if not (_player_state[idx] == CoopState.ACTIVE or _player_state[idx] == CoopState.RESCUED):
        return 1.0
    
    # Can only get COOP_BONUS if partner is also alive
    var partner_idx = 1 - idx
    var partner_alive = (_player_state[partner_idx] == CoopState.ACTIVE or \
                          _player_state[partner_idx] == CoopState.RESCUED)
    
    if partner_alive:
        return 1.0 + COOP_BONUS  # Returns 1.10
    else:
        # SOLO player — no COOP_BONUS
        return 1.0

## Get effective incoming damage multiplier for a player (for received damage)
## Used when boss attacks player — applies SOLO or CRISIS reduction
func get_incoming_damage_multiplier(player_id: int) -> float:
    # CRISIS takes priority (handled in Story 004)
    if _is_crisis_active:
        return get_crisis_damage_multiplier()
    
    # Check SOLO mode
    if is_solo_mode(player_id):
        return get_solo_damage_multiplier()
    
    return 1.0  # No reduction
```

### 4. Signal Emissions for SOLO Mode

```gdscript
## Emit solo_mode_active signal when SOLO mode starts/stops
var _solo_mode_active_player: int = 0  # 0 = none, 1 = P1, 2 = P2

func _update_solo_state() -> void:
    var p1_solo = is_solo_mode(1)
    var p2_solo = is_solo_mode(2)
    
    # Track transitions
    if p1_solo and _solo_mode_active_player != 1:
        solo_mode_active.emit(1)
        _solo_mode_active_player = 1
    elif not p1_solo and _solo_mode_active_player == 1:
        _solo_mode_active_player = 0
```

---

## Out of Scope

- CoopManager Autoload creation (Story 001)
- DOWNTIME/OUT state management (Stories 002, 003)
- CRISIS state detection (Story 004)
- UI indicator for SOLO mode (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_solo_mode_activates_on_partner_downtime**: Given P1 ACTIVE, P2 DOWNTIME → is_solo_mode(P1) = true
- **test_solo_mode_activates_on_partner_out**: Given P1 ACTIVE, P2 OUT → is_solo_mode(P1) = true
- **test_solo_mode_not_active_both_alive**: Given P1 ACTIVE, P2 ACTIVE → is_solo_mode(P1) = false
- **test_solo_mode_not_active_both_down**: Given P1 DOWNTIME, P2 DOWNTIME → is_solo_mode(P1) = false
- **test_solo_damage_multiplier**: Given SOLO mode → get_solo_damage_multiplier() = 0.75
- **test_coop_bonus_no_partner**: Given P1 ACTIVE, P2 OUT → get_outgoing_damage_multiplier(P1) = 1.0
- **test_coop_bonus_with_partner**: Given P1 ACTIVE, P2 ACTIVE → get_outgoing_damage_multiplier(P1) = 1.10
- **test_incoming_solo**: Given P1 SOLO, not CRISIS → get_incoming_damage_multiplier(P1) = 0.75
- **test_solo_signal**: Given P1 becomes SOLO → solo_mode_active.emit(P1) once

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/coop/solo_mode_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Stories 001, 002, 003, 004
- Unlocks: Story 006

---

## Technical Notes

### COOP_BONUS is for Outgoing Damage Only

The COOP_BONUS (+10%) applies when the player attacks the boss. It does NOT apply to incoming damage.

Formula from GDD:
```
effective_damage = base_damage * attack_type_multiplier * (1.0 + combo_multiplier) * (1.0 + COOP_BONUS)
```

### SOLO Mode is for Incoming Damage Only

The SOLO_DAMAGE_REDUCTION (25%) applies when the player receives damage from the boss. It does NOT affect outgoing damage.

Formula from GDD:
```
effective_damage = incoming_damage * (1.0 - SOLO_DAMAGE_REDUCTION)
```

### Why No COOP_BONUS in SOLO Mode

Per GDD Rule 4:
> "Solo player (partner in downtime): SOLO_DAMAGE_REDUCTION = 25% (compensation)"
> "Solo player does NOT receive co-op passive bonus"

The 25% damage reduction IS the SOLO compensation. The COOP_BONUS only applies when both players are actively fighting.
