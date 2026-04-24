# ADR-ARCH-011: Audio System Architecture

## Status
Accepted

## Date
2026-04-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Audio |
| **Knowledge Risk** | LOW — AudioStreamPlayer / AudioServer API 在 Godot 4.4-4.6 无显著变化 |
| **References Consulted** | `docs/engine-reference/godot/modules/` (无相关domain变更) |
| **Post-Cutoff APIs Used** | 无 |
| **Verification Required** | 无 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-ARCH-001 (Events Autoload), ADR-ARCH-003 (Combat State Machine), ADR-ARCH-004 (Combo System), ADR-ARCH-005 (Coop System), ADR-ARCH-006 (Boss AI) |
| **Enables** | 无 |
| **Blocks** | 无 |
| **Ordering Note** | ⚠️ 注意：音频系统 GDD 尚未编写（systems-index 中为 "Not Started"）。本 ADR 基于现有系统信号做合理假设，待 audio-system.md 完成后需交叉验证。 |

## Context

### Problem Statement
音频系统需要管理所有游戏音效和音乐，通过 Events 信号驱动动态混音和状态切换。系统基于"手绘纸偶剧场"美学提供匹配的音频反馈。

### Requirements
- 全信号驱动，无轮询
- BGM 层：根据屏幕状态（Boss Intro / 战斗 / 危机 / Game Over）切换
- SFX 层：命中、连击、救援、Boss 攻击等事件触发
- 动态混音：危机状态时背景音乐降调强调紧迫感
- 协作激励：同步攻击触发和谐音效叠加

## Decision

### AudioManager (Autoload) 设计

