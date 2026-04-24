# Input System

> **Status**: In Design
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 — 协作即意义

## Overview

输入系统管理所有玩家输入的读取、解析和分发。在这款双人合作游戏中，系统需要同时处理两套独立的输入设备（键盘双键位或手柄×2），确保每位玩家的操作被精确识别并路由到对应的游戏角色。

**核心职责：**
1. **输入采集** — 从键盘/手柄读取原始输入事件
2. **输入解析** — 将原始事件转换为游戏动作（移动、攻击、闪避等）
3. **输入分发** — 将解析后的动作路由到对应玩家角色的控制模块
4. **冲突处理** — 检测和处理两套输入设备之间的竞争（如同时按下）

**与协作的关联：**
玩家对"游戏响应"的直接感受几乎全部来自输入系统——按键到画面反应的延迟、操作的精确性、双人同时输入时的稳定性。如果输入系统不可靠，"协作即意义"的体验会立即崩溃。

**技术约束（Godot 4.6）：**
- 双焦点系统：鼠标/触摸焦点与键盘/手柄焦点已分离
- 使用 `StringName`（`&"action"`）而非字符串字面量
- SDL3 手柄后端需要正确的设备检测

## Player Fantasy

**玩家幻想：** 每一下按键都即时、精确地转化为游戏动作，让协作的默契不被打断。

**情感锚点：**
- **即时感** — 按下按钮的瞬间，角色立即响应，没有"我按了但没反应"的挫败感
- **精确感** — 每次输入都被准确识别，不会出现"我想左但角色右"的情况
- **稳定性** — 双人同时输入时不会出现冲突或延迟，操作体验始终如一

**参考游戏对标：**
- 《双人成行》的输入响应 — 没有任何输入延迟破坏协作体验
- 《蔚蓝》的输入精度 — 玩家信任输入，失败后知道是自己的问题而非系统问题

**反面教材（避免）：**
- 输入延迟超过 3 帧会产生"迟钝感"
- 同时按键时出现"按键丢失"会让协作体验崩溃

## Detailed Design

### Core Rules

**1. 输入设备检测**
- 游戏启动时自动检测已连接的输入设备
- 优先检测顺序：手柄×2 → 键盘（检测到键盘则默认Player 1）
- 运行时切换：插入手柄时自动切换，移除手柄时回退到键盘

**2. 输入动作映射**

*Player 1（键盘）：*
| 动作 | 键位 |
|------|------|
| 移动左 | A |
| 移动右 | D |
| 跳跃 | W |
| 闪避 | S |
| 轻攻击 | J |
| 重攻击 | K |

*Player 2（键盘）：*
| 动作 | 键位 |
|------|------|
| 移动左 | ← |
| 移动右 | → |
| 跳跃 | ↑ |
| 闪避 | ↓ |
| 轻攻击 | Numpad 1 |
| 重攻击 | Numpad 2 |

*手柄（两人相同映射）：*
| 动作 | 手柄按钮 |
|------|---------|
| 移动 | 左摇杆 |
| 跳跃 | A Button |
| 闪避 | B Button |
| 轻攻击 | X Button |
| 重攻击 | Y Button |

**3. 输入读取与分发**
- 每帧（`_physics_process`）读取输入状态
- 移动使用 `Input.get_action_raw_strength()` 获取模拟量
- 离散动作使用 `Input.is_action_just_pressed()`
- 每个玩家的输入路由到对应的 `PlayerController` 节点

**4. 无冲突键盘设计原则**
- Player 1 键位：左侧键盘区（WASD + 左手能触及的功能键）
- Player 2 键位：右侧键盘区（方向键 + 右手能触及的数字键）
- 零键位重叠

### States and Transitions

输入系统本身无状态机，但维护每个玩家的**输入缓冲**：

| 状态 | 描述 | 持续时间 |
|------|------|---------|
| 输入激活 | 按键被按下，数值=1.0 | 按住时持续 |
| 输入冷却 | 动作刚触发完，等待冷却 | 动作定义的冷却时间 |
| 输入无效 | 当前状态下该输入不响应 | 状态持续期间 |

### Interactions with Other Systems

**输出 → 战斗系统：**
- 发送：当前帧的移动向量（`Vector2`）
- 发送：动作触发信号（`jumped`、`attacked`、`dodged`）

**输出 → 双人协作系统：**
- 发送：两位玩家的当前输入状态（用于协作连接线显示）

**依赖 ← Godot Input Map：**
- 所有动作在 `project.godot` 的 InputMap 中预定义
- 使用 `StringName`（`&"move_left"`）而非字符串字面量

## Formulas

**1. 模拟输入处理（Dead Zone）**

```
raw_input = Input.get_action_raw_strength(&"action")
clamped_input = dead_zone_removal(raw_input, DEAD_ZONE_THRESHOLD)

if raw_input < DEAD_ZONE_THRESHOLD:
    clamped_input = 0.0
else:
    clamped_input = (raw_input - DEAD_ZONE_THRESHOLD) / (1.0 - DEAD_ZONE_THRESHOLD)
```

| 参数 | 值 | 说明 |
|------|-----|------|
| DEAD_ZONE_THRESHOLD | 0.15 | 手柄摇杆死区，低于此值视为0 |
| 输出范围 | 0.0 - 1.0 | 归一化后的输入强度 |

**2. 输入缓冲窗口**

```
buffered_input = {
    action: action_name,
    timestamp: current_frame_time,
    buffer_duration: INPUT_BUFFER_DURATION
}

if current_time - buffered_input.timestamp <= INPUT_BUFFER_DURATION:
    trigger_action(buffered_input.action)
```

