# boss_focus_phase_test.gd — Unit tests for camera-007 boss focus + phase transition
# GdUnit4 test file
# Tests: AC-4.1, AC-4.2

class_name BossFocusPhaseTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()
	add_child(_camera)

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-4.1: Boss attack triggers BOSS_FOCUS ──────────────────────────────────

func test_boss_attack_transitions_to_boss_focus() -> void:
	_camera._on_boss_attack_started("BEAM")
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.BOSS_FOCUS)


func test_boss_attack_sets_zoom_0_8() -> void:
	_camera._on_boss_attack_started("DEFAULT")
	assert_that(_camera.get_zoom()).is_equal(CameraController.BOSS_FOCUS_ZOOM)


func test_boss_focus_returns_to_normal_after_hold() -> void:
	_camera._on_boss_attack_started("BEAM")
	_camera._state_timer = CameraController.BOSS_FOCUS_HOLD + 0.1
	_camera._process(CameraController.BOSS_FOCUS_HOLD + 0.1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.NORMAL)


# ─── AC-4.2: Boss phase change triggers BOSS_PHASE_CHANGE ─────────────────────

func test_boss_phase_changed_transitions_to_boss_phase_change() -> void:
	_camera._on_boss_phase_changed(2)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.BOSS_PHASE_CHANGE)


func test_boss_phase_changed_sets_trauma_0_9() -> void:
	_camera._on_boss_phase_changed(2)
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_BOSS_PHASE)


func test_boss_phase_changed_zoom_is_0_75() -> void:
	_camera._on_boss_phase_changed(2)
	assert_that(_camera.get_zoom()).is_equal(CameraController.BOSS_PHASE_CHANGE_ZOOM)


func test_boss_phase_change_returns_to_normal_after_hold() -> void:
	_camera._on_boss_phase_changed(2)
	_camera._state_timer = CameraController.BOSS_PHASE_CHANGE_HOLD + 0.1
	_camera._process(CameraController.BOSS_PHASE_CHANGE_HOLD + 0.1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.NORMAL)


func test_boss_phase_change_zoom_returns_to_base() -> void:
	_camera._on_boss_phase_changed(2)
	_camera._state_timer = CameraController.BOSS_PHASE_CHANGE_HOLD + 0.1
	_camera._process(CameraController.BOSS_PHASE_CHANGE_HOLD + 0.1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.BASE_ZOOM)


# ─── Constants ───────────────────────────────────────────────────────────────

func test_boss_focus_zoom_constant() -> void:
	assert_that(CameraController.BOSS_FOCUS_ZOOM).is_equal(Vector2(0.80, 0.80))


func test_boss_focus_hold_constant() -> void:
	assert_that(CameraController.BOSS_FOCUS_HOLD).is_equal(0.5)


func test_boss_phase_change_zoom_constant() -> void:
	assert_that(CameraController.BOSS_PHASE_CHANGE_ZOOM).is_equal(Vector2(0.75, 0.75))


func test_boss_phase_change_hold_constant() -> void:
	assert_that(CameraController.BOSS_PHASE_CHANGE_HOLD).is_equal(1.2)


func test_trauma_boss_phase_constant() -> void:
	assert_that(CameraController.TRAUMA_BOSS_PHASE).is_equal(0.9)


# ─── Camera state enum values ─────────────────────────────────────────────────

func test_camera_state_enum_values() -> void:
	assert_that(CameraController.CameraState.NORMAL).is_equal(0)
	assert_that(CameraController.CameraState.PLAYER_ATTACK).is_equal(1)
	assert_that(CameraController.CameraState.SYNC_ATTACK).is_equal(2)
	assert_that(CameraController.CameraState.COMBAT_ZOOM).is_equal(3)
	assert_that(CameraController.CameraState.BOSS_FOCUS).is_equal(4)
	assert_that(CameraController.CameraState.BOSS_PHASE_CHANGE).is_equal(5)
	assert_that(CameraController.CameraState.CRISIS).is_equal(6)
