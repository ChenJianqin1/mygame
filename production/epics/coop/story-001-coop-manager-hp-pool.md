# Story 001: CoopManager Autoload + HP Pool

> **Epic**: coop
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/coop-system.md`
**Requirement**: `TR-coop-001`, `TR-coop-002`, `TR-coop-008` — HP pool management, DOWNTIME entry, simultaneous DOWNTIME

**ADR Governing Implementation**: ADR-ARCH-005: Coop System HP Pools & Rescue
**ADR Decision Summary**:
```
PLAYER_MAX_HP = 100 (per player)
COOP_BONUS = 0.10 (+10% damage when both alive)
States: ACTIVE, DOWNTIME, RESCUED, CRISIS, OUT
```

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-01, AC-02, AC-08:

- [ ] **AC-01**: P1 at full HP, P2 at full HP — normal play → COOP_BONUS = +10% active
- [ ] **AC-02**: P1 hits 0 HP → P1 enters DOWNTIME, rescue timer starts (3s)
- [ ] **AC-08**: Both players hit 0 same frame → simultaneous DOWNTIME → lose a life / game over

---

## Implementation Notes

### 1. Create `CoopManager.gd` Autoload

```gdscript
## CoopManager — Autoload singleton
## Manages dual-player HP pools, rescue mechanics, and co-op state

# Constants
const PLAYER_MAX_HP: int = 100
const RESCUE_WINDOW: float = 3.0        # seconds
const RESCUE_RANGE: float = 175.0       # pixels
const RESCUED_IFRAMES_DURATION: float = 1.5  # seconds
const COOP_BONUS: float = 0.10         # +10% damage when both alive
const SOLO_DAMAGE_REDUCTION: float = 0.25   # 25% reduction when solo
const CRISIS_DAMAGE_REDUCTION: float = 0.25  # 25% reduction in CRISIS
const CRISIS_HP_THRESHOLD: float = 0.30      # 30% HP threshold

# Player IDs
const PLAYER_P1: int = 1
const PLAYER_P2: int = 2

# State enum
enum CoopState { ACTIVE, DOWNTIME, RESCUED, CRISIS, OUT }

# Player data
var _player_hp: Array[int] = [0, 0]  # Index 0 = P1, Index 1 = P2
var _player_state: Array[CoopState] = [CoopState.ACTIVE, CoopState.ACTIVE]
var _downtime_start_time: Array[float] = [-1.0, -1.0]  # real-time when DOWNTIME started
var _rescued_iframe_end_time: Array[float] = [-1.0, -1.0]  # real-time when i-frames end

func _init() -> void:
    _player_hp[0] = PLAYER_MAX_HP
    _player_hp[1] = PLAYER_MAX_HP
    _player_state[0] = CoopState.ACTIVE
    _player_state[1] = CoopState.ACTIVE

func _process(delta: float) -> void:
    _update_rescue_timers(delta)
    _update_crisis_state()
    _update_rescued_iframes(delta)

func _update_rescue_timers(delta: float) -> void:
    # Check for DOWNTIME timeout → OUT
    for i in range(2):
        if _player_state[i] == CoopState.DOWNTIME:
            var time_elapsed = Time.get_ticks_msec() / 1000.0 - _downtime_start_time[i]
            if time_elapsed >= RESCUE_WINDOW:
                _player_state[i] = CoopState.OUT
                player_out.emit(i + 1)  # Emit with player_id (1 or 2)

func _update_crisis_state() -> void:
    var p1_hp_percent = float(_player_hp[0]) / float(PLAYER_MAX_HP)
    var p2_hp_percent = float(_player_hp[1]) / float(PLAYER_MAX_HP)
    var both_below = (p1_hp_percent < CRISIS_HP_THRESHOLD) and (p2_hp_percent < CRISIS_HP_THRESHOLD)
    var both_alive = (_player_state[0] == CoopState.ACTIVE or _player_state[0] == CoopState.RESCUED) and \
                      (_player_state[1] == CoopState.ACTIVE or _player_state[1] == CoopState.RESCUED)
    
    if both_below and both_alive:
        if not _is_crisis_active:
            _is_crisis_active = true
            crisis_state_changed.emit(true)
    else:
        if _is_crisis_active:
            _is_crisis_active = false
            crisis_state_changed.emit(false)

