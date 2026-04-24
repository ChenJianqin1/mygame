# crisis_mode_test.gd — Unit tests for camera-008 crisis mode
# GdUnit4 test file
# Tests: AC-5.1, AC-5.2, AC-5.3

class_name CrisisModeTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()
	add_child(_camera)

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-5.1: Player downed triggers CRISIS ─────────────────────────────────────

func test_player_downed_transitions_to_crisis() -> void:
	_camera._on_player_downed(1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.CRISIS)


func test_player_downed_sets_max_trauma() -> void:
	_camera._on_player_downed(1)
	assert_that(_camera.get_trauma()).is_equal(1.0)


func test_crisis_zoom_is_0_9() -> void:
	_camera._on_player_downed(1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.CRISIS_ZOOM)


# ─── AC-5.2: Crisis pauses limits ─────────────────────────────────────────────

func test_crisis_pauses_limits() -> void:
	_camera._on_player_downed(1)
	assert_that(_camera._limits_paused).is_true()


func test_limits_paused_flag_exists() -> void:
	assert_that(_camera.has_method("_pause_limits")).is_true()


func test_limits_resume_method_exists() -> void:
	assert_that(_camera.has_method("_resume_limits")).is_true()


# ─── AC-5.3: Player rescued → 0.5s delay, return to NORMAL ────────────────────

func test_player_resumed_resumes_limits() -> void:
	_camera._on_player_downed(1)
	_camera._on_player_rescued(1, Color.WHITE)
	assert_that(_camera._limits_paused).is_false()


func test_crisis_return_pending_after_rescue() -> void:
	_camera._on_player_downed(1)
	_camera._on_player_rescued(1, Color.WHITE)
	assert_that(_camera._crisis_return_pending).is_true()


func test_crisis_returns_to_normal_after_hold() -> void:
	_camera._on_player_downed(1)
	_camera._on_player_rescued(1, Color.WHITE)
	_camera._state_timer = CameraController.CRISIS_HOLD + 0.1
	_camera._update_state_timer(0.0)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.NORMAL)


func test_crisis_zoom_returns_to_base_after_rescue() -> void:
	_camera._on_player_downed(1)
	_camera._on_player_rescued(1, Color.WHITE)
	_camera._state_timer = CameraController.CRISIS_HOLD + 0.1
	_camera._process(CameraController.CRISIS_HOLD + 0.1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.BASE_ZOOM)


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_second_player_down_cancels_return() -> void:
	_camera._on_player_downed(1)
	_camera._on_player_rescued(1, Color.WHITE)
	# Before timer expires, another player goes down
	_camera._on_player_downed(2)
	assert_that(_camera._crisis_return_pending).is_false()
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.CRISIS)


# ─── Constants ───────────────────────────────────────────────────────────────

func test_crisis_zoom_constant() -> void:
	assert_that(CameraController.CRISIS_ZOOM).is_equal(Vector2(0.9, 0.9))


func test_crisis_hold_constant() -> void:
	assert_that(CameraController.CRISIS_HOLD).is_equal(0.5)
