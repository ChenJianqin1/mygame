# Story 010: 未知设备不崩溃

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-010` — Unknown device no-crash — connecting unknown USB device does not crash the game

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 无。Godot 的 Input 系统本身对未知设备有容错。

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继

---

## Acceptance Criteria

*From GDD AC-10 + Edge Cases 6:*

- [ ] 连接未知 USB 设备时，游戏不崩溃
- [ ] 未知设备被忽略，不影响正常输入
- [ ] 断开未知设备后，游戏继续正常运行
- [ ] 系统不抛出任何未捕获异常

---

## Implementation Notes

*Derived from GDD Edge Cases 6:*

1. **容错设计**：
   - 不对 `Input.get_connected_joypads()` 返回的每个设备做假设
   - 使用 `try/catch`（GDScript 中用 `@warning_ignore` 或条件检查）包装设备操作
   - 未知设备不分配给任何玩家

2. **防御性检查**：
   ```gdscript
   func _process_joypad(device_index: int) -> void:
       if not Input.is_joypad_connected(device_index):
           return  # 安全提前返回
       # 继续处理已知设备
   ```

3. **日志记录**：未知设备连接时记录 debug 日志，但不中断流程

---

## Out of Scope

- Story 009 处理多手柄识别逻辑

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 连接未知 USB 设备游戏不崩溃
  - Given: 游戏正常运行，P1 和 P2 使用已知设备
  - When: 插入未知 USB 设备（如奇怪的控制器）
  - Then: 游戏继续运行，无崩溃，无异常
  - Edge cases: 同时插入多个未知设备

- **AC-2**: 移除未知设备后游戏继续
  - Given: 游戏正常运行，未知设备已连接
  - When: 移除未知 USB 设备
  - Then: 游戏继续正常运行
  - Edge cases: 无

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/unknown_device_resilience_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/unknown_device_resilience_test.gd (9 test functions) — APPROVED

---

## Dependencies

- Depends on: Story 009 (多手柄识别)
- Unlocks: None (最后一个 story)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 4/4 passing
**Deviations**: None
**Test Evidence**: ✅ tests/unit/input/unknown_device_resilience_test.gd (9 test functions) — APPROVED via code review
**Code Review**: ✅ APPROVED — 2 files reviewed, all APPROVED
**Files Created/Modified**: src/input/gamepad_input_reader.gd (added debug logging, defensive is_joypad_connected check, fixed division-by-zero)
