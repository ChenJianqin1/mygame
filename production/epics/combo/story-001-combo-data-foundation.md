# Story: Combo Data Foundation

> **Type**: Logic
> **Epic**: Combo连击系统 (`production/epics/combo/EPIC.md`)
> **GDD**: `design/gdd/combo-system.md`
> **ADR**: ADR-ARCH-004
> **Status**: Done
> **Code Review**: APPROVED (2 passes)
> **Manifest Version**: 2026-04-17
> **Completed**: 2026-04-23

## Overview

Implement the foundational data structures for the combo system: `ComboData` class (per-player state container) and `TierLogic` class (static tier calculation). These are the building blocks for all combo logic.

## Player Fantasy

N/A — this is a pure infrastructure story with no player-facing impact.

## Detailed Rules

### ComboData Class

```gdscript
class_name ComboData
extends RefCounted

var player_id: int
var combo_count: int = 0
var combo_timer: float = 0.0
var current_tier: int = 0
var sync_chain_length: int = 0
var last_hit_frame: int = -1

func reset() -> void:
    combo_count = 0
    combo_timer = 0.0
    current_tier = 0
    sync_chain_length = 0
    last_hit_frame = -1
```

### TierLogic Class

```gdscript
class_name TierLogic
extends RefCounted

const TIER_THRESHOLDS := {
    0: 0,    # IDLE
    1: 1,    # NORMAL (1-9)
    2: 10,   # RISING (10-19)
    3: 20,   # INTENSE (20-39)
    4: 40    # OVERDRIVE (40+)
}

static func calculate_tier(combo_count: int) -> int:
    if combo_count == 0:
        return 0  # IDLE
    if combo_count < 10:
        return 1  # NORMAL
    if combo_count < 20:
        return 2  # RISING
    if combo_count < 40:
        return 3  # INTENSE
    return 4      # OVERDRIVE
```

## Formulas

**Tier Calculation:**

| combo_count | tier |
|-------------|------|
| 0 | 0 (IDLE) |
| 1–9 | 1 (Normal) |
| 10–19 | 2 (Rising) |
| 20–39 | 3 (Intense) |
| 40+ | 4 (Overdrive) |

## Edge Cases

- `combo_count = 0` returns `tier = 0` (IDLE)
- Negative combo_count is not expected; behavior is undefined
- Very large combo_count (999+) still returns tier 4

## Dependencies

**Upstream:**
- None — this is the foundation layer

**Downstream:**
- ComboManager (Autoload) — consumes ComboData and TierLogic
- All other combo stories depend on this

## Tuning Knobs

None — tier thresholds are fixed per design.

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-13 | combo_count=8 | calculate_tier() | tier=1 (Normal) |
| AC-14 | combo_count=15 | calculate_tier() | tier=2 (Rising) |
| AC-15 | combo_count=25 | calculate_tier() | tier=3 (Intense) |
| AC-16 | combo_count=45 | calculate_tier() | tier=4 (Overdrive) |
| AC-17 | combo_count=0 | calculate_tier() | tier=0 (IDLE) |
| — | ComboData.reset() called | state is active | all fields reset to initial values |
| — | Two ComboData instances | created for player 1 and 2 | each has independent state |

## Tasks

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|-------------------|
| 1 | Create `src/gameplay/combat/ComboData.gd` | — | 0.5 | None | File exists with correct fields and reset() method |
| 2 | Create `src/gameplay/combat/TierLogic.gd` | — | 0.5 | None | File exists with calculate_tier() and TIER_THRESHOLDS |
| 3 | Write unit tests for TierLogic | — | 0.5 | Tasks 1-2 | All 5 tier boundary tests pass |
| 4 | Write unit tests for ComboData | — | 0.5 | Task 1 | reset() correctly resets all fields |

## Definition of Done

- [x] ComboData class with all fields defined
- [x] TierLogic.calculate_tier() returns correct tier for all boundary values
- [x] TierLogic unit tests pass (5 test cases covering all tiers)
- [x] ComboData.reset() unit test passes
- [x] Files placed in `src/gameplay/combat/`

## Implementation Artifacts

| Type | File | Test Coverage |
|------|------|---------------|
| Implementation | `src/gameplay/combat/TierLogic.gd` | — |
| Implementation | `src/gameplay/combat/ComboData.gd` | — |
| Unit Tests | `tests/unit/combo/tier_logic_test.gd` | 13 test functions |
| Unit Tests | `tests/unit/combo/combo_data_test.gd` | 8 test functions |
