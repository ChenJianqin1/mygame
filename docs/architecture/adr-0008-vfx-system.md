# ADR-ARCH-008: Particle VFX System Architecture

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / Visual Effects |
| **Knowledge Risk** | LOW — GPUParticles2D / CPUParticles2D API 在 Godot 4.4-4.6 无显著变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain变更) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-003 (Combat State Machine), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System), ADR-ARCH-006 (Boss AI) |
| **Enables** | UI系统（屏幕震动无直接依赖） |
| **Blocks** | 无 |
| **Ordering Note** | VFX 是纯被动消费者，不影响游戏逻辑；依赖 CombatSystem 的 hit_landed（直接路由）、ComboSystem 和 CoopSystem 的 Events 信号 |

## Context

### Problem Statement
粒子特效系统需要管理多种 VFX 发射器（hit_vfx、combo_escalation_vfx、sync_burst_vfx、rescue_vfx、boss_death_vfx），每种由不同系统信号触发。系统需要对象池复用（零运行时实例化）、性能预算强制（最大 300 粒子 / 15 发射器）以及正确的混合模式。

### Requirements
- 5 种发射器类型，信号驱动
- CPUParticles2D 用于单次爆发，GPUParticles2D 用于连续螺旋流
- 20 个预分配发射器池，零运行时实例化
- 最大 300 并发粒子，15 并发发射器
- 屏幕空间粒子独立于相机运动

## Decision

### VFXManager (Autoload) 设计

