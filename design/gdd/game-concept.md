# Game Concept: 今日Boss：打工吧！

*Created: 2026-04-16*
*Status: Draft*

---

## Elevator Pitch

一款双人合作横版动作闯关游戏，两位玩家组队，将打工人在工作与生活中面对的困境——Deadline、加班、会议——通过幽默且富有想象力的二次创作，转化为可战胜的Boss。在流畅的Combo战斗中，共同克服"工作日boss"，体验"我们一起扛过来了"的情感共鸣。

> It's a 2D co-op action side-scroller where two players team up to defeat boss interpretations of real-life work/life struggles — like meetings, deadlines, and overtime — finding emotional catharsis through combat that's as satisfying as it is relatable.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D Co-op Action Side-Scroller / Boss Rush |
| **Platform** | PC (Steam / Epic) |
| **Target Audience** | Casual co-op players, office workers aged 18-35, fans of Games Like It Takes Two |
| **Player Count** | Local 2-player co-op (pure双人合作，不存在单人通关) |
| **Session Length** | 30-90 minutes (完整工作日体验 = 一次Session) |
| **Monetization** | 暂无 (First game, single project) |
| **Estimated Scope** | Small (2-4 weeks, solo dev with 2-player协作) |
| **Comparable Titles** | 双人成行 (It Takes Two), 双影奇境 (We Are One) |

---

## Core Fantasy

**"把这些烂事暴打一顿，然后下班回家。"**

在一个充满隐喻的梦境战斗空间里，两位打工人的"另一面"——分裂出的战斗自我——组队面对并战胜那些在现实中让人窒息的困境。每一场Boss战都是一次对现实的"象征性复仇"，而胜利的快感来自于"原来我们能扛过去"。

---

## Unique Hook

**Boss的机制本身就是困境的化身。**

不是给Boss起个职场名字然后用通用战斗打发——而是说"焦虑黑雾"Boss会蔓延覆盖屏幕、逼迫两人靠近才能互相清除；"Deadline从背后追着你跑"这个Boss的攻击方式就是从屏幕边缘碾压过来，让玩家必须不断前进否则就被吞噬。

战斗即隐喻，机制即情感。

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 4 | 华丽Combo特效，颜色随连击升级，命中音效层次分明 |
| **Fantasy** (make-believe) | 7 | 打工人的"第二自我"，梦境战斗空间，困境Boss化 |
| **Narrative** (drama, story arc) | 6 | 工作日叙事弧线：早会Boss → 午前Deadline → 午后危机 → 加班最终Boss |
| **Challenge** (obstacle course) | 5 | Boss机制易懂，但完美通关需要练习；不是硬核，但有技术天花板 |
| **Fellowship** (social connection) | **1** | 双人合作是核心，两人的配合与互相救援是核心情感来源 |
| **Discovery** (exploration) | 3 | 每个Boss的隐喻需要"发现"——原来这个攻击方式代表这个！ |
| **Expression** (self-expression) | 2 | Combo系统让玩家形成自己的风格，有人追求伤害，有人追求美观 |
| **Submission** (relaxation) | 5 | 整体基调轻快，不是压抑或苦涩；失败不重 penalized，不让玩家卡关 |

### Key Dynamics (Emergent player behaviors)

- 玩家会自然开始**尝试不同的Combo顺序**，探索哪种连击最有效
- 双人之间会产生**即兴分工**：谁负责吸引攻击，谁负责输出
- 看到Boss的某种攻击方式后，会**会心一笑**——"太真实了"
- 击败Boss后，玩家会**讨论刚才的战斗有多荒诞**，而不是单纯比分数

### Core Mechanics (Systems we build)

1. **Combo连击系统** — 每次命中累积Combo数，Combo越高视觉反馈越华丽；断了不惩罚但影响评分
2. **双人协作机制** — 两位玩家各有独特技能，但关键机制是**互补**而非分工；危机时刻可互相救援
3. **困境Boss设计** — 每个Boss的**攻击模式和视觉效果**直接反映其所代表的现实困境
4. **工作日叙事弧线** — 关卡按时间线排列：早会(热身) → 午前Deadline(节奏加速) → 午后危机(高潮) → 加班最终Boss(压轴)
5. **即时难度调整** — 如果两位玩家都快没血了，Boss的进攻频率会自动稍微降低；不卡关，但也不轻松

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | 玩家可以自由选择Combo风格、双人配合方式、攻击节奏 | Core |
| **Competence** | Combo系统让玩家看到自己的成长痕迹；同一个Boss可以打得更好 | Core |
| **Relatedness** | 双人合作是核心体验——一起胜利、一起笑、一起"太真实了" | **Core** |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion) — 推进叙事、击败每个Boss、收集Boss背后的隐喻故事
- [ ] **Explorers** (discovery) — 探索每个Boss的隐喻机制，发现"这个设计太绝了"的瞬间
- [x] **Socializers** (relationships) — **核心受众**；情侣、朋友组队，核心乐趣是"一起玩"
- [ ] **Killers/Competitors** — 不是对抗性游戏，不强调PvP或排名

