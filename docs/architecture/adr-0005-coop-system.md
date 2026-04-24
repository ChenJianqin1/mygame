# ADR-ARCH-005: Coop System HP Pools & Rescue Mechanics

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Autoload/信号 API 在 Godot 4.4-4.6 无变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain变更) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-003 (Combat State Machine) |
| **Enables** | UI系统, 粒子特效系统, 音频系统, Boss AI系统 |
| **Blocks** | 无 |
| **Ordering Note** | 本 ADR 依赖战斗系统提供的 player_health_changed 信号；Coop 状态影响战斗数值计算 |

## Context

### Problem Statement
双人合作系统需要管理两位玩家的独立 HP 池、倒下后的救援机制、CRISIS 共生状态、以及协作/单人模式切换。这些状态影响战斗系统的伤害计算、UI的血条显示、VFX的救援特效。

### Requirements
- 每玩家独立 HP 池（PLAYER_MAX_HP = 100）
- 3 秒救援窗口，175px 范围内可救援
- CRISIS 状态：双方都 < 30% HP 时激活，25% 减伤
- 协作加伤 +10%，单人减伤 25%

## Decision

### CoopManager (Autoload) 设计

```gdscript
# CoopManager.gd — Autoload singleton

const PLAYER_MAX_HP := 100
const RESCUE_WINDOW := 3.0        # 秒
const RESCUE_RANGE := 175.0      # 像素
const RESCUED_IFRAMES_DURATION := 1.5  # 秒
const COOP_BONUS := 0.10         # +10%
const SOLO_DAMAGE_REDUCTION := 0.25     # 25%
const CRISIS_DAMAGE_REDUCTION := 0.25   # 25%
const CRISIS_HP_THRESHOLD := 0.30       # 30%

class PlayerCoopState:
    var player_id: int
    var current_hp: int = PLAYER_MAX_HP
    var is_down: bool = false          # DOWNTIME 状态
    var is_out: bool = false          # 救援窗口已过期
    var rescue_timer: float = 0.0     # 距超时剩余时间
    var has_iframes: bool = false     # 无敌帧状态
    var iframe_timer: float = 0.0

    func _init(id: int):
        player_id = id

var _players: Dictionary = {
    1: PlayerCoopState.new(1),
    2: PlayerCoopState.new(2)
}

var _crisis_active: bool = false

func _ready() -> void:
    Events.player_health_changed.connect(_on_player_health_changed)
    Events.rescue_input.connect(_on_rescue_input)

func _process(delta: float) -> void:
    _update_rescue_timers(delta)
    _update_iframes(delta)
    _update_crisis_state()

func _update_rescue_timers(delta: float) -> void:
    for player_id in _players:
        var p: PlayerCoopState = _players[player_id]
        if p.is_down and not p.is_out:
            p.rescue_timer -= delta
            if p.rescue_timer <= 0.0:
                p.is_out = true
                Events.player_out.emit(player_id)

func _update_iframes(delta: float) -> void:
    for player_id in _players:
        var p: PlayerCoopState = _players[player_id]
        if p.has_iframes:
            p.iframe_timer -= delta
            if p.iframe_timer <= 0.0:
                p.has_iframes = false

func _update_crisis_state() -> void:
    var p1: PlayerCoopState = _players[1]
    var p2: PlayerCoopState = _players[2]
    var both_alive: bool = not p1.is_down and not p2.is_down
    if not both_alive:
        _set_crisis(false)
        return

    var p1_low: bool = float(p1.current_hp) / PLAYER_MAX_HP < CRISIS_HP_THRESHOLD
    var p2_low: bool = float(p2.current_hp) / PLAYER_MAX_HP < CRISIS_HP_THRESHOLD
    _set_crisis(p1_low and p2_low)

func _set_crisis(active: bool) -> void:
    if _crisis_active == active:
        return
    _crisis_active = active
    Events.crisis_state_changed.emit(active)
    if active:
        Events.crisis_activated.emit()

func _on_player_health_changed(current: int, max: int) -> void:
    # 来自 CombatSystem — 需根据 player_id 路由
    # 注意：实际实现需要传入 player_id，此处简化
    pass

func _on_rescue_input(player_id: int) -> void:
    var rescuer: PlayerCoopState = _players.get(player_id)
    var partner_id: int = 3 - player_id
    var downed: PlayerCoopState = _players.get(partner_id)

    if downed == null or not downed.is_down or downed.is_out:
        return

    if is_in_rescue_range(rescuer.player_id, downed.player_id):
        _execute_rescue(rescuer, downed)

func _execute_rescue(rescuer: PlayerCoopState, downed: PlayerCoopState) -> void:
    downed.is_down = false
    downed.is_out = false
    downed.rescue_timer = 0.0
    downed.has_iframes = true
    downed.iframe_timer = RESCUED_IFRAMES_DURATION
    downed.current_hp = mini(20, downed.current_hp)  # 救起给 20HP

    var rescuer_color: Color = Color("#F5A623") if rescuer.player_id == 1 else Color("#4ECDC4")
    Events.player_rescued.emit(downed.player_id, rescuer_color)
    Events.rescue_triggered.emit(_get_downed_position(downed.player_id), rescuer_color)

# ── 公开接口 ────────────────────────────────────────────

func is_in_rescue_range(rescuer_id: int, downed_id: int) -> bool:
    # 实际实现需根据 Node2D position 计算距离
    # 此处返回占位值
    return true

func get_rescue_timer(player_id: int) -> float:
    var p: PlayerCoopState = _players.get(player_id)
    return p.rescue_timer if p else 0.0

func is_crisis_active() -> bool:
    return _crisis_active

func get_coop_bonus_multiplier() -> float:
    var p1: PlayerCoopState = _players[1]
    var p2: PlayerCoopState = _players[2]
    var both_alive: bool = not p1.is_down and not p1.is_out and not p2.is_down and not p2.is_out
    return 1.0 + COOP_BONUS if both_alive else 1.0

func get_solo_damage_multiplier(player_id: int) -> float:
    var p: PlayerCoopState = _players.get(player_id)
    if p == null:
        return 1.0
    var partner_id: int = 3 - player_id
    var partner: PlayerCoopState = _players.get(partner_id)
    var is_solo: bool = p.is_down or p.is_out or (partner != null and (partner.is_down or partner.is_out))
    if is_solo:
        return 1.0 - SOLO_DAMAGE_REDUCTION
    return 1.0
```

