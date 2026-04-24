# Story: UI State Machine Foundation

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-001
**Priority**: must-have (critical path)
**Estimate**: 2 days
**Dependencies**: Events autoload (ADR-ARCH-001), design/gdd/ui-system.md

---

## Overview

Implement the 5-state UI screen machine: TITLE → BOSS_INTRO → GAMEPLAY_HUD → PAUSED → GAME_OVER. All screen states render on independent CanvasLayer nodes (screen-space, unaffected by camera). Transitions are signal-driven via the Events bus — no polling in `_process()`.

---

## Player Fantasy

The UI appears instantly when needed and disappears cleanly. Screens don't stutter, pop, or lag behind the game state. Transitions feel snappy and intentional — a fighting game HUD, not a menu simulator.

---

## Detailed Rules

### Screen States

| State | Trigger | CanvasLayer Node |
|-------|---------|------------------|
| TITLE | Game launch / return to title | `UILayer/TITLE` |
| BOSS_INTRO | Boss spawn signal | `UILayer/BOSS_INTRO` |
| GAMEPLAY_HUD | After intro completes | `UILayer/HUD` |
| PAUSED | Pause input (P1 or P2) | `UILayer/PAUSED` |
| GAME_OVER | Both players dead OR boss defeated | `UILayer/GAME_OVER` |

### Transition Rules

- TITLE → BOSS_INTRO: Fires on `Events.game_started` or "Start Game" pressed
- BOSS_INTRO → GAMEPLAY_HUD: Fires on `Events.boss_intro_complete` (timer: 3s)
- GAMEPLAY_HUD → PAUSED: Fires on `Events.game_paused`
- PAUSED → GAMEPLAY_HUD: Fires on `Events.game_resumed`
- GAMEPLAY_HUD → GAME_OVER: Fires on `Events.game_ended`
- Any state → TITLE: Fires on `Events.return_to_title`

### Layer Priority (Z-index)

| Layer | Value | Notes |
|-------|-------|-------|
| GAMEPLAY_HUD | 0 | Base gameplay layer |
| BOSS_INTRO | 10 | Overlays HUD briefly |
| PAUSED | 20 | Darkened overlay |
| GAME_OVER | 30 | Topmost |
| TITLE | 40 | Full-screen, highest |

### State Machine Implementation

- Use a `UIStateMachine` node with enum `State { TITLE, BOSS_INTRO, GAMEPLAY_HUD, PAUSED, GAME_OVER }`
- `_current_state: State` tracks active state
- `_transition_to(new_state: State)` handles enter/exit logic per state
- No `match` statement for state — use dictionary of callables for `enter_STATE()` and `exit_STATE()`
- All transitions logged via `Events.ui_state_changed(state)` signal

---

## Formulas

```
# Layer priority formula
layer_value = BASE_HUD_LAYER + state_priority_offset[state]
```

| State | Offset |
|-------|--------|
| GAMEPLAY_HUD | 0 |
| BOSS_INTRO | 10 |
| PAUSED | 20 |
| GAME_OVER | 30 |
| TITLE | 40 |

---

## Edge Cases

- **Rapid pause/unpause**: Debounce pause input by 200ms to prevent flicker
- **BOSS_INTRO interrupted**: If player takes damage during intro, cancel intro and go to GAMEPLAY_HUD
- **Return to title during boss fight**: Clean up boss state before showing TITLE
- **Multiple pause signals**: Ignore pause if already paused; ignore resume if not paused

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | All 5 states exist as separate CanvasLayer nodes | Visual inspection |
| AC2 | Each state has `enter_STATE()` and `exit_STATE()` called correctly | Unit test or log inspection |
| AC3 | State transitions fire within 1 frame of trigger signal | Signal trace test |
| AC4 | Pause layer darkens (ColorRect at 50% black) behind pause menu | Visual screenshot |
| AC5 | No polling in `_process()` — all updates via signals | Code review |
| AC6 | Layer priorities stack correctly (TITLE always on top) | Visual screenshot during all states |
| AC7 | Pause debounce prevents double-trigger within 200ms | Integration test |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| Events autoload (ADR-ARCH-001) | Required | Cannot connect signals |
| design/gdd/ui-system.md | Read-only | Story must match GDD |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| PAUSE_DEBOUNCE_MS | 200 | 100-500ms | Input debounce |
| BOSS_INTRO_DURATION | 3.0 | 2.0-5.0s | Intro timer |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_ui_state_machine.gd` | State transitions, enter/exit logic |
| Integration test | `tests/integration/ui/test_ui_signals.gd` | Signal → state response |

---

## Files to Implement

- `src/ui/ui_state_machine.gd` — State machine controller
- `src/ui/screens/title_screen.gd` — Title screen logic
- `src/ui/screens/boss_intro_screen.gd` — Boss intro screen
- `src/ui/screens/hud_screen.gd` — Main gameplay HUD
- `src/ui/screens/pause_screen.gd` — Pause menu
- `src/ui/screens/game_over_screen.gd` — Game over screen
- `src/ui/ui.tscn` — Scene with all CanvasLayers

---

**Status**: done
