# Story 007: Player State Machine Integration

> **Epic**: combat
> **Status**: Done
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-001` — 7-state player state machine

**ADR Governing Implementation**: ADR-ARCH-003: Combat State Machine
**ADR Decision Summary**:
```
Player States: IDLE | MOVING | ATTACKING | HURT | DODGING | BLOCKING | DOWNTIME

IDLE ──[attacked]──► ATTACKING ──[anim_end]──► IDLE
  │                    ▲
  │                    │
  └──[dodged]──► DODGING ──[12帧结束]──► IDLE
  │
  └──[hurt_received]──► HURT ──[硬直结束]──► IDLE
  │
  └──[blocking]──► BLOCKING ──[松开/超时]──► IDLE
  │
  └──[hp≤0]──► DOWNTIME
```

**Engine**: Godot 4.6 | **Risk**: LOW
**Dependencies**: ADR-ARCH-001 (Events), ADR-ARCH-002 (Collision Detection)

---

## Acceptance Criteria

From GDD AC-STATE-*:

- [ ] **AC-STATE-001**: IDLE状态，收到attacked(LIGHT)信号 → 进入**ATTACKING**状态
- [ ] **AC-STATE-003**: IDLE状态，收到dodged()信号 → 进入**DODGING**状态

**Full state coverage** (integration test):
- [ ] IDLE → MOVING (move_direction non-zero)
- [ ] IDLE → ATTACKING (attacked signal)
- [ ] IDLE → DODGING (dodged signal)
- [ ] IDLE → BLOCKING (block input held)
- [ ] IDLE → HURT (hurt_received signal)
- [ ] IDLE → DOWNTIME (hp ≤ 0)
- [ ] ATTACKING → IDLE (animation ended)
- [ ] HURT → IDLE (hurt duration ended)
- [ ] DODGING → IDLE (12 frames elapsed)
- [ ] BLOCKING → IDLE (block released or timeout)

---

## Implementation Notes

1. **Create `PlayerStateMachine.gd`** (extends Node2D, not Autoload):
   - States: `idle`, `moving`, `attacking`, `hurt`, `dodging`, `blocking`, `downtime`
   - `transition_to(new_state: String)` with enter/exit callbacks
   - Frame-timer based duration tracking for HURT, DODGING, BLOCKING

2. **Signal connections**:
   - Subscribe to `Events.input_action` for attacked/dodged/block signals
   - Subscribe to `Events.hit_confirmed` for hurt_received
   - Subscribe to `Events.player_hp_changed` for hp≤0 check

3. **Integration with CombatManager**:
   - `CombatManager.attacked.emit(action_type)` → triggers attack
   - `CombatManager.start_dodge()` called on dodged signal
   - `CombatManager.is_invincible()` checked before applying damage

4. **Outgoing signals**:
   - `player_state_changed(old_state, new_state)` → Events for UI/VFX

---

## Out of Scope

- Boss state machine (Boss AI epic)
- Animation playback (Animation epic)
- VFX triggers per state (Particle VFX epic)

---

## QA Test Cases

**Integration Test Specs**:

- **test_state_idle_to_attacking**: Given state=IDLE, when attacked(LIGHT) emitted → expect state=ATTACKING
- **test_state_idle_to_dodging**: Given state=IDLE, when dodged() emitted → expect state=DODGING
- **test_state_attacking_to_idle**: Given state=ATTACKING, when anim_end signal → expect state=IDLE
- **test_state_hurt_to_idle**: Given state=HURT, when hurt timer expires → expect state=IDLE
- **test_state_dodging_to_idle**: Given state=DODGING, when 12 frames elapsed → expect state=IDLE
- **test_state_idle_to_downtime**: Given state=IDLE, when hp≤0 → expect state=DOWNTIME
- **test_dodge_invincibility_during**: When DODGING → CombatManager.is_invincible() = true
- **test_block_triggers_defense**: When BLOCKING → incoming damage reduced by defense_rating

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat/player_state_machine_test.gd` — must exist and pass OR documented playtest sign-off

---

## Dependencies

- Depends on: Stories 001-005 (CombatManager methods), Events Autoload, Collision Detection
- Unlocks: Combo system, Boss AI, VFX integration

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 10/10 passing (all AC-STATE-* transitions)
**Test Evidence**: `tests/integration/combat/player_state_machine_test.gd`
