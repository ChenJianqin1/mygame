# Story: Phase System

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Implement phase transitions triggered by Boss HP crossing 60% and 30% thresholds, including phase change state handling and phase-specific behavior hooks.

---

## Task Description

Implement the Phase System that governs Boss difficulty escalation. Phases are triggered by HP thresholds.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **HP tracking member variable** (add to story-001):
   ```gdscript
   var _boss_hp: int = BASE_BOSS_HP
   var _boss_max_hp: int = BASE_BOSS_HP
   ```

2. **HP update method**:
   ```gdscript
   func set_boss_hp(new_hp: int) -> void:
       var old_hp: int = _boss_hp
       _boss_hp = clampi(new_hp, 0, _boss_max_hp)

       # Check for phase transitions
       _check_phase_transition()

       # Check for defeat
       if _boss_hp <= 0 and _boss_state != BossState.DEFEATED:
           force_defeated()
   ```

3. **_check_phase_transition() method**:
   ```gdscript
   func _check_phase_transition() -> void:
       var hp_ratio: float = float(_boss_hp) / float(_boss_max_hp)
       var old_phase: int = _current_phase

       # Determine new phase
       if hp_ratio <= PHASE_3_THRESHOLD:
           _current_phase = 3
       elif hp_ratio <= PHASE_2_THRESHOLD:
           _current_phase = 2
       else:
           _current_phase = 1

       # Trigger transition if phase changed
       if _current_phase != old_phase:
           _trigger_phase_change(old_phase, _current_phase)
   ```

4. **_trigger_phase_change(old_phase: int, new_phase: int) method**:
   - If not already in PHASE_CHANGE or DEFEATED state:
     - _transition_to(PHASE_CHANGE)
   - Emit `boss_phase_warning(new_phase)` 1 second before transition (for UI telegraph)
   - Call `_handle_phase_change()` after brief delay (~1s)

5. **_handle_phase_change() method**:
   - Compression already paused during PHASE_CHANGE
   - Emit `boss_phase_changed.emit(new_phase)`
   - Emit `Events.boss_phase_changed.emit(new_phase)`
   - Transition to IDLE after phase change animation completes

6. **Query methods**:
   ```gdscript
   func get_current_phase() -> int:
       return _current_phase

   func get_hp_ratio() -> float:
       return float(_boss_hp) / float(_boss_max_hp)

   func get_boss_hp() -> int:
       return _boss_hp

   func get_boss_max_hp() -> int:
       return _boss_max_hp
   ```

7. **Set max HP method** (for different bosses/scaling):
   ```gdscript
   func set_max_hp(new_max: int) -> void:
       _boss_max_hp = new_max
       _boss_hp = mini(_boss_hp, _boss_max_hp)
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | _current_phase, member variables |
| Macro FSM states | story-002 | _transition_to, PHASE_CHANGE state |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | Boss HP = 100%: current_phase = 1 | Unit test |
| AC-02 | Boss HP = 59%: current_phase = 2 | Unit test |
| AC-03 | Boss HP = 29%: current_phase = 3 | Unit test |
| AC-04 | HP crosses 60% downward triggers PHASE_CHANGE | Unit test |
| AC-05 | HP crosses 30% downward triggers PHASE_CHANGE | Unit test |
| AC-06 | boss_phase_changed signal emits on phase transition | Unit test |
| AC-07 | Phase 1 → 2 triggers compression speed change | Unit test |
| AC-08 | HP = 0 triggers DEFEATED state | Unit test |
| AC-09 | get_hp_ratio() returns correct float (0.0 to 1.0) | Unit test |
| AC-10 | set_max_hp() clamps current HP to new max | Unit test |

---

## Estimated Effort

- **Expected**: 1 day
- **Optimistic**: 0.5 days
- **Pessimistic**: 1.5 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add phase logic) |

---

## Notes

- Phase transitions are one-way (Phase 1 → 2 → 3), never backwards
- Phase transition can occur mid-attack (current attack completes under old phase rules)
- _handle_phase_change() is called from the FSM transition, not directly
