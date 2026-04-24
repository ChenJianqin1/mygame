# boss_animation_state_machine.gd — Boss animation state machine
# Implements animation-003 AC-4.1 through AC-4.4
# Boss phase transitions, idle speed scaling, defeat sequence
class_name BossAnimationStateMachine
extends RefCounted

## Boss animation states
enum BossAnimState {
	BOSS_IDLE,
	BOSS_ATTACK_A,
	BOSS_ATTACK_B,
	BOSS_VULNERABLE,
	BOSS_RAGE_ATTACK,
	BOSS_PHASE_TRANSITION,
	BOSS_CRISIS,
	BOSS_DEFEAT
}

## Idle animation frame counts per phase (stiffness progression)
const IDLE_FRAMES := {
	1: 24,  # Phase 1
	2: 20,  # Phase 2 (faster)
	3: 16   # Phase 3 (fastest)
}

## Phase transition duration in frames (60 frames per AC-4.1)
const PHASE_TRANSITION_FRAMES: int = 60

## Defeat animation duration in frames (90 frames per AC-4.4)
const DEFEAT_FRAMES: int = 90

## Attack animation frame counts
const ATTACK_FRAMES := {
	BossAnimState.BOSS_ATTACK_A: 40,
	BossAnimState.BOSS_ATTACK_B: 50,
	BossAnimState.BOSS_RAGE_ATTACK: 35
}

# ─── Runtime State ──────────────────────────────────────────────────────────────
var _current_state: BossAnimState = BossAnimState.BOSS_IDLE
var _current_phase: int = 1
var _animation_frame: int = 0
var _is_transitioning: bool = false  ## True during PHASE_TRANSITION or DEFEAT animations


# ─── Public API ────────────────────────────────────────────────────────────────

## Get the current animation state.
func get_state() -> BossAnimState:
	return _current_state


## Get the current phase (1, 2, or 3).
func get_phase() -> int:
	return _current_phase


## Returns true if a phase transition or defeat animation is playing.
func is_in_transition() -> bool:
	return _is_transitioning


## Advance the animation by one frame.
## Call each animation frame.
func advance_frame() -> void:
	_animation_frame += 1


## Request transition to attack state.
func request_attack_a() -> bool:
	if _is_transitioning:
		return false
	if _current_state == BossAnimState.BOSS_DEFEAT:
		return false
	_current_state = BossAnimState.BOSS_ATTACK_A
	_animation_frame = 0
	return true


func request_attack_b() -> bool:
	if _is_transitioning:
		return false
	if _current_state == BossAnimState.BOSS_DEFEAT:
		return false
	_current_state = BossAnimState.BOSS_ATTACK_B
	_animation_frame = 0
	return true


## Request RAGE_ATTACK (Phase 2+ only).
func request_rage_attack() -> bool:
	if _is_transitioning:
		return false
	if _current_state == BossAnimState.BOSS_DEFEAT:
		return false
	if _current_phase < 2:
		return false
	_current_state = BossAnimState.BOSS_RAGE_ATTACK
	_animation_frame = 0
	return true


## Called when boss takes damage — may trigger VULNERABLE state.
func request_vulnerable() -> void:
	if _is_transitioning:
		return
	if _current_state == BossAnimState.BOSS_DEFEAT:
		return
	if _current_state == BossAnimState.BOSS_ATTACK_A or _current_state == BossAnimState.BOSS_ATTACK_B or _current_state == BossAnimState.BOSS_RAGE_ATTACK:
		return  # Don't interrupt attacks
	_current_state = BossAnimState.BOSS_VULNERABLE
	_animation_frame = 0


## Called when boss HP reaches 0 — starts defeat sequence.
func request_defeat() -> void:
	_current_state = BossAnimState.BOSS_DEFEAT
	_animation_frame = 0
	_is_transitioning = true


## Called when boss phase changes (via BossAI signal).
## Triggers phase transition animation.
func request_phase_change(new_phase: int) -> void:
	if new_phase == _current_phase:
		return
	if _current_state == BossAnimState.BOSS_DEFEAT:
		return
	_current_state = BossAnimState.BOSS_PHASE_TRANSITION
	_animation_frame = 0
	_is_transitioning = true
	_current_phase = new_phase


## Returns true if phase transition animation is complete.
func is_phase_transition_complete() -> bool:
	return _current_state == BossAnimState.BOSS_PHASE_TRANSITION and _animation_frame >= PHASE_TRANSITION_FRAMES


## Call when phase transition animation completes — returns to idle.
func complete_phase_transition() -> void:
	if _current_state == BossAnimState.BOSS_PHASE_TRANSITION:
		_current_state = BossAnimState.BOSS_IDLE
		_animation_frame = 0
		_is_transitioning = false


## Returns true if defeat animation is complete.
func is_defeat_complete() -> bool:
	return _current_state == BossAnimState.BOSS_DEFEAT and _animation_frame >= DEFEAT_FRAMES


## Get idle animation frame count for current phase.
func get_idle_frame_count() -> int:
	return IDLE_FRAMES.get(_current_phase, 24)


## Returns true if current state is an attack state.
func is_in_attack() -> bool:
	return _current_state in [
		BossAnimState.BOSS_ATTACK_A,
		BossAnimState.BOSS_ATTACK_B,
		BossAnimState.BOSS_RAGE_ATTACK
	]
