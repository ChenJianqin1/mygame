# 碰撞检测系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 — 协作即意义

## Overview

碰撞检测系统是游戏物理交互的核心基础设施，负责检测和报告游戏实体之间的接触和重叠。本系统为战斗系统提供精确的Hitbox/Hurtbox碰撞判定，为玩家提供可信赖的地面检测和平台碰撞，为Boss AI提供感知探测。

作为Foundation层系统，它无上游依赖，为战斗系统、Combo连击系统、Boss AI系统提供碰撞查询服务。系统使用Godot 4.6的Area2D和PhysicsBody2D API，构建可配置的碰撞层策略，确保双人合作中"我的攻击命中了"的精确反馈。

## Player Fantasy

**玩家感受：** 碰撞检测对玩家来说是"隐形的基础设施"——他们不会注意到它，但会立刻注意到它的缺失。当玩家的攻击"明明打中了却没伤害"，那是碰撞检测的问题；当玩家感觉"我的跳跃落地不对"或"Boss的攻击判定太奇怪"，也是碰撞检测的问题。

**情感锚点：**
- **信任感** — 玩家可以100%信任碰撞反馈。"我打到了就是打到了，没打到就是没打到"
- **公平感** — 碰撞判定对双方（P1/P2/Boss）一视同仁，不存在"有利于某方"的隐藏偏差
- **精确感** — 打击感和躲避的时机可以被精确掌握，失败是因为玩家操作问题而非系统问题

由于这是纯基础设施系统，不存在玩家主动"使用"它的情况——所有体验都通过战斗系统、协作系统等下游系统传递。

## Detailed Design

### Core Rules

**1. 碰撞层策略（Layer/Mask Design）**

| Layer | 名称 | 用途 |
|-------|------|------|
| 1 | `WORLD` | 静态世界几何体（平台、墙壁） |
| 2 | `PLAYER` | 玩家角色 PhysicsBody2D |
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

**2. Hitbox/Hurtbox 模式实现**

采用 **Spawn-in/Spawn-out 模式**：Hitbox 在攻击时创建，攻击结束时销毁。

- Hitbox 是 Area2D，挂载在攻击动画的关键帧位置
- Hurtbox 是 Area2D，挂载在 Player/Boss 节点上，持续存在
- Hitbox 检测到 Hurtbox 时，发送 `hit_confirmed` 信号
- Hurtbox 收到信号后，发送 `hurt_received` 给所属实体

**Hitbox 生命周期：**
```
UNSPAWNED → [攻击帧] → ACTIVE → [命中] → HIT_REGISTERED → [攻击结束] → DESTROYED
```

**3. 地面检测**

主方案：`CharacterBody2D.is_on_floor()` + `move_and_slide()`
- 零额外开销，与 Godot 内置集成
- 必须在 `move_and_slide()` 后调用

辅助 RayCast2D：仅用于需要精确判断的场景（平台边缘检测）

**4. AI 感知**

双层检测：
- Proximity Sensor（Area2D）：圆形检测区域，检测玩家进入/离开
- Line-of-Sight（RayCast2D，可选）：确认是否视线无遮挡

---

### States and Transitions

Hitbox 状态机：

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| `UNSPAWNED` | 未创建 | 默认 | 攻击动作触发 |
| `ACTIVE` | 检测中 | Spawn | 检测到命中或攻击结束 |
| `HIT_REGISTERED` | 已命中 | 第一次命中 | 攻击结束 |
| `DESTROYED` | 从场景树移除 | 攻击结束 | — |

---

### Interactions with Other Systems

**输出 → 战斗系统：**
- 信号：`hit_confirmed(hitbox, hurtbox, attack_id)` — 通知命中发生
- 接口：战斗系统订阅此信号计算伤害和应用击退

**输出 → Combo连击系统：**
- 信号：`attack_hit(attack_id, is_grounded, hit_count)` — 通知命中成立
- Combo系统据此计算连击数

**输出 → Boss AI系统：**
- 信号：`player_detected(player)`, `player_lost(player)`, `player_hurt(player, damage)`
- Boss AI据此调整行为

**输入 ← 战斗系统：**
- 方法：`HitboxManager.spawn_hitbox(attack_id, config)` — 创建玩家/Boss的Hitbox
- 方法：`HitboxManager.despawn_hitbox(hitbox)` — 提前销毁（可选）

## Formulas

**1. Hitbox尺寸公式**

