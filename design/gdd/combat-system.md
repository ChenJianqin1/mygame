# 战斗系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 — 协作即意义, Pillar 3 — 战斗即隐喻

## Overview

战斗系统是游戏核心战斗体验的指挥官，承接来自输入系统的动作信号和来自碰撞检测系统的命中结果，计算伤害、击退、硬直等战斗反馈，并分发到UI系统（显示伤害数字）、Combo连击系统（累积连击）和粒子特效系统（播放打击特效）。

本系统的核心职责是将"输入"转化为"战斗结果"——玩家按下攻击键，收到命中反馈，看着伤害数字蹦出。战斗系统决定了战斗的"手感"：伤害够不够爽？击退方向对不对？硬直时间合不合理？这些都是战斗系统的领地。

作为Core层系统，它依赖输入系统和碰撞检测系统，为Combo连击系统，双人协作系统、Boss AI系统提供战斗结果的广播。

## Player Fantasy

**玩家幻想：** 这是每一个曾经坐在办公桌前、梦想把桌子掀翻的人的幻想。战斗是将职场挫败感转化为职场力量的物理表现。你不是在逃避工作——你是在征服它，一次荒诞的Boss战接着一次，最终带着"我证明了自己"的感觉离开。

**情感锚点：**
- **力量感** — 每次命中都是一次小小的"我不只是这些"声明
- **荒诞感** — 职场困境以夸张的视觉和音效呈现，严肃与幽默并存
- **胜利感** — 击败Boss不只是游戏胜利，更是一种"原来我们能扛过去"的隐喻性胜利

**战斗基调：**
- 命中反馈：引人入胜、充满活力，但不是暴力——"slam"、"shatter"、"send flying"，而不是"destroy"、"murder"
- 视觉语言：卡通物理感，像Looney Tunes一样——被击中时弹开、翻滚、旋转
- 合作语言：强化协作支柱——"together"、"synchronized"、"assist"

**反面教材（避免）：**
- 血腥、黑暗视觉风格
- 竞争性语言（"beat"、"defeat"）——这不是玩家对世界的对抗
- 真实伤害——命中应该有冲击力但卡通化

## Detailed Design

### Core Rules

**1. 伤害计算**

```
final_damage = base_damage * attack_type_multiplier * combo_multiplier * weakness_multiplier
```

- **attack_type_multiplier**: LIGHT=0.8, MEDIUM=1.0, HEAVY=1.5, SPECIAL=2.0
- **combo_multiplier**: min(1.0 + combo_count * COMBO_DAMAGE_INCREMENT, MAX_COMBO_MULTIPLIER)
  - COMBO_DAMAGE_INCREMENT = 0.05 (每连击+5%伤害)
  - MAX_COMBO_MULTIPLIER = 3.0 (最高3倍)
- **weakness_multiplier**: 弱点命中=1.5，普通=1.0
- **base_damage**: 由攻击类型定义的基准伤害

**2. 击退（Knockback）机制**

```
knockback_force = base_knockback_by_type[attack_type] * knockback_direction
```

- 击退方向：**远离攻击者位置**（attacker's position → target's position）
- **base_knockback_by_type**: LIGHT=50px, MEDIUM=100px, HEAVY=200px, SPECIAL=300px
- 击退使用线性插值平滑，不突变

**3. Hitstop（命中冻结）机制**

```
hitstop_frames = base_hitstop_by_type[attack_type] + bonus_hitstop_from_target
```

- **base_hitstop_by_type**: LIGHT=3帧, MEDIUM=5帧, HEAVY=8帧, SPECIAL=12帧
- **bonus_hitstop_from_target**: Boss被命中时额外+2帧
- Hitstop期间：两个角色都冻结，粒子特效继续播放
- 双人同时命中：hitstop叠加（而非取最大值）

**4. 防御/减伤机制**

```
incoming_damage = final_damage * (1.0 - defense_rating)
```

- defense_rating范围：0.0–0.8（80%最大减伤）
- 当玩家防御时激活（输入系统dodged信号+按住防御键）
- 防御成功时触发特殊音效和视觉反馈

