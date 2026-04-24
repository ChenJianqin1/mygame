# Story 002: DOWNTIME State + Rescue Timer + Range Detection

> **Epic**: coop
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/coop-system.md`
**Requirement**: `TR-coop-002`, `TR-coop-003`, `TR-coop-004`, `TR-coop-010`, `TR-coop-012` — DOWNTIME, rescue timer, range detection

**ADR Governing Implementation**: ADR-ARCH-005: Coop System HP Pools & Rescue
**ADR Decision Summary**:
```
RESCUE_WINDOW = 3.0 seconds
RESCUE_RANGE = 175px (boundary inclusive)
DOWNTIME player is vulnerable to attacks
Rescue timer is real-time (not paused during hitstop)
```

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-02, AC-03, AC-04, AC-10, AC-12:

- [ ] **AC-02**: P1 hits 0 HP → P1 enters DOWNTIME → rescue timer starts (3s)
- [ ] **AC-03**: P1 DOWNTIME, P2 approaches within 175px → P2 presses rescue → P1 instantly revives with 1.5s i-frames
- [ ] **AC-04**: P1 DOWNTIME, timer reaches 0 → without rescue → P1 is OUT
- [ ] **AC-10**: Rescue window at 0.5s, hitstop starts → timer continues, still 0.5s after hitstop
- [ ] **AC-12**: Rescue range = exactly 175px → P2 distance to P1 = 175 → is_in_range = TRUE

---

## Implementation Notes

### 1. Rescue Range Detection

```gdscript
## Check if rescuer is within rescue range of downed player
## Range is inclusive: distance == RESCUE_RANGE means rescue IS allowed
func is_in_rescue_range(rescuer_id: int, downed_id: int) -> bool:
    # This method requires position data from the game scene
    # Returns true if rescuer is within RESCUE_RANGE of downed player
    # Implementation depends on Player nodes providing position
    var rescuer_pos = _get_player_position(rescuer_id)
    var downed_pos = _get_player_position(downed_id)
    if rescuer_pos == null or downed_pos == null:
        return false
    var distance = rescuer_pos.distance_to(downed_pos)
    return distance <= RESCUE_RANGE

func _get_player_position(player_id: int) -> Vector2:
    # Placeholder — actual implementation queries player scene nodes
    # Player nodes must be registered with CoopManager
    return Vector2.ZERO

# Player position tracking (called by Player nodes on position change)
var _player_positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

func update_player_position(player_id: int, position: Vector2) -> void:
    var idx = player_id - 1
    if idx >= 0 and idx < 2:
        _player_positions[idx] = position
```

### 2. Rescue Timer Query

```gdscript
## Get remaining rescue time for a downed player
## Returns -1.0 if player is not in DOWNTIME
func get_rescue_timer(player_id: int) -> float:
    var idx = player_id - 1
    if _player_state[idx] != CoopState.DOWNTIME:
        return -1.0
    
    var current_time = Time.get_ticks_msec() / 1000.0
    var elapsed = current_time - _downtime_start_time[idx]
    var remaining = RESCUE_WINDOW - elapsed
    return max(0.0, remaining)

## Check if rescue window has expired
func is_rescue_window_expired(player_id: int) -> bool:
    return get_rescue_timer(player_id) <= 0.0
```

### 3. Rescue Input Handler

```gdscript
## Called by InputSystem when rescue input is pressed
func attempt_rescue(rescuer_id: int) -> bool:
    var partner_id = 2 if rescuer_id == 1 else 1
    var partner_idx = partner_id - 1
    
    # Partner must be in DOWNTIME (not OUT)
    if _player_state[partner_idx] != CoopState.DOWNTIME:
        return false
    
    # Must be in range
    if not is_in_rescue_range(rescuer_id, partner_id):
        return false
    
    # Execute rescue
    _execute_rescue(partner_id, rescuer_id)
    return true

func _execute_rescue(downed_id: int, rescuer_id: int) -> void:
    var downed_idx = downed_id - 1
    var rescuer_idx = rescuer_id - 1
    
    # Revive player
    _player_state[downed_idx] = CoopState.RESCUED
    _player_hp[downed_idx] = 1  # Revive with minimal HP (healed immediately by game logic)
    
    # Set i-frames timer (real-time)
    var current_time = Time.get_ticks_msec() / 1000.0
    _rescued_iframe_end_time[downed_idx] = current_time + RESCUED_IFRAMES_DURATION
    
    # Emit signals
    var rescuer_color = Color("#F5A623") if rescuer_id == 1 else Color("#4ECDC4")
    var downed_pos = _player_positions[downed_idx]
    rescue_triggered.emit(downed_pos, rescuer_color)
    player_rescued.emit(downed_id, rescuer_color)
```

### 4. DOWNTIME Vulnerability

```gdscript
## DOWNTIME players can be hit — called by CombatSystem
func apply_damage_to_down_player(player_id: int, damage: int) -> void:
    var idx = player_id - 1
    if _player_state[idx] != CoopState.DOWNTIME:
        return  # Only DOWNTIME players are vulnerable when down
    
    _player_hp[idx] = max(0, _player_hp[idx] - damage)
    # If DOWNTIME player takes fatal damage, they stay DOWNTIME (already down)
    # The rescue window continues — if it expires, they become OUT
```

---

## Out of Scope

- CoopManager Autoload creation (Story 001)
- Rescue i-frames invincibility check during RESCUED state (Story 003)
- CRISIS damage reduction (Story 004)
- UI timer display, VFX rescue effects (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_rescue_timer_starts**: Given P1 enters DOWNTIME → get_rescue_timer(P1) returns ~3.0
- **test_rescue_timer_countdown**: Given P1 DOWNTIME for 1s → get_rescue_timer(P1) returns ~2.0
- **test_rescue_timer_expired**: Given P1 DOWNTIME for 3s+ → get_rescue_timer(P1) returns 0.0
- **test_rescue_range_within**: Given P1 at (0,0), P2 at (100, 0) → is_in_rescue_range(P2, P1) = true
- **test_rescue_range_outside**: Given P1 at (0,0), P2 at (200, 0) → is_in_rescue_range(P2, P1) = false
- **test_rescue_range_boundary**: Given P1 at (0,0), P2 at (175, 0) → is_in_rescue_range(P2, P1) = true (inclusive)
- **test_rescue_fails_when_partner_out**: Given P1 is OUT → attempt_rescue(P2) returns false
- **test_rescue_fails_out_of_range**: Given P1 DOWNTIME, P2 too far → attempt_rescue(P2) returns false
- **test_rescue_succeeds**: Given P1 DOWNTIME, P2 in range → attempt_rescue(P2) returns true, P1 state = RESCUED
- **test_rescue_timer_not_paused_during_hitstop**: See AC-10 — timer is real-time, uses Time.get_ticks_msec()

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/coop/downtime_rescue_timer_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (CoopManager foundation)
- Unlocks: Stories 003, 004, 005, 006

---

## Technical Notes

### Real-time Timer Implementation

The rescue timer uses `Time.get_ticks_msec()` which is real-time and NOT affected by game pauses or hitstop. This is intentional per AC-10.

```gdscript
# Wrong (affected by game pause):
var _timer: float = RESCUE_WINDOW
func _process(delta):
    _timer -= delta  # Pauses during hitstop

# Correct (real-time, not affected by pause):
var _downtime_start_time: float  # Set when entering DOWNTIME
func _process(delta):
    var elapsed = Time.get_ticks_msec() / 1000.0 - _downtime_start_time
    var remaining = RESCUE_WINDOW - elapsed  # Continues during hitstop
```
