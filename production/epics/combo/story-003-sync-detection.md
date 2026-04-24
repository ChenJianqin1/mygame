# Story: Sync Detection & Sync Burst

> **Type**: Logic
> **Epic**: Combo连击系统 (`production/epics/combo/EPIC.md`)
> **GDD**: `design/gdd/combo-system.md` (Rule 2, Rule 5)
> **ADR**: ADR-ARCH-004
> **Status**: Done

## Overview

Implement 5-frame sync detection window and 3-hit sync chain triggering. When both players land a hit within 5 frames, the hit is flagged as SYNC. After 3 consecutive SYNC hits, Sync Burst is triggered.

## Player Fantasy

**玩家幻想：** "我们同时打中了！"

Two players hitting within a near-simultaneous window creates a sync bonus. 3 consecutive sync hits trigger a Sync Burst — orange and blue particle trails intertwine, the screen edge pulses in alternating colors.

## Detailed Rules

### Sync Detection

- **SYNC_WINDOW**: 5 frames — two hits within this window are considered synchronized
- `is_sync = abs(P1_hit_frame - P2_hit_frame) <= 5`
- Each player stores their own `last_hit_frame`
- Sync detection is evaluated on every hit from either player

### Sync Chain

- **SYNC_CHAIN_THRESHOLD**: 3 consecutive SYNC hits triggers Sync Burst
- `sync_chain_length` tracks consecutive sync hits per player
- Both players' chain counters increment together when sync is detected
- A non-SYNC hit resets both players' chain counters to 0

### Sync Burst Trigger

- When `sync_chain_length >= 3`, `sync_burst_triggered` signal fires
- Sync Burst is a visual feedback layer — does not affect damage
- Signal carries boss position (Vector2) for VFX placement

## Formulas

**Sync Detection:**
```
is_sync = abs(P1_hit_frame - P2_hit_frame) <= SYNC_WINDOW_FRAMES
```

**Sync Burst Trigger:**
```
triggers_sync_burst = (sync_chain_length >= SYNC_CHAIN_THRESHOLD)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| P1_hit_frame | int | 0–infinity | Frame P1 landed hit |
| P2_hit_frame | int | 0–infinity | Frame P2 landed hit |
| SYNC_WINDOW_FRAMES | int | 5 | Max frames apart for sync |
| **is_sync** | bool | — | True if synchronized |
| sync_chain_length | int | 0–infinity | Consecutive sync hits |
| **triggers_sync_burst** | bool | — | True at 3+ consecutive |

## Edge Cases

- **Only one player has active combo**: The IDLE player's hit is still SYNC if within 5 frames — they receive the sync multiplier even though their own combo_count is 1
- **Both players hit same frame**: Both hits are SYNC, both chain counters increment
- **Chain broken by window expiry**: If combo window expires, chain resets to 0; new sync hit starts fresh chain

## Dependencies

**Upstream:**
- Story 001: last_hit_frame storage in ComboData
- Combat system: provides combo_hit signal with frame timing

**Downstream:**
- Story 005: Signal emission (sync_burst_triggered)
- VFX system: consumes sync_burst_triggered for visuals
- UI system: consumes sync_chain_active for chain display

## Tuning Knobs

| Parameter | Default | Safe Range |
|-----------|---------|-----------|
| SYNC_WINDOW | 5 frames | 3–10 frames |
| SYNC_CHAIN_THRESHOLD | 3 hits | 2–5 hits |

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-09 | P1 hits frame N, P2 hits frame N+3 | Sync check | is_sync = TRUE (3 <= 5) |
| AC-10 | P1 hits frame N, P2 hits frame N+7 | Sync check | is_sync = FALSE (7 > 5) |
| AC-11 | 2 consecutive SYNC hits | 3rd SYNC hit lands | sync_burst_triggered signal fires |
| AC-12 | SYNC_BURST active, non-SYNC hit | Hit lands | Sync Burst ends, chain resets |
| AC-26 | Sync chain breaks | Visual state | sync_chain_active(0) fires |

## Tasks

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|-------------------|
| 1 | Implement TierLogic.is_sync_hit() static method | — | 0.25 | Story 001 | Returns true when frames within SYNC_WINDOW |
| 2 | Implement TierLogic.should_trigger_sync_burst() | — | 0.25 | Story 001 | Returns true when chain >= 3 |
| 3 | Implement _evaluate_sync() in ComboManager | — | 0.5 | Story 001 | Chain counters increment/reset correctly |
| 4 | Wire sync_burst_triggered signal emission | — | 0.25 | Task 3, Story 005 | Signal fires at correct threshold |
| 5 | Write unit tests for sync detection | — | 0.5 | Tasks 1-4 | AC-09, AC-10, AC-11, AC-12, AC-26 pass |

## Definition of Done

- [x] `TierLogic.is_sync_hit()` correctly detects 5-frame window
- [x] `TierLogic.should_trigger_sync_burst()` correctly triggers at 3 hits
- [x] Sync chain counter increments on consecutive SYNC hits
- [x] Non-SYNC hit resets chain counter to 0 for both players
- [x] `sync_burst_triggered` signal fires at 3 consecutive SYNC hits
- [x] All 5 sync detection acceptance criteria pass
