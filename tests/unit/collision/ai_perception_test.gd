# ai_perception_test.gd — Unit tests for collision-005 AI Perception System
# GdUnit4 test file
# Tests: AC-CR4-01, AC-CR4-02, AC-CR4-03, AC-CR4-07, F3-01, F3-02

class_name AIPerceptionTest
extends GdUnitTestSuite

# ─── Detection Radius Formula Tests ─────────────────────────────────────────────

func test_detection_radius_idle_no_occlusion() -> void:
	# AC-F3-01: base_radius=256px, IDLE, no occlusion → 192px
	# Formula: 256 * 0.75 * 1.0 = 192
	var result := CollisionManager.calculate_detection_radius("IDLE", 1.0)
	assert_that(result).is_equal(192.0)


func test_detection_radius_chasing_no_occlusion() -> void:
	# AC-F3-02: base_radius=256px, CHASING, no occlusion → 512px
	# Formula: 256 * 2.0 * 1.0 = 512
	var result := CollisionManager.calculate_detection_radius("CHASING", 1.0)
	assert_that(result).is_equal(512.0)


func test_detection_radius_alerted_with_occlusion() -> void:
	# AC-CR4-07: ALERTED with occlusion → los_modifier=0.5
	# Formula: 256 * 1.5 * 0.5 = 192
	var result := CollisionManager.calculate_detection_radius("ALERTED", 0.5)
	assert_that(result).is_equal(192.0)


func test_detection_radius_patrol() -> void:
	# PATROL: 256 * 1.0 * 1.0 = 256
	var result := CollisionManager.calculate_detection_radius("PATROL", 1.0)
	assert_that(result).is_equal(256.0)


# ─── Inner/Outer Radius Tests ──────────────────────────────────────────────────

func test_inner_radius_calculation() -> void:
	# Inner radius = detection_radius * 0.8
	# IDLE: 192 * 0.8 = 153.6
	var inner := CollisionManager.get_inner_radius("IDLE", 1.0)
	assert_that(inner).is_equal(153.6)


func test_outer_radius_calculation() -> void:
	# Outer radius = detection_radius * 1.2
	# IDLE: 192 * 1.2 = 230.4
	var outer := CollisionManager.get_outer_radius("IDLE", 1.0)
	assert_that(outer).is_equal(230.4)


# ─── Constants Verification ─────────────────────────────────────────────────────

func test_base_detection_radius_constant() -> void:
	assert_that(CollisionManager.BASE_DETECTION_RADIUS).is_equal(256.0)


func test_alertness_multipliers() -> void:
	assert_that(CollisionManager.ALERTNESS_MULTIPLIER["IDLE"]).is_equal(0.75)
	assert_that(CollisionManager.ALERTNESS_MULTIPLIER["PATROL"]).is_equal(1.0)
	assert_that(CollisionManager.ALERTNESS_MULTIPLIER["ALERTED"]).is_equal(1.5)
	assert_that(CollisionManager.ALERTNESS_MULTIPLIER["CHASING"]).is_equal(2.0)


func test_hysteresis_thresholds() -> void:
	assert_that(CollisionManager.INNER_THRESHOLD).is_equal(0.8)
	assert_that(CollisionManager.OUTER_THRESHOLD).is_equal(1.2)


func test_debounce_time() -> void:
	assert_that(CollisionManager.DETECTION_DEBOUNCE_TIME).is_equal(0.2)


# ─── Edge Cases ───────────────────────────────────────────────────────────────

func test_unknown_boss_state_uses_default() -> void:
	# Unknown state defaults to 1.0 multiplier
	var result := CollisionManager.calculate_detection_radius("UNKNOWN_STATE", 1.0)
	assert_that(result).is_equal(256.0)


func test_zero_los_modifier() -> void:
	# Zero LOS modifier = no detection
	var result := CollisionManager.calculate_detection_radius("IDLE", 0.0)
	assert_that(result).is_equal(0.0)


func test_max_los_modifier() -> void:
	# Max LOS modifier = full detection range
	var result := CollisionManager.calculate_detection_radius("CHASING", 1.0)
	assert_that(result).is_equal(512.0)
