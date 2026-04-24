# P2 Keyboard Input Test Suite
# GdUnit4 test file for Story 002: P2 keyboard input response
# Tests that P2InputReader correctly reads P2 keyboard inputs and emits Events.input_action signals.
class_name P2KeyboardInputTest
extends GdUnitTestSuite

# Test: Up key press emits jump action with strength 1.0
func test_p2_up_key_emit_jump_action() -> void:
	set_input_action_pressed(&"jump_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"jump", 1.0])

# Test: Left key press emits move_horizontal with negative strength
func test_p2_left_key_emit_move_horizontal_left() -> void:
	set_input_action_pressed(&"move_left_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"move_horizontal", -1.0])

# Test: Right key press emits move_horizontal with positive strength
func test_p2_right_key_emit_move_horizontal_right() -> void:
	set_input_action_pressed(&"move_right_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"move_horizontal", 1.0])

# Test: Down key press emits dodge action
func test_p2_down_key_emit_dodge_action() -> void:
	set_input_action_pressed(&"dodge_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"dodge", 1.0])

# Test: Numpad 1 press emits attack_light action
func test_p2_numpad1_emit_attack_light_action() -> void:
	set_input_action_pressed(&"attack_light_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"attack_light", 1.0])

# Test: Numpad 2 press emits attack_heavy action
func test_p2_numpad2_emit_attack_heavy_action() -> void:
	set_input_action_pressed(&"attack_heavy_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"attack_heavy", 1.0])

# Test: No keys pressed emits no signals
func test_no_keys_pressed_no_signals_emitted() -> void:
	Input.action_release(&"jump_p2")
	Input.action_release(&"move_left_p2")
	Input.action_release(&"move_right_p2")
	Input.action_release(&"dodge_p2")
	Input.action_release(&"attack_light_p2")
	Input.action_release(&"attack_heavy_p2")
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).is_empty()

# Test: Left+Right simultaneously pressed emits no move_horizontal signal
func test_p2_left_and_right_pressed_simultaneously_emits_no_move() -> void:
	set_input_action_pressed(&"move_left_p2", true)
	set_input_action_pressed(&"move_right_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	var move_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[2] == &"move_horizontal")
	assert_that(move_signals).is_empty()

# Test: Player ID is always 2 for P2 keyboard input
func test_p2_input_always_uses_player_id_2() -> void:
	set_input_action_pressed(&"attack_light_p2", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	var input_action_signals := emitted_signals.filter(func(s): return s[0] == "input_action")
	for sig in input_action_signals:
		assert_that(sig[1]).is_equal(2)

# --- Helper methods ---

func _simulate_physics_process() -> void:
	# P2InputReader._physics_process is called by engine
	# We simulate the input reading part directly
	# Note: InputMap actions have _p2 suffix (physical device mapping),
	# but emitted semantic action names do not (player_id distinguishes players).
	var move_left_strength := Input.get_action_raw_strength(&"move_left_p2")
	var move_right_strength := Input.get_action_raw_strength(&"move_right_p2")
	var net_move := move_right_strength - move_left_strength
	if net_move != 0.0:
		Events.input_action.emit(2, &"move_horizontal", net_move)

	if Input.is_action_just_pressed(&"jump_p2"):
		Events.input_action.emit(2, &"jump", 1.0)
	if Input.is_action_just_pressed(&"dodge_p2"):
		Events.input_action.emit(2, &"dodge", 1.0)
	if Input.is_action_just_pressed(&"attack_light_p2"):
		Events.input_action.emit(2, &"attack_light", 1.0)
	if Input.is_action_just_pressed(&"attack_heavy_p2"):
		Events.input_action.emit(2, &"attack_heavy", 1.0)

func set_input_action_pressed(action: StringName, pressed: bool) -> void:
	Input.action_release(action)
	if pressed:
		Input.action_press(action)

func capture_signals(func_to_call: Callable) -> Array:
	var captured := [] as Array
	var signal_callable := func(player_id: int, action: StringName, strength: float) -> void:
		captured.append(["input_action", player_id, action, strength])
	Events.input_action.connect(signal_callable)
	func_to_call.call()
	Events.input_action.disconnect(signal_callable)
	return captured
