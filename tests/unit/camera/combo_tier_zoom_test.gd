# combo_tier_zoom_test.gd — Unit tests for camera-006 combo tier zoom
# GdUnit4 test file
# Tests: AC-3.3, AC-3.4

class_name ComboTierZoomTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()
	add_child(_camera)

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-3.3: Combo tier 3+ triggers COMBAT_ZOOM ──────────────────────────────

func test_combo_tier_3_triggers_combat_zoom() -> void:
	_camera._on_combo_tier_changed(3, 1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.COMBAT_ZOOM)


func test_combo_tier_4_triggers_combat_zoom() -> void:
	_camera._on_combo_tier_changed(4, 1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.COMBAT_ZOOM)


func test_combo_tier_2_does_not_trigger_combat_zoom() -> void:
	_camera._on_combo_tier_changed(2, 1)
	# State should not change to COMBAT_ZOOM
	assert_that(_camera.get_state()).is_not_equal(CameraController.CameraState.COMBAT_ZOOM)


func test_combo_tier_1_does_not_trigger_combat_zoom() -> void:
	_camera._on_combo_tier_changed(1, 1)
	assert_that(_camera.get_state()).is_not_equal(CameraController.CameraState.COMBAT_ZOOM)


func test_combat_zoom_zoom_is_0_85() -> void:
	_camera._on_combo_tier_changed(3, 1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.COMBAT_ZOOM)


# ─── AC-3.4: Combo drops below 3 → returns to NORMAL after 0.3s ─────────────

func test_combat_zoom_returns_to_normal_after_hold() -> void:
	_camera._on_combo_tier_changed(3, 1)
	_camera._state_timer = CameraController.COMBAT_ZOOM_HOLD + 0.1
	_camera._process(CameraController.COMBAT_ZOOM_HOLD + 0.1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.NORMAL)


func test_combat_zoom_zoom_returns_to_base() -> void:
	_camera._on_combo_tier_changed(3, 1)
	_camera._state_timer = CameraController.COMBAT_ZOOM_HOLD + 0.1
	_camera._process(CameraController.COMBAT_ZOOM_HOLD + 0.1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.BASE_ZOOM)


# ─── Constants ───────────────────────────────────────────────────────────────

func test_combat_zoom_constant() -> void:
	assert_that(CameraController.COMBAT_ZOOM).is_equal(Vector2(0.85, 0.85))


func test_combat_zoom_hold_constant() -> void:
	assert_that(CameraController.COMBAT_ZOOM_HOLD).is_equal(0.3)


func test_combo_tier_zoom_threshold_constant() -> void:
	assert_that(CameraController.COMBO_TIER_ZOOM_THRESHOLD).is_equal(3)
