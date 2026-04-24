# ADR-ARCH-003: 战斗系统状态机与伤害公式

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — StateMachine 模式在 Godot 4.4-4.6 无变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-002 (Collision Detection) |
| **Enables** | ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System), Boss AI系统 |
| **Blocks** | 无 |
| **Ordering Note** | 本 ADR 定义战斗核心规则；Combo/Coop/Boss 系统依赖本 ADR 的信号定义 |

## Context

### Problem Statement
战斗系统需要明确的状态机转换规则和伤害计算公式。所有下游系统（Combo、Coop、Boss AI、UI、VFX）都依赖战斗系统发出的信号。

### Requirements
- 状态机必须覆盖玩家和Boss的所有游戏状态
- 伤害公式必须支持连击累积和攻击类型差异化
- 信号必须与已注册的路由规则一致

## Decision

### 玩家状态机

```
IDLE ──[attacked]──► ATTACKING ──[anim_end]──► IDLE
  │                    ▲
  │                    │
  └──[dodged]──► DODGING ──[12帧结束]──► IDLE
  │
  └──[hurt_received]──► HURT ──[硬直结束]──► IDLE
  │
  └──[blocking]──► BLOCKING ──[松开/超时]──► IDLE
  │
  └──[hp≤0]──► DOWNTIME
```

**状态定义:**

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| `IDLE` | 待机，可移动和攻击 | 默认/动画结束 | 收到移动或攻击输入 |
| `MOVING` | 移动中 | 有移动输入 | 移动输入结束 |
| `ATTACKING` | 执行攻击动作 | attacked信号 | 攻击动画结束 |
| `HURT` | 受击硬直 | hurt_received信号 | 硬直结束 |
| `DODGING` | 闪避无敌帧 | dodged信号 | DODGE_DURATION(12帧)结束 |
| `BLOCKING` | 防御中 | 防御输入+在防御状态 | 防御输入结束或超时 |
| `DOWNTIME` | 倒地/被击倒 | hp ≤ 0 | — |

### Boss 状态机

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| `IDLE` | 待机 | 默认/攻击间隔 | AI决定进入攻击 |
| `ATTACKING` | 执行攻击动作 | AI触发 | 攻击动画结束 |
| `HURT` | 受击硬直 | 玩家命中触发 | 硬直结束 |
| `PHASE_CHANGE` | 阶段转换 | 血量低于阈值 | 转换动画结束 |
| `DEFEATED` | 被击败 | hp ≤ 0 | 死亡动画播放完毕 |

### 伤害公式

```
final_damage = base_damage × attack_type_multiplier × combo_multiplier
```

**变量定义:**

| 变量 | 值 | 类型 |
|------|---|------|
| base_damage | 15 (默认) | int |
| attack_type_multiplier | LIGHT=0.8, MEDIUM=1.0, HEAVY=1.5, SPECIAL=2.0 | float |
| combo_multiplier | min(1.0 + combo_count × 0.05, 3.0) | float |
| **final_damage** | 6–120 | int |

**combo_multiplier:**

```
combo_multiplier = min(1.0 + combo_count × COMBO_DAMAGE_INCREMENT, MAX_COMBO_MULTIPLIER)
COMBO_DAMAGE_INCREMENT = 0.05
MAX_COMBO_MULTIPLIER = 3.0 (solo) / 4.0 (sync)
```

### Hitstop 公式

```
hitstop_frames = base_hitstop[attack_type] + bonus_hitstop[target_type]
```

| attack_type | base_hitstop |
|-------------|--------------|
| LIGHT | 3帧 |
| MEDIUM | 5帧 |
| HEAVY | 8帧 |
| SPECIAL | 12帧 |

| target_type | bonus_hitstop |
|-------------|--------------|
| PLAYER | 0帧 |
| BOSS | 2帧 |
| ELITE | 1帧 |

**双人叠加:** 同帧命中(3帧窗口内)可叠加Hitstop

### 击退公式

```
knockback_force = base_knockback[attack_type] × normalize(target_position - attacker_position)
```

