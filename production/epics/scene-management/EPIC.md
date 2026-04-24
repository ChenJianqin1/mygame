# Epic: 场景管理系统

> **Layer**: Feature
> **GDD**: 无（占位 — GDD 未设计）
> **Architecture Module**: 场景管理系统
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories scene-management`
>
> ⚠️ **警告**: 此系统无 GDD，无 TR，无专用 ADR。Stories 创建前需先完成 GDD 设计。

---

## Overview

场景管理系统管理游戏场景的加载、切换和状态。负责 Boss 战之间的过渡、场景边界的设置、以及场景元数据管理。系统订阅 `boss_defeated` 信号触发场景切换，向 CameraSystem 发送 `arena_changed` 信号更新边界。

⚠️ **注意**: 此 Epic 基于 Architecture 文档中的职责描述创建。完整的需求、公式、验收标准需等待 GDD 设计完成后补充。

核心职责（暂定）：
- 场景加载和卸载
- `boss_defeated` 信号触发场景切换
- 向 CameraSystem 发送 `arena_changed` 信号
- 管理场景边界

---

## Governing ADRs

| ADR | Decision Summary | Note |
|-----|-----------------|------|
| 无专用 ADR | 依赖 boss-ai 和 camera 的 ADR | 需在 GDD 设计时确定 |

---

## Dependencies

此系统依赖以下系统（来自 systems-index.md）：
- Boss AI系统
- 战斗系统

---

## GDD Requirements

⚠️ **无 GDD** — 以下为 Architecture 文档中的职责描述，非正式需求：

| 来源 | 职责描述 | 状态 |
|------|---------|------|
| architecture.md | arena_changed 信号输出 | 待 GDD |
| systems-index.md | 场景加载和切换 | 待 GDD |

**Total**: 0/0 TRs (无 GDD)

---

## Definition of Done

⚠️ **暂定** — 以下基于 Architecture 文档，实际验收标准需等待 GDD 完成：

- 场景正确加载和卸载
- `boss_defeated` 正确触发场景切换
- `arena_changed` 信号正确发送到 CameraSystem
- 场景边界正确设置
- GDD 设计完成后更新完成定义

---

## Open Questions

| # | 问题 | 状态 |
|---|------|------|
| 1 | 系统是否有独立的 GDD？ | 待确认 |
| 2 | 场景切换的过渡动画是什么？ | 待 GDD |
| 3 | 场景数量和类型？ | 待 GDD |

---

## Next Step

Run `/create-stories scene-management` to create placeholder stories, or first complete GDD design for this system.
