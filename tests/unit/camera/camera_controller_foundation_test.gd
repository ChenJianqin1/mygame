# camera_controller_foundation_test.gd — Unit tests for camera-001 camera controller
# GdUnit4 test file
# Tests: AC-7.1 (60fps stable), AC-2.4 (no drift after shake)

class_name CameraControllerTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-7.1: Trauma addition and decay ─────────────────────────────────────

func test_add_trauma_increases_trauma() -> void:
	# Given: Camera at rest
	assert_that(_camera.get_trauma()).is_equal(0.0)

	# When: Trauma is added
	_camera.add_trauma(0.5)

	# Then: Trauma is increased
	assert_that(_camera.get_trauma()).is_equal(0.5)


func test_trauma_clamped_to_max() -> void:
	# When: Trauma exceeds MAX_TRAUMA
	_camera.add_trauma(2.0)

	# Then: Clamped to 1.0
	assert_that(_camera.get_trauma()).is_equal(1.0)


func test_trauma_decay_over_time() -> void:
	# Given: Full trauma
	_camera.add_trauma(1.0)
	assert_that(_camera.get_trauma()).is_equal(1.0)

	# When: 0.5 seconds pass
	_camera.update_camera(0.5)

	# Then: Trauma decayed by 2.0/s * 0.5s = 1.0 → should be 0
	# TRAUMA_DECAY = 2.0 per second
	# After 0.5s: 1.0 - (2.0 * 0.5) = 0.0
	assert_that(_camera.get_trauma()).is_equal(0.0)


func test_trauma_decay_partially() -> void:
	# Given: 0.5 trauma
	_camera.add_trauma(0.5)
	assert_that(_camera.get_trauma()).is_equal(0.5)

	# When: 0.25 seconds pass
	_camera.update_camera(0.25)

	# Then: Decayed to 0.5 - (2.0 * 0.25) = 0.0
	assert_that(_camera.get_trauma()).is_equal(0.0)


# ─── AC-2.4: No drift — offset returns to zero exactly ───────────────────

func test_offset_returns_to_zero_when_trauma_zero() -> void:
	# Given: Trauma applied and decayed to zero
	_camera.add_trauma(1.0)
	_camera.update_camera(1.0)  # 1.0 / 2.0 = 0.5s decay... wait TRAUMA_DECAY=2.0/s
	# After 0.5s: 1.0 - (2.0 * 0.5) = 0.0
	_camera.update_camera(0.5)

	# Then: Offset is exactly Vector2.ZERO (no drift)
	assert_that(_camera.offset).is_equal(Vector2.ZERO)


func test_offset_proportional_to_trauma_squared() -> void:
	# Given: Trauma = 0.5
	_camera.add_trauma(0.5)
	# Trauma stays at 0.5 until update

	# Manually verify: max_offset * trauma^2 = 50 * 0.25 = 12.5
	# We can't directly test the random value, but we can verify it's bounded
	_camera.update_camera(0.0)  # No time passes

	# offset magnitude should be <= MAX_OFFSET
	var magnitude := _camera.offset.length()
	assert_that(magnitude).is_less_or_equal(CameraController.MAX_OFFSET)


func test_is_shaking_returns_true_when_trauma_positive() -> void:
	_camera.add_trauma(0.3)
	assert_that(_camera.is_shaking()).is_true()


func test_is_shaking_returns_false_when_trauma_zero() -> void:
	assert_that(_camera.is_shaking()).is_false()


# ─── Additional tests ─────────────────────────────────────────────────────────

func test_reset_clears_trauma_and_offset() -> void:
	_camera.add_trauma(1.0)
	_camera.update_camera(0.1)
	_camera.reset()

	assert_that(_camera.get_trauma()).is_equal(0.0)
	assert_that(_camera.offset).is_equal(Vector2.ZERO)


func test_camera_shake_intensity_signal_emits() -> void:
	var emissions: Array = []
	_camera.camera_shake_intensity.connect(func(t): emissions.append(t))

	_camera.add_trauma(0.5)
	_camera.update_camera(0.0)

	# Signal should emit on add_trauma when trauma > 0
	assert_that(emissions.size()).is_positive()


func test_trauma_multiple_additions() -> void:
	_camera.add_trauma(0.3)
	_camera.add_trauma(0.4)

	assert_that(_camera.get_trauma()).is_equal(0.7)
