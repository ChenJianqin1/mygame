# 动画系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-17
> **Implements Pillar**: Pillar 3 — 战斗即隐喻, Pillar 4 — 轻快节奏

## Overview

动画系统是游戏视觉表现的核心驱动——它将战斗信号、Boss AI状态和玩家输入转化为角色和Boss的动画表现。系统管理所有角色动画状态机、骨架/精灵帧资源、动画混合和过渡。战斗系统的攻击（LIGHT/MEDIUM/HEAVY/SPECIAL）和Boss AI的阶段变化（Phase 1/2/3）驱动状态转换，动画系统负责让这些转换有手绘纸偶剧场的质感。

## Player Fantasy

我们就是那个能把老板的PPT撕成纸片的卡通二人组。Slapstick Comedy Duo的核心在于：玩家1是快速戳刺的灵巧型（高频小动作），玩家2是弧形挥舞的力量型（大开大合），两者都有Looney Tunes式的夸张预备帧（ anticipation）和弹回（overshoot）。Boss则是一团压迫的几何形状——它的动画越僵硬越有压迫感，崩溃时碎成便签纸片越有释放感。动画系统要让每次攻击有"前一帧还没动、后一帧已经打中"的错觉，同步连击时要让两个角色的动画像镜像一样同步放大，产生"我们在一起就是一整套"的满足感。

## Detailed Design

### Core Rules

#### Animation Philosophy

动画系统遵循以下核心原则来实现"手绘纸偶剧场 + Slapstick Comedy"的感觉：

**原则1：帧经济性（Frame Economy）**
所有攻击动画遵循3-1-2比例分配（anticipation : active : recovery）。每帧都有明确目的——anticipation建立张力，active打中目标，recovery创造破绽。帧数直接来源于战斗系统的hitstop数值。

**原则2：可变速度分层（Variable Speed Layering）**
动画以30fps有效速率运行（60fps物理步进 × speed_scale=0.5）。打击帧瞬间提速至120fps（speed_scale=2.0）创造"啪"的感觉。这创造Looney Tunes式的夸张弹性。

**原则3：纸张质感分层（Paper Texture Layers）**
每个角色由两层构成：底层是主要色块精灵（P1=#F5A623晨曦橙，P2=#4ECDC4梦境蓝），顶层是纸张纹理叠加层（noise_offset实现微抖动）。撕裂边缘通过粒子特效系统实现，不依赖精灵变形。

**原则4：帧锁 hitbox（Frame-Locked Hitbox）**
Hitbox激活时机是动画轨道上的关键帧，不是计时器。动画师在"active"阶段的第一帧设置关键帧值，战斗系统读取该值来决定是否触发伤害。

**原则5：VFX驱动的Boss形变**
Boss从僵硬→颤抖→狂乱的视觉变化主要由VFX（屏幕震动、粒子抖动）实现，而非关键帧动画。这保持Boss作为"几何压迫"的抽象感，同时崩溃时便签爆炸有强烈的视觉释放。

#### API架构

混合方案：AnimatedSprite2D + AnimationPlayer + AnimationTree

| 组件 | 用途 | 为什么用它 |
|------|------|-----------|
| AnimatedSprite2D | Looney Tunes式逐帧循环（anticipation/overshoot） | 艺术家友好，精灵表处理成熟 |
| AnimationPlayer + Sprite2D | 程序化变换，hitbox联动姿势 | 精确属性控制，advance()逐帧步进 |
| AnimationTree + BlendTree | 同步攻击，相位过渡，层叠状态 | 状态间平滑混合 |

> **Godot 4.6注意**：`playback_active`在4.3+已废弃。使用`AnimationMixer.active`。2D精灵不做骨骼混合——BlendTree用alpha-crossfade实现过渡。

#### 动画资源结构

```
assets/animations/
  players/
    player1/
      player1_idle.tres              # SpriteFrames
      player1_attack_light.tres
      player1_attack_medium.tres
      player1_attack_heavy.tres
      player1_attack_special.tres
      player1_hit.tres
      player1_rescue.tres
      player1_animation_tree.tres   # AnimationTree resource
    player2/ (同上结构)
  boss/
    deadline_boss/
      deadline_boss_idle.tres
      deadline_boss_attack_a.tres    # Phase 1 pattern
      deadline_boss_rage.tres         # Phase 2 pattern
      deadline_boss_crisis.tres       # Phase 3 pattern
      deadline_boss_defeat.tres
      deadline_boss_animation_tree.tres
  effects/
    hit_sparks.tres
    sync_glow.tres
```

#### 纸张质感实现细节

- 纸张纹理叠加层：独立的TextureRect或Sprite2D，覆盖在角色精灵上层，opacity=0.15，使用noise shader实现微抖动
- 撕裂边缘：粒子特效系统驱动，animation系统在其上触发`hit_vfx` emitter
- 角色各层Z轴顺序：角色主精灵=20(30), 纸张纹理叠加层=+1, 特效=+10
- squash/stretch：通过Sprite2D.scale的AnimationPlayer轨道实现，每帧设置scale关键帧

---

### States and Transitions

#### 玩家动画状态机

**状态列表：**

| 状态 | 描述 | 攻击子状态 |
|------|------|-----------|
| IDLE | 站立待机 | — |
| MOVE | 行走/奔跑 | — |
| LIGHT_ATTACK | 轻攻击执行中 | anticipation / active / recovery |
| MEDIUM_ATTACK | 中攻击执行中 | anticipation / active / recovery |
| HEAVY_ATTACK | 重攻击执行中 | anticipation / active / recovery |
| SPECIAL_ATTACK | 特殊攻击执行中 | anticipation / active / recovery |
| HURT | 受创硬直 | — |
| RESCUE | 执行救援 | — |
| SYNC_ATTACK | 视觉包装器（非独立状态） | — |
| DEFEAT | 玩家倒下/倒下状态（DOWNTIME别名，详见协作系统） | — |

**完整转换表：**

