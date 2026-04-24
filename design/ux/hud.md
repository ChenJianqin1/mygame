# HUD Design

> **Status**: In Design
> **Author**: ux-designer
> **Last Updated**: 2026-04-17
> **Template**: HUD Design

---

## HUD Philosophy

**核心理念**: 轻量但完整（Light but Complete）

始终显示核心玩家状态（HP、Combo）和 Boss 进度，让玩家无需询问即可做决策。视觉上保持简洁，不抢夺战斗区域的注意力。次要信息（Contextual）仅在相关时刻出现，用完即散。

**设计原则**：
- **底部优先** — 玩家状态信息集中在底部边缘，不遮挡中央战斗区域
- **视觉分层** — Must Show 信息恒驻，Contextual 信息按需闪现
- **Paper 美学** — 便签、纸卷、纸夹等手绘质感元素，与"打工人梦境战斗"的世界观一致

---

## Information Architecture

### Full Information Inventory

| # | 信息 | 来源 |
|---|------|------|
| 1 | P1 HP（当前值/最大值） | coop-system |
| 2 | P2 HP（当前值/最大值） | coop-system |
| 3 | Boss HP（当前值/最大值，始终显示百分比） | ui-system |
| 4 | Boss 相位（1/2/3，通过刻痕和颜色区分） | boss-ai |
| 5 | P1 Combo 计数 | combo-system |
| 6 | P2 Combo 计数 | combo-system |
| 7 | P1 Combo Tier 等级（0-4） | combo-system |
| 8 | P2 Combo Tier 等级（0-4） | combo-system |
| 9 | Sync chain 长度（0-3） | combo-system |
| 10 | Coop Bonus 状态（激活/未激活） | coop-system |
| 11 | Rescue Timer（3秒倒计时） | coop-system |
| 12 | Crisis 状态（激活/未激活） | coop-system |
| 13 | P1 OUT 状态（ghost 图标） | coop-system |
| 14 | P2 OUT 状态（ghost 图标） | coop-system |
| 15 | Damage Number（命中伤害值） | combat-system |
| 16 | Boss Phase Warning（相位警告） | ui-system |
| 17 | Attack Telegraph（攻击提示图标+文字） | ui-system |

### Categorization

**Must Show（始终可见，随游戏进程更新）**：
- P1 HP（P1 橙色便签，左下角）
- P2 HP（P2 蓝色便签，右下角）
- Boss HP（纸卷顶部中央，始终显示百分比数字）
- P1 Combo 计数（仅在 combo > 0 时显示）
- P2 Combo 计数（仅在 combo > 0 时显示）

**Contextual（相关时才出现，触发后短暂或持续显示）**：
- P1/P2 Combo Tier — 通过 Combo counter 的缩放比例和颜色变化表达（不单独显示标签）
- Sync chain 图标 — 仅在 chain > 0 时显示，3 个纸夹图标
- Coop Bonus 光晕 — 仅在奖励激活时显示在 HP 栏附近
- Rescue Timer — 仅在有玩家倒下时显示，圆形径流，直径 80px
- Crisis Edge Glow — 仅在 Crisis 激活时脉冲式覆盖屏幕边缘
- P1/P2 OUT ghost 图标 — 仅在对应玩家 OUT 时显示
- Damage Number — 命中时在命中点短暂弹出，颜色随 Combo Tier 变化
- Boss Phase Warning — 相位切换时全屏闪烁
- Attack Telegraph — Boss 攻击前在屏幕中央短暂显示

---

## Layout Zones

### 布局概览

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                   [ BOSS HP BAR ]                           │
│                   顶部居中, 60% 宽度                         │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                      [战斗区域]                              │
│                    中央 / 全屏幕                             │
│                  (无 HUD 元素遮挡)                          │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [P1 HP栏]         [SYNC CHAIN]          [P2 HP栏]         │
│  左下角            底部中央              右下角               │
│                                                             │
│  [P1 Combo]                              [P2 Combo]        │
│  HP栏下方                                HP栏下方            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 层级定义（Z-Order，从底到高）

| Z-Order | 元素 | 说明 |
|---------|------|------|
| 0（最低） | Crisis Edge Glow | 全屏边缘晕影，仅 Crisis 时激活 |
| 1 | Boss HP Bar | 顶部中央，纸卷风格 |
| 2 | Player HP Bars | 底部角落 |
| 3 | Combo Counters | HP 栏下方 |
| 4 | Sync Chain Indicators | Combo counter 之间 |
| 5 | Contextual Overlays | Rescue Timer、Boss Phase Warning、Attack Telegraph |
| 6 | Damage Numbers | 最高层，弹出在命中点 |

