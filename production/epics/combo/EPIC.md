# Epic: Combo连击系统

> **Layer**: Core
> **GDD**: design/gdd/combo-system.md
> **Architecture Module**: Combo连击系统
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combo`

---

## Overview

Combo连击系统追踪每位玩家的连击数、连击等级（Tier 1-4）、以及 Sync Chain 长度。连击窗口1.5秒，超时重置。Tier 等级通过 `TierLogic.calculate_tier()` 静态方法计算，确保可单独单元测试。Sync 窗口5帧，3+连触发 Sync Burst。

核心职责：
- Per-player ComboData 实例独立追踪
- Tier 等级计算（1-9=Tier1, 10-19=Tier2, 20-39=Tier3, 40+=Tier4）
- Sync 窗口5帧检测
- 3连触发 Sync Burst
- Combo 窗口1.5秒超时重置

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-004: Combo System Data Structures | ComboData实例分离；TierLogic静态方法计算；Sync窗口5帧3连触发 | LOW |

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-combo-001 | Per-player ComboData instance | ADR-ARCH-004 ✅ |
| TR-combo-002 | Tier calculation: TierLogic.calculate_tier() | ADR-ARCH-004 ✅ |
| TR-combo-003 | Combo window 1.5s timeout | ADR-ARCH-004 ✅ |
| TR-combo-004 | Sync window 5 frames | ADR-ARCH-004 ✅ |
| TR-combo-005 | 3+ sync hits trigger Sync Burst | ADR-ARCH-004 ✅ |
| TR-combo-006 | Combo multiplier solo cap 3.0 | ADR-ARCH-004 ✅ |
| TR-combo-007 | Combo multiplier sync cap 4.0 | ADR-ARCH-004 ✅ |
| ... | (all 27 TR-combo requirements) | All ✅ |

**Total**: 27/27 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- Each player has independent ComboData instance tracking their combo separately
- Tier calculation via `TierLogic.calculate_tier()` returns correct tier for all hit counts
- Combo window 1.5s timeout resets combo correctly
- Sync window 5 frames correctly detects near-simultaneous hits
- 3+ sync hits triggers Sync Burst exactly once
- Solo combo multiplier cap at 3.0 enforced
- Sync combo multiplier cap at 4.0 enforced
- All combo tier escalation signals fire correctly
- All Logic stories have passing unit tests
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/combo-system.md` are verified

---

## Stories

| ID | Story | Type | Status | Dependencies |
|----|-------|------|--------|-------------|
| 001 | [story-001-combo-data-foundation.md](story-001-combo-data-foundation.md) | Logic | Ready for Dev | — |
| 002 | [story-002-combo-multiplier.md](story-002-combo-multiplier.md) | Logic | Ready for Dev | 001 |
| 003 | [story-003-sync-detection.md](story-003-sync-detection.md) | Logic | Ready for Dev | 001 |
| 004 | [story-004-combo-timer-edge-cases.md](story-004-combo-timer-edge-cases.md) | Logic | Ready for Dev | 001 |
| 005 | [story-005-combo-signals.md](story-005-combo-signals.md) | Integration | Ready for Dev | 001–004 |

## Next Step

Begin implementation with Story 001 (foundation) or run `/sprint-plan` to schedule these stories in a sprint.
