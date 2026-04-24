# Story: Crisis Edge Glow Effect

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-006
**Priority**: should-have
**Estimate**: 1 day
**Dependencies**: story-001 (UI State Machine), story-002 (Player HP Bars)

---

## Overview

Implement the CRISIS visual effect: when both players are below 30% HP, an ominous red edge glow pulses around the screen (via a full-screen CanvasLayer). The glow pulses at 1Hz synchronized between both players' danger states. Intensity increases as combined HP drops.

---

## Player Fantasy

The screen bleeds red. Both players are on the edge of death. The world itself seems to darken and pulse with urgency. This is CRISIS — the visual language of "you are both one hit from death."

---

## Detailed Rules

### Crisis Edge Glow Visual Layout

```
[FULL SCREEN - CanvasLayer at highest priority]

         [RED EDGE GLOW]
    ╭──────────────────────────╮
    │▓▓▓▓                  ▓▓▓│
    │▓▓                    ▓▓│
    │▓▓    [GAMEPLAY]      ▓▓│
    │▓▓                    ▓▓│
    │▓▓▓▓                  ▓▓▓│
    ╰──────────────────────────╯

    Glow intensity: 0% → 100% based on combined HP%
```

### Components

| Component | Node Type | Notes |
|-----------|-----------|-------|
| Edge glow rect | ColorRect | Full-screen, thin border (50px) |
| Glow shader | ShaderMaterial | Radial vignette with red color |
| Pulse animation | Tween | 1Hz sine wave on opacity |
| Intensity tween | Tween | Interpolates based on combined HP% |

### Crisis Trigger Conditions

| Condition | State |
|-----------|-------|
| Both players HP < 30% | CRISIS ACTIVE |
| Either player HP >= 30% | CRISIS INACTIVE |
| Either player HP = 0 | CRISIS INACTIVE (handled by rescue timer) |

### Glow Behavior

- **Base opacity**: 0.3 (30% red at screen edges)
- **Pulse range**: Opacity oscillates 0.3 → 0.6 (1Hz sine wave)
- **Intensity scaling**: At 30% combined HP, opacity base = 0.3; at 0% combined HP, opacity base = 0.6
- **Shader**: Radial vignette — strongest at edges, transparent at center

### Intensity Formula

```
combined_hp_percent = (p1_hp / p1_max + p2_hp / p2_max) / 2.0
intensity = clamp(1.0 - combined_hp_percent, 0.0, 1.0)  # 0 at 100% combined, 1 at 0%
base_opacity = lerp(0.3, 0.6, intensity)
pulse_opacity = base_opacity + sin(time * PI * 2) * 0.15
```

---

## Edge Cases

- **Player rescued from downed**: If rescued player returns above 30%, crisis deactivates
- **One player dead, one critical**: Crisis inactive (dead player doesn't count)
- **Boss defeated during crisis**: Crisis immediately deactivates
- **Transition out of crisis**: Glow fades out over 500ms, not instant

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Glow appears when both players drop below 30% | Dual-critical HP test |
| AC2 | Glow disappears when either player rises above 30% | Heal one player test |
| AC3 | Pulse rate is 1Hz (±0.1Hz tolerance) | Frame-count test |
| AC4 | Glow intensity increases as combined HP decreases | Visual at various HP% |
| AC5 | Glow is red with radial vignette (strongest at edges) | Visual inspection |
| AC6 | Fade out over 500ms when exiting crisis | Frame-advance test |
| AC7 | Dead players excluded from crisis calculation | One-dead-one-critical test |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | Glow layer integration |
| story-002 (Player HP Bars) | Required | HP data source |
| Events.player_hp_changed signal | Required | Detect crisis threshold |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| CRISIS_THRESHOLD | 0.30 | 0.20-0.40 | HP% trigger |
| PULSE_FREQUENCY | 1.0 | 0.5-2.0Hz | Pulse rate |
| MIN_OPACITY | 0.3 | 0.2-0.4 | Lowest glow opacity |
| MAX_OPACITY | 0.6 | 0.4-0.8 | Highest glow opacity |
| FADE_DURATION_MS | 500 | 300-1000ms | Exit fade time |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_crisis_intensity.gd` | Intensity formula |
| Integration test | `tests/integration/ui/test_crisis_signals.gd` | Threshold trigger |

---

## Files to Implement

- `src/ui/components/crisis_glow.gd` — Crisis edge glow with pulse shader
- `src/ui/ui.tscn` — Add crisis CanvasLayer at highest priority

---

**Status**: done