### 屏幕区域划分

| 区域 | 范围 | HUD 元素 |
|------|------|---------|
| Top Zone | 屏幕顶部 15% | Boss HP Bar |
| Center Zone | 屏幕中央 60% | 战斗区域，无 HUD |
| Bottom Zone | 屏幕底部 25% | P1 HP/P2 HP/Combo Counters/Sync Chain |
| Overlay Layer | 全屏覆盖 | Crisis Edge Glow（Contextual） |

---

## HUD Elements

### 元素规格总览

| 元素 | 分类 | Z-Order | 位置锚点 |
|------|------|---------|---------|
| CrisisEdgeGlow | Contextual | 0 | 全屏 |
| BossHPBar | Must Show | 1 | top-center |
| PlayerHPBar_P1/P2 | Must Show | 2 | bottom-left/right |
| ComboCounter_P1/P2 | Must Show | 3 | HP 栏下方 |
| SyncChainIndicator | Contextual | 4 | 底部中央 |
| RescueTimer | Contextual | 5 | 跟随玩家 |
| BossPhaseWarning | Contextual | 5 | 屏幕中央 |
| AttackTelegraph | Contextual | 5 | 屏幕中央 |
| CoopBonusIndicator | Contextual | 3 | HP 栏旁 |
| GhostIcon | Contextual | 3 | 队友 HP 栏旁 |
| DamageNumber | Contextual | 6 | 命中点 |

---

### E1: PlayerHPBar_P1

| 属性 | 值 |
|------|-----|
| 分类 | Must Show |
| 位置 | bottom-left, 偏移 (40px, -40px) |
| 尺寸 | 220×32px |
| 样式 | 便签纸风格，纸撕边缘，图钉图标 |
| 颜色 | 填充 #F5A623（橙色），背景 #2A2A2E |
| 标识 | 左侧橙色圆点 + "P1" 文字 |
| 字号 | HP 数字最小 16px |

**动画**：
- HP 变化：平滑插值 `lerp(display, actual, 1.0 - pow(0.001, delta_time))`
- 低血量 < 30%：缓慢脉冲（0.5Hz）
- 极低血量 < 10%：快速红色闪烁

**Accessibility**：颜色不是唯一标识 — 橙色标识点 + "P1" 标签文字双重标识

---

### E2: PlayerHPBar_P2

| 属性 | 值 |
|------|-----|
| 分类 | Must Show |
| 位置 | bottom-right, 偏移 (-40px, -40px) |
| 尺寸 | 220×32px |
| 样式 | 便签纸风格，纸撕边缘，图钉图标 |
| 颜色 | 填充 #4ECDC4（蓝色），背景 #2A2A2E |
| 标识 | 左侧蓝色圆点 + "P2" 文字 |

规格与 P1 HP Bar 对称。

---

### E3: BossHPBar

| 属性 | 值 |
|------|-----|
| 分类 | Must Show |
| 位置 | top-center, 偏移 (0, 40px) |
| 尺寸 | 60% 屏幕宽度 × 28px |
| 样式 | 纸卷/卷轴风格 |
| 百分比显示 | 始终显示（如 "42%"） |

**相位颜色**：
- Phase 1：#6B7B8C（冷静蓝灰）
- Phase 2：#D4A017（琥珀警告）
- Phase 3：#E85D3B（紧急红橙）

**相位刻痕**：
- 60% 和 30% 位置有细线标记
- 相位切换时对应刻痕闪烁

**动画**：
- HP 变化：平滑插值
- 相位切换：颜色渐变过渡（0.3s）

---

### E4: ComboCounter_P1

| 属性 | 值 |
|------|-----|
| 分类 | Must Show（仅 combo > 0 时可见） |
| 位置 | P1 HP Bar 下方, bottom-left, 偏移 (40px, -90px) |
| 内容 | 大号数字 + P1 橙色小点 + Tier 名称 |
| Tier 名称 | Tier 2="Rising", Tier 3="Intense", Tier 4="OVERDRIVE" |

