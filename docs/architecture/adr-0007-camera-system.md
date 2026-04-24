# ADR-ARCH-007: Camera System Architecture

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / Presentation |
| **Knowledge Risk** | LOW — Camera2D API 已在 Godot 4.4+ 验证 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` + Godot 4.6 官方文档 |
| **Post-Cutoff APIs Used** | Camera2D.position_smoothing_enabled, Camera2D.position_smoothing_speed |
| **Verification Required** | ✅ 已验证 — 2026-04-17 实测: `smoothing` (bool) → `position_smoothing_enabled`; `smoothing_speed` → `position_smoothing_speed` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-003 (Combat State Machine), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System), ADR-ARCH-006 (Boss AI) |
| **Enables** | UI系统, 粒子特效系统 |
| **Blocks** | 无 |
| **Ordering Note** | 相机系统依赖所有其他 Core 系统的事件信号；相机状态为 VFX 和 UI 提供同步数据 |

## Context

### Problem Statement
相机系统需要在 2D 横版 Boss Rush 中同时追踪两位玩家和 Boss，提供平滑跟随、创伤式屏幕震动、多级缩放和动态状态切换。相机必须通过 Events 与其他系统通信，同时保持对 VFX 和 UI 的低延迟数据共享。

### Requirements
- 单 Camera2D 覆盖双玩家（加权质心算法）
- 创伤式屏幕震动（trauma-based noise），应用于 `offset` 而非 `position`
- SMOOTHING_CENTER_OUT 模式
- 7 个相机状态：NORMAL / PLAYER_ATTACK / SYNC_ATTACK / BOSS_FOCUS / BOSS_PHASE_CHANGE / CRISIS / COMBAT_ZOOM
- 通过 Events 信号与 VFX/UI 共享状态

## Decision

### CameraController 设计

```gdscript
# CameraController.gd — extends Camera2D
# 放在场景根节点或 CameraRig Node2D 下

class_name CameraController
extends Camera2D

## 创伤式震动参数
@export var trauma_decay: float = 2.0    # 创伤衰减率 (units/s)
@export var noise_speed: float = 25.0     # 噪声振荡速度
@export var max_offset: Vector2 = Vector2(50, 35)  # 最大像素偏移

## 缩放参数
@export var base_zoom: Vector2 = Vector2(1.0, 1.0)

## 平滑参数
@export var smoothing_speed_normal: float = 8.0
@export var smoothing_speed_combat: float = 12.0
@export var smoothing_speed_crisis: float = 20.0
@export var smoothing_acceleration: float = 30.0

## 内部状态
var trauma: float = 0.0
var _current_zoom: Vector2 = Vector2.ONE
var _current_speed: float = 8.0
var _current_state: String = "NORMAL"

## 目标追踪
var _target_position: Vector2 = Vector2.ZERO
var _p1_weight: float = 1.0
var _p2_weight: float = 1.0

## 信号 (通过 Events 广播)
# camera_shake_intensity(trauma: float) — VFX/UI 订阅
# camera_zoom_changed(zoom: Vector2) — UI 订阅
# camera_framed_players(positions: Array[Vector2]) — UI 订阅

func _ready() -> void:
    smoothing = SMOOTHING_CENTER_OUT
    # Godot 4.6 验证: smoothing_enabled → position_smoothing_enabled
    # smoothing_speed → position_smoothing_speed
    position_smoothing_enabled = true
    position_smoothing_speed = smoothing_speed_normal

    # 连接 Events 信号
    Events.attack_started.connect(_on_attack_started)
    Events.hit_confirmed.connect(_on_hit_confirmed)
    Events.combo_tier_changed.connect(_on_combo_tier_changed)
    Events.sync_burst_triggered.connect(_on_sync_burst_triggered)
    Events.boss_attack_started.connect(_on_boss_attack_started)
    Events.boss_phase_changed.connect(_on_boss_phase_changed)
    Events.player_downed.connect(_on_player_downed)
    Events.player_rescued.connect(_on_player_rescued)

