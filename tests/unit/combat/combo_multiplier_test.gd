# combo_multiplier_test.gd — Unit tests for combo-002 combo multiplier formulas
# GdUnit4 test file
# Tests solo and sync combo multipliers per story-002 acceptance criteria

class_name ComboMultiplierTest
extends GdUnitTestSuite

# ===== HELPER =====

func get_combat_manager() -> CombatManager:
	return CombatManager.new()


# ===== AC-22: combo_count=0 → multiplier=1.0 =====

func test_multiplier_at_zero_combo() -> void:
	# Given: combo_count=0 (solo)
	# When: get_combo_multiplier is called
	# Then: result = 1.0
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(0)
	assert_that(result).is_equal(1.0)


# ===== AC-04: combo_count=20 (solo) → 2.0 =====

func test_multiplier_solo_at_20() -> void:
	# Given: combo_count=20 (solo)
	# When: get_combo_multiplier is called
	# Then: result = min(1.0 + 20*0.05, 3.0) = 2.0
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(20, false)
	assert_that(result).is_equal(2.0)


# ===== AC-05: combo_count=40 (solo) → 3.0 (cap) =====

func test_multiplier_solo_at_40_caps() -> void:
	# Given: combo_count=40 (solo)
	# When: get_combo_multiplier is called
	# Then: result = min(1.0 + 40*0.05, 3.0) = 3.0 (cap)
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(40, false)
	assert_that(result).is_equal(3.0)


# ===== AC-06: combo_count=40 (sync) → 3.0 =====

func test_multiplier_sync_at_40() -> void:
	# Given: combo_count=40 (sync)
	# When: get_combo_multiplier is called with is_sync=true
	# Then: result = min(1.0 + 40*0.05, 4.0) = 3.0
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(40, true)
	assert_that(result).is_equal(3.0)


# ===== AC-07: combo_count=50 (sync) → 3.5 =====

func test_multiplier_sync_at_50() -> void:
	# Given: combo_count=50 (sync)
	# When: get_combo_multiplier is called with is_sync=true
	# Then: result = min(1.0 + 50*0.05, 4.0) = 3.5
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(50, true)
	assert_that(result).is_equal(3.5)


# ===== AC-08: combo_count=60 (sync) → 4.0 (cap) =====

func test_multiplier_sync_at_60_caps() -> void:
	# Given: combo_count=60 (sync)
	# When: get_combo_multiplier is called with is_sync=true
	# Then: result = min(1.0 + 60*0.05, 4.0) = 4.0 (cap)
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(60, true)
	assert_that(result).is_equal(4.0)


# ===== Additional boundary tests =====

func test_multiplier_sync_at_99_caps() -> void:
	# Given: combo_count=99 (sync)
	# When: get_combo_multiplier is called with is_sync=true
	# Then: result = min(1.0 + 99*0.05, 4.0) = 4.0 (cap)
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(99, true)
	assert_that(result).is_equal(4.0)


func test_multiplier_solo_at_60_still_capped_at_3() -> void:
	# Given: combo_count=60 (solo)
	# When: get_combo_multiplier is called with is_sync=false
	# Then: result = min(1.0 + 60*0.05, 3.0) = 3.0 (solo cap, not 4.0)
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(60, false)
	assert_that(result).is_equal(3.0)


func test_multiplier_sync_at_20_equals_solo() -> void:
	# Given: combo_count=20 (both solo and sync)
	# When: get_combo_multiplier is called
	# Then: both produce 2.0 (below cap threshold)
	var cm := get_combat_manager()
	var solo: float = cm.get_combo_multiplier(20, false)
	var sync: float = cm.get_combo_multiplier(20, true)
	assert_that(solo).is_equal(2.0)
	assert_that(sync).is_equal(2.0)


func test_multiplier_sync_at_1() -> void:
	# Given: combo_count=1 (sync, lower bound)
	# When: get_combo_multiplier is called with is_sync=true
	# Then: result = min(1.0 + 1*0.05, 4.0) = 1.05
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(1, true)
	assert_that(result).is_equal(1.05)
