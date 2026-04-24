# Story 006: Coop Signals + UI/VFX/Audio Integration

> **Epic**: coop
> **Status**: Done
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/coop-system.md`
**Requirement**: All coop signals must connect to UI, VFX, and Audio systems

**ADR Governing Implementation**: ADR-ARCH-005: Coop System HP Pools & Rescue
**Interface Definition from GDD**:
```gdscript
# CoopManager (Autoload)
signal coop_bonus_active(multiplier: float)      # +10% when both alive
signal solo_mode_active(player_id: int)           # 25% damage reduction
signal player_downed(player_id: int)             # rescue timer starts
signal player_rescued(player_id: int, rescuer_color: Color)
signal crisis_state_changed(is_crisis: bool)
signal player_out(player_id: int)
signal rescue_triggered(position: Vector2, rescuer_color: Color)
signal crisis_activated()
```

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD Section "Visual/Audio Requirements" and "UI Requirements":

- [ ] Rescue hand glows in rescuer's color (#F5A623 for P1, #4ECDC4 for P2)
- [ ] Rescue success sparkle effect on rescued player (8-12 particles)
- [ ] Rescued player i-frames shown as soft pulsing glow
- [ ] DOWNTIME: no screen darkening, subtle vignette pulse
- [ ] CRISIS: screen edge glow blends orange+blue (#7F96A6), pulsing 0.5s on/off
- [ ] Player OUT: semi-transparent ghost, desaturated player color
- [ ] COOP_BONUS active: small colored glow around both players
- [ ] Individual HP bars: P1 bottom-left (orange), P2 bottom-right (blue)
- [ ] Rescue timer: circular countdown near downed player (3s → 0)
- [ ] OUT indicator: ghost silhouette next to partner's HP bar
- [ ] DOWNTIME audio: soft "down" stinger (paper rustle)
- [ ] Rescue success audio: warm "whoosh" + brief chime in rescuer's pitch
- [ ] CRISIS audio: music layer shifts to urgent undertone
- [ ] Player OUT audio: quiet fade

---

## Implementation Notes

### 1. Signal Wiring in CoopManager

All signals are already defined in Stories 001-005. This story ensures they are:
- Properly connected by consumer systems
- Emit at correct times with correct data

### 2. UI System Integration

The UI system listens to CoopManager signals:

```gdscript
## In UI System (e.g., HUD node)
func _ready() -> void:
    CoopManager.player_downed.connect(_on_player_downed)
    CoopManager.player_rescued.connect(_on_player_rescued)
    CoopManager.player_out.connect(_on_player_out)
    CoopManager.crisis_state_changed.connect(_on_crisis_state_changed)
    CoopManager.coop_bonus_active.connect(_on_coop_bonus_active)
    CoopManager.solo_mode_active.connect(_on_solo_mode_active)

func _on_player_downed(player_id: int) -> void:
    # Show rescue timer countdown near downed player
    # Timer counts down 3s → 0
    # Circular radial drain animation
    pass

func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
    # Hide rescue timer
    # Show brief rescue success flash
    pass

func _on_player_out(player_id: int) -> void:
    # Show ghost silhouette icon next to partner's HP bar
    pass

func _on_crisis_state_changed(is_crisis: bool) -> void:
    # Toggle screen edge glow (orange+blue blend)
    # Pulse rhythm: 0.5s on, 0.5s off
    pass

func _on_coop_bonus_active(multiplier: float) -> void:
    # Show small colored aura icon near HP bars
    pass

func _on_solo_mode_active(player_id: int) -> void:
    # Show SOLO indicator near active player's HP bar
    pass
```

### 3. VFX System Integration

```gdscript
## In VFX System
func _ready() -> void:
    CoopManager.rescue_triggered.connect(_on_rescue_triggered)
    CoopManager.crisis_activated.connect(_on_crisis_activated)

func _on_rescue_triggered(position: Vector2, rescuer_color: Color) -> void:
    # Spawn rescue hand glow effect at position
    # Hand glow color = rescuer_color
    # Spawn 8-12 particle confetti burst
    # Total effect duration < 1 second
    pass

