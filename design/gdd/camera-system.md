# 摄像机系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-17
> **Implements Pillar**: Pillar 1 — 协作即意义, Pillar 4 — 轻快节奏

## Overview

摄像机系统控制游戏视口的实时定位与缩放。对于2D横版Boss Rush，系统必须同时包含两位玩家和Boss，保持战斗始终在画面中心。系统由Camera2D节点实现，提供平滑跟随、屏幕震动、战场边界约束等功能。

**核心职责：**
- 根据玩家位置（来自动画系统/战斗系统）和Boss位置（来自Boss AI系统）计算最优视口位置
- 支持多种镜头模式：双玩家追踪、Boss聚焦、战斗全景
- 在命中、同步攻击、Boss阶段转换等关键时刻触发屏幕震动
- 保持两位玩家始终在画面内，同时不丢失Boss的位置上下文
- 为屏幕空间VFX（粒子特效、同步爆发光晕）提供相机边界信息

**玩家体验层面的效果：**
- 流畅的镜头运动让战斗不晕（即使在高速Combo时）
- 关键时刻的屏幕震动强化打击感
- 镜头自动在双玩家和Boss之间调整焦距，让玩家始终知道"我在打谁，谁在打我"

## Player Fantasy

摄像机系统是纯基础设施层，玩家不直接与其交互。玩家感受到的是系统的效果：

**"我永远知道队友在哪"**
相机始终将双玩家包含在同一画面中，即使Boss在远处放大招，或两人因战术需要暂时分开，玩家也能一眼看到队友的位置。这建立协作中的"相互可见"感——你不是在单打独斗。

**"打击感好爽"**
命中和同步攻击触发屏幕震动，强化每一击的满足感。屏幕震动的幅度和频率随攻击类型变化（轻攻击=轻微晃动，重攻击=强烈震动，同步攻击=橙蓝交替脉冲）。这是Combo系统和战斗系统打击感的视觉放大器。

**"我不会被奇怪的镜头晃晕"**
相机运动平滑（ease-in-out），即使两人高速移动也不会断裂。相机永远在追逐"最有信息量的构图"——不是简单跟随P1或P2，而是始终同时显示双玩家和Boss三者的关系。

**隐喻层面：**
相机是"第三双眼睛"——帮玩家同时关注自己、队友和Boss。就像在真实工作中，你需要同时注意自己的任务、队友的进展和老板的动向。三者始终可见，是协作的基础。

## Detailed Design

### Section C: Technical Implementation Constraints

> **Author**: godot-specialist
> **Date**: 2026-04-16
> **Engine**: Godot 4.6 / GDScript / 2D Native Rendering

---

#### C.1 Camera2D API in Godot 4.6

**Smoothing Mode**

Camera2D has three smoothing modes set via `smoothing` property (enum `Camera2DSmoothingMode`):

| Mode | Behavior | Recommended For |
|------|----------|-----------------|
| `SMOOTHING_DISABLED` | Camera snaps instantly to target position | Pixel-perfect precision, debug cameras |
| `SMOOTHING_INSIDE_OUT` | Eases from edges toward center | UI-like follow, where you want gentle correction without oscillation |
| `SMOOTHING_CENTER_OUT` | Eases from center toward edges | **Recommended for co-op boss rush** — smooth follow with natural feel |

```gdscript
# Recommended: SMOOTHING_CENTER_OUT for 2D co-op boss rush
camera.smoothing = Camera2D.SMOOTHING_CENTER_OUT
camera.smoothing_speed = 5.0  # Pixels per frame at 60fps (tune with delta)
```

**Verification needed**: `smoothing_speed` is a float controlling interpolation rate. Confirm this property name in Godot 4.6 inspector — the property may be named differently in some versions.

**`draggable_margin` vs `limit` — Boundary Constraint Strategy**

These are two distinct boundary mechanisms:

```
draggable_margin: float (0.0–1.0)
  └── Creates a "soft" dead zone. Camera only moves when target
      exceeds the margin percentage from screen center.
  └── Margin is relative to viewport size.
  └── Example: drag_margin_left=0.2 means left margin triggers
      only when target is 20% past the left viewport edge.
  └── Use when: You want camera to "wait" before recentering,
      letting targets briefly near edges without camera movement.

limit: int (left, right, top, bottom)
  └── Hard pixel boundaries. Camera stops at these world coordinates.
  └── Use when: You have fixed arena bounds and must prevent
      camera from showing outside the playable area.
  └── Often combined with draggable_margin for soft+hard combo.
```

**Recommendation for this game:**
- Use `limit` to enforce hard arena boundaries (from Level Design system)
- Use small `draggable_margin` (0.05–0.1) to reduce micro-corrections during combat
- Set `limit` values dynamically based on current boss arena layout

```gdscript
# Example: Setting arena bounds
camera.limit_left = arena.world_left
camera.limit_right = arena.world_right
camera.limit_top = arena.world_top
camera.limit_bottom = arena.world_bottom
camera.drag_margin_left = 0.08
camera.drag_margin_right = 0.08
```

**`zoom` Control**

Zoom is a `Vector2` property — set directly, not via method call:

```gdscript
# Zoom in (values > 1.0 make world appear larger, camera shows less)
camera.zoom = Vector2(1.5, 1.5)

# Zoom out (values < 1.0 make world appear smaller, camera shows more)
camera.zoom = Vector2(0.75, 0.75)

# Differential zoom (wider horizontal FOV) — use sparingly
camera.zoom = Vector2(0.8, 1.0)
```

**Zoom modes for boss focus / combat focus:**
- `zoom = Vector2(1.0, 1.0)` — standard view
- `zoom = Vector2(1.3, 1.3)` — boss focus (zoomed in ~30%, both players visible but smaller)
- `zoom = Vector2(0.7, 0.7)` — wide view for multi-phase transitions

**WARNING**: Setting `zoom` does not animate — use `Tween` for smooth zoom transitions:
```gdscript
# Smooth zoom transition
var tween := create_tween()
tween.tween_property(camera, "zoom", Vector2(1.3, 1.3), 0.5) \
    .set_trans(Tween.TRANS_CUBIC) \
    .set_ease(Tween.EASE_OUT)
```

**`position` Assignment — Avoiding Conflict with Smoothing**

Setting `camera.position` directly will fight with smoothing if smoothing is enabled. Two solutions:

**Option A — Set `position` and disable smoothing momentarily:**
```gdscript
# For cutscene/teleport: snap instantly
camera.smoothing = Camera2D.SMOOTHING_DISABLED
camera.position = target_position
# Re-enable after
camera.smoothing = Camera2D.SMOOTHING_CENTER_OUT
```

