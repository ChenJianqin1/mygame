# ADR-ARCH-010: Animation System Architecture

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Animation |
| **Knowledge Risk** | MEDIUM — AnimationTree API 在 Godot 4.4-4.6 有变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (AnimationTree, AnimatedSprite2D) |
| **Post-Cutoff APIs Used** | `AnimationMixer.active` 替代废弃的 `playback_active` |
| **Verification Required** | AnimationMixer.active 行为需在 Godot 4.6 中验证 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-003 (Combat State Machine), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System), ADR-ARCH-006 (Boss AI) |
| **Enables** | VFX 系统（动画触发粒子），UI 系统（动画状态不影响） |
| **Blocks** | 无 |
| **Ordering Note** | 动画系统是纯消费者，由战斗/Combo/Coop/Boss AI 信号驱动；AnimationTree 用于同步攻击和相位过渡 |

## Context

### Problem Statement
动画系统需要将战斗信号、Boss AI 状态和玩家输入转换为角色动画表现。系统使用 AnimatedSprite2D + AnimationPlayer + AnimationTree 混合架构，支持帧锁 hitbox、可变速度分层和纸张质感。

### Requirements
- 玩家攻击动画：3-1-2 比例（anticipation/active/recovery）
- 帧锁 hitbox：动画关键帧控制 hitbox 激活时机
- Boss 动画状态机：Phase 1/2/3 + 僵硬感进阶
- AnimationTree 用于同步攻击和相位过渡
- Paper 质感分层：两层精灵 + noise shader 抖动

## Decision

### 玩家动画状态机

```
IDLE ──[attack]──► LIGHT_ATTACK ──[recovery end]──► IDLE
  │                    │
  │                    └──[HURT]──► HURT ──[end]──► IDLE
  │
  └──[hurt_received]──► HURT ──[end]──► IDLE
  └──[player_downed]──► DEFEAT ──[rescue]──► RESCUED ──[i-frames end]──► IDLE
```

### 玩家动画时序（60fps）

| 攻击类型 | anticipation | active | recovery | 总帧数 |
|----------|-------------|--------|----------|--------|
| LIGHT | 8帧 | 2帧 | 6帧 | 16帧 (~267ms) |
| MEDIUM | 14帧 | 3帧 | 10帧 | 27帧 (~450ms) |
| HEAVY | 20帧 | 4帧 | 16帧 | 40帧 (~667ms) |
| SPECIAL | 28帧 | 6帧 | 24帧 | 58帧 (~967ms) |

**anticipation = 输入锁定帧** — 该阶段无缓冲，不可中断。

### AnimationController 设计

