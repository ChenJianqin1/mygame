# sync_attack_camera_test.gd — Unit tests for camera-005 sync attack camera
# GdUnit4 test file
# Tests: AC-2.3

class_name SyncAttackCameraTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()
	add_child(_camera)

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-2.3: Sync burst triggers SYNC_ATTACK state ───────────────────────────

func test_sync_burst_transitions_to_sync_attack() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.SYNC_ATTACK)


func test_sync_burst_sets_max_trauma() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_SYNC)


func test_sync_attack_zoom_is_0_85() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	assert_that(_camera.get_zoom()).is_equal(CameraController.SYNC_ATTACK_ZOOM)


# ─── AC-2.3: SYNC_ATTACK hold timer = 0.5s ─────────────────────────────────

func test_sync_attack_returns_to_normal_after_hold() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	_camera._state_timer = CameraController.SYNC_ATTACK_HOLD + 0.1
	_camera._process(CameraController.SYNC_ATTACK_HOLD + 0.1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.NORMAL)


func test_sync_attack_zoom_returns_to_base() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	_camera._state_timer = CameraController.SYNC_ATTACK_HOLD + 0.1
	_camera._process(CameraController.SYNC_ATTACK_HOLD + 0.1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.BASE_ZOOM)


# ─── Edge cases ───────────────────────────────────────────────────────────────

func test_sync_burst_during_sync_attack_does_not_reset_hold() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	_camera._state_timer = 0.3  # Partway through hold
	var timer_before := _camera._state_timer
	_camera._on_sync_burst_triggered(Vector2(400, 360))  # New sync burst
	# Timer should not reset (same state transition returns early)
	assert_that(_camera._state_timer).is_equal(timer_before)


func test_sync_attack_constant() -> void:
	assert_that(CameraController.SYNC_ATTACK_ZOOM).is_equal(Vector2(0.85, 0.85))


func test_sync_attack_hold_constant() -> void:
	assert_that(CameraController.SYNC_ATTACK_HOLD).is_equal(0.5)


func test_trauma_sync_constant() -> void:
	assert_that(CameraController.TRAUMA_SYNC).is_equal(0.8)
