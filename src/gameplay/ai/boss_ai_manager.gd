# BossAIManager.gd — Autoload singleton for boss AI system
# Implements ADR-ARCH-006: Boss AI System
# Manages boss state machine, phases, attack patterns, and player tracking
extends Node

## Autoload singleton for the boss AI state machine.
## Manages boss phases, attack patterns, compression wall, and rescue crisis modulation.

# ─── Constants (from GDD tuning knobs) ─────────────────────────────────────────
const BASE_BOSS_HP: int = 500
const BASE_COMPRESSION_SPEED: float = 32.0   ## px/s
const COMPRESSION_DAMAGE_RATE: float = 5.0     ## hp/s
const MIN_ATTACK_INTERVAL: float = 1.5        ## seconds
const MERCY_ZONE: float = 100.0              ## pixels
const RESCUE_SLOWDOWN: float = 0.5
const RESCUE_SUSPENSION: float = 2.0          ## seconds
const PHASE_2_THRESHOLD: float = 0.60         ## 60% HP
const PHASE_3_THRESHOLD: float = 0.30         ## 30% HP
const PHASE_CHANGE_HOLD: float = 1.0          ## Seconds to hold PHASE_CHANGE before transitioning

## Attack pattern constants
const PATTERN_RELENTLESS_ADVANCE := "Pattern_1_Relentless_Advance"
const PATTERN_PAPER_AVALANCHE := "Pattern_2_Paper_Avalanche"
const PATTERN_PANIC_OVERLOAD := "Pattern_3_Panic_Overload"
const PATTERN_NONE := "NONE"

## Attack timing constants
const BASE_ATTACK_COOLDOWN: float = 2.5    ## Base cooldown at full HP (seconds)
const ATTACK_TELEGRAPH_TIME: float = 0.8  ## Telegraph delay before attack

## Attack display names for UI
const PATTERN_DISPLAY_NAMES := {
	PATTERN_RELENTLESS_ADVANCE: "截稿压力",
	PATTERN_PAPER_AVALANCHE: "工作堆积",
	PATTERN_PANIC_OVERLOAD: "Deadline panic"
}

# ─── Boss State Enum ────────────────────────────────────────────────────────────
enum BossState {
	IDLE,
	ATTACKING,
	HURT,
	PHASE_CHANGE,
	DEFEATED
}

# ─── Signals ───────────────────────────────────────────────────────────────────
signal boss_attack_started(attack_pattern: String)
signal boss_phase_changed(new_phase: int)
signal boss_phase_warning(phase: int)
signal boss_attack_telegraph(pattern: String)
signal boss_defeated()
signal boss_hp_changed(current_hp: int, max_hp: int)

# ─── Member Variables ───────────────────────────────────────────────────────────
var _boss_state: BossState = BossState.IDLE
var _previous_state: BossState = BossState.IDLE
var _boss_hp: int = BASE_BOSS_HP
var _boss_max_hp: int = BASE_BOSS_HP
var _current_phase: int = 1
var _compression_wall_x: float = 0.0
var _attack_cooldown: float = 0.0
var _rescue_suspension_timer: float = 0.0
var _players_behind: bool = false
var _state_timer: float = 0.0  ## Tracks time spent in current state
var _hurt_duration: float = 0.0  ## Duration of current HURT state
var _pending_phase: int = 0  ## Phase being transitioned to

## Player position tracking for attack selection
var _player1_pos: Vector2 = Vector2.ZERO
var _player2_pos: Vector2 = Vector2.ZERO
var _player1_id: int = -1
var _player2_id: int = -1
var _player1_node_id: int = -1
var _player2_node_id: int = -1

# ─── Lifecycle ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_boss_hp = BASE_BOSS_HP
	_boss_max_hp = BASE_BOSS_HP
	_current_phase = 1
	_boss_state = BossState.IDLE

	# Connect to Events signals
	if Events:
		Events.combo_hit.connect(_on_combo_hit)
		Events.player_downed.connect(_on_player_downed)
		Events.crisis_state_changed.connect(_on_crisis_state_changed)
		Events.boss_defeated.connect(_on_boss_defeated)