| attack_type | base_knockback |
|-------------|----------------|
| LIGHT | 50px |
| MEDIUM | 100px |
| HEAVY | 200px |
| SPECIAL | 300px |

方向: 始终**远离攻击者**。

### 信号路由

| 信号 | 路由 | 原因 |
|------|------|------|
| `combo_hit(attack_type, combo_count, is_grounded)` | CombatSystem → Events → ComboSystem | 跨系统通知 |
| `player_attacked(target_id, damage)` | CombatSystem → BossAI (直接) | Boss需低延迟感知 |
| `damage_dealt(damage, target_id, is_critical)` | CombatSystem → Events → UI | 伤害数字显示 |
| `player_health_changed(current, max)` | CombatSystem → Events → UI | 血条更新 |
| `hit_landed(attack_type, position, direction)` | CombatSystem → VFXManager (直接) | 高频低延迟VFX |

### CombatManager (Autoload) 接口

```gdscript
# CombatManager.gd — Autoload

# 输入信号
signal attacked(action_type: String)   # from InputSystem
signal dodged()                          # from InputSystem
var move_direction: Vector2               # from InputSystem

# 输出信号 (经Events)
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)
signal damage_dealt(damage: int, target_id: int, is_critical: bool)
signal player_health_changed(current: int, max: int)

# 输出信号 (直接)
signal player_attacked(target_id: int, damage: int)  # → BossAI
signal hit_landed(attack_type: String, position: Vector2, direction: Vector2)  # → VFXManager

# 方法
func calculate_damage(base: int, attack_type: String, combo_count: int) -> int
func apply_knockback(target: Node2D, force: Vector2)
func trigger_hitstop(frames: int)
func get_player_state(player_id: int) -> String  # IDLE/MOVING/ATTACKING/HURT/DODGING/BLOCKING/DOWNTIME
func get_boss_state() -> String                # IDLE/ATTACKING/HURT/PHASE_CHANGE/DEFEATED
```

## Alternatives Considered

无替代方案 — GDD已明确定义所有规则。

## Consequences

### Positive
- **精确**: 状态机覆盖所有游戏状态
- **可调**: 所有参数通过 Tuning Knobs 可配置
- **可测试**: 伤害公式可单元测试

### Negative
- **combo_multiplier 上限固定**: 3.0 (solo) / 4.0 (sync)，无法动态调整

### Risks
- **combo累积速度**: 0.05/hit 可能在长战斗中过高。**缓解**: 监控实际战斗长度调整

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | 状态机 IDLE/ATTACKING/HURT/DODGING/BLOCKING/DOWNTIME | 完整状态转换定义 |
| combat-system.md | 伤害公式 | 完整变量和公式 |
| combat-system.md | Hitstop | 帧数表和叠加规则 |
| combat-system.md | 击退 | 基础力和方向公式 |
| combat-system.md | 信号路由 | 与已注册规则一致 |

## Performance Implications
- **CPU**: 伤害计算约 0.01ms；状态机查询 < 0.001ms
- **Memory**: 无额外分配

## Migration Plan
1. 创建 `CombatManager.gd` Autoload
2. 实现状态机 (可使用 StateMachine 子类)
3. 实现伤害计算方法
4. 配置信号发射 (Events vs 直接)
5. 连接上游信号 (InputSystem, CollisionSystem)
6. 连接下游信号 (ComboSystem, BossAI, UI, VFX)

## Validation Criteria
- [ ] 状态转换正确: IDLE→ATTACKING→IDLE
- [ ] 伤害公式输出: LIGHT×0连击=base×0.8, HEAVY×40连击=base×1.5×3.0
- [ ] Hitstop: LIGHT命中Boss=5帧
- [ ] 信号路由正确: combo_hit→Events, hit_landed→VFX直接

## Related Decisions
- ADR-ARCH-001: Events Autoload
- ADR-ARCH-002: Collision Detection
- ADR-ARCH-004: Combo System (依赖本ADR的combo_hit信号)
- ADR-ARCH-005: Coop System
- `docs/architecture/architecture.md`