```gdscript
# AudioManager.gd — Autoload singleton

## 音频总线
const MASTER_BUS := 0
const SFX_BUS := 1
const MUSIC_BUS := 2
const AMBIENT_BUS := 3

## BGM 资源路径
const BGM_TITLE := "res://assets/audio/music/title_theme.mp3"
const BGM_BOSS_INTRO := "res://assets/audio/music/boss_intro.mp3"
const BGM_BATTLE := "res://assets/audio/music/battle_phase1.mp3"
const BGM_BATTLE_PHASE2 := "res://assets/audio/music/battle_phase2.mp3"
const BGM_BATTLE_PHASE3 := "res://assets/audio/music/battle_phase3.mp3"
const BGM_CRISIS := "res://assets/audio/music/crisis.mp3"
const BGM_GAME_OVER := "res://assets/audio/music/game_over.mp3"

## SFX 资源路径
const SFX_LIGHT_HIT := "res://assets/audio/sfx/hit_light.mp3"
const SFX_MEDIUM_HIT := "res://assets/audio/sfx/hit_medium.mp3"
const SFX_HEAVY_HIT := "res://assets/audio/sfx/hit_heavy.mp3"
const SFX_SPECIAL_HIT := "res://assets/audio/sfx/hit_special.mp3"
const SFX_SYNC_CHIME := "res://assets/audio/sfx/sync_chime.mp3"
const SFX_SYNC_BURST := "res://assets/audio/sfx/sync_burst.mp3"
const SFX_REScue := "res://assets/audio/sfx/rescue.mp3"
const SFX_PLAYER_DOWN := "res://assets/audio/sfx/player_down.mp3"
const SFX_COMBO_TIER2 := "res://assets/audio/sfx/combo_tier2.mp3"
const SFX_COMBO_TIER3 := "res://assets/audio/sfx/combo_tier3.mp3"
const SFX_COMBO_TIER4 := "res://assets/audio/sfx/combo_tier4.mp3"
const SFX_BOSS_ATTACK := "res://assets/audio/sfx/boss_attack.mp3"
const SFX_BOSS_PHASE_CHANGE := "res://assets/audio/sfx/boss_phase_change.mp3"

## 音频播放器
var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

## 状态
var _current_bgm_state: String = "TITLE"
var _is_crisis: bool = false
var _current_boss_phase: int = 1

func _ready() -> void:
    _init_audio_players()
    _connect_signals()
    _play_bgm("TITLE")

func _init_audio_players() -> void:
    _bgm_player = AudioStreamPlayer.new()
    _bgm_player.bus = "Music"
    add_child(_bgm_player)

    _sfx_player = AudioStreamPlayer.new()
    _sfx_player.bus = "SFX"
    add_child(_sfx_player)

    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.bus = "Ambient"
    add_child(_ambient_player)

func _connect_signals() -> void:
    # UI 系统
    Events.player_downed.connect(_on_player_downed)
    Events.player_rescued.connect(_on_player_rescued)
    Events.crisis_state_changed.connect(_on_crisis_state_changed)

    # Combo 系统
    Events.combo_hit.connect(_on_combo_hit)
    Events.combo_tier_changed.connect(_on_combo_tier_changed)
    Events.sync_burst_triggered.connect(_on_sync_burst_triggered)

    # 战斗系统
    Events.attack_started.connect(_on_attack_started)
    Events.hit_confirmed.connect(_on_hit_confirmed)

    # Boss AI 系统
    Events.boss_attack_started.connect(_on_boss_attack_started)
    Events.boss_phase_changed.connect(_on_boss_phase_changed)
    Events.boss_defeated.connect(_on_boss_defeated)

## BGM 管理

func _play_bgm(state: String) -> void:
    if _current_bgm_state == state:
        return
    _current_bgm_state = state

    var path: String
    match state:
        "TITLE": path = BGM_TITLE
        "BOSS_INTRO": path = BGM_BOSS_INTRO
        "BATTLE_PHASE1": path = BGM_BATTLE
        "BATTLE_PHASE2": path = BGM_BATTLE_PHASE2
        "BATTLE_PHASE3": path = BGM_BATTLE_PHASE3
        "CRISIS": path = BGM_CRISIS
        "GAME_OVER": path = BGM_GAME_OVER

    var stream: AudioStream = load(path) if path != "" else null
    if stream != null:
        _bgm_player.stream = stream
        _bgm_player.volume_db = 0.0
        _bgm_player.play()

func _crossfade_bgm(new_state: String, duration: float = 2.0) -> void:
    var tween := create_tween()
    tween.tween_property(_bgm_player, "volume_db", -80.0, duration)  # 淡出
    await tween.finished
    _play_bgm(new_state)
    tween = create_tween()
    tween.tween_property(_bgm_player, "volume_db", 0.0, duration)  # 淡入

func _on_crisis_state_changed(is_crisis: bool) -> void:
    _is_crisis = is_crisis
    if is_crisis:
        # 危机时背景音乐降调，增加紧迫感
        _crossfade_bgm("CRISIS", 1.0)
        _set_music_pitch(0.95)  # 略微降调
    else:
        # 危机解除，回到对应 Boss 阶段
        match _current_boss_phase:
            1: _crossfade_bgm("BATTLE_PHASE1", 1.0)
            2: _crossfade_bgm("BATTLE_PHASE2", 1.0)
            3: _crossfade_bgm("BATTLE_PHASE3", 1.0)
        _set_music_pitch(1.0)

func _set_music_pitch(pitch: float) -> void:
    # AudioStreamPlayer 无内置 pitch 属性，使用 AudioServer 或
    # 在资源层面处理（提前降调录制）
    pass

## SFX 管理

func _play_sfx(sfx_path: String, volume_db: float = 0.0) -> void:
    var stream: AudioStream = load(sfx_path)
    if stream != null:
        _sfx_player.stream = stream
        _sfx_player.volume_db = volume_db
        _sfx_player.play()

func _on_combo_tier_changed(tier: int, player_id: int) -> void:
    match tier:
        2: _play_sfx(SFX_COMBO_TIER2)
        3: _play_sfx(SFX_COMBO_TIER3)
        4: _play_sfx(SFX_COMBO_TIER4)

func _on_hit_confirmed(hitbox_id: int, hurtbox_id: int, attack_id: int) -> void:
    # 需要从 attack_id 获取 attack_type
    # 简化处理：根据 attack_type 播放对应 SFX
    pass

func _on_attack_started(attack_type: String) -> void:
    # 攻击开始 SFX（预备音效）
    pass

func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
    # 每次命中播放对应攻击类型 SFX
    match attack_type:
        "LIGHT":   _play_sfx(SFX_LIGHT_HIT)
        "MEDIUM":  _play_sfx(SFX_MEDIUM_HIT)
        "HEAVY":   _play_sfx(SFX_HEAVY_HIT)
        "SPECIAL": _play_sfx(SFX_SPECIAL_HIT)

func _on_sync_burst_triggered(position: Vector2) -> void:
    _play_sfx(SFX_SYNC_BURST)

func _on_player_downed(player_id: int) -> void:
    _play_sfx(SFX_PLAYER_DOWN)

func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
    _play_sfx(SFX_RESCUE)

func _on_boss_attack_started(attack_pattern: String) -> void:
    _play_sfx(SFX_BOSS_ATTACK)

func _on_boss_phase_changed(new_phase: int) -> void:
    _current_boss_phase = new_phase
    _play_sfx(SFX_BOSS_PHASE_CHANGE)
    match new_phase:
        2: _crossfade_bgm("BATTLE_PHASE2", 1.5)
        3: _crossfade_bgm("BATTLE_PHASE3", 1.5)

func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
    _bgm_player.volume_db = -80.0  # 淡出背景音乐
```

