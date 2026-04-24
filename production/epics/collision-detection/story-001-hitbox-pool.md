# Story 001: Hitbox Pool + Layer/Mask Collision Setup

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
- `TR-collision-001` — Player and Boss in scene, Boss not attacking — player approaches Boss → Player CharacterBody detects Boss (mask includes BOSS layer)
- `TR-collision-002` — Player and Boss Hitbox coexist — Boss attacks → Player CharacterBody detects BOSS_HITBOX layer
- `TR-collision-003` — P1 Hitbox overlaps P2 CharacterBody — collision frame → P2 has no response (mask excludes PLAYER_HITBOX)
- `TR-collision-004` — Player on platform — moving toward platform → player is blocked by platform (WORLD layer)

**ADR Governing Implementation**: ADR-ARCH-002: Collision Detection
**ADR Decision Summary**: Area2D 对象池 + Spawn-in/Spawn-out 模式；6层 Layer/Mask 碰撞策略；20个预分配 Area2D 对象池

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Area2D API 在 Godot 4.4-4.6 无变化

**Control Manifest Rules (Foundation Layer)**:
- Required: CollisionManager 作为 Autoload 管理 Hitbox 生命周期
- Required: 对象池 20 个预分配 Area2D，零运行时实例化
- Required: 6层 Layer/Mask 碰撞策略 (WORLD/PLAYER/PLAYER_HITBOX/BOSS/BOSS_HITBOX/SENSOR)

---

## Acceptance Criteria

*From GDD AC (CR1-01 through CR1-04):*

- [ ] 玩家和Boss在场景中，Boss未攻击，玩家接近Boss时 → 玩家CharacterBody检测到Boss（mask包含BOSS层）
- [ ] 玩家和Boss攻击Hitbox同时存在，Boss执行攻击 → 玩家CharacterBody检测到BOSS_HITBOX层
- [ ] P1的Hitbox与P2的CharacterBody重叠 → P2无响应（mask不包含PLAYER_HITBOX）
- [ ] 玩家在平台上，向平台方向移动 → 玩家被平台阻挡（WORLD层）
- [ ] CollisionManager 对象池预分配 20 个 Area2D
- [ ] 对象池从池中 checkout Hitbox，无运行时 new Area2D()

---

## Implementation Notes

*Derived from ADR-ARCH-002 + GDD Section 2.1-2.2:*

### 1. Layer/Mask 配置（project.godot）

```
Layer 1: WORLD        — 静态世界几何体（平台、墙壁）
Layer 2: PLAYER       — 玩家角色 PhysicsBody2D
Layer 3: PLAYER_HITBOX — 玩家攻击 Hitbox（攻击时激活）
Layer 4: BOSS         — Boss CharacterBody2D
Layer 5: BOSS_HITBOX  — Boss 攻击 Hitbox（攻击时激活）
Layer 6: SENSOR       — AI 感知探测器
```

**Mask 矩阵：**

| 实体类型 | Layer | Mask（检测谁） |
|----------|-------|----------------|
| Player CharacterBody | 2 | 1, 4, 5 (World, Boss, BossHitbox) |
| Player Hitbox | 3 | 4 (Boss Hurtbox) |
| Boss CharacterBody | 4 | 1, 2, 3 (World, Player, PlayerHitbox) |
| Boss Hitbox | 5 | 2 (Player Hurtbox) |

### 2. CollisionManager.gd (Autoload)

