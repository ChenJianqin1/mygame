# UX Spec: Pause Menu

> **Status**: Complete
> **Author**: ux-designer
> **Last Updated**: 2026-04-18
> **Journey Phase(s)**: Gameplay — accessible from any gameplay state
> **Template**: UX Spec

---

## Purpose & Player Need

**玩家目标**：暂停游戏，与搭档沟通战术，或者休息一下

**核心功能**：
- 立即暂停游戏进程（所有动画、游戏逻辑冻结，Rescue Timer 除外）
- 提供离开选项（返回标题）和继续游戏选项
- 提供设置访问（音量、亮度）— 无需退出游戏即可调整
- 提供控制说明参考 — 两位玩家可以随时查看当前控制方式

**如果这个屏幕不存在或难以使用**：
- 玩家无法在需要时暂停，导致被迫中断（比如来电、休息需求）
- 设置调整必须退出游戏，破坏体验连续性
- 合作玩家无法在战斗中沟通战术
- 新玩家无法在游戏中查阅控制方式（必须回忆或查文档）

**玩家到达这个屏幕的情绪状态**：
- 意图暂停 — 可能是：来电/门铃、需要休息、与搭档讨论战术、单纯的"喘口气"
- 情绪：轻松为主，但可能有战斗紧张残留

---

## Player Context on Arrival

**何时看到**：
- 游戏过程中任何时刻（Basic tier 要求：Pause anywhere）
- 包括：Boss Intro（等待 1.5s 后才可暂停）、Gameplay HUD、Boss 战斗中

**前置活动**：
- 玩家正在战斗中、正在观看 Boss Intro、或者在场景过渡中
- 可能 P1 或 P2 刚刚按下了 Pause 键

**玩家情绪状态**：
- 可能轻微紧张（战斗中）到完全放松（喘息时刻）
- 意图明确：需要暂停，不需要探索

**注意**：Pause 菜单是**游戏过程中**的入口，与主菜单的"起点"完全不同。玩家是"中途进入"。

---

## Navigation Position

**导航树位置**：

```
[Root] Title Screen
    └── Boss Intro → Gameplay HUD
            └── PAUSE (Overlay — 从 Gameplay HUD 按键触发)
                    ├── Resume → Gameplay HUD
                    ├── 设置 (子菜单)
                    │       ├── 音量设置
                    │       └── 亮度设置
                    ├── 帮助
                    │       └── Control 说明
                    └── 返回标题 → Title Screen
```

**特点**：
- Pause 是 Gameplay HUD 上的**覆盖层**，不是独立屏幕
- 从 Pause 可以返回游戏（Resume）或返回标题（退出当前 session）
- ESC / Pause 键是全局触发器，游戏任何时刻可激活（Boss Intro 期间除外 — 有 1.5s 锁定）
- Pause 状态下，Gameplay HUD 保持可见但**半透明遮罩**覆盖

---

## Entry & Exit Points

### 进入来源

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Gameplay HUD | P1 或 P2 按下 ESC / Pause 键 | 完整的游戏状态（HP、Combo、Boss HP 等全部冻结可见） |
| Boss Intro | 等待 1.5s 后按下 ESC / Pause | Boss 名称和轮廓可见，游戏即将开始 |
| (理论上) Boss Defeated | 可以暂停 | Victory 动画或 Game Over 屏幕之前 |

**限制**：Boss Intro 期间有 1.5s 锁定，期间 Pause 输入被忽略（防止玩家在 Boss 还没介绍完就暂停跳过）

### 退出目标

| Exit Destination | Trigger | Notes |
|---|---|---|
| Gameplay HUD (Resume) | 选择"继续"或按 ESC/Pause 再次 | 游戏逻辑恢复，Rescue Timer 继续（如果正在倒计时） |
| Title Screen | 选择"返回标题" | 放弃当前 session，弹确认对话框防止误触 |
| Settings 子菜单 | 选择"设置" | 进入二级菜单 |
| 帮助子菜单 | 选择"帮助" | 进入二级菜单，显示 Control 说明 |

### 确认对话框

**返回标题**需要二次确认（防止误触）：
- 弹出一个小型便签对话框："确定要返回标题吗？当前进度将丢失。"
- 选项：[ 确定 ] [ 取消 ]
- 键盘：Enter = 确定，ESC = 取消
- 手柄：A = 确定，B = 取消

