# ADR-ARCH-009: UI System Architecture

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Presentation |
| **Knowledge Risk** | LOW — Control nodes / CanvasLayer API 在 Godot 4.4-4.6 无显著变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain变更) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System), ADR-ARCH-006 (Boss AI), ADR-ARCH-007 (Camera System) |
| **Enables** | 输入系统（pause/input 触发 UI 状态） |
| **Blocks** | 无 |
| **Ordering Note** | UI 是纯消费者系统，不影响游戏逻辑；需要从所有 Core 系统订阅信号 |

## Context

### Problem Statement
UI 系统需要将游戏状态（HP、连击、救援、Boss 相位）转换为可读视觉反馈。所有 UI 组件使用 CanvasLayer 独立于游戏世界渲染，订阅 Events 信号驱动更新，无轮询。

### Requirements
- 8 种 UI 组件类型，全部使用 paper/hand-painted 美学
- 全信号驱动更新，无游戏状态轮询
- CanvasLayer 独立渲染，屏幕空间元素不受相机运动影响
- 5 个屏幕状态：TITLE / BOSS_INTRO / GAMEPLAY_HUD / PAUSED / GAME_OVER

## Decision

### UIManager (Autoload) 设计

```gdscript
# UIManager.gd — Autoload singleton

## 屏幕状态
enum ScreenState { TITLE, BOSS_INTRO, GAMEPLAY_HUD, PAUSED, GAME_OVER }
var _current_screen: ScreenState = ScreenState.TITLE

## UI 组件引用（场景加载后初始化）
var _player_hp_bar_p1: Control
var _player_hp_bar_p2: Control
var _boss_hp_bar: Control
var _combo_counter_p1: Control
var _combo_counter_p2: Control
var _sync_chain_indicator: Control
var _coop_bonus_p1: Control
var _coop_bonus_p2: Control
var _rescue_timer: Control
var _crisis_edge_glow: Control
var _pause_menu: Control
var _game_over_screen: Control
var _boss_intro_screen: Control

## 颜色定义
const COLOR_P1 := Color("#F5A623")   # 晨曦橙
const COLOR_P2 := Color("#4ECDC4")    # 梦境蓝
const COLOR_GOLD := Color("#FFD700")  # 打勾金
const COLOR_CRISIS := Color("#7F96A6")  # 危机混合色

## 连击 Tier 缩放
const TIER_SCALES: Dictionary = {
    0: 1.0,
    1: 1.0,
    2: 1.15,
    3: 1.30,
    4: 1.50
}

func _ready() -> void:
    _connect_all_signals()
    _set_screen_state(ScreenState.TITLE)

func _connect_all_signals() -> void:
    # Combo 系统
    Events.combo_tier_changed.connect(_on_combo_tier_changed)
    Events.sync_chain_active.connect(_on_sync_chain_active)
    Events.combo_break.connect(_on_combo_break)
    Events.combo_hit.connect(_on_combo_hit)

    # Coop 系统
    Events.player_downed.connect(_on_player_downed)
    Events.player_rescued.connect(_on_player_rescued)
    Events.crisis_state_changed.connect(_on_crisis_state_changed)
    Events.player_out.connect(_on_player_out)
    Events.coop_bonus_active.connect(_on_coop_bonus_active)

    # Boss AI 系统
    Events.boss_phase_changed.connect(_on_boss_phase_changed)
    Events.boss_phase_warning.connect(_on_boss_phase_warning)
    Events.boss_attack_telegraph.connect(_on_boss_attack_telegraph)
    Events.boss_defeated.connect(_on_boss_defeated)

    # 战斗系统
    Events.player_health_changed.connect(_on_player_health_changed)

    # Camera 系统
    Events.camera_zoom_changed.connect(_on_camera_zoom_changed)

    # Input 系统（直接）
    # UIManager 订阅 input-ready 状态，用于 pause 菜单

## 屏幕状态切换

func _set_screen_state(new_state: ScreenState) -> void:
    _current_screen = new_state
    _update_all_component_visibility()

func _update_all_component_visibility() -> void:
    var hud_visible: bool = (_current_screen == ScreenState.GAMEPLAY_HUD)
    var pause_visible: bool = (_current_screen == ScreenState.PAUSED)
    var gameover_visible: bool = (_current_screen == ScreenState.GAME_OVER)
    var intro_visible: bool = (_current_screen == ScreenState.BOSS_INTRO)

    _set_visible(_boss_hp_bar, hud_visible)
    _set_visible(_player_hp_bar_p1, hud_visible)
    _set_visible(_player_hp_bar_p2, hud_visible)
    _set_visible(_combo_counter_p1, hud_visible)
    _set_visible(_combo_counter_p2, hud_visible)
    _set_visible(_sync_chain_indicator, hud_visible)
    _set_visible(_coop_bonus_p1, hud_visible)
    _set_visible(_coop_bonus_p2, hud_visible)
    _set_visible(_rescue_timer, hud_visible and _rescue_timer.get_meta("active", false))
    _set_visible(_crisis_edge_glow, hud_visible)
    _set_visible(_pause_menu, pause_visible)
    _set_visible(_game_over_screen, gameover_visible)
    _set_visible(_boss_intro_screen, intro_visible)

func _set_visible(node: Control, visible: bool) -> void:
    if node != null:
        node.visible = visible

## 信号处理

func _on_combo_tier_changed(tier: int, player_id: int) -> void:
    var counter: Control = _combo_counter_p1 if player_id == 1 else _combo_counter_p2
    if counter != null:
        var scale: float = TIER_SCALES.get(tier, 1.0)
        _apply_counter_scale(counter, scale)
        _apply_counter_color(counter, tier, player_id)

func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
    # 更新连击计数器显示
    pass

func _on_sync_chain_active(chain_length: int) -> void:
    if _sync_chain_indicator != null:
        _update_sync_chain_icons(chain_length)

func _on_combo_break(player_id: int) -> void:
    var counter: Control = _combo_counter_p1 if player_id == 1 else _combo_counter_p2
    if counter != null:
        _trigger_flutter_animation(counter)

func _on_player_downed(player_id: int) -> void:
    if _rescue_timer != null:
        _rescue_timer.set_meta("active", true)
        _rescue_timer.visible = true
        # 径向倒计时动画
        _start_rescue_timer(player_id)

func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
    if _rescue_timer != null:
        _rescue_timer.set_meta("active", false)
        _trigger_rescue_sparkle(rescuer_color)
        await get_tree().create_timer(0.5).timeout
        _rescue_timer.visible = false

func _on_crisis_state_changed(is_crisis: bool) -> void:
    if _crisis_edge_glow != null:
        _crisis_edge_glow.visible = is_crisis
        if is_crisis:
            _start_crisis_pulse()

func _on_player_out(player_id: int) -> void:
    if _rescue_timer != null:
        _rescue_timer.visible = false
    # 显示 ghost 图标
    _show_ghost_icon(player_id)

func _on_coop_bonus_active(multiplier: float) -> void:
    var bonus_active: bool = (multiplier > 1.0)
    if _coop_bonus_p1 != null:
        _coop_bonus_p1.visible = bonus_active
    if _coop_bonus_p2 != null:
        _coop_bonus_p2.visible = bonus_active

func _on_boss_phase_changed(new_phase: int) -> void:
    if _boss_hp_bar != null:
        _update_boss_hp_bar_phase(new_phase)

func _on_boss_phase_warning(phase: int) -> void:
    _show_phase_warning(phase)

func _on_boss_attack_telegraph(pattern: String) -> void:
    _show_attack_telegraph(pattern)

func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
    # Boss 死亡动画后切换到结算
    pass

func _on_player_health_changed(current: int, max: int) -> void:
    # 更新 HP 条显示（平滑插值）
    pass

func _on_camera_zoom_changed(zoom: Vector2) -> void:
    # UI 元素不随相机缩放（CanvasLayer 独立）
    pass

## UI 组件操作

func _apply_counter_scale(counter: Control, target_scale: float) -> void:
    var tween := create_tween()
    tween.tween_property(counter, "scale", Vector2(target_scale, target_scale), 0.3) \
        .set_trans(Tween.TRANS_CUBIC)

func _apply_counter_color(counter: Control, tier: int, player_id: int) -> void:
    var base_color: Color = COLOR_P1 if player_id == 1 else COLOR_P2
    match tier:
        2: counter.modulate = base_color * 1.2  # +20% 亮度
        3: counter.modulate = base_color * 1.4  # +40% + glow
        4: counter.modulate = COLOR_GOLD  # 金色
        _: counter.modulate = base_color

func _update_sync_chain_icons(chain_length: int) -> void:
    # 显示 chain_length 个同步链图标
    pass

func _trigger_flutter_animation(counter: Control) -> void:
    var tween := create_tween()
    tween.tween_property(counter, "rotation", 0.1, 0.05)
    tween.tween_property(counter, "rotation", -0.1, 0.05)
    tween.tween_property(counter, "rotation", 0.0, 0.05)

func _start_rescue_timer(player_id: int) -> void:
    # 圆形倒计时动画，3秒
    pass

func _trigger_rescue_sparkle(rescuer_color: Color) -> void:
    # 救援成功闪光动画
    pass

func _start_crisis_pulse() -> void:
    # 边缘光晕脉冲：0.5s 亮度 0.7 → 0.5s 亮度 0
    # 使用 Timer 或 Tween 循环
    pass

func _show_ghost_icon(player_id: int) -> void:
    # 在存活的队友 HP 栏旁显示 ghost 图标
    pass

func _update_boss_hp_bar_phase(phase: int) -> void:
    var colors: Dictionary = {
        1: Color("#6B7B8C"),   # 冷静蓝灰
        2: Color("#D4A017"),   # 琥珀警告
        3: Color("#E85D3B")    # 紧急红橙
    }
    if _boss_hp_bar != null:
        _boss_hp_bar.set_phase_color(colors.get(phase, colors[1]))

func _show_phase_warning(phase: int) -> void:
    # 中央屏幕闪烁阶段警告
    pass

func _show_attack_telegraph(pattern: String) -> void:
    # 中央显示攻击名称和图标
    pass

## 屏幕状态转换

func transition_to(state: ScreenState) -> void:
    _set_screen_state(state)

func toggle_pause() -> void:
    if _current_screen == ScreenState.GAMEPLAY_HUD:
        _set_screen_state(ScreenState.PAUSED)
    elif _current_screen == ScreenState.PAUSED:
        _set_screen_state(ScreenState.GAMEPLAY_HUD)

func get_current_screen() -> ScreenState:
    return _current_screen
```

