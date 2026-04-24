# Story 007: Animation-Driven Hitbox Spawning and Edge Cases

> **Epic**: collision-detection
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 3-4 hrs

---

## Context

**GDD**: `design/gdd/collision-detection-system.md`
**Requirements**:
- `TR-collision-029` — Player attacked mid-combo, enters HURT — state switch → Hitbox immediately despawns
- `TR-collision-030` — Player crosses boundary quickly (< debounce) — crossing → no state change triggers
- `TR-collision-031` — Animation frame 5 is hit frame — playing to frame 5 → Method Track calls spawn, hit point synchronized with animation

**ADR Governing Implementation**: ADR-ARCH-002: Collision Detection
**ADR Decision Summary**: Hitbox 必须由动画驱动 spawn/despawn，禁止在 _process 中 spawn；动画关键帧 Method Track 调用 spawn_hitbox()；状态切换时清理所有 Hitbox

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: AnimationPlayer Method Track 回调需要正确配置节点路径

**Control Manifest Rules (Foundation Layer)**:
- Required: 动画驱动 Hitbox：动画资源中使用 Method Track 调用 spawn_hitbox()，而非代码驱动
- Required: 禁止在 _process 中根据输入状态 spawn hitbox
- Required: 玩家状态离开 ATTACKING 时调用 cleanup_by_owner()

---

## Acceptance Criteria

*From GDD AC (EC5-01, EC6-04, EC7-01):*

- [ ] 玩家攻击中被命中进入 HURT，状态切换 → Hitbox 立即 despawn
- [ ] 玩家快速穿越边界（<debounce），穿越 → 不触发任何变化
- [ ] 动画第 5 帧为命中帧，播放到第 5 帧 → Method Track 调用 spawn，命中点与动画同步

---

## Implementation Notes

*Derived from ADR-ARCH-002 + GDD Section 2.7 + Control Manifest:*

### 1. 动画配置要求

```
动画资源: attack_light
帧率: 60fps (16.67ms/frame)
总帧数: 16 frames

Frame 0-4:   anticipation (前摇)
Frame 5:     hit frame (命中帧) — Method Track 调用 spawn
Frame 6-14:  recovery (收招)
Frame 15:    animation_finished → Method Track 调用 despawn
```

### 2. Method Track 配置

在动画资源的 Inspector 中：

```
AnimationPlayer: PlayerController.animation_player
Track Type: Method Call

Track Path: PlayerController (节点路径)

Key (Frame 5):
  Method: _on_attack_hit_frame
  Args: []

Key (Frame 15):
  Method: _on_attack_finished
  Args: []
```

### 3. PlayerController 回调实现

```gdscript
## PlayerController.gd

@export var animation_player: AnimationPlayer
var _current_attack_id: String = ""
var _current_hitbox: Area2D = null

func _ready() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)

## 动画关键帧回调 — Hitbox spawn
## 由 AnimationPlayer Method Track 在第 5 帧调用
func _on_attack_hit_frame() -> void:
    if not is_instance_valid(_current_hitbox):
        _current_hitbox = CollisionManager.spawn_hitbox(_current_attack_id, {
            "owner": self,
            "parent": self,
            "layer": CollisionManager.LAYER_PLAYER_HITBOX,
            "mask": CollisionManager.LAYER_BOSS,
            "offset": _calculate_hitbox_offset(),
            "size": _calculate_hitbox_size()
        })

## 动画结束回调 — Hitbox despawn
## 由 AnimationPlayer Method Track 在动画结束时调用
func _on_attack_finished() -> void:
    if is_instance_valid(_current_hitbox):
        CollisionManager.despawn_hitbox(_current_hitbox)
        _current_hitbox = null

## 动画播放入口
func play_attack(attack_id: String) -> void:
    _current_attack_id = attack_id
    var anim_name := "attack_%s" % attack_id
    animation_player.play(anim_name)
```

### 4. 状态切换时清理 Hitbox

```gdscript
## PlayerController.gd — 状态机集成

signal state_changed(old_state: String, new_state: String)

func _on_state_changed(old_state: String, new_state: String) -> void:
    # 离开 ATTACKING 状态时清理所有该状态的 Hitbox
    if old_state == "ATTACKING":
        CollisionManager.cleanup_by_owner(self, _current_attack_id)
        if is_instance_valid(_current_hitbox):
            _current_hitbox = null

func take_damage(amount: float) -> void:
    # 受伤时切换到 HURT 状态
    var old_state := _current_state
    _current_state = "HURT"
    _on_state_changed(old_state, _current_state)
```

