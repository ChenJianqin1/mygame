# 今日Boss：打工吧！ — Master Architecture

> **Status**: Draft
> **Version**: 1
> **Last Updated**: 2026-04-17
> **Engine**: Godot 4.6 / GDScript / 2D Native Rendering
> **GDDs Covered**: input-system, collision-detection-system, combat-system, combo-system, coop-system, boss-ai-system, camera-system, particle-vfx-system, animation-system, ui-system
> **ADRs Referenced**: None yet — see Phase 6 for required ADRs to create

---

## Engine Knowledge Gap Summary

**Engine: Godot 4.6 | LLM Training Cutoff: ~Godot 4.3**

| Domain | Risk | Post-Cutoff Changes |
|--------|------|---------------------|
| Animation | HIGH | `AnimationTree.playback_active` deprecated 4.3+ → `active`. Base class changed |
| Input | HIGH | SDL3 gamepad backend in 4.5. Dual-focus system in 4.6 (mouse/keyboard focus separation) |
| Physics | LOW | Jolt default in 4.6 but **2D physics unchanged** — still Godot Physics 2D |
| Rendering | MEDIUM | Glow rework in 4.6. D3D12 default on Windows. CanvasLayer unchanged |
| Camera2D | MEDIUM | Property names (`smoothing_speed` vs `position_smoothing_speed`) need editor verification |

**Verified Safe:**
- `Camera2D.SMOOTHING_CENTER_OUT` confirmed in 4.6
- `Area2D` hitbox/hurtbox pattern unchanged in 4.4-4.6
- `CPUParticles2D` / `GPUParticles2D` API stable

**Verification Required Before Implementation:**
1. `AnimationTree.active` property — confirm exists in 4.6 editor
2. `InputEventJoypadButton` dual-detection pattern for simultaneous controllers
3. Camera2D smoothing property names in 4.6 inspector

---

## System Layer Map

```
┌─────────────────────────────────────────────────────────────┐
│ PRESENTATION LAYER                                           │
│ 摄像机系统 · 动画系统 · 粒子特效系统 · UI系统 · 音频系统      │
├─────────────────────────────────────────────────────────────┤
│ FEATURE LAYER                                                │
│ Boss AI系统 · 即时难度调整 · 场景管理系统                     │
├─────────────────────────────────────────────────────────────┤
│ CORE LAYER                                                   │
│ 战斗系统 · Combo连击系统 · 双人协作系统                        │
├─────────────────────────────────────────────────────────────┤
│ FOUNDATION LAYER                                             │
│ Events (Autoload) · 输入系统 · 碰撞检测系统 · 存档系统        │
├─────────────────────────────────────────────────────────────┤
│ PLATFORM LAYER                                               │
│ Godot 4.6 Engine API (Input, Physics2D, Rendering)          │
└─────────────────────────────────────────────────────────────┘
```

**Layer Assignment Rationale:**
- **Camera** → Presentation: camera is driven by gameplay state, outputs visual effects to VFX/UI
- **Boss AI** → Feature: AI behavior is a game feature built on top of core combat rules
- **Audio** → Presentation: purely output/feedback layer, no gameplay logic
- **Scene Management** → Feature: arena/level loading built on top of boss state

