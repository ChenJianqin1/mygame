# Story: Boss AI Testing and Integration

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Write unit tests covering all Boss AI acceptance criteria, verify integration with Events and CoopSystem stubs, and validate the GDD acceptance criteria.

---

## Task Description

Create comprehensive unit tests for BossAIManager covering all acceptance criteria from stories 001-008.

**File location**: `tests/unit/ai/boss_ai_manager_test.gd`

### Test Structure

Follow GdUnit4 naming: `test_[scenario]_[expected].gd`

### Tests to Implement

1. **Foundation tests** (story-001):
   ```gdscript
   func test_boss_ai_constants_have_correct_values():
       assert_eq(BossAIManager.BASE_BOSS_HP, 500)
       assert_eq(BossAIManager.BASE_COMPRESSION_SPEED, 32.0)
       assert_eq(BossAIManager.COMPRESSION_DAMAGE_RATE, 5.0)
       assert_eq(BossAIManager.MIN_ATTACK_INTERVAL, 1.5)
       assert_eq(BossAIManager.MERCY_ZONE, 100.0)
       assert_eq(BossAIManager.RESCUE_SLOWDOWN, 0.5)
       assert_eq(BossAIManager.RESCUE_SUSPENSION, 2.0)
       assert_eq(BossAIManager.PHASE_2_THRESHOLD, 0.60)
       assert_eq(BossAIManager.PHASE_3_THRESHOLD, 0.30)

   func test_boss_state_enum_has_all_states():
       assert_eq(BossAIManager.BossState.size(), 5)

   func test_initial_state_is_idle():
       assert_eq(BossAIManager.get_boss_state(), "IDLE")

   func test_initial_phase_is_1():
       assert_eq(BossAIManager.get_current_phase(), 1)
   ```

2. **FSM tests** (story-002):
   ```gdscript
   func test_idle_to_attacking_transition():
       BossAIManager.request_attack()
       assert_eq(BossAIManager.get_boss_state(), "ATTACKING")

   func test_any_state_to_defeated():
       BossAIManager.force_defeated()
       assert_eq(BossAIManager.get_boss_state(), "DEFEATED")

   func test_hurt_blocks_attack():
       BossAIManager.request_hurt(1.0)
       BossAIManager.request_attack()  # Should not transition
       assert_eq(BossAIManager.get_boss_state(), "HURT")

   func test_defeated_has_no_outgoing_transitions():
       BossAIManager.force_defeated()
       BossAIManager.request_attack()  # Should not transition
       assert_eq(BossAIManager.get_boss_state(), "DEFEATED")
   ```

3. **Compression tests** (story-003):
   ```gdscript
   func test_phase_1_compression_speed():
       BossAIManager.set_boss_hp(BossAIManager.BASE_BOSS_HP)
       var speed = BossAIManager._calculate_compression_speed()
       assert_eq(speed, 32.0)  # base * 1.0

   func test_phase_2_compression_speed():
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.5))
       var speed = BossAIManager._calculate_compression_speed()
       assert_eq(speed, 48.0)  # base * 1.5

   func test_phase_3_compression_speed():
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.2))
       var speed = BossAIManager._calculate_compression_speed()
       assert_eq(speed, 64.0)  # base * 2.0

   func test_compression_does_not_run_in_defeated():
       # Setup: advance some compression
       var initial_x = BossAIManager.get_compression_wall_x()
       BossAIManager.force_defeated()
       # Process one frame (simulated)
       # compression should not advance
       assert_eq(BossAIManager.get_compression_wall_x(), initial_x)
   ```

4. **Phase tests** (story-004):
   ```gdscript
   func test_phase_1_at_100_hp():
       BossAIManager.set_boss_hp(BossAIManager.BASE_BOSS_HP)
       assert_eq(BossAIManager.get_current_phase(), 1)

   func test_phase_2_at_59_hp():
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.59))
       assert_eq(BossAIManager.get_current_phase(), 2)

   func test_phase_3_at_29_hp():
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.29))
       assert_eq(BossAIManager.get_current_phase(), 3)

   func test_phase_transition_emits_signal():
       # Track signal emission
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.59))
       # Signal should have emitted
   ```

5. **Attack selection tests** (story-005):
   ```gdscript
   func test_phase_1_only_relentless_advance():
       BossAIManager.set_boss_hp(BossAIManager.BASE_BOSS_HP)
       var pattern = BossAIManager._select_attack_pattern()
       assert_eq(pattern, BossAIManager.PATTERN_RELENTLESS_ADVANCE)

   func test_rescue_suspension_blocks_attack():
       BossAIManager._rescue_suspension_timer = 1.0
       var pattern = BossAIManager._select_attack_pattern()
       assert_eq(pattern, BossAIManager.PATTERN_NONE)

   func test_attack_cooldown_at_full_hp():
       var cooldown = BossAIManager._calculate_attack_cooldown()
       assert_eq(cooldown, 2.5)  # no floor hit

   func test_attack_cooldown_at_50_hp():
       var cooldown = BossAIManager._calculate_attack_cooldown()  # Need HP scaling
       # At 50% HP, hp_multiplier = 0.75, cooldown = max(1.5, 2.5*0.75) = 1.875
   ```

6. **GDD Acceptance Criteria tests**:
   ```gdscript
   # From GDD AC-01 to AC-13
   func test_ac_01_phase_1_at_full_hp():
       BossAIManager.set_boss_hp(BossAIManager.BASE_BOSS_HP)
       assert_eq(BossAIManager.get_current_phase(), 1)

   func test_ac_09_hp_crosses_60_triggers_phase_change():
       # Setup at 65%, then set to 58%
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.65))
       BossAIManager.set_boss_hp(int(BossAIManager.BASE_BOSS_HP * 0.58))
       assert_eq(BossAIManager.get_boss_state(), "PHASE_CHANGE")
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | All tests depend on base implementation |
| All other stories | stories 002-008 | Tests cover their acceptance criteria |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | All 8 constants tested with correct values | Unit test |
| AC-02 | BossState enum has 5 states | Unit test |
| AC-03 | All 5 FSM state transitions tested | Unit test |
| AC-04 | Compression speed by phase tested | Unit test |
| AC-05 | Phase transitions at 60%/30% HP tested | Unit test |
| AC-06 | All attack pattern selection by phase tested | Unit test |
| AC-07 | Attack cooldown formula tested | Unit test |
| AC-08 | GDD acceptance criteria AC-01 to AC-13 covered | Unit test |
| AC-09 | All tests pass (100%) | CI gate |

---

## Estimated Effort

- **Expected**: 1.5 days
- **Optimistic**: 1 day
- **Pessimistic**: 2 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `tests/unit/ai/boss_ai_manager_test.gd` | Create |
| `tests/unit/ai/` | Create directory if needed |

---

## Notes

- Tests must be deterministic — no random seeds, no time dependencies
- Use dependency injection for CoopManager stubs
- Tests should reset BossAIManager state in `test_suite_before()` or `@before"
- Some tests may need to mock CoopManager returning true for rescue/crisis