---

## Layout Specification

### Information Hierarchy

**层级 1（最重要）**：
1. "暂停" 标题 — 确认当前状态是暂停
2. "继续" 按钮 — 最高优先级操作（玩家最常需要的动作）

**层级 2（次要）**：
3. "设置" 按钮 — 音量/亮度调整
4. "帮助" 按钮 — Control 说明查阅
5. "返回标题" 按钮 — 退出确认

### Layout Zones

**布局方案：便签堆叠 (Sticky-Note Stack)**

基于 Art Bible 的便签美学：
- 全屏半透明遮罩（rgba(0,0,0,0.4)）覆盖游戏画面
- 中央主面板：便签堆叠效果 — 多张黄色 #F8F5E8 纸叠加，最上层承载内容
- 面板从屏幕顶部滑入（slide-down，Art Bible 规范 350ms）
- 面板尺寸：最大 480×520px，居中显示

### ASCII Wireframe

```
┌─────────────────────────────────────────────────────────────┐
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░┌───────────────────────────┐░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓▓▓▓ 便  签  堆  ▓▓▓▓▓│░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓  暂 停  ▓▓▓▓▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓ [ 继  续 ] ▓▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓ [ 设    置 ] ▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓ [ 帮    助 ] ▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓ [ 返回标题 ] ▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░└───────────────────────────┘░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
└─────────────────────────────────────────────────────────────┘
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░ 半透明遮罩 rgba(0,0,0,0.4) ░░░░░░░░░░░░░░░░░░░░░
```

### Component Inventory

| 组件 | 类型 | 内容 | 说明 |
|------|------|------|------|
| PauseOverlay | Visual | 全屏半透明黑色遮罩 rgba(0,0,0,0.4) | 覆盖游戏画面，底下游戏状态可见 |
| StickyNotePanel | Container | 便签堆叠面板，480×520px | 纸张白 #F8F5E8，手撕边缘，叠加阴影 |
| PauseTitle | Text | "暂停" | 顶部，手绘风格字体，24px |
| ResumeButton | Button | "继续" | 最高优先级，主按钮 |
| SettingsButton | Button | "设置" | 进入音量/亮度子菜单 |
| HelpButton | Button | "帮助" | 进入 Control 说明子菜单 |
| QuitButton | Button | "返回标题" | 退出确认对话框 |
| ConfirmDialog | Dialog | 确认对话框 | 防止误触返回标题 |
| SettingsPanel | Container | 设置子菜单面板 | 与主面板样式一致 |
| BGMVolumeSlider | Slider | 音量滑块（0-100）+ 图标 | 音乐音量调节 |
| SFXVolumeSlider | Slider | 音量滑块（0-100）+ 图标 | 音效音量调节 |
| UIVolumeSlider | Slider | 音量滑块（0-100）+ 图标 | UI 音效音量调节 |
| BrightnessSlider | Slider | 亮度滑块（-50% ~ +50%） | 屏幕亮度调节 |
| HelpPanel | Container | 帮助子菜单面板 | 与主面板样式一致 |
| P1Controls | Text/List | P1 键盘+手柄 控制说明 | 当前映射显示 |
| P2Controls | Text/List | P2 键盘+手柄 控制说明 | 当前映射显示 |
| CoopTip | Text | "双人合作技巧" | 简短提示 |

---

## States & Variants

### Screen States

| State | Trigger | 视觉变化 |
|-------|---------|---------|
| Hidden | 游戏运行中，无 Pause | Pause UI 完全不渲染 |
| Entering | ESC/Pause 按下 | 遮罩从 0 到 0.4 淡入（0.2s），面板从顶部滑入（0.35s，Art Bible 规范） |
| Active (主菜单) | 面板完全显示 | 显示主菜单：继续/设置/帮助/返回标题 |
| Active (设置) | 选择"设置" | 面板内容切换为设置面板（淡入淡出，0.2s） |
| Active (帮助) | 选择"帮助" | 面板内容切换为帮助面板（淡入淡出，0.2s） |
| ConfirmDialog | 选择"返回标题" | 小型确认便签对话框弹出在其他按钮上方 |
| Exiting | 选择"继续"或再次按 ESC | 面板向顶部滑出（0.25s），遮罩淡出（0.2s） |