```gdscript
# AnimationController.gd — 每个角色一个实例
class_name AnimationController
extends Node2D

## 动画组件
@export var animated_sprite: AnimatedSprite2D
@export var animation_player: AnimationPlayer
@export var animation_tree: AnimationTree

## 动画状态
enum PlayerAnimState { IDLE, MOVE, LIGHT_ATTACK, MEDIUM_ATTACK, HEAVY_ATTACK, SPECIAL_ATTACK, HURT, RESCUE, DEFEAT, RESCUED }
var _current_state: PlayerAnimState = PlayerAnimState.IDLE
var _attack_sub_phase: String = ""  # "anticipation" | "active" | "recovery"

## 帧锁 hitbox 回调
signal hitbox_active(attack_type: String)      # → CollisionManager
signal hitbox_deactivate()                    # → CollisionManager

## 速度分层
var _speed_scale: float = 0.5  # 默认 30fps 有效速率
const SPEED_SCALE_ACTIVE: float = 2.0  # 打击帧瞬间 120fps

func _ready() -> void:
    _connect_signals()
    animated_sprite.play("idle")
    animation_tree.active = true  # Godot 4.6: AnimationMixer.active

func _connect_signals() -> void:
    Events.attack_started.connect(_on_attack_started)
    Events.hurt_received.connect(_on_hurt_received)
    Events.sync_window_opened.connect(_on_sync_window_opened)
    Events.sync_burst_triggered.connect(_on_sync_burst_triggered)
    Events.combo_tier_escalated.connect(_on_combo_tier_escalated)
    Events.player_downed.connect(_on_player_downed)
    Events.rescue_triggered.connect(_on_rescue_triggered)
    Events.player_rescued.connect(_on_player_rescued)
    Events.player_out.connect(_on_player_out)

func _on_attack_started(attack_type: String, player_id: int) -> void:
    if player_id != _get_my_player_id():
        return
    # anticiption → active → recovery
    match attack_type:
        "LIGHT":   _transition_to(PlayerAnimState.LIGHT_ATTACK)
        "MEDIUM":  _transition_to(PlayerAnimState.MEDIUM_ATTACK)
        "HEAVY":   _transition_to(PlayerAnimState.HEAVY_ATTACK)
        "SPECIAL": _transition_to(PlayerAnimState.SPECIAL_ATTACK)

func _transition_to(new_state: PlayerAnimState) -> void:
    # 状态转换前：清理旧状态
    _exit_state(_current_state)
    _current_state = new_state
    _enter_state(new_state)

func _enter_state(state: PlayerAnimState) -> void:
    match state:
        PlayerAnimState.IDLE:
            animated_sprite.play("idle")
            _speed_scale = 0.5
        PlayerAnimState.MOVE:
            animated_sprite.play("move")
        PlayerAnimState.LIGHT_ATTACK:
            animated_sprite.play("attack_light")
            _attack_sub_phase = "anticipation"
            _speed_scale = 0.5
        PlayerAnimState.MEDIUM_ATTACK:
            animated_sprite.play("attack_medium")
            _attack_sub_phase = "anticipation"
            _speed_scale = 0.5
        PlayerAnimState.HEAVY_ATTACK:
            animated_sprite.play("attack_heavy")
            _attack_sub_phase = "anticipation"
            _speed_scale = 0.5
        PlayerAnimState.SPECIAL_ATTACK:
            animated_sprite.play("attack_special")
            _attack_sub_phase = "anticipation"
            _speed_scale = 0.5
        PlayerAnimState.HURT:
            animated_sprite.play("hurt")
            _speed_scale = 1.0  # 受创不慢动作
        PlayerAnimState.DEFEAT:
            animated_sprite.play("downtime_loop")
            _speed_scale = 0.3  # 慢动作倒地
        PlayerAnimState.RESCUED:
            animated_sprite.play("rescued_invincible")
            _speed_scale = 0.5

func _exit_state(state: PlayerAnimState) -> void:
    match state:
        PlayerAnimState.LIGHT_ATTACK, MEDIUM_ATTACK, HEAVY_ATTACK, SPECIAL_ATTACK:
            hitbox_deactivate.emit()

## 帧锁 hitbox — AnimationPlayer 轨道回调

func _on_animation_keyframe(keyframe: String) -> void:
    match keyframe:
        "hitbox_on":
            hitbox_active.emit(_current_attack_type)
        "hitbox_off":
            hitbox_deactivate.emit()
        "recovery_start":
            _attack_sub_phase = "recovery"
            _speed_scale = 0.5  # 恢复正常速度

## Boss 动画状态机

class_name BossAnimationController
extends Node2D

enum BossAnimState { IDLE, ATTACK_A, ATTACK_B, VULNERABLE, RAGE_ATTACK, PHASE_TRANS, CRISIS, DEFEAT }
var _current_state: BossAnimState = BossAnimState.IDLE
var _current_phase: int = 1

func _on_boss_attack_started(attack_pattern: String) -> void:
    match _current_phase:
        1:
            _transition_to(BossAnimState.ATTACK_A)
        2:
            if attack_pattern == "PAPER_AVALANCHE":
                _transition_to(BossAnimState.RAGE_ATTACK)
            else:
                _transition_to(BossAnimState.ATTACK_A)
        3:
            _transition_to(BossAnimState.CRISIS)

func _on_boss_phase_changed(new_phase: int) -> void:
    _current_phase = new_phase
    _transition_to(BossAnimState.PHASE_TRANS)

func _on_boss_defeated() -> void:
    _transition_to(BossAnimState.DEFEAT)

## 同步攻击包装器

func _on_sync_burst_triggered(position: Vector2) -> void:
    # 同步爆发：两个 AnimationController 接收信号
    # AnimationTree 应用 sync_burst blend
    animation_tree.set("parameters/sync_blend/add", 1.0)

func _on_sync_window_opened(player_id: int, partner_id: int) -> void:
    # P2 anticipation 阶段：添加"同步蓄力"光晕
    if _get_my_player_id() == partner_id:
        # 视觉增强：该攻击动画叠加 sync glow
        animation_tree.set("parameters/sync_glow/add", 0.5)
```

