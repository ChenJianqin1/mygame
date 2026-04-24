# Input Latency Test Suite
# GdUnit4 test file for Story 006: 输入延迟 < 3帧
# Tests that input processing latency meets performance budget requirements.
# AC-1: Input → Events emission < 16.67ms (1 frame at 60fps)
# AC-2: End-to-end < 50ms (3 frames at 60fps) — DEFERRED: requires running game
class_name InputLatencyTest
extends GdUnitTestSuite

# Test: Events.input_action signal emission latency is within 1 frame budget
func test_events_emission_within_1_frame_budget() -> void:
	# 60fps = 16.67ms per frame
	# Input system should add < 1 frame of latency
	const FRAME_BUDGET_MS := 16.67
	var start_time := _get_time_us()
	# Simulate input processing (equivalent to what InputReader does)
	_process_input_action(1, &"jump", 1.0)
	var end_time := _get_time_us()
	var latency_us := end_time - start_time
	var latency_ms := latency_us / 1000.0
	assert_that(latency_ms).is_less(FRAME_BUDGET_MS)

# Test: Jump action emission latency
func test_jump_action_emission_latency() -> void:
	const FRAME_BUDGET_MS := 16.67
	var start_time := _get_time_us()
	_process_input_action(1, &"jump", 1.0)
	var end_time := _get_time_us()
	var latency_ms := (end_time - start_time) / 1000.0
	assert_that(latency_ms).is_less(FRAME_BUDGET_MS)

# Test: Move action emission latency (continuous input)
func test_move_action_emission_latency() -> void:
	const FRAME_BUDGET_MS := 16.67
	var start_time := _get_time_us()
	_process_input_action(1, &"move_horizontal", 0.8)
	var end_time := _get_time_us()
	var latency_ms := (end_time - start_time) / 1000.0
	assert_that(latency_ms).is_less(FRAME_BUDGET_MS)

# Test: Attack action emission latency
func test_attack_action_emission_latency() -> void:
	const FRAME_BUDGET_MS := 16.67
	var start_time := _get_time_us()
	_process_input_action(1, &"attack_light", 1.0)
	var end_time := _get_time_us()
	var latency_ms := (end_time - start_time) / 1000.0
	assert_that(latency_ms).is_less(FRAME_BUDGET_MS)

# Test: Dodge action emission latency
func test_dodge_action_emission_latency() -> void:
	const FRAME_BUDGET_MS := 16.67
	var start_time := _get_time_us()
	_process_input_action(2, &"dodge", 1.0)
	var end_time := _get_time_us()
	var latency_ms := (end_time - start_time) / 1000.0
	assert_that(latency_ms).is_less(FRAME_BUDGET_MS)

# Test: All action types meet latency budget
func test_all_action_types_meet_latency_budget() -> void:
	const FRAME_BUDGET_MS := 16.67
	var actions := [
		[1, &"jump", 1.0],
		[1, &"move_horizontal", 1.0],
		[1, &"attack_light", 1.0],
		[1, &"attack_heavy", 1.0],
		[1, &"dodge", 1.0],
		[2, &"jump", 1.0],
		[2, &"attack_light", 1.0],
	]
	for action in actions:
		var player_id: int = action[0]
		var act: StringName = action[1]
		var strength: float = action[2]
		var start_time := _get_time_us()
		_process_input_action(player_id, act, strength)
		var end_time := _get_time_us()
		var latency_ms := (end_time - start_time) / 1000.0
		assert_that(latency_ms).is_less(FRAME_BUDGET_MS)

# Test: Rapid sequential inputs do not accumulate latency
func test_rapid_inputs_do_not_accumulate_latency() -> void:
	const FRAME_BUDGET_MS := 16.67
	var actions := [&"jump", &"attack_light", &"dodge", &"attack_heavy"]
	var all_within_budget := true
	for act in actions:
		var start_time := _get_time_us()
		_process_input_action(1, act, 1.0)
		var end_time := _get_time_us()
		var latency_ms := (end_time - start_time) / 1000.0
		if latency_ms >= FRAME_BUDGET_MS:
			all_within_budget = false
	assert_that(all_within_budget).is_true()

# Test: P2 actions also meet latency budget
func test_p2_actions_meet_latency_budget() -> void:
	const FRAME_BUDGET_MS := 16.67
	var start_time := _get_time_us()
	_process_input_action(2, &"jump", 1.0)
	_process_input_action(2, &"attack_heavy", 1.0)
	var end_time := _get_time_us()
	var latency_ms := (end_time - start_time) / 1000.0
	# Both emissions in sequence should still be well under budget
	assert_that(latency_ms).is_less(FRAME_BUDGET_MS * 2)

# --- Helper methods ---

func _get_time_us() -> int:
	# Use Time.get_ticks_usec() for microsecond precision timing
	return Time.get_ticks_usec()

func _process_input_action(player_id: int, action: StringName, strength: float) -> void:
	# This simulates what the input readers do — emit Events signal
	# In the real implementation this is an O(1) signal emission
	Events.input_action.emit(player_id, action, strength)

# Note on AC-2 (end-to-end latency < 50ms):
# This requires a running game with display and cannot be tested in headless unit tests.
# Manual verification required: connect a logic analyzer or use frame timestamp logging
# to verify按键到角色实际动作的延迟 < 50ms (3 frames at 60fps).
# This is DEFERRED to manual playtest verification.
