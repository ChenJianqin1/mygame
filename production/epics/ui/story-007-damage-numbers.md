# Story: Damage Number Popup System

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-007
**Priority**: should-have
**Estimate**: 1.5 days
**Dependencies**: story-001 (UI State Machine), Combat system (ADR-ARCH-003)

---

## Overview

Implement floating damage number popups that appear at the point of impact when players or the boss take damage. Numbers drift upward, scale by damage magnitude, and color-code by damage type (white for normal, yellow for crits, red for boss damage).

---

## Player Fantasy

Every hit lands with visual punctuation. The damage number shoots out from the impact point, climbing into the air before fading. Crits feel special — bigger, yellow, and bolder. The screen fills with numbers during big combos.

---

## Detailed Rules

### Damage Number Visual Behavior

```
[Impact at (x, y)]
       ↑
    [DMG: 47]   ← Floats upward over 800ms
       ↑
    [FADE OUT]
```

### Components

| Component | Node Type | Notes |
|-----------|-----------|-------|
| Damage label | Label | "DMG: {amount}" |
| Float tween | Tween | Drifts upward 60px over 800ms |
| Scale tween | Tween | Shrinks from 1.2x to 0.8x over lifetime |
| Fade tween | Tween | Opacity 1.0 → 0.0 over final 200ms |
| Spawn anchor | Node2D | Positioned at damage impact point |

### Damage Number Types

| Type | Trigger | Color | Size | Notes |
|------|---------|-------|------|-------|
| Normal | Standard hit | White `#FFFFFF` | 1.0x | Standard damage |
| Crit | Critical hit (roll) | Yellow `#FACC15` | 1.5x | +50% size, bold |
| Boss | Damage to boss | Orange `#FB923C` | 1.2x | Distinguishable from player |
| Heal | Player heals | Green `#4ADE80` | 1.0x | Shows +HP |

### Spawn Rules

- Numbers spawn at the center of the hurtbox that was hit
- Spawn offset: 20px above impact point
- For boss damage: spawn slightly above boss sprite center
- Max concurrent damage numbers: 20 (pool recycled FIFO)
- Numbers do not overlap — spawn positions jitter ±10px horizontally

### Animation Timeline (per number)

| Time | Event |
|------|-------|
| 0ms | Spawn at impact, scale 1.2x, opacity 1.0 |
| 0-600ms | Drift upward 60px, scale lerp to 1.0x |
| 600-800ms | Fade opacity 1.0 → 0.0, scale to 0.8x |
| 800ms | Return to pool |

---

## Formulas

```
# Scale based on damage magnitude
base_scale = 1.0
if damage >= 50: base_scale = 1.2
if damage >= 100: base_scale = 1.4
if crit: base_scale *= 1.5

# Vertical drift
y_offset = -60 * (elapsed / duration)

# Scale over lifetime
scale = lerp(1.2, 0.8, elapsed / duration)

# Opacity over final portion
if elapsed > duration - fade_duration:
    opacity = 1.0 - ((elapsed - (duration - fade_duration)) / fade_duration)
else:
    opacity = 1.0
```

---

## Edge Cases

- **Damage number overflow**: If >20 concurrent numbers, recycle oldest (FIFO)
- **Zero damage**: Do not spawn (blocked hits, invuln frames)
- **Negative damage (heal)**: Show "+{abs(damage)}" in green
- **Very large damage (999+)**: Cap display at 999
- **Player takes damage while number still visible**: Spawn new number (don't conflict)
- **Boss defeated**: Clear all pending damage numbers immediately

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Damage number spawns at hurtbox center | Visual at various hit locations |
| AC2 | Number drifts upward over 800ms | Frame-advance test |
| AC3 | Crits display yellow and 1.5x larger | Crit trigger test |
| AC4 | Boss damage displays orange | Boss hit test |
| AC5 | Heals display green with + prefix | Heal trigger test |
| AC6 | Numbers fade out over final 200ms | Frame-advance test |
| AC7 | Max 20 concurrent numbers (pool limit) | Stress test with high combo |
| AC8 | Numbers do not visually overlap | Visual inspection at high density |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | HUD integration |
| Events.damage_dealt signal | Required | Trigger spawn |
| Events.player_damaged signal | Required | Player damage numbers |
| Events.boss_damaged signal | Required | Boss damage numbers |
| Events.player_healed signal | Required | Heal numbers |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| DAMAGE_FLOAT_DURATION_MS | 800 | 600-1200ms | Float time |
| DAMAGE_FADE_START_MS | 600 | 400-800ms | When fade begins |
| DAMAGE_FLOAT_DISTANCE | 60 | 40-100px | Vertical drift |
| MAX_CONCURRENT_NUMBERS | 20 | 10-30 | Pool size |
| CRIT_SIZE_MULTIPLIER | 1.5 | 1.2-2.0 | Crit size boost |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_damage_number_formulas.gd` | Animation math, scale logic |
| Integration test | `tests/integration/ui/test_damage_number_pool.gd` | Pool recycling, max limit |

---

## Files to Implement

- `src/ui/components/damage_number.gd` — Single damage number with animation
- `src/ui/components/damage_number_pool.gd` — Object pool for damage numbers
- `src/ui/screens/hud_screen.gd` — (already in story-001) — add pool to HUD

---

**Status**: done
