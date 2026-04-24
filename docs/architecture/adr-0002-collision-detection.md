# ADR-ARCH-002: 碰撞检测 — Area2D Spawn-in/Spawn-out

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics |
| **Knowledge Risk** | LOW — Area2D API 在 Godot 4.4-4.6 无变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md` |
| **Post-Cutoff APIs Used** | 无 — Area2D API 稳定 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload) |
| **Enables** | ADR-ARCH-003 (Combat State Machine), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System) |
| **Blocks** | 无 |
| **Ordering Note** | ADR-ARCH-001 确立信号路由模式后，本 ADR 才能定义碰撞信号的具体签名 |

## Context

### Problem Statement
战斗系统需要精确的 Hitbox/Hurtbox 碰撞判定。Combo系统依赖命中事件计算连击。Boss AI需要感知玩家的接近和离开。如何在 Godot 4.6 中实现高效、可配置的碰撞检测？

### Constraints
- 必须支持 2D 横版战斗的精确命中检测
- 必须支持双玩家同时攻击的独立碰撞判定
- 必须支持性能预算（最大并发 Hitbox 数）

### Requirements
- Hitbox 在攻击动画帧精确 spawn/destroy
- Hurtbox 持续存在，实时检测碰撞
- 所有碰撞事件通过 Events 信号路由（除Boss AI感知直接路由）

## Decision

### 碰撞层策略（Layer/Mask Design）

| Layer | 名称 | 用途 |
|-------|------|------|
| 1 | `WORLD` | 静态世界几何体（平台、墙壁） |
| 2 | `PLAYER` | 玩家角色 CharacterBody2D |
| 3 | `PLAYER_HITBOX` | 玩家攻击 Hitbox（攻击时激活） |
| 4 | `BOSS` | Boss CharacterBody2D |
| 5 | `BOSS_HITBOX` | Boss 攻击 Hitbox（攻击时激活） |
| 6 | `SENSOR` | AI 感知探测器、RayCast2D |

**Mask 矩阵：**

| 实体类型 | Layer | Mask（检测谁） |
|----------|-------|----------------|
| Player CharacterBody | 2 | 1, 4, 5 (World, Boss, BossHitbox) |
| Player Hitbox | 3 | 4 (Boss Hurtbox) |
| Boss CharacterBody | 4 | 1, 2, 3 (World, Player, PlayerHitbox) |
| Boss Hitbox | 5 | 2 (Player Hurtbox) |

### Hitbox/Hurtbox 模式

采用 **Spawn-in/Spawn-out 模式**：

- **Hitbox**: Area2D，在攻击动画关键帧 spawn，攻击结束时 despawn
- **Hurtbox**: Area2D，持续存在于 Player/Boss 节点
- **CollisionManager**: Autoload，管理所有 Hitbox 的生命周期

```
Hitbox 状态机:
UNSPAWNED → [攻击帧] → ACTIVE → [命中] → HIT_REGISTERED → [攻击结束] → DESTROYED
```

**关键规则:**
- Hitbox 在 `DESTROYED` 帧**仍然参与**碰撞检测（该帧有效）
- `queue_free()` 在下一帧物理步执行

### CollisionManager (Autoload)

```gdscript
# CollisionManager.gd — Autoload singleton

## 信号 (经 Events 路由)
signal attack_hit(attack_id: int, is_grounded: bool, hit_count: int)
# 路由: CollisionManager → Events → ComboSystem, BossAI

## Boss AI感知信号 (直接路由)
signal player_detected(player: Node2D)     # 直接 → BossAI
signal player_lost(player: Node2D)          # 直接 → BossAI
signal player_hurt(player: Node2D, damage: float)  # 直接 → BossAI

## 方法
func spawn_hitbox(attack_id: String, config: Dictionary) -> Area2D:
    """
    config keys:
      - owner: Node2D (player or boss)
      - layer: int (PLAYER_HITBOX=3 or BOSS_HITBOX=5)
      - size: Vector2
      - offset: Vector2
      - collision_mask: int
    """
    # 从对象池取出 Area2D
    # 设置 layer, collision_mask, position
    # 添加到场景树
    # 状态 = ACTIVE
    return area

func despawn_hitbox(hitbox: Area2D) -> void:
    hitbox.state = DESTROYED
    hitbox.set_monitoring(false)  # 该帧仍检测
    hitbox.get_parent().remove_child(hitbox)
    pool.return_hitbox(hitbox)

func cleanup_by_owner(owner: Node2D, attack_id: String) -> void:
    # 中断时清理该owner的所有Hitbox
    for hitbox in active_hitboxes:
        if hitbox.owner == owner and hitbox.attack_id == attack_id:
            despawn_hitbox(hitbox)
