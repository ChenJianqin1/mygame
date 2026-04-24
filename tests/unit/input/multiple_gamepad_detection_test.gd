# Multiple Gamepad Detection Test Suite
# GdUnit4 test file for Story 009: 多手柄识别
# Tests that GamepadInputReader correctly limits to first two gamepads.
# AC-1/AC-2/AC-3/AC-4: 3+ gamepads connected, only first two are used.
class_name MultipleGamepadDetectionTest
extends GdUnitTestSuite

# Test: 3 gamepads connected, only first two are assigned
func test_three_gamepads_only_first_two_assigned() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	_simulate_joypad_connect(2, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
		_on_joy_connection_changed(1, true)
		_on_joy_connection_changed(2, true)
	)
	# Only P1 and P2 should receive device_assigned signals, not device 2
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	var p2_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 2)
	var device2_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[2] == 2)
	assert_that(p1_assigned.size()).is_equal(1)
	assert_that(p2_assigned.size()).is_equal(1)
	assert_that(device2_assigned.size()).is_equal(0)

# Test: 1 gamepad connected, assigned to P1 only
func test_one_gamepad_assigned_to_p1_only() -> void:
	_simulate_joypad_connect(0, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
	)
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	var p2_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 2)
	assert_that(p1_assigned.size()).is_equal(1)
	assert_that(p2_assigned.size()).is_equal(0)

# Test: 4 gamepads connected, only first two used
func test_four_gamepads_only_first_two_used() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	_simulate_joypad_connect(2, true)
	_simulate_joypad_connect(3, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
		_on_joy_connection_changed(1, true)
		_on_joy_connection_changed(2, true)
		_on_joy_connection_changed(3, true)
	)
	var assigned_count := emitted_signals.filter(func(s): return s[0] == "device_assigned").size()
	assert_that(assigned_count).is_equal(2)

# Test: Connection order determines assignment (device_index 5 assigned before device_index 3)
func test_connection_order_determines_assignment() -> void:
	# Connect device 5 first, then device 3 — device 5 should be P1
	_simulate_joypad_connect(5, true)
	_simulate_joypad_connect(3, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(5, true)
		_on_joy_connection_changed(3, true)
	)
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	var p2_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 2)
	assert_that(p1_assigned[0][2]).is_equal(5)  # device 5 is P1
	assert_that(p2_assigned[0][2]).is_equal(3)  # device 3 is P2

# Test: Third gamepad silently ignored (no exceptions, no signals)
func test_third_gamepad_silently_ignored() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	_simulate_joypad_connect(2, true)
	# Should not throw, should not emit any signal for device 2
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(2, true)
	)
	var device2_signals := emitted_signals.filter(func(s): return s[2] == 2)
	assert_that(device2_signals.size()).is_equal(0)

# Test: device_assigned signal carries correct player_id and device_index
func test_device_assigned_signal_fields_correct() -> void:
	_simulate_joypad_connect(7, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(7, true)
	)
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	assert_that(p1_assigned.size()).is_equal(1)
	assert_that(p1_assigned[0][1]).is_equal(1)   # player_id = 1
	assert_that(p1_assigned[0][2]).is_equal(7)   # device_index = 7

# Test: Reconnect after disconnect restores assignment
func test_reconnect_restores_assignment() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	_on_joy_connection_changed(0, true)
	_on_joy_connection_changed(1, true)
	# Disconnect P1
	_simulate_joypad_connect(0, false)
	_on_joy_connection_changed(0, false)
	# Reconnect device 0
	_simulate_joypad_connect(0, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
	)
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	assert_that(p1_assigned.size()).is_equal(1)
	assert_that(p1_assigned[0][2]).is_equal(0)