func _update_rescued_iframes(delta: float) -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    for i in range(2):
        if _player_state[i] == CoopState.RESCUED:
            if current_time >= _rescued_iframe_end_time[i]:
                _player_state[i] = CoopState.ACTIVE
```

### 2. HP Management Methods

```gdscript
func apply_damage_to_player(player_id: int, damage: int) -> void:
    var idx = player_id - 1  # Convert to 0-indexed
    _player_hp[idx] = max(0, _player_hp[idx] - damage)
    
    if _player_hp[idx] <= 0:
        _enter_downtime(player_id)

func _enter_downtime(player_id: int) -> void:
    var idx = player_id - 1
    _player_state[idx] = CoopState.DOWNTIME
    _downtime_start_time[idx] = Time.get_ticks_msec() / 1000.0
    player_downed.emit(player_id)

func heal_player(player_id: int, amount: int) -> void:
    var idx = player_id - 1
    _player_hp[idx] = min(PLAYER_MAX_HP, _player_hp[idx] + amount)

func get_player_hp(player_id: int) -> int:
    return _player_hp[player_id - 1]

func get_player_hp_percent(player_id: int) -> float:
    return float(_player_hp[player_id - 1]) / float(PLAYER_MAX_HP)

func get_player_state(player_id: int) -> CoopState:
    return _player_state[player_id - 1]
```

### 3. Signal Interface

```gdscript
signal coop_bonus_active(multiplier: float)      # +10% when both alive
signal solo_mode_active(player_id: int)          # 25% damage reduction
signal player_downed(player_id: int)             # rescue timer starts
signal player_rescued(player_id: int, rescuer_color: Color)
signal crisis_state_changed(is_crisis: bool)
signal player_out(player_id: int)
signal rescue_triggered(position: Vector2, rescuer_color: Color)
signal crisis_activated()

var _is_crisis_active: bool = false
```

### 4. Query Methods for Combat System

```gdscript
func is_coop_bonus_active() -> bool:
    return (_player_state[0] == CoopState.ACTIVE or _player_state[0] == CoopState.RESCUED) and \
           (_player_state[1] == CoopState.ACTIVE or _player_state[1] == CoopState.RESCUED)

func is_solo_mode(player_id: int) -> bool:
    var idx = player_id - 1
    var partner_idx = 1 - idx
    return (_player_state[idx] == CoopState.ACTIVE or _player_state[idx] == CoopState.RESCUED) and \
           (_player_state[partner_idx] == CoopState.DOWNTIME or _player_state[partner_idx] == CoopState.OUT)

func is_crisis_active() -> bool:
    return _is_crisis_active
```

---

## Out of Scope

- Rescue range detection and execution (Story 002)
- Rescue i-frames timer logic (Story 003)
- CRISIS damage reduction calculation (Story 004)
- UI/VFX/Audio signal consumers (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_initial_hp**: Given game start → both players have 100 HP
- **test_apply_damage**: Given P1 at 100 HP → apply_damage(P1, 30) → P1 has 70 HP
- **test_damage_to_zero**: Given P1 at 20 HP → apply_damage(P1, 30) → P1 state is DOWNTIME
- **test_heal**: Given P1 at 50 HP → heal(P1, 30) → P1 has 80 HP (capped at 100)
- **test_simultaneous_damage**: Given both at 10 HP → apply_damage(P1, 15) and apply_damage(P2, 15) same frame → both DOWNTIME
- **test_coop_bonus_active**: Given both players ACTIVE → is_coop_bonus_active() = true
- **test_coop_bonus_not_active_when_one_down**: Given P1 DOWNTIME → is_coop_bonus_active() = false
- **test_solo_mode**: Given P1 ACTIVE, P2 DOWNTIME → is_solo_mode(P1) = true
- **test_crisis_detection**: Given P1 at 29 HP, P2 at 29 HP → is_crisis_active() = true

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/coop/coop_manager_hp_pool_test.gd` — must exist and pass

---

## Dependencies

- Depends on: None (Core layer, first coop story)
- Unlocks: Stories 002-006
