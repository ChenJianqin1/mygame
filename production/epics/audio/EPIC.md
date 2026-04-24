# Epic: 音频系统

> **Layer**: Presentation
> **GDD**: 无独立 GDD（由 architecture.md 和 ADR-ARCH-011 覆盖）
> **Architecture Module**: 音频系统
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories audio`

---

## Overview

音频系统管理游戏中的所有声音输出。系统采用 4 总线架构（Master/SFX/Music/Ambient），通过 WCOSS 路由。所有 SFX 信号驱动，无轮询。BGM 交叉淡入淡出切换。系统订阅来自所有游戏系统的 Events 信号，播放对应音效。

核心职责：
- 4总线架构（MASTER_BUS=0, SFX_BUS=1, MUSIC_BUS=2, AMBIENT_BUS=3）
- 全 SFX 信号驱动订阅（无轮询）
- BGM 交叉淡入淡出切换
- 音量控制（BGM/SFX/UI 独立调节）
- 空间音效（玩家位置相关的 SFX）

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-011: Audio System | 4总线；WCOSS路由；全SFX信号驱动；BGM交叉淡入淡出 | LOW |

---

## Dependencies

此系统依赖以下系统的信号：
- 战斗系统（attack_started, hit_confirmed）
- Combo系统（combo_hit, sync_burst_triggered）
- 双人协作系统（player_downed, player_rescued）
- Boss AI系统（boss_attack_started, boss_phase_changed）
- UI系统（menu interactions）

---

## GDD Requirements

⚠️ **无独立 GDD** — 以下基于 ADR-ARCH-011：

| 来源 | 职责描述 | 状态 |
|------|---------|------|
| ADR-ARCH-011 | 4总线架构 | 已实现 ✅ |
| ADR-ARCH-011 | 全SFX信号驱动 | 已实现 ✅ |
| ADR-ARCH-011 | BGM交叉淡入淡出 | 已实现 ✅ |

**Total**: 基于 ADR-ARCH-011 的架构要求

---

## Definition of Done

This epic is complete when:
- 4-bus audio routing correctly configured (Master/SFX/Music/Ambient)
- All SFX events subscribed from Events bus and fire correctly
- BGM crossfade transitions smoothly between tracks
- Volume controls (BGM/SFX/UI) adjustable independently
- Spatial audio works for position-dependent SFX
- All Acceptance Criteria from `design/gdd/ui-system.md` (audio-related) are verified

---

## Next Step

Run `/create-stories audio` to break this epic into implementable stories.
