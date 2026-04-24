# Epic: 粒子特效系统

> **Layer**: Presentation
> **GDD**: design/gdd/particle-vfx-system.md
> **Architecture Module**: 粒子特效系统
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories particle-vfx`

---

## Overview

粒子特效系统管理游戏中的所有视觉特效。系统采用 CPUParticles2D 用于单次爆发（如命中、Combo升级、Rescue），GPUParticles2D 用于连续螺旋流（如 Sync Burst）。预分配20个发射器，零运行时实例化，FIFO 队列管理。

核心职责：
- 5种发射器类型（hit/combo升级/同步爆发/rescue/boss_death）
- CPUParticles2D 用于单次爆发，GPUParticles2D 用于连续流
- 20个预分配发射器对象池
- FIFO 队列管理（MAX_QUEUE_DEPTH=10）
- 300粒子/15并发发射器上限强制执行
- 全信号驱动，被动响应（不主动查询状态）

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-008: VFX Emitter Pooling | CPU单次爆发；GPU连续流；20预分配；FIFO队列；300粒子/15发射器上限 | MEDIUM ⚠️ |

⚠️ **Engine Risk**: CPUParticles2D vs GPUParticles2D 的选择决策需基于测试确定。

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-vfx-001 | 5 emitter types (hit/combo/sync/rescue/boss_death) | ADR-ARCH-008 ✅ |
| TR-vfx-002 | CPUParticles2D for burst emitters | ADR-ARCH-008 ✅ |
| TR-vfx-003 | GPUParticles2D for continuous flow | ADR-ARCH-008 ✅ |
| TR-vfx-004 | 20 pre-allocated emitter pool | ADR-ARCH-008 ✅ |
| TR-vfx-005 | FIFO queue management | ADR-ARCH-008 ✅ |
| TR-vfx-006 | 300 particle / 15 emitter hard limit | ADR-ARCH-008 ✅ |
| ... | (all 18 TR-vfx requirements) | All ✅ |

**Total**: 18/18 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- All 5 emitter types correctly instantiated and configured
- CPUParticles2D used for burst effects (hit, combo escalation, rescue, boss_death)
- GPUParticles2D used for continuous flow (sync_burst spiral)
- 20-emitter pre-allocated pool correctly initialized in `_ready()`
- FIFO queue correctly enqueues and dequeues events
- When queue is full, oldest event is dropped (FIFO eviction)
- 300-particle / 15-emitter limits enforced in `_can_emit()`
- All VFX signals subscribed correctly from Events bus
- All Logic stories have passing unit tests
- All Acceptance Criteria from `design/gdd/particle-vfx-system.md` are verified

---

## Next Step

Run `/create-stories particle-vfx` to break this epic into implementable stories.
