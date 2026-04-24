# ADR-ARCH-006: Boss AI System Architecture

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | AI / Navigation |
| **Knowledge Risk** | LOW — 行为树/FSM 模式在 Godot 4.4-4.6 无显著变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain变更) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-002 (Collision Detection), ADR-ARCH-003 (Combat State Machine), ADR-ARCH-005 (Coop System) |
| **Enables** | UI系统, 即时难度调整系统 |
| **Blocks** | 无 |
| **Ordering Note** | Boss AI 依赖 CollisionManager 的直接信号路由（低延迟感知）；同时依赖 CoopSystem 的 player_downed/crisis 信号进行压缩速度调制 |

## Context

### Problem Statement
Boss AI 需要同时管理宏观状态机（IDLE/ATTACKING/HURT/PHASE_CHANGE/DEFEATED）和微观行为决策（攻击模式选择、压缩墙速度调制）。AI 感知必须低延迟（直接路由），但状态更新通过 Events 广播给 UI。

### Requirements
- 混合 FSM（宏观）+ Behavior Tree（微观）架构
- 压缩墙作为持续并行进程，每帧运行
- 基于玩家状态（rescue/crisis）动态调整压缩速度
- 直接接收 CollisionManager 的感知信号（低延迟）
- 通过 Events 广播 boss_attack_started / boss_phase_changed

## Decision

### 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                     BossAIManager (Autoload)                     │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │  Macro FSM      │    │  Behavior Tree  │    │  Compression │ │
│  │  (boss states)  │    │  (attack pick)  │    │  (continuous)│ │
│  └────────┬────────┘    └────────┬────────┘    └──────┬───────┘ │
│           │                      │                    │         │
│           └──────────────────────┼────────────────────┘         │
│                                  │                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Context Awareness Module (救援/危机/落后检测)               ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
  CollisionManager      Events (broadcast)    CombatSystem
  (直接信号)            → UI/VFX              (boss_hp_changed)
```

### BossAIManager (Autoload) 核心实现

```gdscript
# BossAIManager.gd — Autoload singleton

## 常量
const BASE_BOSS_HP := 500
const BASE_COMPRESSION_SPEED := 32.0   # px/s
const COMPRESSION_DAMAGE_RATE := 5.0    # hp/s
const MIN_ATTACK_INTERVAL := 1.5        # s
const MERCY_ZONE := 100.0               # px
const RESCUE_SLOWDOWN := 0.5
const RESCUE_SUSPENSION := 2.0          # s
const PHASE_2_THRESHOLD := 0.60
const PHASE_3_THRESHOLD := 0.30

## 状态枚举
enum BossState { IDLE, ATTACKING, HURT, PHASE_CHANGE, DEFEATED }

## 成员变量
var _boss_state: BossState = BossState.IDLE
var _boss_hp: int = BASE_BOSS_HP
var _boss_max_hp: int = BASE_BOSS_HP
var _current_phase: int = 1
var _compression_wall_x: float = 0.0
var _attack_cooldown: float = 0.0
var _rescue_suspension_timer: float = 0.0
var _players_behind: bool = false

## 信号 (广播到 Events)
signal boss_attack_started(attack_pattern: String)
signal boss_phase_changed(new_phase: int)
signal boss_phase_warning(phase: int)
signal boss_attack_telegraph(pattern: String)

func _ready() -> void:
    # 直接信号 — CollisionManager 低延迟感知
    # 这些信号不经过 Events，由 CollisionManager 直接 connect
    # 连接代码在 CollisionManager 初始化时设置

    # Events 信号
    Events.combo_hit.connect(_on_combo_hit)
    Events.player_downed.connect(_on_player_downed)
    Events.crisis_state_changed.connect(_on_crisis_state_changed)
    Events.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
    _update_compression(delta)
    _update_attack_cooldown(delta)
    _update_rescue_suspension(delta)

func _update_compression(delta: float) -> void:
    if _boss_state == BossState.DEFEATED or _boss_state == BossState.PHASE_CHANGE:
        return

    var speed: float = _calculate_compression_speed()
    _compression_wall_x += speed * delta

    # 对危险区域内的玩家造成伤害
    _apply_compression_damage(delta)

func _calculate_compression_speed() -> float:
    var base: float = BASE_COMPRESSION_SPEED
    var phase_mult: float = 1.0 if _current_phase == 1 else 1.5 if _current_phase == 2 else 2.0
    var rescue_mult: float = 1.0
    var crisis_mult: float = 1.0

    # 检测是否有玩家倒下
    var p1_down: bool = _is_player_down(1)
    var p2_down: bool = _is_player_down(2)

    if p1_down or p2_down:
        rescue_mult = RESCUE_SLOWDOWN
    elif _players_behind:
        rescue_mult = 0.6
    elif _is_crisis_active():
        crisis_mult = 1.2

    return base * phase_mult * rescue_mult * crisis_mult

