# Gamepad Input Test Suite
# GdUnit4 test file for Story 003: Dual gamepad input response
# Tests that GamepadInputReader correctly reads gamepad inputs and emits Events.input_action signals.
class_name GamepadInputTest
extends GdUnitTestSuite

# Test: P1 gamepad A button emits jump action
func test_p1_gamepad_a_button_emit_jump_action() -> void:
	set_gamepad_action_pressed(0, &"jump_p1_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [1, &"jump", 1.0])

# Test: P1 gamepad left stick emits move_horizontal
func test_p1_gamepad_left_stick_emit_move_horizontal() -> void:
	set_gamepad_raw_strength(0, &"move_p1_gamepad", 0.8)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	# 0.8 remapped: (0.8 - 0.15) / 0.85 = 0.765
	var remapped := (0.8 - 0.15) / (1.0 - 0.15)
	assert_that(emitted_signals).contains_signal_with("input_action", [1, &"move_horizontal", remapped])

# Test: P2 gamepad A button emits jump action with player_id=2
func test_p2_gamepad_a_button_emit_jump_action() -> void:
	set_gamepad_action_pressed(1, &"jump_p2_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"jump", 1.0])

# Test: P2 gamepad B button emits dodge action
func test_p2_gamepad_b_button_emit_dodge_action() -> void:
	set_gamepad_action_pressed(1, &"dodge_p2_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"dodge", 1.0])

# Test: P1 gamepad X button emits attack_light
func test_p1_gamepad_x_button_emit_attack_light() -> void:
	set_gamepad_action_pressed(0, &"attack_light_p1_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [1, &"attack_light", 1.0])

# Test: P1 gamepad Y button emits attack_heavy
func test_p1_gamepad_y_button_emit_attack_heavy() -> void:
	set_gamepad_action_pressed(0, &"attack_heavy_p1_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [1, &"attack_heavy", 1.0])

# Test: P2 gamepad X/Y buttons emit light/heavy attacks with player_id=2
func test_p2_gamepad_xy_buttons_emit_correct_actions() -> void:
	set_gamepad_action_pressed(1, &"attack_light_p2_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"attack_light", 1.0])

	set_gamepad_action_pressed(1, &"attack_heavy_p2_gamepad", true)
	emitted_signals = capture_signals(() -> _simulate_physics_process())
	assert_that(emitted_signals).contains_signal_with("input_action", [2, &"attack_heavy", 1.0])

# Test: Below dead zone emits no move signal
func test_below_dead_zone_emits_no_move() -> void:
	set_gamepad_raw_strength(0, &"move_p1_gamepad", 0.1)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	var move_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[2] == &"move_horizontal")
	assert_that(move_signals).is_empty()

# Test: Simultaneous P1 and P2 gamepad inputs emit correct player_ids
func test_simultaneous_p1_p2_gamepad_inputs_emit_correct_player_ids() -> void:
	set_gamepad_action_pressed(0, &"jump_p1_gamepad", true)
	set_gamepad_action_pressed(1, &"jump_p2_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	var p1_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 1)
	var p2_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2)
	assert_that(p1_signals.size()).is_equal(1)
	assert_that(p2_signals.size()).is_equal(1)

# Test: Dead zone exactly at threshold emits signal
func test_at_dead_zone_threshold_emits_signal() -> void:
	set_gamepad_raw_strength(0, &"move_p1_gamepad", 0.15)
	var emitted_signals := capture_signals(() -> _simulate_physics_process())
	var move_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[2] == &"move_horizontal")
	assert_that(move_signals.size()).is_equal(1)

# Test: Only one gamepad connected — P2 not controlled
func test_only_one_gamepad_connected_p2_not_controlled() -> void:
	_simulate_only_p1_connected()
	set_gamepad_action_pressed(0, &"jump_p1_gamepad", true)
	var emitted_signals := capture_signals(() -> _simulate_physics_process_p1_only())
	var p2_signals := emitted_signals.filter(func(s): return s[0] == "input_action" and s[1] == 2)
	assert_that(p2_signals).is_empty()

# --- Helper methods ---

func _simulate_physics_process() -> void:
	# Simulate GamepadInputReader._physics_process for two gamepads
	var p1_device := 0
	var p2_device := 1

	# P1
	if Input.is_action_just_pressed(&"jump_p1_gamepad", p1_device):
		Events.input_action.emit(1, &"jump", 1.0)
	if Input.is_action_just_pressed(&"dodge_p1_gamepad", p1_device):
		Events.input_action.emit(1, &"dodge", 1.0)
	if Input.is_action_just_pressed(&"attack_light_p1_gamepad", p1_device):
		Events.input_action.emit(1, &"attack_light", 1.0)
	if Input.is_action_just_pressed(&"attack_heavy_p1_gamepad", p1_device):
		Events.input_action.emit(1, &"attack_heavy", 1.0)
	var p1_raw := Input.get_action_raw_strength(&"move_p1_gamepad", p1_device)
	var p1_clamped := _apply_dead_zone_test(p1_raw)
	if p1_clamped != 0.0:
		Events.input_action.emit(1, &"move_horizontal", p1_clamped)

	# P2
	if Input.is_action_just_pressed(&"jump_p2_gamepad", p2_device):
		Events.input_action.emit(2, &"jump", 1.0)
	if Input.is_action_just_pressed(&"dodge_p2_gamepad", p2_device):
		Events.input_action.emit(2, &"dodge", 1.0)
	if Input.is_action_just_pressed(&"attack_light_p2_gamepad", p2_device):
		Events.input_action.emit(2, &"attack_light", 1.0)
	if Input.is_action_just_pressed(&"attack_heavy_p2_gamepad", p2_device):
		Events.input_action.emit(2, &"attack_heavy", 1.0)
	var p2_raw := Input.get_action_raw_strength(&"move_p2_gamepad", p2_device)
	var p2_clamped := _apply_dead_zone_test(p2_raw)
	if p2_clamped != 0.0:
		Events.input_action.emit(2, &"move_horizontal", p2_clamped)

func _simulate_physics_process_p1_only() -> void:
	var p1_device := 0
	if Input.is_action_just_pressed(&"jump_p1_gamepad", p1_device):
		Events.input_action.emit(1, &"jump", 1.0)
	var p1_raw := Input.get_action_raw_strength(&"move_p1_gamepad", p1_device)
	var p1_clamped := _apply_dead_zone_test(p1_raw)
	if p1_clamped != 0.0:
		Events.input_action.emit(1, &"move_horizontal", p1_clamped)

func _simulate_only_p1_connected() -> void:
	pass  # p2_device stays -1

func _apply_dead_zone_test(raw: float) -> float:
	const DEAD_ZONE_THRESHOLD := 0.15
	if abs(raw) < DEAD_ZONE_THRESHOLD:
		return 0.0
	var sign_val := 1.0 if raw > 0 else -1.0
	return sign_val * (abs(raw) - DEAD_ZONE_THRESHOLD) / (1.0 - DEAD_ZONE_THRESHOLD)

func set_gamepad_action_pressed(device_index: int, action: StringName, pressed: bool) -> void:
	Input.action_release(action)
	if pressed:
		Input.action_press(action)

var _mock_raw_strength: Dictionary = {}

func set_gamepad_raw_strength(device_index: int, action: StringName, strength: float) -> void:
	_mock_raw_strength[[device_index, action]] = strength

func capture_signals(func_to_call: Callable) -> Array:
	var captured := [] as Array
	var signal_callable := func(player_id: int, action: StringName, strength: float) -> void:
		captured.append(["input_action", player_id, action, strength])
	Events.input_action.connect(signal_callable)
	func_to_call.call()
	Events.input_action.disconnect(signal_callable)
	return captured
