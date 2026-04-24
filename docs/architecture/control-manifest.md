# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-04-17
> **Manifest Version**: 2026-04-17
> **ADRs Covered**: ADR-001, ADR-002, ADR-003, ADR-004, ADR-005, ADR-006, ADR-007, ADR-008, ADR-009, ADR-010, ADR-011
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this date when created. `/story-readiness` compares a story's embedded version to this field to detect stories written against stale rules. Always matches `Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs, technical preferences, and engine reference docs. For the reasoning behind each rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns
- **Events Autoload 作为中央信号中继** — Events.gd 纯中继无业务逻辑，fire-and-forget — source: ADR-001
- **所有跨系统信号经 Events.gd 中继** — 23个跨系统信号全部走 Events，只有 hit_landed 例外 — source: ADR-001
- **消费者必须在 `_ready()` 中连接信号** — 避免漏接信号 — source: ADR-001
- **hit_landed 是唯一不经 Events 的信号** — CombatSystem → VFXManager 直接路由，高频低延迟 — source: ADR-001
- **CollisionManager 作为 Autoload 管理 Hitbox 生命周期** — source: ADR-002

### Forbidden Approaches
- **Never 直接节点引用跨系统通信** — 紧耦合，违反松耦合原则；改用 Events 信号 — source: ADR-001
- **Never 循环信号依赖** — 消费者同时是生产者会形成循环；GDD 依赖表已验证无循环 — source: ADR-001
- **Never 在 `_ready()` 之外连接信号** — Godot 的 `_ready()` 在所有节点 `_ready()` 后才发射信号，延迟连接会漏接 — source: ADR-001

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns
- **Area2D Hitbox/Hurtbox Spawn-in/Spawn-out 模式** — Hitbox Area2D 在攻击帧 spawn，攻击结束时 despawn — source: ADR-002
- **Hitbox 在攻击动画帧 spawn，攻击结束时 despawn** — 精确帧级控制，由 AnimationPlayer keyframe 回调触发 — source: ADR-002
- **Hitbox 在 DESTROYED 帧仍参与碰撞检测** — 该帧有效；queue_free() 在下一帧物理步执行 — source: ADR-002
- **6层 Layer/Mask 碰撞策略** — WORLD(1)/PLAYER(2)/PLAYER_HITBOX(3)/BOSS(4)/BOSS_HITBOX(5)/SENSOR(6) — source: ADR-002
- **对象池 20 个预分配 Area2D，零运行时实例化** — 从池取用，归还池中；无 new Area2D() — source: ADR-002
- **玩家状态机: IDLE/MOVING/ATTACKING/HURT/DODGING/BLOCKING/DOWNTIME** — source: ADR-003
- **Boss 状态机: IDLE/ATTACKING/HURT/PHASE_CHANGE/DEFEATED** — source: ADR-003
- **伤害公式: final_damage = base_damage × attack_type_multiplier × combo_multiplier** — source: ADR-003
- **Hitstop: base_hitstop[attack_type] + bonus_hitstop[target_type]** — source: ADR-003
- **击退方向始终远离攻击者** — knockback_force = base_knockback[attack_type] × normalize(target - attacker) — source: ADR-003
- **每玩家独立 ComboData 实例** — ComboData(player_id) 实例分离，互不影响 — source: ADR-004
- **TierLogic 用静态方法计算等级** — TierLogic.calculate_tier()，可单独单元测试 — source: ADR-004
- **SYNC 窗口 5 帧，3+ 连触发 Sync Burst** — TierLogic.is_sync_hit() + should_trigger_sync_burst() — source: ADR-004
- **Combo 窗口计时器 1.5 秒** — ComboManager._process() 计时，超时重置 — source: ADR-004
- **PlayerCoopState 管理独立 HP 池（100/人）** — source: ADR-005
- **3 秒救援窗口，175px 范围** — RESCUE_WINDOW=3.0, RESCUE_RANGE=175.0 — source: ADR-005
- **救援后 1.5s 无敌帧** — RESCUED_IFRAMES_DURATION=1.5，has_iframes + iframe_timer — source: ADR-005
- **CRISIS: 双方 < 30% HP 时激活，25% 减伤** — CRISIS_HP_THRESHOLD=0.30, CRISIS_DAMAGE_REDUCTION=0.25 — source: ADR-005