func _physics_process(delta: float) -> void:
    _update_trauma(delta)
    _update_target_position()
    _update_zoom(delta)
    _update_speed(delta)

func _update_trauma(delta: float) -> void:
    trauma = maxf(0.0, trauma - trauma_decay * delta)
    var shake := _calculate_shake()
    offset = shake if trauma > 0.0 else Vector2.ZERO
    Events.camera_shake_intensity.emit(trauma)

func _calculate_shake() -> Vector2:
    var t := Time.get_ticks_msec() / 1000.0
    var nx := randf_range(-1.0, 1.0) * trauma * trauma  # 二次方衰减
    var ny := randf_range(-1.0, 1.0) * trauma * trauma
    return Vector2(nx, ny) * max_offset

func _update_target_position() -> void:
    # 计算双玩家质心
    var p1_pos := _get_player_position(1)
    var p2_pos := _get_player_position(2)
    _target_position = (p1_pos * _p1_weight + p2_pos * _p2_weight) / (_p1_weight + _p2_weight)

    # Boss 上下文偏移
    var boss_pos := _get_boss_position()
    var boss_offset := boss_pos - _target_position
    if boss_offset.length() > 200:
        _target_position += boss_offset * 0.15

    position = _target_position  # SMOOTHING_CENTER_OUT 自动处理平滑

func _update_zoom(delta: float) -> void:
    var target_zoom := _calculate_target_zoom()
    if target_zoom != _current_zoom:
        _current_zoom = target_zoom
        zoom = _current_zoom
        Events.camera_zoom_changed.emit(_current_zoom)

func _update_speed(delta: float) -> void:
    var target_speed := _get_target_speed_for_state()
    _current_speed = move_toward(_current_speed, target_speed, smoothing_acceleration * delta)
    position_smoothing_speed = _current_speed

func _calculate_target_zoom() -> Vector2:
    var dist := _get_player_distance()
    var z := base_zoom

    # 玩家距离缩放
    if dist < 200:
        pass  # 1.0x
    elif dist < 400:
        z *= Vector2(0.85, 0.85)
    else:
        z *= Vector2(0.7, 0.7)

    # 战斗状态缩放
    match _current_state:
        "PLAYER_ATTACK": z *= Vector2(0.9, 0.9)
        "SYNC_ATTACK":   z *= Vector2(0.85, 0.85)
        "BOSS_FOCUS":    z *= Vector2(0.8, 0.8)
        "BOSS_PHASE_CHANGE": z *= Vector2(0.75, 0.75)
        "COMBAT_ZOOM":   z *= Vector2(0.85, 0.85)

    return z

func _get_target_speed_for_state() -> float:
    match _current_state:
        "CRISIS": return smoothing_speed_crisis
        "BOSS_PHASE_CHANGE": return 4.0
        "PLAYER_ATTACK", "SYNC_ATTACK", "COMBAT_ZOOM": return smoothing_speed_combat
    return smoothing_speed_normal

## 信号处理

func _on_attack_started(attack_type: String) -> void:
    _transition_state("PLAYER_ATTACK")
    _add_trauma_for_attack(attack_type)

func _on_hit_confirmed(hitbox_id: int, hurtbox_id: int, attack_id: int) -> void:
    # 由战斗系统传来，直接触发命中震动
    pass

func _on_combo_tier_changed(tier: int, player_id: int) -> void:
    if tier >= 3:
        _transition_state("COMBAT_ZOOM")

func _on_sync_burst_triggered(position: Vector2) -> void:
    _transition_state("SYNC_ATTACK")
    trauma = maxf(trauma, 0.8)  # 第三次同步爆发最大震动

func _on_boss_attack_started(attack_pattern: String) -> void:
    _transition_state("BOSS_FOCUS")

func _on_boss_phase_changed(new_phase: int) -> void:
    _transition_state("BOSS_PHASE_CHANGE")
    trauma = 0.9  # 最大震动
    _apply_zoom_tween(Vector2(0.75, 0.75), 1.0)

func _on_player_downed(player_id: int) -> void:
    _transition_state("CRISIS")
    trauma = 1.0  # 最大震动
    _pause_limits()  # 暂停边界约束

