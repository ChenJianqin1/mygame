# Story: Signal Integration

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Integration
> **Status**: Done

---

## Overview

Integrate BossAIManager with CollisionManager (direct signals) and Events (broadcast signals) for low-latency AI perception and cross-system communication.

---

## Task Description

Wire up all signal connections between BossAIManager, CollisionManager, and the Events autoload.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **Direct signals from CollisionManager** (low latency):
   These are connected directly in CollisionManager initialization, not via Events.
   ```gdscript
   # In CollisionManager.gd, during _ready():
   BossAIManager.player_detected.connect(_on_boss_ai_player_detected)
   BossAIManager.player_lost.connect(_on_boss_ai_player_lost)
   BossAIManager.player_hurt.connect(_on_boss_ai_player_hurt)
   ```

   BossAIManager methods to connect:
   ```gdscript
   func notify_player_detected(player: Node2D) -> void:
       _on_player_detected(player)

   func notify_player_lost(player: Node2D) -> void:
       _on_player_lost(player)

   func notify_player_hurt(player: Node2D, damage: float) -> void:
       _on_player_hurt(player, damage)
   ```

2. **Events signal connections** (in BossAIManager._ready()):
   ```gdscript
   func _ready() -> void:
       Events.combo_hit.connect(_on_combo_hit)
       Events.player_downed.connect(_on_player_downed)
       Events.crisis_state_changed.connect(_on_crisis_state_changed)
       Events.boss_defeated.connect(_on_boss_defeated)
   ```

3. **Signal handlers** (implement stubs from story-001):
   ```gdscript
   func _on_player_detected(player: Node2D) -> void:
       # Track player position for attack selection
       # Update _players_behind flag
       pass

   func _on_player_lost(player: Node2D) -> void:
       # Stop tracking that player
       pass

   func _on_player_hurt(player: Node2D, damage: float) -> void:
       # AI aggression modulation based on player damage taken
       pass

   func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
       # AI can read combo count to adjust behavior
       # e.g., become more aggressive at high combos
       pass

   func _on_player_downed(player_id: int) -> void:
       _rescue_suspension_timer = RESCUE_SUSPENSION
       # Compression already slows via _calculate_compression_speed

   func _on_crisis_state_changed(is_crisis: bool) -> void:
       # Crisis affects compression speed via _calculate_compression_speed
       # Store crisis state for query
       pass

   func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
       force_defeated()
   ```

4. **Output signals** (BossAIManager → Events):
   ```gdscript
   func _emit_boss_signals() -> void:
       Events.boss_attack_started.emit(pattern)
       Events.boss_phase_changed.emit(new_phase)
   ```

5. **Player position tracking**:
   Add member variables:
   ```gdscript
   var _player1_pos: Vector2 = Vector2.ZERO
   var _player2_pos: Vector2 = Vector2.ZERO
   var _player1_id: int = -1
   var _player2_id: int = -1
   ```

6. **Player ID assignment**:
   ```gdscript
   func register_player(player_id: int, player_node: Node2D) -> void:
       if _player1_id == -1:
           _player1_id = player_id
           _player1_pos = player_node.global_position
       elif _player2_id == -1:
           _player2_id = player_id
           _player2_pos = player_node.global_position
   ```

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | Signal definitions, _ready() |
| Collision Detection (ADR-ARCH-002) | story-005 (collision) | Must configure direct signal routing |
| Events Autoload (ADR-ARCH-001) | story-001 (implicit) | Events signals must exist |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | CollisionManager connects to BossAIManager direct signals | Inspection |
| AC-02 | Events.combo_hit connects to _on_combo_hit | Unit test |
| AC-03 | Events.player_downed connects to _on_player_downed | Unit test |
| AC-04 | Events.crisis_state_changed connects to _on_crisis_state_changed | Unit test |
| AC-05 | Events.boss_defeated connects to _on_boss_defeated | Unit test |
| AC-06 | player_downed triggers rescue_suspension_timer = 2.0s | Unit test |
| AC-07 | boss_attack_started emits to Events | Integration test |
| AC-08 | boss_phase_changed emits to Events | Integration test |
| AC-09 | register_player() correctly assigns P1 and P2 | Unit test |
| AC-10 | Player position updated on player_detected signal | Integration test |

---

## Estimated Effort

- **Expected**: 1 day
- **Optimistic**: 0.5 days
- **Pessimistic**: 1.5 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add signal handlers) |
| `src/core/collision/collision_manager.gd` | Modify (add direct signal connections) |

---

## Notes

- Direct signals from CollisionManager are for low-latency AI perception
- Events broadcast is for UI, VFX, and other decoupled systems
- Player ID assignment is a simplification — actual player registration may come from CoopSystem
