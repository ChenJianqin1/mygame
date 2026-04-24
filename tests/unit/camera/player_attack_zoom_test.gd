# player_attack_zoom_test.gd — Unit tests for camera-004 player attack zoom
# GdUnit4 test file
# Tests: AC-3.1, AC-3.2

class_name PlayerAttackZoomTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()
	add_child(_camera)

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-3.1: Attack triggers PLAYER_ATTACK state ───────────────────────────────

func test_attack_started_transitions_to_player_attack() -> void:
	_camera._on_attack_started("LIGHT", 1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.PLAYER_ATTACK)


func test_attack_started_adds_light_trauma() -> void:
	_camera._on_attack_started("LIGHT", 1)
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_LIGHT)


func test_attack_started_adds_medium_trauma() -> void:
	_camera._on_attack_started("MEDIUM", 1)
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_MEDIUM)


func test_attack_started_adds_heavy_trauma() -> void:
	_camera._on_attack_started("HEAVY", 1)
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_HEAVY)


func test_attack_started_adds_special_trauma() -> void:
	_camera._on_attack_started("SPECIAL", 1)
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_SPECIAL)


func test_attack_started_unknown_type_defaults_to_medium() -> void:
	_camera._on_attack_started("UNKNOWN", 1)
	assert_that(_camera.get_trauma()).is_equal(CameraController.TRAUMA_MEDIUM)


# ─── AC-3.1: Attack zoom value ─────────────────────────────────────────────────

func test_player_attack_zoom_is_0_9() -> void:
	_camera._on_attack_started("LIGHT", 1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.ATTACK_ZOOM)


# ─── AC-3.2: Auto-return to NORMAL after 0.3s ─────────────────────────────────

func test_state_returns_to_normal_after_hold() -> void:
	_camera._on_attack_started("LIGHT", 1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.PLAYER_ATTACK)

	# Advance time past hold duration
	_camera._state_timer = CameraController.ATTACK_ZOOM_HOLD + 0.1
	_camera._update_state_timer(0.0)  # Timer already at hold time

	# Process state transition
	_camera._process(CameraController.ATTACK_ZOOM_HOLD + 0.1)
	assert_that(_camera.get_state()).is_equal(CameraController.CameraState.NORMAL)


func test_zoom_returns_to_base_after_normal() -> void:
	_camera._on_attack_started("LIGHT", 1)
	_camera._state_timer = CameraController.ATTACK_ZOOM_HOLD + 0.1
	_camera._process(CameraController.ATTACK_ZOOM_HOLD + 0.1)
	assert_that(_camera.get_zoom()).is_equal(CameraController.BASE_ZOOM)


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_same_state_does_not_reset_timer() -> void:
	_camera._on_attack_started("LIGHT", 1)
	var initial_timer := _camera._state_timer
	_camera._on_attack_started("LIGHT", 1)  # Same state
	# Timer should not reset
	assert_that(_camera._state_timer).is_equal(initial_timer)


func test_attack_during_attack_state_does_not_reset_hold() -> void:
	_camera._on_attack_started("LIGHT", 1)
	_camera._state_timer = 0.2  # Partway through hold
	var timer_before := _camera._state_timer
	_camera._on_attack_started("LIGHT", 1)  # New attack
	# Timer should reset to 0 (transition_to doesn't restart timer for same state)
	assert_that(_camera._state_timer).is_equal(timer_before)


func test_camera_state_enum_values() -> void:
	assert_that(CameraController.CameraState.NORMAL).is_equal(0)
	assert_that(CameraController.CameraState.PLAYER_ATTACK).is_equal(1)
	assert_that(CameraController.CameraState.SYNC_ATTACK).is_equal(2)
	assert_that(CameraController.CameraState.CRISIS).is_equal(3)
	assert_that(CameraController.CameraState.BOSS_ATTACK).is_equal(4)


func test_trauma_constants() -> void:
	assert_that(CameraController.TRAUMA_LIGHT).is_equal(0.15)
	assert_that(CameraController.TRAUMA_MEDIUM).is_equal(0.25)
	assert_that(CameraController.TRAUMA_HEAVY).is_equal(0.4)
	assert_that(CameraController.TRAUMA_SPECIAL).is_equal(0.6)


func test_attack_zoom_constant() -> void:
	assert_that(CameraController.ATTACK_ZOOM).is_equal(Vector2(0.9, 0.9))


func test_attack_zoom_hold_constant() -> void:
	assert_that(CameraController.ATTACK_ZOOM_HOLD).is_equal(0.3)


func test_get_trauma_for_attack_type() -> void:
	assert_that(CameraController.get_trauma_for_attack_type("LIGHT")).is_equal(0.15)
	assert_that(CameraController.get_trauma_for_attack_type("MEDIUM")).is_equal(0.25)
	assert_that(CameraController.get_trauma_for_attack_type("HEAVY")).is_equal(0.4)
	assert_that(CameraController.get_trauma_for_attack_type("SPECIAL")).is_equal(0.6)
	assert_that(CameraController.get_trauma_for_attack_type("INVALID")).is_equal(0.25)