```gdscript
# VFXManager.gd — Autoload singleton

const MAX_PARTICLES := 300
const MAX_EMITTERS := 15
const MAX_QUEUE_DEPTH := 10
const POOL_SIZE := 20

const COLOR_P1 := Color("#F5A623")   # 晨曦橙
const COLOR_P2 := Color("#4ECDC4")    # 梦境蓝
const COLOR_GOLD := Color("#FFD700")  # 打勾金

var _cpu_particle_pool: Array[CPUParticles2D] = []
var _gpu_sync_pool: Array[GPUParticles2D] = []
var _active_particle_count: int = 0
var _active_emitter_count: int = 0
var _emitter_queue: Array[Dictionary] = []

# 发射器配置模板
const EMITTER_CONFIGS: Dictionary = {
    "hit_vfx": {
        "type": "CPU",
        "particles": 40,
        "lifetime": 1.0,
        " explosiveness": 0.8,
        "lifetime_random": 0.3,
    },
    "combo_escalation_vfx": {
        "type": "CPU",
        "particles": 25,
        "lifetime": 1.2,
        "explosiveness": 0.9,
        "lifetime_random": 0.2,
    },
    "rescue_vfx": {
        "type": "CPU",
        "particles": 18,
        "lifetime": 0.7,
        "explosiveness": 0.85,
        "lifetime_random": 0.3,
    },
    "boss_death_vfx": {
        "type": "CPU",
        "particles": 60,
        "lifetime": 1.5,
        "explosiveness": 0.7,
        "lifetime_random": 0.4,
    },
    "sync_burst_vfx": {
        "type": "GPU",
        "particles": 50,
        "lifetime": 1.2,
        "blend_mode": GPUParticles2D.BR_MODE_ADD,
    }
}

func _ready() -> void:
    _init_pool()
    _connect_signals()

func _init_pool() -> void:
    # 预分配 20 个 CPUParticles2D
    for i in range(POOL_SIZE):
        var emitter := CPUParticles2D.new()
        emitter.emitting = false
        emitter.one_shot = true
        _cpu_particle_pool.append(emitter)

    # 预分配 2 个 GPUParticles2D (sync burst)
    for i in range(2):
        var emitter := GPUParticles2D.new()
        emitter.emitting = false
        _gpu_sync_pool.append(emitter)

func _connect_signals() -> void:
    # 直接信号（低延迟）
    # CombatSystem 直接调用 VFXManager.hit_landed — 不经 Events
    # VFXManager.hit_landed(position, attack_type, direction, player_color)

    # Events 信号
    Events.combo_tier_escalated.connect(_on_combo_tier_escalated)
    Events.sync_burst_triggered.connect(_on_sync_burst_triggered)
    Events.rescue_triggered.connect(_on_rescue_triggered)
    Events.boss_defeated.connect(_on_boss_defeated)
    Events.camera_shake_intensity.connect(_on_camera_shake_intensity)

## 发射接口

func emit_hit(position: Vector2, attack_type: String, direction: Vector2, player_color: Color) -> void:
    var count := _get_particle_count(attack_type)
    if not _can_emit(count):
        _queue_emitter("hit_vfx", {"position": position, "attack_type": attack_type, "direction": direction, "player_color": player_color})
        return

    var emitter := _checkout_cpu_emitter()
    if emitter == null:
        return

    _configure_hit_emitter(emitter, attack_type, position, direction, player_color)
    emitter.restart()
    _active_particle_count += count
    emitter.connect("finished", _on_emitter_finished.bind(emitter, count), CONNECT_ONE_SHOT)

func emit_combo_escalation(tier: int, player_color: Color, position: Vector2) -> void:
    var count := tier * 15
    if not _can_emit(count):
        _queue_emitter("combo_escalation_vfx", {"tier": tier, "player_color": player_color, "position": position})
        return

    var emitter := _checkout_cpu_emitter()
    if emitter == null:
        return

    _configure_combo_emitter(emitter, tier, player_color)
    emitter.restart()
    _active_particle_count += count

func emit_sync_burst(position: Vector2) -> void:
    # 连续螺旋流 — 使用 GPUParticles2D
    var emitter := _get_gpu_sync_emitter()
    if emitter == null:
        return

    _configure_sync_emitter(emitter, position)
    emitter.restart()
    _active_emitter_count += 1

func emit_rescue(position: Vector2, rescuer_color: Color) -> void:
    var emitter := _checkout_cpu_emitter()
    if emitter == null:
        return

    _configure_rescue_emitter(emitter, rescuer_color)
    emitter.restart()
    _active_particle_count += 18

func emit_boss_death(position: Vector2) -> void:
    var emitter := _checkout_cpu_emitter()
    if emitter == null:
        return

    _configure_boss_death_emitter(emitter)
    emitter.restart()
    _active_particle_count += 60

## 配置方法

func _configure_hit_emitter(emitter: CPUParticles2D, attack_type: String, position: Vector2, direction: Vector2, player_color: Color) -> void:
    emitter.position = position

    var config: Dictionary = EMITTER_CONFIGS["hit_vfx"]
    var count: int = _get_particle_count(attack_type)

    emitter.amount = count
    emitter.lifetime = config.lifetime
    emitter.explosiveness = config.explosiveness
    emitter.lifetime_randomness = config.lifetime_random

    # 方向：从 position 向 direction 扩散
    emitter.direction = direction.normalized()
    emitter.spread = _get_spread(attack_type)
    emitter.initial_velocity_max = _get_speed(attack_type)
    emitter.gravity = _get_gravity(attack_type)

    # 颜色
    emitter.color = player_color

func _configure_combo_emitter(emitter: CPUParticles2D, tier: int, player_color: Color) -> void:
    emitter.amount = tier * 15
    emitter.color = player_color
    if tier >= 3:
        emitter.color = player_color * 1.4  # +40% brightness
        emitter.modulate = COLOR_GOLD

func _configure_sync_emitter(emitter: GPUParticles2D, position: Vector2) -> void:
    emitter.position = position
    emitter.amount = 50
    emitter.lifetime = 1.2
    emitter.blend_mode = GPUParticles2D.BR_MODE_ADD
    # 橙色 + 蓝色粒子螺旋混合

func _configure_rescue_emitter(emitter: CPUParticles2D, rescuer_color: Color) -> void:
    emitter.amount = 18
    emitter.color = rescuer_color
    emitter.direction = Vector2(0, -1)  # 向上
    emitter.spread = 45  # 45度锥形

func _configure_boss_death_emitter(emitter: CPUParticles2D) -> void:
    emitter.amount = 60
    emitter.color = Color.WHITE
    emitter.spread = 180  # 全方向
    emitter.initial_velocity_max = 300

## 池管理

func _checkout_cpu_emitter() -> CPUParticles2D:
    for emitter in _cpu_particle_pool:
        if not emitter.emitting:
            return emitter
    return null

func _get_gpu_sync_emitter() -> GPUParticles2D:
    for emitter in _gpu_sync_pool:
        if not emitter.emitting:
            return emitter
    return null

func _on_emitter_finished(emitter: Node, particle_count: int) -> void:
    _active_particle_count -= particle_count
    if emitter is CPUParticles2D:
        emitter.emitting = false
    elif emitter is GPUParticles2D:
        emitter.emitting = false
        _active_emitter_count -= 1
    _drain_queue()

func _can_emit(particle_count: int) -> bool:
    return (_active_particle_count + particle_count < MAX_PARTICLES) and (_active_emitter_count < MAX_EMITTERS)

func _queue_emitter(type: String, params: Dictionary) -> void:
    if _emitter_queue.size() >= MAX_QUEUE_DEPTH:
        _emitter_queue.pop_front()  # FIFO eviction
    _emitter_queue.append({"type": type, "params": params})

func _drain_queue() -> void:
    while _emitter_queue.size() > 0 and _can_emit(50):
        var entry: Dictionary = _emitter_queue.pop_front()
        _process_queued(entry)

func _process_queued(entry: Dictionary) -> void:
    match entry.type:
        "hit_vfx":
            var p: Dictionary = entry.params
            emit_hit(p.position, p.attack_type, p.direction, p.player_color)
        "combo_escalation_vfx":
            var p: Dictionary = entry.params
            emit_combo_escalation(p.tier, p.player_color, p.position)

## 辅助方法

func _get_particle_count(attack_type: String) -> int:
    match attack_type:
        "LIGHT":   return randi() % 4 + 5    # 5-8
        "MEDIUM":  return randi() % 6 + 10   # 10-15
        "HEAVY":   return randi() % 8 + 18   # 18-25
        "SPECIAL": return randi() % 11 + 30  # 30-40
    return 8

func _get_spread(attack_type: String) -> float:
    match attack_type:
        "LIGHT", "MEDIUM": return 180.0   # 360度
        "HEAVY", "SPECIAL": return 60.0   # 120度锥形
    return 180.0

func _get_speed(attack_type: String) -> float:
    match attack_type:
        "LIGHT":   return randf() * 70 + 180.0  # 180-250
        "MEDIUM":  return randf() * 80 + 220.0  # 220-300
        "HEAVY":   return randf() * 50 + 150.0  # 150-200
        "SPECIAL": return randf() * 80 + 200.0  # 200-280
    return 200.0

func _get_gravity(attack_type: String) -> Vector2:
    match attack_type:
        "LIGHT", "MEDIUM": return Vector2(0, 400)   # 400 px/s²
        "HEAVY", "SPECIAL": return Vector2(0, 200) # 200 px/s²
    return Vector2(0, 300)

## 信号处理

func _on_combo_tier_escalated(tier: int, player_color: Color) -> void:
    # position 需要从 GameState 获取（简化处理）
    emit_combo_escalation(tier, player_color, Vector2.ZERO)

func _on_sync_burst_triggered(position: Vector2) -> void:
    emit_sync_burst(position)

func _on_rescue_triggered(position: Vector2, rescuer_color: Color) -> void:
    emit_rescue(position, rescuer_color)

func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
    emit_boss_death(position)

func _on_camera_shake_intensity(trauma: float) -> void:
    # VFX 可以响应相机震动强度做额外位移
    # 例如屏幕边缘粒子做额外偏移
    pass

## 公开接口

func get_active_particle_count() -> int:
    return _active_particle_count

func get_active_emitter_count() -> int:
    return _active_emitter_count
```