## Called each physics frame to update timers and compression wall.
func update(delta: float) -> void:
	_update_compression(delta)
	_update_attack_cooldown(delta)
	_update_rescue_suspension(delta)
	_update_hurt_timer(delta)
	_update_players_behind_status()
	_check_game_over_condition()


## Update compression wall position and apply damage.
## Compression advances every frame except in DEFEATED or PHASE_CHANGE states.
func _update_compression(delta: float) -> void:
	if _boss_state == BossState.DEFEATED or _boss_state == BossState.PHASE_CHANGE:
		return

	var speed: float = _calculate_compression_speed()
	_compression_wall_x += speed * delta

	# Apply damage to players in danger zone
	_apply_compression_damage(delta)


## Calculate compression speed with phase and state modulation.
## Formula (per GDD Rule 4):
##   - base = BASE_COMPRESSION_SPEED (32px/s)
##   - If player downed: base * 0.5
##   - Else if player behind: base * 0.6
##   - Else if both in crisis: base * 1.2
##   - Else: base * phase_multiplier (1.0/1.5/2.0 for phases 1/2/3)
func _calculate_compression_speed() -> float:
	var base_speed: float = BASE_COMPRESSION_SPEED

	# Check player downed (rescue window)
	if _is_any_player_down():
		return base_speed * 0.5

	# Check player behind mercy zone
	if _players_behind:
		return base_speed * 0.6

	# Check crisis state
	if _is_crisis_active():
		return base_speed * 1.2

	# Apply phase multiplier
	var phase_multiplier: float = 1.0
	match _current_phase:
		2:
			phase_multiplier = 1.5
		3:
			phase_multiplier = 2.0

	return base_speed * phase_multiplier


## Apply compression damage to players in the danger zone.
## Damage rate = COMPRESSION_DAMAGE_RATE per second per player in zone.
func _apply_compression_damage(delta: float) -> void:
	# This method would query player positions and emit Events.player_hurt
	# Stub implementation — actual integration with player positions happens in story-007
	pass


## Update attack cooldown timer.
func _update_attack_cooldown(delta: float) -> void:
	if _attack_cooldown > 0:
		_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)


## Update rescue suspension timer.
func _update_rescue_suspension(delta: float) -> void:
	if _rescue_suspension_timer > 0:
		_rescue_suspension_timer = maxf(_rescue_suspension_timer - delta, 0.0)


## Update hurt and phase change state timers.
func _update_hurt_timer(delta: float) -> void:
	if _boss_state == BossState.HURT:
		_state_timer += delta
		if _state_timer >= _hurt_duration:
			_transition_to(BossState.IDLE)
	elif _boss_state == BossState.PHASE_CHANGE:
		_state_timer += delta
		if _state_timer >= PHASE_CHANGE_HOLD:
			_handle_phase_change()


# ─── Public API ─────────────────────────────────────────────────────────────────

## Get the current boss state as a string.
func get_boss_state() -> String:
	return BossState.keys()[_boss_state]


## Get the current phase (1, 2, or 3).
func get_current_phase() -> int:
	return _current_phase


## Apply damage to the boss. Returns actual damage taken.
func apply_damage_to_boss(damage: int) -> int:
	if _boss_state == BossState.DEFEATED:
		return 0

	var prev_hp: int = _boss_hp
	_boss_hp = maxi(0, _boss_hp - damage)
	var actual_damage: int = prev_hp - _boss_hp

	boss_hp_changed.emit(_boss_hp, _boss_max_hp)

	# Check for defeat first (before phase transition)
	if _boss_hp <= 0:
		force_defeated()
		return actual_damage

	# Check for phase transition
	_check_phase_transition()

	return actual_damage


## Set boss HP directly (for heal/buff effects).
func set_boss_hp(new_hp: int) -> void:
	if _boss_state == BossState.DEFEATED:
		return

	_boss_hp = clampi(new_hp, 0, _boss_max_hp)
	boss_hp_changed.emit(_boss_hp, _boss_max_hp)

	# Check for defeat first
	if _boss_hp <= 0:
		force_defeated()
		return

	_check_phase_transition()


