# Boss AI系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 3 — 战斗即隐喻

## Overview

Boss AI系统是Boss的"意志"——它决定Boss何时攻击，用什么招式、如何与玩家的行动相互作用。系统读取玩家位置、连击状态、双人协作状态，然后决定当前应该进攻、追击、还是喘息。攻击模式不是随机的，而是精心设计的"机制即隐喻"：Deadline Boss会从屏幕边缘碾压过来（截稿压力），玩家必须不断前进才能不被吞噬。

从玩家视角，Boss的每一次攻击都是在讲述一个职场困境的故事。你不是在打一个血条——你是在战胜让你窒息的源头。Boss AI让这个故事可玩，而不是只是看一段动画。

## Player Fantasy

**玩家幻想：** Boss不是要杀死你的怪物——Boss就是你无法逃脱的处境。

Deadline Boss的AI不是一个"攻击玩家"的AI，而是一个"压缩空间"的AI。它从屏幕后方不断挤压可战斗区域，迫使两位玩家不断前进。当一位玩家落后时，Boss的压迫会微妙地放缓——刚好够队友伸手拉住他。这种"被处境追赶"的感觉才是"战斗即隐喻"的核心：Deadline不是要打败你，Deadline就是你要打败的东西。

**情感锚点：**
- **共同被追赶感** — 两位玩家被同一个处境追赶，不是各自为战
- **隐喻实现的快感** — "这个攻击方式就是截稿压力本身"的那一刻
- **队友即救生员** — Boss天然设计出需要救援的时机，协作是必然不是偶然

**反面教材（避免）：**
- Boss攻击过于随机——破坏"机制即隐喻"，隐喻变成装饰
- 压迫过于强烈导致无法呼吸——违反Pillar 4，应该是紧张但不死
- 单人可以通过走位存活——协作必须是存活的唯一途径

## Detailed Design

### Core Rules

**Rule 1 — Hybrid FSM + Behavior Tree Architecture**
- **Macro layer (FSM)**: IDLE/ATTACKING/HURT/PHASE_CHANGE/DEFEATED — defined in combat system
- **Micro layer (Behavior Tree)**: Within ATTACKING, selects attack pattern by phase + player position
- Compression is a **continuous parallel process** — runs every frame regardless of boss state

**Rule 2 — Attack Pattern Availability by Phase**

| Pattern | Metaphor | Phase 1 (100%–60%) | Phase 2 (60%–30%) | Phase 3 (30%–0%) |
|---------|---------|---------------------|-------------------|------------------|
| Pattern 1: Relentless Advance | 截稿压力 from behind | ✓ Always | ✓ Always | ✓ Always |
| Pattern 2: Paper Avalanche | 工作堆积 | ✗ | ✓ Available | ✓ Available |
| Pattern 3: Panic Overload | Deadline panic | ✗ | ✗ | ✓ Available |

**Rule 3 — Compression Process (Continuous)**
- Arena boundary advances from behind at COMPRESSION_BASE_SPEED
- Phase 1: Pure compression — no frontal attacks
- Phase 2: Compression + Paper Avalanche frontal projectiles
- Phase 3: All patterns + increased aggression
- Speed modulated by: phase_multiplier, rescue_multiplier, crisis_multiplier

**Rule 4 — Context-Aware Compression Modulation**

```
Every frame:
  if P1_or_P2_downed:
    compression_speed = base * 0.5  # rescue window
  elif P1_behind OR P2_behind:
    compression_speed = base * 0.6  # 40% slower
  elif both_in_CRISIS:
    compression_speed = base * 1.2  # 20% faster
  else:
    compression_speed = base * phase_multiplier
```

**Rule 5 — Behavior Tree Attack Selection (within ATTACKING)**
Priority order:
1. If player downed → pause frontal attacks (2s), slow compression
2. If in rescue mode → slow compression, no new frontal attack
3. Otherwise → select pattern by phase availability + player position

**Rule 6 — Compression Damage**
- Players in danger zone take COMPRESSION_DAMAGE = 5hp/sec (flat drain)
- Player must dodge OUT of danger zone — not immune while inside
- Creates urgency without instant-death

**Rule 7 — Phase Transition**
- Trigger: Boss HP crosses 60% or 30%
- Boss enters PHASE_CHANGE: compression pauses, visual cue plays
- Transition duration: ~1 second (brief mercy window)
- After: compression resumes at new speed

**Rule 8 — Attack Interval**
- MIN_ATTACK_INTERVAL = 1.5 seconds between frontal attacks
- Compression never pauses — it only changes speed

### States and Transitions