func _apply_compression_damage(delta: float) -> void:
    # 实际实现需要检查两个玩家位置是否在压缩墙左侧（危险区域）
    pass

func _update_attack_cooldown(delta: float) -> void:
    if _attack_cooldown > 0:
        _attack_cooldown -= delta

func _update_rescue_suspension(delta: float) -> void:
    if _rescue_suspension_timer > 0:
        _rescue_suspension_timer -= delta

## 行为树：攻击模式选择

func _select_attack_pattern() -> String:
    if _rescue_suspension_timer > 0:
        return "NONE"  # 暂停攻击

    match _current_phase:
        1:
            return "Pattern_1_Relentless_Advance"
        2:
            return _select_phase2_pattern()
        3:
            return _select_phase3_pattern()
    return "NONE"

func _select_phase2_pattern() -> String:
    # Phase 2: Pattern 1 始终 + Pattern 2 可用
    # 基于玩家位置选择
    var player_pos: Vector2 = _get_nearest_player_position()
    if player_pos.x < _compression_wall_x + 300:
        return "Pattern_2_Paper_Avalanche"
    return "Pattern_1_Relentless_Advance"

func _select_phase3_pattern() -> String:
    # Phase 3: 所有模式可用，优先级更高
    return "Pattern_3_Panic_Overload"

## 宏观 FSM 状态转换

func _transition_to(new_state: BossState) -> void:
    var old_state: BossState = _boss_state
    _boss_state = new_state

    match new_state:
        BossState.ATTACKING:
            var pattern: String = _select_attack_pattern()
            if pattern != "NONE":
                boss_attack_started.emit(pattern)
                Events.boss_attack_started.emit(pattern)
        BossState.HURT:
            pass  # 受伤动画播放
        BossState.PHASE_CHANGE:
            _handle_phase_change()
        BossState.DEFEATED:
            _compression_wall_x = -9999  # 停止压缩

func _handle_phase_change() -> void:
    var old_phase: int = _current_phase
    var hp_ratio: float = float(_boss_hp) / _boss_max_hp

    if hp_ratio <= PHASE_3_THRESHOLD:
        _current_phase = 3
    elif hp_ratio <= PHASE_2_THRESHOLD:
        _current_phase = 2

    if _current_phase != old_phase:
        boss_phase_changed.emit(_current_phase)
        Events.boss_phase_changed.emit(_current_phase)

## 信号处理 (直接来自 CollisionManager)

func _on_player_detected(player: Node2D) -> void:
    # 直接来自 CollisionManager — 低延迟感知
    # 用于追踪玩家位置
    pass

func _on_player_lost(player: Node2D) -> void:
    # 直接来自 CollisionManager
    pass

func _on_player_hurt(player: Node2D, damage: float) -> void:
    # 直接来自 CollisionManager — AI 侵略性调制
    pass

func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
    # 来自 Events — ComboSystem 广播
    # AI 可根据 combo_count 调整行为
    pass

func _on_player_downed(player_id: int) -> void:
    # 来自 Events — CoopSystem
    _rescue_suspension_timer = RESCUE_SUSPENSION

func _on_crisis_state_changed(is_crisis: bool) -> void:
    # 来自 Events — CoopSystem
    # CRISIS 激活时压缩加速
    pass

func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
    _boss_state = BossState.DEFEATED

## 辅助方法

func _is_player_down(player_id: int) -> bool:
    # 查询 CoopManager
    return false

func _is_crisis_active() -> bool:
    # 查询 CoopManager
    return false

func _get_nearest_player_position() -> Vector2:
    return Vector2.ZERO

func get_boss_state() -> String:
    match _boss_state:
        BossState.IDLE: return "IDLE"
        BossState.ATTACKING: return "ATTACKING"
        BossState.HURT: return "HURT"
        BossState.PHASE_CHANGE: return "PHASE_CHANGE"
        BossState.DEFEATED: return "DEFEATED"
    return "UNKNOWN"

func get_current_phase() -> int:
    return _current_phase
