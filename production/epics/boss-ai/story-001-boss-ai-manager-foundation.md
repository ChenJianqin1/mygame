# Story: Boss AI Manager Foundation

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Create the BossAIManager Autoload singleton with constants, state enum, member variables, and ready signal connections.

---

## Task Description

Create `BossAIManager.gd` as an Autoload singleton. This is the foundational story — all other Boss AI stories depend on it.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **Autoload registration**: Add `BossAIManager` to project.godot autoloads

2. **Constants** (from GDD Tuning Knobs):
   ```gdscript
   const BASE_BOSS_HP := 500
   const BASE_COMPRESSION_SPEED := 32.0   # px/s
   const COMPRESSION_DAMAGE_RATE := 5.0    # hp/s
   const MIN_ATTACK_INTERVAL := 1.5        # s
   const MERCY_ZONE := 100.0               # px
   const RESCUE_SLOWDOWN := 0.5
   const RESCUE_SUSPENSION := 2.0          # s
   const PHASE_2_THRESHOLD := 0.60
   const PHASE_3_THRESHOLD := 0.30
   ```

3. **BossState enum**:
   ```gdscript
   enum BossState { IDLE, ATTACKING, HURT, PHASE_CHANGE, DEFEATED }
   ```

4. **Member variables**:
   ```gdscript
   var _boss_state: BossState = BossState.IDLE
   var _boss_hp: int = BASE_BOSS_HP
   var _boss_max_hp: int = BASE_BOSS_HP
   var _current_phase: int = 1
   var _compression_wall_x: float = 0.0
   var _attack_cooldown: float = 0.0
   var _rescue_suspension_timer: float = 0.0
   var _players_behind: bool = false
   ```

5. **Output signals** (broadcast to Events):
   ```gdscript
   signal boss_attack_started(attack_pattern: String)
   signal boss_phase_changed(new_phase: int)
   signal boss_phase_warning(phase: int)
   signal boss_attack_telegraph(pattern: String)
   ```

6. **_ready()**: Connect Events signals (combo_hit, player_downed, crisis_state_changed, boss_defeated)

7. **Helper methods** (stubs for now, implemented in later stories):
   - `_is_player_down(player_id: int) -> bool`
   - `_is_crisis_active() -> bool`
   - `_get_nearest_player_position() -> Vector2`

8. **Query methods**:
   - `get_boss_state() -> String`
   - `get_current_phase() -> int`

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| Events Autoload (ADR-ARCH-001) | story-001 (implicit) | Must exist before BossAIManager connects to it |
| CoopSystem (ADR-ARCH-005) | story-001 (implicit) | _is_player_down / _is_crisis_active query CoopManager |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | BossAIManager is registered as Autoload in project.godot | Inspection |
| AC-02 | All 8 constants are defined with correct values from GDD | Unit test |
| AC-03 | BossState enum has all 5 states: IDLE, ATTACKING, HURT, PHASE_CHANGE, DEFEATED | Unit test |
| AC-04 | _ready() connects to Events.combo_hit, Events.player_downed, Events.crisis_state_changed, Events.boss_defeated | Integration test or inspection |
| AC-05 | get_boss_state() returns "IDLE" on init | Unit test |
| AC-06 | get_current_phase() returns 1 on init | Unit test |
| AC-07 | All member variables initialized to correct default values | Unit test |

---

## Estimated Effort

- **Expected**: 1 day
- **Optimistic**: 0.5 days
- **Pessimistic**: 1.5 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Create |
| `project.godot` | Modify (autoload registration) |

---

## Notes

- This story creates stubs for methods that will be fully implemented in later stories
- Query methods (_is_player_down, _is_crisis_active) return false/null for now — real implementation comes in story 007
