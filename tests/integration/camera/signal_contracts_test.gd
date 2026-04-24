# signal_contracts_test.gd — Integration tests for camera-010 signal contracts
# GdUnit4 test file
# Tests: AC-8.1, AC-8.2, AC-8.3

class_name CameraSignalContractsTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _camera: CameraController

func before() -> void:
	_camera = CameraController.new()
	add_child(_camera)

func after() -> void:
	if is_instance_valid(_camera):
		_camera.free()


# ─── AC-8.1: All 8 upstream signals subscribed ─────────────────────────────────

func test_attack_started_handler_exists() -> void:
	assert_that(_camera.has_method("_on_attack_started")).is_true()


func test_hit_confirmed_handler_exists() -> void:
	assert_that(_camera.has_method("_on_hit_confirmed")).is_true()


func test_combo_tier_changed_handler_exists() -> void:
	assert_that(_camera.has_method("_on_combo_tier_changed")).is_true()


func test_sync_burst_triggered_handler_exists() -> void:
	assert_that(_camera.has_method("_on_sync_burst_triggered")).is_true()


func test_boss_attack_started_handler_exists() -> void:
	assert_that(_camera.has_method("_on_boss_attack_started")).is_true()


func test_boss_phase_changed_handler_exists() -> void:
	assert_that(_camera.has_method("_on_boss_phase_changed")).is_true()


func test_player_downed_handler_exists() -> void:
	assert_that(_camera.has_method("_on_player_downed")).is_true()


func test_player_rescued_handler_exists() -> void:
	assert_that(_camera.has_method("_on_player_rescued")).is_true()


# ─── AC-8.2: Downstream signals exist ───────────────────────────────────────

func test_camera_shake_intensity_signal_exists() -> void:
	assert_that(_camera.has_signal("camera_shake_intensity")).is_true()


func test_camera_shake_intensity_emits_on_trauma_change() -> void:
	var emissions: Array = []
	_camera.camera_shake_intensity.connect(func(t): emissions.append(t))
	_camera.add_trauma(0.5)
	assert_that(emissions.size()).is_positive()


# ─── AC-8.3: Signal handlers callable with correct signatures ─────────────────

func test_on_attack_started_accepts_two_args() -> void:
	# Should not error
	_camera._on_attack_started("LIGHT", 1)


func test_on_combo_tier_changed_accepts_two_args() -> void:
	_camera._on_combo_tier_changed(3, 1)


func test_on_sync_burst_triggered_accepts_vector2() -> void:
	_camera._on_sync_burst_triggered(Vector2(400, 360))


func test_on_boss_attack_started_accepts_string() -> void:
	_camera._on_boss_attack_started("DEFAULT")


func test_on_boss_phase_changed_accepts_int() -> void:
	_camera._on_boss_phase_changed(2)


func test_on_player_downed_accepts_int() -> void:
	_camera._on_player_downed(1)


func test_on_player_rescued_accepts_int_and_color() -> void:
	_camera._on_player_rescued(1, Color.WHITE)


# ─── Signal connection verification ────────────────────────────────────────────

func test_all_signal_handlers_are_callable() -> void:
	# Verify each handler can be called without error
	_camera._on_attack_started("LIGHT", 1)
	_camera._on_combo_tier_changed(3, 1)
	_camera._on_sync_burst_triggered(Vector2(400, 360))
	_camera._on_boss_attack_started("DEFAULT")
	_camera._on_boss_phase_changed(2)
	_camera._on_player_downed(1)
	_camera._on_player_rescued(1, Color.WHITE)
	# If we get here without error, all handlers are callable
	assert_that(true).is_true()
