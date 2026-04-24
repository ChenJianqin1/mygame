# Story 004: Defense System

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-006` — Defense reduces incoming damage

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
```
incoming_damage = final_damage × (1.0 - defense_rating)
```
- defense_rating range: 0.0–0.8 (80% max reduction)
- **Minimum damage**: always at least 1 (even if defense_rating=0.8 and final_damage=6)

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-DEF-* and AC-EDGE-*:

- [ ] **AC-DEF-001**: final_damage=50, defense_rating=0.0 → incoming_damage = **50**
- [ ] **AC-DEF-003**: final_damage=6, defense_rating=0.8 → incoming_damage = **1**（最小值保护）
- [ ] **AC-EDGE-001**: final_damage=6, defense=0.8 → incoming_damage = **1**（不是0）

---

## Implementation Notes

1. **In `CombatManager.gd`** add:
   - Constants: `MAX_DEFENSE_RATING = 0.8`
   - `calculate_incoming_damage(final_damage: int, defense_rating: float) -> int`
     - Formula: `max(1, int(final_damage × (1.0 - defense_rating)))`
     - Minimum return is always 1

2. **Defense state**: Player must be in BLOCKING state to apply defense_rating
   - Story 007 handles the state machine integration

3. **Signal**: `defense_successful(blocker_id: int, damage_reduced: int)` for VFX feedback

---

## Out of Scope

- State machine BLOCKING state (Story 007)
- Visual/audio feedback for defense (VFX/Audio systems)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_defense_no_rating**: final_damage=50, defense=0.0 → incoming = 50
- **test_defense_50_percent**: final_damage=20, defense=0.5 → incoming = 10
- **test_defense_max**: final_damage=50, defense=0.8 → incoming = 10
- **test_defense_minimum_1**: final_damage=6, defense=0.8 → incoming = 1 (not 1.2 floored)
- **test_defense_zero_damage**: final_damage=0, defense=0.8 → incoming = 0 (edge case: 0 stays 0)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/defense_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (CombatManager base)
- Unlocks: Story 007 (state machine integration)

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