**Option B — Set the `target` position instead** (if using `remote_transform`):
```gdscript
# Add a Marker2D child to the camera, then:
camera.position_smoothing_enabled = true  # Godot 4.x property
camera.position_smoothing_speed = 5.0
# Position is set via target's global_position automatically
```

**Uncertain**: In Godot 4.6, `position_smoothing_enabled` and `position_smoothing_speed` may be named `smoothing_enabled` and `smoothing_speed`. **Verify in editor before implementing.**

**`offset` — Visual Center Offset**

`offset` (Vector2) shifts the camera center without moving the actual world position. Useful for:
- Offsetting to keep action centered slightly above screen bottom (protagonist bias)
- Compensating for asymmetric boss sprites

```gdscript
# Offset camera center upward by 100 pixels (action bias toward top)
camera.offset = Vector2(0, -100)
```

---

#### C.2 Screen Shake Implementation

**Godot 4.6 Camera2D — No Built-in `shake()` Method**

Camera2D does NOT have a built-in `shake()` method in Godot 4.x. Screen shake must be implemented manually using the **trauma-based noise pattern**.

**Architecture: Trauma + Noise Offset**

```gdscript
class_name CameraController
extends Camera2D

## Trauma-based screen shake — no engine shake method required

@export var trauma_decay: float = 2.0  # Trauma units per second to decay
@export var noise_speed: float = 25.0  # Oscillation speed
@export var max_offset: Vector2 = Vector2(50, 50)  # Maximum pixel offset

var trauma: float = 0.0  # 0.0 to 1.0
var _noise_y: float = 0.0

func _physics_process(delta: float) -> void:
    # Decay trauma
    trauma = maxf(0.0, trauma - trauma_decay * delta)

    # Calculate shake offset
    if trauma > 0.0:
        var shake := _calculate_shake()
        # Apply offset without fighting smoothing
        offset = shake  # 'offset' shifts camera center, not world position
    else:
        offset = Vector2.ZERO

func _calculate_shake() -> Vector2:
    # Use OpenSimplex2 or built-in randf — simpler noise for prototype
    var t := Time.get_ticks_msec() / 1000.0
    var nx := randf_range(-1.0, 1.0) * trauma * trauma  # Quadratic falloff
    var ny := randf_range(-1.0, 1.0) * trauma * trauma
    return Vector2(nx, ny) * max_offset

func add_trauma(amount: float) -> void:
    trauma = minf(1.0, trauma + amount)
```

**Trauma Accumulation by Event Type:**

| Event | Trauma Amount | Feel |
|-------|---------------|------|
| Light attack hit | 0.1–0.2 | Subtle pixel jitter |
| Heavy attack hit | 0.3–0.5 | Clear shake |
| Sync attack (both players hit) | 0.6–0.8 | Strong, punchy |
| Boss phase transition | 0.8–1.0 | Maximum impact |
| Player damage | 0.4 | Moderate recoil |

**Maximum Amplitude and Frequency:**

- Max offset: `50px` horizontal, `35px` vertical (tune to feel)
- Shake frequency: controlled by `noise_speed` and `randf()` call rate
- **Do NOT use sine waves for shake** — they produce predictable, nauseating motion
- Trauma curve should be quadratic (`trauma * trauma`) for fast attack, slow decay

**Avoiding Camera Drift After Shake:**

The `offset` approach avoids drift because:
1. `offset` shifts camera visual center, not world position
2. When trauma = 0, `offset = Vector2.ZERO` — camera returns to exact pre-shake position
3. No physics or smoothing involved — pure visual offset

**Alternative: Apply to `position` instead of `offset` (fighting smoothing risk):**

```gdscript
# ONLY if smoothing is DISABLED during shake:
position += _calculate_shake()
# PROBLEM: When shake ends, camera "snaps" back — jarring
# SOLUTION: Use 'offset' property instead (see above)
```

---

#### C.3 Dual-Camera Considerations

**Single Camera2D is Standard for 2D Co-op**

Multi-camera setups (one camera per player) in 2D co-op are non-standard and introduce:
- Complexity in split-screen rendering
- Synchronization issues between cameras
- Doubled VFX system complexity

**Recommended: Single Camera2D Framing Both Players**

Strategy: Compute the midpoint between both players, then expand the camera frustum to ensure both are visible:

```gdscript
func compute_camera_target(player1: Node2D, player2: Node2D, boss: Node2D) -> Vector2:
    # 1. Midpoint between players (primary anchor)
    var midpoint: Vector2 = (player1.global_position + player2.global_position) / 2.0

    # 2. Distance between players — if far apart, widen view
    var player_distance := player1.global_position.distance_to(player2.global_position)

    # 3. Adjust zoom to fit both players + boss context
    # Baseline: zoom=1.0 fits ~800x450 (720p half)
    # Tune thresholds based on actual sprite sizes
    if player_distance > 600:
        zoom = Vector2(0.8, 0.8)  # Widen to fit both
    elif player_distance < 200:
        zoom = Vector2(1.1, 1.1)  # Tighten for close partners

    # 4. Boss contextual offset — bias slightly toward boss
    # Only apply if boss is significantly far from player midpoint
    var boss_offset := boss.global_position - midpoint
    if boss_offset.length() > 200:
        midpoint += boss_offset * 0.15  # Gentle bias, not full follow

    return midpoint
```

**Viewport and CanvasLayer Placement:**

Camera2D should be placed in the scene root or a dedicated `CameraRig` node:

```
Main (Node2D)
├── Players
├── Boss
├── Level
├── VFX (CanvasLayer with screen-space particles)
├── UI (CanvasLayer)
└── CameraRig (Node2D)
    └── MainCamera (Camera2D)
```

**Key point for VFX integration:**
- VFX that should appear at fixed screen positions (not world positions) must be in a `CanvasLayer` that is NOT a child of Camera2D
- VFX that should move with the world (e.g., impact particles in world space) can be children of the world, and camera transform applies automatically

**Viewfinder Mode (Optional stretch goal):**
If the game needs to show "player 1 screen / player 2 screen" in replay or spectate mode, use two Camera2D nodes with `viewport.set_camera_mode()` — but this is out of scope for initial implementation.

---

#### C.4 Performance

**Camera2D Cost at 60fps:**

Camera2D is a lightweight node. Its cost is negligible compared to:
- Sprite rendering (many draw calls)
- Physics queries
- Particle systems

