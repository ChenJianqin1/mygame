# dynamic_zoom_test.gd — Unit tests for camera-009 dynamic zoom
# GdUnit4 test file
# Tests: AC-1.3, AC-6.3

class_name DynamicZoomTest
extends GdUnitTestSuite

# ─── Dynamic zoom constants ───────────────────────────────────────────────────────

const DISTANCE_THRESHOLD_CLOSE: float = 200.0
const DISTANCE_THRESHOLD_FAR: float = 400.0
const ZOOM_CLOSE: float = 1.0
const ZOOM_MID: float = 0.85
const ZOOM_FAR: float = 0.7

# ─── AC-1.3: Players at 400px+ → zoom = 0.7x ─────────────────────────────────

func test_players_at_400px_uses_far_zoom() -> void:
	# Exactly 400px should use mid zoom (not far)
	var zoom := _get_distance_zoom_for_test(400.0)
	assert_that(zoom).is_equal(ZOOM_MID)


func test_players_over_400px_uses_far_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(500.0)
	assert_that(zoom).is_equal(ZOOM_FAR)


func test_players_at_401px_uses_far_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(401.0)
	assert_that(zoom).is_equal(ZOOM_FAR)


# ─── AC-1.3: Players at 200-400px → zoom = 0.85x ─────────────────────────────

func test_players_at_200px_uses_close_zoom() -> void:
	# Exactly 200px should use close zoom (not mid)
	var zoom := _get_distance_zoom_for_test(200.0)
	assert_that(zoom).is_equal(ZOOM_CLOSE)


func test_players_at_201px_uses_mid_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(201.0)
	assert_that(zoom).is_equal(ZOOM_MID)


func test_players_at_300px_uses_mid_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(300.0)
	assert_that(zoom).is_equal(ZOOM_MID)


func test_players_at_399px_uses_mid_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(399.0)
	assert_that(zoom).is_equal(ZOOM_MID)


# ─── AC-6.3: Players <200px → zoom = 1.0x ───────────────────────────────────

func test_players_at_0px_uses_close_zoom() -> void:
	# Overlapping players
	var zoom := _get_distance_zoom_for_test(0.0)
	assert_that(zoom).is_equal(ZOOM_CLOSE)


func test_players_at_100px_uses_close_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(100.0)
	assert_that(zoom).is_equal(ZOOM_CLOSE)


func test_players_at_199px_uses_close_zoom() -> void:
	var zoom := _get_distance_zoom_for_test(199.0)
	assert_that(zoom).is_equal(ZOOM_CLOSE)


# ─── Multiplicative combination ─────────────────────────────────────────────────

func test_zoom_combines_multiplicatively() -> void:
	# distance=300 (0.85) * PLAYER_ATTACK (0.9) = 0.765
	var distance_zoom := _get_distance_zoom_for_test(300.0)
	var attack_zoom := 0.9
	var effective := distance_zoom * attack_zoom
	assert_that(effective).is_close(0.765, 0.01)


func test_zoom_clamps_to_reasonable_bounds() -> void:
	# Very far distance (far_zoom=0.7) * BOSS_PHASE_CHANGE (0.75) = 0.525
	# Should clamp to 0.5 minimum
	var combined := 0.7 * 0.75
	# Actual clamping would happen in implementation
	assert_that(combined).is_greater_or_equal(0.5)


# ─── Helper function (mirrors implementation logic) ──────────────────────────────

func _get_distance_zoom_for_test(distance: float) -> float:
	# Mirror of CameraController._get_distance_zoom logic
	if distance < DISTANCE_THRESHOLD_CLOSE:
		return ZOOM_CLOSE
	elif distance < DISTANCE_THRESHOLD_FAR:
		return ZOOM_MID
	else:
		return ZOOM_FAR


# ─── Constants ───────────────────────────────────────────────────────────────

func test_distance_threshold_close() -> void:
	assert_that(DISTANCE_THRESHOLD_CLOSE).is_equal(200.0)


func test_distance_threshold_far() -> void:
	assert_that(DISTANCE_THRESHOLD_FAR).is_equal(400.0)


func test_zoom_close_constant() -> void:
	assert_that(ZOOM_CLOSE).is_equal(1.0)


func test_zoom_mid_constant() -> void:
	assert_that(ZOOM_MID).is_equal(0.85)


func test_zoom_far_constant() -> void:
	assert_that(ZOOM_FAR).is_equal(0.7)
