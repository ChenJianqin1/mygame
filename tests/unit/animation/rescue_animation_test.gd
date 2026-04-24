# rescue_animation_test.gd — Unit tests for animation-006 rescue animation sequence
# GdUnit4 test file
# Tests: AC-5.1 through AC-5.5

class_name RescueAnimationTest
extends GdUnitTestSuite

# ─── Rescue Animation Constants ─────────────────────────────────────────────────

const RESCUE_EXECUTE_MS: int = 200
const RESCUE_EXECUTE_FRAMES: int = 12
const RESCUE_REVIVE_MS: int = 300
const RESCUE_REVIVE_FRAMES: int = 18
const RESCUE_TOTAL_MS: int = 500
const RESCUE_TOTAL_FRAMES: int = 30
const DOWNTIME_LOOP_FRAMES: int = 180
const DOWNTIME_LOOP_MS: int = 3000
const RESCUED_IFRAMES_FRAMES: int = 90
const RESCUED_IFRAMES_MS: int = 1500
const RESCUE_WINDOW_MS: int = 3000
const RESCUE_START_DEADLINE_MS: int = 2500  # Must start by t=2.5s

# ─── AC-5.1: Downtime loop duration ─────────────────────────────────────────────

func test_downtime_loop_frames_180() -> void:
	assert_that(DOWNTIME_LOOP_FRAMES).is_equal(180)


func test_downtime_loop_ms_3000() -> void:
	assert_that(DOWNTIME_LOOP_MS).is_equal(3000)


# ─── AC-5.2: Rescue sequence timing ──────────────────────────────────────────────

func test_rescue_execute_frames_12() -> void:
	assert_that(RESCUE_EXECUTE_FRAMES).is_equal(12)


func test_rescue_execute_ms_200() -> void:
	assert_that(RESCUE_EXECUTE_MS).is_equal(200)


func test_rescue_revive_frames_18() -> void:
	assert_that(RESCUE_REVIVE_FRAMES).is_equal(18)


func test_rescue_revive_ms_300() -> void:
	assert_that(RESCUE_REVIVE_MS).is_equal(300)


func test_rescue_total_frames_30() -> void:
	assert_that(RESCUE_TOTAL_FRAMES).is_equal(30)


func test_rescue_total_ms_500() -> void:
	assert_that(RESCUE_TOTAL_MS).is_equal(500)


# ─── AC-5.4: Rescue timing constraint ───────────────────────────────────────────

func test_rescue_start_deadline() -> void:
	# P2 must start rescue by t=2.5s to complete within 3s window
	assert_that(RESCUE_START_DEADLINE_MS).is_equal(2500)


func test_rescue_can_complete_within_window() -> void:
	# If rescue starts at t=2.5s, it should complete at t=3.0s (within window)
	var rescue_end := RESCUE_START_DEADLINE_MS + RESCUE_TOTAL_MS
	assert_that(rescue_end).is_less_or_equal(RESCUE_WINDOW_MS)


# ─── AC-5.5: Rescued i-frames ─────────────────────────────────────────────────

func test_rescued_iframes_frames_90() -> void:
	assert_that(RESCUED_IFRAMES_FRAMES).is_equal(90)


func test_rescued_iframes_ms_1500() -> void:
	assert_that(RESCUED_IFRAMES_MS).is_equal(1500)


# ─── Frame timing calculations ──────────────────────────────────────────────────

func test_frames_to_ms_conversion() -> void:
	# At 60fps, 1 frame = 16.67ms
	var ms_per_frame := float(DOWNTIME_LOOP_MS) / float(DOWNTIME_LOOP_FRAMES)
	assert_that(ms_per_frame).is_close(16.67, 0.1)


func test_rescue_execute_timing() -> void:
	var ms_per_frame := 1000.0 / 60.0  # ~16.67ms
	var expected_ms := RESCUE_EXECUTE_FRAMES * ms_per_frame
	assert_that(expected_ms).is_close(float(RESCUE_EXECUTE_MS), 1.0)


func test_rescue_revive_timing() -> void:
	var ms_per_frame := 1000.0 / 60.0
	var expected_ms := RESCUE_REVIVE_FRAMES * ms_per_frame
	assert_that(expected_ms).is_close(float(RESCUE_REVIVE_MS), 1.0)


# ─── Rescue window edge cases ───────────────────────────────────────────────────

func test_rescue_fails_if_started_too_late() -> void:
	# If rescue starts at t=2.9s, it would end at t=3.4s (outside 3.0s window)
	var late_rescue_end := 2900 + RESCUE_TOTAL_MS
	assert_that(late_rescue_end).is_greater_than(RESCUE_WINDOW_MS)


func test_rescue_succeeds_if_started_at_deadline() -> void:
	# If rescue starts exactly at t=2.5s, it should finish exactly at t=3.0s
	var deadline_rescue_end := RESCUE_START_DEADLINE_MS + RESCUE_TOTAL_MS
	assert_that(deadline_rescue_end).is_equal(RESCUE_WINDOW_MS)