### Button States

| State | 视觉变化 |
|-------|---------|
| Default | 便签按钮底板 #F8F5E8，文字 #2D2D2D |
| Hover/Focus | 晨曦橙 #F5A623 手绘边框高亮 + 1.05x 缩放 |
| Pressed | 打勾金 #FFD700 墨水扩散反馈（按下时 0.1s） |
| Disabled | 50% 透明度（无 — 暂停菜单没有禁用状态） |

### 子菜单返回行为

| 从子菜单返回 | 行为 |
|------------|------|
| Settings → 主菜单 | 面板内容淡出→淡入回到主菜单（0.2s） |
| Help → 主菜单 | 面板内容淡出→淡入回到主菜单（0.2s） |
| ConfirmDialog → 主菜单 | 对话框消失，主菜单按钮恢复 |

### Empty State / Error State

**空状态不适用于 Pause 菜单** — Pause 菜单是游戏状态的覆盖层，不依赖数据。

**错误状态**：
- 如果音量/亮度设置读取失败，使用默认值（BGM=80, SFX=80, UI=80, Brightness=0）
- 如果控制映射读取失败，帮助面板显示"控制映射加载中..."并提供联系支持的方式

### Loading State

Pause 菜单激活时，所有内容已经加载（无异步数据）。设置滑块使用当前值初始化。

---

## Interaction Map

**输入设备**：Keyboard/Mouse（主）+ Gamepad（支持）

### 主菜单交互

| 按键 | 动作 | 即时反馈 | 结果 |
|------|------|---------|------|
| ESC / Pause 键 | 暂停/继续 | 面板滑入或滑出 | 切换 Pause 显示状态 |
| 键盘↑/W | 上移焦点 | 按钮高亮切换 | 在按钮间循环移动 |
| 键盘↓/S | 下移焦点 | 按钮高亮切换 | 在按钮间循环移动 |
| Enter / Space | 确认选择 | 墨水扩散动画 | 执行当前按钮动作 |
| 手柄 D-pad 上 | 上移焦点 | 按钮高亮切换 | 在按钮间循环移动 |
| 手柄 D-pad 下 | 下移焦点 | 按钮高亮切换 | 在按钮间循环移动 |
| 手柄 A | 确认选择 | 墨水扩散动画 | 执行当前按钮动作 |
| 手柄 B | 返回/取消 | 如果在子菜单→返回主菜单；如果在确认对话框→取消 | 上下文相关 |

### 设置子菜单交互

| 按键 | 动作 | 即时反馈 | 结果 |
|------|------|---------|------|
| 键盘←/A | 减小值 | 滑块向左移动 | BGM/SFX/UI 音量 -5，亮度 -5% |
| 键盘→/D | 增大值 | 滑块向右移动 | BGM/SFX/UI 音量 +5，亮度 +5% |
| 手柄 D-pad 左 | 减小值 | 滑块向左移动 | 同上 |
| 手柄 D-pad 右 | 增大值 | 滑块向右移动 | 同上 |
| ESC / 手柄 B | 返回主菜单 | 面板内容淡出→淡入 | 回到 Pause 主菜单 |

### 帮助子菜单交互

| 按键 | 动作 | 即时反馈 | 结果 |
|------|------|---------|------|
| ESC / 手柄 B | 返回主菜单 | 面板内容淡出→淡入 | 回到 Pause 主菜单 |

### 确认对话框交互

| 按键 | 动作 | 即时反馈 | 结果 |
|------|------|---------|------|
| Enter / 手柄 A | 确认"返回标题" | 淡出到 Title Screen | 退出当前 session |
| ESC / 手柄 B | 取消 | 对话框消失 | 回到主菜单，无退出 |

---

## Events Fired