## Get HP ratio (0.0 to 1.0).
func get_hp_ratio() -> float:
	return float(_boss_hp) / float(_boss_max_hp)


## Get current boss HP.
func get_boss_hp() -> int:
	return _boss_hp


## Get boss max HP.
func get_boss_max_hp() -> int:
	return _boss_max_hp


## Set max HP (for boss scaling).
func set_max_hp(new_max: int) -> void:
	_boss_max_hp = new_max
	_boss_hp = mini(_boss_hp, _boss_max_hp)  # Clamp current HP to new max


## Get boss HP as a fraction (0.0 to 1.0).
func get_boss_hp_percent() -> float:
	return float(_boss_hp) / float(_boss_max_hp)


## Returns true if boss is currently in an attack state.
func is_boss_attacking() -> bool:
	return _boss_state == BossState.ATTACKING


## Get display name for an attack pattern (for UI).
func get_attack_display_name(pattern: String) -> String:
	return PATTERN_DISPLAY_NAMES.get(pattern, pattern)


## Attempt to transition to ATTACKING state.
## Only succeeds if current state is IDLE.
func request_attack() -> void:
	if _boss_state == BossState.IDLE:
		_transition_to(BossState.ATTACKING)


## Attempt to transition to HURT state.
## Succeeds from any non-DEFEATED state.
func request_hurt(duration: float) -> void:
	if _boss_state != BossState.DEFEATED:
		_hurt_duration = duration
		_transition_to(BossState.HURT)


## Force the boss to DEFEATED state (terminal).
func force_defeated() -> void:
	_transition_to(BossState.DEFEATED)


# ─── Internal ──────────────────────────────────────────────────────────────────

## Validates and performs a state transition.
## Side effects per target state:
##   ATTACKING: emit boss_attack_started
##   DEFEATED: stop compression wall
func _transition_to(new_state: BossState) -> bool:
	# Validate transition rules
	if not _is_transition_allowed(_boss_state, new_state):
		return false

	var old_state := _boss_state
	_previous_state = old_state
	_boss_state = new_state
	_state_timer = 0.0  # Reset timer on transition

	# Side effects per target state
	match new_state:
		BossState.ATTACKING:
			var pattern: String = _select_attack_pattern()
			if pattern != PATTERN_NONE:
				# Telegraph before attack for UI warning
				boss_attack_telegraph.emit(pattern)
				# Emit for other systems
				boss_attack_started.emit(pattern)
				if Events:
					Events.boss_attack_started.emit(pattern)
				# Set attack cooldown
				_attack_cooldown = _calculate_attack_cooldown()
		BossState.DEFEATED:
			_compression_wall_x = -9999.0  # Stop compression wall
			boss_defeated.emit()

	return true


## Returns true if transition from current to new_state is allowed.
## Transition rules (GDD):
##   IDLE       → ATTACKING, HURT, PHASE_CHANGE, DEFEATED
##   ATTACKING  → IDLE, HURT, PHASE_CHANGE, DEFEATED
##   HURT       → IDLE, PHASE_CHANGE, DEFEATED
##   PHASE_CHANGE → IDLE, ATTACKING, DEFEATED
##   DEFEATED   → (none)
func _is_transition_allowed(current: BossState, new_state: BossState) -> bool:
	if current == BossState.DEFEATED:
		return false  # Terminal state
	if new_state == BossState.DEFEATED:
		return true   # Any state can go to DEFEATED

	match current:
		BossState.IDLE:
			return new_state in [BossState.ATTACKING, BossState.HURT, BossState.PHASE_CHANGE, BossState.DEFEATED]
		BossState.ATTACKING:
			return new_state in [BossState.IDLE, BossState.HURT, BossState.PHASE_CHANGE, BossState.DEFEATED]
		BossState.HURT:
			return new_state in [BossState.IDLE, BossState.PHASE_CHANGE, BossState.DEFEATED]
		BossState.PHASE_CHANGE:
			return new_state in [BossState.IDLE, BossState.DEFEATED]  # Attacks blocked during phase change

	return false