```
hitbox_size = base_size * attack_type_multiplier * entity_scale_multiplier
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_size | — | Vector2 | (16,16)–(256,256) | Hitbox基础尺寸（像素） |
| attack_type_multiplier | — | float | 0.5–3.0 | 攻击类型系数 |
| entity_scale_multiplier | — | float | 0.8–1.5 | 实体缩放系数 |
| **hitbox_size** | result | Vector2 | (8,8)–(384,384) | 最终Hitbox尺寸 |

**示例：** `base_size=(64,64) * 1.5(重攻击) * 2.0(Boss) = (192,192)`

---

**2. Hitbox偏移公式**

```
hitbox_offset = (forward_offset * facing_direction) + (vertical_offset * up_vector)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| forward_offset | — | float | 0–128 | 前后偏移（正值=前方） |
| facing_direction | — | int | {-1, 1} | 实体朝向（-1=左，1=右） |
| vertical_offset | — | float | -64–128 | 上下偏移 |
| up_vector | — | float | 1.0 | 固定向上 |
| **hitbox_offset** | result | Vector2 | (-160,-64)–(160,128) | 最终偏移量 |

---

**3. AI探测半径公式**

```
detection_radius = base_radius * alertness_multiplier * los_modifier
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_radius | — | float | 64–512 | 基础探测半径（像素） |
| alertness_multiplier | — | float | 0.5–2.0 | 警觉度系数（IDLE=0.75, PATROL=1.0, ALERTED=1.5, CHASING=2.0） |
| los_modifier | — | float | 0.5–1.0 | 视线系数（无遮挡=1.0，有遮挡=0.5） |
| **detection_radius** | result | float | 32–1024 | 最终探测半径 |

---

**4. 最大并发Hitbox公式（性能）**

```
max_concurrent_hitboxes = player_count * max_player_hitboxes + boss_count * max_boss_hitboxes + global_reserve
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| player_count | — | int | 1–2 | 本地玩家数 |
| max_player_hitboxes | — | int | 2–4 | 每玩家最大活跃Hitbox |
| boss_count | — | int | 0–1 | 同时Boss数 |
| max_boss_hitboxes | — | int | 3–6 | 每Boss最大活跃Hitbox |
| global_reserve | — | int | 0–4 | 全局保留槽位 |
| **max_concurrent_hitboxes** | result | int | 4–24 | 系统允许最大值 |

**安全范围：** 8–16（超过16触发警告）

## Edge Cases

**1. 多个Hitbox同时命中同一Hurtbox（连招）**
- **如果连招的多个Hitbox空间重叠**：Hitbox级互斥，同一Hitbox对同一Hurtbox只命中一次；不同Hitbox（如连招第1段vs第2段）均可独立命中
- **连招内部重复判定保护**：战斗系统在`hit_cooldown_per_hurtbox`中定义（碰撞系统只提供通道）

**2. 多个来源同时命中**
- 所有命中在同一帧结算，伤害独立叠加，无顺序依赖
- Hitstop可叠加（同时命中=叠加freeze duration）

**3. Hitbox销毁帧检测**
- **销毁帧有效规则**：Hitbox标记为`DESTROYED`后，该帧**仍然参与**碰撞检测；下一帧才从场景树移除
- 实现：不清除`monitoring`，只设置标志，在下一帧`physics_process`中执行`queue_free()`

**4. 帧率波动一致性**
- 固定`physics_ticks_per_second=60`，设置`max_physics_steps_per_frame=2`防止累积延迟
- Godot默认`physics_jitter_fix=0.1`可缓解帧率抖动

**5. 玩家攻击被中断**
- **中断即销毁**：任何导致玩家离开`ATTACKING`状态的事件，立即触发该attack_id下所有Hitbox的despawn
- 玩家状态机在状态转换时调用`HitboxManager.cleanup_by_owner()`

**6. Boss AI感知边界（玩家在探测半径边缘）**
- **双阈值（Hysteresis）**：
  - 进入内圈（r < 0.8×R）→ 立即DETECTED
  - 边界区（0.8R–1.2R）→ 保持上一个状态（debounce）
  - 超出外圈（r > 1.2R）→ 延迟切换为LOST
- `detection_debounce_time`：0.1–0.3s

**7. 碰撞检测与动画/输入时序**
- **动画驱动Hitbox**：动画资源中使用Method Track调用`HitboxManager.spawn_hitbox()`，而非代码驱动
- 动画播放完毕（`animation_finished`）触发despawn
- **禁止**在`_process`中根据输入状态spawn hitbox

## Dependencies

