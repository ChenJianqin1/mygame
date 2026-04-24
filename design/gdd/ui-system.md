# UI系统

> **Status**: Designed
> **Author**: Claude Code
> **Last Updated**: 2026-04-16
> **Implements Pillar**: All (Presentation layer — serves all pillars)

## Overview

The UI system is the presentation layer that translates all game state into visible, readable feedback. It receives signals from Combo连击系统 (combo tier, sync chain, combo break), 双人协作系统 (player HP, rescue timer, crisis state, co-op bonus), and Boss AI系统 (boss HP, phase warnings, attack telegraphs). The system produces: player HP bars with individual identity colors, combo counters with tier-scaled feedback, rescue timers with radial countdown animation, boss phase warnings, and crisis state screen effects.

UI components live in dedicated `CanvasLayer` scenes using Godot `Control` nodes. All UI elements use the hand-painted paper aesthetic from the art bible — sticky-note HP bars, paper-torn borders, thumbtack icons — ensuring the UI is an extension of the dreamlike office battlefield, not a separate HUD layer.

## Player Fantasy

**"The UI is your heartbeat during the workday rush."**

The combo counter is your pulse — each hit pushes it higher, each tier escalation makes your screen feel more alive. The boss phase warnings are tempo markers: Phase 1 is the morning's manageable pace, Phase 2 is the pre-lunch crunch, Phase 3 is the final sprint. The rescue timer is a lifeline made visible — a circular countdown that says "your partner is coming" in the language of radial drain. When crisis hits (both players below 30% HP), the screen edge pulses with the blended orange-blue of two people holding on together. The UI doesn't just display information — it tells the story of your resistance, one signal at a time.

**Emotional anchors:**
- **Pulse visibility** — every significant action has a visible heartbeat response
- **Tempo storytelling** — boss phases read as the rhythm of a workday
- **Lifeline tangibility** — rescue isn't just a mechanic, it's a visible countdown to hope
- **Partnership glow** — crisis doesn't show danger numbers, it shows the bond straining

**反面教材（avoid）:**
- UI elements that block the action — violation of Pillar 4 (轻快节奏)
- Text-heavy indicators — the game is about combat, not reading (violates "no text" design)
- Punishing visuals on failure states — Game Over should be black-humor, not despair

## Detailed Design

### Core Rules

**Rule 1 — Component Inventory**

UI consists of 8 component types:
- `PlayerHPBar_P1` — P1 individual HP, bottom-left anchor, #F5A623 color identity
- `PlayerHPBar_P2` — P2 individual HP, bottom-right anchor, #4ECDC4 color identity
- `BossHPBar` — Boss HP, top-center, paper-torn borders, phase notch markers
- `ComboCounter_P1` / `ComboCounter_P2` — one per player, below respective HP bars
- `SyncChainIndicator` — center, between the two combo counters, shows consecutive sync hits
- `CoopBonusIndicator_P1` / `CoopBonusIndicator_P2` — small colored aura near respective HP bars
- `RescueTimer` — circular radial drain, follows downed player in screen space
- `ScreenStateManager` — manages TITLE / GAMEPLAY_HUD / PAUSED / BOSS_INTRO / GAME_OVER states

All components use hand-painted paper aesthetic: sticky-note HP bars, paper-torn borders, thumbtack icons, note-paper textures (per art bible Section 6/7).

**Rule 2 — Z-Order (back to front)**

| Order | Component | Layer |
|-------|-----------|-------|
| 1 | CrisisEdgeGlow | Layer 0 (behind all gameplay UI) |
| 2 | BossHPBar | Layer 1, top-center |
| 3 | PlayerHPBar_P1, PlayerHPBar_P2 | Layer 1, bottom-left/right |
| 4 | CoopBonusIndicator_P1, CoopBonusIndicator_P2 | Layer 1, adjacent to HP bars |
| 5 | ComboCounter_P1, ComboCounter_P2 | Layer 1, below respective HP bars |
| 6 | SyncChainIndicator | Layer 1, center between combo counters |
| 7 | RescueTimer | Layer 1, world-position projected to screen |
| 8 | BossPhaseWarning, AttackTelegraph | Layer 2, center screen, temporary |
| 9 | PauseMenu, GameOverScreen | Layer 3, blocks gameplay |
| 10 | ScreenFade | Layer 4, covers all |