func _on_crisis_activated() -> void:
    # Activate screen edge glow effect
    # Blend orange (#F5A623) and blue (#4ECDC4) to midpoint (#7F96A6)
    pass
```

### 4. Audio System Integration

```gdscript
## In Audio System
func _ready() -> void:
    CoopManager.player_downed.connect(_on_player_downed_audio)
    CoopManager.player_rescued.connect(_on_player_rescued_audio)
    CoopManager.crisis_state_changed.connect(_on_crisis_state_changed_audio)
    CoopManager.player_out.connect(_on_player_out_audio)

func _on_player_downed_audio(player_id: int) -> void:
    # Play soft "down" stinger
    # Paper rustle sound, not alarming
    pass

func _on_player_rescued_audio(player_id: int, rescuer_color: Color) -> void:
    # Play warm "whoosh"
    # Play brief chime in rescuer's pitch (P1=higher, P2=lower)
    pass

func _on_crisis_state_changed_audio(is_crisis: bool) -> void:
    # If entering CRISIS: shift music layer to urgent undertone
    # If exiting CRISIS: return to normal music layer
    pass

func _on_player_out_audio(player_id: int) -> void:
    # Quiet fade — no punishment sound
    pass
```

### 5. CoopManager Signal Summary

| Signal | Payload | Consumers |
|--------|---------|-----------|
| `coop_bonus_active` | `multiplier: float` | UI (aura icon) |
| `solo_mode_active` | `player_id: int` | UI (SOLO indicator) |
| `player_downed` | `player_id: int` | UI (timer), Audio (down stinger) |
| `player_rescued` | `player_id: int, rescuer_color: Color` | UI (hide timer), VFX (sparkle), Audio (whoosh+chime) |
| `crisis_state_changed` | `is_crisis: bool` | UI (edge glow), Audio (music shift) |
| `player_out` | `player_id: int` | UI (ghost icon), Audio (quiet fade) |
| `rescue_triggered` | `position: Vector2, rescuer_color: Color` | VFX (hand glow) |
| `crisis_activated` | (no payload) | VFX (edge glow trigger) |

---

## Out of Scope

- CoopManager Autoload creation (Story 001)
- HP pool management (Story 001)
- All Logic stories (Stories 001-005)

---

## QA Test Cases

**Integration Test Specs (Integration story)**:

- **test_rescue_signal_contains_color**: When rescue triggered → rescue_triggered emits with rescuer_color
- **test_crisis_signal_on_transition**: When both < 30% → crisis_activated emits; when either >= 30% → crisis_state_changed(false) emits
- **test_out_signal_when_timer_expires**: When rescue timer reaches 0 → player_out emits
- **test_coop_bonus_signal_when_both_alive**: When both ACTIVE → coop_bonus_active emits with 1.10

**Note**: UI/VFX/Audio consumer connections are integration tests that require the full scene to verify visually. These are ADVISORY story type per the testing standards.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test for signal connections OR documented playtest verification

---

## Dependencies

- Depends on: Stories 001-005 (all CoopManager features complete)
- Consumer systems must be implemented: UI (Story from UI epic), VFX (Story from VFX epic), Audio (Story from Audio epic)

---

## Technical Notes

### Signal Connection Pattern

Consumer systems should connect in their `_ready()` method:

```gdscript
func _ready() -> void:
    if CoopManager:
        CoopManager.player_downed.connect(_on_player_downed)
```

### Color Constants

```gdscript
const P1_COLOR: Color = Color("#F5A623")  # 晨曦橙
const P2_COLOR: Color = Color("#4ECDC4")  # 梦境蓝
const CRISIS_COLOR: Color = Color("#7F96A6")  # Orange+Blue midpoint
```

### VFX Budget Consideration

Per ADR-ARCH-008, the VFX system has budget limits. Rescue effects should use:
- 8-12 particles per rescue (small burst)
- Single hand glow sprite (no particle system needed)
- Total effect should complete within 1 second
