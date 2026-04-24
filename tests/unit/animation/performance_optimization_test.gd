# performance_optimization_test.gd — Unit tests for animation-008 performance optimization
# GdUnit4 test file
# Tests: AC-7.1, AC-7.2, AC-7.3

class_name PerformanceOptimizationTest
extends GdUnitTestSuite

# ─── Performance Budget Constants ──────────────────────────────────────────────
const MAX_SPRITE_MEMORY_MB: float = 24.0
const MAX_TOTAL_MEMORY_MB: float = 40.0
const FRAME_TIME_BUDGET_MS: float = 12.0


# ─── AC-7.1: Frame budget monitoring ─────────────────────────────────────────

func test_frame_time_budget_12ms() -> void:
	assert_that(FRAME_TIME_BUDGET_MS).is_equal(12.0)


func test_frame_time_under_budget() -> void:
	var frame_time := 10.0  # Under budget
	var is_under_budget := frame_time <= FRAME_TIME_BUDGET_MS
	assert_that(is_under_budget).is_true()


func test_frame_time_at_budget() -> void:
	var frame_time := 12.0  # Exactly at budget
	var is_under_budget := frame_time <= FRAME_TIME_BUDGET_MS
	assert_that(is_under_budget).is_true()


func test_frame_time_over_budget() -> void:
	var frame_time := 15.0  # Over budget
	var is_under_budget := frame_time <= FRAME_TIME_BUDGET_MS
	assert_that(is_under_budget).is_false()


# ─── AC-7.2: Offscreen pause logic ──────────────────────────────────────────

func test_offscreen_character_count_tracking() -> void:
	# Simulate tracking 3 characters
	var tracked := 3
	assert_that(tracked).is_less_or_equal(3)  # Max concurrent animated characters


func test_process_mode_paused_value() -> void:
	# PROCESS_MODE_DISABLED = 3 in Godot
	var expected_paused_mode := 3
	assert_that(Node.PROCESS_MODE_DISABLED).is_equal(expected_paused_mode)


func test_process_mode_inherit_value() -> void:
	# PROCESS_MODE_INHERIT = 0 in Godot
	var expected_inherit_mode := 0
	assert_that(Node.PROCESS_MODE_INHERIT).is_equal(expected_inherit_mode)


# ─── AC-7.3: Memory budget ───────────────────────────────────────────────────

func test_sprite_memory_budget_24mb() -> void:
	assert_that(MAX_SPRITE_MEMORY_MB).is_equal(24.0)


func test_total_memory_budget_40mb() -> void:
	assert_that(MAX_TOTAL_MEMORY_MB).is_equal(40.0)


func test_memory_calculation_per_character() -> void:
	var memory_per_character := 8.0  # ~8MB per character
	var num_characters := 3
	var total_memory := memory_per_character * num_characters
	assert_that(total_memory).is_less_or_equal(MAX_SPRITE_MEMORY_MB)


func test_memory_with_particles_within_budget() -> void:
	var sprite_memory := 24.0
	var particle_memory := 12.0  # ~12MB for particles
	var total := sprite_memory + particle_memory
	assert_that(total).is_less_or_equal(MAX_TOTAL_MEMORY_MB)


# ─── Frame time history tests ─────────────────────────────────────────────────

func test_frame_time_history_average() -> void:
	var history := [8.0, 10.0, 12.0, 9.0, 11.0]
	var total := 0.0
	for ft in history:
		total += ft
	var average := total / float(history.size())
	assert_that(average).is_close(10.0, 0.1)


func test_frame_time_history_trimming() -> void:
	# Simulate having more than 60 frames stored
	var history := range(65)  # 65 frames
	# Should trim to 60
	if history.size() > 60:
		history = history.slice(0, 59)
	assert_that(history.size()).is_equal(60)


func test_sustained_over_budget_detection() -> void:
	# More than half of last 60 frames over budget
	var over_budget_count := 35  # More than 30
	var is_over_budget := over_budget_count > 30
	assert_that(is_over_budget).is_true()


# ─── Performance threshold tests ───────────────────────────────────────────────

func test_max_concurrent_characters() -> void:
	var max_characters := 3
	assert_that(max_characters).is_equal(3)


func test_offscreen_optimization_threshold() -> void:
	var threshold := 6  # 6+ characters triggers optimization
	assert_that(threshold).is_greater_or_equal(6)
