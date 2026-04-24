# Story: Player HP Bars with Smooth Interpolation

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-002
**Priority**: must-have (critical path)
**Estimate**: 1.5 days
**Dependencies**: story-001 (UI State Machine), Events autoload (ADR-ARCH-001)

---

## Overview

Implement player HP bars in GAMEPLAY_HUD that smoothly interpolate toward actual HP values (lerp), display percentage, and show damage flash on hit. Two player bars (P1 left, P2 right) display alongside their current HP values.

---

## Player Fantasy

HP bars feel weighty. When taking damage, the bar doesn't jump — it drains smoothly, giving players a visceral sense of how hurt they are. The number ticks down in sync with the bar. Both bars update independently without stutter.

---

## Detailed Rules

### HP Bar Visual Layout

```
[P1_HP_BAR]                    [P2_HP_BAR]
[Hearth Icon][===BAR===][===BAR===][HP: 85/100]
```

- P1 HP bar: Left side of HUD, ProgressBar node
- P2 HP bar: Right side of HUD, ProgressBar node (mirrored layout)
- Bar fills left-to-right (P1) and right-to-left (P2) for symmetry

### HP Bar Components

| Component | Node Type | Notes |
|-----------|-----------|-------|
| HP bar background | TextureRect | Dark track image |
| HP bar fill | TextureProgressBar | Green-to-red gradient based on % |
| HP icon | TextureRect | Heart or character silhouette |
| HP text label | Label | "HP: {current}/{max}" |
| Damage flash | ColorRect | White flash on damage, fades in 150ms |

### Interpolation Behavior

- `lerp_speed`: 8.0 (lerp factor per second toward target)
- HP bar `value` lerps toward `actual_hp` each frame in `_process(delta)`
- Display HP text updates when `actual_hp` changes (not every frame)
- Lerp stops when bar reaches actual HP (no overshoot)

### Damage Flash

- Trigger: `Events.player_damaged` signal with `{player_id, damage}`
- Flash color: `Color(1.0, 1.0, 1.0, 0.4)` (40% white)
- Flash duration: 150ms, fade out via `_process()`
- Flash blocks lerp briefly (50ms) to prevent visual desync

### HP Color Gradient

| HP % | Fill Color | Notes |
|------|------------|-------|
| 100-60% | Green `#4ADE80` | Healthy |
| 59-30% | Yellow `#FACC15` | Wounded |
| 29-0% | Red `#EF4444` | Critical |

---

## Formulas

```
# Lerp equation (applied each frame)
display_hp = lerp(display_hp, actual_hp, lerp_speed * delta)
display_hp = clamp(display_hp, 0, actual_max_hp)

# HP percentage for color
hp_percent = actual_hp / actual_max_hp

# HP text format
hp_text = "HP: {floor(actual_hp)}/{actual_max_hp}"
```

---

## Edge Cases

- **HP overflow**: If heal exceeds max, clamp to max
- **HP exactly 0**: Show 0, not -1 or floating point artifact
- **Lerp overshoot**: Clamp display_hp so it never goes below 0 or above actual_hp
- **Multiple rapid hits**: Each damage flash queues; don't reset flash on new damage during fade
- **Boss fight start**: HP bars reset to full before BOSS_INTRO

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | P1 and P2 HP bars display simultaneously | Visual screenshot |
| AC2 | HP bar value lerps smoothly over ~0.5s for 50 damage hit | Visual observation |
| AC3 | HP text updates to floor(actual_hp) value | Text inspection |
| AC4 | Bar color transitions through green → yellow → red | Visual at various HP% |
| AC5 | Damage flash visible for 150ms on hit | Frame-advance test |
| AC6 | Lerp stops exactly at actual HP (no overshoot) | Unit test |
| AC7 | Both bars update independently (P1 damage doesn't affect P2) | Visual test |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | Cannot add to HUD without state machine |
| Events.player_damaged signal | Required | Cannot trigger flash |
| Events.player_healed signal | Required | Cannot trigger heal animation |
| Events.player_hp_changed signal | Required | HP bar display updates |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| HP_LERP_SPEED | 8.0 | 4.0-16.0 | Interpolation rate |
| DAMAGE_FLASH_DURATION_MS | 150 | 100-300ms | Flash fade time |
| HP_FLASH_BLOCK_MS | 50 | 0-100ms | Lerp pause on damage |
| CRITICAL_HP_THRESHOLD | 0.30 | 0.20-0.40 | Yellow→Red transition |
| WARN_HP_THRESHOLD | 0.60 | 0.50-0.70 | Green→Yellow transition |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_hp_bar_lerp.gd` | Lerp formula, edge cases |
| Integration test | `tests/integration/ui/test_hp_bar_signals.gd` | Signal response, flash timing |

---

## Files to Implement

- `src/ui/components/hp_bar.gd` — Reusable HP bar component with lerp + flash
- `src/ui/screens/hud_screen.gd` — (already in story-001) — add HP bar nodes

---

**Status**: done
