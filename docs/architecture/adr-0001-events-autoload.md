# ADR-ARCH-001: Events Autoload 信号总线架构

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (信号架构) |
| **Knowledge Risk** | LOW — Signal API 在 Godot 4.4-4.6 无变化；Autoload 系统无变化 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/` (signal API) |
| **Post-Cutoff APIs Used** | 无 — Signal API 稳定 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | 无 |
| **Enables** | ADR-ARCH-002 (Collision Detection), ADR-ARCH-003 (Combat State Machine), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System) 及之后所有 Foundation/Core ADR |
| **Blocks** | 无 |
| **Ordering Note** | Foundation 层第一个决策 — 所有其他 Foundation/Core ADR 依赖本 ADR 确立的信号路由模式 |

## Context

### Problem Statement
14个系统需要相互通信。直接节点引用会造成紧耦合（难以测试、场景重构脆弱）。需要一种所有系统都能通过它通信的中央消息总线。

### Constraints
- 信号必须是 fire-and-forget（无返回值）
- 消费者必须在 `_ready()` 中连接以避免漏接信号
- 生产者和消费者不能形成循环依赖

### Requirements
- 必须支持所有23个跨系统信号
- 必须与 Godot 4.6 的 Autoload 系统兼容
- 不得产生循环信号依赖

## Decision

采用 **Events Autoload** 作为中央信号中继。所有跨系统信号通过 `Events.gd` 单例：

```gdscript
# Events.gd — Autoload singleton (extends Node)
# 纯中继，无业务逻辑。fire-and-forget。

signal rescue_input(player_id: int)
signal dodge_input(player_id: int)
signal sync_attack_detected()

signal attack_hit(attack_id: int, is_grounded: bool, hit_count: int)
signal attack_started(attack_type: String)
signal hit_confirmed(hitbox_id: int, hurtbox_id: int, attack_id: int)
signal hurt_received(damage: int, knockback: Vector2)

signal combo_hit(player_id: int, hit_count: int)
signal combo_tier_changed(tier: int, player_id: int)
signal sync_burst_triggered(position: Vector2)
signal combo_tier_escalated(tier: int, player_color: Color)

signal player_downed(player_id: int)
signal player_rescued(player_id: int, rescuer_color: Color)
signal crisis_state_changed(is_crisis: bool)
signal coop_bonus_active(multiplier: float)
signal solo_mode_active(player_id: int)

signal boss_attack_started(attack_pattern: String)
signal boss_phase_changed(new_phase: int)
signal boss_hp_changed(current: int, max: int)
signal boss_defeated(position: Vector2, boss_type: String)

signal camera_shake_intensity(trauma: float)
signal camera_zoom_changed(zoom: float)
signal camera_framed_players(positions: Array[Vector2])

signal arena_changed(arena_id: String, bounds: Dictionary)
```

### 路由规则

| 信号 | 路由 | 原因 |
|------|------|------|
| `hit_landed(attack_type, position, direction)` | **直接** CombatSystem → VFXManager | 高频低延迟命中通知；不经 Events 中继 |
| 所有其他23个信号 | Events Autoload 中继 | 标准路由 |

### 架构图

```
CombatSystem ──attack_started──► Events ──► CameraSystem
                                        └──► AnimationSystem

CollisionSystem ──attack_hit──► Events ──► CombatSystem
                                       └──► BossAI

ComboSystem ──combo_tier_changed──► Events ──► CameraSystem
                                          └──► VFXSystem
                                          └──► UI

CoopSystem ──player_downed──► Events ──► CameraSystem
                                      └──► VFXSystem
                                      └──► UI

CombatSystem ──hit_landed──► VFXManager  (直接，不经Events)
```

### 连接约定

```gdscript
# 生产者（CombatSystem 示例）
func _ready() -> void:
    # 直接信号（不经Events）
    VFXManager.hit_landed.connect(_on_hit_landed)
    # Events信号
    Events.attack_started.connect(_on_attack_started)

# 消费者（CameraSystem 示例）
func _ready() -> void:
    Events.attack_started.connect(_on_attack_started)
    Events.combo_tier_changed.connect(_on_combo_tier_changed)
    # ...
```

## Alternatives Considered

### Alternative 1: 直接节点引用
- **描述**: 系统持有 `Node` 引用直接互调
- **优点**: 无调度开销；直接方法调用
- **缺点**: 紧耦合；依赖节点存在性；难以单元测试；重构脆弱
- **拒绝理由**: 违反本项目的松耦合原则，与 GDD 中的信号架构设计不符

### Alternative 2: Hybrid（Events + 直接混合）
- **描述**: 游戏逻辑信号走 Events，VFX 直接连接 CombatSystem
- **优点**: VFX 获得低延迟直接信号
- **缺点**: 混合模式导致规则不清晰；后来者难以理解为何某些信号特殊
- **拒绝理由**: 本 ADR 已将 `hit_landed` 作为唯一例外（直接路由），无需全面混合模式

## Consequences

### Positive
- **松耦合**: 系统通过 Events 通信，不知道彼此存在
- **可观测性**: 信号可在调试器中观察，易于追踪数据流
- **易于扩展**: 新增消费者只需连接 Events，无需修改生产者
- **可测试性**: 可在单元测试中 Mock Events

### Negative
- **轻微调度开销**: 信号穿过额外一层（~1-2 CPU 周期，可忽略）
- **初始化依赖**: 消费者必须在 `_ready()` 中连接，否则漏接信号

### Risks
- **信号循环**: 生产者同时是消费者可能导致循环。**缓解**: GDD 依赖表已验证无循环
- **漏接信号**: 如果消费者在生产者发射信号之后才连接，会漏接。**缓解**: Godot 的 `_ready()` 在所有节点 `_ready()` 后才发射信号

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| 所有14个GDD | 跨系统通信 | Events 作为统一信号总线，所有23个信号 + 1个直接信号 |

## Performance Implications
- **CPU**: 极低 — 每次信号发射约 1-2 CPU 周期
- **Memory**: 极低 — Events 持有约 23 个 Signal 对象
- **Load Time**: 无影响
- **Network**: 不适用

## Migration Plan
1. 创建 `Events.gd` Autoload 单例
2. 将所有信号从直接节点引用迁移到 `Events.<signal>`
3. 所有消费者在 `_ready()` 中连接对应信号
4. VFXManager 添加对 CombatSystem 的 `hit_landed` 直接连接
5. 删除旧的直接引用

## Validation Criteria
- [ ] 帧更新路径中无直接节点引用跨系统通信（除 `hit_landed`）
- [ ] 所有消费者在 `_ready()` 中连接信号
- [ ] `hit_landed` 是唯一不经 Events 的信号
- [ ] 信号目录中23个信号全部在 Events.gd 中定义
- [ ] 无循环信号依赖

## Related Decisions
- ADR-ARCH-002: Collision Detection Area2D
- ADR-ARCH-003: Combat State Machine
- ADR-ARCH-004: Combo System
- ADR-ARCH-005: Coop System
- `docs/architecture/architecture.md` — 主架构文档（Phase 6 引用本 ADR）
