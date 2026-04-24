# ComboManager.gd — Autoload singleton for combo system
# Implements ADR-ARCH-004: Combo System Data Structures
# Manages per-player ComboData and sync detection across both players
class_name ComboManager
extends Node

## Autoload singleton coordinating combo state for both players.
## Tracks combo_count, combo_timer, sync_chain_length per player via ComboData.
## Evaluates sync detection and emits sync_burst_triggered when chain reaches 3.

## Maximum combo count for display (99 shown as "99+")
const MAX_COMBO_COUNT_DISPLAY: int = 99

## Combo window duration in seconds (combo-004)
const COMBO_WINDOW_DURATION: float = 1.5

# ─── Per-Player Combo Data ─────────────────────────────────────────────────────
var _player_combo_data: Dictionary = {
	1: null,  # ComboData for player 1
	2: null   # ComboData for player 2
}

# ─── Signals ───────────────────────────────────────────────────────────────────
## Emitted when sync chain changes (combo-003 AC-26)
## chain_length: int — current consecutive SYNC hit count (0 = chain broken)
signal sync_chain_active(chain_length: int)

## Emitted when 3 consecutive SYNC hits are reached — triggers Sync Burst VFX
## Per combo-003 AC-11
signal sync_burst_triggered(boss_position: Vector2)

## Emitted when combo multiplier is updated (combo-005 AC-signals)
signal combo_multiplier_updated(multiplier: float, player_id: int)

## Emitted when combo tier changes for a player (combo-005 AC-25)
signal combo_tier_changed(tier: int, player_id: int)

## Emitted when combo count resets to 0 (combo-004 AC-27)
signal combo_break(player_id: int)

## Emitted when combo tier escalates — triggers VFX burst (combo-005)
signal combo_tier_escalated(tier: int, player_color: Color)

## Emitted for audio tier sound selection (combo-005)
signal combo_tier_audio(tier: int)

## Emitted when sync window opens between two players (combo-005)
signal sync_window_opened(player_id: int, partner_id: int)

# ─── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player_combo_data[1] = ComboData.new(1)
	_player_combo_data[2] = ComboData.new(2)
	_connect_signals()


func _connect_signals() -> void:
	# Connect to Events.combo_hit from CombatManager
	Events.combo_hit.connect(_on_combo_hit)


# ─── Per-Frame Update (Combo Timer — combo-004) ────────────────────────────────

## Called each frame to advance combo timers for both players.
## Per story-004: timer does NOT advance during hitstop.
func _process(delta: float) -> void:
	for player_id in [1, 2]:
		update_player_combo(player_id, delta)


# ─── Signal Handler: Events.combo_hit ─────────────────────────────────────────

## Handler for Events.combo_hit.
## Called when a hit lands — updates combo state and emits downstream signals.
func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
	# Determine which player based on attack_type or frame data
	# For now, broadcast to both players (the actual player_id comes from hitbox)
	for player_id in [1, 2]:
		_process_hit_for_player(player_id, combo_count)


## Process a hit for a specific player.
func _process_hit_for_player(player_id: int, combo_count: int) -> void:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return

	var prev_tier: int = data.current_tier

	# Register the hit
	data.register_hit(0)  # frame_number=0 (not used in this path)

	# Emit combo_multiplier_updated
	var mult := get_combo_multiplier(player_id)
	combo_multiplier_updated.emit(mult, player_id)

	# Check tier change
	var new_tier: int = data.current_tier
	if new_tier != prev_tier:
		combo_tier_changed.emit(new_tier, player_id)
		combo_tier_escalated.emit(new_tier, _get_player_color(player_id))
		combo_tier_audio.emit(new_tier)

	# Emit sync_chain_active
	sync_chain_active.emit(data.sync_chain_length)

	# Check sync burst
	if TierLogic.should_trigger_sync_burst(data.sync_chain_length):
		sync_burst_triggered.emit(Vector2.ZERO)  # Boss position set by caller


# ─── Public API ────────────────────────────────────────────────────────────────

## Get ComboData for a player.
func get_combo_data(player_id: int) -> ComboData:
	return _player_combo_data.get(player_id)


## Get current combo multiplier for a player (combo-005 query).
func get_combo_multiplier(player_id: int) -> float:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return 1.0
	return CombatManager.get_combo_multiplier(data.combo_count)


## Get current combo tier for a player (combo-005 query).
func get_combo_tier(player_id: int) -> int:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return 0
	return data.current_tier


## Get current sync chain length for a player (combo-005 query).
func get_sync_chain_length(player_id: int) -> int:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return 0
	return data.sync_chain_length


## Evaluate sync detection when a player lands a hit.
## Called by the combat system after register_hit.
## Returns true if this hit was a SYNC hit.
func evaluate_sync_for_player(player_id: int, frame_number: int) -> bool:
	var my_data: ComboData = _player_combo_data.get(player_id)
	var opponent_id: int = 2 if player_id == 1 else 1
	var opponent_data: ComboData = _player_combo_data.get(opponent_id)

	if my_data == null or opponent_data == null:
		return false

	var opponent_frame: int = opponent_data.last_hit_frame
	var is_sync: bool = TierLogic.is_sync_hit(frame_number, opponent_frame)

	if is_sync:
		# Both players' chain counters increment together
		my_data.register_sync_hit()
		opponent_data.register_sync_hit()

		# Emit sync_window_opened
		sync_window_opened.emit(player_id, opponent_id)

		# Check for Sync Burst trigger
		if TierLogic.should_trigger_sync_burst(my_data.sync_chain_length):
			sync_burst_triggered.emit(Vector2.ZERO)
			sync_chain_active.emit(my_data.sync_chain_length)
	else:
		# Non-SYNC hit resets both chains to 0
		my_data.sync_chain_length = 0
		opponent_data.sync_chain_length = 0
		sync_chain_active.emit(0)

	return is_sync


## Called each physics frame to advance combo timers.
## Returns true if combo is still active, false if timer expired.
func update_player_combo(player_id: int, delta: float) -> bool:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return false

	# Track previous count for combo_break detection
	var had_combo := data.combo_count > 0

	# Advance timer
	var result := data.update(delta)

	# Check timer expiry — if timer >= COMBO_WINDOW_DURATION, combo breaks
	if had_combo and data.combo_timer >= COMBO_WINDOW_DURATION:
		_reset_combo(player_id)
		return false

	return result


## Reset all combo state for a player (on death, boss phase change, round end).
func reset_player_combo(player_id: int) -> void:
	var data: ComboData = _player_combo_data.get(player_id)
	if data != null:
		data.reset()


## Reset both players' combo state.
func reset_all() -> void:
	for player_id in [1, 2]:
		reset_player_combo(player_id)


## Get display combo count (capped at MAX_COMBO_COUNT_DISPLAY).
func get_display_combo_count(player_id: int) -> int:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return 0
	return mini(data.combo_count, MAX_COMBO_COUNT_DISPLAY)


## Check if a player currently has an active combo.
func is_combo_active(player_id: int) -> bool:
	var data: ComboData = _player_combo_data.get(player_id)
	if data == null:
		return false
	return data.combo_count > 0


# ─── Internal ─────────────────────────────────────────────────────────────────

func _reset_combo(player_id: int) -> void:
	var data: ComboData = _player_combo_data.get(player_id)
	if data != null:
		data.reset()
	combo_break.emit(player_id)


func _get_player_color(player_id: int) -> Color:
	# Placeholder — actual implementation would look up player character color
	# For now, default to P1 orange
	return VFXManager.COLOR_P1