---

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|------------|
| **Events (Autoload)** | Signal registry — all cross-system event routing | All signals (static fire-and-forget) | — | `Node` |
| **输入系统** | Raw input state, 8-frame input buffer, device-to-player mapping | `rescue_input(player_id)`, `dodge_input(player_id)`, `sync_attack_detected` | `Input` singleton | `Input`, `InputEventJoypadButton` ⚠️ |
| **碰撞检测系统** | Hitbox/Hurtbox Area2D pairs, attack_hit routing | `attack_hit(attack_id, is_grounded, hit_count)` | `attack_started` from CombatSystem | `Area2D`, `CollisionShape2D` |
| **存档系统** | Save file data, slot metadata, serialization | `save_game(slot)`, `load_game(slot)` | Scene/combat/boss state | `FileAccess`, `ConfigFile` |

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|------------|
| **战斗系统** | HP pools, attack cooldowns, hitstop, attack_type_multiplier table, state machine (IDLE/ATTACKING/HURT/DODGE) | `attack_started(attack_type)`, `hit_confirmed`, `hurt_received`, `player_hp_changed` | InputSystem signals; `attack_hit` from CollisionSystem | `Node2D`, `Timer`, StateMachine |
| **Combo连击系统** | Per-player hit_count, combo_tier (1-4), sync_chain_length | `combo_hit`, `combo_tier_changed`, `sync_burst_triggered`, `combo_tier_escalated` | `hit_confirmed`; `sync_attack_detected` | `Timer`, `Dictionary` |
| **双人协作系统** | Per-player HP (100), RESCUE_WINDOW timer (3s), CRISIS state, COOP_BONUS, SOLO_DAMAGE_REDUCTION | `player_downed`, `player_rescued`, `crisis_state_changed`, `coop_bonus_active`, `solo_mode_active` | `hurt_received`; `rescue_input` | `Timer`, `Node2D.distance_to()` |

### Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|------------|
| **Boss AI系统** | Boss HP, phase (1/2/3), attack patterns, compression wall timers | `boss_attack_started`, `boss_phase_changed`, `boss_hp_changed`, `boss_defeated` | `hit_confirmed`; arena bounds | `Node2D`, `Timer`, BehaviorTree |
| **即时难度调整** | Scaling factors per dimension, performance metrics | `difficulty_scaling_changed` | `boss_phase_changed`; `crisis_state_changed` | `Dictionary` |
| **场景管理系统** | Arena state, boundaries, scene transitions | `arena_changed`, `scene_loaded` | `boss_defeated` | `Node`, `ResourceLoader` |

### Presentation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|------------|
| **摄像机系统** | Camera position/zoom/trauma, 7 camera states | `camera_shake_intensity`, `camera_zoom_changed`, `camera_framed_players` | All gameplay signals | `Camera2D`, `SMOOTHING_CENTER_OUT` ✓, `Tween` |
| **动画系统** | AnimationTree/BlendTree state, sprite frames, paper texture layer | `animation_state_changed` | `attack_started`, `hit_confirmed`, `hurt_received`, `boss_phase_changed` | `AnimationTree` ⚠️, `AnimationMixer.active` ⚠️, `AnimatedSprite2D` |
| **粒子特效系统** | 5 emitter types, 20-emitter pool, 300-particle budget | None (purely visual) | `hit_landed` from CombatSystem; `combo_tier_escalated`, `sync_burst_triggered`; `rescue_triggered`; `boss_defeated` | `CPUParticles2D`, `GPUParticles2D` |
| **UI系统** | HP bars, combo counter, rescue timer, CRISIS indicator, damage numbers | None (purely visual) | Combo/Coop/Boss/Camera signals | `Control`, `Label`, `TextureProgress`, `CanvasLayer` |
| **音频系统** | Audio streams, SFX pool, music layers | None (purely audio output) | All upstream game signals | `AudioStreamPlayer`, `AudioStreamPlayer2D` |

⚠️ = post-cutoff API requiring verification in Godot 4.6 editor

---

## Data Flow

### 1. Frame Update Path

