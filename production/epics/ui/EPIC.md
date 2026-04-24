# Epic: UI系统

> **Layer**: Presentation
> **GDD**: design/gdd/ui-system.md
> **Architecture Module**: UI系统
> **Status**: Ready
> **Stories**: 8 stories created

---

## Stories

| ID | Story | Priority | Status | Dependencies |
|----|-------|----------|--------|--------------|
| ui-001 | UI State Machine Foundation | must-have | ready-for-dev | Events autoload |
| ui-002 | Player HP Bars with Smooth Interpolation | must-have | ready-for-dev | story-001 |
| ui-003 | Boss HP Bar with Phase Color Transitions | must-have | ready-for-dev | story-001 |
| ui-004 | Combo Counter with Tier Scaling | must-have | ready-for-dev | story-001 |
| ui-005 | Rescue Timer Radial Countdown | must-have | ready-for-dev | story-001 |
| ui-006 | Crisis Edge Glow Effect | should-have | ready-for-dev | story-001, story-002 |
| ui-007 | Damage Number Popup System | should-have | ready-for-dev | story-001 |
| ui-008 | UI Signal Integration & Event Wiring | must-have | ready-for-dev | All UI stories |

---

## Overview

UI系统管理游戏中的所有屏幕和 HUD 元素。包括 Title Screen、Boss Intro、Gameplay HUD、Pause Menu、Game Over Screen 共5个屏幕状态。系统采用 CanvasLayer 独立渲染（屏幕空间不随相机运动），接收来自 Combo、Coop、Boss、AI 系统的信号驱动更新。

核心职责：
- 5个屏幕状态管理（TITLE/BOSS_INTRO/GAMEPLAY_HUD/PAUSED/GAME_OVER）
- HP 条（平滑插值 lerp）
- Combo 计数器（等级缩放 1.0x/1.15x/1.30x/1.50x）
- Rescue Timer（圆形径流倒计时）
- CRISIS 边缘发光效果
- Boss HP 条（相位颜色变化）
- Damage Number 弹出

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-009: UI System | CanvasLayer独立渲染；5状态机；HP条插值；Combo缩放 | LOW |

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ui-001 | 5-screen state machine | ADR-ARCH-009 ✅ |
| TR-ui-002 | HP bar smooth interpolation | ADR-ARCH-009 ✅ |
| TR-ui-003 | Combo counter tier scaling | ADR-ARCH-009 ✅ |
| TR-ui-004 | Rescue timer radial countdown | ADR-ARCH-009 ✅ |
| TR-ui-005 | Crisis edge glow | ADR-ARCH-009 ✅ |
| ... | (all 20 TR-ui requirements) | All ✅ |

**Total**: 20/20 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- All 5 screen states (TITLE/BOSS_INTRO/GAMEPLAY_HUD/PAUSED/GAME_OVER) transition correctly
- HP bars interpolate smoothly toward actual HP values
- Combo counter scales correctly at each tier (1.0x/1.15x/1.30x/1.50x)
- Rescue timer displays radial countdown correctly
- Crisis edge glow pulses when both players below 30% HP
- Boss HP bar changes color by phase (60%/30% thresholds)
- All UI updates via Events signals (no polling in `_process()`)
- All Logic stories have passing unit tests
- All Visual/Feel stories have evidence docs with sign-off
- All Acceptance Criteria from `design/gdd/ui-system.md` are verified

---

## Next Step

Run `/sprint-plan new` to prioritize and schedule these stories for the next sprint.