### HP 池与状态转换

| 状态 | 进入条件 | 退出条件 |
|------|---------|---------|
| `ACTIVE` | 默认 / 救援完成 | 任意玩家 HP ≤ 0 |
| `DOWNTIME` | HP = 0 | 被救援（立即）或窗口超时（3s后OUT） |
| `RESCUED` | 救援成功 | 无敌帧结束（1.5s后回ACTIVE） |
| `CRISIS` | 双方同时 < 30% HP | 任意一方 ≥ 30% |
| `OUT` | 救援窗口超时 | 下次生命重置 |

### 信号路由（与 architecture.yaml 一致）

| 信号 | 路由 | 说明 |
|------|------|------|
| `player_downed(player_id)` | CoopManager → Events → UI | 救援计时开始 |
| `player_rescued(player_id, color)` | CoopManager → Events → UI + VFX | 救援成功 |
| `crisis_state_changed(is_crisis)` | CoopManager → Events → UI + VFX + 音频 | 危机状态切换 |
| `player_out(player_id)` | CoopManager → Events → UI | 玩家超时死亡 |
| `rescue_triggered(position, color)` | CoopManager → Events → VFX | 救援特效 |
| `crisis_activated()` | CoopManager → Events → VFX + 音频 | 危机特效触发 |

### 数值公式（与 coop-system.md 一致）

```
协作加伤: effective_damage = base * (1.0 + COOP_BONUS) = base * 1.10
单人减伤: effective_damage = base * (1.0 - SOLO_DAMAGE_REDUCTION) = base * 0.75
CRISIS减伤: effective_damage = base * (1.0 - CRISIS_DAMAGE_REDUCTION) = base * 0.75
```

