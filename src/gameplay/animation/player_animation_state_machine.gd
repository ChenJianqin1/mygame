# player_animation_state_machine.gd — Pure state machine for player animation
# Implements animation-001 AC-1.1 through AC-1.5
# Encapsulates state transition rules, attack interruption, and phase tracking.
# This is the pure logic layer — actual AnimationTree/BlendTree lives in scene files.
class_name PlayerAnimationStateMachine
extends RefCounted

## Player animation state identifiers matching ADR-ARCH-010
enum State {
	IDLE,
	MOVE,
	LIGHT_ATTACK,
	MEDIUM_ATTACK,
	HEAVY_ATTACK,
	SPECIAL_ATTACK,
	SYNC_ATTACK,
	HURT,
	RESCUE,
	DEFEAT
}

## Attack phase within an attack state
enum AttackPhase {
	ANTICIPATION,
	ACTIVE,
	RECOVERY
}

## Attack definitions: frame counts for each phase
const ATTACK_FRAMES := {
	State.LIGHT_ATTACK: { "anticipation": 8, "active": 2, "recovery": 6, "total": 16 },
	State.MEDIUM_ATTACK: { "anticipation": 14, "active": 3, "recovery": 10, "total": 27 },
	State.HEAVY_ATTACK: { "anticipation": 20, "active": 4, "recovery": 16, "total": 40 },
	State.SPECIAL_ATTACK: { "anticipation": 28, "active": 6, "recovery": 24, "total": 58 },
}

## Frame at which a faster attack can interrupt a slower attack's anticipation
## LIGHT (8 frames) can interrupt MEDIUM (14 frames) at frame 8 (exactly at LIGHT total)
## Rule A: fast attack can interrupt slow attack if fast.total >= slow.anticipation
const INTERRUPT_THRESHOLDS := {
	State.LIGHT_ATTACK: 16,   # LIGHT total frames
	State.MEDIUM_ATTACK: 27,  # MEDIUM total frames
	State.HEAVY_ATTACK: 40,
	State.SPECIAL_ATTACK: 58,
}

# ─── Runtime State ──────────────────────────────────────────────────────────────
var _current_state: State = State.IDLE
var _attack_phase: AttackPhase = AttackPhase.ANTICIPATION
var _current_attack_frames: int = 0  ## Frames elapsed in current attack state
var _total_frames: int = 0            ## Total animation frames elapsed

# ─── Public API ────────────────────────────────────────────────────────────────

## Get the current animation state
func get_state() -> State:
	return _current_state


## Get the current attack phase (only valid during attack states)
func get_attack_phase() -> AttackPhase:
	return _attack_phase


## Advance the state machine by one frame.
## Call each animation frame.
func advance_frame() -> void:
	_total_frames += 1

	if _is_in_attack_state():
		_current_attack_frames += 1
		_update_attack_phase()


## Attempt to transition to an attack state.
## Returns true if transition was accepted, false if blocked.
func request_attack(attack_type: State) -> bool:
	# HURT interrupts everything — no new attack allowed
	if _current_state == State.HURT or _current_state == State.DEFEAT:
		return false

	# From IDLE or MOVE, any attack is allowed
	if _current_state == State.IDLE or _current_state == State.MOVE:
		_start_attack(attack_type)
		return true

	# From another attack state — check interruption rules
	if _is_in_attack_state():
		return _try_interrupt(attack_type)

	# From other states (RESCUE, etc.) — block by default
	return false


## Trigger HURT state — interrupts all other states (Rule B: HURT highest priority)
func request_hurt() -> void:
	_current_state = State.HURT
	_attack_phase = AttackPhase.ANTICIPATION
	_current_attack_frames = 0


## Transition to IDLE state (called when animation finishes)
func request_idle() -> void:
	_current_state = State.IDLE
	_attack_phase = AttackPhase.ANTICIPATION
	_current_attack_frames = 0


## Transition to MOVE state
func request_move() -> void:
	if _current_state == State.IDLE:
		_current_state = State.MOVE


## Stop MOVE state
func request_stop_move() -> void:
	if _current_state == State.MOVE:
		_current_state = State.IDLE


# ─── Internal ─────────────────────────────────────────────────────────────────

func _is_in_attack_state() -> bool:
	return _current_state in [
		State.LIGHT_ATTACK, State.MEDIUM_ATTACK,
		State.HEAVY_ATTACK, State.SPECIAL_ATTACK, State.SYNC_ATTACK
	]

func _start_attack(attack_type: State) -> void:
	_current_state = attack_type
	_attack_phase = AttackPhase.ANTICIPATION
	_current_attack_frames = 0

func _update_attack_phase() -> void:
	var frames: Dictionary = ATTACK_FRAMES.get(_current_state, {})
	if frames.is_empty():
		return

	var ant := frames.get("anticipation", 0)
	var act := frames.get("active", 0)
	var rec := frames.get("recovery", 0)

	if _current_attack_frames < ant:
		_attack_phase = AttackPhase.ANTICIPATION
	elif _current_attack_frames < ant + act:
		_attack_phase = AttackPhase.ACTIVE
	else:
		_attack_phase = AttackPhase.RECOVERY

func _try_interrupt(new_attack: State) -> bool:
	## Rule C: No self-interrupt
	if new_attack == _current_state:
		return false

	## Check if new attack can interrupt current attack's anticipation
	var current_frames: Dictionary = ATTACK_FRAMES.get(_current_state, {})
	if current_frames.is_empty():
		return false

	var current_anticipation: int = current_frames.get("anticipation", 0)
	var new_total: int = INTERRUPT_THRESHOLDS.get(new_attack, 0)

	## Rule A: New attack can interrupt if it has enough frames
	## LIGHT (16 total) can interrupt MEDIUM (14 anticipation) at MEDIUM frame 8
	## Actually: LIGHT attack can be requested during MEDIUM anticipation
	## and if LIGHT's total frames >= MEDIUM's anticipation frames, it succeeds
	if new_total >= current_anticipation:
		_start_attack(new_attack)
		return true

	return false

func _is_in_anticipation() -> bool:
	return _attack_phase == AttackPhase.ANTICIPATION

func _is_in_active() -> bool:
	return _attack_phase == AttackPhase.ACTIVE

func _is_in_recovery() -> bool:
	return _attack_phase == AttackPhase.RECOVERY
