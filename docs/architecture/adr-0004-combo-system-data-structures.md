# ADR-ARCH-004: Combo System Data Structures & Tier Logic

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — 信号/Autoload API 在 Godot 4.4-4.6 无变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain变更) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-003 (Combat State Machine) |
| **Enables** | ADR-ARCH-005 (Coop System), UI系统, 粒子特效系统, Boss AI系统 |
| **Blocks** | 无 |
| **Ordering Note** | 本 ADR 依赖 combat-system.md 提供的 combo_hit 信号；Tier 阈值与 combo-system.md 保持一致 |

## Context

### Problem Statement
Combo 系统需要明确的数据结构设计：每玩家独立状态（连击数、窗口计时器、Tier等级、Sync链长度），以及 Tier 等级计算逻辑（0-4级阈值定义）。下游系统（UI、VFX、Boss AI、战斗系统）需要通过统一接口查询 Combo 状态。

### Requirements
- 每玩家独立 ComboData，互相不影响
- Tier 等级计算：0=IDLE, 1=Normal(1-9), 2=Rising(10-19), 3=Intense(20-39), 4=Overdrive(40+)
- Sync 检测：5帧窗口，3+连 SYNC 触发 Sync Burst
- 所有状态变更通过 Events 信号广播

## Decision

### 数据结构设计

采用**分离式 ComboData + TierLogic 类**方案：

```gdscript
# ComboData.gd — 每玩家独立状态容器
class_name ComboData
extends RefCounted

var player_id: int
var combo_count: int = 0          # 当前连击数
var combo_timer: float = 0.0      # 距上次命中的时间（秒）
var current_tier: int = 0         # 0=IDLE, 1=NORMAL, 2=RISING, 3=INTENSE, 4=OVERDRIVE
var sync_chain_length: int = 0    # 连续SYNC命中次数
var last_hit_frame: int = -1      # 上次命中帧号（用于SYNC检测）

func reset() -> void:
    combo_count = 0
    combo_timer = 0.0
    current_tier = 0
    sync_chain_length = 0
    last_hit_frame = -1
```

### TierLogic 类 — 等级计算与信号发射

```gdscript
# TierLogic.gd — 等级计算引擎
class_name TierLogic
extends RefCounted

const TIER_THRESHOLDS := {
    0: 0,    # IDLE
    1: 1,    # NORMAL (1-9)
    2: 10,   # RISING (10-19)
    3: 20,   # INTENSE (20-39)
    4: 40    # OVERDRIVE (40+)
}

const SYNC_WINDOW_FRAMES := 5
const SYNC_CHAIN_BURST_THRESHOLD := 3

static func calculate_tier(combo_count: int) -> int:
    if combo_count == 0:
        return 0  # IDLE
    if combo_count < 10:
        return 1  # NORMAL
    if combo_count < 20:
        return 2  # RISING
    if combo_count < 40:
        return 3  # INTENSE
    return 4      # OVERDRIVE

static func is_sync_hit(player_frame: int, partner_frame: int) -> bool:
    return abs(player_frame - partner_frame) <= SYNC_WINDOW_FRAMES

static func should_trigger_sync_burst(sync_chain_length: int) -> bool:
    return sync_chain_length >= SYNC_CHAIN_BURST_THRESHOLD
```

### ComboManager (Autoload) — 统一入口

```gdscript
# ComboManager.gd — Autoload singleton

const COMBO_WINDOW_DURATION := 1.5
const SYNC_WINDOW := 5  # frames
const SYNC_CHAIN_THRESHOLD := 3
const SOLO_MAX_MULTIPLIER := 3.0
const SYNC_MAX_MULTIPLIER := 4.0
const COMBO_DAMAGE_INCREMENT := 0.05

var _player_combo_data: Dictionary = {}  # player_id -> ComboData

func _ready() -> void:
    _player_combo_data[1] = ComboData.new(1)
    _player_combo_data[2] = ComboData.new(2)
    Events.combo_hit.connect(_on_combo_hit)

func _process(delta: float) -> void:
    for player_id in _player_combo_data:
        var data: ComboData = _player_combo_data[player_id]
        if data.combo_count > 0:
            data.combo_timer += delta
            if data.combo_timer >= COMBO_WINDOW_DURATION:
                _reset_combo(player_id)

func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
    # 由 CombatSystem 调用（经 Events 路由）
    # combo_count 是战斗系统传来的当前连击数
    player_id = _determine_player_id(attack_type)
    var data: ComboData = _player_combo_data[player_id]
    var prev_tier: int = data.current_tier

    data.combo_count = combo_count
    data.combo_timer = 0.0
    data.last_hit_frame = Engine.get_process_frames()

    var new_tier: int = TierLogic.calculate_tier(combo_count)
    if new_tier != prev_tier:
        data.current_tier = new_tier
        Events.combo_tier_changed.emit(new_tier, player_id)

    _evaluate_sync(player_id)

func _evaluate_sync(player_id: int) -> void:
    var data: ComboData = _player_combo_data[player_id]
    var partner_id: int = 3 - player_id  # 1<->2 转换
    var partner_data: ComboData = _player_combo_data.get(partner_id)

    if partner_data == null:
        return

    var is_sync: bool = TierLogic.is_sync_hit(data.last_hit_frame, partner_data.last_hit_frame)
    if is_sync:
        data.sync_chain_length += 1
        partner_data.sync_chain_length += 1
        if TierLogic.should_trigger_sync_burst(data.sync_chain_length):
            Events.sync_burst_triggered.emit(_get_boss_position())
    else:
        data.sync_chain_length = 0
        partner_data.sync_chain_length = 0

func _reset_combo(player_id: int) -> void:
    var data: ComboData = _player_combo_data[player_id]
    if data.combo_count > 0:
        Events.combo_break.emit(player_id)
    data.reset()

# ── 公开查询接口 ────────────────────────────────────────────

func get_combo_multiplier(player_id: int, is_sync: bool = false) -> float:
    var data: ComboData = _player_combo_data.get(player_id)
    if data == null or data.combo_count == 0:
        return 1.0
    var multiplier: float = 1.0 + data.combo_count * COMBO_DAMAGE_INCREMENT
    if is_sync:
        return mini(multiplier, SYNC_MAX_MULTIPLIER)
    return mini(multiplier, SOLO_MAX_MULTIPLIER)

func get_combo_tier(player_id: int) -> int:
    var data: ComboData = _player_combo_data.get(player_id)
    return data.current_tier if data else 0

func get_sync_chain_length(player_id: int) -> int:
    var data: ComboData = _player_combo_data.get(player_id)
    return data.sync_chain_length if data else 0
```

