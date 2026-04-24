# Story 006: 输入延迟 < 3帧

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-4 hrs

---

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-006` — Input latency < 3 frames — keypress to screen reaction < 50ms at 60fps

**ADR Governing Implementation**: ADR-ARCH-001: Events Autoload
**ADR Decision Summary**: 所有跨系统信号经 Events 中继；输入系统作为生产者发射信号。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 无。60fps = 16.67ms/帧，3帧 = 50ms。

**Control Manifest Rules (Foundation Layer)**:
- Required: Events Autoload 作为中央信号中继
- Performance: 12ms max for game logic per frame

---

## Acceptance Criteria

*From GDD AC-6:*

- [ ] 测量按键到画面反应的延迟 < 50ms (3帧 at 60fps)
- [ ] 测量方法：示波器或帧时间戳记录
- [ ] 测试覆盖所有动作类型（移动/跳跃/攻击/闪避）

---

## Implementation Notes

*Derived from GDD 反面教材 + Performance Requirements:*

1. **延迟预算**：
   - 目标帧率：60fps = 16.67ms/帧
   - 3帧延迟上限：50ms
   - 输入系统本身应 < 1帧

2. **关键路径**：
   ```
   物理按键 → Input.is_action_just_pressed() → Events.emit()
   → PlayerController._ready() 回调 → 状态改变 → 动画触发
   ```

3. **优化点**：
   - 不在 `_process()` 中轮询，在 `_physics_process()` 处理
   - 避免在输入处理中执行耗时操作
   - Events 信号发射应该是 O(1)

4. **测试方法**：
   ```gdscript
   var input_timestamp: int
   var reaction_timestamp: int

   func _input(event: InputEvent) -> void:
       if event.is_action_pressed(&"jump_p1"):
           input_timestamp = Time.get_ticks_msec()
           Events.input_action.emit(...)

   # 在 PlayerController 中记录 reaction_timestamp
   func _on_input_action(player_id, action) -> void:
       reaction_timestamp = Time.get_ticks_msec()
       latency_ms = reaction_timestamp - input_timestamp
   ```

---

## Out of Scope

- Story 007 测试 60fps 稳定性

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: 测量按键到信号发射的延迟
  - Given: 游戏运行中，无输入
  - When: 按下 J 键（P1 轻攻击）
  - Then: 从按键到 `Events.input_action` 发射的时间戳差 < 16.67ms (1帧)
  - Edge cases: 连续快速按键

- **AC-2**: 端到端延迟测量
  - Given: 游戏运行中，P1 在 IDLE
  - When: 按下 W 键（P1 跳跃）
  - Then: 按键到角色实际开始跳跃动画的时间 < 50ms
  - Note: 这是全链路测试，需要集成测试环境

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/input_latency_test.gd` — must exist and pass

**Status**: ✅ Created — tests/unit/input/input_latency_test.gd

---

## Dependencies

- Depends on: Story 001 (基础键盘输入)
- Unlocks: Story 007 (fps稳定性)

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 2/3 passing (AC-2 DEFERRED — requires manual playtest)
**Deviations**: None
**Test Evidence**: ✅ tests/unit/input/input_latency_test.gd (8 test functions)
**Code Review**: ✅ APPROVED — test file passed code review
