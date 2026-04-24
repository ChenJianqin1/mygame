# 双人协作系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 — 协作即意义

## Overview

双人协作系统是游戏"协作即意义"的物理实现——它定义了P1和P2如何互相依赖、互救、和同步。系统追踪两位玩家的共享状态：一方倒下时另一方可以实施救援，被救一方短暂无敌后重返战场。当两位玩家都在场时，战斗系统的所有数值计算都会考虑协作修正；当只剩一人时，系统切换为solo模式，保持游戏可推进但不享受协作奖励。

从玩家视角，这是一个"我不只是为自己而战"的系统。你的成功会惠及队友，你的失败也需要队友来弥补。Boss的某些攻击会刻意针对这个协作设计——迫使两人分开施压，或逼迫一人营救另一人。这种机制让协作不是选项而是必需。

## Player Fantasy

**玩家幻想：** 每一次救援都是一声"我接住你了"。

当队友倒下时，这不是失败——这是你成为英雄的机会。你冲向倒下的同伴，按下救援键，你的手掌伸出——闪烁着你的颜色（晨曦橙或梦境蓝）——把同伴拉回战场。他们在你身旁站起，短暂无敌的星光环绕，两人一起再次冲向Boss。救援是温暖的、鼓励的，而不是沉重的——没人会被责备，只有感激。

**情感锚点：**
- **被救者的感激** — "谢谢你来救我"不是羞耻，是信任
- **救援者的力量感** — 在队友最需要的时候成为依靠
- **重逢的喜悦** — 两人再次并肩作战的确定性

**反面教材（避免）：**
- 队友倒下时大范围屏幕变暗或警报——违反Pillar 4轻快节奏
- 救援有惩罚性冷却导致两人都陷入危险——制造焦虑而非协作
- 救援动画拖沓超过1秒——破坏战斗节奏

## Detailed Design

### Core Rules

**Rule 1 — Parallel HP + Downtime**
- Each player has an independent HP pool (PLAYER_MAX_HP = 100)
- Hitting 0 HP → player enters `DOWNTIME` state (not death)
- Both players in `DOWNTIME` simultaneously → lose a life or game over
- Player death does NOT reset partner's combo (preserved from combat system)

**Rule 2 — Instant Rescue**
- Rescuer must be within RESCUE_RANGE (~150–200px) of downed partner
- Press rescue input when in range → partner instantly revives
- Rescued player receives RESCUED_IFRAMES_DURATION (1.5s) of invincibility
- Rescue hand glows in rescuer's color (#F5A623 for P1, #4ECDC4 for P2)
- RESCUE_WINDOW = 3 seconds — if timer expires before rescue, player is OUT

**Rule 3 — CRISIS State**
- Both players below 30% HP simultaneously → CRISIS state activates
- CRISIS visual: screen edge glow pulses orange+blue blend, paper debris intensifies
- CRISIS mechanical: 25% damage reduction for BOTH players
- When either player exits <30%, CRISIS ends immediately

**Rule 4 — Co-op Passive Bonus**
- While both players are above 0 HP: both receive COOP_BONUS = +10% base damage
- Stacks with combo multiplier — separate reward track
- Solo player (partner in downtime): SOLO_DAMAGE_REDUCTION = 25% (compensation)
- Solo player does NOT receive co-op passive bonus

