# Epic: 碰撞检测系统

> **Layer**: Foundation
> **GDD**: design/gdd/collision-detection-system.md
> **Architecture Module**: 碰撞检测系统
> **Status**: Stories Ready
> **Stories**: 7/7 created

---

## Overview

碰撞检测系统管理游戏中的所有 Hitbox/Hurtbox 交互。玩家攻击产生 Hitbox，伤害区域与 Boss 的 Hurtbox 重叠时触发命中判定。系统采用 Area2D 对象池模式（预分配20个Area2D，零运行时实例化），Hitbox 在攻击动画帧 spawn，攻击结束时 despawn，支持最多13个并发 Hitbox。

核心职责：
- Area2D Hitbox/Hurtbox 配对检测
- 对象池管理（20个预分配 Area2D）
- 攻击帧级同步（动画 keyframe 触发 spawn/despawn）
- 6层碰撞策略（WORLD/PLAYER/PLAYER_HITBOX/BOSS/BOSS_HITBOX/SENSOR）
- 最多13个并发 Hitbox 上限强制

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-002: Collision Detection | Area2D 对象池 + Spawn-in/Spawn-out 模式；Hitbox 在攻击帧 spawn，攻击结束时 despawn | LOW |

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-collision-001 | Hitbox/Hurtbox Area2D 配对 | ADR-ARCH-002 ✅ |
| TR-collision-002 | 对象池 20 pre-allocated Area2D | ADR-ARCH-002 ✅ |
| TR-collision-003 | Hitbox spawn on attack frame | ADR-ARCH-002 ✅ |
| TR-collision-004 | Hitbox despawn on attack end | ADR-ARCH-002 ✅ |
| TR-collision-005 | Max 13 concurrent hitboxes | ADR-ARCH-002 ✅ |
| TR-collision-006 | 6-layer collision strategy | ADR-ARCH-002 ✅ |
| ... | (all 31 TR-collision requirements) | All ✅ |

**Total**: 31/31 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- Hitbox/Hurtbox Area2D 配对正确响应重叠
- 对象池正确工作（预分配20个，spawn/despawn 正常）
- 最多13个并发 Hitbox 上限强制执行
- Hitbox spawn/despawn 与动画帧精确同步
- 6层碰撞策略正确配置
- 所有 Logic stories 有单元测试通过
- 所有 Integration stories 有集成测试通过或文档化游测
- `design/gdd/collision-detection-system.md` 所有验收标准已验证

---

## Next Step

Run `/create-stories collision-detection` to break this epic into implementable stories.