### Forbidden Approaches
- **Never combo_multiplier 超上限** — solo 上限 3.0, sync 上限 4.0，不可超出 — source: ADR-003
- **Never CRISIS 和 SOLO 减伤叠加** — CRISIS 优先，CRISIS 激活时 SOLO 不生效 — source: ADR-005

### Performance Guardrails
- **Concurrent Hitboxes**: max 13 — 安全上限，包含 2P×4 + 1Boss×6 减去重叠；超出时拒绝 spawn — source: ADR-002
- **对象池大小**: 20 pre-allocated — 运行时绝不实例化新 Area2D — source: ADR-002

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

### Required Patterns
- **Hybrid FSM + Behavior Tree 架构（Boss AI）** — 宏观 FSM 管状态，BT 管攻击选择 — source: ADR-006
- **压缩墙作为持续并行进程，每帧运行** — BossAIManager._process() 中 _update_compression(delta) — source: ADR-006
- **压缩速度调制: rescue×0.5, crisis×1.2, 落后×0.6** — _calculate_compression_speed() 实现所有倍率规则 — source: ADR-006
- **player_detected/lost/hurt 从 CollisionManager 直接路由到 BossAI** — 低延迟感知，不经 Events — source: ADR-006
- **boss_attack_started/boss_phase_changed 经 Events 广播** — 广播给 UI/VFX/Camera — source: ADR-006
- **7 相机状态: NORMAL/PLAYER_ATTACK/SYNC_ATTACK/BOSS_FOCUS/BOSS_PHASE_CHANGE/CRISIS/COMBAT_ZOOM** — source: ADR-007
- **相机状态优先级: CRISIS > BOSS_PHASE_CHANGE > BOSS_FOCUS > SYNC_ATTACK > PLAYER_ATTACK > COMBAT_ZOOM > NORMAL** — source: ADR-007

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns
- **VFXManager: CPUParticles2D 用于单次爆发，GPUParticles2D 用于连续螺旋流** — hit/combo/rescue/boss_death 用 CPU；sync_burst 用 GPU — source: ADR-008
- **VFX 系统完全信号驱动，被动响应** — VFXManager 只做消费者，从不主动查询状态 — source: ADR-008
- **预分配 20 个发射器，零运行时实例化** — _init_pool() 在 _ready 中预分配 — source: ADR-008
- **FIFO 队列（队满时丢弃最老事件）** — MAX_QUEUE_DEPTH=10，_queue_emitter() FIFO 驱逐 — source: ADR-008
- **sync_burst 使用 BR_MODE_ADD（叠加混合）** — 橙色+蓝色粒子螺旋混合视觉 — source: ADR-008
- **UIManager: 全信号驱动更新，无轮询** — 所有 UI 组件通过 Events 信号更新，不在 _process 中查询状态 — source: ADR-009
- **CanvasLayer 独立渲染，屏幕空间不随相机运动** — UI 组件在 CanvasLayer 上，不受 Camera2D 影响 — source: ADR-009
- **5 屏幕状态: TITLE/BOSS_INTRO/GAMEPLAY_HUD/PAUSED/GAME_OVER** — UIManager.ScreenState enum — source: ADR-009
- **HP 条平滑插值: lerp(display_hp, actual_hp, 1.0 - pow(0.001, delta_time))** — source: ADR-009
- **Combo counter Tier 缩放: 1.0x/1.15x/1.30x/1.50x** — TIER_SCALES dict + _apply_counter_scale() — source: ADR-009
- **AnimationController + AnimationTree 混合架构** — AnimatedSprite2D + AnimationPlayer + AnimationTree — source: ADR-010
- **帧锁 hitbox: 动画关键帧控制 hitbox 激活时机** — AnimationPlayer keyframe 回调 → hitbox_active(hitbox_type) — source: ADR-010
- **动画帧比例: anticipation/active/recovery = 3:1:2** — 总帧数: LIGHT=16, MEDIUM=27, HEAVY=40, SPECIAL=58 — source: ADR-010
- **AudioManager: 4 总线（Master/SFX/Music/Ambient）** — MASTER_BUS=0, SFX_BUS=1, MUSIC_BUS=2, AMBIENT_BUS=3 — source: ADR-011
- **全 SFX 信号驱动，无轮询** — AudioManager 作为消费者订阅 Events — source: ADR-011
- **BGM 交叉淡入淡出切换** — _crossfade_bgm() 使用 Tween 音量渐变 — source: ADR-011