**上游依赖（无 — Foundation层）：**
此系统无上游依赖，是所有其他系统的基础。

**下游依赖（被此系统支撑）：**

| 系统 | 依赖内容 | 接口类型 |
|------|---------|---------|
| 战斗系统 | Hitbox碰撞结果、命中信号 | `hit_confirmed(hitbox, hurtbox, attack_id)` 信号 |
| Combo连击系统 | 命中事件 | `attack_hit(attack_id, is_grounded, hit_count)` 信号 |
| 动画系统 | 命中时机触发动画反应 | `attack_hit(attack_id, is_grounded, hit_count)` 信号 |
| Boss AI系统 | 玩家感知（Proximity/Line-of-Sight） | `player_detected`, `player_lost`, `player_hurt` 信号 |

**接口定义：**

```gdscript
# CollisionManager (Autoload)
signal hit_confirmed(hitbox: Area2D, hurtbox: Area2D, attack_id: int)
signal attack_hit(attack_id: int, is_grounded: bool, hit_count: int)  # → ComboSystem, BossAI
signal player_detected(player: Node2D)
signal player_lost(player: Node2D)
signal player_hurt(player: Node2D, damage: float)

# 方法
func spawn_hitbox(attack_id: String, config: Dictionary) -> Area2D
func despawn_hitbox(hitbox: Area2D) -> void
func cleanup_by_owner(owner: Node2D, attack_id: String) -> void
```

## Tuning Knobs

| 参数 | 默认值 | 安全范围 | 影响 |
|------|-------|---------|------|
| `base_detection_radius` | 256px | 64–512px | AI感知的基础范围，太小=Boss迟钝，太大=无法偷袭 |
| `alertness_multiplier_IDLE` | 0.75 | 0.5–1.0 | Boss待机时感知范围系数 |
| `alertness_multiplier_PATROL` | 1.0 | — | Boss巡逻时感知范围系数 |
| `alertness_multiplier_ALERTED` | 1.5 | 1.2–2.0 | Boss警戒时感知范围系数 |
| `alertness_multiplier_CHASING` | 2.0 | 1.5–3.0 | Boss追击时感知范围系数 |
| `detection_inner_threshold` | 0.8 | 0.7–0.9 | 进入确定性检测的距离比例 |
| `detection_outer_threshold` | 1.2 | 1.1–1.5 | 离开确定性Lost的距离比例 |
| `detection_debounce_time` | 0.2s | 0.1–0.5s | 边界区稳定时间 |
| `hitbox_base_size` | (64, 64)px | (16,16)–(128,128) | Hitbox默认尺寸 |
| `attack_type_multiplier_LIGHT` | 0.6 | — | 轻攻击尺寸系数 |
| `attack_type_multiplier_MEDIUM` | 1.0 | — | 中攻击尺寸系数 |
| `attack_type_multiplier_HEAVY` | 1.5 | — | 重攻击尺寸系数 |
| `attack_type_multiplier_SPECIAL` | 2.0 | — | 特殊攻击尺寸系数 |
| `entity_scale_multiplier_PLAYER` | 1.0 | — | 玩家实体缩放系数 |
| `entity_scale_multiplier_BOSS` | 2.0 | — | Boss实体缩放系数 |
| `max_concurrent_hitboxes` | 13 | 8–20 | 系统允许的最大活跃Hitbox数 |
| `hitbox_pool_size` | 20 | 10–30 | Hitbox对象池预分配大小 |
| `max_physics_steps_per_frame` | 2 | 1–4 | 每帧最大物理步数 |

**可配置性：**
- 以上参数通过 `CollisionManager` Autoload 的 `@export` 变量在编辑器中调整
- 攻击类型系数可通过 `AttackTypeRegistry` 资源文件配置，不硬编码

## Visual/Audio Requirements

碰撞检测系统是Foundation基础设施系统，无直接视觉/音效输出。碰撞事件触发后，由战斗系统和粒子特效系统负责视觉反馈（打击火花、命中特效）和音效反馈（命中音效）。

## UI Requirements

碰撞检测系统无直接UI界面。此系统通过战斗系统的受伤闪烁、Boss血条更新等间接UI反馈呈现。

## Acceptance Criteria