| 玩家动作 | 触发事件 | 携带数据 | 说明 |
|---------|---------|---------|------|
| 按 ESC/Pause | `pause_toggled` | is_paused: bool | 全局 Pause 切换信号 |
| 选择"继续" | `pause_resumed` | — | 游戏逻辑恢复 |
| 选择"设置" | `pause_enter_settings` | — | UI 进入设置子面板 |
| 调整音量滑块 | `volume_changed` | bus: String, value: int | 实时更新，发送到 AudioManager |
| 调整亮度滑块 | `brightness_changed` | value: int | 实时更新，发送到 DisplayManager |
| 选择"帮助" | `pause_enter_help` | — | UI 进入帮助子面板 |
| 选择"返回标题" | `quit_confirm_requested` | — | 弹出确认对话框 |
| 确认"返回标题" | `return_to_title` | — | 切换到 Title Screen |
| 取消"返回标题" | `quit_confirm_cancelled` | — | 对话框消失 |

**注意**：Pause 菜单发出的事件主要作用于 UI 状态和 UI → GameState 的请求。实际的音量/亮度变化需要游戏系统响应 `volume_changed` / `brightness_changed` 信号。

---

## Transitions & Animations

### Screen Enter Transition (游戏 → Pause)

| 步骤 | 时长 | 动画 |
|------|------|------|
| 1 | 0.0s | ESC/Pause 按下，触发 |
| 2 | 0.0s - 0.2s | 半透明遮罩 rgba(0,0,0,0) → rgba(0,0,0,0.4) 淡入 |
| 3 | 0.0s - 0.35s | StickyNotePanel 从 y=-520 滑入到 y=居中 (ease-out) |
| 4 | 0.35s 完成 | Pause 菜单完全显示 |

### Screen Exit Transition (Pause → 游戏)

| 步骤 | 时长 | 动画 |
|------|------|------|
| 1 | 0.0s | 选择"继续"或再次按 ESC，触发 |
| 2 | 0.0s - 0.25s | StickyNotePanel 从 y=居中滑出到 y=-520 (ease-in) |
| 3 | 0.0s - 0.2s | 半透明遮罩 rgba(0,0,0,0.4) → rgba(0,0,0,0) 淡出 |
| 4 | 0.25s 完成 | 游戏逻辑恢复 |

### Sub-panel Transitions

**主菜单 ↔ 设置**：
- 主菜单淡出（0.1s）→ 设置面板淡入（0.1s）
- 总时长：0.2s

**主菜单 ↔ 帮助**：
- 同上

**返回主菜单**：
- 当前面板淡出 → 主菜单淡入（0.2s）

### Button Animations

| 动画 | 规格 | 缓动 |
|------|------|------|
| Hover 高亮 | 边框 #F5A623，scale 1.0 → 1.05 | ease-out，0.15s |
| Pressed 墨水扩散 | 背景闪 #FFD700，scale 1.05 → 0.98 | linear，0.1s |
| Focus 指示器 | 晨曦橙手绘边框（与 Hover 共用） | — |

### Slider Animations

| 动画 | 规格 | 缓动 |
|------|------|------|
| 滑块移动 | Thumb 跟随滑轨，实时响应 | linear（无延迟） |
| 数值变化 | 数字标签实时更新 | — |

### Confirm Dialog Animation

| 步骤 | 时长 | 动画 |
|------|------|------|
| 弹出 | 0.0s - 0.15s | 从 scale=0.8 弹到 scale=1.0 (ease-out) |
| 消失 | 0.0s - 0.1s | scale=1.0 → scale=0.8，淡出 |

### Reduced Motion

如果玩家启用了 reduced motion 选项（Accessibility 设置）：
- 所有 slide 动画改为 instant cut（无移动）
- 淡入淡出改为 instant show/hide
- 弹跳/缩放动画改为无
- Pause 激活：遮罩 instant 0.4，按钮 instant 显示

---

## Data Requirements

### Displayed Data

| 数据 | 来源系统 | 读/写 | 说明 |
|------|---------|--------|------|
| 当前音量（BGM/SFX/UI） | AudioManager | 读 | 显示当前值在滑块旁 |
| 当前亮度 | DisplayManager | 读 | 显示当前偏移值（-50% ~ +50%） |
| P1 控制映射 | InputManager | 读 | 从配置的 keybind 读取 |
| P2 控制映射 | InputManager | 读 | 从配置的 keybind 读取 |
| 游戏暂停状态 | GameState | 读 | is_paused 布尔值 |

### 写入数据