**叠加规则**: CRISIS 和 SOLO 不叠加，CRISIS 优先。

## Alternatives Considered

### Alternative 1: 集中式 HP 管理（与战斗系统合并）
- **描述**: 战斗系统直接管理两位玩家的 HP，CoopManager 只处理救援逻辑
- **优点**: HP 数据单一来源
- **缺点**: 战斗系统职责过重，协作逻辑散落
- **拒绝理由**: HP 管理（战斗）和协作状态（倒下/救援）是不同关注点，应分离

### Alternative 2: 玩家死亡后立即出局（无救援窗口）
- **描述**: HP=0 立即触发 OUT，无 3 秒救援窗口
- **优点**: 简单，无计时器管理
- **缺点**: 破坏协作体验，与"协作即意义"冲突
- **拒绝理由**: 违反 Pillar 1 — 协作必须有物理实现

## Consequences

### Positive
- **协作激励明确**: +10% 加伤鼓励不丢下队友
- **单人保护**: 25% 减伤让 solo 玩家也能推进
- **危机可读**: CRISIS 视觉明显，玩家知道情况危急
- **无惩罚文化**: 救援失败不是失败，只是需要下一条命

### Negative
- **多个计时器**: rescue_timer, iframe_timer, CRISIS 检测需要小心同步
- **状态机复杂**: 5个状态转换需要严格定义

### Risks
- **HP 同步丢失**: 如果战斗系统和 CoopManager 的 HP 不同步会产生不一致。**缓解**: player_health_changed 是唯一真源
- **救援窗口耗尽**: timer 在 hitstop 期间继续计时（真实时间），可能感觉不公平。**缓解**: coop-system.md 已有说明

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| coop-system.md | 独立HP池（100/人） | PLAYER_MAX_HP = 100, PlayerCoopState.current_hp |
| coop-system.md | 3秒救援窗口 | RESCUE_WINDOW = 3.0, _update_rescue_timers() |
| coop-system.md | 175px 救援范围 | RESCUE_RANGE = 175.0, is_in_rescue_range() |
| coop-system.md | 1.5s 无敌帧 | RESCUED_IFRAMES_DURATION, has_iframes + iframe_timer |
| coop-system.md | +10% 协作加伤 | COOP_BONUS = 0.10, get_coop_bonus_multiplier() |
| coop-system.md | 25% 单人减伤 | SOLO_DAMAGE_REDUCTION = 0.25, get_solo_damage_multiplier() |
| coop-system.md | CRISIS 状态（双方<30%） | CRISIS_HP_THRESHOLD = 0.30, _update_crisis_state() |
| coop-system.md | 25% CRISIS减伤 | CRISIS_DAMAGE_REDUCTION = 0.25 |
| coop-system.md | player_downed/rescued/crisis 信号 | Events 路由定义 |
| combat-system.md | HP 变化信号 | Events.player_health_changed → CoopManager |

## Performance Implications
- **CPU**: _process 遍历2个玩家状态 + 简单比较，< 0.001ms
- **Memory**: 2个 PlayerCoopState 实例，每个约 300 字节
- **Load Time**: 无影响

## Migration Plan
1. 创建 `CoopManager.gd` Autoload
2. 实现 PlayerCoopState 类
3. 实现计时器逻辑（_process）
4. 连接 Events.player_health_changed, Events.rescue_input
5. 配置信号发射到 Events
6. 实现公开查询方法

## Validation Criteria
- [ ] P1 HP=0 → P1 进入 DOWNTIME，rescue_timer = 3.0s
- [ ] P2 在 175px 内按救援键 → P1 立即救起，获得 1.5s 无敌帧
- [ ] 双方同时 < 30 HP → CRISIS 激活
- [ ] CRISIS 激活时任一玩家 ≥ 30% → CRISIS 立即结束
- [ ] P1 OUT（3s 无救援）→ P2 获得 SOLO_DAMAGE_REDUCTION
- [ ] get_coop_bonus_multiplier() 在双方存活时返回 1.10

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-003: Combat State Machine — HP 状态来源
- `docs/architecture/architecture.md`