| State | Description | Enter | Exit |
|-------|-------------|-------|------|
| `IDLE` | Waiting, no active attack | Default / attack complete / hurt ends | AI selects attack |
| `ATTACKING` | Executing attack pattern | AI decision complete | Animation ends |
| `HURT` | Staggered from player hit | player_attacked signal | Duration ends |
| `PHASE_CHANGE` | Transitioning phases | HP crosses threshold | Transition complete |
| `DEFEATED` | Boss HP = 0 | HP reaches 0 | — |

### Interactions with Other Systems

**输入 ← 碰撞检测系统:**
- `player_detected(player)` — boss aware of player
- `player_lost(player)` — player left detection range
- `player_hurt(player, damage)` — used for AI aggression modulation

**输入 ← 战斗系统:**
- `player_attacked(boss, damage)` — trigger HURT state

**输入 ← Combo连击系统:**
- `combo_hit(attack_type, combo_count, is_grounded)` — AI reads combo count

**输入 ← 双人协作系统:**
- `player_downed(player_id)` — trigger rescue mode
- `crisis_state_changed(is_crisis)` — trigger crisis multiplier

**输出 → 战斗系统:**
- `boss_attack_started(attack_pattern)` — for hitbox management
- `boss_phase_changed(new_phase)` — for UI and difficulty scaling

**输出 → UI系统:**
- `boss_phase_warning(phase)` — phase transition approaching
- `boss_attack_telegraph(pattern)` — incoming attack indicator

## Formulas

**1. Boss HP by Progress**

```
boss_max_hp = floor(BASE_BOSS_HP * progression_multiplier * boss_index_multiplier * coop_scaling)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_BOSS_HP | — | int | 500 | First boss baseline |
| progression_multiplier | — | float | 1.0–2.5 | Session progression |
| boss_index_multiplier | — | float | {1.0, 1.3, 1.6, 2.0} | Per-boss difficulty |
| coop_scaling | — | float | {solo:1.0, co-op:1.5} | Two-player scaling |
| **boss_max_hp** | result | int | 750–3000 | Final boss HP |

**Example:** Boss 3 co-op: `500 * 1.5 * 1.6 * 1.5 = 1800`

---

**2. Compression Speed**

```
compression_speed = BASE_COMPRESSION_SPEED * phase_multiplier * rescue_multiplier * crisis_multiplier
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_COMPRESSION_SPEED | — | float | 32px/s | Baseline wall speed |
| phase_multiplier | — | float | {1.0, 1.5, 2.0} | Per phase |
| rescue_multiplier | — | float | {0.5, 0.6, 1.0} | Player rescue state |
| crisis_multiplier | — | float | {1.0, 1.2} | CRISIS state |
| **compression_speed** | result | float | 16–64px/s | Effective wall speed |

**Example:** Phase 2, player behind: `32 * 1.5 * 0.6 = 28.8px/s`

---

**3. Phase HP Thresholds**

```
current_phase = 1 if hp_ratio > 0.60 else 2 if hp_ratio > 0.30 else 3
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| hp_ratio | — | float | 0.0–1.0 | Current HP / max HP |
| **current_phase** | result | int | 1, 2, 3 | Current phase |

---

**4. Attack Cooldown**

```
attack_cooldown = max(MIN_ATTACK_INTERVAL, base_cooldown * hp_multiplier)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_cooldown | — | float | 2.5s | Full-health interval |
| hp_multiplier | — | float | 1.0–0.5 | Linear decrease to 50% HP |
| MIN_ATTACK_INTERVAL | — | float | 1.5s | Floor |
| **attack_cooldown** | result | float | 1.5–2.5s | Time between attacks |

---

**5. Compression Damage (Danger Zone)**

```
compression_damage = COMPRESSION_DAMAGE_RATE * delta_time
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| COMPRESSION_DAMAGE_RATE | — | float | 5hp/s | Flat drain per second |
| delta_time | — | float | per frame | Time in danger zone |
| **compression_damage** | result | float | 0–∞ | Cumulative damage |

---

**6. Rescue Slowdown Threshold**

```
player_behind = (trailing_player.x < compression_wall.x + MERCY_ZONE)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| MERCY_ZONE | — | float | 100px | Grace zone before slowdown |
| **player_behind** | result | bool | — | True if in danger |

## Edge Cases

**1. Player downed during PHASE_CHANGE**
- Rescue window starts immediately upon down
- Compression already paused during transition — rescue is easy

**2. Both players downed simultaneously**
- No rescue possible — triggers game over / lose life per co-op system

**3. Player exits danger zone during compression advance**
- No further compression damage once out — clean exit