### Flow State Design

- **Onboarding curve**: 第一个Boss（早会Boss）设计得极其简单，教会核心战斗和双人配合，不设血条惩罚
- **Difficulty scaling**: Boss种类多但单个机制简单，玩家可以"熟悉"每个Boss而不是"苦练"
- **Feedback clarity**: Combo数字、命中特效、节奏音效——三重反馈让玩家清楚知道自己打得好不好
- **Recovery from failure**: 失败后快速重开，Boss战中途不reload；但也不会无限续命——失败积累到一定程度会触发Game Over，重开本关

---

## Core Loop

### Moment-to-Moment (30 seconds)

两位玩家在横版战场上**不断移动、连击、闪避**。目标是保持Combo、避免中断、找到攻击窗口。30秒的战斗节拍内，应该有2-3次"我躲开那下了！"和"我们配合得很好！"的瞬间。

### Short-Term (5-15分钟 / 单个Boss)

一个Boss从出现到击败，约2-4分钟。过程中Boss会有2-3个阶段，每阶段引入一种新攻击方式。玩家在**学习→实践→掌握**的循环中推进。"再打一次就能过"的心理是核心驱动。

### Session-Level (30-90分钟 / 完整工作日)

完整经历**早会Boss(热身) → 午前Deadline Boss → 午后危机Boss → 加班最终Boss**。结尾是两人一起战胜"加班"这个最终困境的情感高潮。Session自然结束在"我们下班了"的成就感中。

### Long-Term Progression

**故事模式，单次体验。** 不堆叠周目，不追求无尽模式。玩家通关后可以选择重新挑战任意Boss（用于练习或刷高评分），但核心驱动是一次完整的情感体验。

### Retention Hooks

- **Curiosity**: 每个Boss代表什么困境？理解了会心一笑
- **Investment**: 第一次通关是体验，之后重新挑战是为了打更高评分
- **Social**: 和朋友/伴侣一起玩是核心场景；通关后讨论"哪个Boss最真实"

---

## Game Pillars

### Pillar 1: 协作即意义

两位玩家不是各自打怪，而是在**互相依赖**中前进。一个人的失败就是两个人的失败，一个人的胜利也是两个人的胜利。

*Design test*: 如果在"一人carry一人看"和"两人都有事做"之间选择，选后者。

### Pillar 2: 打工人视角，不说教

用打工人的眼睛看世界，不居高临下批判"躺平"或"卷"，而是**理解和释放**。笑点是共情，不是讽刺。

*Design test*: 这段幽默是让人"太真实了"还是"太夸张了"？优先前者。

### Pillar 3: 战斗即隐喻

每个Boss的**战斗机制本身**在讲述这种困境。攻击方式、视觉效果、甚至Boss的形态都是困境的化身。

*Design test*: 这个Boss的机制能不能用一句话说出它代表的困境？

### Pillar 4: 轻快节奏，不过度煽情

整体基调是**温暖有力的**，不是苦涩或沉重的。Boss战之间有过渡，但不拖沓。高潮是那种"我们一起扛过来了"的爽感。

*Design test*: 这段节奏是让人"更想继续"还是"喘口气"？优先前者。

### Anti-Pillars (What This Game Is NOT)

- **NOT硬核挑战游戏**: 不会因为死了重来整个Boss；失败是过程，不是惩罚
- **NOT叙事烧脑游戏**: 不需要玩家反复阅读文本理解剧情；理解是自然而然的
- **NOT单人游戏**: 纯双人合作，不存在单人通关
- **NOT黑暗讽刺游戏**: 不以挖苦打工为目的；基调是释放和共鸣，不是愤怒

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| 双人成行 (It Takes Two) | 双人合作叙事结构，协作机制即叙事 | 不是3D平台冒险，是横版动作Boss Rush；不是分屏叙事，是同一战场协作 | 验证了"协作+荒诞设定"的市场吸引力 |
| 双影奇境 (We Are One) | 两人共享身体/能力的设定，视觉风格 | 不是解谜为主，是战斗为主；更强调动作满足感 | 验证了2D双人合作的可行性 |
| 吸血鬼幸存者 | Boss Rush结构，"再来一局"的循环心理 | 不是无尽波次，是叙事关卡；双人合作版本 | 验证了"每局Boss战"的可重复游玩价值 |

