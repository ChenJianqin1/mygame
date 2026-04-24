# Epic: 双人协作系统

> **Layer**: Core
> **GDD**: design/gdd/coop-system.md
> **Architecture Module**: 双人协作系统
> **Status**: Ready
> **Stories**: 6 created — see table below

---

## Overview

双人协作系统管理两位玩家的 HP 池（各100）、救援机制、以及危机状态。玩家倒下后有3秒救援窗口（175px范围内），救援成功后获得1.5秒无敌帧。当双方 HP 都低于30%时触发 CRISIS 状态，提供25%减伤。SOLO 模式（队友倒下后）提供20%减伤补偿。

核心职责：
- Per-player HP 池管理（100 HP/人）
- 3秒救援窗口倒计时（RESCUE_WINDOW=3.0）
- 175px 救援范围检测（RESCUE_RANGE=175.0）
- 救援后1.5秒无敌帧（RESCUED_IFRAMES_DURATION=1.5）
- CRISIS 状态检测（双方 < 30% HP）
- SOLO 减伤补偿（队友倒下后 20% 减伤）

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-005: Coop System HP Pools & Rescue | HP池分离；3秒救援窗口；1.5秒无敌帧；CRISIS阈值30%；SOLO减伤20% | LOW |

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-coop-001 | Per-player HP pool 100 HP each | ADR-ARCH-005 ✅ |
| TR-coop-002 | 3-second rescue window (RESCUE_WINDOW=3.0) | ADR-ARCH-005 ✅ |
| TR-coop-003 | 175px rescue range detection | ADR-ARCH-005 ✅ |
| TR-coop-004 | 1.5s i-frames after rescue (RESCUED_IFRAMES_DURATION=1.5) | ADR-ARCH-005 ✅ |
| TR-coop-005 | CRISIS state when both < 30% HP | ADR-ARCH-005 ✅ |
| TR-coop-006 | CRISIS damage reduction 25% | ADR-ARCH-005 ✅ |
| TR-coop-007 | SOLO damage reduction 20% | ADR-ARCH-005 ✅ |
| TR-coop-008 | CRISIS and SOLO do not stack | ADR-ARCH-005 ✅ |
| ... | (all 13 TR-coop requirements) | All ✅ |

**Total**: 13/13 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- Each player maintains independent 100 HP pool
- 3-second rescue timer counts down correctly in real-time
- 175px rescue range detection works correctly
- 1.5s invincibility frames activate after successful rescue
- CRISIS state triggers when both players fall below 30% HP
- CRISIS damage reduction (25%) applies correctly and does not stack with SOLO reduction
- SOLO damage reduction (20%) applies when partner is downed and not stacking with CRISIS
- All Logic stories have passing unit tests
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/coop-system.md` are verified

---

## Stories

| ID | Story | Type | Status |
|----|-------|------|--------|
| 001 | CoopManager Autoload + HP Pool | Logic | Ready-for-Dev |
| 002 | DOWNTIME State + Rescue Timer + Range Detection | Logic | Ready-for-Dev |
| 003 | Rescue Execution + I-frames + OUT State | Logic | Ready-for-Dev |
| 004 | CRISIS State Detection + Damage Reduction | Logic | Ready-for-Dev |
| 005 | SOLO Mode + Damage Modifiers Integration | Logic | Ready-for-Dev |
| 006 | Coop Signals + UI/VFX/Audio Integration | Integration | Ready-for-Dev |

---

## Next Step

Run `/story-readiness story-001` to begin implementation of the first story.
