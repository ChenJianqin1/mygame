# Story: Combo Timer & Edge Cases

> **Type**: Logic
> **Epic**: Combo连击系统 (`production/epics/combo/EPIC.md`)
> **GDD**: `design/gdd/combo-system.md` (Rule 1, Rule 4, Edge Cases)
> **ADR**: ADR-ARCH-004
> **Status**: Done

## Overview

Implement the 1.5-second combo window timer and all edge cases: hitstop behavior, player death, boss phase changes, and display overflow. Combo only decays via time — damage taken, movement, and player death do NOT reset combo.

## Player Fantasy

**玩家幻想：** "别停！停1.5秒就断了。"

The combo window is generous enough to feel fair (1.5s) but tense enough to demand sustained pressure. Nothing feels worse than losing a big combo to an unlucky dodge.

## Detailed Rules

### Combo Window Timer

- **COMBO_WINDOW_DURATION**: 1.5 seconds
- Timer starts at 0.0s on first hit
- Each new hit resets timer to 0.0s
- If timer reaches 1.5s with no hit, combo_count resets to 0
- Timer is implemented in `ComboManager._process(delta)`

### Hitstop Behavior

- Hitstop is a **real-time freeze** — game timer does NOT advance
- Therefore timer does NOT extend during hitstop
- If timer was at 1.4s when hitstop started, it remains at 1.4s when hitstop ends

### What Does NOT Reset Combo

Per Rule 4 (time-only decay):
- Damage taken does NOT reset combo
- Movement does NOT reset combo
- Player death does NOT reset partner's combo
- Boss phase change does NOT reset combo
- Only: 1.5 consecutive seconds without a hit

### Display Overflow

- **MAX_COMBO_COUNT_DISPLAY**: 99
- Internal counter continues incrementing (no hard cap)
- Display shows "99+" after 99
- Multiplier formula uses actual count (not display cap)

## Formulas

**Combo Window Timer:**
```
combo_timer = clamp(time_since_last_hit, 0.0, COMBO_WINDOW_DURATION)
combo_resets = (combo_timer >= COMBO_WINDOW_DURATION)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| time_since_last_hit | float | 0.0–infinity | Seconds since last hit |
| COMBO_WINDOW_DURATION | float | 1.5 | Window before combo reset |
| combo_timer | float | 0.0–1.5 | Current timer position |
| combo_resets | bool | — | True when timer expires |

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Player dies mid-combo | That player's combo resets; partner's combo continues |
| Both players hit same frame | Both counts increment; both chains increment |
| Combo window expires during hitstop | Timer frozen; no reset occurs |
| combo_count = 99 | Display shows "99+"; internal count continues |
| Boss defeated mid-combo | combo_count persists across bosses |
| Only one player has active combo, partner hits sync | IDLE player gets sync multiplier, starts at count=1 |

## Dependencies

**Upstream:**
- Story 001: ComboData fields (combo_timer, combo_count)
- Combat system: combo_hit signal

**Downstream:**
- Story 005: combo_break signal emission
- UI system: displays combo count and timer

## Tuning Knobs

| Parameter | Default | Safe Range |
|-----------|---------|-----------|
| COMBO_WINDOW_DURATION | 1.5s | 0.5–3.0s |
| MAX_COMBO_COUNT_DISPLAY | 99 | 50–999 |

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-01 | Player IDLE, no combo | First hit lands | combo_count=1, timer=0, state=ACTIVE |
| AC-02 | combo_count=5, timer=0.5s | 0.5s passes with no hit | combo_count=0, state=IDLE |
| AC-03 | combo_count=5, timer=1.4s | New hit lands | timer resets to 0, combo_count=6 |
| AC-18 | P1 takes damage | P1 combo | Unchanged (time-only decay) |
| AC-19 | P1 dies | P2 combo | Unchanged |
| AC-21 | Boss defeated | Combo state | combo_count persists |
| AC-23 | combo_count=100 | Internal count | Continues incrementing (display caps at 99) |
| AC-24 | Hitstop (5 frames), timer=1.4s | Hitstop ends | Timer still 1.4s |
| AC-27 | combo_count resets | UI signal | combo_break(player_id) fires |

## Tasks

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|-------------------|
| 1 | Implement ComboManager._process() timer | — | 0.5 | Story 001 | Timer increments, resets combo when expired |
| 2 | Implement _on_combo_hit() to reset timer | — | 0.5 | Story 001 | Timer resets to 0 on each hit |
| 3 | Implement _reset_combo() method | — | 0.25 | Task 1 | Resets combo_count, fires combo_break signal |
| 4 | Write unit tests for timer logic | — | 0.5 | Tasks 1-3 | AC-01, AC-02, AC-03 pass |
| 5 | Write integration tests for edge cases | — | 0.5 | Tasks 1-4 | AC-18, AC-19, AC-21, AC-24, AC-27 pass |

## Definition of Done

- [x] Timer increments in `_process()` at correct rate
- [x] Timer resets to 0 on each hit
- [x] Combo resets when timer exceeds 1.5 seconds
- [x] Hitstop does not extend timer
- [x] Damage does not reset combo
- [x] Player death does not affect partner's combo
- [x] Boss phase change does not reset combo
- [x] combo_break signal fires on reset
- [x] All 9 timer/edge case acceptance criteria pass