| 数据 | 写入目标 | 说明 |
|------|---------|------|
| BGM 音量 | AudioManager | 实时更新，范围 0-100 |
| SFX 音量 | AudioManager | 实时更新，范围 0-100 |
| UI 音量 | AudioManager | 实时更新，范围 0-100 |
| 亮度偏移 | DisplayManager | 实时更新，范围 -50 ~ +50 |
| Pause 激活状态 | UIManager | 触发 UI 状态切换 |

### 状态管理

**Pause 菜单 UI 内部状态**：
- `current_panel`: MAIN / SETTINGS / HELP
- `confirm_dialog_visible`: bool
- `selected_button_index`: int（用于键盘/手柄焦点）

这些状态由 PauseMenuScreen 内部管理（UIState），不写入游戏全局状态。

**暂停冻结范围**（来自 ui-system.md Rule 5）：
- Hitstop (1-6 frames)：UI 继续更新，Rescue Timer 正常倒计时
- Full pause：所有 UI 更新冻结，**除了 Rescue Timer**（倒计时暂停但可见）

---

## Accessibility

### Basic Tier 覆盖

| 功能 | 状态 | 实现说明 |
|------|------|---------|
| 最低字体大小 | **必须实现** | 按钮文字 ≥ 20px，说明文字 ≥ 16px |
| 文本对比度 | **必须实现** | 文字 #2D2D2D 在 #F8F5E8 背景上对比度 9.2:1，≥ 4.5:1 |
| 键盘导航 | **必须实现** | 方向键移动焦点，Enter 确认，ESC 取消/返回 |
| 手柄导航 | **必须实现** | D-pad 移动焦点，A 确认，B 返回/取消 |
| 按钮最小尺寸 | **必须实现** | 44×44px（Art Bible 规范） |
| Pause anywhere | **必须实现** | 游戏任何时刻可触发暂停（Boss Intro 1.5s 锁定除外） |
| Reduced motion | **必须实现** | 所有动画改为 instant cut |

### 键盘/手柄焦点导航

**焦点顺序**（主菜单）：
1. "继续"（默认焦点）
2. "设置"
3. "帮助"
4. "返回标题"

**焦点移动**：
- 键盘：↑/W 上，↓/S 下，循环
- 手柄：D-pad 上/下，循环

**焦点样式**：
- 当前焦点：晨曦橙 #F5A623 手绘边框 + 1.05x 缩放
- 与 Hover 样式共用（键盘和手柄焦点使用相同视觉）

### 颜色使用

**主面板**：#F8F5E8 纸张白背景
**文字**：#2D2D2D 深色（对比度 9.2:1）
**焦点边框**：#F5A623 晨曦橙
**按下反馈**：#FFD700 打勾金

**注意**：Pause 菜单不涉及 P1/P2 颜色区分，焦点用橙色统一表示。

### 屏幕阅读器支持

Pause 菜单使用 Godot Control 节点，理论上可被 AccessKit 覆盖。但：
- 中文文本的屏幕阅读支持需要 Godot 4.6 AccessKit 验证
- 当前 Basic tier 不要求屏幕阅读器支持（仅要求菜单可键盘/手柄导航）
- 如果未来需要屏幕阅读器支持，按钮需要添加 `accessible_description` 属性

### 特殊情况

**Rescue Timer 在 Full Pause 期间的行为**：
- Timer 倒计时暂停（不消耗剩余时间）
- Timer 圆圈保持显示，但不进行径流动画
- 这个行为是功能性的，不是动画问题

---

## Localization Considerations

### 文本元素

| 元素 | 当前文字 | 字符数 | 本地化风险 |
|------|---------|--------|-----------|
| PauseTitle | "暂停" | 2 | 低 — 极短 |
| ResumeButton | "继续" | 2 | 低 |
| SettingsButton | "设置" | 2 | 低 |
| HelpButton | "帮助" | 2 | 低 |
| QuitButton | "返回标题" | 4 | 低 |
| ConfirmDialogText | "确定要返回标题吗？当前进度将丢失。" | 18 | 中 — 需要确认对话框宽度够用 |
| BGMVolumeLabel | "音量" / "音乐" | 2-3 | 低 |
| BrightnessLabel | "亮度" | 2 | 低 |
| P1ControlsTitle | "P1 控制" | 4 | 低 |
| P2ControlsTitle | "P2 控制" | 4 | 低 |