**Rule 3 — Signal-Driven Updates**

UI subscribes to signals from autoloaded managers. No polling — all state changes flow through signals.

**From ComboManager:**
- `combo_tier_changed(tier, player_id)` → update counter scale/color
- `sync_chain_active(chain_length)` → update sync chain icon count
- `combo_break(player_id)` → reset counter, trigger flutter animation
- `combo_hit(attack_type, combo_count, is_grounded)` → increment counter

**From CoopManager:**
- `player_downed(player_id)` → spawn RescueTimer at player screen position
- `player_rescued(player_id, rescuer_color)` → remove RescueTimer, trigger sparkle
- `crisis_state_changed(is_crisis)` → enable/disable CrisisEdgeGlow
- `player_out(player_id)` → remove timer, show ghost icon next to partner HP bar
- `coop_bonus_active(multiplier)` → enable/disable CoopBonusIndicator glow

**From BossAIManager:**
- `boss_phase_changed(new_phase)` → shift HP bar color, update phase notches
- `boss_phase_warning(phase)` → flash phase warning at center screen
- `boss_attack_telegraph(pattern)` → show brief attack name + icon at center

**Rule 4 — Responsive Scaling**

- All UI uses `anchors_preset` for corner/edge pinning
- P1 bottom-left → `PRESET_BOTTOM_LEFT`, P2 bottom-right → `PRESET_BOTTOM_RIGHT`
- Boss HP top-center → `PRESET_TOP_CENTER`
- Stretch mode: `CanvasItem.STRETCH_MODE_DISABLED` with `STRETCH_ASPECT_KEEP_HEIGHT` for HP bars
- Minimum resolution: 1280x720. UI scales proportionally above this.
- Combo counter tier scaling uses `scale` property, not font size changes
- Fonts render at native resolution; scale up for tier 3–4 only

**Rule 5 — Pause Behavior**

- **Hitstop (1–6 frames)**: UI continues updating normally. Hitstop is a visual freeze for gameplay only; rescue timer advances in real-time during hitstop.
- **Full pause (pause menu open)**: All UI updates freeze EXCEPT rescue timer (frozen countdown visible — no further drain, elapsed time still shown).

**Rule 6 — Screen States and Transitions**

```
TITLE → (Start pressed) → GAMEPLAY_HUD
GAMEPLAY_HUD → (pause input) → PAUSED
PAUSED → (resume) → GAMEPLAY_HUD
GAMEPLAY_HUD → (boss engaged) → BOSS_INTRO → GAMEPLAY_HUD
GAMEPLAY_HUD → (both players OUT) → GAME_OVER
GAME_OVER → (Retry pressed, lives remain) → GAMEPLAY_HUD
GAME_OVER → (Title pressed) → TITLE
```

**BOSS_INTRO** state: Brief (1.5s) screen with boss name in hand-lettered style, boss silhouette, and "ready to fight" moment. Auto-transitions to GAMEPLAY_HUD when timer expires or player input detected.

**Rule 7 — Boss HP Bar**