The camera does NOT rasterize — it only computes transform and applies it to the viewport. At 60fps, a single Camera2D costs ~0.01ms or less.

**Optimization Strategies (only if needed):**

1. **Disable camera when not needed:**
   ```gdscript
   camera.enabled = false  # Disables camera entirely
   ```

2. **Reduce smoothing updates:**
   - If smoothing is enabled, camera recomputes every frame
   - For static/idle scenes, consider briefly disabling smoothing

3. **Avoid `_process()` polling for position updates:**
   - If camera follows targets via `remote_transform`, the remote does the work
   - If manual `position` assignment, use `_physics_process()` (fixed timestep) not `_process()`

4. **Do NOT implement "only update when targets move significantly"** as a blanket rule:
   - For a boss rush with constant action, targets move every frame
   - This optimization saves nothing in this game type
   - Only implement if profiling shows camera as a hot spot

**No camera-specific performance concerns for this game.**

---

#### C.5 Signals and Data Emission

**Camera2D Emits Very Few Signals**

Camera2D in Godot 4.x does not emit signals for `zoom_changed`, `position_changed`, or `limit_changed`. Custom signals must be emitted by the wrapper script.

**Custom Signal Architecture:**

```gdscript
class_name CameraController
extends Camera2D

## Emitted when camera zoom changes (for VFX system)
signal zoom_changed(current_zoom: Vector2)

## Emitted when camera position updates (for VFX system — world-space VFX position sync)
signal camera_moved(camera_center: Vector2)

## Emitted when camera bounds change (e.g., new arena section)
signal bounds_changed(limits: Dictionary)  # {left, right, top, bottom}

var _last_zoom := Vector2.ONE

func _physics_process(delta: float) -> void:
    # Emit zoom_changed only when zoom actually changes
    if zoom != _last_zoom:
        zoom_changed.emit(zoom)
        _last_zoom = zoom

    # Emit camera_moved every frame (VFX may need it)
    # For performance, consider throttling to every 2-3 frames if VFX doesn't need 60hz updates
    var viewport_center := get_viewport().get_visible_rect().size / 2
    var world_center := global_position + offset
    camera_moved.emit(world_center)

func set_limits(arena: Dictionary) -> void:
    limit_left = arena.left
    limit_right = arena.right
    limit_top = arena.top
    limit_bottom = arena.bottom
    bounds_changed.emit(arena)
```

**Sharing Camera State with VFX System:**

The VFX system (particle-vfx-system) needs:
1. **Screen bounds** — to clamp screen-space particles
2. **Camera center** — to convert world positions to screen positions
3. **Zoom level** — for scale compensation in particle sizes

**Recommended approach: Event Bus Autoload**

```gdscript
# Autoload: Events (singleton)
extends Node

signal camera_zoom_changed(zoom: Vector2)
signal camera_moved(world_center: Vector2, screen_bounds: Rect2)
signal camera_bounds_changed(limits: Dictionary)

# In CameraController:
func _physics_process(delta: float) -> void:
    Events.camera_zoom_changed.emit(zoom)

    var screen_bounds := Rect2(
        global_position - get_viewport().get_visible_rect().size / 2,
        get_viewport().get_visible_rect().size
    )
    Events.camera_moved.emit(global_position, screen_bounds)
```

**Then in VFX system, connect to these signals:**
```gdscript
# In VFX system
func _ready() -> void:
    Events.camera_zoom_changed.connect(_on_camera_zoom_changed)
    Events.camera_moved.connect(_on_camera_moved)

func _on_camera_zoom_changed(z: Vector2) -> void:
    # Adjust particle base scale based on zoom
    # Higher zoom = smaller relative particles
    particle_base_scale = 1.0 / z.x

func _on_camera_moved(center: Vector2, bounds: Rect2) -> void:
    # Clamp screen-space particles to bounds
    for particle in screen_space_particles:
        particle.position = particle.position.clamp(bounds.position, bounds.end)
```

---

#### C.6 Godot 4.4 / 4.5 / 4.6 Camera2D Changes

Based on `docs/engine-reference/godot/breaking-changes.md` and `VERSION.md`:

| Version | Camera2D Changes |
|---------|-----------------|
| 4.4 | No breaking Camera2D API changes |
| 4.5 | No breaking Camera2D API changes |
| 4.6 | No breaking Camera2D API changes (2D physics unchanged; Jolt affects 3D only) |

**Properties to Verify in Godot 4.6 Editor:**

| Property | Possible Names | Verification Needed |
|----------|---------------|---------------------|
| Smoothing enabled | `smoothing_enabled` or `position_smoothing_enabled` | YES |
| Smoothing speed | `smoothing_speed` or `position_smoothing_speed` | YES |
| Smoothing mode | `smoothing` (enum `Camera2DSmoothingMode`) | Confirmed |

**Recommendation:** Create a minimal prototype scene with Camera2D to verify property names and default behavior before building the full CameraController class.

---

#### C.7 Summary of Implementation Decisions

| Decision | Recommendation |
|----------|----------------|
| Smoothing mode | `SMOOTHING_CENTER_OUT` |
| Boundary constraints | `limit` (hard) + `draggable_margin` (soft, 0.08) |
| Zoom implementation | Direct `zoom = Vector2()` assignment + Tween for transitions |
| Position control | `position` assignment with smoothing disabled for teleports |
| Screen shake | Trauma-based noise offset via `offset` property |
| Camera count | Single Camera2D, dynamically framed for both players |
| Signal strategy | Custom signals on CameraController, forwarded via Events autoload |
| Performance | No special optimization needed for Camera2D |

---

### Core Rules

**规则1 — 主追踪目标：加权双玩家质心**

相机目标位置 = 双玩家的加权质心，活跃攻击者有额外权重：

```
camera_target = (P1_pos × P1_weight + P2_pos × P2_weight) / (P1_weight + P2_weight)
```

| 变量 | 默认权重 | 说明 |
|------|---------|------|
| P1_weight | 1.0 | 基础权重 |
| P2_weight | 1.0 | 基础权重 |
| 活跃攻击者权重 | 1.5 | 玩家处于攻击状态时 |
| 被动/防守玩家权重 | 0.8 | 队友正在攻击时（保持可见但降低权重） |

**Boss包含规则：** Boss永远不是主要追踪目标。相机始终将Boss作为"背景"包含在画面内，但不以Boss为焦点。Boss可占据最多40%的屏幕宽度而不强制拉远镜头。