**Tier 缩放与颜色**：
| Tier | 数字缩放 | 颜色 |
|------|---------|------|
| 0 | 不可见 | — |
| 1 (1-9) | 1.00x | #F5A623 |
| 2 (10-19) | 1.15x | #F5A623 +20% 亮度 |
| 3 (20-39) | 1.30x | #F5A623 +40% 亮度 + glow |
| 4 (40+) | 1.50x | #FFD700 金色 + confetti |

**动画**：
- 递增：弹跳缩放（0.1s）
- Tier 升级：闪烁 + 颜色过渡
- 中断归零：缩小消失（0.2s）

---

### E5: ComboCounter_P2

规格与 P1 Combo Counter 对称，蓝色配色 #4ECDC4。

---

### E6: SyncChainIndicator

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（仅 chain > 0 时可见） |
| 位置 | 底部中央，两个 Combo Counter 之间 |
| 内容 | 3 个纸夹图标，横排，间距 12px |

**图标状态**：
- 未填充：灰色半透明轮廓
- 已填充：橙色+蓝色交替（模拟两人同步感）

**动画**：
- 同步命中：下一个图标弹跳填充
- Sync Burst 触发（3 连）：3 个图标同时发光脉冲，然后清空

---

### E7: CoopBonusIndicator

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（仅 Coop Bonus 激活时可见） |
| 位置 | P1 HP 栏右侧，P2 HP 栏左侧 |
| 尺寸 | 20×20px |
| 内容 | 协作图标（P1 橙色，P2 蓝色） |

**动画**：激活时淡入（0.2s），消失时淡出（0.2s）

---

### E8: RescueTimer

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（仅有玩家倒下时出现） |
| 位置 | 跟随倒下玩家的屏幕坐标投影 |
| 尺寸 | 直径 80px |
| 内容 | 圆形径流倒计时 + 中心秒数（3→2→1） |
| 边框颜色 | 救援者颜色（执行救援的玩家颜色） |

**动画**：
- 径流：圆形从满到空，3 秒完成
- 最后 1 秒：边框红色闪烁
- 超时：缩小消失（0.3s）

---

### E9: CrisisEdgeGlow

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（仅 Crisis 激活时脉冲） |
| 位置 | 全屏边缘覆盖 |
| 颜色 | #7F96A6，透明度 0.5 脉冲 |
| 脉冲节奏 | 0.5s on, 0.5s off |

**动画**：
- 激活：从 0 渐变到 0.5（0.3s）
- 脉冲：每 1 秒完成一次 on/off 循环
- 解除：渐变消失（0.3s）

---

### E10: GhostIcon（OUT Indicator）

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（仅玩家 OUT 时出现） |
| 位置 | 存活队友 HP 栏旁边 |
| 尺寸 | 24×24px |
| 内容 | 半透明 ghost 轮廓图标，灰色 |
| 动画 | 出现时淡入（0.2s），保持显示直到游戏结束 |

---

### E11: DamageNumber

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（每次命中时短暂弹出） |
| 位置 | 命中点的屏幕坐标投影 |
| 尺寸 | 字体 24-36px（随攻击类型变化） |
| 字号 | 攻击类型决定字号大小 |

**颜色随 Combo Tier**：
| Tier | 颜色 |
|------|------|
| 0 | #FFFFFF 白 |
| 1 | #FFB347 浅橙 |
| 2 | #F5A623 橙 |
| 3 | #FF8C00 亮橙 |
| 4 | #FFD700 金色 |

**动画**：
- 弹出：向上漂浮 + 渐变消失（0.6s）
- Billboard：始终面向镜头

---

### E12: BossPhaseWarning

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（相位切换时短暂显示） |
| 位置 | 屏幕中央 |
| 内容 | 全屏闪烁，对应相位颜色 |

**颜色**：
- Phase 1→2：#D4A017 琥珀色
- Phase 2→3：#E85D3B 红色

**动画**：闪烁 0.5s（3 次），然后渐隐

---

### E13: AttackTelegraph

| 属性 | 值 |
|------|-----|
| 分类 | Contextual（Boss 攻击前显示） |
| 位置 | 屏幕中央 |
| 内容 | 攻击图标 + 攻击名称文字 |
| 持续时间 | 1.0 秒后消失 |

**动画**：
- 出现：缩放弹入（0.15s）
- 停留：1.0 秒
- 消失：淡出（0.2s）

---

## Dynamic Behaviors

### DB-1: HUD 密度稳定性