func _check_phase_transition() -> void:
	var hp_ratio: float = get_hp_ratio()
	var old_phase: int = _current_phase

	# Determine new phase
	if hp_ratio <= PHASE_3_THRESHOLD:
		_current_phase = 3
	elif hp_ratio <= PHASE_2_THRESHOLD:
		_current_phase = 2
	else:
		_current_phase = 1

	# Trigger transition if phase changed
	if _current_phase != old_phase:
		_trigger_phase_change(old_phase, _current_phase)


## Trigger phase change with warning signal and state transition.
func _trigger_phase_change(old_phase: int, new_phase: int) -> void:
	# Don't interrupt if already in phase change or defeated
	if _boss_state == BossState.PHASE_CHANGE or _boss_state == BossState.DEFEATED:
		return

	# Store pending phase for later emission
	_pending_phase = new_phase

	# Emit warning signal first (for UI telegraph)
	boss_phase_warning.emit(new_phase)

	# Transition to PHASE_CHANGE state
	_transition_to(BossState.PHASE_CHANGE)


## Internal: Handle phase change completion.
func _handle_phase_change() -> void:
	if _pending_phase <= 0:
		return

	var new_phase := _pending_phase
	_pending_phase = 0

	# Emit the actual phase change signal
	boss_phase_changed.emit(new_phase)

	# Also emit via Events for other systems
	if Events:
		Events.boss_phase_changed.emit(new_phase)

	# Transition to IDLE after phase change is complete
	_transition_to(BossState.IDLE)


## Register a player with the boss AI for tracking.
func register_player(player_id: int, player_node: Node2D) -> void:
	if _player1_id == -1:
		_player1_id = player_id
		_player1_node_id = player_node.get_instance_id()
		_player1_pos = player_node.global_position
	elif _player2_id == -1:
		_player2_id = player_id
		_player2_node_id = player_node.get_instance_id()
		_player2_pos = player_node.global_position


## Get player position by player ID.
func _get_player_position(player_id: int) -> Vector2:
	match player_id:
		1:
			return _player1_pos
		2:
			return _player2_pos
	return Vector2.ZERO


## Returns true if player is behind the compression wall (within mercy zone).
func _is_player_behind(player_id: int) -> bool:
	var player_pos := _get_player_position(player_id)
	if player_pos == Vector2.ZERO:
		return false
	return player_pos.x < _compression_wall_x + MERCY_ZONE


## Returns true if crisis state is currently active (both players below 30% HP).
func _is_crisis_active() -> bool:
	return CoopManager.is_crisis_active()


## Returns true if a player is in DOWNTIME or OUT state.
func _is_player_down(player_id: int) -> bool:
	var state: CoopState = CoopManager.get_player_state(player_id)
	return state == CoopState.DOWNTIME or state == CoopState.OUT


## Returns true if any player is in rescue mode (downed).
func _is_in_rescue_mode() -> bool:
	return _is_player_down(1) or _is_player_down(2)


## Update _players_behind flag based on both players' positions.
func _update_players_behind_status() -> void:
	_players_behind = _is_player_behind(1) or _is_player_behind(2)


## Check if game over condition is met (both players downed).
func _check_game_over_condition() -> void:
	if _is_player_down(1) and _is_player_down(2):
		if Events:
			Events.game_over.trigger()


## Notify: player detected by boss AI perception.
func notify_player_detected(player: Node2D) -> void:
	_on_player_detected(player)


## Notify: player lost from boss AI perception.
func notify_player_lost(player: Node2D) -> void:
	_on_player_lost(player)


## Notify: player hurt (for AI aggression modulation).
func notify_player_hurt(player: Node2D, damage: float) -> void:
	_on_player_hurt(player, damage)