> **调优标记**：活跃攻击者权重1.5x是起始值。如果攻击时相机"拉"向一个玩家太激进，降到1.2x。如果玩家觉得相机忽略了攻击中的玩家，升至1.8x。

**规则2 — 缩放/视野策略**

缩放由两个独立因素控制（对数空间叠加 = 线性空间相乘）：

```
effective_zoom = BASE_ZOOM × zoom_from_player_distance × zoom_from_combat_state × zoom_from_boss_phase
```

| 缩放因素 | 触发条件 | 缩放值 | 恢复 |
|---------|---------|--------|------|
| 玩家距离 < 200px | 正常 | 1.0x | — |
| 玩家距离 200-400px | 拉开 | 0.85x | 平滑 |
| 玩家距离 > 400px | 远距离 | 0.7x | 平滑 |
| 玩家攻击中 | 战斗 | 0.9x | 攻击结束后0.3s ease back |
| 同步攻击激活 | 连击 | 0.85x | 结束后0.5s ease back |
| Boss相位转换 | 阶段变化 | 0.75x | 1.0s ease back |

> **调优标记**：玩家距离阈值（200px、400px）来自预期的玩家机动范围。如果玩家分开时感觉"丢失"，增加阈值。如果战场在最大缩放下太拥挤，减小0.7x下限或调整阈值。

**规则3 — 平滑跟随：平滑算法**

Camera2D使用指数缓动（exponential easing），适合游戏相机：

| 平滑速度 | 感觉 | 用途 |
|---------|------|------|
| 4.0 | 漂浮，电影感 | Boss击败动画 |
| 8.0 | 默认平滑 | 正常游戏 |
| 12.0 | 快速，响应 | 主动战斗（临时覆盖） |
| 20.0 | 几乎即时 | 危机模式 |

速度切换：`move_toward(current_speed, target_speed, acceleration × delta)`，加速度=30.0。

**规则4 — 屏幕震动：基于创伤值**

屏幕震动实现为**创伤积累**模式——从战斗事件积累，随时间衰减。避免"固定时间"问题（无论激烈程度如何，震动感觉都一样）。

**关键实现细节：**
- 震动应用于`Camera2D.offset`（而非`position`）——避免震动结束时相机"漂移"
- 使用`randf()`白噪声——不要用正弦波（可预测，令人晕眩）
- 创伤曲线：二次方衰减（`trauma × trauma`）——快攻慢衰减

| 事件 | 创伤增量 | 最大偏移 |
|------|---------|---------|
| 轻攻击命中 | 0.15 | 2.0px |
| 中攻击命中 | 0.25 | 3.0px |
| 重攻击命中 | 0.4 | 5.0px |
| 特殊攻击命中 | 0.6 | 7.0px |
| 同步命中（每玩家） | 0.3 | 4.0px |
| 第三次连续同步爆发 | 0.8 | 8.0px |
| Boss命中玩家 | 0.5 | 6.0px |
| Boss相位转换 | 0.9 | 10.0px |
| 玩家倒地 | 1.0 | 12.0px |

**规则5 — 相机边界约束**

相机通过Camera2D的`limit_*`属性尊重战场边界：

- `limit`：硬像素边界，相机停在此世界坐标
- `draggable_margin`：软死区，视口相对值（0.05-0.1）——减少战斗中小校正
- `BUFFER_MARGIN=50px`：艺术缓冲区，允许相机稍微超出边界

**边界违规处理（危机模式）：** 玩家倒地时，相机将临时禁用`limit`以保持倒地玩家可见——即使他们在边缘。倒地玩家被救起后重新启用`limit`。

### States and Transitions

**相机状态机：**

| 状态 | 描述 | 缩放 | 平滑速度 | 震动 | 边界 |
|------|------|------|---------|------|------|
| `NORMAL` | 默认追踪，双玩家可见 | 0.85-1.0x | 8.0 | 仅被动衰减 | 启用 |
| `PLAYER_ATTACK` | 任意玩家攻击中 | 0.9x | 12.0 | 命中震动 | 启用 |
| `SYNC_ATTACK` | 5帧同步窗口内双玩家攻击 | 0.85x | 12.0 | 同步震动 | 启用 |
| `BOSS_FOCUS` | Boss攻击信号或活跃攻击 | 0.8x | 8.0 | Boss攻击震动 | 启用 |
| `BOSS_PHASE_CHANGE` | 相位转换（~1s） | 0.75x | 4.0 | 高震动 | 启用 |
| `CRISIS` | 玩家倒地 | 0.9x | 20.0 | 持续震动 | **暂停** |
| `COMBAT_ZOOM` | 连击Tier 3+激活 | 0.85x | 10.0 | Tier震动 | 启用 |

**转换表：**

| 从状态 | 到状态 | 触发条件 | 过渡时长 |
|--------|--------|---------|---------|
| 任意 | `NORMAL` | 无活跃攻击，无Boss信号，双玩家存活 | 自动 |
| `NORMAL` | `PLAYER_ATTACK` | 任意玩家进入ATTACKING | 即时 |
| `NORMAL` | `SYNC_ATTACK` | P1和P2在5帧内攻击 | 即时 |
| `NORMAL` | `BOSS_FOCUS` | Boss AI发送`boss_attack_started` | 即时 |
| `NORMAL` | `BOSS_PHASE_CHANGE` | Boss AI发送`boss_phase_changed` | 即时 |
| `NORMAL` | `CRISIS` | CoopSystem发送`player_downed` | 即时 |
| `NORMAL` | `COMBAT_ZOOM` | ComboSystem发送`tier >= 3` | 0.3s ease |
| `PLAYER_ATTACK` | `NORMAL` | 攻击动画结束+0.3s缓冲 | 0.3s ease back |
| `SYNC_ATTACK` | `NORMAL` | 同步窗口过期+0.5s缓冲 | 0.5s ease back |
| `BOSS_FOCUS` | `NORMAL` | Boss攻击动画结束 | 0.5s ease back |
| `BOSS_PHASE_CHANGE` | `NORMAL` | 相位转换动画结束（~1s） | 1.0s ease back |
| `CRISIS` | `NORMAL` | 被救玩家存活>0.5s | 0.5s ease back |
| `COMBAT_ZOOM` | `NORMAL` | 连击Tier降至3以下 | 0.3s ease back |

**状态优先级（高优先级优先）：** `CRISIS > BOSS_PHASE_CHANGE > BOSS_FOCUS > SYNC_ATTACK > PLAYER_ATTACK > COMBAT_ZOOM > NORMAL`