### 纸张质感分层

```
角色节点层级：
Character (Node2D)
├── PaperTextureLayer (Sprite2D, z_index +1, opacity 0.15)
├── MainSprite (AnimatedSprite2D, z_index 0)
└── VFXAnchor (Node2D, z_index +10)
```

Paper Texture 实现：独立 Sprite2D + noise shader，微抖动通过 UV offset 实现。

### AnimationTree blend 策略

| Blend 类型 | 用途 | 实现 |
|-----------|------|------|
| Attack blend | 任意攻击 → IDLE | AnimationNodeBlendSpace1D |
| Phase blend | Boss 相位过渡 | AnimationNodeTransition |
| Sync glow | 同步蓄力/爆发 | AnimationNodeAdd2 |
| Hurt override | HURT 中断一切 | AnimationNodeOneShot（优先级） |

### 信号路由

| 信号 | 来源 | 路由 | 动画响应 |
|------|------|------|---------|
| `attack_started` | CombatSystem → Events | Events → AnimationController | 进入对应攻击状态 |
| `hurt_received` | CombatSystem → Events | Events → AnimationController | HURT 中断 |
| `sync_window_opened` | ComboSystem → Events | Events → AnimationController | 同步蓄力光晕 |
| `sync_burst_triggered` | ComboSystem → Events | Events → AnimationController | 同步爆发 blend |
| `combo_tier_escalated` | ComboSystem → Events | Events → AnimationController | 动画强度变化 |
| `player_downed` | CoopSystem → Events | Events → AnimationController | DEFEAT |
| `rescue_triggered` | CoopSystem → Events | Events → AnimationController | RESCUE 动画 |
| `player_rescued` | CoopSystem → Events | Events → AnimationController | RESCUED |
| `player_out` | CoopSystem → Events | Events → AnimationController | 倒地结束 |
| `boss_attack_started` | BossAI → Events | Events → BossAnimController | Boss 攻击动画 |
| `boss_phase_changed` | BossAI → Events | Events → BossAnimController | Phase 过渡动画 |
| `boss_defeated` | BossAI → Events | Events → BossAnimController | Defeat 崩溃动画 |

### 帧锁 hitbox 机制

```
攻击动画帧轨道：
Frame 0-7:  anticipation — 无 hitbox
Frame 8-9:  active      — hitbox_on 关键帧
Frame 10-15: recovery   — 无 hitbox
```

AnimationPlayer 的 `animation_changed` 信号或 AnimationTree 的 blend 回调触发 `hitbox_active(attack_type)` → CollisionManager spawn_hitbox()。

## Alternatives Considered

### Alternative 1: 纯 AnimationPlayer（无 AnimationTree）
- **描述**: 所有动画状态用 AnimationPlayer 管理，不用 AnimationTree
- **优点**: 调试直观，艺术家友好
- **缺点**: 同步攻击和相位过渡需要手动状态管理
- **拒绝理由**: AnimationTree 的 blend 节点是同步和相位过渡的正确工具