```
FROM \ TO   | IDLE | MOVE | LIGHT | MEDIUM | HEAVY | SPECIAL | HURT | RESCUE | SYNC | DEFEAT |
------------|------|------|-------|--------|-------|---------|------|--------|------|--------|
IDLE        | —    | Yes  | Yes   | Yes    | Yes   | Yes     | Yes* | Yes    | Yes  | Yes*   |
MOVE        | Yes  | —    | Yes   | Yes    | Yes   | Yes     | Yes* | No     | Yes  | Yes*   |
LIGHT       | Yes+ | No   | No**  | No**   | No**  | No**    | Yes* | No     | No   | Yes*   |
MEDIUM      | Yes+ | No   | No**  | No**   | No**  | No**    | Yes* | No     | No   | Yes*   |
HEAVY       | Yes+ | No   | No**  | No**   | No**  | No**    | Yes* | No     | No   | Yes*   |
SPECIAL     | Yes+ | No   | No**  | No**   | No**  | No**    | Yes* | No     | No   | Yes*   |
HURT        | Yes  | Yes  | No    | No     | No    | No      | No   | No     | No   | Yes    |
RESCUE      | No   | No   | No    | No     | No    | No      | Yes* | No     | No   | Yes*   |
SYNC_ATTACK | Yes+ | No   | No    | No     | No    | No      | Yes* | No     | No   | Yes*   |
DEFEAT      | No   | No   | No    | No     | No    | No      | No   | No     | No   | No     |

Yes  = 合法转换
Yes* = 强制转换（受创等中断）
Yes+ = 仅在recovery帧结束后合法
No   = 非法转换
No** = 仅在anticipation阶段非法（见中断规则）
```

**攻击中断规则：**

规则A — anticipation阶段快速攻击可中断慢速攻击：

| 攻击方处于... | 可中断目标的... | 阶段限制 |
|-------------|----------------|---------|
| LIGHT anticipation | MEDIUM anticipation | anticipation阶段 |
| LIGHT anticipation | HEAVY anticipation | anticipation阶段 |
| LIGHT anticipation | SPECIAL anticipation | anticipation阶段 |
| MEDIUM anticipation | HEAVY anticipation | anticipation阶段 |
| MEDIUM anticipation | SPECIAL anticipation | anticipation阶段 |
| HEAVY anticipation | SPECIAL anticipation | anticipation阶段 |

一旦进入**active**或**recovery**阶段，任何攻击不可被其他攻击中断（除HURT强制中断）。

规则B — HURT中断一切：
- HURT是强制转换，来自战斗系统的`hurt_received`信号
- HURT可中断任何状态：IDLE、MOVE、所有攻击状态（任何阶段）、RESCUE、SYNC_ATTACK
- HURT拥有最高优先级，无动画锁可覆盖受创
- 例外：HURT不中断DEFEAT（已倒地的无法再倒地）

规则C — 禁止自中断：
- 玩家不能从LIGHT_ATTACK直接转回LIGHT_ATTACK
- 任何攻击的recovery帧结束后，玩家必须回到IDLE才能发起新攻击
- 例外：SYNC_ATTACK可通过连击系统同步窗口触发，跟在任何攻击后

**攻击相位时序表（所有动画60fps）：**

| 攻击类型 | anticipation | active | recovery | 总帧数 | 总时长 |
|----------|-------------|--------|----------|--------|--------|
| LIGHT | 8帧 | 2帧 | 6帧 | **16帧** | ~267ms |
| MEDIUM | 14帧 | 3帧 | 10帧 | **27帧** | ~450ms |
| HEAVY | 20帧 | 4帧 | 16帧 | **40帧** | ~667ms |
| SPECIAL | 28帧 | 6帧 | 24帧 | **58帧** | ~967ms |

> 帧率：所有动画以60fps运行（Godot 4.6，@tool一致）。anticipation帧为玩家输入锁定——无缓冲，无中断。active帧：hitbox激活，可造成伤害。recovery帧：角色处于破绽状态，不可发起新攻击，可移动/转向。

---

#### Boss动画状态机

**相位1状态（HP 100%-60%）：**

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| BOSS_IDLE | 有节制的呼吸，纸张颤动 | 默认/攻击结束 | AI选择攻击 |
| BOSS_ATTACK_A | 攻击模式A——压迫推进 | AI决策 | 动画完成 |
| BOSS_ATTACK_B | 攻击模式B（预留） | AI决策 | 动画完成 |
| BOSS_VULNERABLE | 受创后短暂踉跄 | 玩家命中注册 | 持续时间结束（~24帧） |

**相位2增加（HP 60%-30%）：**

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| BOSS_RAGE_ATTACK | 攻击模式2——便签雪崩 | AI决策 | 动画完成 |
| BOSS_PHASE_TRANSITION | 过渡到相位2 | HP穿越60% | ~60帧（~1.0s） |

**相位3增加（HP 30%-0%）：**

| 状态 | 描述 | 进入条件 | 退出条件 |
|------|------|---------|---------|
| BOSS_CRISIS_MODE | 攻击模式3——恐慌过载+紊乱移动 | HP穿越30% | Boss被击败 |
| BOSS_DEFEAT | 崩溃动画——Boss碎裂成便签纸片 | HP归零 | 动画完成（~90帧/1.5s） |

**Boss僵硬感进阶（视觉特性，非关键帧动画）：**

| 相位 | anticipation帧数 | 曲线 | 视觉特征 | 攻击间隔 |
|------|----------------|------|---------|---------|
| Phase 1 | 24-30帧 | 平滑ease-in-out | 有节制的纸张沙沙声 | 2.5s基准 |
| Phase 2 | 18-24帧 | 略急促 | 轻微垂直抖动 | 2.0s基准 |
| Phase 3 | 12-18帧 | 急促/线性 | 全身颤抖，更快循环 | 1.5s基准 |

> Boss的"僵硬感"主要由VFX（屏幕震动+粒子抖动）实现，不是逐帧关键帧动画。这保持Boss作为"压迫几何形状"的抽象感。Phase 1 = "有节制"，Phase 2 = "紊乱"，Phase 3 = "绝望/颤抖"。

**Boss状态转换表：**

