# rescue_timer_test.gd — Unit tests for ui-005 rescue timer
# GdUnit4 test file
# Tests: AC1 through AC8

class_name RescueTimerTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _timer: RescueTimer

func before() -> void:
	_timer = RescueTimer.new()
	add_child(_timer)

func after() -> void:
	if is_instance_valid(_timer):
		_timer.free()


# ─── AC1 / AC2: Timer state ───────────────────────────────────────────────────

func test_timer_starts_inactive() -> void:
	assert_that(_timer.is_active()).is_false()
	assert_that(_timer.visible).is_false()


func test_start_timer_activates() -> void:
	_timer._start_timer()
	assert_that(_timer.is_active()).is_true()
	assert_that(_timer.visible).is_true()


func test_start_timer_sets_time_to_duration() -> void:
	_timer._start_timer()
	assert_that(_timer.get_time_remaining()).is_equal(RescueTimer.RESCUE_DURATION)


# ─── AC2: Depletion formula ───────────────────────────────────────────────────

func test_fill_percent_full() -> void:
	_timer._start_timer()
	assert_that(_timer.get_fill_percent()).is_equal(100.0)


func test_fill_percent_half() -> void:
	_timer._start_timer()
	_timer._time_remaining = RescueTimer.RESCUE_DURATION / 2.0
	assert_that(_timer.get_fill_percent()).is_equal(50.0)


func test_fill_percent_empty() -> void:
	_timer._start_timer()
	_timer._time_remaining = 0.0
	assert_that(_timer.get_fill_percent()).is_equal(0.0)


func test_fill_percent_at_warn_threshold() -> void:
	_timer._start_timer()
	_timer._time_remaining = RescueTimer.WARN_THRESHOLD
	assert_that(_timer.get_fill_percent()).is_close(50.0, 0.1)


func test_fill_percent_at_critical_threshold() -> void:
	_timer._start_timer()
	_timer._time_remaining = RescueTimer.CRITICAL_THRESHOLD
	assert_that(_timer.get_fill_percent()).is_close(20.0, 0.1)


# ─── AC3 / AC4: Pause and resume ──────────────────────────────────────────────

func test_pause_timer() -> void:
	_timer._start_timer()
	_timer._pause_timer()
	assert_that(_timer._is_paused).is_true()


func test_resume_timer() -> void:
	_timer._start_timer()
	_timer._pause_timer()
	_timer._resume_timer()
	assert_that(_timer._is_paused).is_false()


func test_stop_timer_hides() -> void:
	_timer._start_timer()
	_timer._stop_timer()
	assert_that(_timer.visible).is_false()
	assert_that(_timer.is_active()).is_false()


# ─── AC6: Death trigger at zero ───────────────────────────────────────────────

func test_death_trigger_at_zero() -> void:
	_timer._start_timer()
	_timer._time_remaining = 0.0
	_timer._trigger_death()
	assert_that(_timer.is_active()).is_false()


# ─── Constants ─────────────────────────────────────────────────────────────────

func test_rescue_duration_constant() -> void:
	assert_that(RescueTimer.RESCUE_DURATION).is_equal(10.0)


func test_warn_threshold_constant() -> void:
	assert_that(RescueTimer.WARN_THRESHOLD).is_equal(5.0)


func test_critical_threshold_constant() -> void:
	assert_that(RescueTimer.CRITICAL_THRESHOLD).is_equal(2.0)


func test_pulse_freq_constants() -> void:
	assert_that(RescueTimer.PULSE_MIN_FREQ).is_equal(1.0)
	assert_that(RescueTimer.PULSE_MAX_FREQ).is_equal(4.0)


# ─── Color constants ───────────────────────────────────────────────────────────

func test_color_normal_green() -> void:
	assert_that(RescueTimer.COLOR_NORMAL).is_equal(Color("#4ADE80"))


func test_color_warn_yellow() -> void:
	assert_that(RescueTimer.COLOR_WARN).is_equal(Color("#FACC15"))


func test_color_critical_red() -> void:
	assert_that(RescueTimer.COLOR_CRITICAL).is_equal(Color("#EF4444"))


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_time_remaining_clamped_to_zero() -> void:
	_timer._start_timer()
	_timer._time_remaining = -5.0
	_timer._update_display()  # Should not crash
	assert_that(_timer.get_time_remaining()).is_equal(0.0)


func test_fill_percent_never_negative() -> void:
	_timer._start_timer()
	_timer._time_remaining = -1.0
	assert_that(_timer.get_fill_percent()).is_equal(0.0)


func test_hide_timer_resets_state() -> void:
	_timer._start_timer()
	_timer._hide_timer()
	assert_that(_timer.is_active()).is_false()
	assert_that(_timer.visible).is_false()
	assert_that(_timer._is_paused).is_false()
