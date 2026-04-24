# Story: Compression Wall (Continuous Process)

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Implement the compression wall as a continuous parallel process that advances every frame, applies damage to players in the danger zone, and modulates speed based on game state.

---

## Task Description

Implement the compression wall mechanism — the defining mechanic of the Boss AI that creates the "pushed by deadline" feeling.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **_process(delta) integration**:
   - Call `_update_compression(delta)` every frame
   - Call `_update_attack_cooldown(delta)` every frame
   - Call `_update_rescue_suspension(delta)` every frame
   - Call `_update_hurt_timer(delta)` if in HURT state

2. **_update_compression(delta: float) method**:
   ```gdscript
   func _update_compression(delta: float) -> void:
       if _boss_state == BossState.DEFEATED or _boss_state == BossState.PHASE_CHANGE:
           return

       var speed: float = _calculate_compression_speed()
       _compression_wall_x += speed * delta

       # Apply damage to players in danger zone
       _apply_compression_damage(delta)
   ```

3. **_calculate_compression_speed() -> float**:
   Implement the modulation rules from GDD Rule 4:
   ```
   Every frame:
     if P1_or_P2_downed:
       compression_speed = base * 0.5  # rescue window
     elif P1_behind OR P2_behind:
       compression_speed = base * 0.6  # 40% slower
     elif both_in_CRISIS:
       compression_speed = base * 1.2  # 20% faster
     else:
       compression_speed = base * phase_multiplier
   ```
   - base = BASE_COMPRESSION_SPEED (32px/s)
   - phase_multiplier = {1.0, 1.5, 2.0} for phases {1, 2, 3}

4. **_apply_compression_damage(delta: float) method**:
   - Check if each player is in danger zone (player.x < _compression_wall_x)
   - If player in danger zone: `damage = COMPRESSION_DAMAGE_RATE * delta`
   - Emit `Events.player_hurt(player, damage)` for each player in zone
   - Rate = 5hp/s per GDD

5. **_update_attack_cooldown(delta: float) method**:
   - Decrement _attack_cooldown if > 0
   - Never go below 0

6. **_update_rescue_suspension(delta: float) method**:
   - Decrement _rescue_suspension_timer if > 0
   - Never go below 0

7. **_update_hurt_timer(delta: float) method**:
   - If _boss_state == HURT:
     - Decrement _hurt_timer by delta
     - When reaches 0: transition to IDLE

8. **Query methods for compression state**:
   ```gdscript
   func get_compression_wall_x() -> float:
       return _compression_wall_x

   func is_player_in_danger_zone(player_pos: Vector2) -> bool:
       return player_pos.x < _compression_wall_x
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | Member variables, constants |
| Macro FSM states | story-002 | _boss_state checks |
| CoopSystem integration | story-007 | _is_player_down, _is_crisis_active queries |

**Note**: story-007 implements the CoopSystem queries. For this story, _is_player_down() returns false and _is_crisis_active() returns false by default.

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | Phase 1 compression_speed = 32 * 1.0 = 32px/s | Unit test |
| AC-02 | Phase 2 compression_speed = 32 * 1.5 = 48px/s | Unit test |
| AC-03 | Phase 3 compression_speed = 32 * 2.0 = 64px/s | Unit test |
| AC-04 | Player downed: compression_speed *= 0.5 | Unit test |
| AC-05 | Player behind MERCY_ZONE: compression_speed *= 0.6 | Unit test |
| AC-06 | Both players in CRISIS: compression_speed *= 1.2 | Unit test |
| AC-07 | Player in danger zone for 1s takes 5 damage | Unit test |
| AC-08 | DEFEATED state: compression does not advance | Unit test |
| AC-09 | PHASE_CHANGE state: compression does not advance | Unit test |
| AC-10 | get_compression_wall_x() returns current wall position | Unit test |
| AC-11 | is_player_in_danger_zone() returns true when player.x < wall_x | Unit test |

---

## Estimated Effort

- **Expected**: 1.5 days
- **Optimistic**: 1 day
- **Pessimistic**: 2 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add compression logic) |

---

## Notes

- Compression is a continuous process — it runs every frame regardless of boss state
- The only exceptions are DEFEATED and PHASE_CHANGE (compression pauses, not stops)
- _apply_compression_damage uses Events.player_hurt to notify other systems