```
FROM \ TO       | IDLE | ATTACK_A | ATTACK_B | VULNERABLE | RAGE | PHASE_TRANS | CRISIS | DEFEAT |
----------------|------|----------|----------|------------|------|-------------|--------|--------|
BOSS_IDLE       | —    | Yes      | Yes      | Yes*       | Yes  | No          | No     | Yes**  |
BOSS_ATTACK_A   | Yes  | No       | No       | No         | No   | No          | No     | Yes**  |
BOSS_ATTACK_B   | Yes  | No       | No       | No         | No   | No          | No     | Yes**  |
BOSS_VULNERABLE | Yes  | No       | No       | No         | No   | No          | No     | Yes**  |
BOSS_RAGE_ATTACK| Yes  | No       | No       | No         | No   | No          | No     | Yes**  |
BOSS_PHASE_TRANS| No   | No       | No       | No         | No   | —           | Yes    | Yes**  |
BOSS_CRISIS     | No***| No***    | No***    | Yes*       | No   | No          | —      | Yes**  |
BOSS_DEFEAT     | No   | No       | No       | No         | No   | No          | No     | No     |

Yes  = 合法转换
Yes* = 强制（玩家命中注册 → VULNERABLE，与当前状态无关）
Yes** = 强制（HP <= 0 → DEFEAT，任意状态）
No   = 非法转换
No*** = CRISIS状态锁定Boss在攻击动画中直至完成
```

---

#### 同步攻击——视觉包装器模型

SYNC_ATTACK**不是独立的状态机**。它是现有攻击状态的视觉增强层：

**触发流程：**
1. ComboSystem检测到SYNC_WINDOW（5帧内P1和P2均命中）→ 发射`sync_burst_triggered`信号
2. 动画系统接收信号，两名玩家保留各自的LIGHT/MEDIUM/HEAVY/SPECIAL攻击子状态
3. 视觉增强层被应用：双色彩虹光晕（P1=#F5A623橙色 + P2=#4ECDC4蓝色）交织粒子轨迹，屏幕边缘交替橙色/蓝色脉冲
4. 攻击hitbox略微放大（+15%半径）作为视觉奖励提示

**"同步蓄力"视觉（当P1命中而P2仍在anticipation时）：**
- P2的anticipation动画获得"同步蓄力"光晕
- 蓄力光晕随P2接近active帧而增强
- 如果P2在5帧窗口内命中：爆发特效触发
- 如果P2错过5帧窗口：光晕消散，P2的攻击判定为SOLO

---

#### 救援动画序列

**倒地玩家（downtime_loop）：**

| 属性 | 值 | 来源 |
|------|---|------|
| 动画名 | downtime_loop | — |
| 持续时间 | 180帧（3.0s）— 循环直至救援或OUT | 匹配RESCUE_WINDOW |
| 视觉效果 | 玩家平躺，慢速纸张颤动，去饱和颜色 | Coop系统GDD |
| 颜色 | 幽灵状去饱和（玩家原本颜色#F5A623或#4ECDC4） | Coop系统GDD |
| 碰撞体 | 关闭（无hitbox，完全可被攻击） | Coop系统边缘情况 |

**救援者动画序列：**

| 阶段 | 动画 | 持续时间 | 视觉 |
|------|------|---------|------|
| RESCUE_APPROACH | 跑向倒地队友 | 直至进入RESCUE_RANGE | 正常奔跑，手部光晕在50% |
| RESCUE_EXECUTE | 伸手 | 12帧（~200ms） | 手部光晕100%，救援者颜色 |
| RESCUE_REVIVE | 拉起队友 | 18帧（~300ms） | 队友起身，纸片火花爆发（8-12粒子） |
| 返回IDLE | 恢复正常游玩 | — | 队友进入RESCUED（无敌帧）状态 |

**时序容差：** 如果P2在t=2.95s（窗口前50ms）按下救援，救援仍被触发——REVIVE动画作为原子事件要么完成要么不完成。

**救援后无敌帧（RESCUED_IFRAMES）：**

| 属性 | 值 | 来源 |
|------|---|------|
| 动画名 | rescued_invincible | — |
| 持续时间 | 90帧（1.5s） | RESCUED_IFRAMES_DURATION，Coop系统 |
| 视觉效果 | 角色周围柔和脉冲光晕，颜色饱和度70% | Coop系统GDD |
| 无敌帧 | 完全减伤——所有伤害无效 | Coop系统规则2 |
| 状态 | 90帧后从RESCUED回到IDLE | Coop系统状态表 |

---

### Interactions with Other Systems

#### 信号契约——动画系统消费

```gdscript
# 来自战斗系统
signal attack_started(attack_type: String, player_id: int)   # 触发攻击子状态机
signal hurt_received(player_id: int)                         # 强制HURT转换

# 来自连击系统
signal sync_window_opened(player_id: int, partner_id: int)  # anticipation上"待同步"光晕
signal sync_burst_triggered(position: Vector2)               # 完整同步爆发VFX
signal combo_tier_escalated(tier: int, player_color: Color) # 基于阶级的动画强度

# 来自协作系统
signal player_downed(player_id: int)         # 进入DOWNTIME
signal rescue_triggered(rescuer_id: int, downed_id: int)  # 进入RESCUE
signal player_rescued(player_id: int, rescuer_color: Color)  # 被救玩家 → RESCUED
signal player_out(player_id: int)            # DOWNTIME超时

# 来自BossAI系统
signal boss_state_changed(new_state: String) # Boss FSM转换
signal boss_phase_changed(new_phase: int)     # Phase 1→2→3，触发僵硬感变化
signal boss_hp_changed(current: int, max: int)  # HP条同步
```

#### 信号契约——动画系统发射

```gdscript
# 发射至战斗系统
signal animation_state_changed(player_id: int, state: String)  # hitbox激活时机同步
signal recovery_complete(player_id: int)  # 玩家可再次行动

# 发射至VFX/粒子特效系统
signal hitbox_activated(attack_type: String, position: Vector2)  # 生成hitbox VFX
signal sync_burst_visual(position: Vector2)  # 橙蓝交织粒子
```

#### 信号接线架构

推荐方案：**直接节点引用**（非Autoload）