### 组件清单与 Z-Order

| 组件 | Layer | 锚点 | 颜色 |
|------|-------|------|------|
| CrisisEdgeGlow | 0 (最底) | 全屏边缘 | #7F96A6 |
| BossHPBar | 1 | TOP_CENTER | 按相位变色 |
| PlayerHPBar_P1 | 1 | BOTTOM_LEFT | #F5A623 |
| PlayerHPBar_P2 | 1 | BOTTOM_RIGHT | #4ECDC4 |
| CoopBonusIndicator_P1/P2 | 1 | HP栏旁 | P1/P2颜色 |
| ComboCounter_P1/P2 | 1 | HP栏下方 | P1/P2颜色，Tier缩放 |
| SyncChainIndicator | 1 | 中央 | P1/P2交替 |
| RescueTimer | 1 | 投影到屏幕 | 救援者颜色 |
| BossPhaseWarning | 2 | 中央 | 临时 |
| PauseMenu / GameOverScreen | 3 | 全屏 | 覆盖 |

### 信号订阅（全部经 Events）

| 信号 | 来源 | UI 响应 |
|------|------|---------|
| `combo_tier_changed(tier, player_id)` | ComboSystem → Events | 连击计数器缩放+变色 |
| `combo_hit(attack_type, combo_count, is_grounded)` | CombatSystem → Events | 计数器递增 |
| `sync_chain_active(chain_length)` | ComboSystem → Events | 同步链图标填充 |
| `combo_break(player_id)` | ComboSystem → Events | 计数器重置+飘动动画 |
| `player_downed(player_id)` | CoopSystem → Events | 生成 RescueTimer |
| `player_rescued(player_id, rescuer_color)` | CoopSystem → Events | 移除 Timer+闪光 |
| `crisis_state_changed(is_crisis)` | CoopSystem → Events | CrisisEdgeGlow 开关 |
| `player_out(player_id)` | CoopSystem → Events | 移除Timer，显示ghost图标 |
| `coop_bonus_active(multiplier)` | CoopSystem → Events | CoopBonusIndicator 开关 |
| `boss_phase_changed(new_phase)` | BossAI → Events | BossHPBar 相位变色 |
| `boss_phase_warning(phase)` | BossAI → Events | 中央警告闪烁 |
| `boss_attack_telegraph(pattern)` | BossAI → Events | 中央攻击提示 |
| `player_health_changed(current, max, player_id)` | CombatSystem → Events | HP 条更新 |