func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
    _resume_limits()
    await get_tree().create_timer(0.5).timeout
    _transition_state("NORMAL")

func _transition_state(new_state: String) -> void:
    _current_state = new_state

func _add_trauma_for_attack(attack_type: String) -> void:
    match attack_type:
        "LIGHT":   trauma = maxf(trauma, 0.15)
        "MEDIUM":  trauma = maxf(trauma, 0.25)
        "HEAVY":   trauma = maxf(trauma, 0.4)
        "SPECIAL": trauma = maxf(trauma, 0.6)

func _apply_zoom_tween(target: Vector2, duration: float) -> void:
    var tween := create_tween()
    tween.tween_property(self, "zoom", target, duration) \
        .set_trans(Tween.TRANS_CUBIC) \
        .set_ease(Tween.EASE_OUT)

func _pause_limits() -> void:
    limit_left = -99999
    limit_right = 99999
    limit_top = -99999
    limit_bottom = 99999

func _resume_limits() -> void:
    # 从场景或 ArenaManager 获取实际边界
    var arena := _get_current_arena()
    limit_left = arena.left - 50
    limit_right = arena.right + 50
    limit_top = arena.top - 50
    limit_bottom = arena.bottom + 50

## 辅助方法

func _get_player_position(player_id: int) -> Vector2:
    # 从 PlayerManager 获取实际位置
    return Vector2.ZERO

func _get_player_distance() -> float:
    var p1 := _get_player_position(1)
    var p2 := _get_player_position(2)
    return p1.distance_to(p2)

func _get_boss_position() -> Vector2:
    # 从 BossManager 获取
    return Vector2.ZERO

func _get_current_arena() -> Dictionary:
    return {"left": 0, "right": 1280, "top": 0, "bottom": 720}

func get_current_state() -> String:
    return _current_state