**5. 闪避机制（i-frames）**

- 闪避激活时：玩家完全无敌，持续DODGE_DURATION帧
- DODGE_DURATION：12帧（200ms @60fps）
- 冷却：DODGE_COOLDOWN = 24帧（400ms）
- 闪避期间可以继续移动

**6. Boss设计（无弱点系统）**

- Boss使用单一Hitbox，扁平血量
- 简化设计——不引入弱点系统以保持节奏流畅

---

### States and Transitions

**玩家实体状态机：**

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| `IDLE` | 待机，可移动和攻击 | 默认/动画结束 | 收到移动或攻击输入 |
| `MOVING` | 移动中 | 有移动输入 | 移动输入结束 |
| `ATTACKING` | 执行攻击动作 | attacked信号 | 攻击动画结束 |
| `HURT` | 受击硬直 | hurt_received信号 | 硬直结束（HURT_DURATION帧） |
| `DODGING` | 闪避无敌帧 | dodged信号 | DODGE_DURATION帧结束 |
| `BLOCKING` | 防御中 | 防御输入+在防御状态 | 防御输入结束或DODGE_DURATION帧 |
| `DOWNTIME` | 倒地/被击倒 | 生命值≤0 | — |

**Boss实体状态机：**

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| `IDLE` | 待机 | 默认/攻击间隔 | AI决定进入攻击 |
| `ATTACKING` | 执行攻击动作 | AI触发 | 攻击动画结束 |
| `HURT` | 受击硬直 | 玩家命中触发 | 硬直结束 |
| `PHASE_CHANGE` | 阶段转换（如有） | 血量低于阈值 | 转换动画结束 |
| `DEFEATED` | 被击败 | 生命值≤0 | 死亡动画播放完毕 |

---

### Interactions with Other Systems

**输入 ← 输入系统：**
- 信号：`attacked(action_type)` — 触发攻击
- 信号：`dodged()` — 触发闪避
- 变量：`move_direction: Vector2` — 当前移动向量

**输入 ← 碰撞检测系统：**
- 信号：`hit_confirmed(hitbox, hurtbox, attack_id)` — 命中发生
- 数据：`attack_id` → 查询attack_type_multiplier

**输出 → Combo连击系统：**
- 信号：`combo_hit(attack_type, combo_count, is_grounded)` — 每次命中时发送

**输出 → Boss AI系统：**
- 信号：`player_attacked(boss, damage)` — 通知Boss被攻击
- Boss AI据此调整行为模式

**输出 → UI系统：**
- 信号：`damage_dealt(damage, target_id, is_critical)` — 显示伤害数字
- 信号：`player_health_changed(current, max)` — 更新玩家血条

**输出 → 粒子特效系统：**
- 信号：`hit_landed(attack_type, position, direction)` — 触发命中特效，direction用于粒子散射方向

## Formulas

**1. 伤害公式**

```
final_damage = base_damage * attack_type_multiplier * combo_multiplier
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_damage | — | int | 8–20 | 攻击类型的基准伤害值 |
| attack_type_multiplier | — | float | {LIGHT:0.8, MEDIUM:1.0, HEAVY:1.5, SPECIAL:2.0} | 攻击类型伤害倍率 |
| combo_multiplier | — | float | 1.0–3.0 | 随连击数累积 |
| **final_damage** | result | int | 6–120 | 最终交付伤害 |

**combo_multiplier计算:**
```
combo_multiplier = min(1.0 + combo_count * 0.05, 3.0)
```

**示例:** HEAVY攻击，连击10: `15 * 1.5 * 1.5 = 34`

---

**2. 击退公式**

```
knockback_force = base_knockback[attack_type] * normalize(target_position - attacker_position)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_knockback | — | float | {LIGHT:50, MEDIUM:100, HEAVY:200, SPECIAL:300} | 基础击退力(px) |
| knockback_direction | — | Vector2 | 单位向量 | 方向=远离攻击者 |
| **knockback_force** | result | Vector2 | 任意方向 | 最终击退向量 |

---

