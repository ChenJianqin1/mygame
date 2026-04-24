# Story 003: Hitstop System

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-003` — Hitstop: base + bonus per attack/target type

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
```
hitstop_frames = base_hitstop[attack_type] + bonus_hitstop[target_type]
```
- base_hitstop: LIGHT=3, MEDIUM=5, HEAVY=8, SPECIAL=12
- bonus_hitstop: PLAYER=0, BOSS=2, ELITE=1
- **Co-op stacking**: simultaneous hits (within 3-frame window) stack hitstop

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-HS-*:

- [ ] **AC-HS-001**: attack_type=LIGHT → hitstop_frames = **3帧**
- [ ] **AC-HS-004**: attack_type=SPECIAL → hitstop_frames = **12帧**
- [ ] **AC-HS-010**: LIGHT命中BOSS → hitstop_frames = 3 + 2 = **5帧**

---

## Implementation Notes

1. **In `CombatManager.gd`** add:
   - Constants: `base_hitstop: Dictionary = {LIGHT: 3, MEDIUM: 5, HEAVY: 8, SPECIAL: 12}`
   - Constants: `bonus_hitstop: Dictionary = {PLAYER: 0, BOSS: 2, ELITE: 1}`
   - `calculate_hitstop(attack_type: String, target_type: String) -> int`
   - `trigger_hitstop(frames: int)` — pauses both attacker and target for specified frames

2. **Co-op stacking**: `CombatManager` tracks recent hitstop triggers; if another hit occurs within 3 frames, add the new hitstop frames to existing

3. **Signal**: `hitstop_started(frames: int)` and `hitstop_ended()` for VFX/animation coordination

---

## Out of Scope

- Visual feedback during hitstop (VFX system)
- State machine transitions (Story 007)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_hitstop_LIGHT**: attack_type=LIGHT, target=PLAYER → frames = 3
- **test_hitstop_MEDIUM**: attack_type=MEDIUM, target=PLAYER → frames = 5
- **test_hitstop_HEAVY**: attack_type=HEAVY, target=PLAYER → frames = 8
- **test_hitstop_SPECIAL**: attack_type=SPECIAL, target=PLAYER → frames = 12
- **test_hitstop_LIGHT_on_BOSS**: attack_type=LIGHT, target=BOSS → frames = 5
- **test_hitstop_LIGHT_on_ELITE**: attack_type=LIGHT, target=ELITE → frames = 4
- **test_hitstop_HEAVY_on_BOSS**: attack_type=HEAVY, target=BOSS → frames = 10

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/hitstop_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (CombatManager base)
- Unlocks: Integration with VFX system

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