**Rule 5 — Co-op Visual Identity**
- P1 uses #F5A623 (晨曦橙), P2 uses #4ECDC4 (梦境蓝)
- Rescue effects always show rescuer's color
- CRISIS blend creates orange+blue midpoint (#7F96A6)

### States and Transitions

| State | Description | Enter | Exit |
|-------|-------------|-------|------|
| `ACTIVE` | Both players alive, normal play | Default / rescue complete | Either hits 0 HP |
| `DOWNTIME` | Player at 0 HP, waiting for rescue | HP reaches 0 | Rescued or window expires |
| `RESCUED` | Brief invincibility after rescue | Rescue triggered | I-frames end |
| `CRISIS` | Both below 30% HP | Both < 30% simultaneously | Either >= 30% |
| `OUT` | Player timed out | Rescue window expires | — |

**Rescue Flow:**
- P1 or P2 hits 0 → `DOWNTIME` state, RESCUE_WINDOW timer starts (3s)
- Partner approaches within 150–200px → presses rescue → instant revive
- Rescued player enters `RESCUED` (1.5s i-frames) → returns to `ACTIVE`
- If timer expires → player enters `OUT` state (cannot be revived until next life)

### Interactions with Other Systems

**输入 ← 输入系统:**
- `rescue_input(player_id)` — triggers rescue attempt

**输出 → 战斗系统:**
- `coop_bonus_active(multiplier: float)` — +10% damage when both alive
- `solo_mode_active(player_id: int)` — 25% damage reduction for solo player

**输出 → UI系统:**
- `player_downed(player_id: int)` — show rescue timer countdown
- `player_rescued(player_id: int, rescuer_color: Color)` — rescue success animation
- `crisis_state_changed(is_crisis: bool)` — screen edge effect toggle
- `player_out(player_id: int)` — mark player as timed-out

**输出 → 粒子特效系统:**
- `rescue_triggered(position: Vector2, rescuer_color: Color)` — hand glow + spark
- `crisis_activated()` — blended orange+blue edge glow

**输出 → 音频系统:**
- `crisis_audio_activate()` — urgent music layer

## Formulas

**1. Co-op Damage Bonus**

```
effective_damage = base_damage * attack_type_multiplier * (1.0 + combo_multiplier) * (1.0 + COOP_BONUS)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_damage | — | int | 8–20 | From attack type |
| attack_type_multiplier | — | float | {LIGHT:0.8, MEDIUM:1.0, HEAVY:1.5, SPECIAL:2.0} | From combat system |
| combo_multiplier | — | float | 1.0–4.0 | From combo system (solo or sync, pre-applied) |
| COOP_BONUS | — | float | 0.10 | +10% when both alive |
| **effective_damage** | result | int | 10.56–158.4 | Final damage with all bonuses |

**Example:** base=15, HEAVY(1.5), combo=2.0, both alive: `15 * 1.5 * 3.0 * 1.10 = 74.25`

---

**2. Solo Mode Damage Reduction**

```
effective_damage = incoming_damage * (1.0 - SOLO_DAMAGE_REDUCTION)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| SOLO_DAMAGE_REDUCTION | — | float | 0.25 | 25% reduction when solo |
| **effective_damage** | result | int | — | Reduced incoming damage |

---

**3. CRISIS Damage Reduction**

```
effective_damage = incoming_damage * (1.0 - CRISIS_DAMAGE_REDUCTION)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| CRISIS_DAMAGE_REDUCTION | — | float | 0.25 | 25% reduction in CRISIS state |
| **effective_damage** | result | int | — | Reduced incoming damage |

> CRISIS and SOLO reductions do NOT stack — CRISIS takes priority when both apply.

---

**4. Rescue Window Timer**

```
rescue_timer = clamp(RESCUE_WINDOW - time_since_down, 0.0, RESCUE_WINDOW)
player_out = (rescue_timer <= 0.0)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| time_since_down | — | float | 0.0–∞ | Seconds since player hit 0 HP |
| RESCUE_WINDOW | — | float | 3.0s | Window before player is OUT |
| **rescue_timer** | result | float | 0.0–3.0 | Remaining rescue time |

---

**5. Rescue Range Check**

```
is_in_range = (rescuer_position.distance_to(downed_position) <= RESCUE_RANGE)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| RESCUE_RANGE | — | float | 150–200px | Proximity required for rescue |
| **is_in_range** | result | bool | — | True if rescue is possible |

---

**6. CRISIS State Detection**

```
is_crisis = (P1_hp < PLAYER_MAX_HP * 0.30) AND (P2_hp < PLAYER_MAX_HP * 0.30)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| PLAYER_MAX_HP | — | int | 100 | Per-player HP |
| **is_crisis** | result | bool | — | True when both below 30% |

## Edge Cases

**1. Rescuer is hit during rescue approach**
- Rescue can be interrupted — player can be hit while moving toward downed partner
- Rescue state is not i-frame protected — must reach partner before being hit or time out

**2. Downed player is hit during DOWNTIME**
- Boss/attack can hit the DOWNTIME player (they're vulnerable on the ground)
- Visual: paper debris scatters around the downed player — danger cue
- This creates urgency: the rescuing player needs to be fast

**3. CRISIS state + one player rescued**
- Example: P1 is rescued, both now active — if either is still <30%, CRISIS continues
- CRISIS ends only when both are >=30% OR one hits 0 HP (enters DOWNTIME)

**4. Rescue window expires during hitstop**
- Hitstop pauses the game, not the rescue timer — timer is real-time
- If rescue window was at 0.5s when hitstop started, it continues during hitstop

**5. Both players hit 0 simultaneously (same frame)**
- Both enter DOWNTIME simultaneously — no rescue possible
- Immediately lose a life or trigger game over (team wipe scenario)

**6. Rescue range edge case (exactly at boundary)**
- If distance == RESCUE_RANGE: rescue IS allowed (boundary inclusive)

**7. Solo player is OUT (rescue window expired)**
- Player is OUT — cannot be rescued until next life
- Partner must survive alone until life lost / game over
- OUT player remains visible on screen as a ghost (visual feedback)

**8. CRISIS + one player OUT**
- CRISIS requires BOTH players — a solo player at any HP cannot trigger it
- Solo player just gets SOLO_DAMAGE_REDUCTION

## Dependencies

**Upstream dependencies:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| 输入系统 | `rescue_input(player_id)` signal, dual-input handling | Signal |
| 战斗系统 | `player_health_changed(current, max)` signal, damage calculation | Signal |

**Downstream dependents:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| UI系统 | player_downed, player_rescued, crisis_state_changed signals | Signal |
| 粒子特效系统 | rescue_triggered, crisis_activated signals | Signal |
| 战斗系统 | coop_bonus_active, solo_mode_active signals | Signal |
| 音频系统 | crisis_audio_activate signal | Signal |

**Interface definition:**

```gdscript
# CoopManager (Autoload)

# Input from InputSystem
signal rescue_input(player_id: int)

# Output signals
signal coop_bonus_active(multiplier: float)  # +10% when both alive
signal solo_mode_active(player_id: int)  # 25% damage reduction
signal player_downed(player_id: int)  # rescue timer starts
signal player_rescued(player_id: int, rescuer_color: Color)
signal crisis_state_changed(is_crisis: bool)
signal player_out(player_id: int)
signal rescue_triggered(position: Vector2, rescuer_color: Color)
signal crisis_activated()

# Methods
func is_in_rescue_range(rescuer_id: int, downed_id: int) -> bool
func get_rescue_timer(player_id: int) -> float
func is_crisis_active() -> bool
```

## Tuning Knobs

| Parameter | Default | Safe Range | Effect |
|-----------|---------|-----------|--------|
| `PLAYER_MAX_HP` | 100 | 50–200 | Per-player HP |
| `RESCUE_WINDOW` | 3.0s | 1.5–5.0s | Time before downed player is OUT |
| `RESCUE_RANGE` | 175px | 100–250px | Proximity required for rescue |
| `RESCUED_IFRAMES_DURATION` | 1.5s | 0.5–3.0s | Invincibility after rescue |
| `COOP_BONUS` | 0.10 | 0.05–0.20 | +% damage when both alive |
| `SOLO_DAMAGE_REDUCTION` | 0.25 | 0.15–0.40 | % damage reduction when solo |
| `CRISIS_DAMAGE_REDUCTION` | 0.25 | 0.15–0.40 | % damage reduction in CRISIS |
| `CRISIS_HP_THRESHOLD` | 0.30 | 0.20–0.50 | HP% threshold for CRISIS |

## Visual/Audio Requirements

**Rescue Visual (hand-painted paper aesthetic):**
- Rescue hand glows in rescuer's color (#F5A623 for P1, #4ECDC4 for P2)
- Brief sparkle effect on rescued player (paper confetti burst, 8–12 particles)
- Rescued player i-frames shown as soft pulsing glow around character
- Screen does NOT darken on DOWNTIME — just a subtle vignette pulse

**CRISIS Visual:**
- Screen edge glow blends orange (#F5A623) and blue (#4ECDC4) at midpoint (#7F96A6)
- Pulsing glow rhythm: 0.5s on, 0.5s off
- Paper debris density increases in background
- Color saturation on both characters increases subtly

**Player OUT Visual:**
- Downed player becomes semi-transparent ghost
- No dark/negative coloring — ghost is desaturated player's color
- Ghost drifts slightly toward partner (connection visual)

**Co-op Passive Bonus Visual:**
- When COOP_BONUS active: small colored glow around both player characters
- Subtle, not distracting but visible enough to read

**Audio:**
- DOWNTIME: soft "down" stinger (paper rustle, not alarming)
- Rescue success: warm "whoosh" + brief chime in rescuer's pitch
- CRISIS activation: music layer shifts to urgent undertone
- Player OUT: quiet fade — no punishment sound

## UI Requirements

- **Individual HP bars**: P1 bar bottom-left (orange), P2 bar bottom-right (blue)
- **Rescue timer**: Circular countdown near downed player — 3s → 0 with radial drain animation
- **CRISIS indicator**: Screen-edge glow (purely visual, no text)
- **OUT indicator**: Ghost silhouette icon next to partner's HP bar
- **Co-op bonus active**: Small colored aura icon near HP bars when COOP_BONUS applies

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-01 | P1 at full HP, P2 at full HP | Normal play | COOP_BONUS = +10% active |
| AC-02 | P1 hits 0 HP | P1 enters DOWNTIME | Rescue timer starts (3s) |
| AC-03 | P1 DOWNTIME, P2 approaches within 175px | P2 presses rescue | P1 instantly revives with 1.5s i-frames |
| AC-04 | P1 DOWNTIME, timer reaches 0 | Without rescue | P1 is OUT |
| AC-05 | P1 OUT | P2 continues fight | P2 gets SOLO_DAMAGE_REDUCTION = 25% |
| AC-06 | Both players below 30 HP | Both below threshold | CRISIS state activates |
| AC-07 | CRISIS active, P1 rescued to 50 HP | P1 >= 30% | CRISIS ends (P2 still <30%) |
| AC-08 | Both players hit 0 same frame | Simultaneous DOWNTIME | Lose a life / game over |
| AC-09 | P1 is DOWNTIME, rescue in progress | Boss attacks P1 | P1 takes damage (vulnerable) |
| AC-10 | Rescue window at 0.5s, hitstop starts | Hitstop (5 frames) | Timer continues — still 0.5s after hitstop |
| AC-11 | P1 at 100 HP, combo=2.0, both alive | Query damage | effective_damage = base * 3.0 * 1.10 |
| AC-12 | Rescue range = exactly 175px | P2 distance to P1 = 175 | is_in_range = TRUE |
| AC-13 | Player OUT | Next life begins | Player returns to ACTIVE state |

## Open Questions

| # | Question | Owner | Target Date |
|---|----------|-------|-------------|
| 1 | Does the game have a shared LIVES system (3 lives = game over), or is game over instant on team wipe? | Game Designer | Co-op verification |
| 2 | Does rescue require a specific button or automatic when in range + pressing any action? | Input system verification | Input GDD |
| 3 | Should OUT players be visible as ghosts on screen, or completely invisible? | UX review | Visual review |
| 4 | Does CRISIS state affect audio only, or trigger a music change? | Audio review | Audio system GDD |
