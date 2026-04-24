# Story: Rescue Timer Radial Countdown

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-005
**Priority**: must-have (critical path)
**Estimate**: 1.5 days
**Dependencies**: story-001 (UI State Machine), Coop system (ADR-ARCH-005)

---

## Overview

Implement the rescue timer: a radial countdown circle displayed when one player is downed. The circle depletes clockwise over the rescue window duration (default 10s). If timer expires before rescue, downed player dies permanently.

---

## Player Fantasy

Time bleeds away in a circular clock. Every second feels precious. The radial timer pulses urgently as it nears zero, then — if rescue fails — the downed player's ghost fades away. The UI makes the stakes visceral.

---

## Detailed Rules

### Rescue Timer Visual Layout

```
[PLAYER 2 DOWNED]
     [RADIAL TIMER]
    ╭──────────────╮
    │    ╲    ╱   │
    │      ◯      │  ← Radial depletes clockwise
    │    ╱    ╲   │
    ╰──────────────╯
    [TIME: 7.2s]
```

### Components

| Component | Node Type | Notes |
|-----------|-----------|-------|
| Downed player label | Label | "PLAYER {n} DOWNED" |
| Radial timer background | TextureRect | Dark circular track |
| Radial timer fill | TextureProgressBar (radial) | Depleting fill |
| Time remaining label | Label | "TIME: {seconds}s" |
| Pulse animation | AnimationPlayer | Speeds up as timer runs low |
| Death warning flash | ColorRect | Red flash at 2s remaining |

### Radial Timer Behavior

- Fill depletes clockwise from 100% to 0%
- Duration: 10 seconds (configurable)
- Timer pauses when rescue is triggered (player overlaps downed player hitbox)
- Timer resumes if rescue is interrupted

### Visual Urgency Escalation

| Time Remaining | Visual Effect |
|----------------|---------------|
| 10s - 5s | Normal fill, no pulse |
| 5s - 2s | Fill color shifts yellow, gentle pulse |
| 2s - 0s | Fill color shifts red, rapid pulse, red vignette flash |

### Rescue Interaction

- When rescuer overlaps downed player: `Events.rescue_started` fires
- Timer pauses at current value
- If rescue completes: `Events.rescue_completed` fires, timer hides
- If rescue interrupted (rescuer takes damage): timer resumes from paused value

---

## Formulas

```
# Radial fill percentage
fill_percent = (time_remaining / rescue_duration) * 100.0

# Timer label (one decimal place)
time_text = "TIME: {time_remaining:.1f}s"

# Pulse frequency (interpolates from 1Hz to 4Hz as time runs out)
pulse_freq = lerp(1.0, 4.0, 1.0 - (time_remaining / rescue_duration))
```

---

## Edge Cases

- **Both players downed simultaneously**: Show two rescue timers (stacked vertically)
- **Rescue timer at 0**: Downed player dies permanently, `Events.player_died_permanently` fires
- **Boss defeat while timer active**: Stop all timers, clear downed states
- **Player gets interrupted mid-rescue**: Timer resumes, not resets
- **Timer exactly at 0**: Round up to 0.0, trigger death immediately

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Radial timer appears when player is downed | Trigger downed state |
| AC2 | Timer depletes from 100% to 0% over 10 seconds | Frame-advance test |
| AC3 | Timer pauses when rescue overlap begins | Visual test |
| AC4 | Timer resumes if rescue interrupted | Visual test |
| AC5 | Pulse animation speeds up as time decreases | Visual observation |
| AC6 | Red flash at 2s remaining | Frame-advance test |
| AC7 | Timer hidden on rescue complete | Visual test |
| AC8 | Both downed players show separate timers | Dual-downed test |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | Timer belongs in HUD |
| Events.player_downed signal | Required | Show timer |
| Events.rescue_started signal | Required | Pause timer |
| Events.rescue_completed signal | Required | Hide timer |
| Events.player_died_permanently signal | Required | Trigger death |
| Coop system (ADR-ARCH-005) | Required | Logic source |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| RESCUE_DURATION | 10.0 | 5.0-15.0s | Full timer duration |
| WARN_THRESHOLD | 5.0 | 3.0-8.0s | Yellow pulse trigger |
| CRITICAL_THRESHOLD | 2.0 | 1.0-4.0s | Red pulse trigger |
| PULSE_MIN_FREQ | 1.0 | 0.5-2.0Hz | Normal pulse rate |
| PULSE_MAX_FREQ | 4.0 | 2.0-8.0Hz | Max pulse rate |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_rescue_timer.gd` | Depletion formula, edge cases |
| Integration test | `tests/integration/ui/test_rescue_timer_signals.gd` | Signal → pause/resume |

---

## Files to Implement

- `src/ui/components/rescue_timer.gd` — Radial countdown timer with pulse
- `src/ui/screens/hud_screen.gd` — (already in story-001) — add rescue timer nodes

---

**Status**: done