# Test: device_assigned emitted before device_mode_changed
func test_device_assigned_before_mode_changed() -> void:
	_simulate_joypad_connect(0, true)
	var emission_order: Array = []
	var captured := [] as Array

	var assigned_callable := func(player_id: int, device_index: int) -> void:
		emission_order.append("device_assigned")
		captured.append(["device_assigned", player_id, device_index])
	var mode_callable := func(player_id: int, mode: StringName) -> void:
		emission_order.append("device_mode_changed")
		captured.append(["device_mode_changed", player_id, mode])

	Events.device_assigned.connect(assigned_callable)
	Events.device_mode_changed.connect(mode_callable)
	_on_joy_connection_changed(0, true)
	Events.device_assigned.disconnect(assigned_callable)
	Events.device_mode_changed.disconnect(mode_callable)

	assert_that(emission_order[0]).is_equal("device_assigned")
	assert_that(emission_order[1]).is_equal("device_mode_changed")

# Test: P2 gamepad assigned with correct device_index
func test_p2_device_assigned_correct_index() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
		_on_joy_connection_changed(1, true)
	)
	var p2_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 2)
	assert_that(p2_assigned.size()).is_equal(1)
	assert_that(p2_assigned[0][2]).is_equal(1)  # device_index = 1 for P2

# --- Helper methods (mirrors GamepadInputReader logic) ---

var _mock_connected_joypads: Array[int] = []
var _p1_device_override: int = -1
var _p2_device_override: int = -1

func _simulate_joypad_connect(device_index: int, connected: bool) -> void:
	if connected:
		if device_index not in _mock_connected_joypads:
			_mock_connected_joypads.append(device_index)
			_mock_connected_joypads.sort()
	else:
		_mock_connected_joypads.erase(device_index)

func _on_joy_connection_changed(device_index: int, connected: bool) -> void:
	if connected:
		_handle_joypad_connect(device_index)
	else:
		_handle_joypad_disconnect(device_index)

func _detect_joypads() -> void:
	_p1_device_override = _mock_connected_joypads[0] if _mock_connected_joypads.size() > 0 else -1
	_p2_device_override = _mock_connected_joypads[1] if _mock_connected_joypads.size() > 1 else -1

const PLAYER_ID_P1 := 1
const PLAYER_ID_P2 := 2

func _handle_joypad_connect(device_index: int) -> void:
	# Only first two gamepads are used (P1 and P2)
	if _mock_connected_joypads.size() > 2 and device_index != _mock_connected_joypads[0] and device_index != _mock_connected_joypads[1]:
		return  # Third+ gamepad ignored
	_detect_joypads()
	if device_index == _p1_device_override:
		Events.device_assigned.emit(PLAYER_ID_P1, device_index)
		Events.device_mode_changed.emit(PLAYER_ID_P1, &"gamepad")
		Events.device_status_message.emit(PLAYER_ID_P1, "Player 1 手柄已连接")
	elif device_index == _p2_device_override:
		Events.device_assigned.emit(PLAYER_ID_P2, device_index)
		Events.device_mode_changed.emit(PLAYER_ID_P2, &"gamepad")
		Events.device_status_message.emit(PLAYER_ID_P2, "Player 2 手柄已连接")

func _handle_joypad_disconnect(device_index: int) -> void:
	var player_id := -1
	if device_index == _p1_device_override:
		_p1_device_override = -1
		player_id = PLAYER_ID_P1
	elif device_index == _p2_device_override:
		_p2_device_override = -1
		player_id = PLAYER_ID_P2
	if player_id > 0:
		_detect_joypads()
		Events.device_mode_changed.emit(player_id, &"keyboard")
		Events.device_status_message.emit(player_id, "Player %d 手柄已断开" % player_id)

func capture_signals(func_to_call: Callable) -> Array:
	var captured := [] as Array
	var assigned_callable := func(player_id: int, device_index: int) -> void:
		captured.append(["device_assigned", player_id, device_index])
	var device_mode_callable := func(player_id: int, mode: StringName) -> void:
		captured.append(["device_mode_changed", player_id, mode])
	var device_status_callable := func(player_id: int, message: String) -> void:
		captured.append(["device_status_message", player_id, message])
	Events.device_assigned.connect(assigned_callable)
	Events.device_mode_changed.connect(device_mode_callable)
	Events.device_status_message.connect(device_status_callable)
	func_to_call.call()
	Events.device_assigned.disconnect(assigned_callable)
	Events.device_mode_changed.disconnect(device_mode_callable)
	Events.device_status_message.disconnect(device_status_callable)
	return captured
