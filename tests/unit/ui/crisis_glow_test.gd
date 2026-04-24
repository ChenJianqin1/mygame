# crisis_glow_test.gd — Unit tests for ui-006 crisis glow
# GdUnit4 test file
# Tests: AC1 through AC7

class_name CrisisGlowTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _glow: CrisisGlow

func before() -> void:
	_glow = CrisisGlow.new()
	add_child(_glow)

func after() -> void:
	if is_instance_valid(_glow):
		_glow.free()


# ─── AC1 / AC2: Crisis state ──────────────────────────────────────────────────

func test_crisis_starts_inactive() -> void:
	assert_that(_glow.is_crisis_active()).is_false()


func test_enter_crisis() -> void:
	_glow._enter_crisis()
	assert_that(_glow.is_crisis_active()).is_true()


func test_exit_crisis() -> void:
	_glow._enter_crisis()
	_glow._exit_crisis()
	assert_that(_glow.is_crisis_active()).is_false()


# ─── AC3: Pulse frequency ─────────────────────────────────────────────────────

func test_pulse_frequency_constant() -> void:
	assert_that(CrisisGlow.PULSE_FREQUENCY).is_equal(1.0)


func test_pulse_amplitude_constant() -> void:
	assert_that(CrisisGlow.PULSE_AMPLITUDE).is_equal(0.15)


# ─── AC4 / AC5: Opacity and intensity ─────────────────────────────────────────

func test_min_opacity_constant() -> void:
	assert_that(CrisisGlow.MIN_OPACITY).is_equal(0.3)


func test_max_opacity_constant() -> void:
	assert_that(CrisisGlow.MAX_OPACITY).is_equal(0.6)


func test_glow_color_is_red() -> void:
	assert_that(CrisisGlow.GLOW_COLOR).is_equal(Color(1.0, 0.0, 0.0, 1.0))


func test_crisis_threshold_constant() -> void:
	assert_that(CrisisGlow.CRISIS_THRESHOLD).is_equal(0.30)


func test_fade_duration_constant() -> void:
	assert_that(CrisisGlow.FADE_DURATION_MS).is_equal(500)


# ─── AC6: Fade out duration ───────────────────────────────────────────────────

func test_fade_duration_ms() -> void:
	# FADE_DURATION_MS is 500ms
	assert_that(CrisisGlow.FADE_DURATION_MS).is_equal(500)


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_opacity_clamped_to_max() -> void:
	_glow._current_opacity = 1.0
	_glow._update_pulse()
	# Should clamp to MAX_OPACITY
	assert_that(_glow.get_current_opacity()).is_less_or_equal(CrisisGlow.MAX_OPACITY)


func test_opacity_never_negative() -> void:
	_glow._current_opacity = -0.5
	_glow._update_pulse()
	assert_that(_glow.get_current_opacity()).is_greater_or_equal(0.0)


func test_boss_defeated_exits_crisis() -> void:
	_glow._enter_crisis()
	_glow._on_boss_defeated()
	assert_that(_glow.is_crisis_active()).is_false()


func test_pulse_time_increases_when_active() -> void:
	_glow._is_crisis_active = true
	var initial_time := _glow._pulse_time
	_glow._process(0.016)  # ~1 frame at 60fps
	assert_that(_glow._pulse_time).is_greater_than(initial_time)