### HP 条平滑插值

```
display_hp = lerp(display_hp, actual_hp, 1.0 - pow(0.001, delta_time))
```

### Combo Counter Tier 缩放

| Tier | Scale | Color Effect |
|------|-------|-------------|
| 0 (IDLE) | 1.0x | 默认色 |
| 1 (1-9) | 1.0x | 默认色 |
| 2 (10-19) | 1.15x | +20% 亮度 |
| 3 (20-39) | 1.30x | +40% + glow |
| 4 (40+) | 1.50x | 金色 + confetti |

## Alternatives Considered

### Alternative 1: 直接节点引用代替 Events
- **描述**: UI 直接持有各系统 Manager 的节点引用
- **优点**: 无信号调度开销
- **缺点**: 紧耦合；UI 难以独立测试
- **拒绝理由**: 松耦合是架构原则；Events 信号可观测、易调试

### Alternative 2: 轮询代替信号
- **描述**: UI 在 _process 中轮询游戏状态
- **优点**: 状态同步简单
- **缺点**: 每帧状态检查浪费 CPU；状态变化容易错过
- **拒绝理由**: 全信号驱动是设计要求；轮询浪费资源

## Consequences

### Positive
- **松耦合**: UI 只订阅 Events，不直接引用 Manager
- **可测试**: UI 可在单元测试中 Mock Events 验证行为
- **Paper 美学**: 所有组件使用统一视觉风格

