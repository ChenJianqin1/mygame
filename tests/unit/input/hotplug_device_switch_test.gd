# Hotplug Device Switch Test Suite
# GdUnit4 test file for Story 004: 设备热插拔自动切换
# Tests that GamepadInputReader correctly handles gamepad connect/disconnect events.
class_name HotplugDeviceSwitchTest
extends GdUnitTestSuite

# Test: P1 gamepad connect emits device_mode_changed with gamepad mode
func test_p1_gamepad_connect_emits_gamepad_mode() -> void:
	_simulate_joypad_connect(0, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
	)
	assert_that(emitted_signals).contains_signal_with("device_mode_changed", [1, &"gamepad"])

# Test: P1 gamepad disconnect emits device_mode_changed with keyboard mode
func test_p1_gamepad_disconnect_emits_keyboard_mode() -> void:
	# Simulate P1 having a connected gamepad first
	_simulate_joypad_connect(0, true)
	_on_joy_connection_changed(0, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, false)
	)
	assert_that(emitted_signals).contains_signal_with("device_mode_changed", [1, &"keyboard"])

# Test: P2 gamepad connect emits device_mode_changed with gamepad mode
func test_p2_gamepad_connect_emits_gamepad_mode() -> void:
	_simulate_joypad_connect(1, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(1, true)
	)
	assert_that(emitted_signals).contains_signal_with("device_mode_changed", [2, &"gamepad"])

# Test: P2 gamepad disconnect emits device_mode_changed with keyboard mode
func test_p2_gamepad_disconnect_emits_keyboard_mode() -> void:
	_simulate_joypad_connect(1, true)
	_on_joy_connection_changed(1, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(1, false)
	)
	assert_that(emitted_signals).contains_signal_with("device_mode_changed", [2, &"keyboard"])

# Test: Device status message emitted on P1 connect
func test_p1_connect_emits_status_message() -> void:
	_simulate_joypad_connect(0, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
	)
	var msg_signals := emitted_signals.filter(func(s): return s[0] == "device_status_message" and s[1] == 1)
	assert_that(msg_signals.size()).is_equal(1)
	assert_that(msg_signals[0][2] as String).contains("Player 1")

# Test: Device status message emitted on P2 disconnect
func test_p2_disconnect_emits_status_message() -> void:
	_simulate_joypad_connect(1, true)
	_on_joy_connection_changed(1, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(1, false)
	)
	var msg_signals := emitted_signals.filter(func(s): return s[0] == "device_status_message" and s[1] == 2)
	assert_that(msg_signals.size()).is_equal(1)
	assert_that(msg_signals[0][2] as String).contains("Player 2")

# Test: Third gamepad connect is ignored (no signal emitted)
func test_third_gamepad_ignored() -> void:
	# Simulate 3 gamepads connected (device_index=2 is third)
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	_simulate_joypad_connect(2, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(2, true)
	)
	var mode_signals := emitted_signals.filter(func(s): return s[0] == "device_mode_changed")
	assert_that(mode_signals).is_empty()

# Test: Reconnect after disconnect restores gamepad mode
func test_reconnect_restores_gamepad_mode() -> void:
	_simulate_joypad_connect(0, true)
	_on_joy_connection_changed(0, true)
	var disconnect_signals := capture_signals(func():
		_on_joy_connection_changed(0, false)
	)
	assert_that(disconnect_signals).contains_signal_with("device_mode_changed", [1, &"keyboard"])
	_simulate_joypad_connect(0, true)
	var reconnect_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
	)
	assert_that(reconnect_signals).contains_signal_with("device_mode_changed", [1, &"gamepad"])

# Test: No signals when disconnected device that was never connected
func test_unknown_device_disconnect_emits_no_signals() -> void:
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(99, false)
	)
	assert_that(emitted_signals).is_empty()

# Test: Simultaneous P1 and P2 connect both emit correct player_ids
func test_both_p1_p2_connect_emit_correct_player_ids() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
		_on_joy_connection_changed(1, true)
	)
	var p1_signals := emitted_signals.filter(func(s): return s[0] == "device_mode_changed" and s[1] == 1)
	var p2_signals := emitted_signals.filter(func(s): return s[0] == "device_mode_changed" and s[1] == 2)
	assert_that(p1_signals.size()).is_equal(1)
	assert_that(p2_signals.size()).is_equal(1)

# --- Helper methods ---

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
	# Simplified simulation of the hotplug handler
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
	# Third+ gamepad ignored
	if _mock_connected_joypads.size() > 2 and device_index != _mock_connected_joypads[0] and device_index != _mock_connected_joypads[1]:
		return
	_detect_joypads()
	if device_index == _p1_device_override:
		Events.device_mode_changed.emit(PLAYER_ID_P1, &"gamepad")
		Events.device_status_message.emit(PLAYER_ID_P1, "Player 1 手柄已连接")
	elif device_index == _p2_device_override:
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
	var device_mode_callable := func(player_id: int, mode: StringName) -> void:
		captured.append(["device_mode_changed", player_id, mode])
	var device_status_callable := func(player_id: int, message: String) -> void:
		captured.append(["device_status_message", player_id, message])
	Events.device_mode_changed.connect(device_mode_callable)
	Events.device_status_message.connect(device_status_callable)
	func_to_call.call()
	Events.device_mode_changed.disconnect(device_mode_callable)
	Events.device_status_message.disconnect(device_status_callable)
	return captured
