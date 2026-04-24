# Story 006: Boss HP Formula

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 0.5 day

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-010` — Boss HP scales with progression, index, and co-op

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
```
boss_max_hp = floor(BASE_BOSS_HP × progression_multiplier × boss_index_multiplier × coop_scaling)
```
- BASE_BOSS_HP = 500
- progression_multiplier: 1.0–2.5 (based on game progress)
- boss_index_multiplier: {1.0, 1.3, 1.6, 2.0} for bosses 1-4
- coop_scaling: solo=1.0, co-op=1.5

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-BHP-*:

- [ ] **AC-BHP-001**: 第1Boss单人 → boss_max_hp = floor(500 × 1.0 × 1.0 × 1.0) = **500**
- [ ] **AC-BHP-010**: 午后Boss(序号3)双人 → boss_max_hp = floor(500 × 1.5 × 1.6 × 1.5) = **1800**

---

## Implementation Notes

1. **In `CombatManager.gd`** add:
   - Constants: `BASE_BOSS_HP = 500`, `boss_index_multipliers = [1.0, 1.3, 1.6, 2.0]`
   - Constants: `progression_multipliers` (1.0–2.5 range, value from game state)
   - `calculate_boss_hp(boss_index: int, is_coop: bool, progression: float) -> int`
     - progression defaults to 1.0 if not specified
     - coop_scaling = 1.5 if is_coop else 1.0
     - Returns floor of calculation

2. **Note**: This is a calculation-only story; Boss entity creation is handled by Boss AI epic

---

## Out of Scope

- Boss entity creation/management (Boss AI system)
- Boss state machine (Boss AI system)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_boss_hp_boss1_solo**: boss_index=1, is_coop=false, progression=1.0 → 500
- **test_boss_hp_boss1_coop**: boss_index=1, is_coop=true, progression=1.0 → 750
- **test_boss_hp_boss4_solo**: boss_index=4, is_coop=false, progression=1.0 → 2000
- **test_boss_hp_boss3_coop_progression**: boss_index=3, is_coop=true, progression=1.5 → 1800
- **test_boss_hp_max_scaling**: boss_index=4, is_coop=true, progression=2.5 → 7500

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/boss_hp_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (CombatManager base)
- Unlocks: Boss AI system integration

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 6/6 passing (boss1 solo, boss1 coop, boss4 solo, boss3 coop+progression, max scaling, defaults)
**Test Evidence**: `tests/unit/combat/boss_hp_test.gd`
