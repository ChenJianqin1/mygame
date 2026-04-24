# Story: UI Signal Integration & Event Wiring

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-008
**Priority**: must-have (critical path)
**Estimate**: 1 day
**Dependencies**: All other UI stories (story-001 through story-007)

---

## Overview

Wire all UI components to the Events signal bus. This story connects every UI element to the correct signal emitters from Combo, Coop, Combat, Boss AI, and Input systems. No UI component polls in `_process()` — all updates flow through the Events autoload.

---

## Player Fantasy

The UI is a reactive instrument. It responds instantly to every game event — a perfect puppet to the game's state. There is no lag between "boss takes damage" and "damage number appears." Everything is synchronized through the signal architecture.

---

## Detailed Rules

### Signal Wiring Map

| UI Component | Connected Signals | Callback |
|--------------|-----------------|----------|
| UIStateMachine | `game_started`, `game_paused`, `game_resumed`, `game_ended`, `return_to_title` | `_on_game_state_changed` |
| HP Bar (P1) | `player_hp_changed(1,*)`, `player_damaged(1,*)`, `player_healed(1,*)` | `_on_p1_hp_changed` |
| HP Bar (P2) | `player_hp_changed(2,*)`, `player_damaged(2,*)`, `player_healed(2,*)` | `_on_p2_hp_changed` |
| Boss HP Bar | `boss_spawned`, `boss_hp_changed`, `boss_phase_changed`, `boss_defeated` | `_on_boss_*` |
| Combo Counter | `combo_hit(*,*)`, `combo_ended`, `combo_tier_changed` | `_on_combo_*` |
| Rescue Timer | `player_downed(*)`, `rescue_started(*)`, `rescue_completed(*)`, `player_died_permanently(*)` | `_on_rescue_*` |
| Crisis Glow | `player_hp_changed(*,*)` | `_on_player_hp_critical_check` |
| Damage Numbers | `damage_dealt(*)`, `player_damaged(*)`, `boss_damaged(*)`, `player_healed(*)` | `_on_damage_*` |

### Signal Signature Reference

All signals defined in `Events` autoload (ADR-ARCH-001):

```
# Game state
game_started()
game_paused()
game_resumed()
game_ended()
return_to_title()

# Player state (player_id: 1 or 2)
player_hp_changed(player_id: int, current_hp: float, max_hp: float)
player_damaged(player_id: int, damage: float, source: String)
player_healed(player_id: int, amount: float)
player_downed(player_id: int)
player_died_permanently(player_id: int)

# Boss state
boss_spawned(boss_name: String, max_hp: float)
boss_hp_changed(current_hp: float)
boss_phase_changed(phase: int)
boss_defeated()

# Combo state (player_id: 1 or 2, hit_count: int)
combo_hit(player_id: int, hit_count: int)
combo_ended(player_id: int)
combo_tier_changed(player_id: int, tier: int, multiplier: float)

# Rescue state (player_id: int)
rescue_started(downed_player_id: int)
rescue_completed(downed_player_id: int)

# Damage numbers
damage_dealt(amount: float, position: Vector2, is_crit: bool, target: String)
```

### Connection Pattern

```gdscript
# Example: HP bar connection in _ready()
func _ready() -> void:
    Events.player_hp_changed.connect(_on_p1_hp_changed)
    Events.player_damaged.connect(_on_p1_damaged)
    Events.player_healed.connect(_on_p1_healed)

# All UI components must:
# 1. Connect in _ready()
# 2. Use single underscore prefix for callbacks (_on_*)
# 3. Disconnect in queue_free() via _exit_tree()
```

### No Polling Rule

All UI components follow the signal-driven pattern:
- **FORBIDDEN**: `get_node_or_null()` or direct state access in `_process()`
- **REQUIRED**: All state changes flow through Events signals
- **EXCEPTION**: HP bar lerp (story-002) interpolates display values in `_process()`, but source data comes from signals

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | All UI components connect to Events in `_ready()` | Code review |
| AC2 | All signal callbacks follow `_on_*` naming | Code review |
| AC3 | No UI component reads game state directly in `_process()` | Code review |
| AC4 | All 8 signal types listed above are connected | Signal trace test |
| AC5 | Components disconnect in `_exit_tree()` to prevent leaks | Memory test |
| AC6 | HP bar lerp is the only exception (display interpolation) | Code review |
| AC7 | Events signal documentation matches implementation | Doc vs code comparison |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | State machine wiring |
| story-002 (Player HP Bars) | Required | HP bar signals |
| story-003 (Boss HP Bar) | Required | Boss bar signals |
| story-004 (Combo Counter) | Required | Combo signals |
| story-005 (Rescue Timer) | Required | Rescue signals |
| story-006 (Crisis Glow) | Required | Crisis signals |
| story-007 (Damage Numbers) | Required | Damage signals |
| Events autoload (ADR-ARCH-001) | Required | Signal source |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Integration test | `tests/integration/ui/test_ui_signal_wiring.gd` | All signals connected |
| Integration test | `tests/integration/ui/test_signal_no_polling.gd` | No _process() polling |

---

## Files to Implement

- `src/ui/ui.tscn` — Final scene with all connections wired
- `src/ui/ui.gd` — Optional: root UI script that manages all child components

---

**Status**: done
