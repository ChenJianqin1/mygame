# 粒子特效系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 3 — 战斗即隐喻, Pillar 4 — 轻快节奏

## Overview

粒子特效系统是战斗的"视觉证明"——每次命中、每次连击升级、每次救援成功，都是粒子爆发的时刻。从玩家视角，每次攻击命中都是一次"我把这件事撕碎了"的视觉确认；从系统视角，系统接收来自战斗系统、Combo连击系统和双人协作系统的信号，驱动不同类型和强度的粒子效果。

粒子形状统一使用便签/纸张碎屑（来自art bible的"便签爆炸"美学）：轻攻击=小纸片飞散，重攻击=整张便签撕裂，连击满级=金色火星+墨水飞溅。粒子运动是向外扩散的抛物线，模拟"纸张被拍飞"的卡通物理感。所有粒子都是二维的，使用Godot `GPUParticles2D`或`CPUParticles2D`实现，持续时间0.3–1.5秒不等。

系统管理所有粒子发射器的实例化、信号订阅、和生命周期，不直接参与碰撞检测或游戏逻辑。

## Player Fantasy

**"把这些烂事撕碎，变成纸片飞走吧。"**

每次命中都是一次小小的声明——"我不只是这些"。粒子不是装饰，是战斗的视觉证据：你打出的每一击，都在把那些让人窒息的烂事撕成纸片。轻攻击把便签拍飞，重攻击把整张纸撕裂，连击越高，纸片越密、颜色越热。粒子飞散的弧线是宣泄的轨迹。

协作时刻（Sync Burst、救援成功）有额外的情感层：当两位玩家的颜色交织在一起时——橙色与蓝色在同步命中中缠绕——粒子是"我们一起扛过来了"的视觉证明。救援时的手部光效和火花是"你伸手拉了我一把"的温暖记录。

**情感锚点：**
- **宣泄感** — 每次命中都是破坏性的、满足的、"我赢了"
- **升维的成就感** — 连击越高，粒子越密越热，是努力积累的视觉等价物
- **协作的温暖** — 同步命中和救援的粒子效果是搭档关系的证明，不是伤害数字

**反面教材（avoid）:**
- 粒子过于抽象（圆形、方形）——破坏"便签爆炸"的隐喻
- 粒子过于血腥或暗黑——违反Pillar 4轻快节奏
- 粒子遮挡玩家视线——违反"轻快节奏"，不应阻碍战斗视野

## Detailed Design

### Core Rules

**Rule 1 — Emitter Types and Signal Map**

Five emitter types, each driven by a specific upstream signal:

| Emitter ID | Signal Received | Emitter Type | Particle Backend |
|------------|----------------|--------------|------------------|
| `hit_vfx` | `CombatSystem.hit_landed(attack_type, position, direction)` | One-shot hit burst | CPUParticles2D |
| `combo_escalation_vfx` | `ComboSystem.combo_tier_escalated(tier, player_color)` | Tier escalation burst | CPUParticles2D |
| `sync_burst_vfx` | `ComboSystem.sync_burst_triggered(position)` | Continuous intertwined stream | GPUParticles2D |
| `rescue_vfx` | `CoopSystem.rescue_triggered(position, rescuer_color)` | One-shot rescue burst | CPUParticles2D |
| `boss_death_vfx` | `BossAIManager.boss_defeated(position, boss_type)` | Explosion burst | CPUParticles2D |

*Note: `boss_defeated` signal is proposed here for BossAI adoption — see Open Questions.*

Crisis edge glow is **handled in UI layer** (per CoopSystem spec), not in VFX system. No `crisis_vfx` emitter in this system.

**Rule 2 — Per-Attack-Type Emission Parameters**

Particles scale with attack weight. All values are one-shot bursts (emitters are reused via pooling — Rule 11).

| Attack Type | Particle Count | Speed (px/s) | Lifetime (s) | Size (px) | Shape |
|-------------|---------------|--------------|--------------|----------|-------|
| `LIGHT` | 5–8 | 180–250 | 0.3–0.5 | 6–10 | Small scrap |
| `MEDIUM` | 10–15 | 220–300 | 0.5–0.7 | 10–16 | Medium scrap |
| `HEAVY` | 18–25 | 150–200 | 0.8–1.2 | 16–28 | Whole torn note |
| `SPECIAL` | 30–40 | 200–280 | 1.0–1.5 | 20–32 | Whole torn note + gold sparks |