```
60fps _physics_process (fixed timestep)

INPUT SYSTEM
  → Input.get_axis(P1_LEFT/P1_RIGHT) → raw P1 movement
  → Input.get_axis(P2_LEFT/P2_RIGHT) → raw P2 movement
  → Input.is_action_just_pressed(RESCUE_P1) → rescue_input signal
  → 8-frame ring buffer stores inputs

COMBAT SYSTEM
  → If attack input buffered AND state == IDLE:
      state = ATTACKING
      emit attack_started(attack_type)
      start hitstop timer (frame countdown per attack_type)
  → If state == HURT: decrement i_frames counter

COLLISION DETECTION
  → For each active hitbox Area2D:
      query overlaps via shape.intersects()
      if overlap → emit attack_hit(attack_id, is_grounded, hit_count)

COMBO SYSTEM
  → On attack_hit:
      hit_count++, tier = lookup_tier(hit_count)
      if sync window active (5 frames): sync_chain_length++
      if sync_chain_length == 3: emit sync_burst_triggered()
      emit combo_hit(player_id, hit_count)
      emit combo_tier_changed(tier, player_id)
      emit combo_tier_escalated(tier, player_color)

COOP SYSTEM
  → On hurt_received: player_hp -= damage
      if hp <= 0: state = DOWNTIME, emit player_downed()
      rescue_timer starts (3.0s real-time)
      if both < 30%: emit crisis_state_changed(true)
  → On rescue_input:
      if rescuer within 175px of downed player:
          partner revives with 1.5s i-frames
          emit player_rescued(downed_id, rescuer_color)

BOSS AI SYSTEM (parallel, not frame-locked)
  → On timer: evaluate phase → select attack pattern
      emit boss_attack_started(attack_pattern)
  → On hit_confirmed: boss_hp -= effective_damage
      if phase threshold crossed: emit boss_phase_changed()

CAMERA SYSTEM
  → Compute weighted midpoint: (P1_pos×w1 + P2_pos×w2) / (w1+w2)
  → Compute effective_zoom = BASE × dist_zoom × combat_zoom × boss_zoom
  → Apply smoothing: position = lerp(current, target, 1-exp(-speed×dt))
  → Apply trauma decay: trauma = max(0, trauma - 2.0 × dt)
  → If trauma > 0: offset = shake_offset via randf × trauma²

ANIMATION SYSTEM
  → On attack_started: play attack animation (anticipation→active→recovery)
  → On hit_confirmed: play hit reaction animation
  → On boss_phase_changed: crossfade to new phase animation
```

### 2. Signal Directory

| Signal | Producer | Consumers |
|--------|----------|-----------|
| rescue_input(player_id) | InputSystem | CoopSystem |
| dodge_input(player_id) | InputSystem | CombatSystem |
| sync_attack_detected | InputSystem | ComboSystem |
| attack_hit(attack_id, grounded, hit_count) | CollisionSystem | CombatSystem, BossAI |
| attack_started(attack_type) | CombatSystem | CameraSystem, AnimationSystem |
| hit_confirmed(hitbox, hurtbox, attack_id) | CombatSystem | ComboSystem, BossAI, CameraSystem |
| hurt_received(damage, knockback) | CombatSystem | CoopSystem, AnimationSystem |
| combo_hit(player_id, hit_count) | ComboSystem | UI (reads) |
| combo_tier_changed(tier, player_id) | ComboSystem | CameraSystem, VFXSystem, UI |
| sync_burst_triggered(position) | ComboSystem | CameraSystem, VFXSystem |
| combo_tier_escalated(tier, player_color) | ComboSystem | VFXSystem |
| player_downed(player_id) | CoopSystem | CameraSystem, VFXSystem, UI |
| player_rescued(player_id, rescuer_color) | CoopSystem | CameraSystem, VFXSystem, UI |
| crisis_state_changed(is_crisis) | CoopSystem | CameraSystem, VFXSystem, UI |
| coop_bonus_active(multiplier) | CoopSystem | CombatSystem |
| solo_mode_active(player_id) | CoopSystem | CombatSystem |
| boss_attack_started(pattern) | BossAI | CameraSystem, AnimationSystem |
| boss_phase_changed(new_phase) | BossAI | CameraSystem, VFXSystem, AnimationSystem |
| boss_hp_changed(current, max) | BossAI | UI |
| boss_defeated(position, type) | BossAI | VFXSystem, SceneManagement |
| camera_shake_intensity(trauma) | CameraSystem | VFXSystem, UI |
| camera_zoom_changed(zoom) | CameraSystem | UI |
| camera_framed_players([P1,P2]) | CameraSystem | UI |
| arena_changed(arena_id, bounds) | SceneManagement | CameraSystem |

