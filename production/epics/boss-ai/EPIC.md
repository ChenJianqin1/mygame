# Epic: Boss AI系统

> **Layer**: Core
> **GDD**: design/gdd/boss-ai-system.md
> **Architecture Module**: Boss AI系统
> **Status**: Ready
> **Stories**: 9 created — see below

| ID | Story | Type | Status |
|----|-------|------|--------|
| 001 | Boss AI Manager Foundation | Logic | Ready for Dev |
| 002 | Macro FSM States | Logic | Ready for Dev |
| 003 | Compression Wall | Logic | Ready for Dev |
| 004 | Phase System | Logic | Ready for Dev |
| 005 | Attack Pattern Selection | Logic | Ready for Dev |
| 006 | Signal Integration | Integration | Ready for Dev |
| 007 | Rescue and Crisis Modulation | Logic | Ready for Dev |
| 008 | UI Telegraphs | Integration | Ready for Dev |
| 009 | Testing and Integration | Logic | Ready for Dev |

---

## Overview

Boss AI系统管理 Boss 的行为、状态和攻击模式。系统采用 Hybrid FSM + Behavior Tree 架构：宏观 FSM 管状态（IDLE/ATTACKING/HURT/PHASE_CHANGE/DEFEATED），BT 管攻击选择。压缩墙机制作为持续并行进程，根据玩家状态动态调整攻击节奏（rescue×0.5, crisis×1.2, 落后×0.6）。

核心职责：
- Hybrid FSM + BT 架构
- Boss 5状态机（IDLE/ATTACKING/HURT/PHASE_CHANGE/DEFEATED）
- Phase 切换（HP 60%/30%）
- 压缩墙动态节奏调制
- Boss 攻击模式和 Telegraph

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-006: Boss AI Behavior Tree & Phase | Hybrid FSM+BT；Phase阈值60%/30%；压缩墙倍率调制 | MEDIUM ⚠️ |

⚠️ **Engine Risk**: Hybrid FSM + Behavior Tree 在 Godot 4.6 中的实现模式需在实现阶段验证（用 `Tree` 节点还是手写状态机）。

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-boss-001 | Hybrid FSM + Behavior Tree architecture | ADR-ARCH-006 ✅ |
| TR-boss-002 | Boss 5-state FSM | ADR-ARCH-006 ✅ |
| TR-boss-003 | Phase 1→2 at 60% HP | ADR-ARCH-006 ✅ |
| TR-boss-004 | Phase 2→3 at 30% HP | ADR-ARCH-006 ✅ |
| TR-boss-005 | Compression wall modulation | ADR-ARCH-006 ✅ |
| TR-boss-006 | Attack pattern selection via BT | ADR-ARCH-006 ✅ |
| ... | (all 13 TR-boss requirements) | All ✅ |

**Total**: 13/13 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- Boss FSM correctly transitions through all 5 states under documented conditions
- Phase transitions trigger at correct HP thresholds (60% and 30%)
- Behavior Tree correctly selects attack patterns based on game state
- Compression wall correctly modulates attack pace (rescue×0.5, crisis×1.2, behind×0.6)
- Boss telegraphs display correctly before attacks
- All Logic stories have passing unit tests
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/boss-ai-system.md` are verified

---

## Next Step

Run `/create-stories boss-ai` to break this epic into implementable stories.