- **Direction**: Outward radial from `position`, biased along `direction` vector (provided by signal)
- **Spread**: LIGHT/MEDIUM = full 360° radial; HEAVY/SPECIAL = 120° cone in `direction`
- **Motion**: Parabolic arc — initial velocity outward + downward gravity (simulates "paper being slapped飞")
- **Gravity**: 400 px/s² downward for LIGHT/MEDIUM; 200 px/s² for HEAVY/SPECIAL (slower fall for torn whole notes)
- **Tier scaling**: When combo tier ≥ 3, all hit_vfx counts multiply by 1.5x and add gold spark particles (Rule 7)

**Rule 3 — Particle Shape / Procedural Torn-Edge Shader**

Particles use a **procedural paper scrap** approach — no texture atlas required.

- **Small scrap (LIGHT)**: 4–6 vertex irregular quadrilateral polygon, aspect ratio 0.6–1.4, drawn via `draw_polygon` in CPUParticles2D
- **Medium scrap (MEDIUM)**: 5–7 vertex irregular pentagon/hexagon
- **Whole torn note (HEAVY/SPECIAL)**: Rectangular 32×32 with torn edge shader — edge vertices randomly displaced 2–4px using noise in fragment shader
- **Gold spark (tier 4 only)**: Small triangular shard with additive blend, color #FFD700, lifetime 0.2–0.4s

**Torn edge shader approach (for HEAVY/SPECIAL):**
```gdscript
# Fragment shader — displace along paper edge using noise
float edge_noise = noise(UV * 20.0 + vec2(time * 0.1)) * 0.08
float edge_mask = step(0.42, UV.x) * step(UV.x, 0.58)  # horizontal strip
color.a *= 1.0 - edge_noise * edge_mask
```

No texture atlas — shapes are procedural. This ensures infinite variation and avoids atlas lookup overhead.

**Rule 4 — P1/P2 Color Assignment**

Particle color is driven by the **attacker's player identity**.

| Player | Color Name | Hex | Usage |
|--------|-----------|-----|-------|
| Player 1 | 晨曦橙 (Dawn Orange) | #F5A623 | All P1 attack particles |
| Player 2 | 梦境蓝 (Dream Cyan) | #4ECDC4 | All P2 attack particles |
| Gold Spark | 打勾金 (Check Gold) | #FFD700 | Tier 4 combo overflow only |

- `hit_vfx` color = `attacker_color` — looked up from `GameState.get_player_color(attacker_id)`
- `combo_escalation_vfx` color = `player_color` from signal
- `sync_burst_vfx`: P1 (orange) and P2 (blue) particles emitted simultaneously at same position, intertwined via helical motion + additive blend
- `rescue_vfx` color = `rescuer_color` from signal (rescuer's color, not rescued player's)

**Rule 5 — GPU vs CPU Particle Decision**

| Backend | Emitters | Rationale |
|---------|----------|-----------|
| `CPUParticles2D` | `hit_vfx`, `combo_escalation_vfx`, `rescue_vfx`, `boss_death_vfx` | One-shot bursts; deterministic; `restart()` called per signal; no GPU overhead for short-lived effects |
| `GPUParticles2D` | `sync_burst_vfx` | Continuous intertwined orange+blue spiral stream while sync chain active; complex motion; additive blend for glow |

**Sync burst motion**: Helical intertwined — P1 particles spiral clockwise, P2 particles spiral counterclockwise, radius 30–50px, pitch 40px/revolution. Achieved via `orbital_velocity` in CPUParticles2D.

**Rule 6 — Z-Order (back to front)**

```
[Environment sprites]     z = 0 to 50
[Boss sprites]            z = 50 to 100
[Player sprites]         z = 100 to 150
[Hit VFX / Combo VFX]     z = 200        ← particles above characters
[Sync Burst VFX]          z = 210        ← sync burst above hit VFX
[Rescue VFX]              z = 220        ← rescue above sync burst
[UI Layer]                z = 300+       ← always on top
```

All VFX emitters are children of a dedicated `VFXLayer` Node2D at z=200. Particles do **NOT** collide with world geometry — purely decorative visual feedback.

**Rule 7 — Combo Tier Escalation**

| Tier | Trigger | Hit VFX Modifier | Color Effect | Additional |
|------|---------|------------------|-------------|------------|
| Tier 1 | 1–9 hits | Base count | Player color 100% | None |
| Tier 2 | 10–19 hits | Count × 1.2x | Player color +20% brightness | Small paper swirl (3–5 particles) |
| Tier 3 | 20–39 hits | Count × 1.5x | Player color +40% + glow | Heavy debris burst + 10% gold sparks |
| Tier 4 | 40+ hits | Count × 2.0x | Gold tint overlay | Paper confetti explosion (30 particles) + gold burn |

