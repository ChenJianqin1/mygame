# Story 009: 多手柄识别

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-009` — Multi-gamepad detection — 3+ gamepads connected, only first two are used

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继。

**Engine**: Godot 4.6 | **Risk**: MEDIUM ⚠️
**Engine Notes**: Godot 4.6 中 `Input.get_connected_joypads()` 返回所有已连接手柄的 device_index 列表。

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继

---

## Acceptance Criteria

*From GDD AC-9 + Edge Cases 2:*

- [ ] 连接 3 个或更多手柄时，只有前两个被识别和使用
- [ ] 前两个手柄按连接顺序分配为 P1 和 P2
- [ ] 第三个及之后的手柄被忽略，无异常
- [ ] 无法区分手柄顺序时，按设备连接先后分配

---

## Implementation Notes

*Derived from GDD Edge Cases 2:*

1. **设备列表获取**：
   ```gdscript
   var connected_joypads = Input.get_connected_joypads()
   # 返回 device_index 列表，按连接顺序排列
   ```

2. **只使用前两个**：
   ```gdscript
   if connected_joypads.size() >= 2:
       p1_device = connected_joypads[0]
       p2_device = connected_joypads[1]
   elif connected_joypads.size() == 1:
       p1_device = connected_joypads[0]
       p2_device = -1  # 无 P2 手柄
   ```

3. **忽略额外手柄**：不做任何处理，静默忽略

---

## Out of Scope

- Story 003 处理手柄基础输入功能
- Story 004 处理手柄热插拔

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 3个手柄连接，只有前两个有效
  - Given: 3个手柄已连接
  - When: P1 手柄按下 A，P3 手柄按下 A
  - Then: 只有 P1 响应，P3 被忽略
  - Edge cases: 按连接顺序而非 device_index

- **AC-2**: 只有1个手柄时的行为
  - Given: 只有1个手柄连接
  - When: 该手柄按下 A
  - Then: 分配为 P1 控制，P2 使用键盘
  - Edge cases: 无

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/multiple_gamepad_detection_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/multiple_gamepad_detection_test.gd (9 test functions) — APPROVED

---

## Dependencies

- Depends on: Story 003 (手柄基础功能)
- Unlocks: Story 010 (未知设备)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 4/4 passing
**Deviations**: None
**Test Evidence**: ✅ tests/unit/input/multiple_gamepad_detection_test.gd (9 test functions) — APPROVED via code review
**Code Review**: ✅ APPROVED — 3 files reviewed, all APPROVED
**Files Created/Modified**: src/autoload/Events.gd (added device_assigned signal), src/input/gamepad_input_reader.gd (emit device_assigned on assignment)
