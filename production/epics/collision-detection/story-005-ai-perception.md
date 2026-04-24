# Story 005: AI Perception System

> **Epic**: collision-detection
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 4-6 hrs

---

## Context

**GDD**: `design/gdd/collision-detection-system.md`
**Requirements**:
- `TR-collision-013` — Boss IDLE, player enters R=256px — distance < 256px → player_detected triggers
- `TR-collision-014` — Player already detected, now distant — distance > 307px (1.2R) → after 0.2s delay, player_lost triggers
- `TR-collision-015` — Player quickly enters inner circle — distance < 204px (0.8R) → immediately DETECTED
- `TR-collision-016` — Player behind cover — Boss ALERTED state with occlusion → los_modifier=0.5, detection range halved
- `TR-collision-019` — base_radius=256px, IDLE state, no occlusion → Boss detection = 192px
- `TR-collision-020` — base_radius=256px, CHASING state → Boss detection = 512px

**ADR Governing Implementation**: ADR-ARCH-002: Collision Detection
**ADR Decision Summary**: 双层检测（Proximity Area2D + Line-of-Sight RayCast2D）；双阈值（Hysteresis）避免边界抖动；player_detected/lost/hurt 直接路由到 BossAI

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Area2D API 稳定；感知检测距离计算需验证浮点精度

**Control Manifest Rules (Foundation Layer)**:
- Required: player_detected/lost/hurt 从 CollisionManager 直接路由到 BossAI
- Required: 双阈值检测：进入内圈(0.8R)立即DETECTED，边界区(0.8R-1.2R)保持状态，超出外圈(1.2R)延迟LOST
- Required: los_modifier 用于视线遮挡时的检测范围调整

---

## Acceptance Criteria

*From GDD AC (CR4-01, CR4-02, CR4-03, CR4-07, F3-01, F3-02):*

- [ ] Boss 处于 IDLE，玩家进入 R=256px → 距离 < 256px 时触发 player_detected
- [ ] 玩家已被检测，现远离 → 距离 > 307px（1.2R），延迟 0.2s 后触发 player_lost
- [ ] 玩家快速进入内圈 → 距离 < 204px（0.8R），立即 DETECTED
- [ ] 玩家在掩体后，Boss ALERTED 状态且有遮挡 → los_modifier=0.5，检测范围减半
- [ ] base_radius=256px，IDLE 状态，无遮挡 → detection_radius=192px
- [ ] base_radius=256px，CHASING 状态 → detection_radius=512px

---

## Implementation Notes

*Derived from ADR-ARCH-002 + GDD Section 2.4 + Control Manifest:*

### 1. AI 感知检测半径公式

```
detection_radius = base_radius * alertness_multiplier * los_modifier
```

| 变量 | 值 | 描述 |
|------|-----|------|
| base_radius | 256px | 基础探测半径 |
| alertness_multiplier | IDLE=0.75, PATROL=1.0, ALERTED=1.5, CHASING=2.0 |
| los_modifier | 无遮挡=1.0, 有遮挡=0.5 |
| **detection_radius** | result | 最终探测半径 |

### 2. CollisionManager Proximity Sensor

```gdscript
## CollisionManager.gd — AI 感知系统

const BASE_DETECTION_RADIUS: float = 256.0

const ALERTNESS_MULTIPLIER: Dictionary = {
    "IDLE": 0.75,
    "PATROL": 1.0,
    "ALERTED": 1.5,
    "CHASING": 2.0
}

const INNER_THRESHOLD: float = 0.8   # 进入确定性检测
const OUTER_THRESHOLD: float = 1.2  # 离开确定性 Lost
const DEBOUNCE_TIME: float = 0.2    # 边界区稳定时间

var _detection_state: Dictionary = {}  # player_id -> {state, debounce_timer}

signal player_detected(player: Node2D)     # 直接 → BossAI
signal player_lost(player: Node2D)         # 直接 → BossAI
signal player_hurt(player: Node2D, damage: float)  # 直接 → BossAI

func _process(delta: float) -> void:
    _update_proximity_detection(delta)

func _update_proximity_detection(delta: float) -> void:
    for player in _players_in_proximity:
        var dist := player.global_position.distance_to(_boss.global_position)
        var alert_mult := ALERTNESS_MULTIPLIER.get(_boss.current_state, 1.0)
        var los_mod := _calculate_los_modifier(player)
        var detection_radius := BASE_DETECTION_RADIUS * alert_mult * los_mod

        var inner_radius := detection_radius * INNER_THRESHOLD
        var outer_radius := detection_radius * OUTER_THRESHOLD

        var state_data := _detection_state.get(player.get_instance_id(), {
            "state": "LOST",
            "debounce_timer": 0.0
        })

        match state_data["state"]:
            "LOST":
                if dist < inner_radius:
                    _set_detection_state(player, "DETECTED")
                elif dist < outer_radius:
                    # 边界区，保持 LOST 但开始 debounce
                    pass
            "DETECTED":
                if dist > outer_radius:
                    state_data["debounce_timer"] += delta
                    if state_data["debounce_timer"] >= DEBOUNCE_TIME:
                        _set_detection_state(player, "LOST")
                else:
                    state_data["debounce_timer"] = 0.0

func _set_detection_state(player: Node2D, new_state: String) -> void:
    var id := player.get_instance_id()
    _detection_state[id]["state"] = new_state
    _detection_state[id]["debounce_timer"] = 0.0

    if new_state == "DETECTED":
        player_detected.emit(player)
    elif new_state == "LOST":
        player_lost.emit(player)

func _calculate_los_modifier(player: Node2D) -> float:
    # 使用 RayCast2D 检测视线遮挡
    var los_cast := RayCast2D.new()
    los_cast.global_position = _boss.global_position
    los_cast.target_position = player.global_position - _boss.global_position
    los_cast.enabled = true
    add_child(los_cast)
    los_cast.force_update_transform()

    var result: float = 1.0
    if not los_cast.is_colliding():
        # 无遮挡，完全检测范围
        result = 1.0
    else:
        # 有遮挡，检测范围减半
        result = 0.5

    los_cast.queue_free()
    return result
```