如果玩家在Boss相位转换期间倒地（`CRISIS`），相机保持`CRISIS`模式（边界暂停，倒地玩家可见）。

### Interactions with Other Systems

**信号消耗：**

| 来源系统 | 信号 | 相机响应 |
|---------|------|---------|
| 战斗系统 | `attack_started(attack_type)` | 进入`PLAYER_ATTACK`，根据`attack_type`应用震动 |
| 战斗系统 | `hit_confirmed(hitbox, hurtbox, attack_id)` | 立即应用命中震动 |
| 连击系统 | `combo_tier_changed(tier, player_id)` | tier >= 3则进入`COMBAT_ZOOM` |
| 连击系统 | `sync_burst_triggered(position)` | 进入`SYNC_ATTACK`，应用高震动 |
| Boss AI | `boss_attack_started(attack_pattern)` | 进入`BOSS_FOCUS` |
| Boss AI | `boss_phase_changed(new_phase)` | 进入`BOSS_PHASE_CHANGE`，应用最大震动 |
| 协作系统 | `player_downed(player_id)` | 进入`CRISIS`，暂停边界 |
| 协作系统 | `player_rescued(player_id)` | 0.5s后队列返回`NORMAL` |

**信号发射：**

| 目标系统 | 信号 | 数据 | 用途 |
|---------|------|------|------|
| VFX/粒子特效 | `camera_shake_intensity` | `float (0.0-1.0)` | 粒子可用震动强度做额外位移效果 |
| UI | `camera_zoom_changed` | `float` | 随缩放缩放的UI元素（如伤害数字） |
| UI | `camera_framed_players` | `[P1_pos, P2_pos]` | 绘制帧内玩家间的连接线（同步攻击UI） |

> **接口设计**：推荐使用Autoload EventBus共享相机状态，而非直接节点引用。相机系统发射信号，其他系统订阅。

## Formulas

### F.1 相机目标位置公式

```
camera_target = (P1_pos × P1_weight + P2_pos × P2_weight) / (P1_weight + P2_weight)
```

**变量定义：**

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| P1_pos | Vector2 | 任意 | 玩家1世界坐标 |
| P2_pos | Vector2 | 任意 | 玩家2世界坐标 |
| P1_weight | float | 0.5-2.0 | 玩家1权重，默认1.0 |
| P2_weight | float | 0.5-2.0 | 玩家2权重，默认1.0 |

**权重激活条件：**
- 玩家正在攻击：`weight = 1.5`（来自战斗系统`attack_started`信号）
- 队友正在攻击：`weight = 0.8`（保持可见但去焦点）

---

### F.2 有效缩放公式

```
effective_zoom = BASE_ZOOM × player_distance_zoom × combat_state_zoom × boss_phase_zoom
```

| 子因素 | 公式 | 输出范围 |
|--------|------|---------|
| player_distance_zoom | 距离<200: 1.0, 200-400: 0.85, >400: 0.7 | 0.7-1.0 |
| combat_state_zoom | 攻击中: 0.9, 同步攻击: 0.85 | 0.85-0.9 |
| boss_phase_zoom | 相位3: 0.9, 其他: 1.0 | 0.9-1.0 |

**示例计算（玩家分开300px，Boss相位2，无攻击）：**
```
player_distance_zoom = 0.85
combat_state_zoom = 1.0
boss_phase_zoom = 1.0
effective_zoom = 1.0 × 0.85 × 1.0 × 1.0 = 0.85
```

---

### F.3 震动强度公式