```gdscript
# In AnimationSystem node
@onready var player1_tree: AnimationTree = %Player1AnimationTree
@onready var player2_tree: AnimationTree = %Player2AnimationTree

func _ready() -> void:
    CombatSystem.connect("attack_started", _on_attack_started)
    ComboSystem.connect("sync_burst_triggered", _on_sync_burst)
    CoopSystem.connect("player_downed", _on_player_downed)

func _on_attack_started(attack_type: String, player_id: int) -> void:
    var tree: AnimationTree = player1_tree if player_id == 1 else player2_tree
    tree["parameters/AttackBlend/blend_amount"] = 1.0  # 触发到攻击状态的混合
```

> **Godot 4.6 Callable语法**：`some_signal.connect(_on_signal_received)`（4.0+正确语法，无第二个参数）

#### 性能基准

| 指标 | 预算 | 说明 |
|------|------|------|
| 精灵/纹理内存 | ~24MB（2玩家+Boss） | 含粒子纹理约40MB |
| 同屏角色数 | 3（低风险） | 2玩家+Boss，无需优化 |
| 离屏角色优化 | 6+时启用 | VisibleOnScreenNotifier2D暂停动画 |
| 粒子系统 | 20个预实例化emitter | 来自粒子特效系统GDD |

## Formulas

### D.1 攻击动画时长公式

每种攻击类型对应帧数由战斗系统的hitstop值决定（见战斗系统GDD公式4）：

```
animation_duration(attack_type) = anticipation_frames(attack_type) + active_frames(attack_type) + recovery_frames(attack_type)
```

| 攻击类型 | anticipation | active | recovery | 总时长 |
|----------|-------------|--------|----------|--------|
| LIGHT | 8 | 2 | 6 | 16帧 ≈ 267ms |
| MEDIUM | 14 | 3 | 10 | 27帧 ≈ 450ms |
| HEAVY | 20 | 4 | 16 | 40帧 ≈ 667ms |
| SPECIAL | 28 | 6 | 24 | 58帧 ≈ 967ms |

### D.2 Hitbox激活帧公式

```
hitbox_first_active_frame(attack_type) = anticipation_frames(attack_type)
hitbox_last_active_frame(attack_type) = anticipation_frames(attack_type) + active_frames(attack_type) - 1
```

验证示例（HEAVY）：第一帧 = 20，最后一帧 = 20 + 4 - 1 = 23 ✓

### D.3 恢复完成时刻

```
recovery_complete_frame(attack_type) = animation_duration(attack_type) - 1
recovery_complete_ms(attack_type) = recovery_complete_frame × (1000 / 60)
```

验证示例（HEAVY）：recovery_complete_frame = 39，recovery_complete_ms ≈ 650ms

### D.4 同步蓄力混合因子

当P1命中而P2处于anticipation阶段时，P2的anticipation动画应用同步蓄力混合：

```
sync_charge_blend(P2) = clamp((P1_hit_time - P2_anticipation_start_time) / SYNC_WINDOW_DURATION, 0.0, 1.0)
```

其中：
- SYNC_WINDOW_DURATION = 5帧 ≈ 83ms（来自ComboSystem）
- sync_charge_blend从0.0（无蓄力）到1.0（即将爆发）

### D.5 Boss相位转换动画时长

| 转换 | 时长 | 说明 |
|------|------|------|
| Phase 1 → Phase 2 | 60帧 ≈ 1.0s | 固定值 |
| Phase 2 → Phase 3 | 60帧 ≈ 1.0s | 固定值 |
| → BOSS_DEFEAT | 90帧 ≈ 1.5s | 崩溃便签碎片动画 |

### D.6 救援动画序列时长

```
RESCUE_EXECUTE = 12帧 ≈ 200ms
RESCUE_REVIVE = 18帧 ≈ 300ms
RESCUE_TOTAL = 30帧 ≈ 500ms
downtime_loop = RESCUE_WINDOW = 180帧 = 3.0s（循环）
rescued_iframes = RESCUED_IFRAMES_DURATION = 90帧 ≈ 1.5s
```

**时序约束验证**：
```
P2_rescue_start_deadline = RESCUE_WINDOW - RESCUE_TOTAL
                           = 3.0s - 0.5s
                           = 2.5s

P2须在t=2.5s前开始RESCUE_APPROACH，动画序列才能在窗口内完成 ✓
```

### D.7 同步视觉参数

| 参数 | 值 | 说明 |
|------|---|------|
| sync_glow_radius_multiplier | 1.15 | 同步时hitbox略微放大（+15%） |
| sync_particle_count | 12 | 橙蓝交织粒子数 |
| screen_edge_pulse_frequency | 2Hz | 屏幕边缘脉冲频率 |

## Edge Cases

### E-1：HURT中断anticipation阶段

**触发**：玩家在攻击anticipation阶段收到`hurt_received`信号。

**处理**：
- 立即从anticipation切换到HURT状态
- anticipation动画停止，播放HURT动画
- 攻击尝试被消耗——HURT结束后**不恢复**anticipation

**后果**：该次攻击被完全取消，不造成伤害，不计入连击。

---

### E-2：HURT中断active阶段

**触发**：玩家在攻击active阶段收到`hurt_received`信号。

**处理**：
- Hitbox立即停用（无延迟命中）
- HURT动画播放
- 触发HURT的该次命中仍然计入连击（根据Combo系统规则：受到伤害不重置连击数）

**后果**：攻击造成了一次命中，但攻击者进入破绽状态。

---

### E-3：Boss被击败时玩家处于active攻击状态

**触发**：Boss HP归零，而玩家攻击的active阶段尚未结束。

**处理**（来自战斗系统边缘情况）：
- 玩家攻击动画播放至完成
- 但hitbox在Boss DEFEAT信号发射时立即关闭
- 玩家无法在Boss已死后造成命中

**动画处理**：动画完成，但视觉上Boss已经进入崩溃便签状态——这实际上是正确的"我们赢了"的视觉节奏。

---

### E-4：同步蓄力——P1命中P2仍在anticipation

**触发**：P1在active帧命中，P2仍在anticipation阶段，且两人命中时差在SYNC_WINDOW（5帧）内。