### Alternative 2: 纯 Sprite 帧动画（无 AnimationPlayer）
- **描述**: 所有动画用 AnimatedSprite2D 的 sprite_frames 实现
- **优点**: 简单
- **缺点**: 无法精确控制 hitbox 帧同步
- **拒绝理由**: 帧锁 hitbox 需要精确的帧级控制

## Consequences

### Positive
- **帧锁 hitbox**: 动画师控制 hitbox 时机，无需程序员手动同步
- **AnimationTree blend**: 同步攻击和相位过渡平滑
- **速度分层**: 30fps 基础 + 120fps 打击帧创造 Looney Tunes 感

### Negative
- **多组件复杂度**: AnimatedSprite2D + AnimationPlayer + AnimationTree 三层需要协调
- **AnimationTree 调试**: blend 节点状态难追踪

### Risks
- **Godot 4.6 AnimationMixer.active**: `playback_active` 在 4.3+ 废弃。**缓解**: 使用 `animation_tree.active = true`
- **帧锁精度**: 如果动画帧率与物理帧率不同步，hitbox 可能偏移。**缓解**: hitbox 关键帧在 active 帧持有多帧

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| animation-system.md | 3-1-2 帧比例 | anticipation/active/recovery 阶段定义 |
| animation-system.md | 帧锁 hitbox | _on_animation_keyframe() → hitbox_active |
| animation-system.md | 速度分层 (0.5x / 2.0x) | _speed_scale 变量控制 |
| animation-system.md | 纸张质感分层 | PaperTextureLayer + MainSprite + noise shader |
| animation-system.md | HURT 中断一切 | _transition_to(HURT) 可从任意状态进入 |
| animation-system.md | 同步攻击视觉包装器 | AnimationTree sync_blend + _on_sync_burst_triggered |
| animation-system.md | 救援动画序列 | DEFEAT → RESCUE → RESCUED 状态机 |
| animation-system.md | Boss 僵硬感进阶 | BossAnimController._current_phase 控制动画风格 |
| animation-system.md | boss_defeated 崩溃 | BossAnimState.DEFEAT + 便签粒子 |
| animation-system.md | AnimationMixer.active | Godot 4.6 兼容 |

## Performance Implications
- **CPU**: 动画系统本身 < 0.1ms（无 GPU 开销）
- **Memory**: 每角色 AnimationTree ≈ 50KB
- **Load Time**: 动画资源预加载

## Migration Plan
1. 创建 `AnimationController.gd` 类
2. 配置 AnimatedSprite2D + AnimationPlayer + AnimationTree 节点结构
3. 实现玩家状态机（_transition_to）
4. 实现帧锁 hitbox 回调（_on_animation_keyframe）
5. 实现 AnimationTree blend 配置
6. 创建 `BossAnimationController.gd`
7. 连接 Events 信号
8. 实现 PaperTextureLayer + noise shader

## Validation Criteria
- [ ] LIGHT 攻击：anticipation 8帧后 active 2帧，hitbox 在 active 帧激活
- [ ] HURT 可从任意攻击状态的 anticipation 阶段中断
- [ ] DEFEAT 倒地动画循环 3 秒（匹配 rescue window）
- [ ] sync_burst_triggered 触发同步爆发视觉增强
- [ ] Boss Phase 3 动画比 Phase 1 更快速（更低 anticipation 帧）
- [ ] animation_tree.active = true 在 Godot 4.6 正常工作

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-003: Combat State Machine — attack_started 来源
- ADR-ARCH-004: Combo System — sync_burst_triggered
- ADR-ARCH-005: Coop System — player_downed/rescued
- ADR-ARCH-006: Boss AI — boss_phase_changed
- `docs/architecture/architecture.md`
