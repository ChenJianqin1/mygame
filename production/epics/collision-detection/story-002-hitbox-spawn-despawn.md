# Story 002: Hitbox Spawn/Despawn Lifecycle

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
- `TR-collision-005` — Player initiates LIGHT attack — animation plays to attack frame → Hitbox Area2D created and set to ACTIVE
- `TR-collision-006` — Attack animation finishes — animation_finished signal → Hitbox enters DESTROYED state, removed next frame
- `TR-collision-009` — Player is interrupted — state leaves ATTACKING → all related Hitboxes immediately despawn
- `TR-collision-010` — During attack animation — input detected in _process attempting spawn → spawn must not happen in _process, must be animation-driven

**ADR Governing Implementation**: ADR-ARCH-002: Collision Detection
**ADR Decision Summary**: Hitbox 在攻击动画帧 spawn，攻击结束时 despawn；Hitbox 在 DESTROYED 帧仍参与碰撞检测；queue_free() 在下一帧物理步执行

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Area2D API 在 Godot 4.4-4.6 无变化

**Control Manifest Rules (Foundation Layer)**:
- Required: Hitbox 在攻击动画帧 spawn，攻击结束时 despawn
- Required: Hitbox 在 DESTROYED 帧仍参与碰撞检测
- Required: 动画驱动 Hitbox（AnimationPlayer keyframe 回调），禁止在 _process 中 spawn

---

## Acceptance Criteria

*From GDD AC (CR2-01, CR2-02, CR2-06, CR2-07):*

- [ ] 玩家发起轻攻击，动画播放到攻击帧 → Hitbox Area2D 被创建并设为 ACTIVE
- [ ] 攻击动画播放完毕，animation_finished 信号 → Hitbox 转入 DESTROYED 状态，该帧后移除
- [ ] 玩家被打断，状态从 ATTACKING 离开 → 所有相关 Hitbox 立即 despawn
- [ ] 攻击动画播放中，在 _process 中检测输入尝试 spawn → 不应在 _process spawn，必须动画驱动

---

## Implementation Notes

*Derived from ADR-ARCH-002 + GDD Section 2.2 + Control Manifest:*

### 1. Hitbox 状态机

```
UNSPAWNED → [攻击帧] → ACTIVE → [命中] → HIT_REGISTERED → [攻击结束] → DESTROYED
```

**状态说明：**
- `UNSPAWNED`: 未创建（对象池中）
- `ACTIVE`: 检测中，可触发命中
- `HIT_REGISTERED`: 已命中，仍参与该帧碰撞检测
- `DESTROYED`: 标记销毁，该帧仍检测，下帧 queue_free()

### 2. AnimationPlayer Method Track 配置

```gdscript
# 动画资源中，在攻击关键帧添加 Method Track 调用：
# AnimationPlayer: attack_light
# Frame 5 (hit frame): Method Track → HitboxManager.spawn_hitbox("attack_light_p1", {...})
# Frame 16 (animation end): Method Track → HitboxManager.despawn_hitbox(hitbox)
```

### 3. CollisionManager 方法

```gdscript
## spawn_hitbox — 从对象池取出 Hitbox 并配置
func spawn_hitbox(attack_id: String, config: Dictionary) -> Area2D:
    if _active_hitboxes.size() >= MAX_CONCURRENT_HITBOXES:
        push_warning("Max concurrent hitboxes reached")
        return null

    var hitbox := _hitbox_pool.pop_back() as Area2D
    if hitbox == null:
        return null

    # 配置 Hitbox 属性
    hitbox.attack_id = attack_id
    hitbox.owner_entity = config.get("owner")
    hitbox.state = HitboxState.ACTIVE
    hitbox.position = config.get("offset", Vector2.ZERO)
    hitbox.rotation = config.get("rotation", 0.0)

    # 设置碰撞层
    hitbox.collision_layer = config.get("layer", LAYER_PLAYER_HITBOX)
    hitbox.collision_mask = config.get("mask", LAYER_BOSS)

    # 设置形状
    var shape := RectangleShape2D.new()
    shape.size = config.get("size", Vector2(64, 64))
    hitbox.add_child(shape)

    # 添加到场景树
    var parent := config.get("parent", get_tree().root)
    parent.add_child(hitbox)
    hitbox.monitoring = true

    _active_hitboxes.append(hitbox)
    return hitbox

## despawn_hitbox — 将 Hitbox 标记为 DESTROYED 并归还池
func despawn_hitbox(hitbox: Area2D) -> void:
    if hitbox == null or not is_instance_valid(hitbox):
        return

    hitbox.state = HitboxState.DESTROYED
    hitbox.set_monitoring(false)  # 该帧仍检测，但不再接收新信号
    hitbox.get_parent().remove_child(hitbox)
    _return_to_pool(hitbox)
    _active_hitboxes.erase(hitbox)

## cleanup_by_owner — 中断时清理该owner的所有Hitbox
func cleanup_by_owner(owner: Node2D, attack_id: String = "") -> void:
    for hitbox in _active_hitboxes:
        if hitbox.owner_entity == owner:
            if attack_id.is_empty() or hitbox.attack_id == attack_id:
                despawn_hitbox(hitbox)

## _return_to_pool — 归还池中，重置状态
func _return_to_pool(hitbox: Area2D) -> void:
    # 清除所有子节点（形状等）
    for child in hitbox.get_children():
        child.queue_free()

    # 重置状态
    hitbox.attack_id = ""
    hitbox.owner_entity = null
    hitbox.state = HitboxState.UNSPAWNED
    hitbox.position = Vector2.ZERO
    hitbox.rotation = 0.0
    hitbox.collision_layer = 0
    hitbox.collision_mask = 0

    _hitbox_pool.append(hitbox)
```

