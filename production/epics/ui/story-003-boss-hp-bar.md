# Story: Boss HP Bar with Phase Color Transitions

**Epic**: UI System (`production/epics/ui/EPIC.md`)
**Story ID**: ui-003
**Priority**: must-have (critical path)
**Estimate**: 1 day
**Dependencies**: story-001 (UI State Machine), Boss AI system (ADR-ARCH-006)

---

## Overview

Implement a dedicated boss HP bar displayed at the top-center of GAMEPLAY_HUD. The bar shows boss phase (1/2/3) via color transitions: white at full HP, yellow at 60% (Phase 2), red at 30% (Phase 3). Includes boss name label and phase indicator.

---

## Player Fantasy

The boss HP bar is the heartbeat of an encounter. When the boss enters Phase 2, the bar shifts to an ominous yellow, signaling escalation. In Phase 3, it burns red — both players know they're in the final stretch. The bar feels monumental, not tacked-on.

---

## Detailed Rules

### Boss HP Bar Visual Layout

```
[Phase 1: WHITE BAR]  [Phase 2: YELLOW BAR]  [Phase 3: RED BAR]

         [BOSS_NAME_LABEL: "IGNIS, THE ETERNAL FLAME"]
         [============= HP BAR =============] [HP: 8500/10000]
         [Phase: 1]              [Phase: 2]              [Phase: 3]
```

### Components

| Component | Node Type | Notes |
|-----------|-----------|-------|
| Boss name label | Label | Top center, bold, white text |
| HP bar track | TextureRect | Dark metallic background |
| HP bar fill | TextureProgressBar | Phase-colored fill |
| HP text | Label | Below bar: "HP: {current}/{max}" |
| Phase indicator | Label | "Phase {n}" in top-right of bar |
| Phase pip markers | TextureRect | 3 small pips showing phase thresholds |

### Phase Color Transitions

| Phase | HP Threshold | Fill Color | Track Tint | Label Color |
|-------|-------------|------------|------------|-------------|
| Phase 1 | 100%-61% | White `#FFFFFF` | Gray `#6B7280` | White |
| Phase 2 | 60%-31% | Yellow `#FBBF24` | Orange `#D97706` | Yellow |
| Phase 3 | 30%-0% | Red `#EF4444` | Dark Red `#991B1B` | Red |

- Color transitions are instant at threshold (no lerp between phases)
- Bar width matches player HP bars (consistent visual weight)
- Boss HP bar is always visible during boss encounters, hidden otherwise

### Phase Display

- Three pip indicators at 60% and 30% positions on the bar track
- Active phase pip glows; inactive pips are dim
- "Phase X" label updates on transition via `Events.boss_phase_changed`

---

## Formulas

```
# Phase determination
phase = 1 if hp_percent > 0.60 else (2 if hp_percent > 0.30 else 3)

# HP text (same format as player bars)
hp_text = "HP: {floor(boss_current_hp)}/{boss_max_hp}"

# Bar fill direction (always left-to-right, even for boss)
```

---

## Edge Cases

- **Boss HP overflow**: Clamp to max
- **Boss HP exactly at threshold (60%, 30%)**: Round to Phase N+1 (e.g., exactly 60% → Phase 2)
- **Boss defeat during transition**: Immediately hide bar, trigger GAME_OVER or victory
- **Multiple bosses**: Show HP bar for primary boss only (ignore Adds/summons)
- **Phase skip**: If boss skips from Phase 1 to Phase 3 (enrage), update bar once

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Boss HP bar visible during boss encounter, hidden otherwise | Visual toggle test |
| AC2 | Bar fill color matches current phase (white/yellow/red) | Visual at 100%, 60%, 30% HP |
| AC3 | Phase pip at 60% and 30% glows when reached | Visual screenshot |
| AC4 | Boss name displays above bar | Visual inspection |
| AC5 | HP text updates in real-time with floor() precision | Text inspection |
| AC6 | Color transition is instant at threshold | Frame-advance test |
| AC7 | Phase label updates via signal, not polling | Signal trace test |

---

## Dependencies

| Dependency | Status | Impact if Delayed |
|-----------|--------|-------------------|
| story-001 (UI State Machine) | Required | Boss bar must integrate with HUD |
| Events.boss_hp_changed signal | Required | HP bar updates |
| Events.boss_phase_changed signal | Required | Phase transitions |
| Events.boss_spawned / boss_defeated | Required | Show/hide bar |

---

## Tuning Knobs

| Knob | Default | Range | Affects |
|------|---------|-------|---------|
| PHASE_2_THRESHOLD | 0.60 | 0.55-0.65 | Phase 2 trigger |
| PHASE_3_THRESHOLD | 0.30 | 0.25-0.35 | Phase 3 trigger |
| BOSS_BAR_WIDTH | 600px | 400-800px | Visual scale |

---

## Test Plan

| Test Type | Test File | Coverage |
|-----------|-----------|----------|
| Unit test | `tests/unit/ui/test_boss_hp_phase.gd` | Threshold logic, phase calculation |
| Integration test | `tests/integration/ui/test_boss_hp_signals.gd` | Signal → color change |

---

## Files to Implement

- `src/ui/components/boss_hp_bar.gd` — Boss HP bar with phase colors
- `src/ui/screens/hud_screen.gd` — (already in story-001) — add boss bar nodes

---

**Status**: done