### 信号路由（与 architecture.yaml 一致）

| 信号 | 路由 | 说明 |
|------|------|------|
| `combo_hit` | CombatSystem → Events → ComboManager | 输入信号 |
| `combo_tier_changed(tier, player_id)` | ComboManager → Events → UI | 等级变化 |
| `sync_burst_triggered(position)` | ComboManager → Events → VFX | 触发同步爆发视觉 |
| `combo_break(player_id)` | ComboManager → Events → UI | 连击中断（仅视觉） |
| `combo_multiplier_updated(multiplier, player_id)` | ComboManager → CombatSystem | 伤害计算用 |

### Tier 阈值定义（与 combo-system.md 一致）

| Tier 值 | 名称 | 触发条件 | 视觉强度 |
|---------|------|---------|---------|
| 0 | IDLE | combo_count = 0 | 无 |
| 1 | Normal | 1–9 | 微妙脉冲，默认颜色 |
| 2 | Rising | 10–19 | 中度发光 +20% 亮度 |
| 3 | Intense | 20–39 | 重度发光 + 屏幕震动 +40% 亮度 |
| 4 | Overdrive | 40+ | 峰值效果（纸屑爆炸，全饱和） |

## Alternatives Considered

### Alternative 1: 集中式 ComboManager 内联管理
- **描述**: 所有逻辑放 ComboManager 内，Tier 计算直接内联在 `_on_combo_hit` 中
- **优点**: 简单，所有状态在一个类
- **缺点**: ComboManager 变得臃肿；难以单独测试 TierLogic
- **拒绝理由**: 违反单一职责，且下游系统（VFX）需要独立查询 sync_chain 状态

### Alternative 2: 纯值类型 + 函数式
- **描述**: 用 Dictionary 存状态，所有逻辑用独立函数
- **优点**: 无对象创建开销
- **缺点**: 无类型安全，难调试，GDScript 弱类型下维护成本高
- **拒绝理由**: 数据驱动游戏需要可读的类结构

## Consequences

### Positive
- **类型安全**: ComboData 和 TierLogic 是独立 class，有明确字段
- **可测试**: TierLogic 是静态方法，可直接单元测试
- **可扩展**: 新增玩家只需在 _ready 中创建 ComboData
- **职责分离**: 计时器逻辑在 ComboManager，Tier计算在 TierLogic

### Negative
- **RefCounted 对象创建**: ComboData 是 RefCounted，每次新建有轻微开销（但玩家只有2人，开销可忽略）

### Risks
- **Tier 阈值不同步**: 如果 combo-system.md 改了阈值但本 ADR 没改，会产生不一致。**缓解**: 阈值为常量，ADR 和 GDD 同时更新

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combo-system.md | Tier阈值定义（0-4级） | TierLogic.TIER_THRESHOLDS 常量精确定义 |
| combo-system.md | 每玩家独立combo_count | ComboData(player_id) 实例分离 |
| combo-system.md | SYNC窗口5帧，3连触发Burst | TierLogic.SYNC_WINDOW_FRAMES / SYNC_CHAIN_BURST_THRESHOLD |
| combo-system.md | 1.5秒窗口计时器 | ComboManager._process() 计时逻辑 |
| combo-system.md | get_combo_multiplier() 方法 | 公开接口返回 1.0–4.0 倍率 |
| ui-system.md | combo_tier_changed 信号 | Events 路由到 UI |
| particle-vfx-system.md | sync_burst_triggered 信号 | Events 路由到 VFX |

## Performance Implications
- **CPU**: _process 每帧遍历2个 ComboData，计时器更新约 0.001ms
- **Memory**: 2个 ComboData 实例，每个约 200 字节
- **Load Time**: 无影响

## Migration Plan
1. 创建 `ComboData.gd` — 每玩家状态容器
2. 创建 `TierLogic.gd` — 静态等级计算类
3. 创建 `ComboManager.gd` Autoload — 事件路由 + 计时器
4. 连接 `Events.combo_hit` 信号
5. 实现 `get_combo_multiplier()`, `get_combo_tier()`, `get_sync_chain_length()` 公开接口
6. 配置信号发射到 Events

## Validation Criteria
- [ ] 每玩家独立 combo_count，独立计时器
- [ ] Tier 计算正确：combo=0→0, 1-9→1, 10-19→2, 20-39→3, 40+→4
- [ ] SYNC 检测：5帧窗口内判定为 SYNC
- [ ] 3+ 连续 SYNC 触发 sync_burst_triggered
- [ ] get_combo_multiplier(1, false) 在 combo=40 时返回 3.0
- [ ] get_combo_multiplier(1, true) 在 combo=60 时返回 4.0

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-003: Combat State Machine — combo_hit 信号定义
- `docs/architecture/architecture.md`
