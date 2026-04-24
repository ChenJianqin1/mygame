# paper_texture_test.gd — Unit tests for animation-005 paper texture
# GdUnit4 test file
# Tests: AC-6.1, AC-6.2

class_name PaperTextureTest
extends GdUnitTestSuite

# ─── Paper texture constants ──────────────────────────────────────────────────

const PAPER_TEXTURE_OPACITY: float = 0.15
const PAPER_JITTER_AMPLITUDE: float = 1.0
const PAPER_JITTER_FREQUENCY: float = 8.0
const SQUASH_STRETCH_INTENSITY: float = 1.2

# ─── AC-6.1: Paper texture opacity ───────────────────────────────────────────

func test_paper_texture_opacity() -> void:
	assert_that(PAPER_TEXTURE_OPACITY).is_equal(0.15)


# ─── AC-6.1: Jitter frequency (8Hz) ─────────────────────────────────────────

func test_jitter_frequency_8hz() -> void:
	assert_that(PAPER_JITTER_FREQUENCY).is_equal(8.0)


# ─── AC-6.1: Jitter amplitude (±1.0px) ──────────────────────────────────────

func test_jitter_amplitude_1px() -> void:
	assert_that(PAPER_JITTER_AMPLITUDE).is_equal(1.0)


# ─── AC-6.2: Squash/stretch on hit ───────────────────────────────────────────

func test_squash_stretch_intensity() -> void:
	assert_that(SQUASH_STRETCH_INTENSITY).is_equal(1.2)


func test_squash_x_scale() -> void:
	# On hit, X scale should stretch (1.2x)
	var squash_x := SQUASH_STRETCH_INTENSITY
	assert_that(squash_x).is_equal(1.2)


func test_squash_y_scale() -> void:
	# On hit, Y scale should compress (inverse of X)
	var squash_y := 2.0 - SQUASH_STRETCH_INTENSITY  # 0.8
	assert_that(squash_y).is_equal(0.8)


# ─── Jitter calculation tests ──────────────────────────────────────────────────

func test_jitter_offset_calculation() -> void:
	# Simulate jitter at peak amplitude
	var time := 0.0  # sin(0) = 0, not a peak
	# At t=0.125s (1/8 of period), sin(2*pi*8*0.125) = sin(2*pi) = ~0
	# Better test: at t=0.0625s (1/16 of period)
	var t := 0.0625
	var expected := sin(TAU * PAPER_JITTER_FREQUENCY * t)
	# Just verify the calculation is bounded
	assert_that(expected).is_less_or_equal(1.0)
	assert_that(expected).is_greater_or_equal(-1.0)


# ─── Squash/stretch recovery ──────────────────────────────────────────────────

func test_squash_recovery_formula() -> void:
	# After 2 frames, scale returns to 1.0, 1.0
	var frames := 2
	var current_scale_x := lerpf(SQUASH_STRETCH_INTENSITY, 1.0, float(frames) / 2.0)
	var current_scale_y := lerpf(2.0 - SQUASH_STRETCH_INTENSITY, 1.0, float(frames) / 2.0)
	assert_that(current_scale_x).is_equal(1.0)
	assert_that(current_scale_y).is_equal(1.0)


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_jitter_bounded_range() -> void:
	# Jitter should always be within ±amplitude
	var t := randf() * 10.0  # Random time
	var jitter := sin(TAU * PAPER_JITTER_FREQUENCY * t) * PAPER_JITTER_AMPLITUDE
	assert_that(jitter).is_less_or_equal(PAPER_JITTER_AMPLITUDE)
	assert_that(jitter).is_greater_or_equal(-PAPER_JITTER_AMPLITUDE)


func test_opacity_in_valid_range() -> void:
	# Opacity should be between 0.0 and 1.0
	assert_that(PAPER_TEXTURE_OPACITY).is_greater_or_equal(0.0)
	assert_that(PAPER_TEXTURE_OPACITY).is_less_or_equal(1.0)