### 4. 动画回调示例

```gdscript
# PlayerController.gd — 动画信号处理

func _ready() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)

func _on_attack_hit_frame() -> void:
    # 由 AnimationPlayer Method Track 调用
    var hitbox := CollisionManager.spawn_hitbox("attack_light_p1", {
        "owner": self,
        "parent": self,
        "layer": CollisionManager.LAYER_PLAYER_HITBOX,
        "mask": CollisionManager.LAYER_BOSS,
        "offset": Vector2(50, 0),  # 相对于 Player 位置
        "size": Vector2(64, 64)
    })
    _current_hitbox = hitbox

func _on_animation_finished(anim_name: String) -> void:
    if anim_name.begins_with("attack_"):
        if _current_hitbox != null:
            CollisionManager.despawn_hitbox(_current_hitbox)
            _current_hitbox = null

func _on_state_changed(old_state: String, new_state: String) -> void:
    # 玩家状态离开 ATTACKING 时清理所有 Hitbox
    if old_state == "ATTACKING" and new_state != "ATTACKING":
        CollisionManager.cleanup_by_owner(self)
```

---

## Out of Scope

- Story 001 处理 Layer/Mask 配置和对象池初始化
- Story 003 处理地面检测
- Story 004 处理 AI 感知

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **AC-1**: Hitbox spawns at attack frame and becomes ACTIVE
  - Given: Player 在 ATTACKING 状态，动画播放到第 5 帧（hit frame）
  - When: AnimationPlayer Method Track 调用 spawn_hitbox()
  - Then: Hitbox.state == ACTIVE，monitoring == true，可检测碰撞
  - Edge cases: 已达 MAX_CONCURRENT_HITBOXES 时拒绝 spawn

- **AC-2**: Hitbox enters DESTROYED state on animation_finished
  - Given: 攻击动画播放完毕（animation_finished 信号）
  - When: despawn_hitbox() 被调用
  - Then: Hitbox.state == DESTROYED，monitoring == false，该帧仍参与碰撞检测
  - Edge cases: animation_finished 在非攻击动画时不应触发 despawn

- **AC-3**: Interruption despawns all related Hitboxes
  - Given: Player 在 ATTACKING 状态，有一个活跃 Hitbox
  - When: Player 被击中，状态切换到 HURT
  - Then: CollisionManager.cleanup_by_owner(self) 被调用，所有 Hitbox despawn
  - Edge cases: 多个不同 attack_id 的 Hitbox 应全部清理

- **AC-4**: Spawn must be animation-driven, not _process-driven
  - Given: Player 在 ATTACKING 状态
  - When: _process 中检测到输入尝试 spawn
  - Then: spawn 不应发生，必须通过 AnimationPlayer Method Track
  - Edge cases: 确认实现中无 _process 或 _physics_process 直接 spawn

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/collision/hitbox_spawn_despawn_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Hitbox pool + Layer/Mask)
- Unlocks: Story 003 (ground detection), Story 004 (AI perception), Story 006 (edge cases)

---

## Technical Notes

### AnimationPlayer Method Track 配置步骤

1. 在动画资源中选中攻击帧（第 5 帧）
2. 打开 Animation > Edit Tracks > Add Track > Method Call
3. 选择 PlayerController 节点
4. 方法名: `_on_attack_hit_frame`
5. 参数: （无参数，方法内通过 PlayerController 获取 context）

### DESTROYED 帧仍检测的关键实现

```gdscript
# 在 physics_process 中处理 queue_free
func _physics_process(delta: float) -> void:
    for hitbox in _active_hitboxes:
        if hitbox.state == HitboxState.DESTROYED:
            # 该帧物理步执行完后才真正释放
            hitbox.queue_free()
            _active_hitboxes.erase(hitbox)
```

### 并发上限强制

```gdscript
func spawn_hitbox(...) -> Area2D:
    if _active_hitboxes.size() >= MAX_CONCURRENT_HITBOXES:
        push_error("Hitbox spawn rejected: max concurrent hitboxes (%d) reached" % MAX_CONCURRENT_HITBOXES)
        return null
    # ... 正常 spawn
```