### 音频总线设计

| Bus | 用途 | 音量 |
|-----|------|------|
| Master | 总输出 | 0dB |
| SFX | 所有音效 | -6dB（低于音乐） |
| Music | BGM | -3dB（主输出音量） |
| Ambient | 环境音/持续音效 | -9dB |

### 信号订阅

| 信号 | 来源 | 音频响应 |
|------|------|---------|
| `combo_tier_changed(tier, player_id)` | ComboSystem → Events | Tier 2/3/4 升级音效 |
| `combo_hit(attack_type, combo_count, is_grounded)` | CombatSystem → Events | 命中 SFX（按攻击类型） |
| `sync_burst_triggered(position)` | ComboSystem → Events | 同步爆发 SFX |
| `player_downed(player_id)` | CoopSystem → Events | 倒地 SFX |
| `player_rescued(player_id, rescuer_color)` | CoopSystem → Events | 救援成功 SFX |
| `crisis_state_changed(is_crisis)` | CoopSystem → Events | 危机 BGM 切换 |
| `attack_started(attack_type)` | CombatSystem → Events | 攻击预备 SFX |
| `boss_attack_started(attack_pattern)` | BossAI → Events | Boss 攻击 SFX |
| `boss_phase_changed(new_phase)` | BossAI → Events | Boss 阶段转换 BGM |
| `boss_defeated(position, boss_type)` | BossAI → Events | 胜利/失败 BGM |

### 动态混音规则

| 条件 | BGM 动作 | SFX 层 |
|------|---------|--------|
| 正常战斗 | BATTLE_PHASE1/2/3 | 正常音量 |
| CRISIS 激活 | CRISIS BGM（紧迫），pitch 降 5% | SFX 略微提升 |
| 同步攻击中 | BGM 降低 20% 以突出 SFX | 同步 SFX 叠加 |
| Boss 阶段转换 | 1.5s 交叉淡入新 BGM | 阶段转换 SFX |

## Consequences

### Positive
- **全信号驱动**: 音频系统完全被动响应，无需轮询
- **动态混音**: BGM 根据游戏状态自动切换
- **协作音效**: 同步攻击有独特音效叠加

### Negative
- **Pitch 控制有限**: Godot AudioStreamPlayer 无内置 pitch 属性，需用其他方式实现
- **GDD 缺失**: 音频系统 GDD 尚未编写，本 ADR 基于合理假设

### Risks
- **Pitch 实现**: Godot 4.6 中 pitch shift 需要 `AudioStreamPlayer` 配合 `AudioServer.set_bus_effect` 或预录制降调版本。**缓解**: 确认实现方式
- **GDD 不同步**: 音频系统 GDD 完成后可能与本 ADR 不一致。**缓解**: 待 GDD 完成后重新审查本 ADR

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ui-system.md | Combo tier audio | _on_combo_tier_changed() |
| combo-system.md | sync_burst audio | _on_sync_burst_triggered() |
| coop-system.md | rescue/down audio | _on_player_downed() / _on_player_rescued() |
| combat-system.md | hit SFX by attack type | _on_combo_hit() |
| boss-ai-system.md | boss phase BGM | _on_boss_phase_changed() |
| camera-system.md | 无直接音频依赖 | — |

## Performance Implications
- **CPU**: 音频播放本身 < 0.01ms（引擎级）
- **Memory**: 音频流按需加载，非预加载
- **Load Time**: BGM 资源按场景需要加载

## Migration Plan
1. 创建 `AudioManager.gd` Autoload
2. 配置音频总线（Master / SFX / Music / Ambient）
3. 导入所有 BGM 和 SFX 资源
4. 实现 _connect_signals()
5. 实现 BGM 管理和交叉淡入淡出
6. 实现 SFX 播放接口
7. 配置动态混音规则

## Validation Criteria
- [ ] Combo Tier 4 升级 → SFX_COMBO_TIER4 播放
- [ ] 同步爆发触发 → SFX_SYNC_BURST 叠加
- [ ] crisis_state_changed(true) → BGM 切换到 CRISIS
- [ ] boss_phase_changed(2) → BGM 交叉淡入到 PHASE2
- [ ] player_downed → SFX_PLAYER_DOWN 播放
- [ ] player_rescued → SFX_RESCUE 播放

## Related Decisions
- ADR-ARCH-001: Events Autoload — 信号路由模式
- ADR-ARCH-003: Combat State Machine — attack_started / combo_hit
- ADR-ARCH-004: Combo System — sync_burst_triggered
- ADR-ARCH-005: Coop System — player_downed/rescued
- ADR-ARCH-006: Boss AI — boss_phase_changed
- `docs/architecture/architecture.md`