**3. Hitstop公式**

```
hitstop_frames = base_hitstop[attack_type] + bonus_hitstop[target_type]
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_hitstop | — | int | {LIGHT:3, MEDIUM:5, HEAVY:8, SPECIAL:12} | 基础冻结帧数 |
| bonus_hitstop | — | int | {PLAYER:0, BOSS:2, ELITE:1} | 目标额外帧数 |
| **hitstop_frames** | result | int | 3–14 | 总冻结帧数 |

**双人叠加:** 同帧命中(3帧窗口内)可叠加Hitstop

---

**4. 防御减伤公式**

```
incoming_damage = final_damage * (1.0 - defense_rating)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| defense_rating | — | float | 0.0–0.8 | 防御减伤比例 |
| **incoming_damage** | result | int | 1–96 | 实际扣血(最小1) |

---

**5. Boss HP公式**

```
boss_max_hp = floor(BASE_BOSS_HP * progression_multiplier * boss_index_multiplier * coop_scaling)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_BOSS_HP | — | int | 500 | 第一个Boss基准HP |
| progression_multiplier | — | float | 1.0–2.5 | 随进度增长 |
| boss_index_multiplier | — | float | {1.0, 1.3, 1.6, 2.0} | 第1-4个Boss倍率 |
| coop_scaling | — | float | {solo:1.0, co-op:1.5} | 双人缩放 |
| **boss_max_hp** | result | int | 750–3000 | 最终Boss HP |

**示例:** 午后Boss(序号3)双人: `500 * 1.5 * 1.6 * 1.5 = 1800`

## Edge Cases

**1. 零伤害场景（防御减伤至1以下）**
- **如果 defense_rating=0.8（最大），final_damage=6（最小）**：incoming_damage = 6 * 0.2 = 1.2 → 最小扣血为1
- 防御成功时最小扣血为1点，伤害数字仍显示"1"

**2. 极端Combo值（超过MAX_COMBO_MULTIPLIER）**
- combo_count >= 40时，combo_multiplier锁定在3.0
- 超过40连击后combo_count继续累积（用于显示）

**3. 同时命中多个目标**
- 每个目标独立承受full damage——更符合"力量感"幻想

**4. Boss被击败时正在攻击**
- Boss：立即切换DEFEATED，攻击动画被打断
- 玩家：攻击动画完成，但hitbox关闭

**5. 防御和闪避同时触发**
- 闪避优先：`DODGING`状态压制`BLOCKING`，UI显示"闪避中"

**6. 伤害数字溢出**
- 需要定义`damage_cap = 999`，超过则截断

**7. 玩家死亡时连击是否清零**
- 单人独立连击，保留合作策略（一个玩家死亡另一个继续攒连击）

**8. 双人同时攻击同一个Boss**
- 伤害独立叠加，Boss承受P1+P2叠加伤害
- Combo各自独立维护
- 最后一击归属记录用于奖励/成就判定

## Dependencies

**上游依赖（必须存在才能运行）：**

| 系统 | 依赖内容 | 接口类型 |
|------|---------|---------|
| 输入系统 | 动作信号（attacked、dodged）、移动向量 | 信号+变量 |
| 碰撞检测系统 | hit_confirmed信号、spawn_hitbox方法 | 信号+方法 |

**下游依赖（依赖此系统）：**

| 系统 | 依赖内容 | 接口类型 |
|------|---------|---------|
| Combo连击系统 | combo_hit信号、combo_count | 信号 |
| Boss AI系统 | player_attacked信号 | 信号 |
| UI系统 | damage_dealt信号、player_health_changed信号 | 信号 |
| 粒子特效系统 | hit_landed(attack_type, position, direction)信号 | 信号 |

**接口定义：**

```gdscript
# CombatManager (Autoload)

# 输入信号
signal attacked(action_type: String)  # from InputSystem
signal dodged()  # from InputSystem
var move_direction: Vector2  # from InputSystem