**Note:** `hit_landed(attack_type, position, direction)` is emitted by CombatSystem directly (not via Events) to VFXSystem. VFXSystem connects to CombatSystem's own signal.

### 3. Save/Load Path

**Save:** Player pause → UI requests save → SceneManagement serializes arena state → CombatSystem serializes player HP/combo/rescue timers → BossAI serializes boss HP/phase → SaveSystem writes ConfigFile → UI confirms "Saved!"

**Load:** Select slot → SaveSystem reads ConfigFile → SceneManagement loads scene + restores arena → CombatSystem restores HP/combo/rescue → BossAI restores boss HP/phase → CoopSystem restores crisis flag → unpause

**Not saved:** Camera trauma, particle emitter state, input buffer, animation playback frame

### 4. Initialization Order

```
1. ENGINE BOOT
2. AUTOLOAD SINGLETONS (project.godot order):
   → Events (signal bus — all systems depend)
   → SaveSystem
   → InputSystem (subscribes to Input singleton)
3. SCENE: main.tscn instantiates
   → Players (P1.tscn, P2.tscn) with CombatSystem nodes
   → Boss (deadline_boss.tscn) with BossAI node
   → VFXLayer + VFXManager
   → UILayer
   → CameraRig + CameraController
4. EACH NODE._ready() fires (tree order):
   → Systems connect to Events signals
   → AnimationSystem connects to CombatSystem directly
   → CoopSystem initializes with player count
5. FIRST FRAME: _physics_process begins
   → InputSystem reads inputs
   → Boss AI starts compression wall timers
   → Camera follows P1+P2 midpoint at spawn
6. GAME IN PLAY
```

**No circular dependencies.** Events is pure relay — consumers register in `_ready()` after producers have initialized.

---

## API Boundaries

### Events (Autoload — Signal Bus)

```gdscript
# Events.gd — Autoload singleton
# Pure relay — no logic, fire-and-forget

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

### CombatSystem

```gdscript
# Attached to Player node

func start_attack(attack_type: String) -> void
func receive_hit(damage: int, knockback: Vector2, attack_id: int) -> void
func apply_combo_multiplier(multiplier: float) -> float  # effective_damage
func get_attack_cooldown(attack_type: String) -> float
func get_player_state() -> String  # "IDLE" | "ATTACKING" | "HURT" | "DODGE"

# Emits: attack_started, hit_confirmed, hurt_received, player_hp_changed
# Consumed: dodge_input (from Events)
```

### ComboSystem (Autoload)

```gdscript
func record_hit(player_id: int, attack_id: int, is_sync: bool) -> Dictionary
  # Returns: { tier, hit_count, is_escalation, is_sync_burst }
func break_combo(player_id: int) -> void
func get_combo_tier(player_id: int) -> int      # 1-4
func get_combo_multiplier(player_id: int) -> float  # 1.0-3.0 solo / 1.0-4.0 sync
func get_sync_chain_length(player_id: int) -> int  # 0-3

# Emits: combo_hit, combo_tier_changed, sync_burst_triggered, combo_tier_escalated
# Consumed: hit_confirmed, sync_attack_detected (from Events)
```

### CoopSystem (Autoload)

```gdscript
func request_rescue(downed_player_id: int, rescuer_id: int) -> bool
  # Returns true if within 175px and timer > 0
func get_rescue_timer(player_id: int) -> float      # 0.0-3.0s
func is_in_crisis() -> bool                         # both < 30% HP
func get_coop_bonus() -> float                      # 1.10 when both alive
func get_solo_reduction(player_id: int) -> float     # 0.25 when partner downed

