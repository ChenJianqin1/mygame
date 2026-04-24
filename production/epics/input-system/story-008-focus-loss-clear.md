# Story 008: 失焦清空输入状态

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-008` — Focus loss clears input — window blur followed by refocus does not carry over pre-blur input state

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 无

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继

---

## Acceptance Criteria

*From GDD AC-8 + Edge Cases 5:*

- [ ] 游戏窗口失焦后，所有输入缓冲被清空
- [ ] 失焦期间按下的键在恢复焦点后不会触发动作
- [ ] 恢复焦点后，从静止状态开始接受新输入
- [ ] 不延续失焦前的输入状态（如移动方向）

---

## Implementation Notes

*Derived from GDD Edge Cases 5:*

1. **失焦检测**：
   ```gdscript
   func _notification(what: int) -> void:
       if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
           _clear_input_buffer()
           _reset_input_state()
   ```

2. **清空内容**：
   - 清空输入缓冲队列
   - 重置所有"按住"状态（is_action_pressed 返回 false）
   - 发送 `input_cleared` 信号通知其他系统

3. **恢复行为**：
   - 不自动恢复任何状态
   - 必须重新按下按键才能触发动作

---

## Out of Scope

- Story 004 处理设备热插拔

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 失焦清空输入缓冲
  - Given: P1 按下 W 键（jump），输入缓冲中有 jump
  - When: 游戏窗口失焦
  - Then: 输入缓冲被清空
  - Edge cases: 恢复焦点后该 W 键不应触发 jump

- **AC-2**: 失焦期间按键不延续
  - Given: P1 在 IDLE
  - When: 失焦期间按下 W 键，然后恢复焦点
  - Then: P1 不跳跃，必须重新按下 W 才能触发
  - Edge cases: 无

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/focus_loss_clear_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/focus_loss_clear_test.gd (9 test functions) — APPROVED

---

## Dependencies

- Depends on: Story 001 (基础键盘输入)
- Unlocks: Story 009 (多手柄识别)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 4/4 passing
**Deviations**: None
**Test Evidence**: ✅ tests/unit/input/focus_loss_clear_test.gd (9 test functions) — APPROVED via code review
**Code Review**: ✅ APPROVED — 6 files reviewed, all APPROVED
**Files Created/Modified**: src/autoload/Events.gd, src/input/focus_loss_handler.gd (new), src/input/input_manager.gd, src/input/p2_input_reader.gd, src/input/gamepad_input_reader.gd
