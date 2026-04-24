# Story: Boss AI Macro FSM States

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Implement the Boss AI Macro FSM (Finite State Machine) with all 5 states, state transitions, and transition validation.

---

## Task Description

Implement the宏观 FSM layer of Boss AI — the state machine that governs Boss's high-level behavior.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **_transition_to(new_state: BossState) method**:
   - Validates transition is allowed
   - Records old state
   - Updates _boss_state
   - Side effects per target state:
     - `ATTACKING`: emit boss_attack_started, Events.boss_attack_started
     - `HURT`: trigger hurt animation
     - `PHASE_CHANGE`: call _handle_phase_change()
     - `DEFEATED`: set _compression_wall_x = -9999 (stops compression)

2. **State transition rules** (from GDD Detailed Design):

   | Current State | Allowed Next States | Trigger |
   |--------------|---------------------|---------|
   | IDLE | ATTACKING, HURT, DEFEATED | AI decision / player hit / HP=0 |
   | ATTACKING | IDLE, HURT, DEFEATED | Animation complete / player hit / HP=0 |
   | HURT | IDLE, DEFEATED | Hurt duration ends / HP=0 |
   | PHASE_CHANGE | ATTACKING, DEFEATED | Transition complete / HP=0 |
   | DEFEATED | (none) | — |

3. **Invalid transition handling**:
   - If transition_to is called with invalid next state, log warning and ignore
   - HURT should block new ATTACKING (boss is staggered)
   - DEFEATED is terminal — no transitions out

4. **State query method** (already stubbed in story-001, now fully implemented):
   ```gdscript
   func get_boss_state() -> String:
       match _boss_state:
           BossState.IDLE: return "IDLE"
           BossState.ATTACKING: return "ATTACKING"
           BossState.HURT: return "HURT"
           BossState.PHASE_CHANGE: return "PHASE_CHANGE"
           BossState.DEFEATED: return "DEFEATED"
       return "UNKNOWN"
   ```

5. **State duration tracking**:
   - Add `_state_timer: float = 0.0`
   - Increment in _process: `_state_timer += delta`
   - Reset on each _transition_to call

6. **Public state request methods**:
   ```gdscript
   func request_attack() -> void:
       # Called by AI when ready to attack
       if _boss_state == BossState.IDLE:
           _transition_to(BossState.ATTACKING)

   func request_hurt(duration: float) -> void:
       # Called by CombatSystem when boss takes damage
       if _boss_state != BossState.DEFEATED:
           _transition_to(BossState.HURT)
           _hurt_duration = duration

   func force_defeated() -> void:
       _transition_to(BossState.DEFEATED)
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | Must have BossState enum and member variables |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | IDLE → ATTACKING transition works and sets state correctly | Unit test |
| AC-02 | Any state → DEFEATED works (terminal state) | Unit test |
| AC-03 | HURT blocks new ATTACKING transition | Unit test |
| AC-04 | DEFEATED has no outgoing transitions | Unit test |
| AC-05 | get_boss_state() returns correct string for all 5 states | Unit test |
| AC-06 | _state_timer increments while in any non-DEFEATED state | Unit test |
| AC-07 | request_attack() from IDLE triggers ATTACKING | Unit test |
| AC-08 | request_hurt() triggers HURT state | Unit test |
| AC-09 | force_defeated() always succeeds regardless of current state | Unit test |
| AC-10 | ATTACKING transition emits boss_attack_started signal | Unit test |

---

## Estimated Effort

- **Expected**: 1 day
- **Optimistic**: 0.5 days
- **Pessimistic**: 1.5 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add FSM logic) |

---

## Notes

- FSM logic is synchronous — no async/await needed
- Transitions are immediate, not animated
- HURT duration is set by CombatSystem via request_hurt(duration)