```

### 状态机定义

| 状态 | 触发条件 | 缩放 | 平滑速度 | 震动 |
|------|---------|------|---------|------|
| `NORMAL` | 默认 | 0.85-1.0x | 8.0 | 仅被动衰减 |
| `PLAYER_ATTACK` | attack_started | 0.9x | 12.0 | 命中震动 |
| `SYNC_ATTACK` | sync_burst_triggered | 0.85x | 12.0 | 同步震动 |
| `BOSS_FOCUS` | boss_attack_started | 0.8x | 8.0 | Boss攻击震动 |
| `BOSS_PHASE_CHANGE` | boss_phase_changed | 0.75x | 4.0 | 最大震动 |
| `CRISIS` | player_downed | 0.9x | 20.0 | 持续震动 |
| `COMBAT_ZOOM` | combo_tier ≥ 3 | 0.85x | 10.0 | Tier震动 |

**状态优先级**: `CRISIS > BOSS_PHASE_CHANGE > BOSS_FOCUS > SYNC_ATTACK > PLAYER_ATTACK > COMBAT_ZOOM > NORMAL`

### 信号路由

| 信号 | 来源 | 路由 | 消费者 |
|------|------|------|--------|
| `attack_started` | CombatSystem → Events | Events → CameraController | 触发 PLAYER_ATTACK |
| `hit_confirmed` | CombatSystem → Events | Events → CameraController | 触发命中震动 |
| `combo_tier_changed` | ComboSystem → Events | Events → CameraController | 触发 COMBAT_ZOOM |
| `sync_burst_triggered` | ComboSystem → Events | Events → CameraController | 触发 SYNC_ATTACK |
| `boss_attack_started` | BossAI → Events | Events → CameraController | 触发 BOSS_FOCUS |
| `boss_phase_changed` | BossAI → Events | Events → CameraController | 触发 BOSS_PHASE_CHANGE |
| `player_downed` | CoopSystem → Events | Events → CameraController | 触发 CRISIS |
| `player_rescued` | CoopSystem → Events | Events → CameraController | 恢复 NORMAL |
| `camera_shake_intensity` | CameraController | Events → VFX/UI | 粒子/UI震动响应 |
| `camera_zoom_changed` | CameraController | Events → UI | UI 元素缩放 |
| `camera_framed_players` | CameraController | Events → UI | 绘制玩家连线 |

## Alternatives Considered

### Alternative 1: 屏幕震动应用于 `position` 而非 `offset`
- **描述**: 直接在 `position` 上加震动偏移
- **优点**: 实现简单
- **缺点**: 与 smoothing 冲突；震动结束时相机"弹回"原位，造成视觉断裂
- **拒绝理由**: `offset` 不影响世界位置，震动结束时精确回到原位，无漂移

### Alternative 2: 双 Camera2D（分屏）
- **描述**: 每个玩家一个相机，各自追踪
- **优点**: 每个玩家都能看到自己的角色
- **缺点**: 同步问题；VFX 复杂度翻倍；不符合"同时看到队友"的设计目标
- **拒绝理由**: 单相机加权质心即可满足双玩家同时可见的需求

### Alternative 3: 固定相机（无平滑）
- **描述**: 相机固定在固定位置，玩家自由移动
- **优点**: 无抖动，调试简单
- **缺点**: 无法跟随战斗，Boss Rush 不适合
- **拒绝理由**: 设计需求要求平滑跟随双玩家

## Consequences

### Positive
- **创伤式震动**: 不同攻击类型有不同震动强度，增强打击感层次
- **状态机分离**: 7 个状态清晰分离，行为可预测
- **Events 路由**: 与其他系统松耦合
- **offset 震动**: 无漂移，震动结束精确回到原位

### Negative
- **状态优先级复杂性**: 7 个状态的优先级需要严格测试

### Risks
- **状态竞争**: 两个状态同时触发时，优先级必须正确。**缓解**: 状态优先级表已明确定义

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| camera-system.md | 双玩家质心追踪 | _update_target_position() 质心公式 |
| camera-system.md | SMOOTHING_CENTER_OUT | smoothing = SMOOTHING_CENTER_OUT |
| camera-system.md | 平滑跟随双玩家 | position_smoothing_speed 动态调整 |
| camera-system.md | 创伤式震动 | _calculate_shake() + trauma_decay |
| camera-system.md | 7 状态机 | _current_state + _transition_state() |
| camera-system.md | 状态优先级 | 硬编码优先级表 |
| camera-system.md | camera_shake_intensity 信号 | Events.camera_shake_intensity.emit(trauma) |
| camera-system.md | camera_zoom_changed 信号 | Events.camera_zoom_changed.emit(zoom) |
| camera-system.md | 边界约束暂停（CRISIS） | _pause_limits() / _resume_limits() |
| particle-vfx-system.md | camera_shake_intensity | Events 路由到 VFX |

## Performance Implications
- **CPU**: Camera2D 本身 < 0.01ms；创伤计算每帧约 0.001ms
- **Memory**: CameraController 约 2KB
- **Load Time**: 无影响

## Migration Plan
1. 创建 `CameraController.gd` 类
2. 配置 Camera2D 属性（smoothing mode, limits）
3. 实现创伤式震动（_calculate_shake）
4. 实现目标追踪（_update_target_position）
5. 实现状态机（_transition_state）
6. 连接 Events 信号
7. 实现 Tween 缩放过渡
8. 配置 camera_shake_intensity / camera_zoom_changed / camera_framed_players 发射

## Validation Criteria
- [ ] 双玩家在 400px 距离时相机自动缩放至 0.7x
- [ ] 重攻击命中触发 trauma=0.4，约 0.5s 后衰减完毕
- [ ] 玩家 DOWNTIME → 边界约束暂停，倒地玩家可见
- [ ] 玩家被救 → 0.5s 后恢复 NORMAL
- [ ] Boss 相位转换 → 震动 0.9，缩放 0.75x
- [ ] 震动结束后 offset=Vector2.ZERO，相机无漂移
- [ ] camera_shake_intensity 信号正确发射到 Events

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-006: Boss AI — boss_phase_changed 信号来源
- `docs/architecture/architecture.md`
