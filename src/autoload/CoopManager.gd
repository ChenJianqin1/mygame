# CoopManager.gd — Autoload singleton for co-op system
# Implements ADR-ARCH-005: Coop System HP Pools & Rescue
# Manages dual-player HP pools, rescue mechanics, and co-op state machine
class_name CoopManager
extends Node

## Autoload singleton managing two-player co-op state and HP pools.
## Tracks player HP, co-op bonus, downtime, rescue, and crisis states.

# ─── Constants ───────────────────────────────────────────────────────────────────
const PLAYER_MAX_HP: int = 100
const RESCUE_WINDOW: float = 3.0          ## seconds before player is OUT
const RESCUE_RANGE: float = 175.0        ## pixels — rescue trigger distance
const RESCUED_IFRAMES_DURATION: float = 1.5  ## seconds of invincibility after rescue
const COOP_BONUS: float = 0.10          ## +10% damage when both alive
const SOLO_DAMAGE_REDUCTION: float = 0.25  ## 25% damage reduction when solo
const CRISIS_DAMAGE_REDUCTION: float = 0.25  ## 25% damage reduction in crisis
const CRISIS_HP_THRESHOLD: float = 0.30  ## 30% HP threshold for crisis

## Player identifiers
const PLAYER_P1: int = 1
const PLAYER_P2: int = 2

## Player colors (used for UI/VFX)
const P1_COLOR: Color = Color("#F5A623")
const P2_COLOR: Color = Color("#4ECDC4")
const CRISIS_COLOR: Color = Color("#7F96A6")

# ─── State Enum ─────────────────────────────────────────────────────────────────
enum CoopState {
	ACTIVE,    ## Normal play
	DOWNTIME,  ## Player at 0 HP, rescue timer running
	RESCUED,   ## Recently rescued, has i-frames
	CRISIS,    ## Both players below CRISIS_HP_THRESHOLD
	OUT        ## Rescue window expired, player is out of the round
}

# ─── Signals ───────────────────────────────────────────────────────────────────
## Emitted when co-op bonus becomes active/inactive (+10% damage both alive)
signal coop_bonus_active(multiplier: float)

## Emitted when a player enters solo mode (partner is down)
signal solo_mode_active(player_id: int)

## Emitted when a player hits 0 HP and enters DOWNTIME
signal player_downed(player_id: int)

## Emitted when a downed player is rescued
signal player_rescued(player_id: int, rescuer_color: Color)

## Emitted when crisis state changes
signal crisis_state_changed(is_crisis: bool)

## Emitted when a player's rescue window expires (player is OUT)
signal player_out(player_id: int)

## Emitted when a rescue is triggered
signal rescue_triggered(position: Vector2, rescuer_color: Color)

## Emitted when crisis activates
signal crisis_activated()

# ─── Per-Player State ───────────────────────────────────────────────────────────
var _player_hp: Array[int] = [PLAYER_MAX_HP, PLAYER_MAX_HP]
var _player_state: Array[CoopState] = [CoopState.ACTIVE, CoopState.ACTIVE]
var _downtime_start_time: Array[float] = [-1.0, -1.0]  ## real-time seconds when DOWNTIME started
var _rescued_iframe_end_time: Array[float] = [-1.0, -1.0]  ## real-time seconds when i-frames end

var _is_crisis_active: bool = false
var _was_coop_bonus_active: bool = true  ## Tracks previous coop bonus state for change detection
var _was_solo_mode: Array[bool] = [false, false]  ## Tracks previous solo mode state per player

# ─── Lifecycle ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player_hp[0] = PLAYER_MAX_HP
	_player_hp[1] = PLAYER_MAX_HP
	_player_state[0] = CoopState.ACTIVE
	_player_state[1] = CoopState.ACTIVE
	_was_coop_bonus_active = is_coop_bonus_active()
	_was_solo_mode[0] = is_solo_mode(1)
	_was_solo_mode[1] = is_solo_mode(2)
	# Emit initial coop bonus state
	coop_bonus_active.emit(1.0 + COOP_BONUS)

# ─── Public API: HP Management ──────────────────────────────────────────────────

## Apply damage to a player. If HP reaches 0, player enters DOWNTIME.
func apply_damage_to_player(player_id: int, damage: int) -> void:
	var idx: int = player_id - 1
	var old_hp: int = _player_hp[idx]
	_player_hp[idx] = maxi(0, _player_hp[idx] - damage)
	Events.player_damaged.emit(player_id, damage)
	Events.player_hp_changed.emit(player_id, _player_hp[idx], PLAYER_MAX_HP)
	if _player_hp[idx] <= 0 and old_hp > 0:
		_enter_downtime(player_id)