```gdscript
## CollisionManager — Autoload singleton
## Manages Hitbox/Hurtbox collision detection and object pooling

const POOL_SIZE := 20
const MAX_CONCURRENT_HITBOXES := 13

var _hitbox_pool: Array[Area2D] = []
var _active_hitboxes: Array[Area2D] = []

func _init() -> void:
    _preallocate_pool()

func _preallocate_pool() -> void:
    for i in POOL_SIZE:
        var hitbox := Area2D.new()
        hitbox.set_script(HitboxResource)  # 自定义 Hitbox 脚本
        hitbox.monitoring = false
        _hitbox_pool.append(hitbox)

func spawn_hitbox(attack_id: String, config: Dictionary) -> Area2D:
    if _active_hitboxes.size() >= MAX_CONCURRENT_HITBOXES:
        push_warning("Max concurrent hitboxes (%d) reached" % MAX_CONCURRENT_HITBOXES)
        return null
    var hitbox := _hitbox_pool.pop_back() as Area2D
    _configure_hitbox(hitbox, attack_id, config)
    get_tree().root.add_child(hitbox)
    _active_hitboxes.append(hitbox)
    return hitbox

func despawn_hitbox(hitbox: Area2D) -> void:
    hitbox.state = HitboxState.DESTROYED
    hitbox.set_monitoring(false)  # 该帧仍检测
    hitbox.get_parent().remove_child(hitbox)
    _hitbox_pool.append(hitbox)
    _active_hitboxes.erase(hitbox)

enum HitboxState { UNSPAWNED, ACTIVE, HIT_REGISTERED, DESTROYED }
```

### 3. Hitbox Area2D 资源配置

```gdscript
## HitboxResource.gd — 自定义 Area2D 脚本

class_name HitboxResource
extends Area2D

var attack_id: String = ""
var owner_entity: Node2D = null
var state: CollisionManager.HitboxState = CollisionManager.HitboxState.UNSPAWNED

signal hit_confirmed(hitbox: Area2D, hurtbox: Area2D)

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if state == CollisionManager.HitboxState.DESTROYED:
        return
    if area is HurtboxResource:
        hit_confirmed.emit(self, area)
```

---

## Out of Scope

- Story 002 处理 Hitbox spawn/despawn 时序
- Story 003 处理地面检测
- Story 004 处理 AI 感知

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: Player CharacterBody detects Boss via mask
  - Given: Player 和 Boss 在同一场景
  - When: 玩家向 Boss 移动
  - Then: Player 的 CharacterBody 通过 mask 检测到 BOSS layer
  - Edge cases: Boss 未攻击时仅 CharacterBody 检测，无 Hitbox

- **AC-2**: Player detects BOSS_HITBOX layer when attacking
  - Given: Boss 执行攻击，Hitbox 已 spawn
  - When: Player 向 Boss Hitbox 移动
  - Then: Player CharacterBody 检测到 BOSS_HITBOX (layer 5)
  - Edge cases: 多个 Boss Hitbox 同时存在

- **AC-3**: P1 Hitbox does not trigger P2 CharacterBody
  - Given: P1 的 PLAYER_HITBOX (layer 3) 与 P2 的 PLAYER CharacterBody (layer 2) 重叠
  - When: 碰撞检测帧
  - Then: P2 无响应，因为 P2 mask 不包含 PLAYER_HITBOX
  - Edge cases: P2 的 hurtbox 应该被 P1 Hitbox 检测到

- **AC-4**: Player blocked by WORLD layer platform
  - Given: Player 在平台上，向平台方向移动
  - When: move_and_slide() 执行
  - Then: 玩家被 WORLD layer (layer 1) 的平台阻挡
  - Edge cases: 半透明平台边界情况

- **AC-5**: Object pool preallocates 20 Area2D
  - Given: 游戏启动，CollisionManager 初始化
  - When: _preallocate_pool() 执行
  - Then: _hitbox_pool 包含 20 个 Area2D 实例
  - Edge cases: 重复初始化不应堆积

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/hitbox_pool_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation layer, first collision story)
- Unlocks: Story 002 (Hitbox spawn/despawn), Story 003 (ground detection), Story 004 (AI perception)

---

## Technical Notes

### Layer/Mask 配置在 project.godot

需要在 `project.godot` 中配置 Physics > 2D Physics Layers：

```
[layer_names]

2d_physics/layer_1="WORLD"
2d_physics/layer_2="PLAYER"
2d_physics/layer_3="PLAYER_HITBOX"
2d_physics/layer_4="BOSS"
2d_physics/layer_5="BOSS_HITBOX"
2d_physics/layer_6="SENSOR"
```

### 对象池关键约束

1. **零运行时实例化**: 所有 Area2D 在 _init() 中预分配
2. **线程安全**: Autoload 在主线程运行，无线程安全问题
3. **状态重置**: checkout 时必须重置所有状态（position, rotation, scale, monitoring）