**Non-game inspirations**:
- 打工人的职场meme文化（"996"、"开会开到下班"）— 提供了丰富的Boss设计素材
- 喜剧中的"情绪宣泄"理论 — 笑可以释放压力，打Boss也是一种释放

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-40 |
| **Gaming experience** | Casual到Mid-core；不需要是硬核玩家 |
| **Time availability** | 30-90分钟的完整Session；工作日晚上或周末 |
| **Platform preference** | PC (Steam) |
| **Current games they play** | 双人成行、糖豆人、你裁我剪！等合作游戏 |
| **What they're looking for** | 和朋友/伴侣一起玩的轻松体验；有共鸣感但不过于沉重的题材；动作战斗的满足感 |
| **What would turn them away** | 硬核难度；需要大量时间投入；单人游戏 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — 原生2D引擎，2D物理精确，内存占用低，GDScript上手极快；非常适合横版动作游戏 |
| **Key Technical Challenges** | 双人本地合作的网络/输入分离；Combo系统的视觉反馈层次设计 |
| **Art Style** | 2D手绘风格，色彩鲜明，角色设计简约但表情丰富 |
| **Art Pipeline Complexity** | Medium — 需要角色立绘、Boss立绘、背景图、粒子特效；所有资源可2D完成 |
| **Audio Needs** | Moderate — 战斗音效（命中、Combo音效）、Boss语音（无台词，用音效表达）、背景音乐（轻快但紧张） |
| **Networking** | 无需网络；纯本地双人（键盘双控制器 or 手柄×2） |
| **Content Volume** | 约4个Boss，3-4个场景/关卡，1-2小时游戏时长 |
| **Procedural Systems** | 无程序生成；所有内容手工设计 |

---

## Risks and Open Questions

### Design Risks
- Combo系统是否能支撑整个游戏？如果Boss种类多但战斗机制都差不多，会感觉重复
- 困境Boss的隐喻设计是否能让足够多的玩家"有同感"？地域/行业差异可能导致理解门槛

### Technical Risks
- Godot 4.6的2D动画系统是否满足Combo特效的层次需求？
- 本地双人输入分离是否会出现延迟或冲突？

### Market Risks
- 双人合作游戏市场竞争激烈；题材差异化是否能被正确传达？
- Steam上"职场讽刺"类游戏口碑两极分化；定位需要精准

### Scope Risks
- 4周内完成4个Boss + 场景 + 双人合作系统，对单人开发来说紧张但可行
- Art pipeline是最大瓶颈；需要提前确认视觉风格

### Open Questions
- 角色的"第二自我"长什么样？玩家1和玩家2的角色是否有差异化设计？
- Boss的出现顺序是否固定？还是可以根据随机选择？
- Boss战之间是否有过渡动画/场景？还是纯战斗无缝衔接？

---

## MVP Definition

**Core hypothesis**: 两位玩家能在流畅的Combo战斗中，通过协作克服职场困境Boss，体验到"我们一起扛过来了"的情感共鸣。

**Required for MVP**:
1. 一个完整可玩的Boss战（推荐：Deadline Boss — 最能体现"战斗即隐喻"）
2. 双人本地合作系统（键盘双键位 or 手柄×2）
3. Combo连击系统 + 视觉反馈
4. 基本的角色和Boss视觉风格验证

**Explicitly NOT in MVP**:
- 所有4个Boss；先做一个验证核心假设
- 完整的叙事弧线和过场动画
- 评分/评价系统

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1个Boss（Deadline Boss）+ 练习关卡 | 双人合作 + Combo系统 + 基本视觉反馈 | 1-2 weeks |
| **Vertical Slice** | 4个Boss + 早会/午前/午后/加班4个场景 | 完整Combo + Boss机制 + 叙事过渡 | 3-4 weeks |
| **Alpha** | 所有Boss + 所有场景 + 基础UI | 所有内容，音效完整，可以发布Demo | 4-6 weeks |
| **Full Vision** | Alpha + 评分系统 + 解锁内容 + Steam发布准备 | 所有功能和发布级质量 | 6-8 weeks |

---

## Visual Identity Anchor

*(注: 完整Visual Identity由/art-bible定义，此处为概念阶段的锚点记录)*

**方向名称**: [待/art-bible后确认]

**一行视觉法则**: [待/art-bible后确认]

**初步方向描述**:
- 色调：**温暖有力**，不是黑暗讽刺的冷色，也不是过于卡通的荧光色
- 角色：简约轮廓，夸张但不过分的表情；两位主角是对称的，但色调/配饰有区分
- Boss：视觉直接反映其代表的困境，但经过"梦境化"处理——不完全是现实
- 整体感受：像一个**手绘动画风格的工作日讽刺漫画**

---

## Next Steps

- [ ] 完成概念文档后，运行 `/setup-engine` 配置 Godot 4.6
- [ ] 运行 `/art-bible` 创建完整的视觉身份规范
- [ ] 运行 `/map-systems` 将概念分解为独立系统
- [ ] 运行 `/design-system [first-system]` 撰写首个系统GDD
- [ ] 原型核心机制：`/prototype combo-boss`
- [ ] 用 `/playtest-report` 验证核心假设
- [ ] 如果验证通过，用 `/sprint-plan new` 规划首个冲刺