### Forbidden Approaches
- **Never 屏幕震动应用于 position 而非 offset** — offset 不影响世界位置，震动结束时精确回到原位无漂移；position 会导致震动结束时相机"弹回" — source: ADR-007

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | PlayerController |
| Variables | snake_case | move_speed |
| Signals/Events | snake_case (过去式) | health_changed |
| Files | snake_case | player_controller.gd |
| Scenes/Prefabs | PascalCase | PlayerController.tscn |
| Constants | UPPER_SNAKE_CASE | MAX_SPEED |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60fps (fixed physics timestep at 60fps) |
| Frame budget | 12ms max for game logic (16.67ms total / 60fps — 4ms headroom) |
| Draw calls | ≤200 per frame at target framerate |
| Memory ceiling | 512MB total runtime memory |

### System-Specific Hard Limits

| System | Limit | Enforcement |
|--------|-------|-------------|
| Concurrent Particles | 300 max | VFXManager._can_emit() 强检查 |
| Concurrent Emitters | 15 max | VFXManager._can_emit() 强检查 |
| Particle Pool Size | 20 pre-allocated | VFXManager._init_pool() 预分配 |
| Concurrent Hitboxes | 13 max | CollisionManager spawn 拒绝超出 |

### Forbidden APIs (Godot 4.6)

These APIs are deprecated or behave differently in the pinned engine version:

- **`Camera2D.smoothing`** (bool) — deprecated in Godot 4.4+, use `position_smoothing_enabled` (bool) + `position_smoothing_speed` (float)
- **`AnimationTree.playback_active`** — deprecated, use `AnimationTree.active` (verified working in 4.6, but verify AnimationMixer.active behavior if using AnimationMixer directly)

Source: `docs/engine-reference/godot/VERSION.md`

### Cross-Cutting Constraints

- **数据驱动**: Gameplay values must be data-driven (external config), never hardcoded — 所有数值从 Tuning Knobs 或 Constant 文件读取
- **可测试性**: All public methods must be unit-testable — use dependency injection over singletons where possible for testability
- **直接信号路由例外**: hit_landed 是唯一直接信号路由（CombatSystem → VFXManager）；所有其他跨系统信号必须经 Events Autoload
- **公开 API 文档注释**: All game code must include doc comments on public APIs — 每个 class 和 public method 需有 `## Description` 注释

---

## Validation Checklist

Before marking a story Done, verify:

- [ ] No direct node references for cross-system communication (except hit_landed)
- [ ] All consumers connect signals in `_ready()` only
- [ ] No signal circular dependencies
- [ ] Hitbox pool: 20 pre-allocated, zero runtime instantiation
- [ ] Hitbox concurrency never exceeds 13
- [ ] Combo multiplier never exceeds 3.0 (solo) / 4.0 (sync)
- [ ] CRISIS and SOLO damage reduction do not stack
- [ ] Camera shake applied to `offset`, not `position`
- [ ] VFX: CPUParticles2D for bursts, GPUParticles2D for continuous flows only
- [ ] UI: all updates via Events signals, no polling in `_process()`
- [ ] All gameplay values come from constants/config, not hardcoded
