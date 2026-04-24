# Combo system formula tests
# GdUnit4 test file
# Validates combo damage multiplier and decay formulas from design/gdd/combo-system.md

class_name ComboFormulaTest
extends GdUnitTestSuite

# Test: combo multiplier scales correctly with hit count
func test_combo_multiplier_at_strike_3() -> void:
	# Formula: multiplier = 1.0 + (hit_count - 1) * 0.25
	# At hit 3: multiplier = 1.0 + (3-1) * 0.25 = 1.5
	var hit_count := 3
	var expected_multiplier := 1.5
	var actual_multiplier := 1.0 + (hit_count - 1) * 0.25
	assert_that(actual_multiplier).is_equal(expected_multiplier)

# Test: combo multiplier at max hits (10)
func test_combo_multiplier_at_max_hits() -> void:
	# At hit 10: multiplier = 1.0 + (10-1) * 0.25 = 3.25
	var hit_count := 10
	var expected_multiplier := 3.25
	var actual_multiplier := 1.0 + (hit_count - 1) * 0.25
	assert_that(actual_multiplier).is_equal(expected_multiplier)

# Test: combo decay timer calculation
func test_decay_timer_at_strike_5() -> void:
	# Formula: decay_timer = max(0.3, 2.0 - (combo_count - 1) * 0.2)
	# At hit 5: decay = 2.0 - (5-1) * 0.2 = 2.0 - 0.8 = 1.2
	var combo_count := 5
	var expected_decay := 1.2
	var actual_decay := maxf(0.3, 2.0 - (combo_count - 1) * 0.2)
	assert_that(actual_decay).is_equal(expected_decay)

# Test: combo decay never goes below 0.3s
func test_decay_timer_floor_at_high_combo() -> void:
	# At hit 20: decay = 2.0 - 19 * 0.2 = 2.0 - 3.8 = -1.8 → clamped to 0.3
	var combo_count := 20
	var expected_decay := 0.3
	var actual_decay := maxf(0.3, 2.0 - (combo_count - 1) * 0.2)
	assert_that(actual_decay).is_equal(expected_decay)
