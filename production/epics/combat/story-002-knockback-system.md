# Story 002: Knockback System

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-004` — Knockback direction away from attacker

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
```
knockback_force = base_knockback[attack_type] × normalize(target_position - attacker_position)
```
- base_knockback: LIGHT=50px, MEDIUM=100px, HEAVY=200px, SPECIAL=300px
- Direction: always **away from attacker**

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-KB-*:

- [ ] **AC-KB-001**: 攻击者(100,0)，目标(200,0) → knockback方向 = normalize((200-100,0)) = **(1,0)**
- [ ] **AC-KB-010**: LIGHT攻击，方向(1,0) → knockback_force = 50 × (1,0) = **(50, 0)**

---

## Implementation Notes

1. **In `CombatManager.gd`** add:
   - Constants: `base_knockback: Dictionary = {LIGHT: 50.0, MEDIUM: 100.0, HEAVY: 200.0, SPECIAL: 300.0}`
   - `apply_knockback(target: Node2D, attacker_position: Vector2, attack_type: String) -> Vector2`
     - Calculate direction: `normalize(target.global_position - attacker_position)`
     - Calculate force: `base_knockback[attack_type] * direction`
     - Return knockback vector (caller applies to target's velocity)

2. **Edge case**: attacker and target at same position → use Vector2(1, 0) as fallback direction

---

## Out of Scope

- Hitstop during knockback (Story 003)
- State machine transitions (Story 007)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_knockback_direction_right**: Given attacker=(100,0), target=(200,0) → direction = (1, 0)
- **test_knockback_direction_left**: Given attacker=(200,0), target=(100,0) → direction = (-1, 0)
- **test_knockback_LIGHT_force**: Given attack_type=LIGHT, direction=(1,0) → force = (50, 0)
- **test_knockback_HEAVY_force**: Given attack_type=HEAVY, direction=(0,-1) → force = (0, -200)
- **test_knockback_same_position**: Given attacker=target → use fallback (1, 0)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/knockback_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (CombatManager base structure)
- Unlocks: Integration with collision detection

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