**处理**：
- P1的攻击正常播放（active帧 → recovery）
- P2的anticipation动画应用"同步蓄力"光晕
- 如果P2在5帧内命中anticipation→active并命中：同步爆发触发，P1和P2的攻击均获得同步视觉增强
- 如果P2错过5帧窗口：P1的攻击判定为SOLO（无同步），P2的蓄力光晕消散

---

### E-5：救援者在RESCUE_APPROACH途中受创

**触发**：P2正在向倒地的P1跑近（RESCUE_APPROACH），此时P2收到`hurt_received`信号。

**处理**（来自Coop系统边缘情况1）：
- P2强制切换到HURT状态，RESCUE被取消
- P1继续播放downtime_loop动画
- 救援计时器（RESCUE_WINDOW=3.0s）**不暂停**，继续计时

**后果**：如果P2在窗口后期受创，可能来不及再次发起救援。

---

### E-6：两名玩家同时倒地（同一帧）

**触发**：两名玩家在同一帧各自HP归零（同时受到致命伤害）。

**处理**（来自Coop系统规则1）：
- 两名玩家同时进入DEFEAT状态
- 无法互相救援
- 游戏失败/生命数减少被触发
- 无救援动画播放

---

### E-7：Boss相位转换期间攻击动画仍在播放

**触发**：Boss在Phase 1→2或Phase 2→3的转换期间，Boss有一个攻击动画正在播放。

**处理**（来自Boss AI系统规则5）：
- Boss保持当前攻击状态直至动画完成
- 新的相位规则适用于**下一次**攻击选择
- 相位转换动画（BOSS_PHASE_TRANSITION）只在新攻击选择**之后**播放

---

### E-8：Boss在active攻击期间受到玩家命中

**触发**：Boss正在执行BOSS_ATTACK_A/B/RAGE/CRISIS时，玩家命中注册。

**处理**（来自Boss AI系统规则4）：
- Boss保持在当前攻击状态
- Hitbox保持激活（攻击不中断）
- BOSS_VULNERABLE状态**不在攻击进行中进入**，而是等攻击动画完成后才转换

---

### E-9：玩家在recovery帧期间输入攻击

**触发**：玩家处于某个攻击的recovery阶段，此时玩家再次按下攻击键。

**处理**：
- 输入在动画系统层被忽略/锁定
- 动画系统检测`recovery_complete`信号后才开放新攻击输入
- 这保持了攻击之间的有节奏感的"呼吸"时间

---

### E-10：帧跳帧（Lag Spike）期间帧锁hitbox行为

**触发**：游戏遭遇帧跳帧（如大量粒子同时生成），导致动画Advance()调用延迟。

**处理**：
- 帧锁hitbox设计：hitbox激活是动画轨道上的关键帧值，不是独立计时器
- 如果动画Advance()延迟，hitbox激活也延迟——不会有"帧锁但视觉提前"的bug
- 视觉与逻辑仍然同步，hitbox不会在对应视觉帧之前激活

**风险**：Lag Spike期间可能发生"视觉已经击中但hitbox还没激活"——玩家会看到攻击动作但没有伤害数字。这是可以接受的设计选择。

## Dependencies

### 上游依赖（动画系统消费）

| 依赖系统 | 依赖原因 | 接口 |
|---------|---------|------|
| 战斗系统 | 攻击类型、攻击开始/受创信号 | 消费：`attack_started`，`hurt_received` |
| 碰撞检测系统 | 命中时机（来自碰撞检测，不来自战斗系统） | 消费：`attack_hit(attack_id, is_grounded, hit_count)` |
| 连击系统 | 同步攻击触发、连击 tier 变化 | 消费：`sync_burst_triggered`，`combo_tier_escalated` |
| 双人协作系统 | 倒地/救援/被救/OUT 信号 | 消费：`player_downed`，`rescue_triggered`，`player_rescued`，`player_out` |
| Boss AI系统 | Boss 状态/相位变化 | 消费：`boss_state_changed`，`boss_phase_changed`，`boss_hp_changed` |

### 下游依赖（依赖动画系统）

| 依赖系统 | 依赖原因 | 接口 |
|---------|---------|------|
| 战斗系统 | 动画状态变化驱动 hitbox 时序 | 发射：`animation_state_changed`，`recovery_complete` |
| 粒子特效系统 | 动画关键帧触发 VFX emitter | 发射：`hitbox_activated`，`sync_burst_visual` |
| UI系统 | 动画系统可能需要显示某些状态（如连击 tier 变化） | 接口待确认（见开放问题） |
| 音频系统 | 动画关键帧触发音效（攻击命中、特殊同步） | 发射信号给 AudioSystem（接口待确认） |

### 无依赖的系统

| 系统 | 说明 |
|------|------|
| 输入系统 | 动画系统不直接读取输入——输入通过战斗系统转换为`attack_started`信号 |
| 摄像机系统 | 动画系统不控制摄像机——摄像机跟随角色位置由角色控制器决定 |
| 场景管理系统 | 动画系统不关心场景加载/切换——动画资源通过 ResourceLoader 独立加载 |

## Tuning Knobs

### G.1 攻击动画帧数（调整战斗手感）

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| LIGHT_anticipation_frames | 8 | 4-16 | 轻攻击预演帧数，越少越"快" |
| LIGHT_active_frames | 2 | 1-6 | 轻攻击判定帧，越多越宽松 |
| LIGHT_recovery_frames | 6 | 2-16 | 轻攻击破绽帧，越少越安全 |
| MEDIUM_anticipation_frames | 14 | 8-24 | 中攻击预演 |
| MEDIUM_active_frames | 3 | 1-8 | 中攻击判定 |
| MEDIUM_recovery_frames | 10 | 4-20 | 中攻击破绽 |
| HEAVY_anticipation_frames | 20 | 12-36 | 重攻击预演 |
| HEAVY_active_frames | 4 | 2-10 | 重攻击判定 |
| HEAVY_recovery_frames | 16 | 8-28 | 重攻击破绽 |
| SPECIAL_anticipation_frames | 28 | 16-48 | 特殊攻击预演 |
| SPECIAL_active_frames | 6 | 2-12 | 特殊攻击判定 |
| SPECIAL_recovery_frames | 24 | 12-40 | 特殊攻击破绽 |

