# ui_state_machine_test.gd — Unit tests for ui-001 UI state machine
# GdUnit4 test file
# Tests: state transitions, enter/exit callbacks, pause debounce

class_name UIStateMachineTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _ui: UIStateMachine

func before() -> void:
	_ui = UIStateMachine.new()

func after() -> void:
	if is_instance_valid(_ui):
		_ui.free()


# ─── Initial state ────────────────────────────────────────────────────────────

func test_initial_state_is_title() -> void:
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.TITLE)


# ─── AC1: All 5 states exist ─────────────────────────────────────────────────

func test_all_five_states_exist() -> void:
	assert_that(UIStateMachine.State.keys().size()).is_equal(5)
	assert_that(UIStateMachine.State.TITLE).is_equal(0)
	assert_that(UIStateMachine.State.BOSS_INTRO).is_equal(1)
	assert_that(UIStateMachine.State.GAMEPLAY_HUD).is_equal(2)
	assert_that(UIStateMachine.State.PAUSED).is_equal(3)
	assert_that(UIStateMachine.State.GAME_OVER).is_equal(4)


# ─── State transitions ────────────────────────────────────────────────────────

func test_start_game_transitions_to_boss_intro() -> void:
	# Given: TITLE state
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.TITLE)

	# When: start_game is called
	_ui.start_game()

	# Then: Transition to BOSS_INTRO
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.BOSS_INTRO)


func test_complete_boss_intro_transitions_to_hud() -> void:
	_ui.start_game()  # TITLE → BOSS_INTRO
	_ui.complete_boss_intro()

	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.GAMEPLAY_HUD)


func test_end_game_transitions_to_game_over() -> void:
	_ui.start_game()
	_ui.complete_boss_intro()
	_ui.end_game()

	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.GAME_OVER)


func test_return_to_title_from_any_state() -> void:
	# From GAME_OVER
	_ui.return_to_title()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.TITLE)

	# From GAMEPLAY_HUD
	_ui.start_game()
	_ui.complete_boss_intro()
	_ui.return_to_title()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.TITLE)


# ─── AC3: State transitions fire immediately (within 1 frame) ─────────────────

func test_transition_is_immediate_no_queued_delay() -> void:
	# Given: TITLE state
	# When: start_game called
	_ui.start_game()

	# Then: Immediately in BOSS_INTRO (no async/queued delay)
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.BOSS_INTRO)


# ─── Pause debounce (AC7) ──────────────────────────────────────────────────────

func test_pause_transitions_to_paused() -> void:
	# Given: GAMEPLAY_HUD state
	_ui.start_game()
	_ui.complete_boss_intro()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.GAMEPLAY_HUD)

	# When: attempt_pause called
	var toggled := _ui.attempt_pause()

	# Then: Paused
	assert_that(toggled).is_true()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.PAUSED)


func test_pause_resume_cycle() -> void:
	_ui.start_game()
	_ui.complete_boss_intro()
	_ui.attempt_pause()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.PAUSED)

	_ui.attempt_pause()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.GAMEPLAY_HUD)


func test_pause_debounce_blocks_rapid_toggle() -> void:
	_ui.start_game()
	_ui.complete_boss_intro()

	# First pause attempt succeeds
	var first := _ui.attempt_pause()
	assert_that(first).is_true()

	# Immediate second attempt is debounced (within 200ms)
	_ui.update(0.1)  # Only 100ms passed
	var second := _ui.attempt_pause()

	# Should be blocked
	assert_that(second).is_false()


func test_pause_debounce_allows_after_window() -> void:
	_ui.start_game()
	_ui.complete_boss_intro()
	_ui.attempt_pause()

	# Wait for debounce to expire (200ms)
	_ui.update(0.25)  # 250ms

	var second := _ui.attempt_pause()
	assert_that(second).is_true()


# ─── Transition guards ─────────────────────────────────────────────────────────

func test_cannot_pause_from_title() -> void:
	var result := _ui.attempt_pause()
	assert_that(result).is_false()
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.TITLE)


func test_cannot_resume_from_title() -> void:
	_ui.attempt_pause()
	# Already not paused
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.TITLE)


func test_same_state_transition_is_noop() -> void:
	_ui.start_game()  # Now BOSS_INTRO
	_ui.start_game()   # Try to transition to BOSS_INTRO again
	assert_that(_ui.get_state()).is_equal(UIStateMachine.State.BOSS_INTRO)


# ─── Layer priorities ───────────────────────────────────────────────────────────

func test_layer_priorities_exist() -> void:
	assert_that(UIStateMachine.LAYER_PRIORITIES[UIStateMachine.State.TITLE]).is_equal(40)
	assert_that(UIStateMachine.LAYER_PRIORITIES[UIStateMachine.State.GAMEPLAY_HUD]).is_equal(0)
	assert_that(UIStateMachine.LAYER_PRIORITIES[UIStateMachine.State.PAUSED]).is_equal(20)
	assert_that(UIStateMachine.LAYER_PRIORITIES[UIStateMachine.State.GAME_OVER]).is_equal(30)
	assert_that(UIStateMachine.LAYER_PRIORITIES[UIStateMachine.State.BOSS_INTRO]).is_equal(10)