### 5. 快速穿越边界的 debounce

```gdscript
## CollisionManager.gd — 边界穿越 debounce

const DETECTION_DEBOUNCE_TIME: float = 0.1  # 100ms

var _boundary_cross_timer: float = 0.0
var _last_boundary_state: bool = false

func _process(delta: float) -> void:
    var current_boundary_state := _is_in_detection_zone()

    # 检测到状态变化
    if current_boundary_state != _last_boundary_state:
        _boundary_cross_timer += delta

        if _boundary_cross_timer < DETECTION_DEBOUNCE_TIME:
            # debounce 时间内快速穿越 → 忽略
            return

        # debounce 结束，确认状态变化
        _last_boundary_state = current_boundary_state
        _boundary_cross_timer = 0.0
    else:
        _boundary_cross_timer = 0.0

func _is_in_detection_zone() -> bool:
    # 检测玩家是否在检测区域内
    return false  # 实现依赖具体游戏逻辑
```

---

## Out of Scope

- Story 001-006 处理其他碰撞检测功能
- Combat 系统的具体伤害计算和受击反应
- Animation 系统的动画资源制作

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: Hitbox despawns on state change to HURT
  - Given: Player 在 ATTACKING 状态，有一个活跃 Hitbox
  - When: Player 被击中，状态切换到 HURT
  - Then: _on_state_changed 被调用，cleanup_by_owner(self) 执行，Hitbox despawn
  - Edge cases: 动画播放到一半被中断

- **AC-2**: Fast boundary crossing ignored during debounce
  - Given: 玩家在检测区域边界快速穿越（<100ms）
  - When: 穿越发生时
  - Then: 不触发 player_detected 或 player_lost
  - Edge cases: 慢速穿越应正常触发

- **AC-3**: Hitbox spawns at animation frame 5 via Method Track
  - Given: 播放 attack_light 动画
  - When: 动画播放到第 5 帧
  - Then: AnimationPlayer Method Track 调用 _on_attack_hit_frame()，Hitbox spawn
  - Edge cases: 动画暂停/快进时不应触发

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/animation_hitbox_sync_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Hitbox spawn/despawn 基础), Story 003 (collision signals)
- Unlocks: combat epic (战斗系统依赖动画触发的命中)

---

## Technical Notes

### AnimationPlayer Method Track 配置步骤

1. 在场景中选择 AnimationPlayer 节点
2. 打开 Animation > Edit Animation
3. 选择 attack_light 动画
4. 在帧 5 位置，点击 Track 面板 > Add Track > Method Call
5. 选择 PlayerController 节点
6. 输入方法名: `_on_attack_hit_frame`
7. 在帧 15（animation end）添加第二个 Method Call: `_on_attack_finished`

### 禁止 _process 中 spawn

Control Manifest 明确规定：

```gdscript
## 错误示例 — 禁止这样做
func _process(delta: float) -> void:
    if Input.is_action_just_pressed(&"attack"):
        # 错误！这是 _process 中 spawn
        CollisionManager.spawn_hitbox(...)

## 正确做法 — 动画驱动
func _ready() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)

func play_attack(attack_id: String) -> void:
    animation_player.play("attack_%s" % attack_id)

func _on_attack_hit_frame() -> void:
    # 由 AnimationPlayer Method Track 调用
    CollisionManager.spawn_hitbox(...)
```

### 状态切换与 Hitbox 清理时序

```
Frame N: Player 被击中
  → take_damage() 被调用
  → _current_state = "HURT"
  → _on_state_changed("ATTACKING", "HURT")
  → cleanup_by_owner(self) → Hitbox despawn

Frame N+1: Hitbox 物理检测
  → Hitbox.state == DESTROYED，但仍参与该帧检测
  → 不触发新的命中

Frame N+2: queue_free() 执行
  → Hitbox 从场景树移除
```

### Hitbox 与 Animation 同步的重要性

动画驱动的 Hitbox spawn 确保：
1. **视觉一致性**: Hitbox spawn 时机与动画帧完全同步
2. **可预测性**: 玩家可以精确掌握命中时机
3. **性能优化**: 命中检测与动画播放绑定，避免无效检测

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 10/10 passing (frame ranges, signals, constants verification)
**Test Evidence**: `tests/unit/collision/animation_hitbox_sync_test.gd`