**设计决策**：HUD 元素数量和可见性不随战斗激烈程度变化，始终按上述规格运行。战斗再激烈，HUD 也保持一致，不展开额外信息。

---

### DB-2: Combo Tier 升级视觉连锁反应

当 Combo Tier 升级时，多个 HUD 元素联动响应：

| 升级 | ComboCounter 缩放 | ComboCounter 颜色 | Tier 名称 | 其他联动 |
|------|-----------------|------------------|---------|---------|
| Tier 1→2 | 1.00x → 1.15x | +20% 亮度 | 显示 "Rising" | — |
| Tier 2→3 | 1.15x → 1.30x | +40% 亮度 + glow | 显示 "Intense" | Camera 轻微震动 |
| Tier 3→4 | 1.30x → 1.50x | 变为金色 #FFD700 | 显示 "OVERDRIVE" | Damage Number 颜色同步变为金色 |

**动画细节**：
- 缩放：弹跳效果（0.1s）
- 颜色过渡：渐变（0.2s）
- Tier 4 触发：额外 confetti 粒子效果

---

### DB-3: Crisis 激活时 HUD 行为

当 Crisis 状态激活（双方 HP < 30%）：

1. **CrisisEdgeGlow** 渐变出现（0.3s），透明度从 0 到 0.5
2. 脉冲开始：0.5s 显示 / 0.5s 隐藏，持续循环
3. 其他 HUD 元素**无变化**，保持原有规格

当 Crisis 解除时：
- CrisisEdgeGlow 渐变消失（0.3s）
- 脉冲停止

---

### DB-4: 玩家倒下 → Rescue 流程

**步骤 1：P1 倒下**
- P1 HP Bar 显示 0，血条清空
- **RescueTimer** 出现在 P1 屏幕位置（跟随 Node2D 世界坐标投影）
- RescueTimer：圆形径流，直径 80px，3 秒倒计时
- P1 **GhostIcon** 暂不出现（等待 Rescue 结果）
- **CoopBonusIndicator** 继续显示（因为 P2 仍存活）

**步骤 2a：Rescue 成功（P2 执行救援）**
- RescueTimer 立即消失，闪光动画
- P1 获得 20HP（最小值）+ 1.5s 无敌帧
- P1 HP Bar 更新显示新 HP 值（从 0 插值到 20）
- P1 GhostIcon 不出现

**步骤 2b：Rescue 超时（3 秒内无救援）**
- RescueTimer 缩小消失（0.3s）
- P1 **GhostIcon** 淡入出现在 P2 HP 栏旁边
- P2 获得 SOLO_DAMAGE_REDUCTION（-25% 伤害）
- **CoopBonusIndicator** 消失（P2 独自战斗）

---

### DB-5: Boss HP 变化与 Phase 切换

**Boss HP 变化**：
- 百分比数字实时更新（始终显示）
- HP 条平滑插值：`lerp(display_hp, actual_hp, 1.0 - pow(0.001, delta_time))`
- 颜色随当前 Phase 保持

**Phase 切换触发**：
- HP 跨过 60%：Phase 1 → Phase 2
- HP 跨过 30%：Phase 2 → Phase 3

**Phase 切换时 HUD 行为**：
- BossHPBar 颜色渐变过渡（0.3s）
- 对应刻痕（60% 或 30%）闪烁 3 次
- **BossPhaseWarning** 全屏闪烁（Phase 1→2 琥珀色，Phase 2→3 红色，0.5s）
- Camera 震动（Phase 切换是高紧张节点）

---

### DB-6: Sync Burst 触发

当 Sync Burst 触发（3 连 Sync 命中）：

1. **SyncChainIndicator** 3 个纸夹图标同时发光脉冲
2. 两个 **ComboCounter** 短暂高亮（金色闪烁 0.2s）
3. Camera 震动（trauma = 0.8）
4. VFX 系统触发 sync burst 视觉特效
5. Sync Chain 清空：所有图标变为未填充状态

---

## Platform & Input Variants

### 平台支持

**目标平台**：PC（Steam）

**输入方式**：
- Keyboard/Mouse（Primary）
- Gamepad（Partial — 本地双人合作，手柄 × 2）
- Touch：None

### HUD 与输入设备的独立性

**设计决策**：HUD 布局不随输入设备变化。键盘和手柄玩家使用相同的 HUD 布局。

**例外**：按键绑定提示不在 HUD 上显示，战斗教学场景中单独处理。

### 手柄支持说明