```

### 信号路由

| 信号 | 路由 | 原因 |
|------|------|------|
| `attack_hit(attack_id, is_grounded, hit_count)` | CollisionManager → Events → ComboSystem, BossAI | 跨系统命中通知 |
| `player_detected/lost` | CollisionManager → BossAI (直接) | AI感知，低延迟要求 |
| `player_hurt` | CollisionManager → BossAI (直接) | AI感知，低延迟要求 |

### 对象池

- **Pool size**: 20 个预分配 Area2D
- **Checkout**: `spawn_hitbox()` 从池取
- **Checkin**: `despawn_hitbox()` 还池

### 最大并发 Hitbox

```
max_concurrent_hitboxes = player_count(2) × max_player_hitboxes(4)
                          + boss_count(1) × max_boss_hitboxes(6)
                          + global_reserve(4)
                        = 8 + 6 + 4 = 18
```

安全上限: **13** (默认配置)

## Alternatives Considered

### Alternative 1: CharacterBody + move_and_collide()
- **描述**: Hitbox用CharacterBody的move_and_collide()逐帧检测
- **优点**: 物理引擎直接支持
- **缺点**: 需要手动管理碰撞列表；不适合"命中后消失"的攻击模式
- **拒绝理由**: GDD明确要求Area2D方案；CharacterBody更适合持续物理而非一次性碰撞

### Alternative 2: StaticBody2D + RayCast2D
- **描述**: 使用RayCast2D进行命中检测
- **优点**: 精确控制检测方向
- **缺点**: 每次攻击需要多个RayCast；不支持区域碰撞
- **拒绝理由**: 无法检测区域碰撞（需要Area2D）；GDD不支持此方案

## Consequences

### Positive
- **精确**: Area2D 的 shape.intersects() 提供精确的形状碰撞
- **可配置**: Layer/Mask 策略易于调整
- **高效**: 对象池避免运行时内存分配
- **可测试**: CollisionManager 是独立Autoload，易于单元测试

### Negative
- **延迟一帧**: Area2D 的 `area_entered` 信号在碰撞后一帧触发（Godot行为）
- **状态管理复杂性**: Hitbox状态机需要精确管理

### Risks
- **Hitbox漏检**: 如果Hitbox移动过快可能穿透Hurtbox。**缓解**: 使用足够大的碰撞层+适当形状
- **性能峰值**: 多个同时命中可能造成性能抖动。**缓解**: 硬上限13个并发Hitbox

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| collision-detection-system.md | Hitbox/Hurtbox Area2D spawn-in/spawn-out | Area2D + CollisionManager Autoload |
| collision-detection-system.md | 6层Layer/Mask策略 | Layer/Mask矩阵定义 |
| collision-detection-system.md | 对象池20个预分配 | pool实现 |
| collision-detection-system.md | `attack_hit(attack_id, is_grounded, hit_count)` 信号 | 定义完整信号签名 |
| combat-system.md | 战斗系统依赖碰撞检测 | 提供命中信号路由 |
| combo-system.md | Combo系统依赖碰撞事件 | `attack_hit` 经Events路由 |
| boss-ai-system.md | Boss AI感知 | `player_detected/lost/hurt` 直接路由 |

## Performance Implications
- **CPU**: 每个Area2D碰撞检测约0.01ms；13个并发约0.13ms
- **Memory**: 20个对象池Area2D + 各自Shape2D；每个约1KB
- **Load Time**: 无影响

## Migration Plan
1. 创建 `CollisionManager.gd` Autoload
2. 实现6层Layer/Mask配置
3. 创建 Area2D 对象池
4. 实现 Hitbox 状态机
5. 配置 Hitbox spawn/despawn 调用
6. 配置信号路由（Events + 直接）

## Validation Criteria
- [ ] 6层Layer/Mask正确配置
- [ ] Hitbox在攻击帧spawn，攻击结束despawn
- [ ] `attack_hit` 信号正确路由到 ComboSystem 和 BossAI
- [ ] 对象池正确工作（无运行时instantiate）
- [ ] 并发Hitbox不超过13个
- [ ] `player_detected/lost/hurt` 正确路由到BossAI

## Related Decisions
- ADR-ARCH-001: Events Autoload — 确立信号路由模式
- ADR-ARCH-003: Combat State Machine — 战斗系统依赖本ADR
- ADR-ARCH-004: Combo System — Combo系统依赖本ADR的`attack_hit`信号
- `docs/architecture/architecture.md` — 主架构文档
