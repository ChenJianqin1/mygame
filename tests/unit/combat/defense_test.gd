# defense_test.gd — Unit tests for combat-004 defense system
# GdUnit4 test file
# Tests: damage reduction formula, minimum 1 damage floor, max defense cap

class_name DefenseTest
extends GdUnitTestSuite

# AC-DEF-001: final_damage=50, defense=0.0 → incoming = 50
func test_defense_no_rating() -> void:
	var cm := CombatManager.new()
	var incoming: int = cm.calculate_incoming_damage(50, 0.0)
	assert_that(incoming).is_equal(50)
	cm.free()


# AC-DEF-003 / AC-EDGE-001: final_damage=6, defense=0.8 → incoming = 1 (minimum floor)
func test_defense_minimum_1_damage() -> void:
	var cm := CombatManager.new()
	var incoming: int = cm.calculate_incoming_damage(6, 0.8)
	# 6 * (1.0 - 0.8) = 6 * 0.2 = 1.2 → floor = 1
	assert_that(incoming).is_equal(1)
	cm.free()


# 50% defense reduction
func test_defense_50_percent() -> void:
	var cm := CombatManager.new()
	var incoming: int = cm.calculate_incoming_damage(20, 0.5)
	# 20 * 0.5 = 10
	assert_that(incoming).is_equal(10)
	cm.free()


# AC-DEF-003: final_damage=50, defense=0.8 → incoming = 10 (not floored to 0)
func test_defense_max_rating() -> void:
	var cm := CombatManager.new()
	var incoming: int = cm.calculate_incoming_damage(50, 0.8)
	# 50 * 0.2 = 10
	assert_that(incoming).is_equal(10)
	cm.free()


# Zero damage stays zero (edge case)
func test_zero_damage_passes_through() -> void:
	var cm := CombatManager.new()
	var incoming: int = cm.calculate_incoming_damage(0, 0.8)
	assert_that(incoming).is_equal(0)
	cm.free()


# Defense rating above max is capped
func test_defense_rating_capped_at_max() -> void:
	var cm := CombatManager.new()
	# 0.9 should be treated as 0.8
	var incoming: int = cm.calculate_incoming_damage(50, 0.9)
	# With cap: 50 * (1.0 - 0.8) = 10
	assert_that(incoming).is_equal(10)
	cm.free()


# Additional coverage
func test_defense_partial_30_percent() -> void:
	var cm := CombatManager.new()
	var incoming: int = cm.calculate_incoming_damage(100, 0.3)
	# 100 * 0.7 = 70
	assert_that(incoming).is_equal(70)
	cm.free()


func test_defense_constants() -> void:
	assert_that(CombatManager.MAX_DEFENSE_RATING).is_equal(0.8)