手柄玩家与键盘玩家共用同一 HUD，无特殊差异。手柄特有的输入提示（如 "Press A to Attack"）不在 HUD 上显示，而是在教学关卡或 Pause 菜单的 Controls 页面中处理。

---

## Accessibility

### 辅助功能承诺（Basic Tier）

基于 `design/accessibility-requirements.md`，本项目 targeting Basic tier。以下规格与 HUD 设计相关。

### 视觉辅助功能

| 功能 | 状态 | 实现说明 |
|------|------|---------|
| 最低字体大小 | **必须实现** | HUD 元素最小 16px |
| 文本对比度 | **必须实现** | 所有文本/背景对比度 ≥ 4.5:1（WCAG AA） |
| 颜色备份标识 | **必须实现** | P1/P2 不只靠颜色区分，有文字标签 "P1"/"P2" |
| 亮度/Gamma 控制 | **必须实现** | 图形设置中提供 -50% ~ +50% 亮度调节 |
| 屏幕闪烁警告 | **必须实现** | Phase Warning 全屏闪烁有 0.5s 预警 |

### 颜色作为唯一标识的风险

**Critical**：P1 = 橙色 #F5A623，P2 = 蓝色 #4ECDC4。这两个颜色**不能**作为唯一标识手段。

**备份方案**：
- P1 HP Bar：橙色 + "P1" 标签文字
- P2 HP Bar：蓝色 + "P2" 标签文字
- Combo Counter：P1 橙色小点 / P2 蓝色小点作为区分
- Sync Chain：橙色+蓝色交替填充（既是同步视觉也暗示两人）

### 色彩敏感性问题

本项目**不包含** Colorblind modes（不在 Basic tier 范围内）。色彩备份标识（P1/P2 文字标签）已覆盖基本可辨识性需求。

### 屏幕闪烁 / photosensitivity

**Harding FPA 审计**：Boss Phase Warning 全屏闪烁需要通过 Harding FPA 标准。

**缓解措施**：
- 单次闪烁时长 ≥ 1 秒（Phase Warning 实际 0.5s 闪烁 3 次 = 1.5s，总时长可接受）
- 闪烁前有 Attack Telegraph 1 秒提示（给玩家准备时间）
- Crisis Edge Glow 是缓慢脉冲（0.5s 频率），不属于快速闪烁

### 运动/动画减少模式

**设计决策**：HUD 的缩放、脉冲、淡入淡出动画是**游戏体验的一部分**，无法禁用。

**例外**：Menu transitions 可以是 instant cuts（在 Pause 菜单设置中提供该选项）。

**不可禁用的动画**：
- Combo Counter 缩放动画（战斗反馈核心）
- Crisis Edge Glow 脉冲（危机氛围核心）
- HP 条平滑插值（视觉流畅性）
- Camera shake（战斗打击感核心）

---

## Open Questions

| # | 问题 | 状态 | 备注 |
|---|------|------|------|
| 1 | Damage Number 的字号具体是多少？不同攻击类型（L/M/H/S）如何区分？ | Open | 规格中写了 24-36px，需在实现时确认具体值 |
| 2 | Boss HP Bar 的 Boss 名称最长可能多少字符？中文本地化后是否超出纸卷宽度？ | Open | 需在实现时用最长 Boss 名称测试 |
| 3 | Ghost Icon 在游戏结束（Game Over）时是否保留？ | Open | 当前规格是"保持显示直到游戏结束或重置" |
| 4 | Attack Telegraph 的图标是 sprite 还是 Unicode 符号？ | Open | 影响实现方式 |
| 5 | SyncChainIndicator 的 3 个纸夹图标在没有 Sync 时显示为灰色轮廓，但 HUD Spec 说"仅在 chain > 0 时才显示图标" — 两种方案哪个正确？ | **已解决** | 采用"仅在 chain > 0 时显示"，chain=0 时完全不渲染 |
| 6 | Combo Tier 名称（"Rising"/"Intense"/"OVERDRIVE"）是否需要本地化？ | Open | 如果需要中文翻译，需要重新设计字号 |
| 7 | Rescue Timer 的圆形径流如何绘制？用 TextureProgressRing 还是程序化绘制？ | Open | 影响实现工作量 |
| 8 | Phase Warning 全屏闪烁如何实现？用 ColorRect overlay 还是 shader？ | Open | 影响性能，需与 VFX 协调 |