**4. Boss HURT during active frontal attack**
- Current attack animation continues (hitbox stays active)
- Compression continues (HURT is stagger, not retreat)

**5. Phase transition during attack animation**
- Phase transition can trigger mid-attack
- Current attack completes under old phase rules

**6. Panic Overload (Phase 3) + both in CRISIS**
- CRISIS +20% speed stacks with Phase 3 compression — hardest scenario

**7. Player rescued during compression advance**
- Compression slows to 50% for 2s — allows regrouping

**8. Boss defeated during compression advance**
- Compression immediately stops, all animations cancel

## Dependencies

**Upstream dependencies:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| 战斗系统 | `player_attacked(boss, damage)` signal, boss state machine | Signal |
| 碰撞检测系统 | `player_detected`, `player_lost`, `player_hurt` signals | Signal |
| Combo连击系统 | `combo_hit` signal | Signal |
| 双人协作系统 | `player_downed`, `crisis_state_changed` signals | Signal |

**Downstream dependents:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| 即时难度调整 | Boss HP, phase, attack patterns | Signals |
| UI系统 | `boss_phase_warning`, `boss_attack_telegraph` signals | Signal |

**Interface definition:**

```gdscript
# BossAIManager (Autoload)

# Input signals
signal player_attacked(boss: Node2D, damage: int)  # from CombatSystem
signal player_detected(player: Node2D)  # from CollisionSystem
signal player_lost(player: Node2D)  # from CollisionSystem
signal player_hurt(player: Node2D, damage: float)  # from CollisionSystem
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)  # from ComboSystem
signal player_downed(player_id: int)  # from CoopSystem
signal crisis_state_changed(is_crisis: bool)  # from CoopSystem

# Output signals
signal boss_attack_started(attack_pattern: String)
signal boss_phase_changed(new_phase: int)
signal boss_phase_warning(phase: int)
signal boss_attack_telegraph(pattern: String)
```

## Tuning Knobs

| Parameter | Default | Safe Range | Effect |
|-----------|---------|-----------|--------|
| `BASE_BOSS_HP` | 500 | 300–1000 | Baseline HP |
| `BASE_COMPRESSION_SPEED` | 32px/s | 16–64px/s | Wall advance speed |
| `COMPRESSION_DAMAGE_RATE` | 5hp/s | 2–15hp/s | Danger zone drain |
| `MIN_ATTACK_INTERVAL` | 1.5s | 1.0–3.0s | Time between frontal attacks |
| `MERCY_ZONE` | 100px | 50–200px | Grace zone for rescue slowdown |
| `PHASE_2_THRESHOLD` | 0.60 | 0.50–0.70 | HP% for Phase 2 |
| `PHASE_3_THRESHOLD` | 0.30 | 0.20–0.40 | HP% for Phase 3 |
| `RESCUE_SLOWDOWN` | 0.5 | 0.3–0.7 | Compression speed when player downed |
| `RESCUE_SUSPENSION` | 2.0s | 1.0–4.0s | Frontal attack pause when player downed |

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-01 | Boss HP = 100% | Query phase | current_phase = 1 |
| AC-02 | Boss HP = 59% | Query phase | current_phase = 2 |
| AC-03 | Boss HP = 29% | Query phase | current_phase = 3 |
| AC-04 | Phase 1 boss | AI selects attack | Only Pattern 1 available |
| AC-05 | Phase 2 boss | AI selects attack | Patterns 1 and 2 available |
| AC-06 | Player1 behind MERCY_ZONE | Compression check | compression_speed *= 0.6 |
| AC-07 | Player1 downed | Compression check | compression_speed *= 0.5 |
| AC-08 | Both players in CRISIS | Compression check | compression_speed *= 1.2 |
| AC-09 | Boss HP crosses 60% | During combat | PHASE_CHANGE state entered |
| AC-10 | Boss in HURT state | Attack selected | No new attack — blocked |
| AC-11 | Player in danger zone | 1 second passes | Takes 5 damage |
| AC-12 | Both players downed | Same frame | Game over triggered |
| AC-13 | Boss full HP, MIN_ATTACK_INTERVAL=1.5s | Attack cooldown | 2.5s (no floor hit) |

## Open Questions

| # | Question | Owner | Target |
|---|----------|-------|--------|
| 1 | How many total attack patterns should future bosses have beyond MVP 3? | Game Designer | Boss AI verification |
| 2 | Does AI need a difficulty scaling input from 即时难度调整? | System design | Boss AI + difficulty co-design |
| 3 | Should panic overload (Phase 3) be a specific combined attack or pure speed increase? | Game Designer | Phase 3 design |
