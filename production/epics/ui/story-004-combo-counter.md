# Story: Combo Counter with Tier Scaling

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-004
**Priority**: must-have (critical path)
**Estimate**: 1.5 days
**Dependencies**: story-001 (UI State Machine), Combo system (ADR-ARCH-004)

---

## Overview

Implement the combo counter display in GAMEPLAY_HUD. The counter shows current combo hit count, multiplier tier (1.0x/1.15x/1.30x/1.50x), and tier name. The counter scales in size at higher tiers and shakes on reset. Updates via `Events.combo_*` signals.

---

## Player Fantasy

The combo counter is a badge of honor. As the count climbs, the counter grows larger and more menacing. Tier names ("FURY!", "BLOODSHED!") flash on screen. When the combo breaks, the counter shatters visually — a dramatic punctuation that makes players hunger for the next streak.

---

## Detailed Rules

### Combo Counter Visual Layout

```
[FURY!]           [COMBO: 24]
[1.30x]           [██████████]
                  [Combo tier bar]
```

### Components

| Component | Node Type | Notes |
|-----------|-----------|-------|
| Combo count label | Label (large) | "COMBO: {count}" |
| Multiplier tier label | Label (medium) | "1.30x" |
| Tier name label | Label (bold) | "FURY!" |
| Tier progress bar | ProgressBar | Shows progress to next tier |
| Shake anchor | Node2D | Parent for shake animation |
| Scale anchor | Node2D | Parent for tier-based scaling |

### Tier Definitions

| Tier | Multiplier | Combo Count | Label Color | Scale |
|------|-----------|-------------|-------------|-------|
| Normal | 1.00x | 0-9 | White | 1.0x |
| FURY | 1.15x | 10-24 | Orange `#FB923C` | 1.1x |
| CARNAGE | 1.30x | 25-49 | Red `#EF4444` | 1.2x |
| BLOODSHED | 1.50x | 50+ | Dark Red `#991B1B` + glow | 1.3x |

### Tier Transition Animation

- On tier up: Counter pulses (scale to 1.2x, back to tier scale) over 300ms
- On combo reset: Counter shakes (position jitter ±5px) over 200ms, then fades to 0 briefly
- Tier name label flashes for 500ms on transition

### Tier Progress Bar

- Shows progress toward next tier (not percentage — actual hit count within tier)
- Example: At combo 17, tier is FURY (10-24), progress bar shows 7/15 (count between tier start and end)

---

## Formulas

```
# Tier calculation
if combo < 10: tier = NORMAL
elif combo < 25: tier = FURY
elif combo < 50: tier = CARNAGE
else: tier = BLOODSHED

# Multiplier from tier
multiplier = {NORMAL: 1.00, FURY: 1.15, CARNAGE: 1.30, BLOODSHED: 1.50}[tier]

# Progress within tier
tier_progress = (combo - tier_start) / (tier_end - tier_start)
tier_progress = clamp(tier_progress, 0.0, 1.0)

# Scale from tier
scale = {NORMAL: 1.0, FURY: 1.1, CARNAGE: 1.2, BLOODSHED: 1.3}[tier]
```

---

## Edge Cases

- **Combo starts at 0**: Counter hidden until first hit
- **Combo reset to 0**: Animate out (shake + fade), hide after 500ms
- **Tier down**: Not possible — tiers only go up within a combo
- **Max combo (999)**: Cap display at 999, multiplier stays at 1.50x
- **Simultaneous P1+P2 hits**: Both register; combo counter increments by 2

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Counter displays combo count starting at first hit | Visual test |
| AC2 | Multiplier updates to correct tier at thresholds (10, 25, 50) | Frame-advance test |
| AC3 | Counter scales larger at higher tiers (1.0x → 1.3x) | Visual measurement |
| AC4 | Tier name label flashes for 500ms on tier change | Frame-advance test |
| AC5 | Progress bar shows within-tier progress correctly | Visual inspection |
| AC6 | Shake + fade animation plays on combo reset | Visual observation |
| AC7 | Counter hidden when combo = 0 | Visual inspection |
| AC8 | Both P1+P2 hits update counter correctly | Integration test |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | Counter belongs in HUD |
| Events.combo_hit signal | Required | Counter increment |
| Events.combo_ended signal | Required | Reset animation |
| Events.combo_tier_changed signal | Required | Tier transitions |
| Combo system (ADR-ARCH-004) | Required | Logic source |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| TIER_FURY_THRESHOLD | 10 | 8-15 | Tier 2 trigger |
| TIER_CARNAGE_THRESHOLD | 25 | 20-35 | Tier 3 trigger |
| TIER_BLOODSHED_THRESHOLD | 50 | 40-70 | Tier 4 trigger |
| TIER_FLASH_DURATION_MS | 500 | 300-800ms | Tier name flash |
| RESET_SHAKE_DURATION_MS | 200 | 150-400ms | Reset animation |
| RESET_FADE_DURATION_MS | 500 | 300-800ms | Counter hide |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_combo_tier_calc.gd` | Tier logic, threshold edge cases |
| Unit test | `tests/unit/ui/test_combo_progress_bar.gd` | Progress calculation |
| Integration test | `tests/integration/ui/test_combo_signals.gd` | Signal → display update |

---

## Files to Implement

- `src/ui/components/combo_counter.gd` — Combo counter with tier scaling and animations
- `src/ui/screens/hud_screen.gd` — (already in story-001) — add combo counter nodes

---

**Status**: done
