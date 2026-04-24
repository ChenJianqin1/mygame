# Story 001: CombatManager Autoload + Damage Formula

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-002` — Damage formula: base × attack_type × combo_multiplier

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
```
final_damage = base_damage × attack_type_multiplier × combo_multiplier
combo_multiplier = min(1.0 + combo_count × 0.05, 3.0)
```
- attack_type_multiplier: LIGHT=0.8, MEDIUM=1.0, HEAVY=1.5, SPECIAL=2.0
- combo_multiplier cap: 3.0 (solo)

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-DMG-*:

- [ ] **AC-DMG-001**: IDLE状态，base_damage=15，LIGHT攻击命中无连击Boss → final_damage = 15 × 0.8 = **12**
- [ ] **AC-DMG-003**: base_damage=15，HEAVY攻击命中 → final_damage = 15 × 1.5 = **23**
- [ ] **AC-DMG-010**: combo_count=0 → combo_multiplier = **1.0**
- [ ] **AC-DMG-012**: combo_count=40 → combo_multiplier = **3.0**（上限）
- [ ] **AC-DMG-020**: HEAVY攻击 + 连击10 → final_damage = 15 × 1.5 × 1.5 = **34**
- [ ] **AC-EDGE-003**: combo_count=100 → combo_multiplier = **3.0**（锁定上限）

---

## Implementation Notes

1. **Create `CombatManager.gd` Autoload** with:
   - Constants for `base_damage`, `attack_type_multiplier` map, `COMBO_DAMAGE_INCREMENT`, `MAX_COMBO_MULTIPLIER`
   - `calculate_damage(base: int, attack_type: String, combo_count: int) -> int` method
   - `get_combo_multiplier(combo_count: int) -> float` method (caps at MAX_COMBO_MULTIPLIER)

2. **Signal interface** (for downstream systems):
   ```gdscript
   signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)
   signal damage_dealt(damage: int, target_id: int, is_critical: bool)
   ```

3. **Tuning knobs exposed** as `const` at top of file (not hardcoded magic numbers)

---

## Out of Scope

- State machine transitions (Story 007)
- Hitstop triggering (Story 003)
- Knockback application (Story 002)
- Defense calculation (Story 004)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_damage_LIGHT_no_combo**: Given base=15, attack_type=LIGHT, combo=0 → expect 12
- **test_damage_HEAVY_no_combo**: Given base=15, attack_type=HEAVY, combo=0 → expect 23
- **test_damage_SPECIAL_high_combo**: Given base=15, attack_type=SPECIAL, combo=20 → expect 45 (1.0+20*0.05=2.0, capped; 15*2.0*2.0=60... wait, that's over cap. Actually: combo=20 → multiplier=2.0, 15*2.0*2.0=60 but cap is 3.0 → expect 60)
- **test_combo_multiplier_zero**: Given combo=0 → expect 1.0
- **test_combo_multiplier_40**: Given combo=40 → expect 3.0 (capped)
- **test_combo_multiplier_100**: Given combo=100 → expect 3.0 (locked)
- **test_damage_HEAVY_combo_10**: Given base=15, attack_type=HEAVY, combo=10 → expect 34

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/combat_manager_damage_test.gd` — must exist and pass

---

## Dependencies

- Depends on: None (Core layer, first combat story)
- Unlocks: Stories 002-007

## Completion Notes

**Completed**: 2026-04-23
**Code Review**: APPROVED
**Criteria**: 6/6 passing
**Test Evidence**: `tests/unit/combat/combat_manager_damage_test.gd` — 10 test functions covering all ACs + edge cases

## Test Results Summary

| Test | Status |
|------|--------|
| test_damage_LIGHT_no_combo | PASS |
| test_damage_HEAVY_no_combo | PASS |
| test_combo_multiplier_zero | PASS |
| test_combo_multiplier_40 | PASS |
| test_damage_HEAVY_combo_10 | PASS |
| test_combo_multiplier_100 | PASS |
| test_damage_MEDIUM_no_combo | PASS |
| test_damage_SPECIAL_no_combo | PASS |
| test_combo_multiplier_20 | PASS |
| test_damage_SPECIAL_high_combo | PASS |