# Emits: player_downed, player_rescued, crisis_state_changed,
#        coop_bonus_active, solo_mode_active, rescue_triggered (→ VFX direct)
# Consumed: hurt_received, rescue_input (from Events)
```

### BossAISystem

```gdscript
# Attached to Boss node

func get_current_phase() -> int          # 1, 2, or 3
func get_attack_pattern() -> String       # current active pattern
func calculate_damage_to_player(base_damage: int, player_id: int) -> int
  # Applies phase scaling: Phase 1: 0.8×, Phase 2: 1.0×, Phase 3: 1.2×

# Emits: boss_attack_started, boss_phase_changed, boss_hp_changed, boss_defeated
# Consumed: hit_confirmed (from Events)
```

### CameraSystem

```gdscript
# Extends Camera2D

func set_arena_bounds(left: int, right: int, top: int, bottom: int) -> void
func add_trauma(amount: float) -> void   # caps at 1.0, decay = 2.0/s
func transition_to_state(new_state: String) -> void
  # NORMAL | PLAYER_ATTACK | SYNC_ATTACK | BOSS_FOCUS | BOSS_PHASE_CHANGE | CRISIS | COMBAT_ZOOM

# Emits: camera_shake_intensity, camera_zoom_changed, camera_framed_players (→ Events)
# Consumed: all gameplay signals (attack_started, hit_confirmed, combo_tier_changed,
#            sync_burst_triggered, boss_attack_started, boss_phase_changed,
#            player_downed, player_revived)
```

### VFXManager (Autoload)

```gdscript
func emit_hit(attack_type: String, position: Vector2, direction: Vector2) -> void
func emit_combo_escalation(tier: int, player_color: Color) -> void
func emit_sync_burst(position: Vector2) -> void
func emit_rescue(position: Vector2, rescuer_color: Color) -> void
func emit_boss_death(position: Vector2, boss_type: String) -> void
func get_active_particle_count() -> int   # budget tracking
func get_active_emitter_count() -> int    # budget tracking

# Consumed: combo_tier_escalated, sync_burst_triggered (from Events);
#           rescue_triggered (direct from CoopSystem);
#           hit_landed (direct from CombatSystem, not via Events)
```

### AnimationSystem

```gdscript
# Attached to Player/Boss node

func play_attack(attack_type: String) -> void
  # anticipation → active → recovery at 30fps effective
func play_hit_reaction(hurtbox_id: int) -> void
func crossfade_to_boss_phase(phase: int) -> void
func get_current_animation() -> String

# Consumed: attack_started, hit_confirmed, hurt_received (from Events + direct CombatSystem)
#           boss_phase_changed (from Events)

