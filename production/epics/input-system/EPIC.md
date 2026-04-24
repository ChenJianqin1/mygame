# Epic: 输入系统

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: 输入系统
> **Status**: Ready
> **Stories**: 10 stories created — see table below

---

## Overview

输入系统是所有玩家输入的源头，负责将物理按键/手柄事件映射为游戏语义动作。本地双人合作需要精确的输入分离：P1 和 P2 必须能同时操作而不冲突。系统输出原始输入向量、缓冲状态、以及 `sync_attack_detected` 信号供上层系统消费。

核心职责：
- 键盘 P1 (WASD) 和 P2 (Arrow Keys) 的输入分离
- 手柄 P1 和 P2 的输入分离（支持热插拔）
- 8帧输入缓冲，支持精确时序判定
- 语义动作信号输出：rescue_input、dodge_input、sync_attack_detected

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-001: Events Autoload | 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号 | LOW |
| ADR-ARCH-002: Collision Detection | 定义了6层碰撞策略，输入系统不影响碰撞但共享事件架构 | LOW |

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-001 | P1/P2 键盘分离 (WASD / Arrow Keys) | ADR-ARCH-001 ✅ |
| TR-input-002 | P1/P2 手柄分离 (JOY_A / JOY_X) | ADR-ARCH-001 ✅ |
| TR-input-003 | 8-frame input buffer for timing | ADR-ARCH-001 ✅ |
| TR-input-004 | rescue_input / dodge_input signals | ADR-ARCH-001 ✅ |
| TR-input-005 | sync_attack_detected for combo sync | ADR-ARCH-001 ✅ |
| TR-input-006 | Input buffering window 8 frames | ADR-ARCH-001 ✅ |
| TR-input-007 | Hot-plug support for gamepads | ADR-ARCH-001 ✅ |
| TR-input-008 | Simultaneous input separation (P1+P2) | ADR-ARCH-001 ✅ |
| TR-input-009 | dodge window: 12 frames | ADR-ARCH-001 ✅ |
| TR-input-010 | dodge iframe overlap allowed | ADR-ARCH-001 ✅ |

**Total**: 10/10 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- All input mappings (keyboard P1/P2, gamepad P1/P2) are functional
- 8-frame input buffer correctly stores and retrieves historical inputs
- Simultaneous P1+P2 input does not conflict or alias
- All signals (`rescue_input`, `dodge_input`, `sync_attack_detected`) fire correctly
- All Logic stories have passing unit tests in `tests/unit/input/`
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/input-system.md` are verified

---

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 键盘 P1 输入响应 | Logic | Ready | ADR-ARCH-001 |
| 002 | 键盘 P2 输入响应 | Logic | Ready | ADR-ARCH-001 |
| 003 | 手柄输入响应 | Logic | Ready | ADR-ARCH-001 |
| 004 | 设备热插拔自动切换 | Logic | Ready | ADR-ARCH-001 |
| 005 | P1+P2 同时输入无冲突 | Integration | Ready | ADR-ARCH-001 |
| 006 | 输入延迟 < 3帧 | Logic | Ready | ADR-ARCH-001 |
| 007 | 60fps 稳定性 | Logic | Ready | ADR-ARCH-001 |
| 008 | 失焦清空输入状态 | Logic | Ready | ADR-ARCH-001 |
| 009 | 多手柄识别 | Logic | Ready | ADR-ARCH-001 |
| 010 | 未知设备不崩溃 | Logic | Ready | ADR-ARCH-001 |

**Total**: 10 stories (9 Logic, 1 Integration)

---

## Next Step

Run `/story-readiness story-001-p1-keyboard-input.md` to begin implementation of Story 001.
