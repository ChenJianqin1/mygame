# Story 005: Dodge/i-frames System

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-005` — i-frames during dodge

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
- Dodge duration: `DODGE_DURATION = 12帧` (200ms @ 60fps)
- Dodge cooldown: `DODGE_COOLDOWN = 24帧` (400ms)
- During dodge: **player is invincible** — no damage taken
- Priority: DODGING state overrides BLOCKING if both triggered

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-DOD-*:

- [ ] **AC-DOD-001**: 玩家按下闪避键 → 触发DODGING状态，持续**12帧**后退出
- [ ] **AC-DOD-020**: 玩家在DODGING状态时，Boss攻击命中 → 玩家**不受到伤害**

---

## Implementation Notes

1. **In `CombatManager.gd`** add:
   - Constants: `DODGE_DURATION = 12`, `DODGE_COOLDOWN = 24`
   - Variables: `_dodge_timer: int = 0`, `_dodge_cooldown_timer: int = 0`, `_is_invincible: bool = false`
   - `start_dodge()` — sets state to DODGING, _is_invincible=true, starts 12-frame timer
   - `end_dodge()` — sets state to IDLE, _is_invincible=false, starts 24-frame cooldown
   - `is_invincible() -> bool` — returns _is_invincible
   - `can_dodge() -> bool` — returns cooldown expired

2. **Damage immunity check**: All damage application routes through `CombatManager.apply_damage_to_player()` which checks `is_invincible()` first

3. **Signal**: `player_dodged()` for VFX (dash trail), `invincibility_started()`, `invincibility_ended()`

---

## Out of Scope

- State machine transitions (Story 007)
- Visual/audio dodge feedback (VFX/Audio systems)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_dodge_duration**: Call start_dodge() → after 12 frames, is_invincible() = false
- **test_dodge_invincibility**: During dodge, is_invincible() = true
- **test_dodge_cooldown**: After dodge ends → can_dodge() = false for 24 frames
- **test_dodge_damage_blocked**: If dodge active, apply_damage_to_player() returns 0 (no damage)
- **test_dodge_priority**: If both dodge and block triggered → dodge wins (invincibility active)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat/dodge_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (CombatManager base)
- Unlocks: Story 007 (state machine integration with InputSystem signals)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 5/5 passing (dodge duration, invincibility, cooldown, damage blocked, priority)
**Test Evidence**: `tests/unit/combat/dodge_test.gd`
