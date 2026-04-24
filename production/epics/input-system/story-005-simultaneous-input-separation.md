# Story 005: P1+P2 同时输入无冲突

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17
> **Est**: 3-5 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005` — No input conflicts — P1 and P2 can press keys simultaneously without crosstalk

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号。player_id 参数确保信号路由正确。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 无

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继
- Required: 所有跨系统信号经 Events 中继
- Required: `player_id` 参数正确传递

---

## Acceptance Criteria

*From GDD AC-5 + Edge Cases 3:*

- [ ] P1 按 WASD，P2 按方向键，两套输入同时被识别
- [ ] P1 用键盘、P2 用手柄，同时操作互不干扰
- [ ] P1 和 P2 各自的操作信号正确携带 player_id
- [ ] 键盘键位无重叠（左侧 WASD vs 右侧方向键）
- [ ] 同时按下相排斥的键（如 P1 按 A 和 D）应互相抵消

---

## Implementation Notes

*Derived from GDD Section 2.4 (无冲突键盘设计原则) + Edge Cases 3:*

1. **键位分离设计**：
   - P1 键盘：左侧 A/D/S/W + 左手能触及的 J/K
   - P2 键盘：右侧方向键 + 右手能触及的 Numpad 1/2
   - 零键位重叠

2. **player_id 路由**：
   ```gdscript
   func _physics_process() -> void:
       if Input.is_action_just_pressed(&"jump_p1"):
           Events.input_action.emit(player_id: 1, action: &"jump", strength: 1.0)
       if Input.is_action_just_pressed(&"jump_p2"):
           Events.input_action.emit(player_id: 2, action: &"jump", strength: 1.0)
   ```

3. **同时按键处理**：GDD 要求各自路由，P1 和 P2 的输入本身已分离

---

## Out of Scope

- Story 001 处理 P1 单独键盘
- Story 002 处理 P2 单独键盘
- Story 003 处理手柄单独输入

---

## QA Test Cases

**Integration Test Specs (Integration story)**:

- **AC-1**: P1+P2 同时键盘输入无串扰
  - Given: P1 和 P2 都在 IDLE 状态
  - When: P1 按 W 同时 P2 按 ↑
  - Then: 两个 jump 信号分别发射，player_id 分别为 1 和 2
  - Edge cases: P1 按 A+D 同时应互相抵消

- **AC-2**: P1 键盘 + P2 手柄同时使用
  - Given: P1 键盘已连接，P2 手柄已连接
  - When: P1 按 A，P2 按手柄左摇杆
  - Then: P1 移动向量为 Vector2(-1, 0)，P2 移动向量为手柄摇杆值
  - Edge cases: 无

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/input/simultaneous_input_separation_test.gd` — must exist and pass

**Status**: ✅ Created — tests/integration/input/simultaneous_input_separation_test.gd

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003 (各自独立功能正常)
- Unlocks: Story 006 (输入延迟)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: ✅ tests/integration/input/simultaneous_input_separation_test.gd (9 test functions)
**Code Review**: ✅ APPROVED — 测试文件通过代码审查