> 调整这些值会直接影响战斗手感。anticipation减少会让攻击"更快"，但也会减少视觉预警。recovery减少让攻击更安全但可能破坏节奏感。

### G.2 动画速度分层

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| animation_anticipation_speed_scale | 0.5 | 0.25-1.0 | anticipation阶段速度（越小越慢，夸张） |
| animation_impact_speed_scale | 2.0 | 1.0-4.0 | 打击帧速度（越大越快，脆） |
| animation_recovery_speed_scale | 1.0 | 0.5-2.0 | recovery阶段速度 |
| animation_base_fps | 30 | 15-60 | 精灵动画帧率 |

### G.3 Boss动画参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| BOSS_PHASE1_anticipation_frames | 24-30 | 16-40 | Phase 1 攻击预演 |
| BOSS_PHASE2_anticipation_frames | 18-24 | 12-32 | Phase 2 攻击预演（更快） |
| BOSS_PHASE3_anticipation_frames | 12-18 | 8-24 | Phase 3 攻击预演（狂乱） |
| BOSS_VULNERABLE_frames | 24 | 12-48 | 受创后破绽持续时间 |
| BOSS_PHASE_TRANSITION_frames | 60 | 40-90 | 相位转换动画时长 |
| BOSS_DEFEAT_frames | 90 | 60-120 | 击败崩溃动画时长 |

### G.4 纸张质感参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| paper_texture_opacity | 0.15 | 0.0-0.4 | 纸张纹理叠加透明度 |
| paper_jitter_amplitude | 1.0px | 0.0-3.0px | 纸张抖动幅度 |
| paper_jitter_frequency | 8Hz | 2-20Hz | 纸张抖动频率 |
| squash_stretch_intensity | 1.2 | 1.0-1.5 | squash/stretch强度系数 |

### G.5 同步攻击视觉参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| SYNC_WINDOW_DURATION | 5帧 | 3-10帧 | 同步检测窗口 |
| sync_glow_radius_multiplier | 1.15 | 1.0-1.5 | 同步时hitbox放大比例 |
| sync_particle_count | 12 | 6-24 | 同步爆发粒子数 |
| sync_charge_blend_rate | 0.2/帧 | 0.1-0.5/帧 | 蓄力光晕渐变速率 |
| screen_edge_pulse_frequency | 2Hz | 1-4Hz | 屏幕边缘脉冲频率 |

### G.6 救援动画参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| RESCUE_EXECUTE_frames | 12 | 8-20 | 救援伸手动画帧数 |
| RESCUE_REVIVE_frames | 18 | 12-30 | 救援拉起动画帧数 |
| rescued_iframes_frames | 90 | 60-120 | 救援后无敌帧数 |
| downtime_desaturation | 0.5 | 0.2-0.8 | 倒地状态颜色去饱和比例 |
| rescue_glow_intensity | 1.0 | 0.5-2.0 | 救援光晕强度 |

### G.7 Z轴顺序

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| PLAYER_Z_BASE | 20 | — | 玩家精灵基础Z值 |
| PLAYER_EFFECTS_Z_OFFSET | +10 | — | 玩家特效层相对偏移 |
| BOSS_Z_BASE | 0 | — | Boss精灵基础Z值 |
| BOSS_EFFECTS_Z_OFFSET | +10 | — | Boss特效层相对偏移 |
| SYNC_OVERLAY_Z | 100 | — | 同步攻击特效层级（屏幕空间） |

### G.8 性能相关

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| max_concurrent_animated_characters | 3 | — | 同屏最大动画角色数 |
| offscreen_animation_pause | true | true/false | 离屏角色是否暂停动画 |
| sprite_texture_max_size | 2048×2048 | 1024-4096 | 单个精灵纹理最大尺寸 |

## Visual/Audio Requirements

### H.1 动画视觉要求

#### 玩家动画（手绘纸偶风格）

| 动画名 | 帧数要求 | 风格要求 | 特殊要求 |
|--------|---------|---------|---------|
| idle | 8-12帧循环 | 轻微纸张颤动，肩膀微起伏 | 持续循环 |
| move | 6-8帧循环 | 奔跑有弹跳感，手臂摆动 | — |
| attack_light | 16帧（8+2+6） | anticipation=快速戳刺准备，active=戳出，recovery=收回 | 打击帧有"脆"感 |
| attack_medium | 27帧（14+3+10） | anticipation=弧形挥舞准备，active=横扫，recovery=收势 | anticipation有拖拽感 |
| attack_heavy | 40帧（20+4+16） | anticipation=明显蓄力（下蹲+手臂后拉），active=重劈，recovery=缓慢收回 | 重量感最强 |
| attack_special | 58帧（28+6+24） | 最夸张的anticipation，可能包含翻滚或特殊位移 | 变身感 |
| hurt | 12帧 | 向后弹开，纸张碎裂效果叠加 | 可被打断 |
| rescue_approach | 取决于距离 | 跑向队友，颜色向救援者偏移 | — |
| rescue_execute | 12帧 | 手部伸出，颜色高亮 | 手部光晕100% |
| rescue_revive | 18帧 | 拉起倒地玩家，纸片火花 | 8-12个纸片粒子 |
| downtime_loop | 180帧（3秒循环） | 倒地平躺，缓慢纸张颤动，去饱和 | 循环至被救或OUT |
| rescued_invincible | 90帧（1.5秒） | 柔和脉冲光晕，颜色70%饱和 | 透明度脉动 |

#### Boss动画（压迫几何 + 便签崩溃）

