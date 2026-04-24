# ui_state_machine.gd — UI state machine for screen management
# Implements ui-001 AC1-AC7: 5-state machine with enter/exit callbacks
# States: TITLE, BOSS_INTRO, GAMEPLAY_HUD, PAUSED, GAME_OVER
class_name UIStateMachine
extends Node

## UI screen state identifiers
enum State {
	TITLE,
	BOSS_INTRO,
	GAMEPLAY_HUD,
	PAUSED,
	GAME_OVER
}

## Layer priorities for CanvasLayer z-index
const LAYER_PRIORITIES := {
	State.TITLE: 40,
	State.BOSS_INTRO: 10,
	State.GAMEPLAY_HUD: 0,
	State.PAUSED: 20,
	State.GAME_OVER: 30
}

## Pause input debounce window
const PAUSE_DEBOUNCE_MS: int = 200

var _current_state: State = State.TITLE
var _previous_state: State = State.TITLE
var _pause_debounce_timer: float = 0.0

## Emitted when UI state changes
signal ui_state_changed(state: State, previous_state: State)

# ─── Public API ────────────────────────────────────────────────────────────────

## Get the current UI state.
func get_state() -> State:
	return _current_state


## Transition to a new state. Calls exit_* and enter_* for the transition.
func transition_to(new_state: State) -> void:
	if new_state == _current_state:
		return

	var old_state := _current_state
	var exit_method := "exit_" + _state_name(old_state)
	var enter_method := "enter_" + _state_name(new_state)

	# Call exit handler for old state
	if has_method(exit_method):
		call(exit_method)

	_previous_state = old_state
	_current_state = new_state

	# Call enter handler for new state
	if has_method(enter_method):
		call(enter_method)

	ui_state_changed.emit(_current_state, _previous_state)


## Called each frame to update debounce timers.
func update(delta: float) -> void:
	if _pause_debounce_timer > 0:
		_pause_debounce_timer -= delta * 1000.0


## Attempt to toggle pause. Debounced to prevent rapid toggling.
func attempt_pause() -> bool:
	if _pause_debounce_timer > 0:
		return false

	if _current_state == State.PAUSED:
		_resume()
		_pause_debounce_timer = PAUSE_DEBOUNCE_MS
		return true
	elif _current_state == State.GAMEPLAY_HUD:
		_pause()
		_pause_debounce_timer = PAUSE_DEBOUNCE_MS
		return true
	return false


# ─── Transition Helpers ─────────────────────────────────────────────────────────

func _pause() -> void:
	transition_to(State.PAUSED)


func _resume() -> void:
	transition_to(State.GAMEPLAY_HUD)


func start_game() -> void:
	## TITLE → BOSS_INTRO
	if _current_state == State.TITLE:
		transition_to(State.BOSS_INTRO)


func complete_boss_intro() -> void:
	## BOSS_INTRO → GAMEPLAY_HUD
	if _current_state == State.BOSS_INTRO:
		transition_to(State.GAMEPLAY_HUD)


func end_game() -> void:
	## GAMEPLAY_HUD → GAME_OVER
	if _current_state == State.GAMEPLAY_HUD or _current_state == State.PAUSED:
		transition_to(State.GAME_OVER)


func return_to_title() -> void:
	transition_to(State.TITLE)


# ─── State Enter/Exit Handlers ─────────────────────────────────────────────────
## Override these in subclasses or connect via method calls

func enter_TITLE() -> void:
	pass

func exit_TITLE() -> void:
	pass

func enter_BOSS_INTRO() -> void:
	pass

func exit_BOSS_INTRO() -> void:
	pass

func enter_GAMEPLAY_HUD() -> void:
	pass

func exit_GAMEPLAY_HUD() -> void:
	pass

func enter_PAUSED() -> void:
	pass

func exit_PAUSED() -> void:
	pass

func enter_GAME_OVER() -> void:
	pass

func exit_GAME_OVER() -> void:
	pass


# ─── Internal ──────────────────────────────────────────────────────────────────

func _state_name(state: State) -> String:
	return State.keys()[state]