### 布局风险

**确认对话框文字**："确定要返回标题吗？当前进度将丢失。"（18字符）是最长文本元素。

- 英文版："Are you sure? Progress will be lost."（38字符，明显更长）
- 需要确认对话框宽度（最大 480px 面板内）能容纳英文版本
- 建议：对话框最大宽度 400px，文字自动换行

**按钮文字**：
- "返回标题"（4字符）vs "Return to Title"（14字符）— 英文版按钮需要更宽
- 建议：按钮最小宽度 200px，按钮内文字左右留 20px padding

### 未来扩展

如果添加其他语言本地化：
- 所有按钮和标签需要外置字符串表
- 对话框文本需要支持换行
- 音量/亮度标签注意单复数形式（如果语言有区别）

---

## Acceptance Criteria

- [ ] 按 ESC/Pause 键，0.35s 内显示 Pause 菜单（面板滑入 + 遮罩淡入）
- [ ] 选择"继续"或再次按 ESC，0.25s 内关闭 Pause 菜单并恢复游戏
- [ ] "继续"按钮是默认焦点（键盘/手柄首次打开时）
- [ ] 键盘 ↑/↓ 或 手柄 D-pad 上/下 可以在按钮间循环移动焦点
- [ ] Enter/Space 或 手柄 A 确认执行当前按钮动作
- [ ] 手柄 B 在主菜单时返回游戏（与 ESC 等效）
- [ ] 手柄 B 在设置/帮助子菜单时返回主菜单
- [ ] 选择"设置"进入设置面板，音量/亮度滑块可调节
- [ ] 选择"帮助"进入帮助面板，显示 P1/P2 控制说明
- [ ] 选择"返回标题"弹出确认对话框
- [ ] 确认对话框中 Enter/手柄 A 确认退出，ESC/手柄 B 取消
- [ ] 所有按钮最小尺寸 44×44px
- [ ] 焦点按钮显示 #F5A623 橙色边框 + 1.05x 缩放
- [ ] 按下按钮显示 #FFD700 打勾金墨水扩散动画
- [ ] 所有文字与背景对比度 ≥ 4.5:1
- [ ] Reduced motion 选项启用时，所有动画改为 instant cut
- [ ] Boss Intro 期间（1.5s 内）按 ESC/Pause 无响应（1.5s 后正常响应）
- [ ] Full pause 状态下 Rescue Timer 保持可见但不继续倒计时
- [ ] 音量/亮度设置实时生效，退出 Pause 后保持

---

## Open Questions

| # | 问题 | 状态 | 备注 |
|---|------|------|------|
| 1 | 控制重绑定是否在 Pause 菜单的"设置"中？ | Open | 当前 spec 只包含音量/亮度，控制重绑定需要单独页面；如果要做，设置面板需要扩展 |
| 2 | 帮助面板中 P1/P2 控制显示的格式是什么样的？ | Open | 需要与 InputManager 协调，确认 keybind 显示格式（"键A" 还是 "A键"） |
| 3 | 确认对话框的"当前进度将丢失"是否准确？ | Open | 游戏是否有存档点？还是每次都是完整 session？如果没有进度丢失，这个提示是误导 |
| 4 | 设置面板的 3 个音量滑块（BGM/SFX/UI）对应 AudioManager 的哪个 bus？ | Open | 需要与 Audio 系统协调，ADR-ARCH-011 定义了 WCOSS bus 路由 |
| 5 | Reduced motion 选项在 Pause 菜单中是否可见/可调？ | Open | 还是在游戏主设置中统一配置？Pause 菜单的 Settings 是否包含 accessibility 选项 |
| 6 | 手柄 B 按钮在主菜单时返回游戏 vs 取消操作如何区分？ | Open | 当前设计：主菜单按 B = 返回游戏（resume）；如果在子菜单或对话框中按 B = 返回/取消 — 这是否与用户预期一致？ |
| 7 | Boss Intro 1.5s 锁定的实现方式是什么？ | Open | 是在 InputManager 层拦截 Pause 输入，还是在 PauseMenuScreen 层读取 BossIntro 状态？ |
