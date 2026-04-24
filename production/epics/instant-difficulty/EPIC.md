# Epic: 即时难度调整

> **Layer**: Feature
> **GDD**: 无（占位 — GDD 未设计）
> **Architecture Module**: 即时难度调整
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories instant-difficulty`
>
> ⚠️ **警告**: 此系统无 GDD，无 TR，无专用 ADR。Stories 创建前需先完成 GDD 设计。

---

## Overview

即时难度调整系统根据当前游戏状态动态调整 Boss 攻击的难度。系统订阅 `boss_phase_changed` 和 `crisis_state_changed` 信号，根据玩家表现（HP 状态、战斗节奏）实时调整压缩墙倍率，确保游戏既不过于简单也不过于困难。

⚠️ **注意**: 此 Epic 基于 Architecture 文档中的职责描述创建。完整的需求、公式、验收标准需等待 GDD 设计完成后补充。

核心职责（暂定）：
- 订阅 `boss_phase_changed` 和 `crisis_state_changed` 信号
- 根据游戏状态计算难度倍率
- 将难度调整应用到 Boss AI 压缩墙

---

## Governing ADRs

| ADR | Decision Summary | Note |
|-----|-----------------|------|
| 无专用 ADR | 依赖 boss-ai 和 coop 系统的 ADR | 需在 GDD 设计时确定 |

---

## Dependencies

此系统依赖以下系统（来自 systems-index.md）：
- Boss AI系统
- 双人协作系统

---

## GDD Requirements

⚠️ **无 GDD** — 以下为 Architecture 文档中的职责描述，非正式需求：

| 来源 | 职责描述 | 状态 |
|------|---------|------|
| systems-index.md | 根据 boss_phase_changed 和 crisis_state_changed 调整难度 | 待 GDD |
| architecture.md | difficulty_scaling_changed 信号输出 | 待 GDD |

**Total**: 0/0 TRs (无 GDD)

---

## Definition of Done

⚠️ **暂定** — 以下基于 Architecture 文档，实际验收标准需等待 GDD 完成：

- 系统订阅 `boss_phase_changed` 和 `crisis_state_changed` 信号
- 难度倍率计算正确应用
- 不影响核心战斗体验
- GDD 设计完成后更新完成定义

---

## Open Questions

| # | 问题 | 状态 |
|---|------|------|
| 1 | 系统是否有独立的 GDD？ | 待确认 |
| 2 | 难度调整的具体公式是什么？ | 待 GDD |
| 3 | 难度调整是否有上下限？ | 待 GDD |

---

## Next Step

Run `/create-stories instant-difficulty` to create placeholder stories, or first complete GDD design for this system.