## Heal a player by amount, capped at PLAYER_MAX_HP.
func heal_player(player_id: int, amount: int) -> void:
	var idx: int = player_id - 1
	_player_hp[idx] = mini(PLAYER_MAX_HP, _player_hp[idx] + amount)
	Events.player_healed.emit(player_id, amount)
	Events.player_hp_changed.emit(player_id, _player_hp[idx], PLAYER_MAX_HP)


## Get current HP for a player.
func get_player_hp(player_id: int) -> int:
	return _player_hp[player_id - 1]


## Get HP as a fraction (0.0 to 1.0) for a player.
func get_player_hp_percent(player_id: int) -> float:
	return float(_player_hp[player_id - 1]) / float(PLAYER_MAX_HP)


## Get the current CoopState for a player.
func get_player_state(player_id: int) -> CoopState:
	return _player_state[player_id - 1]


## Returns true if co-op bonus is active (both players ACTIVE or RESCUED).
func is_coop_bonus_active() -> bool:
	var p1_ok: bool = (_player_state[0] == CoopState.ACTIVE) or (_player_state[0] == CoopState.RESCUED)
	var p2_ok: bool = (_player_state[1] == CoopState.ACTIVE) or (_player_state[1] == CoopState.RESCUED)
	return p1_ok and p2_ok


## Returns true if a player is in solo mode (partner is DOWNTIME or OUT).
func is_solo_mode(player_id: int) -> bool:
	var idx: int = player_id - 1
	var partner_idx: int = 1 - idx
	var me_ok: bool = (_player_state[idx] == CoopState.ACTIVE) or (_player_state[idx] == CoopState.RESCUED)
	var partner_down: bool = (_player_state[partner_idx] == CoopState.DOWNTIME) or (_player_state[partner_idx] == CoopState.OUT)
	return me_ok and partner_down


## Returns SOLO damage multiplier (0.75 = 25% reduction when solo).
func get_solo_damage_multiplier() -> float:
	return 1.0 - SOLO_DAMAGE_REDUCTION


## Returns outgoing damage multiplier for a player (for their attacks).
## COOP_BONUS applies when both players are alive; no bonus in SOLO mode.
func get_outgoing_damage_multiplier(player_id: int) -> float:
	var idx: int = player_id - 1

	# Can only get bonus if player is alive
	if not (_player_state[idx] == CoopState.ACTIVE or _player_state[idx] == CoopState.RESCUED):
		return 1.0

	# Can only get COOP_BONUS if partner is also alive
	var partner_idx: int = 1 - idx
	var partner_alive: bool = (_player_state[partner_idx] == CoopState.ACTIVE) or (_player_state[partner_idx] == CoopState.RESCUED)

	if partner_alive:
		return 1.0 + COOP_BONUS  # Returns 1.10
	else:
		# SOLO player — no COOP_BONUS
		return 1.0


## Returns true if crisis state is currently active.
func is_crisis_active() -> bool:
	return _is_crisis_active


## Returns crisis damage multiplier (0.75 = 25% reduction when crisis active).
func get_crisis_damage_multiplier() -> float:
	if _is_crisis_active:
		return 1.0 - CRISIS_DAMAGE_REDUCTION
	return 1.0


## Returns incoming damage multiplier for a player.
## CRISIS takes priority over SOLO (they don't stack).
func get_incoming_damage_multiplier(player_id: int) -> float:
	# CRISIS takes priority
	if _is_crisis_active:
		return get_crisis_damage_multiplier()

	# Check SOLO mode
	var idx: int = player_id - 1
	var partner_idx: int = 1 - idx
	var me_ok: bool = (_player_state[idx] == CoopState.ACTIVE) or (_player_state[idx] == CoopState.RESCUED)
	var partner_down: bool = (_player_state[partner_idx] == CoopState.DOWNTIME) or (_player_state[partner_idx] == CoopState.OUT)
	var is_solo: bool = me_ok and partner_down

	if is_solo:
		return 1.0 - SOLO_DAMAGE_REDUCTION

	return 1.0


## Attempt to rescue a downed player. Call when rescuer is within range.
## Returns true if rescue was successful.
func attempt_rescue(rescuer_id: int, downed_player_id: int, rescuer_color: Color = Color.WHITE) -> bool:
	var downed_idx: int = downed_player_id - 1
	if _player_state[downed_idx] != CoopState.DOWNTIME:
		return false  # Not in downtime

	_player_state[downed_idx] = CoopState.RESCUED
	var current_time: float = Time.get_ticks_msec() / 1000.0
	_rescued_iframe_end_time[downed_idx] = current_time + RESCUED_IFRAMES_DURATION
	_rescued_iframe_end_time[rescuer_id - 1] = current_time + RESCUED_IFRAMES_DURATION

	# Restore some HP on rescue (50%)
	_player_hp[downed_idx] = PLAYER_MAX_HP / 2

	player_rescued.emit(downed_player_id, rescuer_color)
	rescue_triggered.emit(Vector2.ZERO, rescuer_color)  # Position from GameState
	return true