# Keyframe signals (direct to CollisionSystem, not via Events):
# hitbox_frame_active(attack_id, frame) → activates hitbox Area2D
```

---

## ADR Audit

**Existing ADRs:** None — `docs/architecture/` is empty

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| — | — | — | — | — | — |

**No existing ADRs to audit.**

**Traceability:** 0/78 technical requirements have ADR coverage. All 78 TRs require new ADRs before implementation.

---

## Required ADRs

### Must have before coding starts (Foundation & Core)

| # | Title | Covers | Priority |
|---|-------|--------|----------|
| ADR-ARCH-001 | Events Autoload vs Direct Signal Architecture | All cross-system signals | FOUNDATION |
| ADR-ARCH-002 | Collision Detection: Area2D Spawn-In/Spawn-Out | TR-collision-001, TR-collision-002 | FOUNDATION |
| ADR-ARCH-003 | Combat System State Machine & Damage Formula | TR-combat-001 through TR-combat-008 | CORE |
| ADR-ARCH-004 | Combo System Data Structures & Tier Logic | TR-combo-001 through TR-combo-006 | CORE |
| ADR-ARCH-005 | Coop System HP Pools & Rescue Mechanics | TR-coop-001 through TR-coop-007 | CORE |

### Should have before relevant system is built

| # | Title | Covers | Priority |
|---|-------|--------|----------|
| ADR-ARCH-006 | Boss AI Behavior Tree & Phase Architecture | TR-boss-001 through TR-boss-005 | FEATURE |
| ADR-ARCH-007 | Real-Time Difficulty Adjustment Strategy | Difficulty scaling signals | FEATURE |
| ADR-ARCH-008 | Camera System Implementation Details | TR-camera-001 through TR-camera-005 | PRESENTATION |
| ADR-ARCH-009 | AnimationTree/BlendTree/AnimatedSprite2D Hybrid | TR-anim-001 through TR-anim-005 | PRESENTATION |
| ADR-ARCH-010 | VFX Emitter Pooling & CPU/GPU Decision | TR-vfx-001 through TR-vfx-005 | PRESENTATION |
| ADR-ARCH-011 | Z-Order Layering & CanvasLayer Assignment | Z-axis conventions, VFX/animation layer | PRESENTATION |

### Can defer to implementation

| # | Title | Covers | Priority |
|---|-------|--------|----------|
| ADR-ARCH-012 | Save/Load Serialization Format | Save system data schema | PERSISTENCE |
| ADR-ARCH-013 | Audio Signal Subscription Architecture | How audio subscribes to game events | PRESENTATION |

---

## Architecture Principles

**Derived from game concept, GDDs, and technical preferences:**

1. **Signal-based decoupling:** All cross-system communication via Events Autoload (fire-and-forget). Producers emit without knowing consumers. Consumers connect in `_ready()` after producers initialize.

2. **Foundation-first build order:** Foundation systems (Input, Collision) must be designed and verified before Core systems that depend on them. Core systems (Combat, Combo, Coop) must be stable before Feature/Presentation layers.

3. **Data-owning singletons:** Each system owns its state absolutely. No system reads another system's internal state directly — only through exposed APIs and signals.

4. **Animation drives hitboxes, not timers:** Hitbox activation is frame-locked to animation keyframes, not arbitrary timers. This ensures visual hit and game damage are always synchronized.

5. **Coop is always on:** Dual-player state is always tracked, even in single-player scenarios. Solo mode is a degradation state with explicit compensation (25% damage reduction), not an absent feature.

6. **Performance budgets are hard limits:** VFX system enforces 300-particle / 15-emitter budgets with FIFO queuing. No visual effect ever blocks gameplay frame rate.

---

## Open Questions

These decisions are deferred and must be resolved before the relevant layer is built:

| # | Question | Owner | Target |
|---|----------|-------|--------|
| 1 | Events Autoload vs direct node references for VFX? | Technical Director | ADR-ARCH-001 |
| 2 | AnimationTree `active` property confirmed in Godot 4.6? | godot-specialist | ADR-ARCH-009 |
| 3 | SDL3 gamepad dual-detection pattern for P1+P2 simultaneous? | godot-specialist | ADR-ARCH-001 |
| 4 | Camera2D smoothing property name: `smoothing_speed` or `position_smoothing_speed`? | godot-specialist | ADR-ARCH-008 |
| 5 | `boss_defeated(position, boss_type)` signal signature confirmed by BossAI? | Boss AI designer | ADR-ARCH-006 |
| 6 | `hit_landed` signal: `(attack_type, position, direction)` confirmed by Combat? | Combat designer | ADR-ARCH-010 |
| 7 | Save slot count and metadata format? | Technical Director | ADR-ARCH-012 |

---

## Technical Director Sign-Off

- Technical Director Sign-Off: **2026-04-17 — APPROVED WITH CONDITIONS**
  - Condition: ADR-ARCH-001 (Events Autoload) and ADR-ARCH-002 (Collision Detection) must be created before Foundation systems are implemented
- Lead Programmer Feasibility: **Skipped — Lean mode**

---

*Generated by `/create-architecture` on 2026-04-17*