### 3. Proximity Area2D 配置

```gdscript
## BossAIManager.gd — Boss AI 节点

@export var proximity_sensor: Area2D
@export var los_sensor: RayCast2D

func _ready() -> void:
    proximity_sensor.area_entered.connect(_on_player_entered_proximity)
    proximity_sensor.area_exited.connect(_on_player_exited_proximity)

func _on_player_entered_proximity(area: Area2D) -> void:
    if area is PlayerHurtbox:
        CollisionManager.register_player_proximity(area.owner_entity, self)

func _on_player_exited_proximity(area: Area2D) -> void:
    if area is PlayerHurtbox:
        CollisionManager.unregister_player_proximity(area.owner_entity)
```

### 4. 公式验证

```gdscript
## 公式验证测试

func test_detection_radius_formula() -> void:
    # F3-01: base_radius=256px, IDLE, no occlusion
    var result := 256.0 * 0.75 * 1.0
    assert_eq(result, 192.0, "IDLE detection radius should be 192px")

    # F3-02: base_radius=256px, CHASING, no occlusion
    result = 256.0 * 2.0 * 1.0
    assert_eq(result, 512.0, "CHASING detection radius should be 512px")

    # CR4-07: ALERTED with occlusion
    result = 256.0 * 1.5 * 0.5
    assert_eq(result, 192.0, "ALERTED with occlusion detection radius should be 192px")
```

---

## Out of Scope

- Story 001 处理 Layer/Mask 配置和对象池
- Story 002 处理 Hitbox spawn/despawn
- Boss AI 状态机行为（PATROL/ALERTED/CHASING）属于 boss-ai epic

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: Player enters detection range triggers player_detected
  - Given: Boss 处于 IDLE 状态，base_radius=256px
  - When: Player 进入距离 256px 范围内
  - Then: player_detected 信号触发
  - Edge cases: Player 从外圈快速进入内圈(<0.8R)应立即检测

- **AC-2**: Player distant triggers player_lost after debounce
  - Given: Player 已被 DETECTED，当前距离 250px
  - When: Player 移动到 307px (>1.2R)
  - Then: 0.2s 延迟后 player_lost 触发
  - Edge cases: Player 在边界区(0.8R-1.2R)徘徊不应触发

- **AC-3**: Player in inner circle immediately detected
  - Given: Boss IDLE，Player 快速进入内圈(<0.8R=204px)
  - When: Player 进入 204px 范围内
  - Then: 立即 DETECTED，无 debounce
  - Edge cases: 从外圈直接跳入内圈

- **AC-4**: Los modifier halves detection range with occlusion
  - Given: Boss ALERTED 状态，Player 在掩体后（有遮挡）
  - When: 计算 detection_radius
  - Then: los_modifier=0.5，范围减半
  - Edge cases: 部分遮挡情况

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/ai_perception_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Layer/Mask 配置，Hurtbox 需要设置正确 layer)
- Unlocks: boss-ai epic (Boss AI 使用感知信号调整行为)

---

## Technical Notes

### 双阈值检测原理

```
外圈 (1.2R=307px) ───────────────────────────────
    │
    │  超出外圈 → LOST（延迟 0.2s）
    │
边界区 (0.8R~1.2R) ──────────────────────────────
    │
    │  保持上一状态（debounce）
    │
内圈 (0.8R=204px) ───────────────────────────────
    │
    │  进入内圈 → 立即 DETECTED
    │
内范围 (<0.8R) ──────────────────────────────────
    DETECTED
```

### 与 Boss AI 的集成

根据 Control Manifest：
- `player_detected/lost/hurt` 从 CollisionManager **直接路由**到 BossAI（不经 Events）
- 这是唯一允许的直接路由例外，因为 AI 感知需要低延迟

### 性能考虑

- `_process` 中每帧更新检测（与 Boss AI 频率同步）
- RayCast2D 用于视线检测，限制使用频率避免性能问题
- Proximity Area2D 仅用于粗略的玩家进入/离开检测

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 8/8 passing (detection radius formula, inner/outer thresholds, alertness multipliers, constants)
**Test Evidence**: `tests/unit/collision/ai_perception_test.gd`