### Negative
- **信号多**: 13+ 信号需要仔细管理连接和断开
- **组件同步**: 多个信号可能同时触发同一组件更新

### Risks
- **信号遗漏**: 如果某系统信号发射但 UI 未连接，状态会丢失。**缓解**: 所有连接在 _ready() 中集中建立
- **CanvasLayer 层级冲突**: 多个 CanvasLayer 可能有 z-index 冲突。**缓解**: 明确 Z-Order 表

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ui-system.md | 8 种 UI 组件 | UIManager 持有所有引用 |
| ui-system.md | 全信号驱动 | _connect_all_signals() 订阅所有 Events |
| ui-system.md | CanvasLayer 独立渲染 | 每个组件在独立 CanvasLayer 或同级 |
| ui-system.md | Paper 美学 | 颜色常量定义（C1/P2/C GOLD） |
| ui-system.md | 5 屏幕状态 | ScreenState enum + _set_screen_state() |
| ui-system.md | HP 平滑插值 | display_hp lerp 公式 |
| ui-system.md | Combo Tier 缩放 | TIER_SCALES + _apply_counter_scale() |
| ui-system.md | Rescue Timer | _start_rescue_timer() + 径向动画 |
| ui-system.md | Crisis Edge Glow | _crisis_edge_glow + _start_crisis_pulse() |
| ui-system.md | Boss HP Bar 相位变色 | _update_boss_hp_bar_phase() |
| combo-system.md | combo_tier_changed | Events 订阅 |
| coop-system.md | player_downed/rescued | Events 订阅 |
| boss-ai-system.md | boss_phase_changed | Events 订阅 |
| camera-system.md | camera_zoom_changed | Events 订阅 |

## Performance Implications
- **CPU**: UI 更新仅在信号触发时发生，无每帧轮询，< 0.01ms
- **Memory**: UI 组件约 50KB
- **Load Time**: CanvasLayer 场景按需加载

## Migration Plan
1. 创建 `UIManager.gd` Autoload
2. 预加载所有 UI 组件场景
3. 实现 ScreenState enum 和 _set_screen_state()
4. 实现 _connect_all_signals()
5. 实现每个信号的处理方法
6. 实现 UI 组件操作方法（缩放/变色/动画）
7. 配置 Pause/Resume 转换
8. 配置 Boss HP Bar 相位变色

## Validation Criteria
- [ ] 5 屏幕状态切换正确：TITLE → BOSS_INTRO → GAMEPLAY_HUD → PAUSED / GAME_OVER
- [ ] combo_tier_changed(tier=4, player_id=1) → P1 计数器缩放 1.5x + 金色
- [ ] player_downed(1) → RescueTimer 出现，3秒倒计时
- [ ] player_rescued → RescueTimer 消失 + 闪光动画
- [ ] crisis_state_changed(true) → CrisisEdgeGlow 脉冲激活
- [ ] boss_phase_changed(3) → BossHPBar 变为红色
- [ ] pause 输入 → PAUSED 状态，timer 停止

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-004: Combo System — combo_tier_changed 来源
- ADR-ARCH-005: Coop System — player_downed/rescued 来源
- ADR-ARCH-006: Boss AI — boss_phase_changed 来源
- ADR-ARCH-007: Camera System — camera_zoom_changed 来源
- `docs/architecture/architecture.md`