**核心规则测试（27项）：**

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| CR1-01 | 玩家和Boss在场景中，Boss未攻击 | 玩家接近Boss | 玩家CharacterBody检测到Boss（mask包含BOSS层） |
| CR1-02 | 玩家和Boss攻击Hitbox同时存在 | Boss执行攻击 | 玩家CharacterBody检测到BOSS_HITBOX层 |
| CR1-03 | P1的Hitbox与P2的CharacterBody重叠 | 碰撞检测帧 | P2无响应（mask不包含PLAYER_HITBOX） |
| CR1-04 | 玩家在平台上 | 向平台方向移动 | 玩家被平台阻挡（WORLD层） |
| CR2-01 | 玩家发起轻攻击 | 动画播放到攻击帧 | Hitbox Area2D被创建并设为ACTIVE |
| CR2-02 | 攻击动画播放完毕 | animation_finished信号 | Hitbox转入DESTROYED状态，该帧后移除 |
| CR2-03 | PLAYER_HITBOX与BOSS层重叠 | 碰撞检测 | hit_confirmed信号触发 |
| CR2-04 | 同一Hitbox与Hurtbox重叠多帧 | 第一帧后 | 不重复触发命中 |
| CR2-06 | 玩家被打断 | 状态从ATTACKING离开 | 所有相关Hitbox立即despawn |
| CR2-07 | 攻击动画播放中 | 在_process中检测输入尝试spawn | 不应在_process spawn，必须动画驱动 |
| CR3-01 | 玩家站在实心平台 | move_and_slide()后 | is_on_floor()返回true |
| CR3-02 | 玩家从平台跃出 | 空中移动 | is_on_floor()返回false |
| CR4-01 | Boss处于IDLE，玩家进入R=256px | 距离 < 256px | 触发player_detected |
| CR4-02 | 玩家已被检测，现远离 | 距离 > 307px（1.2R） | 延迟0.2s后触发player_lost |
| CR4-03 | 玩家快速进入内圈 | 距离 < 204px（0.8R） | 立即DETECTED |
| CR4-07 | 玩家在掩体后 | Boss ALERTED状态且有遮挡 | los_modifier=0.5，检测范围减半 |

**公式测试（14项）：**

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| F1-01 | base_size=(64,64)，LIGHT攻击，玩家 | 计算尺寸 | hitbox_size=(38.4, 38.4) |
| F1-02 | base_size=(64,64)，HEAVY攻击，Boss | 计算尺寸 | hitbox_size=(192, 192) |
| F3-01 | base_radius=256px，IDLE状态，无遮挡 | Boss检测 | detection_radius=192px |
| F3-02 | base_radius=256px，CHASING状态 | Boss检测 | detection_radius=512px |
| F4-01 | player_count=1, boss_count=1 | 计算上限 | max=12 |
| F4-02 | player_count=2, boss_count=1 | 计算上限 | max=16（超过安全范围，触发警告） |

**边缘情况测试（22项）：**

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| EC1-01 | 连招第1段和第2段覆盖同一Hurtbox | 分别命中 | 两个Hitbox均可独立触发 |
| EC2-01 | P1和P2同时命中同一Boss | 同一帧 | 伤害叠加 |
| EC2-02 | 两攻击同帧命中Boss | 命中帧 | Hitstop叠加 |
| EC3-01 | Hitbox在帧N标记为DESTROYED | 帧N物理检测 | 仍参与检测，命中有效 |
| EC3-02 | 帧N的DESTROYED检测完成 | 帧N+1开始 | queue_free()执行 |
| EC4-01 | 30/60/120fps执行相同移动 | 物理模拟 | 结果一致 |
| EC5-01 | 玩家攻击中被命中进入HURT | 状态切换 | Hitbox立即despawn |
| EC6-04 | 玩家快速穿越边界（<debounce） | 穿越 | 不触发任何变化 |
| EC7-01 | 动画第5帧为命中帧 | 播放到第5帧 | Method Track调用spawn，命中点与动画同步 |

## Open Questions

| # | 问题 | 负责人 | 目标日期 |
|---|------|--------|---------|
| 1 | Hitbox的hitstop持续时间是否需要在碰撞系统定义，还是完全由战斗系统控制？ | Game Designer | 战斗系统GDD时确认 |
| 2 | 攻击类型（LIGHT/MEDIUM/HEAVY/SPECIAL）是否需要扩展为枚举？当前只有4种基础类型 | Game Designer | 战斗系统GDD时确认 |
| 3 | Boss的Line-of-Sight检测是否需要分段RayCast以支持半遮挡场景？ | AI Programmer | Boss AI系统GDD时确认 |
| 4 | 是否需要支持"无敌帧"（i-frames）的碰撞穿透？即玩家无敌状态时不触发hurt_received | Game Designer | 战斗系统GDD时确认 |