### 发射器类型与信号映射

| 发射器 ID | 来源信号 | Backend | 类型 |
|-----------|---------|---------|------|
| `hit_vfx` | CombatSystem.hit_landed (直接) | CPUParticles2D | 单次爆发 |
| `combo_escalation_vfx` | ComboSystem.combo_tier_escalated (Events) | CPUParticles2D | 单次爆发 |
| `sync_burst_vfx` | ComboSystem.sync_burst_triggered (Events) | GPUParticles2D | 连续螺旋流 |
| `rescue_vfx` | CoopSystem.rescue_triggered (Events) | CPUParticles2D | 单次爆发 |
| `boss_death_vfx` | BossAIManager.boss_defeated (Events) | CPUParticles2D | 单次爆发 |

### 颜色定义

| 来源 | 颜色 | Hex |
|------|------|-----|
| P1 攻击粒子 | 晨曦橙 | #F5A623 |
| P2 攻击粒子 | 梦境蓝 | #4ECDC4 |
| Tier 4 金色火星 | 打勾金 | #FFD700 |

### 性能预算

| 指标 | 上限 | 强制方式 |
|------|------|---------|
| 并发粒子数 | 300 | VFXManager._can_emit() 检查 |
| 并发发射器 | 15 | 同上 |
| 发射器池大小 | 20 | POOL_SIZE 常量 |
| 队列深度 | 10 | FIFO 驱逐 |

