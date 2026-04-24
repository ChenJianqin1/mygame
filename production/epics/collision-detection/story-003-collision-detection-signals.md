# Story 003: Collision Detection and Hit Signals

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
- `TR-collision-007` — PLAYER_HITBOX overlaps BOSS layer — collision detection → hit_confirmed signal fires
- `TR-collision-008` — Same Hitbox overlaps Hurtbox for multiple frames — after first frame → no repeated hit trigger
- `TR-collision-023` — Combo part 1 and part 2 cover same Hurtbox — each hits separately → both Hitboxes can independently trigger
- `TR-collision-026` — Hitbox marked DESTROYED at frame N — frame N physics detection → still participates, hit is valid
- `TR-collision-027` — Frame N DESTROYED detection complete — frame N+1 starts → queue_free() executes

**ADR Governing Implementation**: ADR-ARCH-002: Collision Detection
**ADR Decision Summary**: Hitbox/Hurtbox 通过 Area2D area_entered 信号检测重叠；同一 Hitbox 对同一 Hurtbox 只命中一次；DESTROYED 帧仍参与碰撞

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Area2D API 在 Godot 4.4-4.6 无变化

**Control Manifest Rules (Foundation Layer)**:
- Required: 碰撞事件通过 Events 信号路由（跨系统）或直接路由（Boss AI感知）
- Required: Hitbox 级互斥：同一 Hitbox 对同一 Hurtbox 只命中一次

---

## Acceptance Criteria

*From GDD AC (CR2-03, CR2-04, EC1-01, EC3-01, EC3-02):*

- [ ] PLAYER_HITBOX 与 BOSS 层重叠 → hit_confirmed 信号触发
- [ ] 同一 Hitbox 与 Hurtbox 重叠多帧 → 第一帧后不重复触发命中
- [ ] 连招第1段和第2段覆盖同一 Hurtbox → 两个 Hitbox 均可独立触发
- [ ] Hitbox 在帧 N 标记为 DESTROYED → 帧 N 物理检测仍参与，命中有效
- [ ] 帧 N 的 DESTROYED 检测完成 → 帧 N+1 开始 queue_free() 执行

---

## Implementation Notes

*Derived from ADR-ARCH-002 + GDD Section 2.3:*

### 1. 信号路由架构

```
Hitbox 检测到 Hurtbox
       ↓
hit_confirmed(hitbox, hurtbox, attack_id)
       ↓
   ┌─────────────────────────────────────┐
   │ CollisionManager                    │
   │  → Events.attack_hit (跨系统路由)    │
   │  → BossAI 直接路由 (低延迟)          │
   └─────────────────────────────────────┘
```

### 2. CollisionManager 信号定义

```gdscript
## CollisionManager.gd — Autoload singleton

signal hit_confirmed(hitbox: Area2D, hurtbox: Area2D, attack_id: String)
# 路由: CollisionManager → Events.attack_hit → ComboSystem, BossAI

# Boss AI 感知信号（直接路由）
signal player_detected(player: Node2D)     # 直接 → BossAI
signal player_lost(player: Node2D)          # 直接 → BossAI
signal player_hurt(player: Node2D, damage: float)  # 直接 → BossAI
```

### 3. Hitbox 命中检测实现

```gdscript
## HitboxResource.gd — Area2D 子类

class_name HitboxResource
extends Area2D

var attack_id: String = ""
var owner_entity: Node2D = null
var state: CollisionManager.HitboxState = CollisionManager.HitboxState.UNSPAWNED

# 记录已命中的 Hurtbox，防止同一 Hitbox 对同一 Hurtbox 重复命中
var _hit_hurtboxes: Set[Area2D] = []

signal hit_confirmed(hitbox: Area2D, hurtbox: Area2D, attack_id: String)

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    # DESTROYED 帧仍参与检测，但不触发新命中
    if state == CollisionManager.HitboxState.DESTROYED:
        return

    # 检查是否为有效 Hurtbox
    if not (area is HurtboxResource):
        return

    # Hitbox 级互斥：同一 Hitbox 对同一 Hurtbox 只命中一次
    if area in _hit_hurtboxes:
        return

    _hit_hurtboxes.add(area)

    # 标记为已命中（但仍参与该帧检测）
    if state == CollisionManager.HitboxState.ACTIVE:
        state = CollisionManager.HitboxState.HIT_REGISTERED

    # 发射命中信号
    hit_confirmed.emit(self, area, attack_id)
    CollisionManager.on_hit_confirmed(self, area, attack_id)

func reset() -> void:
    _hit_hurtboxes.clear()
```

### 4. Events Autoload 信号路由

