# Story: Rescue and Crisis Modulation

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Implement the context awareness module that detects player rescue state, crisis state, and player-behind conditions to modulate compression speed.

---

## Task Description

Implement the救援/危机/落后检测 logic that powers compression speed modulation. This makes the "deadline pushes you but gives you breathing room when you're down" feeling work.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **CoopManager queries** (stubs from story-001, now implemented):
   ```gdscript
   func _is_player_down(player_id: int) -> bool:
       # Query CoopManager for player state
       # CoopManager.is_player_down(player_id)
       return false  # stub until CoopManager exists

   func _is_crisis_active() -> bool:
       # Query CoopManager for crisis state
       # CoopManager.is_in_crisis()
       return false  # stub until CoopManager exists
   ```

2. **Player behind detection**:
   ```gdscript
   func _is_player_behind(player_id: int) -> bool:
       var player_pos := _get_player_position(player_id)
       return player_pos.x < _compression_wall_x + MERCY_ZONE

   func _get_player_position(player_id: int) -> Vector2:
       match player_id:
           1: return _player1_pos
           2: return _player2_pos
       return Vector2.ZERO
   ```

3. **Update player behind flag**:
   ```gdscript
   func _update_players_behind_status() -> void:
       _players_behind = _is_player_behind(1) or _is_player_behind(2)
   ```

4. **Call update in _process**:
   ```gdscript
   func _process(delta: float) -> void:
       # ... existing compression, cooldown, rescue timer updates ...
       _update_players_behind_status()
   ```

5. **Rescue mode detection**:
   ```gdscript
   func _is_in_rescue_mode() -> bool:
       return _is_player_down(1) or _is_player_down(2)
   ```

6. **_calculate_compression_speed() integration**:
   The compression speed formula from story-003 now uses these helpers:
   ```gdscript
   func _calculate_compression_speed() -> float:
       var base: float = BASE_COMPRESSION_SPEED
       var phase_mult: float = 1.0 if _current_phase == 1 else 1.5 if _current_phase == 2 else 2.0
       var rescue_mult: float = 1.0
       var crisis_mult: float = 1.0

       if _is_in_rescue_mode():
           rescue_mult = RESCUE_SLOWDOWN  # 0.5
       elif _players_behind:
           rescue_mult = 0.6
       elif _is_crisis_active():
           crisis_mult = 1.2

       return base * phase_mult * rescue_mult * crisis_mult
   ```

7. **Edge case: Both players downed**:
   Per GDD Edge Case 2: "Both players downed simultaneously — no rescue possible — triggers game over"
   ```gdscript
   func _check_game_over_condition() -> void:
       if _is_player_down(1) and _is_player_down(2):
           Events.game_over.trigger()  # or similar signal
   ```

8. **Player position update from signals**:
   ```gdscript
   func _on_player_detected(player: Node2D) -> void:
       # Update position tracking based on player node
       # This is called from CollisionManager direct signal
       if player.get_instance_id() == _player1_node_id:
           _player1_pos = player.global_position
       elif player.get_instance_id() == _player2_node_id:
           _player2_pos = player.global_position
   ```

   Add to member variables:
   ```gdscript
   var _player1_node_id: int = -1
   var _player2_node_id: int = -1
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | Helper method stubs |
| Compression wall | story-003 | _calculate_compression_speed uses these helpers |
| Signal integration | story-006 | player_detected signal updates positions |
| CoopSystem (ADR-ARCH-005) | CoopSystem story | _is_player_down, _is_crisis_active query real CoopManager |

**Note**: CoopSystem may not be implemented yet. This story should use CoopManager stubs that return safe defaults (false) until CoopSystem is implemented.

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | _is_in_rescue_mode() returns true when P1 is down | Unit test |
| AC-02 | _is_in_rescue_mode() returns true when P2 is down | Unit test |
| AC-03 | _is_crisis_active() returns false (stub) | Unit test |
| AC-04 | _is_player_behind() returns true when player.x < wall_x + 100 | Unit test |
| AC-05 | _is_player_behind() returns false when player ahead | Unit test |
| AC-06 | _players_behind flag updates every frame | Unit test |
| AC-07 | Rescue mode: compression_speed *= 0.5 | Unit test |
| AC-08 | Player behind: compression_speed *= 0.6 | Unit test |
| AC-09 | Crisis active: compression_speed *= 1.2 | Unit test |
| AC-10 | Both players down: game_over signal triggered | Integration test |

---

## Estimated Effort

- **Expected**: 1 day
- **Optimistic**: 0.5 days
- **Pessimistic**: 1.5 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add rescue/crisis logic) |

---

## Notes

- CoopManager stubs return false until real CoopSystem is implemented
- This allows Boss AI to be tested independently of CoopSystem
- When CoopSystem is implemented, only _is_player_down() and _is_crisis_active() need to query the real system