## Process per-frame timers. Call from _process(delta).
func update(delta: float) -> void:
	_update_rescue_timers()
	_update_crisis_state()
	_update_rescued_iframes()
	_update_solo_mode()


# ─── Internal ──────────────────────────────────────────────────────────────────

func _enter_downtime(player_id: int) -> void:
	var idx: int = player_id - 1
	_player_state[idx] = CoopState.DOWNTIME
	_downtime_start_time[idx] = Time.get_ticks_msec() / 1000.0
	player_downed.emit(player_id)


func _update_rescue_timers() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	for i in range(2):
		if _player_state[i] == CoopState.DOWNTIME:
			var elapsed: float = current_time - _downtime_start_time[i]
			if elapsed >= RESCUE_WINDOW:
				_player_state[i] = CoopState.OUT
				player_out.emit(i + 1)


func _update_crisis_state() -> void:
	var p1_percent: float = get_player_hp_percent(1)
	var p2_percent: float = get_player_hp_percent(2)
	var both_below_threshold: bool = (p1_percent < CRISIS_HP_THRESHOLD) and (p2_percent < CRISIS_HP_THRESHOLD)
	var both_alive: bool = is_coop_bonus_active()

	if both_below_threshold and both_alive:
		if not _is_crisis_active:
			_is_crisis_active = true
			crisis_state_changed.emit(true)
			crisis_activated.emit()
	else:
		if _is_crisis_active:
			_is_crisis_active = false
			crisis_state_changed.emit(false)

	# Emit coop_bonus_active when state changes
	var coop_bonus_now: bool = both_alive
	if coop_bonus_now != _was_coop_bonus_active:
		_was_coop_bonus_active = coop_bonus_now
		coop_bonus_active.emit(1.0 + COOP_BONUS if coop_bonus_now else 1.0)


func _update_solo_mode() -> void:
	# Check solo mode for each player
	for i in range(2):
		var is_solo_now: bool = is_solo_mode(i + 1)
		if is_solo_now != _was_solo_mode[i]:
			_was_solo_mode[i] = is_solo_now
			if is_solo_now:
				solo_mode_active.emit(i + 1)


func _update_rescued_iframes() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	for i in range(2):
		if _player_state[i] == CoopState.RESCUED:
			if current_time >= _rescued_iframe_end_time[i]:
				_player_state[i] = CoopState.ACTIVE


# ─── I-frames (Story 003) ────────────────────────────────────────────────────────

## Returns true if player has invincibility frames (RESCUED state with active timer).
func has_iframes(player_id: int) -> bool:
	var idx: int = player_id - 1
	if _player_state[idx] != CoopState.RESCUED:
		return false
	var current_time: float = Time.get_ticks_msec() / 1000.0
	return current_time < _rescued_iframe_end_time[idx]


## Returns remaining i-frame time in seconds.
func get_iframe_remaining(player_id: int) -> float:
	var idx: int = player_id - 1
	if _player_state[idx] != CoopState.RESCUED:
		return 0.0
	var current_time: float = Time.get_ticks_msec() / 1000.0
	return maxf(0.0, _rescued_iframe_end_time[idx] - current_time)


## Returns true if damage should be blocked (player has i-frames).
func should_block_damage(player_id: int) -> bool:
	return has_iframes(player_id)


## Apply damage to a player in DOWNTIME (they can be hit while downed).
func apply_damage_to_down_player(player_id: int, damage: int) -> void:
	var idx: int = player_id - 1
	if _player_state[idx] != CoopState.DOWNTIME:
		return
	_player_hp[idx] = maxi(0, _player_hp[idx] - damage)
	Events.player_damaged.emit(player_id, damage)
	Events.player_hp_changed.emit(player_id, _player_hp[idx], PLAYER_MAX_HP)


## Returns true if player is in OUT state.
func is_player_out(player_id: int) -> bool:
	return _player_state[player_id - 1] == CoopState.OUT


## Reset both players to ACTIVE with full HP (called on life loss / team wipe).
func trigger_life_loss() -> void:
	_player_hp[0] = PLAYER_MAX_HP
	_player_hp[1] = PLAYER_MAX_HP
	_player_state[0] = CoopState.ACTIVE
	_player_state[1] = CoopState.ACTIVE
	_downtime_start_time[0] = -1.0
	_downtime_start_time[1] = -1.0
	_rescued_iframe_end_time[0] = -1.0
	_rescued_iframe_end_time[1] = -1.0
	_is_crisis_active = false


## Respawn a player at checkpoint (AC-13).
func respawn_player(player_id: int) -> void:
	var idx: int = player_id - 1
	_player_hp[idx] = PLAYER_MAX_HP
	_player_state[idx] = CoopState.ACTIVE
	_downtime_start_time[idx] = -1.0
	_rescued_iframe_end_time[idx] = -1.0