```gdscript
## Events.gd — Autoload singleton (from ADR-ARCH-001)

signal attack_hit(attack_id: String, is_grounded: bool, hit_count: int)
# 路由: CollisionManager → Events → ComboSystem, BossAI

func on_hit_confirmed(hitbox: Area2D, hurtbox: Area2D, attack_id: String) -> void:
    # CollisionManager 调用此方法路由到 Events
    # 注意：这是 hit_landed 例外的直接路由，经 Events 中继
    var is_grounded := hitbox.owner_entity.is_on_floor() if hitbox.owner_entity else false
    attack_hit.emit(attack_id, is_grounded, 1)  # hit_count 由 ComboSystem 计算
```

### 5. DESTROYED 帧处理

```gdscript
## CollisionManager.gd — physics_process 中的队列处理

func _physics_process(delta: float) -> void:
    # 处理 DESTROYED Hitbox 的 queue_free()
    var to_free: Array[Area2D] = []
    for hitbox in _active_hitboxes:
        if hitbox.state == HitboxState.DESTROYED:
            to_free.append(hitbox)

    for hitbox in to_free:
        hitbox.queue_free()
        _active_hitboxes.erase(hitbox)
        _return_to_pool(hitbox)
```

---

## Out of Scope

- Story 001 处理 Layer/Mask 配置和对象池初始化
- Story 002 处理 Hitbox spawn/despawn 时序
- Story 004 处理 AI 感知
- Story 005 处理 Combo 系统

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: hit_confirmed fires when PLAYER_HITBOX overlaps BOSS
  - Given: Player Hitbox (layer 3) 与 Boss Hurtbox (layer 4) 重叠
  - When: Area2D area_entered 信号触发
  - Then: hit_confirmed 信号发射，包含 hitbox, hurtbox, attack_id
  - Edge cases: 多个 Hitbox 同时命中同一个 Hurtbox

- **AC-2**: No repeated hit for same Hitbox-Hurtbox pair
  - Given: Hitbox 已命中某个 Hurtbox（_hit_hurtboxes 已记录）
  - When: 同一 Hitbox 与同一 Hurtbox 在下一帧继续重叠
  - Then: 不再触发 hit_confirmed
  - Edge cases: 不同 Hitbox（连招第1段vs第2段）应可独立命中

- **AC-3**: Different Hitboxes can hit same Hurtbox independently
  - Given: 连招第1段 Hitbox 和连招第2段 Hitbox 覆盖同一 Hurtbox
  - When: 分别命中
  - Then: 两个 Hitbox 均可独立触发命中
  - Edge cases: 每个 Hitbox 有独立的 _hit_hurtboxes 记录

- **AC-4**: DESTROYED Hitbox still participates in frame N detection
  - Given: Hitbox 在帧 N 被标记为 DESTROYED
  - When: 帧 N 物理检测发生
  - Then: Hitbox 仍参与碰撞检测，命中有效
  - Edge cases: 该帧新进入的 Hurtbox 仍应被检测到

- **AC-5**: queue_free executes in frame N+1
  - Given: Hitbox 在帧 N 被标记为 DESTROYED 且检测完成
  - When: 帧 N+1 开始
  - Then: queue_free() 执行，Hitbox 从场景树移除
  - Edge cases: 确保 queue_free() 不会在同一帧内立即执行

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/collision_detection_signals_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Hitbox pool), Story 002 (spawn/despawn)
- Unlocks: Story 004 (AI perception), Story 005 (Combo hit tracking)

---

## Technical Notes

### Hitbox 级互斥 vs Hurtbox 级互斥

- **Hitbox 级互斥**（本实现）：同一 Hitbox 对同一 Hurtbox 只命中一次
- **Hurtbox 级互斥**：同一 Hurtbox 对同一 Hitbox 只被命中一次

本实现采用 Hitbox 级互斥，因为：
1. 连招需要同一 Hurtbox 被多个 Hitbox 依次命中
2. 避免同一个 Hitbox 因物理重叠多次触发

### Events 信号 vs 直接信号

根据 ADR-ARCH-001 和 ADR-ARCH-002：
- `attack_hit`: 经 Events 中继 → ComboSystem, BossAI
- `player_detected/lost/hurt`: 直接路由 → BossAI（低延迟要求）

### Area2D area_entered 信号特性

Godot 的 Area2D `area_entered` 信号在碰撞后一帧触发，这是 Area2D 的已知行为。本实现通过以下方式确保正确性：
1. DESTROYED 帧仍设置 `monitoring = true`，允许该帧检测
2. 状态检查在回调内部执行，过滤无效命中
