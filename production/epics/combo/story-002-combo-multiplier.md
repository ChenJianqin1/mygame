# Story: Combo Multiplier Calculation

> **Type**: Logic
> **Epic**: Combo连击系统 (`production/epics/combo/EPIC.md`)
> **GDD**: `design/gdd/combo-system.md` (Rule 3)
> **ADR**: ADR-ARCH-004
> **Status**: Done

## Overview

Implement the combo damage multiplier formulas with separate caps for solo and sync play. Solo combo caps at 3.0x (40 combo); sync combo caps at 4.0x (60 combo). Both use the same 0.05 per-combo increment.

## Player Fantasy

**玩家幻想：** "连击越高，伤害越强。同步命中能突破单人的天花板。"

Solo players can reach 3.0x and feel powerful, but synchronized pairs can reach 4.0x — a tangible reward for maintained coordination that is impossible to achieve alone.

## Detailed Rules

### Multiplier Formulas

**Solo combo multiplier:**
```
solo_multiplier = min(1.0 + combo_count * 0.05, 3.0)
```

**Sync combo multiplier:**
```
sync_multiplier = min(1.0 + combo_count * 0.05, 4.0)
```

### Multiplier Table

| combo_count | solo_multiplier | sync_multiplier |
|-------------|-----------------|-----------------|
| 0 | 1.0 | 1.0 |
| 20 | 2.0 | 2.0 |
| 40 | 3.0 (cap) | 3.0 |
| 50 | 3.0 (cap) | 3.5 |
| 60 | 3.0 (cap) | 4.0 (cap) |
| 99 | 3.0 (cap) | 4.0 (cap) |

## Formulas

**Solo Multiplier:**
```
solo_multiplier = min(1.0 + combo_count * 0.05, 3.0)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| combo_count | int | 0–99 | Current combo count |
| **solo_multiplier** | float | 1.0–3.0 | Solo damage multiplier |

**Sync Multiplier:**
```
sync_multiplier = min(1.0 + combo_count * 0.05, 4.0)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| combo_count | int | 0–99 | Current combo count |
| **sync_multiplier** | float | 1.0–4.0 | Sync damage multiplier |

## Edge Cases

- `combo_count = 0` → multiplier = 1.0 (no bonus)
- Sync multiplier applies when the hit is flagged as SYNC (flag comes from sync detection story)
- Below 40 combo, sync and solo produce identical values

## Dependencies

**Upstream:**
- Story 001: ComboData foundation (combo_count stored here)

**Downstream:**
- Combat system queries multiplier via `get_combo_multiplier(player_id, is_sync)`
- UI displays multiplier (via combo_multiplier_updated signal)

## Tuning Knobs

| Parameter | Default | Safe Range |
|-----------|---------|-----------|
| SOLO_MAX_MULTIPLIER | 3.0 | 2.0–5.0 |
| SYNC_MAX_MULTIPLIER | 4.0 | 3.0–6.0 |
| COMBO_DAMAGE_INCREMENT | 0.05 | 0.01–0.1 |

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-04 | combo_count=20 (solo) | Query multiplier | solo_multiplier = 2.0 |
| AC-05 | combo_count=40 (solo) | Query multiplier | solo_multiplier = 3.0 (cap) |
| AC-06 | combo_count=40 (sync) | Query multiplier | sync_multiplier = 3.0 |
| AC-07 | combo_count=50 (sync) | Query multiplier | sync_multiplier = 3.5 |
| AC-08 | combo_count=60 (sync) | Query multiplier | sync_multiplier = 4.0 (cap) |
| AC-22 | combo_count=0 | Query multiplier | 1.0 |

## Tasks

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|-------------------|
| 1 | Add multiplier constants to ComboManager | — | 0.25 | Story 001 | SOLO_MAX_MULTIPLIER=3.0, SYNC_MAX_MULTIPLIER=4.0, COMBO_DAMAGE_INCREMENT=0.05 defined |
| 2 | Implement get_combo_multiplier(player_id, is_sync) | — | 0.5 | Story 001 | Returns correct multiplier for all combo_count values |
| 3 | Write unit tests for multiplier formula | — | 0.5 | Task 2 | All 6 multiplier ACs pass |

## Definition of Done

- [x] `get_combo_multiplier(player_id, is_sync=false)` returns correct solo multiplier
- [x] `get_combo_multiplier(player_id, is_sync=true)` returns correct sync multiplier
- [x] All 6 multiplier acceptance criteria pass
- [x] Multiplier capped at correct values (3.0 solo, 4.0 sync)
