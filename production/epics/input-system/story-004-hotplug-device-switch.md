# Story 004: 设备热插拔自动切换

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-004` — Hot-plug device switching — inserting/removing gamepad mid-game triggers automatic switch

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号。

**Engine**: Godot 4.6 | **Risk**: MEDIUM ⚠️
**Engine Notes**: Godot 4.6 中 `Input.joy_connection_changed` 信号可用于热插拔检测。

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继
- Required: 所有跨系统信号经 Events 中继

---

## Acceptance Criteria

*From GDD AC-4 + Edge Cases 1:*

- [ ] 游戏运行中插入手柄，自动切换到手柄模式，无需暂停
- [ ] 游戏运行中拔出手柄，自动切换到键盘模式
- [ ] 切换时显示提示："Player X 手柄已连接/断开"
- [ ] 切换过程不中断当前游戏状态
- [ ] 重新插入手柄后，自动恢复手柄模式

---

## Implementation Notes

*Derived from GDD Edge Cases 1:*

1. **热插拔监听**：
   ```gdscript
   func _ready() -> void:
       Input.joy_connection_changed.connect(_on_joy_connection_changed)

   func _on_joy_connection_changed(device_index: int, connected: bool) -> void:
       # connected=true: 新手柄插入
       # connected=false: 手柄拔出
       _update_device_mapping()
   ```

2. **自动切换逻辑**：
   - 插入手柄 → 切换到该手柄控制对应玩家
   - 拔出手柄 → 检查是否还有手柄，有则切换，无则切换到键盘

3. **提示显示**：通过 UI 系统显示临时 toast 提示

4. **状态保持**：切换不改变玩家的实际游戏状态（HP/位置等）

---

## Out of Scope

- Story 003 处理手柄基础输入功能
- Story 005 处理多手柄同时输入

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 插入手柄自动切换到手柄模式
  - Given: 游戏运行中，两个手柄未连接
  - When: 插入 P1 手柄
  - Then: P1 控制自动切换到手柄，对应手柄按钮响应
  - Edge cases: 插入第三个手柄应被忽略

- **AC-2**: 拔出手柄自动切换到键盘
  - Given: P1 使用手柄控制
  - When: P1 手柄被拔出
  - Then: P1 自动切换到键盘控制，显示提示
  - Edge cases: 同时拔两个手柄应切换到纯键盘

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/hotplug_device_switch_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/hotplug_device_switch_test.gd

---

## Dependencies

- Depends on: Story 003 (手柄基础功能)
- Unlocks: Story 005 (同时输入)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 5/5 passing
**Deviations**: None (test helper minor discrepancy — does not affect production code)
**Test Evidence**: ✅ tests/unit/input/hotplug_device_switch_test.gd (11 test functions)
**Code Review**: ✅ APPROVED — critical device-stealing bug fixed, all ACs covered
