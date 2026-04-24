# Story: UI Telegraphs and Attack Warnings

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Integration
> **Status**: Done

---

## Overview

Implement UI signal outputs for attack telegraphs and phase warnings, allowing the UI system to display warnings before Boss attacks.

---

## Task Description

Implement the UI-facing signals and timing that allow the UI to telegraph incoming attacks and phase changes.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **Attack telegraph timing**:
   Per GDD, attacks should be telegraphed before they happen. Add telegraph offset:
   ```gdscript
   const ATTACK_TELEGRAPH_TIME := 0.8  # seconds before attack
   ```

2. **boss_attack_telegraph signal emission**:
   When attack is selected (in _transition_to ATTACKING):
   ```gdscript
   func _transition_to(new_state: BossState) -> void:
       # ... existing transition logic ...

       match new_state:
           BossState.ATTACKING:
               var pattern: String = _select_attack_pattern()
               if pattern != PATTERN_NONE:
                   # Emit telegraph FIRST (before attack starts)
                   boss_attack_telegraph.emit(pattern)
                   Events.boss_attack_telegraph.emit(pattern)

                   # Delay actual attack start
                   await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
                   boss_attack_started.emit(pattern)
                   Events.boss_attack_started.emit(pattern)
                   _attack_cooldown = _calculate_attack_cooldown()
   ```

3. **Phase warning signal**:
   Emit phase warning 1 second before phase change:
   ```gdscript
   func _trigger_phase_change(old_phase: int, new_phase: int) -> void:
       # Emit warning first
       boss_phase_warning.emit(new_phase)
       Events.boss_phase_warning.emit(new_phase)

       # Then do phase change after delay
       await get_tree().create_timer(1.0).timeout
       _handle_phase_change()
   ```

4. **Phase warning signal definition** (already in story-001, just verify):
   ```gdscript
   signal boss_phase_warning(phase: int)
   ```

5. **Boss HP bar updates**:
   Emit signal when boss HP changes significantly:
   ```gdscript
   func set_boss_hp(new_hp: int) -> void:
       var old_hp: int = _boss_hp
       _boss_hp = clampi(new_hp, 0, _boss_max_hp)

       # Emit HP changed signal for UI
       Events.boss_hp_changed.emit(_boss_hp, _boss_max_hp)

       _check_phase_transition()
       # ... rest of existing logic ...
   ```

   Add signal:
   ```gdscript
   signal boss_hp_changed(current_hp: int, max_hp: int)
   ```

6. **Attack pattern name mapping** (for UI display):
   ```gdscript
   const PATTERN_DISPLAY_NAMES := {
       PATTERN_RELENTLESS_ADVANCE: "截稿压力",
       PATTERN_PAPER_AVALANCHE: "工作堆积",
       PATTERN_PANIC_OVERLOAD: "Deadline panic"
   }

   func get_attack_display_name(pattern: String) -> String:
       return PATTERN_DISPLAY_NAMES.get(pattern, pattern)
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | Signal definitions |
| Attack pattern selection | story-005 | _select_attack_pattern, boss_attack_started |
| Phase system | story-004 | _trigger_phase_change |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | boss_attack_telegraph emits before boss_attack_started | Integration test |
| AC-02 | Telegraph delay is 0.8 seconds | Unit test |
| AC-03 | boss_phase_warning emits before boss_phase_changed | Integration test |
| AC-04 | Phase warning delay is 1.0 seconds | Unit test |
| AC-05 | boss_hp_changed emits when set_boss_hp is called | Integration test |
| AC-06 | Events.boss_attack_telegraph broadcasts to all listeners | Integration test |
| AC-07 | Events.boss_phase_warning broadcasts to all listeners | Integration test |
| AC-08 | get_attack_display_name returns correct Chinese names | Unit test |

---

## Estimated Effort

- **Expected**: 0.5 days
- **Optimistic**: 0.25 days
- **Pessimistic**: 1 day

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add telegraph timing) |

---

## Notes

- UI team will consume these signals to show warning indicators
- Telegraph timing (0.8s) gives players time to react but doesn't make attacks too easy
- Phase warning (1.0s) is slightly longer to account for phase change animation
