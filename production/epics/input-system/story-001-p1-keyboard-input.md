# Story 001: 键盘 P1 输入响应

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-001` — P1 keyboard input responds correctly — WASD moves/jumps P1 as expected

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号。输入系统维护每个玩家的输入缓冲，输出原始输入向量和语义动作信号。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 无

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继
- Required: 所有跨系统信号经 Events 中继
- Forbidden: Never 直接节点引用跨系统通信

---

## Acceptance Criteria

*From GDD AC-1:*

- [ ] 按下 W 键，P1 角色向上跳跃
- [ ] 按下 A 键，P1 角色向左移动
- [ ] 按下 D 键，P1 角色向右移动
- [ ] 按下 S 键，P1 角色执行闪避动作
- [ ] 按下 J 键，P1 角色执行轻攻击
- [ ] 按下 K 键，P1 角色执行重攻击
- [ ] 释放所有键后，P1 角色停止移动并回到 IDLE 状态

---

## Implementation Notes

*Derived from ADR-ARCH-001 Implementation Guidelines + GDD Section 2.3:*

1. **InputMap 配置**：在 `project.godot` 中预定义以下 InputMap 动作：
   - `move_left_p1` — A 键
   - `move_right_p1` — D 键
   - `jump_p1` — W 键
   - `dodge_p1` — S 键
   - `attack_light_p1` — J 键
   - `attack_heavy_p1` — K 键

2. **输入读取**：在 `InputManager.gd`（Autoload）的 `_physics_process()` 中：
   - 使用 `Input.is_action_just_pressed()` 检测离散动作（jump/dodge/attack）
   - 使用 `Input.get_action_raw_strength()` 获取移动模拟量

3. **信号发射**：检测到动作时，经 Events 中继：
   ```gdscript
   Events.input_action.emit(player_id: 1, action: &"jump", strength: 1.0)
   ```

4. **路由**：PlayerController 订阅 `Events.input_action`，根据 player_id 过滤处理自己的动作

---

## Out of Scope

- Story 002 处理 P2 键盘输入
- Story 003 处理手柄输入
- Story 005 处理 P1+P2 同时输入

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 按下 W 键，P1 角色向上跳跃
  - Given: P1 在 IDLE 状态，无冷却
  - When: 按下 W 键持续 1 帧
  - Then: `Events.input_action` 发射，player_id=1, action=&"jump"
  - Edge cases: 冷却中按下应该被忽略

- **AC-2**: 按下 A/D 键，P1 角色左右移动
  - Given: P1 在 IDLE 状态
  - When: 按下 A 键，释放后按下 D 键
  - Then: 移动向量依次为 Vector2(-1, 0) 和 Vector2(1, 0)
  - Edge cases: 同时按下 A+D 应该被忽略

- **AC-3**: 按下 S/J/K 键对应闪避/轻攻击/重攻击
  - Given: P1 在 IDLE 状态，无动作冷却
  - When: 分别按下 S/J/K 键
  - Then: `Events.input_action` 分别发射 dodge/attack_light/attack_heavy 信号
  - Edge cases: 攻击中再次按下应该被忽略

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/p1_keyboard_input_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/p1_keyboard_input_test.gd

---

## Dependencies

- Depends on: None (Foundation layer, first story)
- Unlocks: Story 002 (P2 keyboard), Story 003 (gamepad)

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing
**Deviations**: ADVISORY — action 语义命名（去掉 _p1 后缀）符合 GDD 意图，但与最初 Implementation Notes 不同；已与用户确认采用方案A
**Test Evidence**: ✅ tests/unit/input/p1_keyboard_input_test.gd (9 test functions)
**Code Review**: ✅ APPROVED — godot-gdscript-specialist + qa-tester review passed
