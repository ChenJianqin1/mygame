# Story 002: 键盘 P2 输入响应

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002` — P2 keyboard input responds correctly — arrow keys + numpad control P2 as expected

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 无

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继
- Required: 所有跨系统信号经 Events 中继
- Forbidden: Never 直接节点引用跨系统通信

---

## Acceptance Criteria

*From GDD AC-2:*

- [ ] 按下 ↑ 键，P2 角色向上跳跃
- [ ] 按下 ← 键，P2 角色向左移动
- [ ] 按下 → 键，P2 角色向右移动
- [ ] 按下 ↓ 键，P2 角色执行闪避动作
- [ ] 按下 Numpad 1，P2 角色执行轻攻击
- [ ] 按下 Numpad 2，P2 角色执行重攻击
- [ ] 释放所有键后，P2 角色停止移动并回到 IDLE 状态

---

## Implementation Notes

*Derived from GDD Section 2.2 (Player 2 键盘映射):*

1. **InputMap 配置**：
   - `move_left_p2` — ← 键
   - `move_right_p2` — → 键
   - `jump_p2` — ↑ 键
   - `dodge_p2` — ↓ 键
   - `attack_light_p2` — Numpad 1
   - `attack_heavy_p2` — Numpad 2

2. **输入读取**：与 Story 001 相同模式，player_id = 2

3. **信号发射**：
   ```gdscript
   Events.input_action.emit(player_id: 2, action: &"jump", strength: 1.0)
   ```

---

## Out of Scope

- Story 001 处理 P1 键盘输入
- Story 003 处理手柄输入
- Story 005 处理 P1+P2 同时输入

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 按下方向键，P2 角色响应正确方向
  - Given: P2 在 IDLE 状态
  - When: 按下 ↑/←/→/↓ 键
  - Then: `Events.input_action` 发射 player_id=2 对应 action
  - Edge cases: 与 P1 同时按方向键不应互相干扰

- **AC-2**: 按下 Numpad 1/2，P2 执行轻/重攻击
  - Given: P2 在 IDLE 状态
  - When: 按下 Numpad 1 和 Numpad 2
  - Then: `Events.input_action` 分别发射 attack_light 和 attack_heavy
  - Edge cases: 攻击中再次按下应被忽略

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/p2_keyboard_input_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/p2_keyboard_input_test.gd

---

## Dependencies

- Depends on: None (Foundation layer)
- Unlocks: Story 003 (gamepad), Story 005 (simultaneous input)

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: ✅ tests/unit/input/p2_keyboard_input_test.gd (9 test functions)
**Code Review**: ✅ APPROVED — 与 Story 001 模式完全对称
