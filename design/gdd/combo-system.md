# Combo连击系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 — 协作即意义

## Overview

Combo连击系统是游戏的"成就感引擎"——它追踪每次命中、累积连击数、在视觉和数值上奖励持续命中。战斗系统发送`combo_hit`信号，连击系统计算当前连击窗口是否有效、是否需要重置，并向UI系统、粒子特效系统和战斗系统本身分发连击状态。

从玩家视角，每次命中都在累积一个"能量球"——连击数越高，伤害倍率越高（最高3倍），视觉反馈越华丽。连击断了不惩罚，但会失去能量积累的奖励。这种"不断则奖"的机制驱动玩家追求流畅、持续的命中体验，而不是保守战术。

## Player Fantasy

**玩家幻想：** 连击是两个人的心跳同步。

两位玩家不是各自攒连击，而是在**同频命中**中放大彼此的力量。当P1和P2同时命中Boss，连击数短暂融合——晨曦橙与梦境蓝交织成一股绳索，Boss在"双剑合璧"的攻势下踉跄。连击系统用数字告诉玩家：你们越同步，力量越强。

**情感锚点：**
- **同步感** — "我们同时打中了"不只是巧合，是配合的证明
- **成就感** — 40连击的"同步爆发"比40连击的单人秀更满足
- **可量化的协作** — 连击数是协作的无声证明，数字本身就是对话

**反面教材（避免）：**
- 把连击做成竞争（谁打得更帅、谁连击更高）——破坏协作感
- 连击断了有大面积惩罚（屏幕变暗、音效下降）——违反Pillar 4轻快节奏
- Solo combo可以达到与sync combo同等的最高倍率——破坏协作激励

## Detailed Design

### Core Rules

**Rule 1 — Combo Window (Time-based Decay)**

Each player's combo has an independent **combo window timer** measured in real seconds, not game frames.

- **COMBO_WINDOW_DURATION**: 1.5 seconds
- The timer starts at 0.0s on the first hit
- Each subsequent hit **resets** the timer to 0.0s and increments combo_count by 1
- If the timer reaches 1.5s without a new hit, combo_count resets to 0 for that player
- **Hitstop does NOT extend the window**: hitstop is a visual freeze, not elapsed time — the timer is already paused during hitstop (real-time freeze), so the window duration is unaffected

**Rule 2 — Sync Bonus (Simultaneous Hit Detection)**

When both players land a hit on the boss within a tight timing window, a **Sync Burst** is triggered.

- **SYNC_WINDOW**: 5 frames (~83ms at 60fps; ~69ms at 72fps)
- Sync is evaluated on every hit from either player:
  - When P1 lands a hit, check if P2 landed a hit within the last SYNC_WINDOW frames
  - When P2 lands a hit, check if P1 landed a hit within the last SYNC_WINDOW frames
  - If both players hit within the window, the hit is flagged as **SYNC**
- A **Sync Chain** is a sequence of 3 or more consecutive SYNC hits — triggers the Sync Burst visual
- P1 and P2 combo_count values are **not merged** — each stays independent; sync is a bonus modifier, not a merge

**Rule 3 — Combo Multiplier (Separate Caps for Solo and Sync)**

The combo multiplier scales damage. Solo combo and sync combo have different ceilings:

- **Solo combo multiplier**: `min(1.0 + combo_count * 0.05, 3.0)` — caps at 40 combo (3.0x)
- **Sync combo multiplier**: `min(1.0 + combo_count * 0.05, 4.0)` — caps at 60 combo (4.0x)
- Both multipliers use the same increment (0.05 per combo) and same signal (`combo_hit`)
- When a hit is SYNC, the **sync multiplier** applies instead of the solo multiplier
- Below 40 combo, sync and solo produce identical multiplier values (both = `1.0 + count * 0.05`)
- Above 40 combo, solo multiplier locks at 3.0x; sync multiplier continues scaling to 4.0x
- **MAX_COMBO_COUNT_DISPLAY** = 99 (display cap; internal counter has no hard cap)

