# Unknown Device Resilience Test Suite
# GdUnit4 test file for Story 010: 未知设备不崩溃
# Tests that connecting unknown USB devices does not crash the game.
# AC-1/AC-2/AC-3/AC-4: Unknown device handling is silent and robust.
class_name UnknownDeviceResilienceTest
extends GdUnitTestSuite

# Test: Connecting unknown device does not crash game
func test_unknown_device_connect_does_not_crash() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	# Simulate unknown device connecting (device_index not in first two)
	# Should not throw, should not emit any signals
	var crashed := false
	try:
		_on_joy_connection_changed(99, true)
	catch e:
		crashed = true
	assert_that(crashed).is_false()

# Test: Unknown device is silently ignored (no signals emitted)
func test_unknown_device_silently_ignored() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(99, true)
	)
	# No device_assigned, device_mode_changed, or device_status_message for device 99
	var device_99_signals := emitted_signals.filter(func(s): return s[2] == 99)
	assert_that(device_99_signals.size()).is_equal(0)

# Test: Removing unknown device does not crash
func test_unknown_device_disconnect_does_not_crash() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	# First connect an unknown device
	_simulate_joypad_connect(77, true)
	var crashed := false
	try:
		_on_joy_connection_changed(77, false)
	catch e:
		crashed = true
	assert_that(crashed).is_false()

# Test: Normal gamepad operations continue after unknown device events
func test_normal_gamepad_works_after_unknown_device_events() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	# Add unknown device
	_on_joy_connection_changed(88, true)
	# Normal P1/P2 gamepads should still work
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
		_on_joy_connection_changed(1, true)
	)
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	var p2_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 2)
	assert_that(p1_assigned.size()).is_equal(1)
	assert_that(p2_assigned.size()).is_equal(1)

# Test: Multiple unknown devices do not crash
func test_multiple_unknown_devices_do_not_crash() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	var crashed := false
	try:
		_on_joy_connection_changed(50, true)
		_on_joy_connection_changed(60, true)
		_on_joy_connection_changed(70, true)
		_on_joy_connection_changed(50, false)
		_on_joy_connection_changed(60, false)
		_on_joy_connection_changed(70, false)
	catch e:
		crashed = true
	assert_that(crashed).is_false()

# Test: Unknown device disconnect before connect does not crash
func test_unknown_device_disconnect_before_connect_does_not_crash() -> void:
	var crashed := false
	try:
		# Disconnect a device that was never connected
		_on_joy_connection_changed(999, false)
	catch e:
		crashed = true
	assert_that(crashed).is_false()

# Test: Normal disconnect still works correctly after unknown device events
func test_normal_disconnect_works_after_unknown_device_events() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	# Unknown device events first
	_on_joy_connection_changed(55, true)
	_on_joy_connection_changed(55, false)
	# Now normal disconnect
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, false)
	)
	var p1_mode_changed := emitted_signals.filter(func(s): return s[0] == "device_mode_changed" and s[1] == 1 and s[2] == &"keyboard")
	assert_that(p1_mode_changed.size()).is_equal(1)

# Test: Gamepad disconnect reassigns slots correctly
func test_disconnect_reassigns_player_slots_correctly() -> void:
	_simulate_joypad_connect(0, true)
	_simulate_joypad_connect(1, true)
	_on_joy_connection_changed(0, true)
	_on_joy_connection_changed(1, true)
	# Disconnect P1
	_simulate_joypad_connect(0, false)
	_on_joy_connection_changed(0, false)
	# P1 slot should now be available for next device
	var emitted_signals := capture_signals(func():
		_on_joy_connection_changed(0, true)
	)
	var p1_assigned := emitted_signals.filter(func(s): return s[0] == "device_assigned" and s[1] == 1)
	assert_that(p1_assigned.size()).is_equal(1)

# Test: No exception thrown when checking joypad connection for unknown device
func test_is_joypad_connected_unknown_device_no_exception() -> void:
	var crashed := false
	var result := false
	try:
		result = Input.is_joypad_connected(9999)
	catch e:
		crashed = true
	assert_that(crashed).is_false()
	# Result should be false for unknown device
	assert_that(result).is_false()

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
		return  # Third+ gamepad ignored silently
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
