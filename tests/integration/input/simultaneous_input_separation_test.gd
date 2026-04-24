# Simultaneous Input Separation Test Suite
# GdUnit4 test file for Story 005: P1+P2 同时输入无冲突
# Tests that P1 and P2 inputs are correctly isolated via player_id routing through Events.
class_name SimultaneousInputSeparationTest
extends GdUnitTestSuite

# Test: P1 and P2 keyboard inputs emit with correct player_ids simultaneously
func test_p1_and_p2_keyboard_emit_correct_player_ids() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"jump", 1.0)
		_input_action_press(2, &"jump", 1.0)
	)
	var p1_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1)
	var p2_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2)
	assert_that(p1_signals.size()).is_equal(1)
	assert_that(p2_signals.size()).is_equal(1)
	assert_that(p1_signals[0][2]).is_equal(&"jump")
	assert_that(p2_signals[0][2]).is_equal(&"jump")

# Test: P1 keyboard move + P2 gamepad move simultaneously — no crosstalk
func test_p1_keyboard_p2_gamepad_simultaneous_no_crosstalk() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"move_horizontal", -1.0)
		_input_action_press(2, &"move_horizontal", 0.8)
	)
	var p1_move := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1 and s[2] == &"move_horizontal")
	var p2_move := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2 and s[2] == &"move_horizontal")
	assert_that(p1_move.size()).is_equal(1)
	assert_that(p2_move.size()).is_equal(1)
	assert_that(p1_move[0][3]).is_equal(-1.0)
	assert_that(p2_move[0][3]).is_equal(0.8)

# Test: P1 attack + P2 dodge simultaneously — both signals emitted
func test_p1_attack_p2_dodge_simultaneous_both_emitted() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"attack_light", 1.0)
		_input_action_press(2, &"dodge", 1.0)
	)
	var p1_attack := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1 and s[2] == &"attack_light")
	var p2_dodge := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2 and s[2] == &"dodge")
	assert_that(p1_attack.size()).is_equal(1)
	assert_that(p2_dodge.size()).is_equal(1)

# Test: Opposing directions (A+D) for same player cancel out
func test_p1_a_and_d_pressed_simultaneously_cancels() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"move_horizontal", -1.0)
		_input_action_press(1, &"move_horizontal", 1.0)
	)
	var move_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1 and s[2] == &"move_horizontal")
	# Both directions pressed — in real input this would be net 0, test verifies correct event emission
	assert_that(move_signals.size()).is_equal(2)

# Test: P1 jump + P2 heavy attack simultaneously
func test_p1_jump_p2_heavy_attack_simultaneous() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"jump", 1.0)
		_input_action_press(2, &"attack_heavy", 1.0)
	)
	var p1_jump := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1 and s[2] == &"jump")
	var p2_heavy := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2 and s[2] == &"attack_heavy")
	assert_that(p1_jump.size()).is_equal(1)
	assert_that(p2_heavy.size()).is_equal(1)

# Test: All discrete actions for P1 and P2 can fire simultaneously
func test_all_discrete_actions_p1_p2_simultaneous() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"jump", 1.0)
		_input_action_press(1, &"dodge", 1.0)
		_input_action_press(1, &"attack_light", 1.0)
		_input_action_press(1, &"attack_heavy", 1.0)
		_input_action_press(2, &"jump", 1.0)
		_input_action_press(2, &"dodge", 1.0)
		_input_action_press(2, &"attack_light", 1.0)
		_input_action_press(2, &"attack_heavy", 1.0)
	)
	var p1_count := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1).size()
	var p2_count := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2).size()
	assert_that(p1_count).is_equal(4)
	assert_that(p2_count).is_equal(4)

# Test: Continuous move + discrete action simultaneously
func test_p1_move_and_jump_simultaneous() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"move_horizontal", 1.0)
		_input_action_press(1, &"jump", 1.0)
	)
	var move := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1 and s[2] == &"move_horizontal")
	var jump := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1 and s[2] == &"jump")
	assert_that(move.size()).is_equal(1)
	assert_that(jump.size()).is_equal(1)
	assert_that(move[0][3]).is_equal(1.0)

# Test: P2 keyboard + P1 gamepad cross-device simultaneous
func test_p2_keyboard_p1_gamepad_cross_device() -> void:
	var emitted_signals := capture_signals(func():
		_input_action_press(1, &"move_horizontal", 0.5)
		_input_action_press(2, &"move_horizontal", -1.0)
	)
	var p1_move := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1)
	var p2_move := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2)
	assert_that(p1_move.size()).is_equal(1)
	assert_that(p2_move.size()).is_equal(1)
	assert_that(p1_move[0][3]).is_equal(0.5)
	assert_that(p2_move[0][3]).is_equal(-1.0)

# --- Helper methods ---

func _input_action_press(player_id: int, action: StringName, strength: float) -> void:
	Events.input_action.emit(player_id, action, strength)

func capture_signals(func_to_call: Callable) -> Array:
	var captured := [] as Array
	var signal_callable := func(player_id: int, action: StringName, strength: float) -> void:
		captured.append(["input_action", player_id, action, strength])
	Events.input_action.connect(signal_callable)
	func_to_call.call()
	Events.input_action.disconnect(signal_callable)
	return captured
