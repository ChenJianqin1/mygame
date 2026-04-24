# ComboData Unit Test Suite
# GdUnit4 test file for Story: combo/story-001-combo-data-foundation.md
# Tests ComboData — per-player combo state container
class_name ComboDataTest
extends GdUnitTestSuite

# Test: Two ComboData instances have independent state
func test_independent_state_per_player() -> void:
	var p1 := ComboData.new(1)
	var p2 := ComboData.new(2)
	p1.register_hit(100)
	assert_that(p1.combo_count).is_equal(1)
	assert_that(p2.combo_count).is_equal(0)

# Test: reset() clears all fields to initial values
func test_reset_clears_all_fields() -> void:
	var combo := ComboData.new(1)
	combo.register_hit(1)
	combo.register_hit(2)
	combo.register_sync_hit()
	combo.reset()
	assert_that(combo.combo_count).is_equal(0)
	assert_that(combo.combo_timer).is_equal(0.0)
	assert_that(combo.current_tier).is_equal(0)
	assert_that(combo.sync_chain_length).is_equal(0)
	assert_that(combo.last_hit_frame).is_equal(-1)

# Test: register_hit increments combo_count and updates tier
func test_register_hit_updates_count_and_tier() -> void:
	var combo := ComboData.new(1)
	combo.register_hit(10)
	assert_that(combo.combo_count).is_equal(1)
	assert_that(combo.current_tier).is_equal(1)
	assert_that(combo.last_hit_frame).is_equal(10)

# Test: register_hit with tier escalation
func test_register_hit_tier_escalation() -> void:
	var combo := ComboData.new(1)
	# 8 hits → tier 1 (NORMAL)
	for i in 8:
		combo.register_hit(i)
	assert_that(combo.current_tier).is_equal(1)
	# 10th hit → tier 2 (RISING)
	combo.register_hit(10)
	assert_that(combo.current_tier).is_equal(2)

# Test: register_sync_hit increments sync_chain_length
func test_register_sync_hit_increments_chain() -> void:
	var combo := ComboData.new(1)
	combo.register_sync_hit()
	combo.register_sync_hit()
	assert_that(combo.sync_chain_length).is_equal(2)

# Test: update() increments combo_timer
func test_update_increments_timer() -> void:
	var combo := ComboData.new(1)
	combo.register_hit(1)
	combo.update(0.5)
	combo.update(0.25)
	assert_that(combo.combo_timer).is_equal(0.75)

# Test: is_empty() returns true when no hits
func test_is_empty_true_when_no_hits() -> void:
	var combo := ComboData.new(1)
	assert_that(combo.is_empty()).is_true()

# Test: is_empty() returns false after a hit
func test_is_empty_false_after_hit() -> void:
	var combo := ComboData.new(1)
	combo.register_hit(1)
	assert_that(combo.is_empty()).is_false()