| 参数 | 值 | 说明 |
|------|-----|------|
| INPUT_BUFFER_DURATION | 100ms | 允许的输入提前量（提前按键但还没到动作执行帧） |

**3. 帧率归一化（用于物理计算）**

```
normalized_delta = delta * (target_framerate / actual_framerate)
```
`delta` 已由 Godot 引擎归一化，但移动向量计算需验证：
- `move_velocity = move_direction * move_speed * normalized_delta`

## Edge Cases

**1. 设备热插拔**
- **如果游戏手柄在游戏中被拔出**：自动切换到键盘模式，弹出提示"Player X 手柄断开，已切换到键盘"
- **如果手柄在游戏中被插入**：自动切换到手柄模式，无需暂停

**2. 多手柄识别**
- **如果连接超过2个手柄**：优先使用前两个已识别的手柄，忽略额外的
- **如果无法区分手柄顺序**：按设备连接的先后顺序分配P1/P2

**3. 键盘键位重叠（P1/P2同时按同一键）**
- **在键盘双键位模式下**：理论上通过键位分离设计避免重叠
- **如果检测到重叠按键**：两个输入都被接受，各自路由到对应玩家

**4. 输入缓冲溢出**
- **如果缓冲队列超过10个输入**：丢弃最旧的输入，只保留最新的
- **防止**：长时间暂停后按一堆键导致连续动作触发

**5. 失焦/暂停时输入**
- **如果游戏窗口失去焦点**：清空所有输入缓冲，停止所有动作
- **恢复焦点时**：从静止状态重新开始，不延续失焦前的输入状态

**6. 未知输入设备**
- **如果检测到未知设备类型**：忽略该设备，继续使用已识别的设备
- **不崩溃**：输入系统作为Autoload运行时，任何异常设备输入不导致游戏中断

## Dependencies

**上游依赖（无 — Foundation层）**

此系统无上游依赖，是所有其他系统的基础。

**下游依赖（被此系统支撑）：**

| 系统 | 依赖内容 | 接口类型 |
|------|---------|---------|
| 战斗系统 | 移动向量、动作信号 | 信号（`jumped`、`attacked`、`dodged`）+ Vector2 |
| Combo连击系统 | 攻击动作触发 | 信号（`attacked`） |
| 双人协作系统 | 两位玩家的输入状态 | Dictionary（player_id → input_state） |
| Boss AI系统 | 无直接依赖 | — |

**接口定义：**

```gdscript
# 信号定义
signal input_action(player_id: int, action: StringName, strength: float)
signal input_device_changed(player_id: int, device_type: String)  # "keyboard" | "gamepad"
```

## Tuning Knobs

| 参数 | 默认值 | 安全范围 | 影响 |
|------|-------|---------|------|
| DEAD_ZONE_THRESHOLD | 0.15 | 0.05 - 0.3 | 太小：手柄漂移；太大：失去精细控制 |
| INPUT_BUFFER_DURATION | 100ms | 50ms - 200ms | 太短：感觉"按了没反应"；太长：输入感觉迟钝 |
| INPUT_BUFFER_MAX_SIZE | 10 | 5 - 20 | 太大：堆积动作太多；太小：缓冲效果不明显 |
| KEYBOARD_POLL_RATE | 60Hz | 60Hz（固定） | Godot 引擎固定 |
| GAMEPAD_POLL_RATE | 60Hz | 60Hz（固定） | Godot 引擎固定 |

**可配置性：**
- 以上参数全部可通过 `InputManager.autoload` 的 exported 变量在编辑器中调整
- 键位映射通过 Godot ProjectSettings → InputMap 配置，不在此GDD中硬编码

## Visual/Audio Requirements

N/A — Foundation层基础设施，无直接视觉/音效输出。

## Acceptance Criteria

**基础功能测试：**

| # | 条件 | 测试方法 |
|---|------|---------|
| AC-1 | P1键盘输入正确响应 | 按下WASD，验证P1角色移动/跳跃与按键一致 |
| AC-2 | P2键盘输入正确响应 | 按下方向键+功能键，验证P2角色响应正确 |
| AC-3 | 手柄输入正确响应 | 连接两个手柄，验证P1/P2各自操作正确 |
| AC-4 | 设备热插拔 | 游戏运行中插入手柄/拔出手柄，验证自动切换 |
| AC-5 | 输入无冲突 | P1和P2同时按键，不出现串扰 |

**性能测试：**

| # | 条件 | 测试方法 |
|---|------|---------|
| AC-6 | 输入延迟 < 3帧 | 示波器测量：按键到画面反应 < 50ms (60fps) |
| AC-7 | 60fps稳定 | 连续输入1分钟，无帧率下降 |

**边界情况测试：**

| # | 条件 | 测试方法 |
|---|------|---------|
| AC-8 | 失焦清空输入 | 窗口失焦后恢复，按键不延续之前状态 |
| AC-9 | 多手柄识别 | 连接3个手柄，验证只使用前两个 |
| AC-10 | 未知设备不崩溃 | 连接未知USB设备，无异常崩溃 |

## Open Questions

**1. 手柄震动支持**
- 问题：是否需要在特定动作时触发手柄震动（如攻击命中、受伤）？
- 决策：建议作为可选功能，不在MVP中实现
- 负责人：UX Designer

**2. 输入重映射**
- 问题：是否允许玩家自定义键位映射？
- 决策：建议V-Slice阶段再决定，MVP使用固定键位
- 负责人：UX Designer

**3. 触摸/移动端支持**
- 问题：未来是否有移动端移植计划？
- 决策：当前平台为PC，触摸支持作为潜在扩展考虑
- 负责人：Product Manager