**Combo escalation VFX** (`combo_tier_escalated` signal):

| From Tier | To Tier | Burst Count | Color | Behavior |
|-----------|---------|------------|-------|----------|
| 1 → 2 | 8 | Player color +20% bright | Rising arc, then disperse |
| 2 → 3 | 15 | Player color +40% bright + glow | Burst outward + brief screen shake |
| 3 → 4 | 25 | Gold #FFD700 | Explosive upward burst + gold sparks |

**Rule 8 — Sync Burst Specifics**

Sync burst is visually distinct from normal hits:

- **Emission**: P1 (orange #F5A623) + P2 (blue #4ECDC4) particles emitted simultaneously at `position`
- **Count**: 15 orange + 15 blue per frame while sync chain active
- **Motion**: Helical intertwined — orange clockwise, blue counterclockwise, radius 30–50px
- **Blend mode**: Additive (`BR_MODE_ADD`) — orange + blue overlap = bright white-yellow at intersections
- **Sync burst trigger** (3 consecutive sync hits): One-shot burst of 50 particles (orange + blue + gold) at `position`, lifetime 1.2s, explosive outward

**Rule 9 — Rescue VFX Specifics**

One-shot burst at the **rescued player's position** on `rescue_triggered(position, rescuer_color)`:

| Parameter | Value |
|-----------|-------|
| Particle count | 12–18 |
| Color | `rescuer_color` (#F5A623 or #4ECDC4) |
| Motion | Upward arc toward rescued player (positive Y in Godot 2D) |
| Speed | 120–180 px/s initial, decelerates |
| Lifetime | 0.4–0.7s |
| Shape | Small paper scraps + golden spark accents |
| Hand glow | Circular glow sprite at rescue position, color = rescuer_color, radius 40px, fades over 0.5s |

Motion is a narrow 45° cone upward, slightly biased toward rescuer's position.

**Rule 10 — Performance Budget**

| Budget Item | Limit |
|-------------|-------|
| Max concurrent particles | 300 |
| Max concurrent emitters | 15 |
| Max particle texture size | 512×512 |
| Max frame time for VFX | 2ms |
| Draw calls budget (total) | 150/frame |

**Budget enforcement**: `VFXManager` tracks active particle count and emitter count. If either exceeds 80% of limit, new emitters are queued (FIFO, max queue depth 10). Emitters that complete are returned to pool, not freed.

**Rule 11 — Emitter Pooling**

All emitters are pooled and reused — zero `instantiate()` calls during gameplay.

- **Pool size**: 20 emitters pre-instantiated at game start
- **Pooled**: All CPUParticles2D emitters (`hit_vfx`, `combo_escalation_vfx`, `rescue_vfx`, `boss_death_vfx`)
- **GPU emitters** (`sync_burst_vfx`): 2 instances, toggled active/inactive — long-lived continuous emitters
- **Checkout**: `VFXManager.emit(signal_name, params)` → checks out emitter → configures → `restart()`
- **Checkin**: When `is_emitting() == false` and `get_particle_count() == 0` → return to pool

### States and Transitions

**Emitter states (per pooled emitter):**

| State | Description | Enter | Exit |
|-------|-------------|-------|------|
| `IDLE` | In pool, available | Checkin complete | Checkout requested |
| `ACTIVE` | Emitting particles | `restart()` called | All particles expired |
| `COOLDOWN` | Brief pause between uses | Emitter finishes but pool is full | Next checkout |

**Sync burst emitter states:**

| State | Description | Enter | Exit |
|-------|-------------|-------|------|
| `SYNC_IDLE` | No sync chain | sync_chain_length drops to 0 | sync_chain_length ≥ 1 |
| `SYNC_STREAM` | Continuous intertwined particles | sync_chain_length ≥ 1 | sync_chain_length drops to 0 |
| `SYNC_BURST` | One-shot burst on 3rd consecutive sync | sync_burst_triggered fires | Lifetime expires |

### Interactions with Other Systems

**Input ← CombatSystem (upstream):**
- `hit_landed(attack_type, position, direction)` → `hit_vfx` emitter fires

**Input ← ComboManager (upstream):**
- `combo_tier_escalated(tier, player_color)` → `combo_escalation_vfx` fires
- `sync_burst_triggered(position)` → `sync_burst_vfx` fires, triggers `SYNC_BURST` state

**Input ← CoopManager (upstream):**
- `rescue_triggered(position, rescuer_color)` → `rescue_vfx` fires

**Input ← BossAIManager (upstream, proposed):**
- `boss_defeated(position, boss_type)` → `boss_death_vfx` fires

**Output ← (none — VFX is purely visual, does not affect game state)**

## Formulas

**1. Hit VFX Composite Count**

```
composite_count = base_particles(attack_type) × combo_multiplier(tier) + gold_sparks(tier) + confetti_bonus(tier)
gold_sparks = floor(base_particles × 0.10)  if tier ≥ 3  else 0
confetti_bonus = 30  if tier = 4  else 0
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| attack_type | enum | {LIGHT, MEDIUM, HEAVY, SPECIAL} | Player's chosen attack category |
| tier | int | 1–4 | Current combo tier |
| base_particles | int | attack-type-specific min–max | Random value in attack type's range |
| combo_multiplier | float | {1.0, 1.2, 1.5, 2.0} | Tier-based scaling multiplier |
| gold_sparks | int | 0 or floor(base × 0.10) | Gold sparkle count (Tier 3+) |
| confetti_bonus | int | 0 or 30 | Gold confetti explosion (Tier 4 only) |
| **composite_count** | int | [0, ~118] | Total particle count for this emitter |

**Output Range:** Bounded. Minimum 0. Maximum ~118 (`SPECIAL max 40 × Tier 4 multiplier 2.0 + Tier 4 gold sparks ~8 + confetti 30`).

**Example:** attack_type=HEAVY (base [18,25]), tier=4, base=22:
`22 × 2.0 + floor(22×0.10) + 30 = 44 + 2 + 30 = 76 particles`

---

**2. Hit VFX Speed (parabolic arc)**

```
vfx_velocity = (speed_horizontal, speed_vertical - gravity)
speed_horizontal = random_in_range(speed_min, speed_max)
speed_vertical = random_in_range(speed_min, speed_max)
gravity = match attack_type:
  LIGHT/MEDIUM → 400 px/s²
  HEAVY/SPECIAL → 200 px/s²
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| attack_type | enum | {LIGHT, MEDIUM, HEAVY, SPECIAL} | Attack category |
| speed_min/max | int | attack-type-specific | Speed range in px/s |
| speed_horizontal | int | [speed_min, speed_max] | Random horizontal velocity component |
| speed_vertical | int | [speed_min, speed_max] | Random upward velocity component |
| gravity | int | 200 or 400 | Downward acceleration (heavier = more gravity) |
| **vfx_velocity** | vec2 | unbounded | 2D velocity for particle physics |

**Output Range:** Both components unbounded individually. `speed_horizontal` and `speed_vertical` within attack-type range. Gravity pulls `speed_vertical` negative over time, simulating arc trajectory.

**Example:** attack_type=HEAVY (speed [150, 200]), gravity=120:
`speed_horizontal=175, speed_vertical=188 → (175, 68) → particle arcs upward then falls`

---

**3. Sync Burst Particle Blend**

```
blended_color = lerp(color_orange, color_blue, blend_weight)
blend_weight = clamp(overlap_intensity × 2.0 - 0.5, 0.0, 1.0)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| color_orange | vec3 | (1.0, 0.65, 0.0) | RGB for P1 sync particles |
| color_blue | vec3 | (0.3, 0.8, 0.77) | RGB for P2 sync particles |
| overlap_intensity | float | 0.0–1.0 | How densely orange and blue particles overlap |
| blend_weight | float | 0.0–1.0 | Mixing ratio (0.0 = full orange, 1.0 = full blue) |
| **blended_color** | vec3 | (0.0–1.0, 0.0–1.0, 0.0–1.0) | Final RGB at overlap point |

**Dead zone:** overlap_intensity < 0.25 → orange dominant; > 0.75 → blue dominant. Only 0.25–0.75 band creates smooth blend.

**Output Range:** Each RGB component clamped to [0.0, 1.0].

**Example:** overlap_intensity=0.5:
`blend_weight = 0.5 → blended_color = lerp((1.0,0.65,0.0), (0.3,0.8,0.77), 0.5) = (0.65, 0.725, 0.385)`

---

**4. Performance Budget Check**

```
can_emit = (current_particles + pending_particles < MAX_PARTICLES)
         AND (active_emitters < MAX_EMITTERS)
pending_particles = hit_vfx_count + combo_escalation_count
hit_vfx_count = base_particles(attack_type) × combo_multiplier(tier)
combo_escalation_count = tier × 15

if not can_emit:
    queue_emitter(emitter, priority=tier)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| current_particles | int | 0–300 | Particles currently active from all emitters |
| active_emitters | int | 0–15 | Emitters currently firing |
| pending_particles | int | 0–∞ | Particle count from the new triggering event |
| hit_vfx_count | int | 5–80 | Particle count for hit VFX |
| combo_escalation_count | int | 15–60 | Particle count for combo escalation burst |
| MAX_PARTICLES | int | 300 | Hard ceiling for concurrent particles |
| MAX_EMITTERS | int | 15 | Hard ceiling for concurrent emitters |
| tier | int | 1–4 | Combo tier (higher = dequeued first when queue drains) |
| **can_emit** | bool | {true, false} | True = fires immediately; False = queued |

**Example (budget overflow):**
```
Player A (SPECIAL, tier=4): pending = 40×2.0 + 4×15 = 140
Player B (HEAVY, tier=3): pending = 22×1.5 + 3×15 = 78
current_particles=200, active_emitters=12
can_A = (200+140 < 300) → false → queued (priority 4)
can_B = (200+78 < 300) → false → queued (priority 3)
```

## Edge Cases

**If a new event is queued when the event queue is already at max depth (10):**
The oldest entry in the queue is silently dropped (FIFO eviction), and the new event is enqueued. The queue never grows beyond 10 entries. *Rationale: Most recent events preserved; oldest assumed least relevant.*

**If `hit_landed` and `combo_tier_escalated` fire simultaneously (same frame):**
Both events processed independently. Each spawns its own emitter request. Separate emitter slots, run concurrently. No priority ordering between them within the same frame.

**If `combo_tier_escalated` fires with a lower tier than the currently playing tier (tier regression):**
No de-escalation animation. Any running emitter for the higher tier is immediately cancelled. If the new lower tier has a persistent emitter running, it continues. If no emitter exists for the lower tier, nothing spawns. *Rationale: Combo break is an abrupt negative event — playing de-escalation VFX would feel anticlimactic and delay the player's next attempt to rebuild combo.*

**If `boss_death_vfx` is triggered while a `hit_vfx` emitter is still active:**
Boss death VFX takes absolute visual priority. All active hit VFX emitters are force-cancelled immediately. Boss death one-shot then spawns at boss center position. *Rationale: Boss death is the climactic end-state; no hit impact effects should compete visually.*

**If `sync_burst_triggered` and `rescue_triggered` fire the same frame at the same position:**
Sync burst one-shot spawns and plays. Rescue VFX one-shot is dropped for that frame (not queued). Rescue event is lost — no retry. *Rationale: Sync burst is the higher-stakes combat moment; rescue VFX is secondary cooperative indicator.*

**If sync-burst chain breaks while continuous GPU emitter is still active (before 3rd consecutive hit):**
Continuous emitter immediately deactivated. In-flight particle animation allowed to finish naturally (natural lifetime decay, no forced kill). Burst one-shot NEVER triggered unless 3rd consecutive sync hit lands.

**If `rescue_triggered` fires at a position where an active `hit_vfx` emitter exists:**
Rescue VFX spawns at rescued player's position. Overlapping hit VFX continues playing unmodified — no cancellation, no blending. Both VFX stacks visually. *Rationale: Both events are semantically important and do not interfere with each other's meaning.*

**If combo tier regresses from tier 4 to tier 3:**
Any tier-4-specific emitter (persistent or one-shot) is force-cancelled. If tier 3 has an associated persistent emitter, it is started or restarted. No transition VFX between tiers. *Rationale: Tier changes are instantaneous at game-logic level; VFX mirrors with immediate state switches.*

## Dependencies

**Upstream dependencies:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| CombatSystem | `hit_landed(attack_type, position, direction)` | Signal |
| ComboManager | `combo_tier_escalated(tier, player_color)`, `sync_burst_triggered(position)` | Signal |
| CoopManager | `rescue_triggered(position, rescuer_color)` | Signal |
| BossAIManager | `boss_defeated(position, boss_type)` (proposed — pending BossAI adoption) | Signal |

**Downstream dependents:** None — VFX is purely visual feedback, does not emit signals back to game systems.

```gdscript
# VFXManager (Autoload)

# Input signals
signal hit_landed(attack_type: String, position: Vector2, direction: Vector2)  # from CombatSystem
signal combo_tier_escalated(tier: int, player_color: Color)  # from ComboManager
signal sync_burst_triggered(position: Vector2)  # from ComboManager
signal rescue_triggered(position: Vector2, rescuer_color: Color)  # from CoopManager
signal boss_defeated(position: Vector2, boss_type: String)  # from BossAIManager (proposed)

# Methods
func emit_hit(attack_type: String, position: Vector2, direction: Vector2)
func emit_combo_escalation(tier: int, player_color: Color)
func emit_sync_burst(position: Vector2)
func emit_rescue(position: Vector2, rescuer_color: Color)
func emit_boss_death(position: Vector2, boss_type: String)
func get_active_particle_count() -> int
func get_active_emitter_count() -> int
```

## Tuning Knobs

| Parameter | Default | Safe Range | Effect |
|-----------|---------|-----------|--------|
| `PARTICLE_COUNT_LIGHT` | 5–8 | 3–15 | Light attack particle count |
| `PARTICLE_COUNT_MEDIUM` | 10–15 | 6–25 | Medium attack particle count |
| `PARTICLE_COUNT_HEAVY` | 18–25 | 10–40 | Heavy attack particle count |
| `PARTICLE_COUNT_SPECIAL` | 30–40 | 15–60 | Special attack particle count |
| `PARTICLE_SPEED_LIGHT` | 180–250 px/s | 100–400 | Light attack particle speed |
| `PARTICLE_SPEED_MEDIUM` | 220–300 px/s | 150–450 | Medium attack particle speed |
| `PARTICLE_SPEED_HEAVY` | 150–200 px/s | 80–350 | Heavy attack particle speed |
| `PARTICLE_SPEED_SPECIAL` | 200–280 px/s | 120–400 | Special attack particle speed |
| `GRAVITY_LIGHT_MEDIUM` | 400 px/s² | 200–600 | Downward gravity for light/medium particles |
| `GRAVITY_HEAVY_SPECIAL` | 200 px/s² | 100–400 | Downward gravity for heavy/special particles |
| `COMBO_TIER2_MULTIPLIER` | 1.2 | 1.0–1.5 | Particle count multiplier at tier 2 |
| `COMBO_TIER3_MULTIPLIER` | 1.5 | 1.2–2.0 | Particle count multiplier at tier 3 |
| `COMBO_TIER4_MULTIPLIER` | 2.0 | 1.5–3.0 | Particle count multiplier at tier 4 |
| `GOLD_SPARK_RATIO` | 0.10 | 0.05–0.20 | Fraction of particles that become gold sparks at tier 3+ |
| `CONFETTI_BONUS_COUNT` | 30 | 15–50 | Extra confetti particles at tier 4 |
| `SYNC_BURST_COUNT` | 50 | 25–80 | Particles in sync burst one-shot |
| `SYNC_CONTINUOUS_RATE` | 15+15 per frame | 10–30 per color | Continuous sync emitter emission rate |
| `RESCUE_PARTICLE_COUNT` | 12–18 | 8–30 | Rescue VFX particle count |
| `RESCUE_LIFETIME` | 0.4–0.7s | 0.2–1.2s | Rescue particle lifetime |
| `MAX_POOL_EMITTERS` | 20 | 15–30 | Pre-instantiated emitter pool size |
| `MAX_PARTICLES` | 300 | 200–500 | Hard ceiling for concurrent particles |
| `MAX_EMITTERS` | 15 | 10–25 | Hard ceiling for concurrent active emitters |
| `QUEUE_MAX_DEPTH` | 10 | 5–20 | Maximum VFX event queue depth |
| `BUDGET_THRESHOLD` | 0.80 | 0.70–0.95 | Fraction of budget at which queuing begins |

## Visual/Audio Requirements

### VFX Visual Requirements per Emitter Type

| Emitter | Shape | Color | Motion | Special Effects | Z-Order |
|---------|-------|-------|--------|-----------------|---------|
| **hit_vfx** (LIGHT) | 4–6 vertex irregular quad, 6–10px | P1: #F5A623 / P2: #4ECDC4 | Outward radial parabolic arc, 360°, gravity 400px/s² | — | z=200 |
| **hit_vfx** (MEDIUM) | 5–7 vertex pentagon/hex, 10–16px | Same as above | Outward radial parabolic arc, 360°, gravity 400px/s² | — | z=200 |
| **hit_vfx** (HEAVY/SPECIAL) | 32×32 torn-edge rectangle, procedural shader | Same + Tier 3+: gold sparks #FFD700 | 120° cone in attack direction, gravity 200px/s² | Tier 4: gold confetti burst (30 particles) | z=200 |
| **combo_escalation_vfx** | Mixed: paper scraps + rising arcs | Player color + brightness boost per tier | Tier 2: rise then disperse; Tier 3: burst outward; Tier 4: golden confetti rain | Tier 3+: screen shake (2px, 100ms); Tier 4: gold burn glow | z=200 |
| **sync_burst_vfx** (continuous) | Small triangular shards, 4–8px | P1 #F5A623 + P2 #4ECDC4 simultaneously | Helical intertwined: P1 clockwise, P2 counterclockwise; radius 30–50px | Additive blend (orange+blue overlap = white-yellow glow) | z=210 |
| **sync_burst_vfx** (one-shot burst) | Mixed: paper scraps + gold sparks, 8–16px | Orange + blue + #FFD700 gold | Explosive radial outward, lifetime 1.2s | Additive blend; brief screen flash (50ms) | z=210 |
| **rescue_vfx** | Small paper scraps + golden spark accents, 6–12px | `rescuer_color` | 45° cone upward toward rescued player; 120–180 px/s, decelerating | Hand glow: circular sprite, 40px radius, fades over 0.5s | z=220 |
| **boss_death_vfx** | Large torn paper fragments, 24–48px + gold confetti 8–16px | Boss accent color → #FFD700 gold fade | Explosive upward burst → slow parabolic fall (paper rain) | Force-cancel all other VFX; slowmo 200ms @ 0.5x | z=200 |

### Animation & Visual Style Constraints

**Hand-torn paper aesthetic (per art bible "便签爆炸"):**
- Particle edges must show hand-torn irregularity — no perfectly straight edges
- No geometric shapes (circles, squares) — all particles are irregular polygons or torn rectangles
- 1–2px dark brown (#3D2914) stroke outline where visible at runtime
- Flat color fills, no gradients on particles — color variance from per-particle hue shift within palette family
- Lifetime fade: alpha fade over final 20% of lifetime — no hard pop-out
- Scale: 1.0 → 1.1 in first 10% of lifetime ("pop" feel), shrink to 0.8 at end
- Gravity: always downward (positive Y in Godot 2D) except rescue_vfx (intentional upward arc)
- All CPUParticles2D emitters use `one_shot = true` except sync_burst_vfx continuous mode
- Max concurrent particles: 300 (performance budget — Rule 10)
- Particle density at any single point must not exceed 15 overlapping particles

**Blend modes:**
- NORMAL for all one-shot bursts
- ADDITIVE (BR_MODE_ADD) only for sync_burst_vfx orange+blue overlap glow

### Art Bible Principles Mapping

| Art Bible Principle | Application to VFX |
|---------------------|-------------------|
| 便签爆炸 | ALL emitters use paper scrap/torn-note shapes — no abstract geometric particles |
| 梦境温度 | Hand-torn irregular edges, flat fills, warm brown outlines |
| 并肩的印记 | sync_burst_vfx intertwines P1+P2 particles; rescue_vfx uses rescuer's color |
| 轻快节奏 | Particles must not linger >1.5s; screen shake ≤2px, ≤100ms |
| 协作的温暖 | rescue_vfx hand glow + sparks distinct from combat宣泄感 |

### Audio Cue Mapping per VFX Event

| VFX Event | Audio Cue | Characteristics | Spatial? |
|-----------|-----------|----------------|-----------|
| hit_vfx (LIGHT) | `sfx_hit_light` | Percussive "pap" — 50–80ms, high-frequency | Position-panned to hit origin |
| hit_vfx (MEDIUM) | `sfx_hit_medium` | "Thwack" — 80–120ms, mid-freq + low-end thump | Position-panned |
| hit_vfx (HEAVY) | `sfx_hit_heavy` | "Slam" — 150–200ms, low-end + transient click, screen-shake sync | Position-panned |
| hit_vfx (SPECIAL) | `sfx_hit_special` | "Slam" + golden chime overtone — 200–300ms | Position-panned |
| combo escalation T1→T2 | `sfx_combo_tier2` | Rising "whoosh" — 100ms, pitch rises 1/3 octave | Global |
| combo escalation T2→T3 | `sfx_combo_tier3` | "Burst" + screen shake sync — 150ms | Global |
| combo escalation T3→T4 | `sfx_combo_tier4` | Golden chime cascade — 400ms, harmonic overtones, reverb | Global |
| sync burst (continuous) | `sfx_sync_stream` | Looping ambient "whir" — P1+P2 harmonic interval, low volume | Position-panned to midpoint between P1 and P2 |
| sync burst (one-shot) | `sfx_sync_burst` | "Explosion" + golden chime — 300ms, stereo widener | Global |
| rescue_vfx | `sfx_rescue` | Warm "whoosh-up" + chime — 200ms, ascending pitch | Position-panned to rescued player |
| boss_death_vfx | `sfx_boss_death` | "Paper tear" crescendo → golden cascade — 800ms, reverb-heavy | Global |

**Audio-Visual sync tolerances:**

| VFX Event | Max A/V Offset |
|-----------|----------------|
| hit_vfx (all) | 3 frames (~50ms @ 60fps) |
| combo_escalation_vfx | 5 frames (~83ms) |
| sync_burst one-shot | 3 frames |
| rescue_vfx | 4 frames (~67ms) |
| boss_death_vfx | 6 frames (~100ms) — slowmo provides forgiveness window |

## UI Requirements

粒子特效系统 does not own any UI elements. VFX elements render at z=200–220, above character sprites but below the UI layer (z=300+).

No dedicated UI requirements for this system.

**📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:particle-vfx-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-01 | Signal `hit_landed(LIGHT, pos, dir)` received | VFXManager emits | hit_vfx fires, 5–8 particles, 360° spread, gravity 400px/s², P1/P2 color |
| AC-02 | Signal `hit_landed(SPECIAL, pos, dir)` received | VFXManager emits | hit_vfx fires, 30–40 particles, 120° cone, gravity 200px/s², gold sparks |
| AC-03 | Signal `combo_tier_escalated(2, player_color)` received | VFXManager emits | combo_escalation_vfx fires, 8 burst particles, player_color +20% bright |
| AC-04 | Signal `combo_tier_escalated(4, player_color)` received | VFXManager emits | combo_escalation_vfx fires, 25 burst particles, gold #FFD700, explosive upward |
| AC-05 | sync_chain_length = 1 | sync_burst_triggered not yet fired | sync_burst_vfx continuous emitter activates (P1+P2 intertwined helical, additive blend) |
| AC-06 | 3rd consecutive sync hit | sync_burst_triggered fires | sync_burst_vfx one-shot burst: 50 particles (orange+blue+gold), additive blend |
| AC-07 | sync_chain drops to 0 | Chain broken | sync_burst continuous emitter immediately deactivated |
| AC-08 | Signal `rescue_triggered(pos, rescuer_color)` received | VFXManager emits | rescue_vfx fires, 12–18 particles, upward arc, rescuer_color, hand glow sprite |
| AC-09 | Boss HP = 0 | `boss_defeated(pos, type)` fires | boss_death_vfx fires, gold confetti rain; all active hit emitters force-cancelled |
| AC-10 | current_particles = 250 (>80% of 300) | New hit_vfx event | New emitter queued (not dropped), FIFO order |
| AC-11 | Queue depth = 10 | New event arrives | Oldest queued event dropped, new event enqueued |
| AC-12 | combo tier = 3 | Query hit_vfx count | hit_vfx particles × 1.5, gold sparks appear |
| AC-13 | combo tier = 4 | Query hit_vfx count | hit_vfx particles × 2.0, gold confetti bonus (30 particles) |
| AC-14 | Emitter completes (is_emitting=false, count=0) | Checkin | Emitter returned to pool, available for next checkout |
| AC-15 | Emitter pool exhausted (20 active) | New event arrives | Event queued (max depth 10, FIFO) |
| AC-16 | sync_burst P1+P2 overlap | Additive blend | orange+blue overlap produces white-yellow glow |
| AC-17 | combo break (tier 4 → tier 2) | combo_tier_escalated(2) fires | Tier 4 emitter force-cancelled immediately, no de-escalation animation |
| AC-18 | sync_burst + rescue same frame at same position | Both signals | sync_burst wins, rescue VFX dropped |

## Open Questions

| # | Question | Owner | Target |
|---|----------|-------|--------|
| 1 | `boss_defeated` signal: defined in this GDD but needs BossAI adoption — exact signature `boss_defeated(position, boss_type)` confirmed? | Boss AI designer | Boss AI GDD |
| 2 | `hit_landed` signal: confirmed as `(attack_type, position, direction)` with direction as Vector2? | Combat designer | Combat GDD |
| 3 | Screen shake at tier 3+ — is this owned by VFX system or a separate screen-shake system? | Game Designer | Systems integration |
| 4 | `sfx_sync_stream` looping audio — seamless loop point needed from audio team. Does this exist in the audio asset pipeline? | Audio team | Audio system GDD |
| 5 | Is the torn-edge procedural shader feasible in Godot 4.6 GPUParticles2D, or does it require a custom shader pass? | Technical artist | Engine verification |
| 6 | Hand glow sprite for rescue — is this a sprite asset or a shader-generated radial glow? | Art production | Asset spec |