| 动画名 | 帧数要求 | 风格要求 | 特殊要求 |
|--------|---------|---------|---------|
| boss_idle_phase1 | 24帧循环 | 有节制的呼吸，纸张沙沙声，微幅摇晃 | 相1独有 |
| boss_idle_phase2 | 20帧循环 | 轻微垂直抖动（VFX驱动，非关键帧） | 相2独有 |
| boss_idle_phase3 | 16帧循环 | 全身颤抖，急促 | 相3独有 |
| boss_attack_a | 60-80帧 | 压迫推进，纸张堆积感 | 相1/2 |
| boss_rage | 50-70帧 | 便签雪崩，快速连击 | 相2/3 |
| boss_crisis | 40-60帧 | 恐慌过载，运动轨迹紊乱 | 相3独有 |
| boss_phase_transition | 60帧 | Boss短暂停顿→形态变化（僵硬感加重） | 相间过渡 |
| boss_vulnerable | 24帧 | 踉跄，受创反馈 | 被命中后 |
| boss_defeat | 90帧 | 几何崩溃，便签爆炸飞散，粒子系统主导 | Boss HP=0 |

#### 同步攻击视觉

| 要求 | 规格 |
|------|------|
| 粒子效果 | 12个粒子，橙色(#F5A623)和蓝色(#4ECDC4)交替，从攻击点向外螺旋射出 |
| 屏幕效果 | 边缘脉冲，橙蓝交替，2Hz频率，持续500ms |
| 光晕叠加 | 攻击者精灵外发光，混合橙色+蓝色，opacity=0.4 |
| Hitbox扩大 | 同步攻击hitbox半径×1.15 |

#### 纸张质感视觉

| 要求 | 规格 |
|------|------|
| 纹理叠加层 | 纸张noise纹理，opacity=0.15，覆盖在主精灵上 |
| 微抖动 | position jitter ±1.0px，频率8Hz（通过noise_offset实现） |
| 撕裂边缘 | 粒子特效实现（非精灵变形），粒子形状为不规则纸片 |
| Squash/stretch | Sprite2D.scale关键帧，intensity=1.2，打击帧触发 |

---

### H.2 动画音效要求

动画系统负责在关键帧触发音效，音效资源由音频系统管理：

| 触发时机 | 音效描述 | 备注 |
|---------|---------|------|
| LIGHT active帧 | 轻短打击音（纸片撕裂声） | — |
| MEDIUM active帧 | 中等冲击音（砰） | — |
| HEAVY active帧 | 重击音（沉闷冲击+纸张撕裂） | — |
| SPECIAL active帧 | 特殊音效（全屏震撼+纸片飞散） | — |
| 命中hit_vfx触发 | 命中音效（根据命中类型变化） | 由VFX emitter触发后调用 |
| Sync burst触发 | 橙蓝和声+纸片共鸣 | 独特音效，区分于普通命中 |
| RESCUE_EXECUTE | 手部伸出音效（嗖） | — |
| RESCUE_REVIVE | 拉起音效+纸片火花 | — |
| BOSS_VULNERABLE | Boss踉跄音效（纸张揉皱声） | — |
| BOSS_DEFEAT | Boss崩溃音效（大量纸张撕裂+落地） | 持续1.5s，配合粒子 |
| downtime_loop | 无音效（静音） | 避免听觉疲劳 |

> **音效优先级**：所有音效由音频系统管理，动画系统通过信号触发。动画系统不直接加载或播放音频文件。

## UI Requirements

### I.1 动画系统不直接控制UI

动画系统是纯表现层系统，不主动驱动任何UI元素。UI的动画（如连击数字弹出、HP条变化、Boss血条）由UI系统独立管理。

### I.2 动画系统向UI系统提供的接口（只读）

UI系统可能需要查询以下状态来驱动UI动画：

| 查询 | 类型 | 说明 |
|------|------|------|
| 当前玩家状态 | String | IDLE / MOVE / LIGHT_ATTACK 等（用于UI状态联动） |
| 同步攻击是否激活 | bool | sync_burst_active（用于UI显示同步连击特效） |
| Boss当前相位 | int (1/2/3) | 用于Boss血条分段显示 |
| 连击Tier | int | combo_tier_escalated信号（来自连击系统） |

> 这些查询通过共享数据（如Autoload）实现，动画系统**发射**信号，UI系统**订阅**，不直接控制。

### I.3 UI需求（动画系统需要UI配合的部分）

| 需求 | 描述 |
|------|------|
| 屏幕空间粒子层 | 同步攻击时屏幕边缘脉冲需要屏幕空间的CanvasLayer，z高于所有游戏内元素 |
| 屏幕震动隔离 | Boss攻击或同步爆发时屏幕震动不应影响UI元素（使用CanvasLayer层分离） |

### I.4 无直接UI需求

以下UI功能**不依赖**动画系统：
- 连击计数器显示（连击系统直接驱动，订阅`combo_tier_escalated`）
- Boss HP条（战斗系统直接驱动，订阅`boss_hp_changed`）
- 救援计时器（协作系统直接驱动，订阅`player_downed`和计时器）
- 暂停菜单动画（UI系统独立管理）

## Acceptance Criteria

### AC-1：动画状态机基本功能

- [ ] **AC-1.1**：玩家从IDLE输入LIGHT攻击 → 动画正确播放16帧（8 anticipation + 2 active + 6 recovery）→ 返回IDLE
- [ ] **AC-1.2**：玩家在anticipation阶段受创 → 立即切换到HURT状态，攻击被取消
- [ ] **AC-1.3**：玩家在recovery帧期间输入攻击 → 输入被忽略，动画不被打断
- [ ] **AC-1.4**：MEDIUM攻击anticipation可以被LIGHT攻击anticipation中断（8帧 vs 14帧），但MEDIUM active阶段不行
- [ ] **AC-1.5**：BOSS_ATTACK_A播放时受到玩家命中 → Boss保持在ATTACK_A状态，VULNERABLE不在攻击中进入

### AC-2：帧锁Hitbox同步

- [ ] **AC-2.1**：LIGHT攻击的hitbox只在帧8-9（active帧）激活，帧10+关闭
- [ ] **AC-2.2**：HEAVY攻击的hitbox只在帧20-23（active帧）激活，帧24+关闭
- [ ] **AC-2.3**：帧跳帧（lag）期间，hitbox激活时机与视觉动画帧同步延迟，不出现"视觉未到但伤害已触发"

### AC-3：同步攻击视觉

- [ ] **AC-3.1**：P1和P2在5帧窗口内各自命中 → 同步爆发触发，双色粒子螺旋射出（橙色#F5A623 + 蓝色#4ECDC4）
- [ ] **AC-3.2**：P1命中时P2处于anticipation → P2显示"同步蓄力"光晕（淡→强），P2在5帧内命中则爆发，未命中则光晕消散
- [ ] **AC-3.3**：同步攻击时攻击hitbox半径×1.15（+15%）

### AC-4：Boss动画状态与相位

- [ ] **AC-4.1**：Boss从Phase 1→2（HP穿越60%）→ BOSS_PHASE_TRANSITION播放60帧 → 进入Phase 2状态机
- [ ] **AC-4.2**：Boss进入Phase 2后，idle动画帧率加快（20帧 vs 24帧），VFX增加垂直抖动
- [ ] **AC-4.3**：Boss进入Phase 3（HP穿越30%）→ idle动画帧率继续加快（16帧），全身颤抖明显
- [ ] **AC-4.4**：Boss HP归零 → BOSS_DEFEAT播放90帧 → 便签爆炸粒子主导视觉效果

### AC-5：救援动画序列

- [ ] **AC-5.1**：P1倒地 → downtime_loop播放，180帧（3.0s）后P1自动OUT
- [ ] **AC-5.2**：P2在P1倒地后进入RESCUE_RANGE（175px内）并按下救援 → RESCUE_EXECUTE（12帧）→ RESCUE_REVIVE（18帧）→ P1起身
- [ ] **AC-5.3**：P2在RESCUE_APPROACH途中受创 → RESCUE取消，P2进入HURT，P1继续downtime_loop，计时器不暂停
- [ ] **AC-5.4**：P2在t=2.5s后开始救援 → 500ms动画序列在RESCUE_WINDOW=3.0s内完成，P1被救起
- [ ] **AC-5.5**：救援成功后P1显示rescued_invincible动画（90帧，柔和脉冲光晕），期间完全减伤

### AC-6：纸张质感

- [ ] **AC-6.1**：所有角色精灵有纸张纹理叠加层（opacity=0.15），可见微抖动（±1.0px，8Hz）
- [ ] **AC-6.2**：打击帧（active帧）触发squash/stretch效果，Sprite2D.scale峰值=1.2

### AC-7：性能基准

- [ ] **AC-7.1**：3个角色（2玩家+Boss）同屏，动画全部播放，帧率稳定60fps
- [ ] **AC-7.2**：角色离屏后动画暂停（offscreen pause），返回后正确恢复
- [ ] **AC-7.3**：20个预实例化VFX emitter全部就绪，无运行时分配卡顿

### AC-8：信号契约

- [ ] **AC-8.1**：动画系统正确订阅并响应所有上游信号（attack_started, attack_hit, hurt_received, sync_burst_triggered, combo_tier_escalated, player_downed, rescue_triggered, player_rescued, player_out, boss_phase_changed）
- [ ] **AC-8.1b**：`attack_ended` 信号是否存在？如不存在，从 AC-8.1 中移除并确认 animation-system 不依赖此信号
- [ ] **AC-8.2**：动画系统正确发射2个下游信号（animation_state_changed, recovery_complete）
- [ ] **AC-8.3**：所有信号连接使用Godot 4.6 Callable语法（无废弃API警告）

## Open Questions

### O-1：UI系统与动画系统的接口方式

**问题**：动画系统向UI系统提供状态查询的方式尚未确定。

**选项**：
- A：共享Autoload数据（动画系统写入，UI系统读取）
- B：信号订阅（动画系统发射，UI系统订阅）
- C：直接节点引用（动画系统直接控制UI节点）

**建议**：选项B（信号订阅）——保持松耦合，UI系统不需知道动画系统内部状态。

---

### O-2：BOSS_ATTACK_B具体内容

**问题**：Boss Phase 1有两个攻击槽（ATTACK_A和ATTACK_B），但Boss AI系统GDD只明确定义了Pattern A（压迫推进）。ATTACK_B的具体动画内容未定义。

**影响**：如果Phase 1只有ATTACK_A，Boss战斗会显得单调。

**建议**：在Boss AI系统GDD中明确Pattern B的具体行为后，更新BOSS_ATTACK_B动画内容。临时方案：将ATTACK_B设为ATTACK_A的镜像变体。

---

### O-3：特殊攻击动画的视觉差异

**问题**：SPECIAL_ATTACK是最具表现力的动画，但"特殊攻击"的定义在战斗系统和连击系统中均未明确说明是什么类型的攻击。

**影响**：动画师无法确定SPECIAL_ATTACK的视觉风格（范围？位移？特效强度？）。

**建议**：在战斗系统GDD中明确SPECIAL_ATTACK的机制定义后，SPECIAL_ATTACK动画方可设计。

---

### O-4：动画资源加载策略

**问题**：何时预加载动画资源？是否支持运行时动态加载？

**选项**：
- A：全部预加载（游戏开始时加载所有动画，开机慢但运行流畅）
- B：按需加载（第一次使用某个动画时加载，可能有短暂卡顿）
- C：后台预加载（游戏开始时预加载核心动画，其余在后台流式加载）

**建议**：选项C——开机时预加载Boss和玩家核心动画，后台预加载特效动画。

---

### O-5：AudioSystem接口确认

**问题**：动画关键帧触发音效的方式尚未与音频系统确认。

**待确认**：
- 动画系统发射信号还是直接调用AudioSystem方法？
- 音效资源路径约定是什么？
- 是否需要音效优先级系统（多个同时触发的音效如何处理）？

**建议**：与音频系统GDD作者协商后更新本节。

---

### O-6：屏幕震动与游戏手感

**问题**：Boss攻击时屏幕震动参数（幅度、频率、持续时间）由动画系统还是VFX系统控制？

**当前理解**：VFX系统通过粒子和环境效果实现Boss Phase 2/3的视觉颤抖。屏幕震动（如Boss落地冲击）是否由动画系统触发（调用Camera2D）还是由VFX系统直接控制？

**建议**：明确Camera2D的控制权归属。屏幕震动建议由VFX系统统一管理，动画系统只发射信号触发。