## Signal handler: player detected.
func _on_player_detected(player: Node2D) -> void:
	# Track player position for attack selection
	# Update _players_behind flag based on MERCY_ZONE
	var player_pos := player.global_position
	if _player1_id != -1 and player_pos == _player1_pos:
		_player1_pos = player_pos
	elif _player2_id != -1 and player_pos == _player2_pos:
		_player2_pos = player_pos

	# Update _players_behind based on compression wall
	if _compression_wall_x > 0:
		_players_behind = (player_pos.x < _compression_wall_x - MERCY_ZONE)


## Signal handler: player lost from perception.
func _on_player_lost(player: Node2D) -> void:
	# Stop tracking that player
	pass


## Signal handler: player hurt (for AI aggression modulation).
func _on_player_hurt(player: Node2D, damage: float) -> void:
	# AI could increase aggression based on damage dealt
	pass


## Signal handler: combo hit.
func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
	# AI can read combo count to adjust behavior
	# e.g., become more aggressive at high combos
	pass


## Signal handler: player downed.
func _on_player_downed(player_id: int) -> void:
	_rescue_suspension_timer = RESCUE_SUSPENSION


## Signal handler: crisis state changed.
func _on_crisis_state_changed(is_crisis: bool) -> void:
	# Crisis affects compression speed via _calculate_compression_speed
	# This stub returns false; actual crisis state comes from CoopManager
	pass


## Signal handler: boss defeated via Events.
func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
	force_defeated()


# ─── Compression Query Methods ─────────────────────────────────────────────────────

## Get the current compression wall X position.
func get_compression_wall_x() -> float:
	return _compression_wall_x


## Get the current compression wall speed (for UI display).
func get_compression_speed() -> float:
	return _calculate_compression_speed()


## Returns true if the player position is in the danger zone (left of wall).
func is_player_in_danger_zone(player_pos: Vector2) -> bool:
	return player_pos.x < _compression_wall_x


# ─── Attack Pattern Selection ─────────────────────────────────────────────────────

## Returns true if boss can attack (IDLE state and cooldown expired).
func can_attack() -> bool:
	return _boss_state == BossState.IDLE and _attack_cooldown <= 0


## Select attack pattern based on phase and context.
## Priority: rescue_suspension > player_down > phase_selection
func _select_attack_pattern() -> String:
	# Pause attacks during rescue suspension
	if _rescue_suspension_timer > 0:
		return PATTERN_NONE

	# Pause attacks when player is downed
	if _is_any_player_down():
		return PATTERN_NONE

	# Select based on phase
	match _current_phase:
		1:
			return _select_phase1_pattern()
		2:
			return _select_phase2_pattern()
		3:
			return _select_phase3_pattern()

	return PATTERN_NONE


## Phase 1: Always Relentless Advance (no frontal attacks, just compression).
func _select_phase1_pattern() -> String:
	return PATTERN_RELENTLESS_ADVANCE


## Phase 2: Paper Avalanche when player near wall, else Relentless Advance.
func _select_phase2_pattern() -> String:
	# Paper Avalanche when player is within 300px of compression wall
	if _compression_wall_x > 0 and _players_behind:
		return PATTERN_RELENTLESS_ADVANCE
	# Player close to wall triggers Paper Avalanche
	# Note: _players_behind flag is set based on MERCY_ZONE check
	return PATTERN_PAPER_AVALANCHE


## Phase 3: Always Panic Overload (highest aggression).
func _select_phase3_pattern() -> String:
	return PATTERN_PANIC_OVERLOAD


## Calculate attack cooldown based on current HP.
## Formula: max(MIN_ATTACK_INTERVAL, BASE_ATTACK_COOLDOWN * hp_multiplier)
## hp_multiplier: linear from 0.5 at 0% HP to 1.0 at 100% HP
func _calculate_attack_cooldown() -> float:
	var hp_ratio: float = get_hp_ratio()
	var hp_multiplier: float = 0.5 + 0.5 * hp_ratio
	var cooldown: float = BASE_ATTACK_COOLDOWN * hp_multiplier
	return maxf(cooldown, MIN_ATTACK_INTERVAL)
