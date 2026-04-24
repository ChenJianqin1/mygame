# player_state_machine.gd — Gameplay state machine for player combat states
# Implements combat-007: 7-state player state machine integration
# States: IDLE | MOVING | ATTACKING | HURT | DODGING | BLOCKING | DOWNTIME
# Integrates with Events (input actions) and CombatManager (dodge/defense)

class_name PlayerStateMachine
extends Node

## Player gameplay states per ADR-ARCH-003
enum State {
	IDLE,
	MOVING,
	ATTACKING,
	HURT,
	DODGING,
	BLOCKING,
	DOWNTIME
}

## HURT state duration in frames (per GDD AC-STATE-*)
const HURT_DURATION: int = 10

## BLOCKING state timeout in frames (released or auto-timeout)
const BLOCK_TIMEOUT: int = 60

## Player ID for single-player (1 = P1, 2 = P2)
var player_id: int = 1

## Current state
var _current_state: State = State.IDLE

## State timers
var _hurt_timer: int = 0
var _block_timer: int = 0

## Track if block input is held
var _block_held: bool = false

## Movement state
var _is_moving: bool = false

## Signals
signal player_state_changed(old_state: State, new_state: State)
signal state_frame_update(delta_frames: int)  # For systems that need frame-tick updates

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()


func _process(delta: float) -> void:
	_update_state_timers()


func _connect_signals() -> void:
	# Input actions
	Events.input_action.connect(_on_input_action)
	# Combat events
	Events.hurt_received.connect(_on_hurt_received)
	Events.player_hp_changed.connect(_on_player_hp_changed)
	# Animation events
	Events.attack_started.connect(_on_attack_started)


func _update_state_timers() -> void:
	match _current_state:
		State.HURT:
			_hurt_timer -= 1
			if _hurt_timer <= 0:
				_transition_to(State.IDLE)
		State.BLOCKING:
			_block_timer -= 1
			if _block_timer <= 0 or not _block_held:
				_transition_to(State.IDLE)
		State.DODGING:
			# DODGING timer is managed by CombatManager
			# We just need to check if dodge ended
			if not CombatManager.is_invincible(player_id):
				_transition_to(State.IDLE)

# ─── Public API ────────────────────────────────────────────────────────────────

## Get the current state
func get_state() -> State:
	return _current_state


## Request transition from external code
func request_state(new_state: State) -> void:
	_transition_to(new_state)


## Called by animation system when attack animation ends
func on_attack_animation_ended() -> void:
	if _current_state == State.ATTACKING:
		_transition_to(State.IDLE)


## Called by animation system when hurt animation ends
func on_hurt_animation_ended() -> void:
	if _current_state == State.HURT:
		_transition_to(State.IDLE)


# ─── Signal Handlers ─────────────────────────────────────────────────────────

func _on_input_action(player_id: int, action: StringName, strength: float) -> void:
	if player_id != self.player_id:
		return

	match action:
		&"move":
			_handle_move_input(strength)
		&"light_attack", &"medium_attack", &"heavy_attack", &"special_attack":
			_handle_attack_input(String(action))
		&"dodge":
			_handle_dodge_input()
		&"block":
			_handle_block_input(strength > 0)


func _on_hurt_received(damage: int, knockback: Vector2) -> void:
	# HURT has highest priority — interrupts everything except DODGING
	if _current_state == State.DODGING:
		return
	_transition_to(State.HURT)
	_hurt_timer = HURT_DURATION


func _on_player_hp_changed(player_id: int, current: int, max: int) -> void:
	if player_id != self.player_id:
		return
	if current <= 0:
		_transition_to(State.DOWNTIME)


func _on_attack_started(attack_type: String) -> void:
	# Attack started via CombatManager — transition to ATTACKING
	if _current_state == State.IDLE or _current_state == State.MOVING:
		_transition_to(State.ATTACKING)


# ─── Input Handlers ──────────────────────────────────────────────────────────

func _handle_move_input(strength: float) -> void:
	if strength > 0:
		if not _is_moving and _current_state == State.IDLE:
			_transition_to(State.MOVING)
		_is_moving = true
	else:
		if _is_moving and _current_state == State.MOVING:
			_transition_to(State.IDLE)
		_is_moving = false


func _handle_attack_input(attack_type: String) -> void:
	# Can attack from IDLE or MOVING
	if _current_state == State.IDLE or _current_state == State.MOVING:
		_transition_to(State.ATTACKING)
		Events.attack_started.emit(attack_type)


func _handle_dodge_input() -> void:
	# Can dodge from IDLE or MOVING
	if _current_state == State.IDLE or _current_state == State.MOVING:
		if CombatManager.start_dodge(player_id):
			_transition_to(State.DODGING)


func _handle_block_input(is_held: bool) -> void:
	_block_held = is_held
	if is_held:
		# Can block from IDLE or MOVING
		if _current_state == State.IDLE or _current_state == State.MOVING:
			_transition_to(State.BLOCKING)
			_block_timer = BLOCK_TIMEOUT
	else:
		# Block released — transition to IDLE if currently blocking
		if _current_state == State.BLOCKING:
			_transition_to(State.IDLE)


# ─── State Transitions ────────────────────────────────────────────────────────

func _transition_to(new_state: State) -> void:
	if _current_state == new_state:
		return

	var old_state: State = _current_state
	_current_state = new_state

	# Emit signal for VFX/UI systems
	player_state_changed.emit(old_state, new_state)

	# Reset state-specific timers
	match new_state:
		State.IDLE:
			_hurt_timer = 0
			_block_timer = 0
			_block_held = false
		State.DOWNTIME:
			_hurt_timer = 0
			_block_timer = 0
			_block_held = false
			_is_moving = false
