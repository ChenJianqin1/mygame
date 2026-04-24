# Epic: 动画系统

> **Layer**: Presentation
> **GDD**: design/gdd/animation-system.md
> **Architecture Module**: 动画系统
> **Status**: In Progress
> **Stories**: 8 stories created

---

## Stories

| ID | Story | Type | Status | Est |
|----|-------|------|--------|-----|
| 001 | Player Animation State Machine Foundation | Logic | Ready-for-Dev | 3 days |
| 002 | Frame-Locked Hitbox Synchronization | Logic | Ready-for-Dev | 2 days |
| 003 | Boss Animation State Machine | Logic | Ready-for-Dev | 3 days |
| 004 | Sync Attack Visual System | Integration | Ready-for-Dev | 2 days |
| 005 | Paper Texture Implementation | Logic | Ready-for-Dev | 2 days |
| 006 | Rescue Animation Sequence | Integration | Ready-for-Dev | 2 days |
| 007 | Signal Integration | Logic | Ready-for-Dev | 1 day |
| 008 | Performance Optimization | Logic | Ready-for-Dev | 1 day |

**Total Estimated**: 16 days

---

## Overview

动画系统管理角色和 Boss 的动画状态。系统采用 Hybrid 架构：AnimatedSprite2D + AnimationPlayer + AnimationTree。帧锁 hitbox 激活由动画关键帧控制，确保视觉打击和游戏伤害精确同步。动画帧比例：anticipation/active/recovery = 3:1:2（L/M/H/SPECIAL 各自不同帧数）。

核心职责：
- Hybrid 动画架构（AnimatedSprite2D + AnimationPlayer + AnimationTree）
- 帧锁 hitbox 激活（关键帧 → hitbox_active）
- 动画帧比例（LIGHT=16帧, MEDIUM=27帧, HEAVY=40帧, SPECIAL=58帧）
- 玩家动画状态（idle/walk/attack/hurt/dodge）
- Boss 相位切换动画

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-010: Animation System | Hybrid AnimatedSprite2D+AnimationPlayer+AnimationTree；帧锁hitbox；帧比例3:1:2 | HIGH ⚠️ |

⚠️ **Engine Risk**: AnimationTree.active 属性在 Godot 4.4+ 被废弃，需验证 Godot 4.6 中的正确属性名和行为。

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-anim-001 | Hybrid animation architecture | ADR-ARCH-010 ✅ |
| TR-anim-002 | Frame-locked hitbox activation | ADR-ARCH-010 ✅ |
| TR-anim-003 | Animation frame ratios (3:1:2) | ADR-ARCH-010 ✅ |
| TR-anim-004 | Player animation states | ADR-ARCH-010 ✅ |
| TR-anim-005 | Boss phase transition animations | ADR-ARCH-010 ✅ |
| ... | (all 23 TR-anim requirements) | All ✅ |

**Total**: 23/23 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- Hybrid animation architecture (AnimatedSprite2D + AnimationPlayer + AnimationTree) implemented correctly
- Frame-locked hitbox activation via AnimationPlayer keyframe callbacks works precisely
- Animation frame ratios correct: LIGHT=16, MEDIUM=27, HEAVY=40, SPECIAL=58
- Player animations (idle/walk/attack/hurt/dodge) transition correctly
- Boss phase transition animations crossfade correctly
- All Logic stories have passing unit tests
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/animation-system.md` are verified

---

## Next Step

Run `/sprint-plan` to schedule these stories into sprints.