> **Design rationale**: Cooperation is the path to max multiplier (Pillar 1). A solo player can reach 3.0x and feel powerful, but a synchronized pair can reach 4.0x — a tangible reward for maintained coordination that is impossible to achieve alone.

**Rule 4 — What Triggers Combo Decay**

Combo decay (combo_count reset to 0) is triggered by **time only**:

- **TIME decay only**: combo_count resets when COMBO_WINDOW_DURATION (1.5s) expires with no new hit
- **DAMAGE taken does NOT reset combo** — player can be hit and retain their combo
- **MOVING away from boss does NOT reset combo** — position is irrelevant
- **PLAYER DEATH does NOT reset partner's combo** — P1 death leaves P2 combo intact; P2 death leaves P1 combo intact
- **BOSS PHASE CHANGE does NOT reset combo** — combo persists across phase transitions
- The only way to lose combo is to stop hitting for 1.5 consecutive seconds

**Rule 5 — Sync Burst Visual Trigger**

Sync Burst is a visual state, not a mechanical one:

- **SYNC_CHAIN_THRESHOLD**: 3 consecutive SYNC hits triggers Sync Burst
- Sync Burst is a visual feedback layer — it does not affect damage or multiplier calculation
- Sync Burst visuals: orange (#F5A623) and blue (#4ECDC4) particle trails intertwine, screen edge glow pulses in alternating colors
- Breaking a Sync Chain (landing a non-SYNC hit or letting the window expire) ends Sync Burst visuals immediately — combo_count itself is unaffected unless Rule 1 also triggers

### States and Transitions

**Combo State Machine (per player):**

| State | Description | Enter | Exit |
|-------|-------------|-------|------|
| `IDLE` | No active combo | Default / combo reset | First hit lands |
| `ACTIVE` | Combo building | First hit | Window expires (1.5s) |
| `SYNC` | Sync hit registered | P1+P2 hit within 5 frames | Chain breaks |
| `SYNC_BURST` | 3+ consecutive SYNC hits | 3rd consecutive SYNC hit | Non-SYNC hit or window expires |
| `DECAY` | Window about to expire | Timer < 0.3s remaining | Timer hits 0 OR new hit |

**Sync Chain behavior:**
- `SYNC` state: at least 1 consecutive sync hit
- `SYNC_BURST` state: 3+ consecutive sync hits — triggers orange+blue particle burst
- Any non-SYNC hit ends the chain; new SYNC hit starts fresh count

### Interactions with Other Systems

**输入 ← 战斗系统:**
- Signal: `combo_hit(attack_type: String, combo_count: int, is_grounded: bool)` — each hit increments combo_count, resets timer

**输出 → UI系统:**
- Signal: `combo_tier_changed(tier: int, player_id: int)` — triggers tier-based UI scaling
- Signal: `sync_chain_active(chain_length: int)` — activates sync burst visuals
- Signal: `combo_break(player_id: int)` — triggers combo break visual (no penalty effect)

**输出 → 粒子特效系统:**
- Signal: `sync_burst_triggered(position: Vector2)` — orange+blue intertwined particles
- Signal: `combo_tier_escalated(tier: int, player_color: Color)` — escalation VFX

**输出 → 战斗系统:**
- Signal: `combo_multiplier_updated(multiplier: float, player_id: int)` — combat uses for damage calc
- Method: `get_combo_multiplier(player_id: int) -> float` — query current multiplier

**输出 → 音频系统:**
- Signal: `combo_tier_audio(tier: int)` — different hit sounds per tier (tier 3+ gets stinger)

## Formulas

**1. Combo Multiplier (Solo)**

```
solo_multiplier = min(1.0 + combo_count * 0.05, 3.0)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| combo_count | — | int | 0–99 | Current combo count for this player |
| **solo_multiplier** | result | float | 1.0–3.0 | Solo damage multiplier |

**Example:** `combo_count=20 → 1.0 + 20*0.05 = 2.0x`

---

**2. Combo Multiplier (Sync)**

```
sync_multiplier = min(1.0 + combo_count * 0.05, 4.0)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| combo_count | — | int | 0–99 | Current combo count at time of sync hit |
| **sync_multiplier** | result | float | 1.0–4.0 | Sync damage multiplier (cooperation bonus) |

**Example:** `combo_count=50 → min(1.0 + 50*0.05, 4.0) = 3.5x` (solo would be locked at 3.0x)

> **Key difference**: Solo caps at 3.0x (40 combo). Sync caps at 4.0x (60 combo) — cooperation reaches a higher ceiling.

---

**3. Combo Window Timer**

```
combo_timer = clamp(time_since_last_hit, 0.0, COMBO_WINDOW_DURATION)
combo_resets = (combo_timer >= COMBO_WINDOW_DURATION)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| time_since_last_hit | — | float | 0.0–∞ | Seconds since last combo_hit |
| COMBO_WINDOW_DURATION | — | float | 1.5 | Window before combo reset |
| **combo_timer** | result | float | 0.0–1.5 | Current timer position |
| **combo_resets** | result | bool | — | True when timer expires |

**Hitstop behavior**: Timer is NOT extended by hitstop. hitstop is a real-time freeze, so the timer already pauses during it — no special handling needed.

---

**4. Sync Detection**

```
is_sync = (abs(P1_hit_frame - P2_hit_frame) <= SYNC_WINDOW)
sync_chain_length = count of consecutive is_sync=true hits
triggers_sync_burst = (sync_chain_length >= 3)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| P1_hit_frame | — | int | 0–∞ | Frame P1 landed this hit |
| P2_hit_frame | — | int | 0–∞ | Frame P2 landed this hit |
| SYNC_WINDOW | — | int | 5 frames | Max frames apart for sync |
| **is_sync** | result | bool | — | True if hit counts as synchronized |
| **sync_chain_length** | result | int | 0–∞ | Consecutive sync hit count |
| **triggers_sync_burst** | result | bool | — | True at 3+ consecutive sync hits |

---

**5. Combo Tier Thresholds**

```
tier = 0 (IDLE) if combo_count == 0
tier = 1 if 0 < combo_count <= 9
tier = 2 if 10 <= combo_count <= 19
tier = 3 if 20 <= combo_count <= 39
tier = 4 if combo_count >= 40
```

| Tier | Name | Trigger | Visual Intensity |
|------|------|---------|-----------------|
| 0 | IDLE | combo_count = 0 | None |
| 1 | Normal | 1–9 | Subtle pulse, default color |
| 2 | Rising | 10–19 | Moderate glow, +20% brightness |
| 3 | Intense | 20–39 | Heavy glow + screen shake, +40% brightness |
| 4 | Overdrive | 40+ | Peak effects (paper debris explosion, full saturation) |

**Color assignment**: P1 uses #F5A623 (晨曦橙), P2 uses #4ECDC4 (梦境蓝). At sync burst (tier 3+, 3+ consecutive sync hits), colors intertwine.

## Edge Cases

**1. Player dies mid-combo**
- P1 death: P1 combo resets to 0, P2 combo continues unchanged
- P2 death: P2 combo resets to 0, P1 combo continues unchanged
- The living player's combo is never affected by partner's death

**2. Both players hit simultaneously (same frame)**
- Both hits register as SYNC
- Both combo_count values increment independently
- Both receive the sync multiplier for that hit
- Sync chain counter increments for both

**3. Sync chain broken by non-SYNC hit**
- Non-SYNC hit ends the chain for both players immediately
- Sync Burst visuals end; chain counter resets to 0
- The hit itself still counts normally

**4. Combo window expires during hitstop**
- hitstop is a real-time freeze — timer does NOT advance during hitstop
- If window was at 1.4s when hitstop started, it remains at 1.4s when hitstop ends

**5. 99+ combo (display overflow)**
- MAX_COMBO_COUNT_DISPLAY = 99
- combo_count continues incrementing internally (no hard cap)
- Display shows "99+" after 99
- Multiplier formula uses actual count (not display cap)

**6. Boss defeated mid-combo**
- combo_count does NOT reset — player keeps count into next boss
- Momentum carries across the session

**7. Sync hit with only one player having active combo**
- Example: P1 has combo_count=20, P2 is IDLE (0)
- P1's hit is SYNC, P2's hit is also SYNC
- P1 gets sync_multiplier applied (higher than solo at same count)
- P2 starts their own combo from their count

## Dependencies

**Upstream dependencies:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| 战斗系统 | `combo_hit` signal with attack_type, combo_count, is_grounded | Signal |
| 输入系统 | (indirect — combat system already depends on input) | — |

**Downstream dependents:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| UI系统 | combo_tier_changed, sync_chain_active, combo_break signals | Signal |
| 粒子特效系统 | sync_burst_triggered, combo_tier_escalated signals | Signal |
| 战斗系统 | combo_multiplier_updated signal, get_combo_multiplier() method | Signal + method |
| Boss AI系统 | `combo_hit` signal — Boss根据连击数调整行为 | Signal |
| 音频系统 | combo_tier_audio signal | Signal |

**Interface definition:**

```gdscript
# ComboManager (Autoload)

# Input from CombatSystem
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)

# Output signals
signal combo_multiplier_updated(multiplier: float, player_id: int)
signal combo_tier_changed(tier: int, player_id: int)
signal sync_chain_active(chain_length: int)
signal sync_burst_triggered(position: Vector2)
signal sync_window_opened(player_id: int, partner_id: int)  # 动画系统消费此信号
signal combo_tier_escalated(tier: int, player_color: Color)
signal combo_break(player_id: int)
signal combo_tier_audio(tier: int)

# Methods
func get_combo_multiplier(player_id: int) -> float
func get_combo_tier(player_id: int) -> int
func get_sync_chain_length(player_id: int) -> int
```

## Tuning Knobs

| Parameter | Default | Safe Range | Effect |
|-----------|---------|-----------|--------|
| `COMBO_WINDOW_DURATION` | 1.5s | 0.5–3.0s | Too short = impossible to maintain; too long = combo feels meaningless |
| `SYNC_WINDOW` | 5 frames | 3–10 frames | Too tight = unreachable; too loose = sync feels cheap |
| `SYNC_CHAIN_THRESHOLD` | 3 hits | 2–5 hits | Lower = easier burst; higher = more impressive when achieved |
| `COMBO_DAMAGE_INCREMENT` | 0.05 | 0.01–0.1 | Per-combo damage bonus (shared with combat system) |
| `SOLO_MAX_MULTIPLIER` | 3.0 | 2.0–5.0 | Solo combo damage cap |
| `SYNC_MAX_MULTIPLIER` | 4.0 | 3.0–6.0 | Sync combo damage cap (must be > SOLO_MAX) |
| `MAX_COMBO_COUNT_DISPLAY` | 99 | 50–999 | Display cap on combo counter |
| `COMBO_TIER_1_THRESHOLD` | 10 | Fixed | Start of Tier 2 visual escalation |
| `COMBO_TIER_2_THRESHOLD` | 20 | Fixed | Start of Tier 3 (shake + heavy glow) |
| `COMBO_TIER_3_THRESHOLD` | 40 | Fixed | Start of Tier 4 (overdrive / paper debris explosion) |

## Visual/Audio Requirements

**Combo tier visual escalation (hand-painted paper/note aesthetic):**

| Tier | Trigger | VFX | Color Effect |
|------|---------|-----|--------------|
| Tier 1 | 1–9 hits | Subtle hit spark | Default player color |
| Tier 2 | 10–19 hits | Paper scraps start swirling | +20% brightness |
| Tier 3 | 20–39 hits | Heavy paper debris + screen shake | +40% brightness, screen shake |
| Tier 4 Overdrive | 40+ hits | Paper debris explosion (confetti burst) | Full saturation + gold tint |

**Sync Burst visuals (3+ consecutive SYNC hits):**
- P1 orange (#F5A623) and P2 blue (#4ECDC4) particle trails intertwine mid-air
- Screen edge pulses alternating orange/blue glow
- At combo tier 3+, sync burst also triggers gold paper confetti rain
- Sync chain counter visible as small icons near the combo display

**Combo break visual:**
- Short paper flutter (3–5 small pieces dispersing)
- No dramatic effect — respects "no penalty" design
- Combo counter fades and resets

**Audio:**
- Tier 1–2: Standard hit sounds (paper slap)
- Tier 3: Deeper impact sound + subtle bass undertone
- Tier 4 Overdrive: Stinger sound + sustained energy tone
- Sync chain: Soft chime layer that builds with chain length

## UI Requirements

- **Combo counter**: Large number, center-bottom of screen, scales up with tier
- **P1/P2 distinction**: Small colored indicator (orange dot / blue dot) next to counter
- **Sync chain indicator**: Row of small icons below combo counter; fills as sync chain builds
- **Combo tier label**: Subtle text below counter ("Rising" / "Intense" / "OVERDRIVE")
- **No penalty UI on combo break**: Quiet reset, no "combo lost" text

## Acceptance Criteria

**Core Rules Tests (27 tests):**

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-01 | Player IDLE, no combo | First hit lands | combo_count=1, timer=0, state=ACTIVE |
| AC-02 | combo_count=5, timer=0.5s | 0.5s passes with no hit | combo_count=0, state=IDLE |
| AC-03 | combo_count=5, timer=1.4s | New hit lands | timer resets to 0, combo_count=6 |
| AC-04 | combo_count=20 (solo) | Query multiplier | solo_multiplier = 2.0 |
| AC-05 | combo_count=40 (solo) | Query multiplier | solo_multiplier = 3.0 (cap) |
| AC-06 | combo_count=40 (sync) | Query multiplier | sync_multiplier = 3.0 |
| AC-07 | combo_count=50 (sync) | Query multiplier | sync_multiplier = 3.5 |
| AC-08 | combo_count=60 (sync) | Query multiplier | sync_multiplier = 4.0 (cap) |
| AC-09 | P1 hits frame N, P2 hits frame N+3 | Sync check | is_sync = TRUE (3 <= 5) |
| AC-10 | P1 hits frame N, P2 hits frame N+7 | Sync check | is_sync = FALSE (7 > 5) |
| AC-11 | 2 consecutive SYNC hits | 3rd SYNC hit lands | sync_burst_triggered signal fires |
| AC-12 | SYNC_BURST active, non-SYNC hit | Hit lands | Sync Burst ends, chain resets |
| AC-13 | combo_count=8 | Calculate tier | tier=1 (Normal) |
| AC-14 | combo_count=15 | Calculate tier | tier=2 (Rising) |
| AC-15 | combo_count=25 | Calculate tier | tier=3 (Intense) |
| AC-16 | combo_count=45 | Calculate tier | tier=4 (Overdrive) |
| AC-17 | combo_count=99 | Display shows | "99+" |
| AC-18 | P1 takes damage | P1 combo | Unchanged (time-only decay) |
| AC-19 | P1 dies | P2 combo | Unchanged |
| AC-20 | P2 IDLE, P1 count=20, P2 hits sync | Hit lands | P2 gets sync_multiplier, starts from 1 |
| AC-21 | Boss defeated | Combo state | combo_count persists |
| AC-22 | combo_count=0 | Query multiplier | 1.0 |
| AC-23 | combo_count=100 | Internal count | Continues incrementing (display caps at 99) |
| AC-24 | Hitstop (5 frames), timer=1.4s | Hitstop ends | Timer still 1.4s |
| AC-25 | combo_tier changes 2→3 | UI update | combo_tier_changed(3, player_id) fires |
| AC-26 | Sync chain breaks | Visual state | sync_chain_active(0) fires |
| AC-27 | combo_count resets | UI signal | combo_break(player_id) fires |

## Open Questions

| # | Question | Owner | Target Date |
|---|----------|-------|-------------|
| 1 | Should sync hits count as 1.5 toward combo_count (faster sync escalation)? | Game Designer | Combo verification |
| 2 | Is 4.0x sync cap correct? Needs playtesting to validate | Game Designer | Playtest |
| 3 | Screen shake at tier 3 only, or also tier 4? | Game Designer | VFX review |
| 4 | Does combo carry across bosses in full game, or only within a session? | Game Designer | Session design |
