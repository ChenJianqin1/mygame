# FPS Stability Test Suite
# GdUnit4 test file for Story 007: 60fps 稳定性
# Tests that input processing does not cause frame time budget violations.
# AC-1/AC-2/AC-3: Input processing must complete within 12ms frame budget
class_name FpsStabilityTest
extends GdUnitTestSuite

# Test: Single input processing call completes within frame budget
func test_single_input_processing_within_frame_budget() -> void:
	# Frame budget: 12ms for game logic (60fps = 16.67ms total)
	# Input system should use < 1ms
	const INPUT_BUDGET_MS := 1.0
	var start_time := _get_time_us()
	_process_single_input(1, &"jump", 1.0)
	var end_time := _get_time_us()
	var duration_ms := (end_time - start_time) / 1000.0
	assert_that(duration_ms).is_less(INPUT_BUDGET_MS)

# Test: Burst of 10 rapid inputs still within budget
func test_burst_10_inputs_within_frame_budget() -> void:
	const INPUT_BUDGET_MS := 1.0
	var start_time := _get_time_us()
	for i: int in 10:
		_process_single_input(1, &"attack_light", 1.0)
	var end_time := _get_time_us()
	var duration_ms := (end_time - start_time) / 1000.0
	assert_that(duration_ms).is_less(INPUT_BUDGET_MS)

# Test: Continuous rapid inputs do not accumulate over budget
func test_continuous_rapid_inputs_no_accumulation() -> void:
	const INPUT_BUDGET_MS := 1.0
	var actions := [&"jump", &"attack_light", &"attack_heavy", &"dodge"]
	var total_start := _get_time_us()
	for j: int in 20:
		for act: StringName in actions:
			_process_single_input(1, act, 1.0)
	var total_end := _get_time_us()
	var total_ms := (total_end - total_start) / 1000.0
	# 80 emissions total should still be under budget
	assert_that(total_ms).is_less(INPUT_BUDGET_MS * 10.0)

# Test: P1 and P2 simultaneous inputs stay within budget
func test_p1_p2_simultaneous_inputs_within_budget() -> void:
	const INPUT_BUDGET_MS := 1.0
	var start_time := _get_time_us()
	_process_single_input(1, &"jump", 1.0)
	_process_single_input(2, &"move_horizontal", 0.8)
	_process_single_input(1, &"attack_light", 1.0)
	_process_single_input(2, &"dodge", 1.0)
	var end_time := _get_time_us()
	var duration_ms := (end_time - start_time) / 1000.0
	assert_that(duration_ms).is_less(INPUT_BUDGET_MS)

# Test: Move action (continuous) also within budget
func test_move_action_within_budget() -> void:
	const INPUT_BUDGET_MS := 1.0
	var start_time := _get_time_us()
	_process_single_input(1, &"move_horizontal", 0.5)
	_process_single_input(1, &"move_horizontal", -0.3)
	var end_time := _get_time_us()
	var duration_ms := (end_time - start_time) / 1000.0
	assert_that(duration_ms).is_less(INPUT_BUDGET_MS)

# Test: All discrete action types within budget
func test_all_discrete_actions_within_budget() -> void:
	const INPUT_BUDGET_MS := 1.0
	var actions := [&"jump", &"dodge", &"attack_light", &"attack_heavy"]
	var start_time := _get_time_us()
	for act: StringName in actions:
		_process_single_input(1, act, 1.0)
	var end_time := _get_time_us()
	var duration_ms := (end_time - start_time) / 1000.0
	assert_that(duration_ms).is_less(INPUT_BUDGET_MS)

# Test: 60fps frame budget not violated by input processing
func test_60fps_frame_budget_not_violated() -> void:
	# Total frame budget = 16.67ms at 60fps
	# Game logic budget = 12ms
	# Input should use < 1ms (leaving 11ms for other systems)
	const INPUT_BUDGET_MS := 1.0
	var start_time := _get_time_us()
	# Simulate one full input processing cycle
	_process_single_input(1, &"jump", 1.0)
	_process_single_input(2, &"move_horizontal", 0.8)
	var end_time := _get_time_us()
	var duration_ms := (end_time - start_time) / 1000.0
	assert_that(duration_ms).is_less(INPUT_BUDGET_MS)

# --- Helper methods ---

func _get_time_us() -> int:
	return Time.get_ticks_usec()

func _process_single_input(player_id: int, action: StringName, strength: float) -> void:
	Events.input_action.emit(player_id, action, strength)

# Note on AC-1/AC-2/AC-3 (60fps stability):
# Full 60fps stability testing requires a running Godot instance with frame profiling.
# These tests verify the INPUT PROCESSING PORTION stays within its allocated frame budget.
# Actual FPS stability over 1 minute of continuous play must be verified manually
# using Godot's Performance monitor or an external frame profiler.
#
# Memory allocation testing (original test_no_memory_allocation_in_input_processing)
# is removed because it required Godot's memory profiler which is unavailable in
# headless unit tests. Manual verification via Godot profiler is required for that check.
#
# Manual verification steps:
# 1. Run game at 60fps target
# 2. Use Godot's Performance singleton to monitor:
#    - Performance.monitor("frame_time")
#    - Performance.monitor("process_time")
# 3. Press inputs continuously for 1 minute
# 4. Verify frame time stays under 16.67ms consistently
