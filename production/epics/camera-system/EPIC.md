# Epic: 摄像机系统

> **Layer**: Foundation
> **GDD**: design/gdd/camera-system.md
> **Architecture Module**: 摄像机系统
> **Status**: Ready
> **Stories**: Created (10 stories) — run `/story-readiness` to validate before dev

---

## Overview

摄像机系统管理游戏相机，负责追踪 P1+P2 位置、实现画面震动（trauma）、以及动态缩放（zoom）。系统有7个状态（NORMAL/PLAYER_ATTACK/SYNC_ATTACK/BOSS_FOCUS/BOSS_PHASE_CHANGE/CRISIS/COMBAT_ZOOM），通过 `camera_shake_intensity` 和 `camera_zoom_changed` 信号与 Events 总线连接。

核心职责：
- P1+P2 位置追踪，加权中点计算
- 7个相机状态及优先级切换
- Trauma 震动（通过 offset 实现，非 position）
- 动态缩放（基于玩家间距、Boss状态、战斗状态）
- 7状态优先级：CRISIS > BOSS_PHASE_CHANGE > BOSS_FOCUS > SYNC_ATTACK > PLAYER_ATTACK > COMBAT_ZOOM > NORMAL

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-007: Camera System | Camera2D 震动通过 offset 实现；7状态机；动态 zoom 计算公式 | MEDIUM ⚠️ |

⚠️ **Engine Risk**: Camera2D.smoothing 在 Godot 4.4+ 被拆分为 `position_smoothing_enabled` + `position_smoothing_speed`，需在 Godot 4.6 编辑器中验证属性名。

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-camera-001 | Camera tracks P1+P2 weighted midpoint | ADR-ARCH-007 ✅ |
| TR-camera-002 | 7 camera states with priority | ADR-ARCH-007 ✅ |
| TR-camera-003 | Trauma shake via offset (not position) | ADR-ARCH-007 ✅ |
| TR-camera-004 | Dynamic zoom based on player distance | ADR-ARCH-007 ✅ |
| TR-camera-005 | Boss focus zoom on boss attacks | ADR-ARCH-007 ✅ |
| ... | (all 21 TR-camera requirements) | All ✅ |

**Total**: 21/21 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- Camera correctly tracks P1+P2 weighted midpoint position
- 7 camera states transition correctly with proper priority
- Trauma shake implemented via `offset` (not `position`)
- Dynamic zoom calculated from player distance, boss state, and combat state
- Camera offset smoothly returns to origin when trauma decays
- All Logic stories have passing unit tests
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/camera-system.md` are verified

---

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | CameraController Foundation + Trauma Shake | Logic | Ready | ADR-ARCH-007 |
| 002 | Dual-Player Weighted Centroid Tracking | Logic | Ready | ADR-ARCH-007 |
| 003 | 7-State Camera State Machine + Priority | Logic | Ready | ADR-ARCH-007 |
| 004 | Player Attack Zoom Response | Integration | Ready | ADR-ARCH-007 |
| 005 | Sync Attack Camera Response | Integration | Ready | ADR-ARCH-007 |
| 006 | Combo Tier Zoom (Tier 3+) | Integration | Ready | ADR-ARCH-007 |
| 007 | Boss Focus + Phase Transition | Integration | Ready | ADR-ARCH-007 |
| 008 | Crisis Mode (Player Downed) | Integration | Ready | ADR-ARCH-007 |
| 009 | Dynamic Zoom (Player Distance-Based) | Logic | Ready | ADR-ARCH-007 |
| 010 | Camera Signal Contracts (Events Integration) | Integration | Ready | ADR-ARCH-007 |

---

## Next Step

Run `/story-readiness story-001-camera-controller-foundation.md` to validate Story 001 is ready for implementation.