- Position: top-center, 60% screen width
- Border style: paper-torn left/right edges (hand-painted aesthetic)
- Phase markers: visible notches at 60% and 30% thresholds
- Phase colors:
  - Phase 1 (100%–60%): calm blue-gray (#6B7B8C)
  - Phase 2 (60%–30%): amber warning (#D4A017)
  - Phase 3 (30%–0%): urgent red-orange (#E85D3B)
- Boss name displayed above bar in hand-lettered typography
- Width depletes left-to-right as HP decreases

**Rule 8 — Combo Counter Tier Scaling**

| Tier | Trigger | Scale | Visual Effect |
|------|---------|-------|---------------|
| 1 | 1–9 hits | 1.0x | Default player color, no glow |
| 2 | 10–19 hits | 1.15x | +20% brightness, subtle glow |
| 3 | 20–39 hits | 1.3x | Heavy glow, screen shake, +40% brightness |
| 4 | 40+ hits | 1.5x | Peak effects, gold tint, paper confetti particles |

- P1 counter uses #F5A623, P2 counter uses #4ECDC4
- Sync hits (tier 3+): orange+blue colors intertwine mid-display
- Counter shows "99+" after 99 but multiplier formula uses actual count
- SyncChainIndicator: row of icons below counters; fills as sync chain builds (3 icons = sync burst threshold)

**Rule 9 — Rescue Timer**

- Animation: circular radial drain (pie-chart countdown, not linear bar)
- Position: downed player's world position projected to screen space
- Color: rescuer's identity color (#F5A623 if P1 rescuer, #4ECDC4 if P2 rescuer)
- Duration: 3 seconds (matches CoopSystem RESCUE_WINDOW)
- On rescue: radial fills back up briefly, then disappears with sparkle
- On expire: timer disappears silently, ghost icon appears next to surviving partner's HP bar

**Rule 10 — CRISIS Visual**

- Effect: screen-edge vignette glow, 40px wide, color #7F96A6 (orange+blue midpoint)
- Pulse rhythm: 0.5s opacity 0.7 → 0.5s opacity 0.0 (on/off loop)
- Activation: `crisis_state_changed(true)` from CoopManager
- Deactivation: `crisis_state_changed(false)` — stops immediately
- Layer: behind HP/HUD elements (Layer 0), above gameplay world

**Rule 11 — Co-op Bonus Indicator**

- Visual: small colored aura (12px radius glow) adjacent to each player's HP bar
- P1 aura: #F5A623 orange. P2 aura: #4ECDC4 blue
- Activation: visible when COOP_BONUS (+10% damage) is active (both players alive above 0 HP)
- No text or icon — purely color glow
- Deactivates silently when solo mode triggers

### States and Transitions

**Screen-level states:**

| State | Description | Enter | Exit |
|-------|-------------|-------|------|
| `TITLE` | Title screen, start prompt | Default / from GAME_OVER | Start pressed → BOSS_INTRO |
| `BOSS_INTRO` | Boss name reveal, 1.5s | Boss engaged | Timer expires / any input → GAMEPLAY_HUD |
| `GAMEPLAY_HUD` | Full HUD active during combat | BOSS_INTRO ends / PAUSED resume | Pause → PAUSED / both OUT → GAME_OVER |
| `PAUSED` | Pause menu overlay, gameplay frozen | Pause input in GAMEPLAY_HUD | Resume → GAMEPLAY_HUD |
| `GAME_OVER` | Game over screen | Both players OUT | Retry → GAMEPLAY_HUD / Title → TITLE |

**HUD component states (per component):**

| Component | States | Transition Triggers |
|-----------|--------|---------------------|
| HPBar | NORMAL / LOW (< 30%) / CRITICAL (< 10%) | HP value changes |
| ComboCounter | IDLE (0) / ACTIVE (1+) / SYNC / OVERDRIVE (40+) | combo_hit / combo_break |
| RescueTimer | HIDDEN / COUNTING / EXPIRED | player_downed / timer=0 |
| CrisisEdgeGlow | OFF / PULSING | crisis_state_changed |
| BossHPBar | PHASE1 / PHASE2 / PHASE3 / DEFEATED | boss_phase_changed / boss_hp=0 |

**HP Bar color states:**
- NORMAL: full color (P1=#F5A623, P2=#4ECDC4)
- LOW (< 30%): desaturated + dim pulse
- CRITICAL (< 10%): flashing red tint overlay

### Interactions with Other Systems

**Input ← ComboManager (upstream):**
- `combo_tier_changed(tier, player_id)` → ComboCounter scales up and changes color
- `sync_chain_active(chain_length)` → SyncChainIndicator fills icons
- `combo_break(player_id)` → ComboCounter resets, flutter animation
- `combo_hit(attack_type, combo_count, is_grounded)` → increments counter display

**Input ← CoopManager (upstream):**
- `player_downed(player_id)` → spawns RescueTimer at player's screen-space position
- `player_rescued(player_id, rescuer_color)` → removes timer, triggers rescue sparkle
- `crisis_state_changed(is_crisis)` → enables/disables CrisisEdgeGlow
- `player_out(player_id)` → removes timer, places ghost icon next to partner HP bar
- `coop_bonus_active(multiplier)` → enables/disables CoopBonusIndicator glow

**Input ← BossAIManager (upstream):**
- `boss_phase_changed(new_phase)` → BossHPBar shifts color, updates phase notches
- `boss_phase_warning(phase)` → flashes phase warning at center screen
- `boss_attack_telegraph(pattern)` → shows brief attack name + icon at center screen

**Input ← CombatSystem (upstream):**
- `player_health_changed(current, max, player_id)` → HP bar depletes/replenishes

**Input ← InputSystem (upstream):**
- `pause_input` → toggles PAUSED state
- `start_input` → transitions TITLE → BOSS_INTRO

**Output → Game world (downstream):**
- UI does not directly affect game logic — purely observational

## Formulas

**1. HP Bar Drain Interpolation**

```
display_hp = lerp(display_hp, actual_hp, 1.0 - pow(0.001, delta_time))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| display_hp | float | 0–max_hp | Smoothed HP value for animation |
| actual_hp | int | 0–max_hp | True HP from CombatSystem |
| delta_time | float | per frame | Frame delta time |
| **lerp result** | float | 0–max_hp | Smoothed toward actual |

**2. Combo Counter Scale by Tier**

```
target_scale = match tier:
  0 (IDLE) → 1.0
  1         → 1.0
  2         → 1.15
  3         → 1.30
  4         → 1.50
current_scale = lerp(current_scale, target_scale, 1.0 - pow(0.0001, delta_time))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| current_scale | float | 1.0–1.5 | Animated scale value |
| target_scale | float | fixed per tier | Goal scale |
| **lerp result** | float | 1.0–1.5 | Smoothed scale |

**3. Screen-Space Position for RescueTimer**

```
screen_pos = camera.unproject_position(world_pos)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| world_pos | Vector2 | arena coords | Downed player world position |
| camera | Camera2D | — | Current game camera |
| **screen_pos** | Vector2 | screen coords | Timer anchor point |

**4. CrisisEdgeGlow Opacity (pulsing)**

```
glow_opacity = 0.7 * (sin(time_since_activation * PI * 2) * 0.5 + 0.5)  [if active]
glow_opacity = 0.0  [if inactive]
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| time_since_activation | float | 0–∞ | Seconds since crisis activated |
| pulse_period | — | 1.0s (0.5 on + 0.5 off) | From CoopSystem pulse rhythm |
| **glow_opacity** | float | 0.0–0.7 | Current glow alpha |

## Edge Cases

**1. Two RescueTimers active simultaneously**
- Both P1 and P2 hit 0 HP in same frame → both enter DOWNTIME simultaneously
- Two RescueTimers appear (one near each player)
- If one partner rescues the other before timer expires, the rescued player's timer disappears
- If both timers expire simultaneously → GAME_OVER (team wipe per CoopSystem)

**2. Crisis state triggers while RescueTimer is active**
- Example: P1 is DOWNTIME, P2 is rescuing, P2 drops to 29% HP (crossing CRISIS threshold)
- CrisisEdgeGlow activates immediately (pulsing begins)
- RescueTimer continues counting normally
- CRISIS does NOT interrupt rescue — timer and glow coexist

**3. Boss defeated during BOSS_INTRO animation**
- If boss_hp reaches 0 during the BOSS_INTRO screen
- BOSS_INTRO transitions directly to victory sequence
- No GAMEPLAY_HUD shown for that boss

**4. Pause during BOSS_INTRO**
- Pause input ignored during BOSS_INTRO
- Timer continues; BOSS_INTRO completes normally before pause can activate

**5. Player revived during rescue animation**
- Rescue triggers `player_rescued` signal → timer removed instantly
- Brief sparkle animation plays at rescue location
- No dangling timer state

**6. HP bar at exactly 30% or 60% (phase boundary)**
- HP values are checked after interpolation: if actual_hp / max_hp ≤ 0.60 → Phase 2 immediately
- No hysteresis — transitions are instantaneous at threshold

**7. Game resolution changes during gameplay**
- All UI anchors recalculate automatically via `anchors_preset`
- No restart required — UI reflows to new resolution

**8. Combo counter overflow (99+)**
- Display shows "99+" after count exceeds 99
- Internal multiplier calculation uses actual count (capped at 4.0x for sync per ComboSystem)
- Display cap does not affect damage formula

**9. Hitstop during combo tier transition**
- Tier transitions happen instantly on `combo_tier_changed` signal
- Scale interpolation smooths over ~0.2s regardless of hitstop state
- No tier transition is blocked by hitstop

**10. Boss HP bar reaches 0 same frame as player downed**
- Boss HP = 0 → DEFEATED state triggers
- Both players DOWNTIME same frame → immediate GAME_OVER
- DEFEATED takes visual priority (victory animation plays before game over appears)
- Player sees brief victory moment before game over overlay

**11. RescueTimer expires same frame as rescue input pressed**
- Input processed in order: timer expiration checked first, then rescue input
- If timer reaches 0.0 on the same frame rescue input is received → OUT takes priority
- Rescue window is strict real-time (CoopSystem Rule 4)

## Dependencies

**Upstream dependencies:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| ComboManager | `combo_tier_changed`, `sync_chain_active`, `combo_break`, `combo_hit` | Signal subscription |
| CoopManager | `player_downed`, `player_rescued`, `crisis_state_changed`, `player_out`, `coop_bonus_active` | Signal subscription |
| BossAIManager | `boss_phase_changed`, `boss_phase_warning`, `boss_attack_telegraph` | Signal subscription |
| CombatSystem | `player_health_changed(current, max, player_id)` | Signal subscription |
| InputSystem | `pause_input`, `start_input` | Input event binding |

**Downstream dependents:**

| System | Dependency Content | Interface |
|--------|-------------------|-----------|
| (none) | UI is purely observational — it reflects game state without affecting it | — |

**Interface definition:**

```gdscript
# UIManager (Autoload)

# Input from ComboManager
signal combo_tier_changed(tier: int, player_id: int)
signal sync_chain_active(chain_length: int)
signal combo_break(player_id: int)
signal combo_hit(attack_type: String, combo_count: int, is_grounded: bool)

# Input from CoopManager
signal player_downed(player_id: int)
signal player_rescued(player_id: int, rescuer_color: Color)
signal crisis_state_changed(is_crisis: bool)
signal player_out(player_id: int)
signal coop_bonus_active(multiplier: float)

# Input from BossAIManager
signal boss_phase_changed(new_phase: int)
signal boss_phase_warning(phase: int)
signal boss_attack_telegraph(pattern: String)

# Input from CombatSystem
signal player_health_changed(current: int, max: int, player_id: int)

# Input from InputSystem (via _input handling)
# pause_input → toggles PAUSED state
# start_input → TITLE → BOSS_INTRO

# Methods
func transition_to(state: String)  # TITLE, GAMEPLAY_HUD, PAUSED, BOSS_INTRO, GAME_OVER
func get_screen_state() -> String
```

## Tuning Knobs

| Parameter | Default | Safe Range | Effect |
|-----------|---------|-----------|--------|
| `UI_SCALE_BASE` | 1.0 | 0.8–1.5 | Global UI scale multiplier |
| `HP_BAR_DRAIN_SPEED` | 0.001 | 0.0001–0.01 | How fast HP bars lerp to actual HP (higher = faster) |
| `COMBO_SCALE_LERP_SPEED` | 0.0001 | 0.00001–0.001 | How fast combo counter scales to target tier |
| `BOSS_HP_BAR_WIDTH` | 0.60 | 0.40–0.80 | Boss HP bar as fraction of screen width |
| `RESCUE_TIMER_SIZE` | 80px | 60–120px | Diameter of rescue timer circle |
| `CRISIS_GLOW_WIDTH` | 40px | 20–80px | Width of screen-edge vignette |
| `CRISIS_GLOW_MAX_OPACITY` | 0.7 | 0.4–1.0 | Maximum opacity of crisis glow |
| `CRISIS_PULSE_PERIOD` | 1.0s | 0.5–2.0s | Full pulse cycle (on + off) |
| `BOSS_INTRO_DURATION` | 1.5s | 1.0–3.0s | Duration of boss intro screen |
| `ATTACK_TELEGRAPH_DURATION` | 1.0s | 0.5–2.0s | How long attack telegraph stays on screen |
| `COMBO_TIER2_SCALE` | 1.15 | 1.0–1.4 | Scale multiplier at tier 2 |
| `COMBO_TIER3_SCALE` | 1.30 | 1.1–1.6 | Scale multiplier at tier 3 |
| `COMBO_TIER4_SCALE` | 1.50 | 1.2–2.0 | Scale multiplier at tier 4 (overdrive) |
| `HP_CRITICAL_THRESHOLD` | 0.10 | 0.05–0.20 | HP% below which critical flash starts |
| `HP_LOW_THRESHOLD` | 0.30 | 0.20–0.40 | HP% below which low/desaturated state starts |
| `MIN_RESOLUTION_WIDTH` | 1280 | 960–1920 | Minimum supported screen width |

## Visual/Audio Requirements

**Visual Requirements (hand-painted paper aesthetic):**

| Component | Visual Style | Color | Animation |
|-----------|-------------|-------|-----------|
| PlayerHPBar_P1 | Sticky-note rectangle, paper-torn edges | #F5A623 fill, darker edge | Smooth HP drain, pulse on low |
| PlayerHPBar_P2 | Sticky-note rectangle, paper-torn edges | #4ECDC4 fill, darker edge | Smooth HP drain, pulse on low |
| BossHPBar | Long paper scroll, torn ends, notched at 60%/30% | Phase-dependent (#6B7B8C → #D4A017 → #E85D3B) | Depletes left-to-right, phase notches flash on transition |
| ComboCounter | Hand-written number, paper scrap below | P1=#F5A623, P2=#4ECDC4, gold tint tier 4 | Scale bounce on hit, glow intensifies with tier |
| SyncChainIndicator | Row of 3 small paper-clip icons | Orange/blue alternating | Fill animation on chain build |
| RescueTimer | Circular pie-chart radial drain | Rescuer's color | Clockwise drain, flash-fill on rescue |
| CrisisEdgeGlow | Full-screen vignette | #7F96A6 (orange+blue blend) | 0.5s on/off pulse |
| CoopBonusIndicator | Small radial glow spot | P1=#F5A623, P2=#4ECDC4 | Soft fade in/out |
| BossPhaseWarning | Center screen flash | Boss phase color | Brief 0.3s opacity flash |
| AttackTelegraph | Icon + attack name in hand-lettered style | White text, dark shadow | Slides up, fades after duration |
| PauseMenu | Stack of sticky notes | Yellow #F5D76E background | Slide-down animation |
| GameOverScreen | "系统提示：您的年假已用完" | Fluorescent white #FAFAFA | Fade-in |
| TitleScreen | Single warm spotlight on dark | Gold #F5A623 accent | Subtle breathing pulse on start prompt |

**Audio Requirements:**

| Event | Sound |
|-------|-------|
| Boss phase transition | Deep "whomp" — low frequency undertone signaling change |
| Crisis activated | Urgency undertone layered into music (CoopSystem handles this) |
| Attack telegraph appears | Soft paper-slide sound |
| Rescue success | Warm "whoosh" + brief chime in rescuer's pitch |
| Game Over | Single fluorescent buzz (office lighting flicker) |

## UI Requirements

- **Player HP bars**: Bottom-left (P1, orange) and bottom-right (P2, blue), sticky-note aesthetic, paper-torn edges, thumbtack icon at anchor point
- **Boss HP bar**: Top-center, 60% screen width, paper scroll aesthetic, visible phase notches at 60% and 30%
- **Combo counters**: Below respective HP bars, one per player, hand-written number style, scale with tier
- **Sync chain indicator**: Row of 3 paper-clip icons between combo counters, fills as sync chain builds
- **Rescue timer**: Circular radial drain at downed player's screen position, 80px diameter
- **CRISIS edge glow**: Full-screen vignette, #7F96A6 blended color, 0.5s on/off pulse
- **Co-op bonus indicator**: Small colored aura near each HP bar, visible only when bonus is active
- **Boss phase warning**: Center screen flash, phase-appropriate color
- **Attack telegraph**: Icon + brief text label, center screen, fades after 1s
- **Pause menu**: Sticky-note stack aesthetic, accessible from gameplay at any time
- **Game Over screen**: "系统提示：您的年假已用完" text, fluorescent white on dark, black-humor tone
- **Title screen**: Warm spotlight on dark, "Press Start" with breathing pulse animation
- **Boss intro screen**: Boss name in hand-lettered typography, boss silhouette, 1.5s auto-transition

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-01 | P1 HP = 100% | Query HP bar | P1 bar shows full, #F5A623 color |
| AC-02 | P1 HP drops to 20% | HP update signal | P1 bar is desaturated, slow pulse |
| AC-03 | P1 HP drops to 8% | HP update signal | P1 bar flashes red tint overlay |
| AC-04 | P1 combo = 25 | Query scale | Combo counter scale = 1.30x |
| AC-05 | P1 combo = 45, P2 combo = 45 | Both hit sync | Both counters show gold tint, colors intertwine |
| AC-06 | Sync chain = 3 consecutive | 3rd sync hit | SyncChainIndicator shows 3 filled icons, sync burst triggers |
| AC-07 | P1 downed | player_downed signal | RescueTimer spawns at P1 screen position, radial drain begins |
| AC-08 | RescueTimer counting, rescue occurs | player_rescued signal | Timer disappears, sparkle at rescue location |
| AC-09 | RescueTimer counting, timer = 0 | No rescue | Timer disappears, ghost icon appears next to P2 HP bar |
| AC-10 | Both players below 30% HP | crisis_state_changed(true) | CrisisEdgeGlow activates, 0.5s on/off pulse begins |
| AC-11 | Either player exits below 30% | crisis_state_changed(false) | CrisisEdgeGlow deactivates immediately |
| AC-12 | Boss HP crosses 60% | boss_phase_changed(2) | BossHPBar shifts to amber #D4A017, 60% notch flashes |
| AC-13 | Boss HP crosses 30% | boss_phase_changed(3) | BossHPBar shifts to urgent red-orange #E85D3B, 30% notch flashes |
| AC-14 | Boss attack telegraph fires | boss_attack_telegraph | Center screen shows icon + attack name for 1.0s |
| AC-15 | Boss HP = 0 | Boss DEFEATED | Victory animation plays, GAME_OVER overlay if both players OUT |
| AC-16 | Gameplay, pause pressed | pause_input | PauseMenu appears, gameplay freezes |
| AC-17 | Title screen | start_input | Transitions to BOSS_INTRO |
| AC-18 | Both players alive | Any moment | CoopBonusIndicator glows near both HP bars |
| AC-19 | P1 OUT, P2 alive | P1 player_out | Ghost silhouette icon appears next to P2 HP bar |
| AC-20 | BOSS_INTRO active | 1.5s timer expires | Auto-transitions to GAMEPLAY_HUD |

## Open Questions

| # | Question | Owner | Target |
|---|----------|-------|--------|
| 1 | Does the game have a LIVES system (3 lives = game over), or is game over instant on team wipe? | Game Designer | Coop verification |
| 2 | Does the rescue require a specific button, or automatic when in range + pressing any action? | Input system verification | Input GDD |
| 3 | Should OUT players be visible as ghosts on screen, or completely invisible? | UX review | Visual review |
| 4 | Does CRISIS state affect audio only, or trigger a music change? | Audio review | Audio system GDD |
| 5 | What is the boss HP bar depleting animation — instant or smooth drain? | UI review | This GDD (AC-01 uses interpolated drain) |
| 6 | Is there a "boss name" displayed during BOSS_INTRO? If so, what typography? | Art bible verification | Typography direction needed |
| 7 | Does the pause menu have controller/gamepad navigation? | Input system | Required for PC+gamepad |
| 8 | Should screen shake at tier 3 combo be implemented in UI layer or handled by the screen shake system? | Systems integration | Which system owns the effect |