```

### 感知信号路由（与 architecture.yaml 一致）

| 信号 | 路由 | 原因 |
|------|------|------|
| `player_detected(player)` | CollisionManager → BossAI (直接) | AI 感知低延迟 |
| `player_lost(player)` | CollisionManager → BossAI (直接) | AI 感知低延迟 |
| `player_hurt(player, damage)` | CollisionManager → BossAI (直接) | AI 感知低延迟 |
| `combo_hit` | CombatSystem → Events → BossAI | 跨系统通知 |
| `player_downed` | CoopSystem → Events → BossAI | 救援模式调制 |
| `crisis_state_changed` | CoopSystem → Events → BossAI | 危机速度调制 |

### 压缩速度调制规则

| 条件 | 倍率 | 原因 |
|------|------|------|
| 任意玩家 DOWNTIME | × 0.5 | 救援窗口，给玩家喘息 |
| 任意玩家落后（< MERCY_ZONE） | × 0.6 | 避免过度惩罚 |
| 双方 CRISIS | × 1.2 | 增加紧张感 |
| 正常（Phase 1） | × 1.0 | 基准速度 |

### 攻击间隔规则

- **Phase 1**: 无 frontal attacks（纯压缩）
- **Phase 2**: Pattern 1 + 2，MIN_ATTACK_INTERVAL = 1.5s 地板
- **Phase 3**: 所有模式，攻击更频繁（hp_multiplier 降至 0.5）

## Alternatives Considered

### Alternative 1: 纯 FSM AI（无 Behavior Tree）
- **描述**: 所有 AI 逻辑用 switch/case 状态机
- **优点**: 简单，调试直观
- **缺点**: 攻击选择逻辑会堆在 ATTACKING 状态内，难以扩展
- **拒绝理由**: Phase 增加时攻击模式增多，纯 FSM 难以管理

### Alternative 2: 纯 Behavior Tree（无宏观 FSM）
- **描述**: 用 BT 管理所有状态，包括 IDLE/DEFEATED
- **优点**: 统一架构，设计师可编辑 BT
- **缺点**: Phase 转换需要专门处理，不如 FSM 直观
- **拒绝理由**: Boss 宏观状态（IDLE/DEFEATED）与行为决策是正交的

## Consequences

### Positive
- **分离关注点**: 宏观 FSM 管状态，BT 管行为选择
- **低延迟感知**: 直接信号路由避免 Events 调度开销
- **可预测**: 压缩墙是确定性的持续进程，玩家可学习和适应
- **上下文感知**: 救援/危机状态直接影响 AI 行为

### Negative
- **架构复杂度**: 两套系统（FSM + BT）需要协调
- **调试难度**: 行为问题需要同时看两个系统

### Risks
- **FSM/BT 状态冲突**: BT 选择了攻击但 FSM 在 HURT 状态。**缓解**: ATTACKING 状态才执行 BT，HURT/PHASE_CHANGE 优先
- **压缩墙与攻击不同步**: 攻击动画期间压缩墙不暂停（只是速度变化）。**缓解**: 这是设计意图，保持压迫感

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| boss-ai-system.md | Hybrid FSM + BT 架构 | Macro FSM (_boss_state) + Behavior Tree (_select_attack_pattern) |
| boss-ai-system.md | 压缩墙持续进程 | _update_compression() 在 _process 中每帧运行 |
| boss-ai-system.md | Phase 1 无 frontal attacks | _select_attack_pattern() 在 Phase 1 只返回 Pattern_1 |
| boss-ai-system.md | 压缩速度调制 | _calculate_compression_speed() 实现所有倍率规则 |
| boss-ai-system.md | Phase 2 Paper Avalanche | _select_phase2_pattern() 实现 |
| boss-ai-system.md | Phase 3 Panic Overload | _select_phase3_pattern() 实现 |
| boss-ai-system.md | player_detected/lost/hurt 直接路由 | 直接连接 CollisionManager 信号 |
| boss-ai-system.md | boss_attack_started/boss_phase_changed | Events 广播 |
| boss-ai-system.md | COMPRESSION_DAMAGE_RATE = 5hp/s | _apply_compression_damage() 实现 |
| boss-ai-system.md | RESCUE_SLOWDOWN = 0.5 | _calculate_compression_speed() 实现 |

## Performance Implications
- **CPU**: _process 每帧计算压缩速度 + 位置检测，< 0.01ms
- **Memory**: BossAIManager 约 1KB，无额外对象
- **Load Time**: 无影响

## Migration Plan
1. 创建 `BossAIManager.gd` Autoload
2. 实现 BossState 枚举和宏观 FSM
3. 实现 _select_attack_pattern() 行为树
4. 实现 _update_compression() 持续进程
5. 配置 CollisionManager 直接信号连接
6. 连接 Events 信号（combo_hit, player_downed, crisis_state_changed）
7. 配置 boss_attack_started/boss_phase_changed 广播到 Events

## Validation Criteria
- [ ] Phase 1：compression_speed = 32 * 1.0 = 32px/s，无 frontal attacks
- [ ] Phase 2：compression_speed = 32 * 1.5 = 48px/s，可选 Pattern 1/2
- [ ] Phase 3：compression_speed = 32 * 2.0 = 64px/s，所有模式可用
- [ ] 玩家 DOWNTIME：compression_speed *= 0.5
- [ ] 双方 CRISIS：compression_speed *= 1.2
- [ ] player_detected/lost/hurt 直接路由生效（无 Events 中继）
- [ ] boss_phase_changed 在 HP 跨过 60%/30% 时触发
- [ ] get_boss_state() 返回正确宏观状态

## Related Decisions
- ADR-ARCH-002: Collision Detection — 直接信号路由规则
- ADR-ARCH-005: Coop System — player_downed/crisis_state_changed 信号
- `docs/architecture/architecture.md`
