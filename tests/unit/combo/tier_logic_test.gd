# TierLogic Unit Test Suite
# GdUnit4 test file for Story: combo/story-001-combo-data-foundation.md
# Tests TierLogic.calculate_tier() — 5-tier combo system
# AC-13 through AC-17 + boundary tests
class_name TierLogicTest
extends GdUnitTestSuite

# AC-17: combo_count=0 → tier=0 (IDLE)
func test_tier_at_zero_combo() -> void:
	assert_that(TierLogic.calculate_tier(0)).is_equal(0)

# AC-13: combo_count=8 → tier=1 (Normal)
func test_tier_at_8_combo() -> void:
	assert_that(TierLogic.calculate_tier(8)).is_equal(1)

# AC-14: combo_count=15 → tier=2 (Rising)
func test_tier_at_15_combo() -> void:
	assert_that(TierLogic.calculate_tier(15)).is_equal(2)

# AC-15: combo_count=25 → tier=3 (Intense)
func test_tier_at_25_combo() -> void:
	assert_that(TierLogic.calculate_tier(25)).is_equal(3)

# AC-16: combo_count=45 → tier=4 (Overdrive)
func test_tier_at_45_combo() -> void:
	assert_that(TierLogic.calculate_tier(45)).is_equal(4)

# Boundary: combo_count=1 → tier=1 (Normal, lower bound)
func test_tier_at_1_combo() -> void:
	assert_that(TierLogic.calculate_tier(1)).is_equal(1)

# Boundary: combo_count=9 → tier=1 (Normal, upper bound)
func test_tier_at_9_combo() -> void:
	assert_that(TierLogic.calculate_tier(9)).is_equal(1)

# Boundary: combo_count=10 → tier=2 (Rising, lower bound)
func test_tier_at_10_combo() -> void:
	assert_that(TierLogic.calculate_tier(10)).is_equal(2)

# Boundary: combo_count=19 → tier=2 (Rising, upper bound)
func test_tier_at_19_combo() -> void:
	assert_that(TierLogic.calculate_tier(19)).is_equal(2)

# Boundary: combo_count=20 → tier=3 (Intense, lower bound)
func test_tier_at_20_combo() -> void:
	assert_that(TierLogic.calculate_tier(20)).is_equal(3)

# Boundary: combo_count=39 → tier=3 (Intense, upper bound)
func test_tier_at_39_combo() -> void:
	assert_that(TierLogic.calculate_tier(39)).is_equal(3)

# Boundary: combo_count=40 → tier=4 (Overdrive, lower bound)
func test_tier_at_40_combo() -> void:
	assert_that(TierLogic.calculate_tier(40)).is_equal(4)

# Large combo: combo_count=999 → tier=4 (Overdrive cap)
func test_tier_at_large_combo() -> void:
	assert_that(TierLogic.calculate_tier(999)).is_equal(4)