# 输出信号
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)  # to ComboSystem
signal player_attacked(target_id: int, damage: int)  # to BossAI
signal damage_dealt(damage: int, target_id: int, is_critical: bool)  # to UI
signal player_health_changed(current: int, max: int)  # to UI
signal hit_landed(attack_type: String, position: Vector2, direction: Vector2)  # to VFX (direct, not via Events)

# 方法
func calculate_damage(base: int, attack_type: String, combo: int) -> int
func apply_knockback(target: Node2D, force: Vector2)
func trigger_hitstop(frames: int)
```

## Tuning Knobs

| 参数 | 默认值 | 安全范围 | 影响 |
|------|-------|---------|------|
| `base_damage` | 15 | 5–30 | 基础伤害基准，太高=Boss秒杀玩家，太低=刮痧感 |
| `attack_type_multiplier_LIGHT` | 0.8 | 0.5–1.2 | 轻攻击倍率 |
| `attack_type_multiplier_MEDIUM` | 1.0 | 0.8–1.5 | 中攻击倍率 |
| `attack_type_multiplier_HEAVY` | 1.5 | 1.2–2.5 | 重攻击倍率 |
| `attack_type_multiplier_SPECIAL` | 2.0 | 1.5–3.0 | 特殊攻击倍率 |
| `COMBO_DAMAGE_INCREMENT` | 0.05 | 0.01–0.1 | 每连击伤害增量，太高=滚雪球，太低=连击无意义 |
| `MAX_COMBO_MULTIPLIER` | 3.0 | 2.0–5.0 | 连击伤害上限 |
| `MAX_COMBO_COUNT` | 99 | 50–999 | 连击计数上限（影响显示） |
| `base_knockback_LIGHT` | 50px | 20–100px | 轻攻击击退力 |
| `base_knockback_MEDIUM` | 100px | 50–200px | 中攻击击退力 |
| `base_knockback_HEAVY` | 200px | 100–400px | 重攻击击退力 |
| `base_knockback_SPECIAL` | 300px | 200–600px | 特殊攻击击退力 |
| `base_hitstop_LIGHT` | 3帧 | 1–6帧 | 轻攻击冻结帧数 |
| `base_hitstop_MEDIUM` | 5帧 | 3–10帧 | 中攻击冻结帧数 |
| `base_hitstop_HEAVY` | 8帧 | 5–15帧 | 重攻击冻结帧数 |
| `base_hitstop_SPECIAL` | 12帧 | 8–20帧 | 特殊攻击冻结帧数 |
| `bonus_hitstop_BOSS` | 2帧 | 0–5帧 | Boss被命中额外冻结 |
| `DODGE_DURATION` | 12帧 | 8–20帧 | 闪避无敌持续时间 |
| `DODGE_COOLDOWN` | 24帧 | 12–48帧 | 闪避冷却时间 |
| `MAX_DEFENSE_RATING` | 0.8 | 0.5–0.95 | 最大防御减伤比例 |
| `DAMAGE_CAP` | 999 | 100–9999 | 伤害上限 |
| `BASE_BOSS_HP` | 500 | 300–1000 | 基准Boss血量 |
| `coop_scaling` | 1.5x | 1.0–2.0 | 双人合作Boss血量缩放 |

## Visual/Audio Requirements

**核心艺术原则：**
- 所有打击能量用**便签/纸张碎屑**承载（拒绝血液/金属碎片）
- P1配色#F5A623（晨曦橙）/ P2配色#4ECDC4（梦境蓝）贯穿所有VFX
- 手绘质感：勾线用#3D2914，保留笔触可见性

**命中特效（Hit Effects）：**

| 攻击类型 | 粒子形态 | 色彩 |
|---------|---------|------|
| 轻攻击命中 | 小纸片飞散(1-3px) | #FFE66D便签黄 |
| 重攻击命中 | 整张便签撕裂+旋转 | #F5A623→#FF4757渐变 |
| Combo满级 | 纸张燃烧金色火星 | #FFD700金色 |
| 弱点命中 | 眼镜框光晕脉冲 | #7B68EE紫色脉冲 |

**屏幕反馈：**
- Hitstop：轻攻击4-8帧 / 重攻击10-15帧
- 屏幕震动：轻攻击2px振幅3帧 / 重攻击4-6px振幅6帧
- 边缘光效：命中方向闪过角色代表色

**防御视觉：**
- 完美防御：纸张光环爆发+屏幕闪白
- 普通防御：便签环绕角色#4ECDC4光晕
- 协作防御：连接线闪金光环

**闪避视觉：**
- 无敌闪避：角色化作残影消失，晨曦橙/梦境蓝淡化残影
- 轨迹效果：位移路径留下便签纸飘落轨迹

## UI Requirements

战斗系统对UI的需求：
- **伤害数字**：显示在命中点上方，颜色随Combo升级变化
- **Boss血条**：位于屏幕顶部中央，显示当前HP/最大HP
- **玩家血条**：分列屏幕底部两侧，各自显示P1/P2血量
- **连击计数器**：屏幕中央显示当前连击数，字体随Combo放大
- **防御/闪避图标**：冷却状态时显示倒计时

**UI更新信号：**
- `damage_dealt(damage, target_id, is_critical)` — 伤害数字显示
- `player_health_changed(current, max)` — 血条更新

## Acceptance Criteria

**核心规则测试（52项）：**

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-DMG-001 | IDLE状态，base_damage=15 | LIGHT攻击命中无连击Boss | final_damage = 15 * 0.8 = **12** |
| AC-DMG-003 | base_damage=15 | HEAVY攻击命中 | final_damage = 15 * 1.5 = **23** |
| AC-DMG-010 | combo_count=0 | 计算combo_multiplier | 1.0 |
| AC-DMG-012 | combo_count=40 | 计算combo_multiplier | 3.0（上限） |
| AC-DMG-020 | HEAVY+连击10 | 计算final_damage | 15 * 1.5 * 1.5 = **34** |
| AC-KB-001 | 攻击者(100,0)，目标(200,0) | 计算击退方向 | normalize((200-100,0)) = **(1,0)** |
| AC-KB-010 | LIGHT攻击，方向(1,0) | 计算knockback_force | 50 * (1,0) = **(50, 0)** |
| AC-HS-001 | attack_type=LIGHT | 计算hitstop_frames | 3帧 |
| AC-HS-004 | attack_type=SPECIAL | 计算hitstop_frames | 12帧 |
| AC-HS-010 | LIGHT命中BOSS | 计算hitstop_frames | 3 + 2 = **5帧** |
| AC-DEF-001 | final_damage=50，defense_rating=0.0 | 计算incoming_damage | 50 |
| AC-DEF-003 | final_damage=6，defense_rating=0.8 | 计算incoming_damage | **1**（最小值保护） |
| AC-DOD-001 | 玩家按下闪避键 | 触发DODGING | 持续12帧后退出 |
| AC-DOD-020 | 玩家在DODGING状态 | Boss攻击命中 | 玩家不受到伤害 |
| AC-BHP-001 | 第1Boss单人 | 计算boss_max_hp | floor(500*1.0*1.0*1.0) = **500** |
| AC-BHP-010 | 午后Boss(序号3)双人 | 计算boss_max_hp | floor(500*1.5*1.6*1.5) = **1800** |
| AC-EDGE-001 | final_damage=6，defense=0.8 | 计算incoming_damage | **1**（不是0） |
| AC-EDGE-003 | combo_count=100 | 计算combo_multiplier | **3.0**（锁定上限） |
| AC-STATE-001 | IDLE | attacked(LIGHT) | ATTACKING |
| AC-STATE-003 | IDLE | dodged() | DODGING |

## Open Questions

| # | 问题 | 负责人 | 目标日期 |
|---|------|--------|---------|
| 1 | 防御是否需要消耗体力/耐力？当前设计是无消耗纯粹操作 | Game Designer | 战斗系统验证时确认 |
| 2 | Boss是否有阶段转换（phase change）机制？当前无弱点但可能有阶段 | Boss AI系统GDD时确认 |
| 3 | 攻击类型的数量是否足够？当前4种是否满足设计需求 | Game Designer | 战斗系统验证时确认 |

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
