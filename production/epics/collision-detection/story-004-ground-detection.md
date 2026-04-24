# Story 004: Ground Detection

> **Epic**: collision-detection
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2-3 hrs

---

## Context

**GDD**: `design/gdd/collision-detection-system.md`
**Requirements**:
- `TR-collision-011` — Player standing on solid platform — after move_and_slide() → is_on_floor() returns true
- `TR-collision-012` — Player jumps off platform — airborne movement → is_on_floor() returns false
- `TR-collision-028` — 30/60/120fps execute same movement — physics simulation → consistent results

**ADR Governing Implementation**: ADR-ARCH-002: Collision Detection
**ADR Decision Summary**: 主方案使用 CharacterBody2D.is_on_floor() + move_and_slide()；固定 physics_ticks_per_second=60

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CharacterBody2D.is_on_floor() API 在 Godot 4.4-4.6 无变化

**Control Manifest Rules (Foundation Layer)**:
- Required: 使用 CharacterBody2D.is_on_floor() + move_and_slide() 进行地面检测
- Required: 固定 physics_ticks_per_second=60，设置 max_physics_steps_per_frame=2

---

## Acceptance Criteria

*From GDD AC (CR3-01, CR3-02, EC4-01):*

- [ ] 玩家站在实心平台上，move_and_slide() 后 → is_on_floor() 返回 true
- [ ] 玩家从平台跃出，空中移动 → is_on_floor() 返回 false
- [ ] 30/60/120fps 执行相同移动 → 物理模拟结果一致

---

## Implementation Notes

*Derived from ADR-ARCH-002 + GDD Section 2.3:*

### 1. 地面检测主方案

```gdscript
## PlayerController.gd — 玩家角色控制器

func _physics_process(delta: float) -> void:
    # 获取输入方向
    var input_direction := Vector2.ZERO
    input_direction.x = Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")

    # 应用移动
    velocity.x = input_direction.x * move_speed

    # 跳跃处理
    if Input.is_action_just_pressed(&"jump") and is_on_floor():
        velocity.y = jump_velocity

    # 重力
    velocity.y += gravity * delta

    # move_and_slide() 自动处理地面检测
    move_and_slide()

    # 在 move_and_slide() 后检查 is_on_floor()
    if is_on_floor():
        _on_grounded()
    else:
        _on_airborne()
```

### 2. 帧率一致性保证

```gdscript
## project.godot 配置

[physics]
common/physics_ticks_per_second=60
common/max_physics_steps_per_frame=2
common/physics_jitter_fix=0.1
```

```gdscript
## PlayerController.gd — 使用 delta 的物理模拟

const GRAVITY: float = 980.0  # pixels/s^2
const JUMP_VELOCITY: float = -400.0  # pixels/s (negative = upward)

func _physics_process(delta: float) -> void:
    # delta 是固定物理步长 (1/60s)
    # 使用 delta 计算确保跨帧率一致性
    velocity.y += GRAVITY * delta
    move_and_slide()
```

### 3. 辅助 RayCast2D（边缘检测）

```gdscript
## PlayerController.gd — 边缘检测（可选）

@export var edge_cast: RayCast2D

func _physics_process(delta: float) -> void:
    move_and_slide()

    # 边缘检测：在地面时向前下方发射射线
    if is_on_floor() and edge_cast != null:
        edge_cast.enabled = true
        edge_cast.target_position = Vector2(forward_direction * 16, 32)
        edge_cast.force_update_transform()
        if not edge_cast.is_colliding():
            # 前方无地面，降低速度或停止
            velocity.x *= 0.8

func _on_grounded() -> void:
    # 重置边缘检测状态
    pass

func _on_airborne() -> void:
    # 空中时禁用边缘检测
    if edge_cast:
        edge_cast.enabled = false
```

---

## Out of Scope

- Story 001 处理 Layer/Mask 配置
- Story 002 处理 Hitbox spawn/despawn
- Story 003 处理碰撞检测信号

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: is_on_floor() returns true when standing on platform
  - Given: Player 站在实心平台（WORLD layer）上
  - When: move_and_slide() 执行后
  - Then: is_on_floor() 返回 true
  - Edge cases: 半透明平台边缘情况

- **AC-2**: is_on_floor() returns false when airborne
  - Given: Player 从平台边缘跃出
  - When: 空中移动时
  - Then: is_on_floor() 返回 false
  - Edge cases: 刚离开平台边缘的瞬间

- **AC-3**: Consistent physics at 30/60/120fps
  - Given: 相同的初始状态（位置、速度）
  - When: 分别在 30fps、60fps、120fps 下执行相同的跳跃序列
  - Then: 最终落地位置和速度一致
  - Edge cases: 帧率波动时的 physics_jitter_fix 效果

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/ground_detection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Layer/Mask 配置)
- Unlocks: Story 002 (Hitbox spawn/despawn 需要 is_on_floor() 信息)

---

## Technical Notes

### is_on_floor() 行为说明

`CharacterBody2D.is_on_floor()` 在以下情况返回 true：
- 身体下方有碰撞体（在 last_safe_transform 范围内）
- 最近一次 `move_and_slide()` 调用使身体停在碰撞体上

注意：`is_on_floor()` 在 `move_and_slide()` 后才正确更新，必须在每次 `move_and_slide()` 后重新检查。

### 帧率一致性关键点

1. **固定物理步长**: `physics_ticks_per_second=60` 保证每帧物理步长固定为 1/60s
2. **max_physics_steps_per_frame=2**: 防止低帧率时物理累积延迟
3. **physics_jitter_fix=0.1**: 缓解帧率抖动对物理模拟的影响
4. **delta 用于重力计算**: `velocity.y += GRAVITY * delta` 确保重力与帧率成正比

### 与 Hitbox 系统的关系

地面状态影响：
1. **命中信号**: `attack_hit` 信号需要 `is_grounded` 参数
2. **击退方向**: 地面时击退方向更水平，空中时更垂直

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 5/5 passing (is_on_floor behavior, physics consistency, jump physics, constants verification)
**Test Evidence**: `tests/unit/collision/ground_detection_test.gd`