## Alternatives Considered

### Alternative 1: 每种 VFX 独立节点管理
- **描述**: 每个发射器类型有自己的场景/节点树
- **优点**: 调试直观
- **缺点**: 无统一池管理，性能不可控
- **拒绝理由**: 需要统一池管理强制性能预算

### Alternative 2: GPUParticles2D 全家桶
- **描述**: 所有 VFX 都用 GPUParticles2D
- **优点**: GPU 加速，适合大量粒子
- **缺点**: CPUParticles2D 对单次爆发更高效（确定性、无 GPU 上传开销）
- **拒绝理由**: 单次爆发用 CPUParticles2D 更合适，连续流用 GPUParticles2D

## Consequences

### Positive
- **零 GC**: 预分配池，发射器复用，无运行时实例化
- **性能可预测**: 硬上限 300 粒子 / 15 发射器
- **信号驱动**: VFX 系统完全被动，由其他系统信号触发

### Negative
- **调试复杂性**: 池管理使得发射器状态追踪较复杂
- **队列丢弃**: 队列满时 FIFO 驱逐最老事件

### Risks
- **粒子数量超限**: 如果 _can_emit 逻辑有 bug，可能超预算。**缓解**: _can_emit 是强检查
- **GPU/CPU 混合模式**: sync_burst 使用 GPUParticles2D，其他用 CPUParticles2D，需要两个池管理

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| particle-vfx-system.md | 5 种发射器类型 | EMITTER_CONFIGS 定义 |
| particle-vfx-system.md | hit_vfx 单次爆发 | _configure_hit_emitter() |
| particle-vfx-system.md | sync_burst 连续螺旋流 | _configure_sync_emitter() + GPUParticles2D |
| particle-vfx-system.md | rescue_vfx 救援爆发 | _configure_rescue_emitter() |
| particle-vfx-system.md | boss_death_vfx | _configure_boss_death_emitter() |
| particle-vfx-system.md | 粒子池 20 个预分配 | _init_pool() |
| particle-vfx-system.md | 最大 300 粒子 / 15 发射器 | MAX_PARTICLES / MAX_EMITTERS |
| particle-vfx-system.md | P1/P2 颜色定义 | COLOR_P1 / COLOR_P2 常量 |
| particle-vfx-system.md | FIFO 队列（队满丢弃） | _queue_emitter() |
| particle-vfx-system.md | Additive blend (sync) | BR_MODE_ADD |
| combat-system.md | hit_landed 直接信号 | emit_hit() 直接调用 |
| combo-system.md | sync_burst_triggered | Events 路由 |
| coop-system.md | rescue_triggered | Events 路由 |
| camera-system.md | camera_shake_intensity | Events 路由 |

## Performance Implications
- **CPU**: 每帧池扫描 ~0.01ms（20个发射器）
- **Memory**: 20×CPUParticles2D + 2×GPUParticles2D ≈ 200KB
- **Load Time**: 预分配开销约 5ms

## Migration Plan
1. 创建 `VFXManager.gd` Autoload
2. 实现池初始化（_init_pool）
3. 实现 5 种发射器配置（EMITTER_CONFIGS）
4. 实现发射接口（emit_hit / emit_combo_escalation / emit_sync_burst / emit_rescue / emit_boss_death）
5. 实现性能检查（_can_emit）和队列（FIFO）
6. 连接 Events 信号
7. 配置 CombatSystem 直接调用 VFXManager.hit_landed

## Validation Criteria
- [ ] 20 个发射器预分配完成，无运行时实例化
- [ ] hit_landed(SPECIAL, tier=4) 触发 ~76 粒子（44+2+30）
- [ ] 粒子数超过 300 时新事件入队，不丢弃现有粒子
- [ ] 队列满时（10个）FIFO 驱逐最老事件
- [ ] sync_burst 使用 BR_MODE_ADD（叠加混合）
- [ ] emit_rescue 使用 rescuer_color 而非被救者颜色
- [ ] GPUParticles2D 用于 sync_burst，CPUParticles2D 用于其他

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-003: Combat State Machine — hit_landed 直接路由
- ADR-ARCH-004: Combo System — sync_burst_triggered
- ADR-ARCH-005: Coop System — rescue_triggered
- ADR-ARCH-006: Boss AI — boss_defeated
- ADR-ARCH-007: Camera System — camera_shake_intensity
- `docs/architecture/architecture.md`
