# Story 003: 手柄输入响应

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-003` — Gamepad input responds correctly — both P1 and P2 gamepad controls work independently

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号。

**Engine**: Godot 4.6 | **Risk**: MEDIUM ⚠️
**Engine Notes**: SDL3 手柄后端在 Godot 4.5 有变化，需验证设备检测模式。多人本地游戏需要同时检测两个手柄。

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继
- Required: 所有跨系统信号经 Events 中继

---

## Acceptance Criteria

*From GDD AC-3:*

- [ ] 连接两个手柄后，P1 手柄控制 P1，P2 手柄控制 P2
- [ ] P1 手柄左摇杆控制 P1 移动
- [ ] P1 手柄 A 键控制 P1 跳跃
- [ ] P1 手柄 B 键控制 P1 闪避
- [ ] P1 手柄 X/Y 键控制 P1 轻/重攻击
- [ ] P2 手柄对应按钮控制 P2 相应动作
- [ ] 手柄摇杆移动使用 DEAD_ZONE (0.15) 去除漂移

---

## Implementation Notes

*Derived from GDD Section 2.2 (手柄映射) + Technical Preferences:*

1. **InputMap 配置**：
   - `move_p1_gamepad` — P1 手柄左摇杆 X/Y 轴
   - `jump_p1_gamepad` — P1 手柄 A 按钮
   - `dodge_p1_gamepad` — P1 手柄 B 按钮
   - `attack_light_p1_gamepad` — P1 手柄 X 按钮
   - `attack_heavy_p1_gamepad` — P1 手柄 Y 按钮
   - 对应 P2 同理，device_index 区分

2. **设备检测**（⚠️ Godot 4.6 SDL3）：
   ```gdscript
   # 检测已连接的手柄数量
   var gamepad_count = Input.get_connected_joypads().size()
   ```

3. **P1/P2 分离**：根据 `Input.get_joy_guid()` 或设备索引分配

4. **Dead Zone 处理**：
   ```gdscript
   var raw = Input.get_action_raw_strength(&"move_p1_gamepad")
   var clamped = dead_zone_removal(raw, 0.15)  # DEAD_ZONE_THRESHOLD
   ```

---

## Out of Scope

- Story 001 处理 P1 纯键盘
- Story 002 处理 P2 纯键盘
- Story 004 处理热插拔

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 两个手柄独立控制 P1 和 P2
  - Given: 两个手柄已连接
  - When: P1 手柄操作，P2 手柄同时操作
  - Then: P1 和 P2 各自正确响应，互不干扰
  - Edge cases: 摇杆死区测试

- **AC-2**: 手柄按钮映射正确
  - Given: P1 手柄已连接
  - When: 按下 A/B/X/Y 按钮
  - Then: 对应 jump/dodge/attack_light/attack_heavy 信号发射
  - Edge cases: 按住多个按钮应分别响应

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/gamepad_input_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/gamepad_input_test.gd

---

## Dependencies

- Depends on: Story 001, Story 002 (先验证键盘输入模式)
- Unlocks: Story 004 (热插拔), Story 005 (同时输入)

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing
**Deviations**: None
**Test Evidence**: ✅ tests/unit/input/gamepad_input_test.gd (11 test functions)
**Code Review**: ✅ APPROVED — godot-specialist 确认所有 SDL3 API 在 Godot 4.6 正常工作
