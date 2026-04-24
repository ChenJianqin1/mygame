# Systems Index: 今日Boss：打工吧！

> **Status**: Draft
> **Created**: 2026-04-16
> **Last Updated**: 2026-04-16
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

一款双人合作2D横版动作Boss Rush游戏，核心玩法是**Combo连击战斗** + **协作机制**。游戏把打工人的职场困境转化为可战胜的Boss，战斗机制即困境隐喻。玩家在流畅的Combo战斗中体验"我们一起扛过来了"的情感共鸣。

**核心支柱驱动：**
- Pillar 1 "协作即意义" → 双人协作系统是核心系统
- Pillar 3 "战斗即隐喻" → Boss AI系统必须支持机制即隐喻的设计
- Pillar 4 "轻快节奏" → 即时难度调整保证不卡关

**MVP范围：** 1个可玩Boss战（Deadline Boss）+ 双人合作 + Combo系统 + 基本视觉反馈

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 输入系统 | Foundation | MVP | Designed | design/gdd/input-system.md | — |
| 2 | 碰撞检测系统 | Foundation | MVP | Designed | design/gdd/collision-detection-system.md | — |
| 3 | 摄像机系统 | Foundation | MVP | Designed | design/gdd/camera-system.md | — |
| 4 | 战斗系统 | Core | MVP | Designed | design/gdd/combat-system.md | 输入系统, 碰撞检测系统 |
| 5 | Combo连击系统 | Core | MVP | Designed | design/gdd/combo-system.md | 战斗系统, 输入系统 |
| 6 | 双人协作系统 | Core | MVP | Approved (reviewed 2026-04-17) | design/gdd/coop-system.md | 输入系统, 战斗系统 |
| 7 | Boss AI系统 | Core | MVP | Designed | design/gdd/boss-ai-system.md | 战斗系统, 碰撞检测系统 |
| 8 | 即时难度调整 | Core | Vertical Slice | Not Started | — | Boss AI系统, 双人协作系统 |
| 9 | UI系统 | Presentation | MVP | Designed | design/gdd/ui-system.md | Combo连击系统, 双人协作系统, Boss AI系统 |
| 10 | 粒子特效系统 | Presentation | MVP | Designed | design/gdd/particle-vfx-system.md | 战斗系统, Combo连击系统 |
| 11 | 动画系统 | Presentation | MVP | Designed | design/gdd/animation-system.md | 战斗系统, Boss AI系统 |
| 12 | 场景管理系统 | Feature | Vertical Slice | Not Started | — | Boss AI系统, 战斗系统 |
| 13 | 音频系统 | Feature | Vertical Slice | Not Started | — | 战斗系统, 场景管理系统 |
| 14 | 存档系统 | Persistence | Full Vision | Not Started | — | 场景管理系统 |

---

## Categories

| Category | Description | Systems in this project |
|----------|-------------|------------------------|
| **Foundation** | 所有系统依赖的基础设施 | 输入系统, 碰撞检测系统, 摄像机系统 |
| **Core** | 核心玩法系统，构成游戏基本体验 | 战斗系统, Combo连击系统, 双人协作系统, Boss AI系统, 即时难度调整 |
| **Presentation** | 玩家可见的表现层 | UI系统, 粒子特效系统, 动画系统 |
| **Feature** | 游戏功能系统 | 场景管理系统, 音频系统 |
| **Persistence** | 存档和状态保存 | 存档系统 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems |
|------|------------|------------------|---------|
| **MVP** | 核心循环可运行的最低要求，无法测试核心乐趣则不做 | 首个可玩原型 | 输入系统, 碰撞检测系统, 摄像机系统, 战斗系统, Combo连击系统, 双人协作系统, Boss AI系统, UI系统, 粒子特效系统, 动画系统 |
| **Vertical Slice** | 一个完整的、经过打磨的区域，展示完整体验 | Demo/Vertical Slice | 即时难度调整, 场景管理系统, 音频系统 |
| **Alpha** | 所有功能以粗略形式存在 | Alpha | — |
| **Full Vision** | 完整游戏 | Release | 存档系统 |

---

## Dependency Map

### Foundation Layer (无依赖，先设计与实现)

1. **输入系统** — 所有输入的源头，本地双人合作需要精确的输入分离
2. **碰撞检测系统** — 2D战斗的物理基础，Hitbox/Hurtbox机制

### Core Layer (依赖Foundation)

3. **战斗系统** — 依赖：输入系统, 碰撞检测系统
4. **Combo连击系统** — 依赖：战斗系统, 输入系统
5. **双人协作系统** — 依赖：输入系统, 战斗系统
6. **Boss AI系统** — 依赖：战斗系统, 碰撞检测系统
7. **即时难度调整** — 依赖：Boss AI系统, 双人协作系统

### Feature Layer (依赖Core)

8. **场景管理系统** — 依赖：Boss AI系统, 战斗系统
9. **音频系统** — 依赖：战斗系统, 场景管理系统

### Presentation Layer (依赖Core/Feature)

10. **摄像机系统** — 依赖：玩家位置（来自战斗系统）, Boss位置（来自Boss AI系统）
11. **UI系统** — 依赖：Combo连击系统, 双人协作系统, Boss AI系统
12. **粒子特效系统** — 依赖：战斗系统, Combo连击系统
13. **动画系统** — 依赖：战斗系统, Boss AI系统

### Persistence Layer

14. **存档系统** — 依赖：场景管理系统

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | 输入系统 | MVP | Foundation | S |
| 2 | 碰撞检测系统 | MVP | Foundation | S |
| 3 | 战斗系统 | MVP | Core | M |
| 4 | Combo连击系统 | MVP | Core | M |
| 5 | 双人协作系统 | MVP | Core | M |
| 6 | Boss AI系统 | MVP | Core | L |
| 7 | UI系统 | MVP | Presentation | M |
| 8 | 粒子特效系统 | MVP | Presentation | M |
| 9 | 动画系统 | MVP | Presentation | L |
| 10 | 摄像机系统 | MVP | Foundation | S |
| 11 | 即时难度调整 | Vertical Slice | Core | S |
| 12 | 场景管理系统 | Vertical Slice | Feature | M |
| 13 | 音频系统 | Vertical Slice | Feature | M |
| 14 | 存档系统 | Full Vision | Persistence | S |

**Effort估算：** S=1 session, M=2-3 sessions, L=4+ sessions

---

## Circular Dependencies

- 无循环依赖发现

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|------------------|------------|
| Boss AI系统 | Design | "战斗即隐喻"要求每个Boss的攻击模式必须与其代表的困境高度匹配 — 需要大量迭代才能找到"感觉对"的机制 | 优先设计Deadline Boss的机制，验证"机制=隐喻"的核心假设 |
| 双人协作系统 | Technical | 本地双人输入分离在Godot 4.6中的实现有已知复杂性，需要验证 | 原型阶段早期验证输入分离 |
| Combo连击系统 | Design | Combo的"感觉"很难用文字描述清楚，需要大量视觉/音效反馈迭代 | 快速原型验证Combo反馈的满足感 |
| 粒子特效系统 | Scope | 手绘风格粒子需要大量定制资源，可能成为瓶颈 | MVP阶段使用占位符粒子，Vertical Slice再定制 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 14 |
| Design docs started | 8 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 10/10 |
| Vertical Slice systems designed | 0/3 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first — use `/design-system [system-name]`
- [ ] Run `/design-review` on each completed GDD
- [ ] Prototype high-risk systems early: Boss AI系统, 双人协作系统
- [ ] Run `/gate-check pre-production` when MVP GDDs are designed