```
shake_offset = trauma × trauma × max_offset
trauma(t) = max(0.0, trauma_0 - TRAUMA_DECAY × Δt)
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| trauma | float | 0.0-1.0 | 当前创伤值 |
| trauma_0 | float | 0.0-1.0 | 初始创伤值（事件触发时） |
| TRAUMA_DECAY | float | 0.5-3.0 | 衰减率，默认2.0/s |
| Δt | float | 秒 | 自上次更新以来的时间 |
| max_offset | Vector2 | px | 最大偏移，默认(50, 35) |

**验证示例（重攻击命中）：**
```
trauma_0 = 0.4
Δt = 0.5s
trauma = max(0.0, 0.4 - 2.0 × 0.5) = max(0.0, -0.6) = 0.0  # 震动在0.5s后已完全衰减
```

---

### F.4 平滑速度过渡公式

```
current_speed = move_toward(current_speed, target_speed, acceleration × delta)
position = lerp(current_position, target_position, 1.0 - exp(-current_speed × delta))
```

| 变量 | 默认值 | 安全范围 | 描述 |
|------|-------|---------|------|
| acceleration | 30.0 | 10-60 | 速度变化加速度 |
| NORMAL_speed | 8.0 | 4-12 | 默认平滑速度 |
| COMBAT_speed | 12.0 | 8-20 | 战斗时平滑速度 |
| CRISIS_speed | 20.0 | 15-30 | 危机时平滑速度 |

---

### F.5 相机边界公式

```
camera_limit_left = arena.world_left - BUFFER_MARGIN
camera_limit_right = arena.world_right + BUFFER_MARGIN
camera_limit_top = arena.world_top - BUFFER_MARGIN
camera_limit_bottom = arena.world_bottom + BUFFER_MARGIN
```

| 变量 | 默认值 | 说明 |
|------|-------|------|
| BUFFER_MARGIN | 50px | 艺术缓冲区 |
| draggable_margin | 0.08 | 软死区（视口比例） |

## Edge Cases

### EC-1：双玩家同时在战场两侧边缘

**条件**：P1和P2分别在战场左右两侧，距离>最大缩放范围。

**处理**：
- 相机应用`zoom = 0.7x`（最小缩放）
- 如果即使0.7x也无法同时包含双玩家，优先包含P1+P1连线中心点，Boss可能被裁切出画面
- 如果有玩家在边界外，相机`limit`强制约束，溢出玩家在屏幕边缘可见部分

---

### EC-2：玩家在极限距离内但Boss也在极限距离内

**条件**：双玩家靠近（<200px），但Boss在远处（>400px from midpoint）。

**处理**：
- 玩家距离缩放因子=1.0x（不缩放）
- Boss上下文偏移因子=0.15轻微倾向Boss
- 结果：相机主要跟随双玩家，Boss在背景可见但不被裁切

---

### EC-3：CRISIS状态中玩家在战场边界

**条件**：倒地玩家（P1）在战场左边缘，相机`limit`会将其裁切出画面。

**处理**：
- 相机立即暂停`limit`约束（`camera.limit_left = -INF`等）
- 相机继续追踪倒地玩家位置
- 一旦玩家被救起（`player_rescued`），0.5s内平滑恢复`limit`约束

---

### EC-4：Boss相位转换发生在CRISIS期间

**条件**：玩家倒地（CRISIS），同时Boss HP穿越阈值触发相位转换。

**处理**：
- 状态优先级：`CRISIS > BOSS_PHASE_CHANGE`（CRISIS优先）
- 相机保持在CRISIS模式：边界暂停，继续追踪倒地玩家
- BOSS_PHASE_CHANGE的视觉效果（震动、缩放）在CRISIS下被抑制

---

### EC-5：同步攻击窗口与Boss聚焦同时触发

**条件**：P1和P2触发同步攻击（SYNC_ATTACK），同时Boss发出攻击信号（BOSS_FOCUS）。

**处理**：
- 状态优先级：`SYNC_ATTACK` = `BOSS_FOCUS`（同级）
- 以最后到达的状态为准（无优先级差异）
- 两者缩放均为0.85x/0.8x，数值接近，无明显视觉冲突

---

### EC-6：帧跳帧（Lag Spike）期间相机行为

**条件**：游戏遭遇帧跳帧，导致`_physics_process`调用延迟。

**处理**：
- 相机位置更新使用`delta`缩放：`position += (target - current) × smoothing × delta`
- Lag期间，相机运动速度降低（与游戏物理同步）
- 不出现"相机追上来了但游戏逻辑落后"的视觉断裂

---

### EC-7：相机边界动态变化

**条件**：Boss从Arena A移动到Arena B（场景管理系统切换区域）。

**处理**：
- 场景切换时，CameraController接收新的`arena_bounds`数据
- 使用Tween在1.0s内平滑过渡`limit`值（不跳变）
- 过渡期间相机追踪不受影响

---

### EC-8：双玩家距离极近（<50px）

**条件**：双玩家几乎重叠（近战战斗场景）。

**处理**：
- `player_distance_zoom` = 1.0x（不使用1.1x，避免过度放大）
- 相机跟随双玩家质心（几乎重合）
- 战斗聚焦缩放因子生效（0.9x或0.85x）

---

### EC-9：屏幕震动与缩放同时生效

**条件**：震动触发时相机同时在执行缩放过渡（Tween）。

**处理**：
- 震动应用于`offset`，Tween应用于`zoom`——两个属性互不干扰
- 震动不影响缩放Tween的进度
- 同时生效时视觉感受是"放大+震动"——这是正确的战斗紧张感

---

### EC-10：P1或P2节点不存在（调试/重生时）

**条件**：玩家死亡后还未重生，或调试时禁用玩家节点。

**处理**：
- 相机仅追踪存在的玩家
- 如果只有一个玩家，相机跟随该玩家（无质心计算）
- 如果零个玩家存在（两个都死亡），相机固定在最后位置，等待重生

## Dependencies

### 上游依赖（相机系统消费）

| 依赖系统 | 依赖原因 | 接口 |
|---------|---------|------|
| 战斗系统 | 需要玩家位置和攻击类型以计算追踪目标和震动 | 消费：`attack_started`，`hit_confirmed` |
| 连击系统 | 需要连击Tier和同步攻击触发以计算缩放和震动 | 消费：`combo_tier_changed`，`sync_burst_triggered` |
| 协作系统 | 需要倒地/被救信号以进入CRISIS状态 | 消费：`player_downed`，`player_rescued` |
| Boss AI系统 | 需要Boss位置和相位变化以计算追踪上下文和震动 | 消费：`boss_attack_started`，`boss_phase_changed` |

### 下游依赖（依赖相机系统）

| 依赖系统 | 依赖原因 | 接口 |
|---------|---------|------|
| 粒子特效系统 | 需要相机屏幕边界以限制屏幕空间粒子，需要相机位置同步世界VFX | 发射：`camera_shake_intensity`，`camera_zoom_changed`，`camera_framed_players` |
| UI系统 | 需要缩放变化以缩放UI元素（如伤害数字） | 发射：`camera_zoom_changed` |
| 动画系统 | 可能需要相机震动强度以调整动画中的VFX强度 | 发射：`camera_shake_intensity` |

### 无依赖的系统

| 系统 | 说明 |
|------|------|
| 输入系统 | 相机系统不读取输入——追踪目标来自其他系统的信号 |
| 碰撞检测系统 | 不直接交互 |
| 场景管理系统 | 相机从场景管理系统接收`arena_bounds`——但那是场景加载后的配置数据，不是实时依赖 |

## Tuning Knobs

### G.1 追踪权重参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| P1_BASE_WEIGHT | 1.0 | 0.5-2.0 | 玩家1基础权重 |
| P2_BASE_WEIGHT | 1.0 | 0.5-2.0 | 玩家2基础权重 |
| ACTIVE_ATTACKER_WEIGHT | 1.5 | 1.0-2.5 | 攻击中玩家权重倍数 |
| PASSIVE_DEFENDER_WEIGHT | 0.8 | 0.5-1.2 | 队友攻击时另一玩家权重 |
| BOSS_CONTEXTUAL_BIAS | 0.15 | 0.0-0.3 | Boss位置对质心的偏移系数 |

### G.2 缩放参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| BASE_ZOOM | 1.0 | 0.8-1.5 | 基础缩放值 |
| PLAYER_DIST_THRESHOLD_LOW | 200px | 100-400px | 玩家距离触发轻微缩放阈值 |
| PLAYER_DIST_THRESHOLD_HIGH | 400px | 300-600px | 玩家距离触发最大缩放阈值 |
| PLAYER_DIST_ZOOM_NEAR | 1.0 | 0.9-1.1 | 近距离缩放（<200px） |
| PLAYER_DIST_ZOOM_MID | 0.85 | 0.7-1.0 | 中距离缩放（200-400px） |
| PLAYER_DIST_ZOOM_FAR | 0.7 | 0.5-0.85 | 远距离缩放（>400px） |
| ATTACK_ZOOM | 0.9 | 0.8-1.0 | 攻击中缩放 |
| SYNC_ATTACK_ZOOM | 0.85 | 0.7-1.0 | 同步攻击缩放 |
| BOSS_PHASE3_ZOOM | 0.9 | 0.8-1.0 | Boss危机相位缩放 |

### G.3 平滑速度参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| SMOOTHING_SPEED_NORMAL | 8.0 | 4-12 | 默认平滑速度（px/s） |
| SMOOTHING_SPEED_COMBAT | 12.0 | 8-20 | 战斗时平滑速度 |
| SMOOTHING_SPEED_CRISIS | 20.0 | 15-30 | 危机时平滑速度 |
| SMOOTHING_SPEED_BOSS_TRANSITION | 4.0 | 2-8 | Boss转换时平滑速度（电影感） |
| SMOOTHING_ACCELERATION | 30.0 | 10-60 | 速度变化加速度 |

### G.4 屏幕震动参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| TRAUMA_DECAY | 2.0/s | 0.5-4.0 | 震动衰减率 |
| MAX_SHAKE_OFFSET | (50, 35)px | (20-80, 15-60)px | 最大震动幅度 |
| LIGHT_TRAUMA | 0.15 | 0.05-0.3 | 轻攻击震动量 |
| MEDIUM_TRAUMA | 0.25 | 0.1-0.5 | 中攻击震动量 |
| HEAVY_TRAUMA | 0.4 | 0.2-0.7 | 重攻击震动量 |
| SPECIAL_TRAUMA | 0.6 | 0.3-1.0 | 特殊攻击震动量 |
| SYNC_TRAUMA | 0.3 | 0.15-0.6 | 同步命中震动量 |
| SYNC_BURST_TRAUMA | 0.8 | 0.5-1.0 | 第三次连续同步爆发震动量 |
| BOSS_HIT_TRAUMA | 0.5 | 0.2-0.8 | Boss命中玩家震动量 |
| BOSS_PHASE_TRAUMA | 0.9 | 0.5-1.0 | Boss相位转换震动量 |
| PLAYER_DOWN_TRAUMA | 1.0 | 0.5-1.0 | 玩家倒地震动量 |

### G.5 边界约束参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| BUFFER_MARGIN | 50px | 20-100px | 艺术缓冲，超出战场边界的可见区域 |
| DRAG_MARGIN | 0.08 | 0.02-0.2 | 软死区（视口比例），控制相机"等待"后才追踪 |
| ZOOM_TRANSITION_DURATION | 0.5s | 0.2-1.5s | 缩放过渡动画时长 |
| LIMIT_TRANSITION_DURATION | 1.0s | 0.5-2.0s | 边界变化过渡动画时长 |

### G.6 状态持续时间参数

| 参数名 | 默认值 | 安全范围 | 影响 |
|--------|-------|---------|------|
| ATTACK_ZOOM_HOLD | 0.3s | 0.1-0.6s | 攻击后缩放保持时间 |
| SYNC_ZOOM_HOLD | 0.5s | 0.3-1.0s | 同步攻击后缩放保持时间 |
| BOSS_FOCUS_HOLD | 0.5s | 0.2-1.0s | Boss攻击后缩放恢复时间 |
| CRISIS_RECOVERY_DELAY | 0.5s | 0.2-1.0s | 被救后返回NORMAL的延迟 |

## Visual/Audio Requirements

### H.1 视觉反馈要求

摄像机系统本身不生成精灵或VFX——它通过**屏幕震动**和**缩放变化**强化其他系统的视觉效果。

| 触发事件 | 相机视觉响应 | 持续时间 |
|---------|------------|---------|
| 轻攻击命中 | 轻微像素抖动（2px） | ~0.3s |
| 中攻击命中 | 中等晃动（3px） | ~0.4s |
| 重攻击命中 | 强烈震动（5px） | ~0.5s |
| 特殊攻击命中 | 强力震动（7px）+ 缩放0.9x | ~0.6s |
| 同步命中 | 双色彩虹脉冲（橙蓝交替） | ~0.5s |
| 第三次连续同步爆发 | 屏幕边缘橙蓝交替脉冲 + 强震动 | ~0.8s |
| Boss命中玩家 | 中等震动（6px） | ~0.5s |
| Boss相位转换 | 强烈震动（10px）+ 缩放0.75x | ~1.2s |
| 玩家倒地 | 最大震动（12px）+ 缩放0.9x | ~1.5s |

**同步攻击视觉：**
- 相机不直接渲染粒子——那是粒子特效系统的工作
- 相机在SYNC_ATTACK状态期间缩放0.85x，为屏幕边缘的橙蓝脉冲留出空间
- 相机发射`camera_zoom_changed`信号，UI/粒子系统响应

**屏幕震动视觉特点：**
- 水平偏移 > 垂直偏移（更符合横版战斗的左右打击感）
- 震动曲线为二次方衰减：快速到达峰值，慢速衰减
- 不使用正弦波震动（可预测且令人晕眩）

---

### H.2 无音频直接要求

摄像机系统不直接控制音频。但通过以下接口与音频系统协作：

| 相机事件 | 音频系统预期行为 |
|---------|---------------|
| 攻击命中震动触发 | 音频系统播放命中音效（音量随震动强度略微提升） |
| Boss相位转换 | 音频系统播放Boss咆哮/环境变化音效 |
| 玩家倒地 | 音频系统降低背景音乐音量，强调紧张感 |

> 音频系统的触发逻辑由音频系统自行管理——摄像机系统仅通过`camera_shake_intensity`信号提供数据。

## UI Requirements

### I.1 摄像机系统向UI系统提供的数据

摄像机系统通过EventBus Autoload向UI系统发射以下信号：

| 信号 | 数据类型 | 内容 | UI用途 |
|------|---------|------|-------|
| `camera_zoom_changed` | float | 当前有效缩放值（0.7-1.0） | 缩放依赖的UI元素（如伤害数字大小） |
| `camera_framed_players` | Array[Vector2] | P1和P2的屏幕位置 | 绘制玩家间连接线（同步攻击UI） |
| `camera_shake_intensity` | float | 当前震动强度（0.0-1.0） | UI震动效果（如果需要） |

### I.2 UI系统需要摄像机数据的场景

| UI元素 | 需要的数据 | 处理方式 |
|-------|-----------|---------|
| 伤害数字 | 缩放值 | 根据`camera_zoom_changed`反向缩放数字（保持屏幕大小一致） |
| 同步攻击连线 | P1/P2屏幕位置 | 根据`camera_framed_players`绘制连线 |
| 连击数字 | 无特殊需求 | 不依赖相机系统 |
| Boss HP条 | 无特殊需求 | 不依赖相机系统 |
| 救援计时器 | 无特殊需求 | 不依赖相机系统 |

### I.3 UI系统不需要摄像机控制的场景

- 所有HUD元素的位置固定于屏幕空间（CanvasLayer），不随相机移动
- 相机缩放不影响CanvasLayer元素（它们在独立层）
- 屏幕震动不影响UI元素（震动应用于相机，不应用于CanvasLayer）

### I.4 相机边界对UI的影响

- UI元素不显示在游戏世界坐标中，因此相机边界不影响UI布局
- 如果有"屏幕外敌人警告"UI，需要使用`camera_framed_players`结合世界坐标计算屏幕外方向

## Acceptance Criteria

### AC-1：基本追踪功能

- [ ] **AC-1.1**：单玩家在场地移动，相机平滑跟随，无抖动或断裂
- [ ] **AC-1.2**：双玩家同时在场地移动，相机跟随两者质心，双玩家始终可见
- [ ] **AC-1.3**：双玩家分开至400px以上，相机自动缩放至0.7x，双玩家和Boss仍同时可见

### AC-2：屏幕震动

- [ ] **AC-2.1**：轻攻击命中 → 可见轻微像素抖动（~2px），持续~0.3s后消失
- [ ] **AC-2.2**：重攻击命中 → 可见明显震动（~5px），持续~0.5s后消失
- [ ] **AC-2.3**：同步攻击触发 → 橙蓝交替脉冲视觉，震动强度~0.3，持续~0.5s
- [ ] **AC-2.4**：震动结束后相机回到精确原位，无漂移

### AC-3：战斗状态响应

- [ ] **AC-3.1**：任意玩家发起攻击 → 相机立即进入PLAYER_ATTACK模式，缩放0.9x，平滑速度升至12.0
- [ ] **AC-3.2**：攻击结束后0.3s，相机平滑返回NORMAL模式
- [ ] **AC-3.3**：连击Tier升至3+ → 相机进入COMBAT_ZOOM模式，缩放0.85x
- [ ] **AC-3.4**：连击Tier降至3以下 → 0.3s内平滑返回NORMAL

### AC-4：Boss追踪

- [ ] **AC-4.1**：Boss攻击时（`boss_attack_started`）→ 相机进入BOSS_FOCUS模式，缩放0.8x
- [ ] **AC-4.2**：Boss相位转换（HP穿越阈值）→ 震动10px + 缩放0.75x + 平滑速度降至4.0（电影感），持续~1.2s
- [ ] **AC-4.3**：Boss在屏幕任意位置，始终可见（未被裁切超出边界）

### AC-5：危机模式（玩家倒地）

- [ ] **AC-5.1**：任意玩家倒地 → 相机立即进入CRISIS模式，平滑速度升至20.0（几乎即时追踪）
- [ ] **AC-5.2**：倒地玩家在战场边缘 → 相机边界约束暂停，倒地玩家仍可见
- [ ] **AC-5.3**：玩家被救起 → 0.5s后平滑返回NORMAL，边界约束恢复

### AC-6：双玩家追踪质量

- [ ] **AC-6.1**：P1在左、P2在右，Boss在中间 → 三者同时可见，无裁切
- [ ] **AC-6.2**：P1攻击时 → 相机加权偏向P1（P1权重1.5，P2权重0.8），但P2仍在画面内
- [ ] **AC-6.3**：双玩家距离<200px → 相机不放大（保持1.0x），保持紧凑构图

### AC-7：性能基准

- [ ] **AC-7.1**：3角色 + 全屏幕震动 + 全缩放动画，帧率稳定60fps
- [ ] **AC-7.2**：帧跳帧（lag spike）期间，相机运动速度与游戏逻辑同步，无视觉断裂

### AC-8：信号契约

- [ ] **AC-8.1**：相机正确订阅并响应所有8个上游信号（attack_started, hit_confirmed, combo_tier_changed, sync_burst_triggered, boss_attack_started, boss_phase_changed, player_downed, player_rescued）
- [ ] **AC-8.2**：相机正确发射3个下游信号（camera_shake_intensity, camera_zoom_changed, camera_framed_players）
- [ ] **AC-8.3**：所有信号使用Godot 4.6 Callable语法

## Open Questions

### O-1：EventBus vs 直接节点引用的最终架构

**问题**：摄像机系统向其他系统共享数据的方式尚未最终确定。

**选项**：
- A：EventBus Autoload（推荐）——相机发射到Autoload，其他系统订阅。松耦合，易扩展。
- B：直接节点引用——其他系统直接持有CameraController引用。性能略优但耦合紧。

**建议**：选项A（EventBus）——这是Godot中多系统间共享状态的常见模式，与粒子特效系统GDD中建议的信号架构一致。

---

### O-2：屏幕空间VFX与相机的CanvasLayer层级

**问题**：同步攻击的屏幕边缘橙蓝脉冲（来自粒子特效系统）应该放在哪个CanvasLayer？

**问题详情**：
- 如果放在跟随相机的CanvasLayer（作为Camera2D子节点），脉冲会随相机移动
- 如果放在固定CanvasLayer（独立于相机），脉冲位置固定

**建议**：屏幕边缘脉冲应使用**独立于相机的固定CanvasLayer**，这样玩家看到的是屏幕边缘的固定效果，而非随相机移动的效果。

---

### O-3：DRAG_MARGIN的具体值

**问题**：软死区（draggable_margin）的推荐值是0.08，但这是估计值。

**需要验证**：
- 0.08是否真的减少战斗中的微校正？
- 在实际分辨率（1080p vs 1440p）上，视口比例是否一致？

**建议**：在原型阶段验证，实际测试不同值对战斗手感的影响。

---

### O-4：Boss作为"背景"的40%屏幕宽度规则

**问题**：规则规定Boss可占据最多40%屏幕宽度而不强制缩放——这个数字是估计值。

**需要验证**：
- Deadline Boss的实际Sprite宽度是多少？
- 40%阈值是否会导致Boss"太大"或"太小"？

**建议**：在Boss美术资源确定后重新评估这个阈值。

---

### O-5：状态优先级的设计意图确认

**问题**：`CRISIS > BOSS_PHASE_CHANGE > BOSS_FOCUS > SYNC_ATTACK > PLAYER_ATTACK > COMBAT_ZOOM > NORMAL`的优先级是否正确？

**疑点**：如果Boss相位转换（CRISIS之外最震撼的事件）与玩家倒地同时发生，相机应该优先追踪倒地玩家吗？还是优先展示Boss的相位转换？

**当前设计**：CRISIS优先——玩家倒地是最高优先级的视觉事件。

**确认需求**：这个优先级设计需要与游戏设计师确认是否符合预期手感。
