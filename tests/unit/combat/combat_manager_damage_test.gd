# combat_manager_damage_test.gd — Unit tests for CombatManager damage formula
# GdUnit4 test file
# Validates TR-combat-002 (damage formula: base × attack_type × combo_multiplier)

class_name CombatManagerDamageTest
extends GdUnitTestSuite

# ===== HELPER =====

func get_combat_manager() -> CombatManager:
	# Return existing instance or create new one for testing
	return CombatManager.new()


# ===== AC-DMG-001: LIGHT attack, no combo =====

func test_damage_LIGHT_no_combo() -> void:
	# Given: base=15, attack_type=LIGHT, combo=0
	# When: calculate_damage is called
	# Then: final_damage = 15 * 0.8 = 12
	var cm := get_combat_manager()
	var result: int = cm.calculate_damage(15, "LIGHT", 0)
	assert_that(result).is_equal(12)


# ===== AC-DMG-003: HEAVY attack, no combo =====

func test_damage_HEAVY_no_combo() -> void:
	# Given: base=15, attack_type=HEAVY, combo=0
	# When: calculate_damage is called
	# Then: final_damage = 15 * 1.5 = 23
	var cm := get_combat_manager()
	var result: int = cm.calculate_damage(15, "HEAVY", 0)
	assert_that(result).is_equal(23)


# ===== AC-DMG-010: combo_count=0 → combo_multiplier=1.0 =====

func test_combo_multiplier_zero() -> void:
	# Given: combo_count=0
	# When: get_combo_multiplier is called
	# Then: result = 1.0
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(0)
	assert_that(result).is_equal(1.0)


# ===== AC-DMG-012: combo_count=40 → combo_multiplier=3.0 (cap) =====

func test_combo_multiplier_40() -> void:
	# Given: combo_count=40
	# When: get_combo_multiplier is called
	# Then: result = 3.0 (capped at MAX_COMBO_MULTIPLIER)
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(40)
	assert_that(result).is_equal(3.0)


# ===== AC-DMG-020: HEAVY attack + combo 10 =====

func test_damage_HEAVY_combo_10() -> void:
	# Given: base=15, attack_type=HEAVY, combo=10
	# When: calculate_damage is called
	# Then: final_damage = 15 * 1.5 * 1.5 = 34
	var cm := get_combat_manager()
	var result: int = cm.calculate_damage(15, "HEAVY", 10)
	assert_that(result).is_equal(34)


# ===== AC-EDGE-003: combo_count=100 → combo_multiplier=3.0 (locked) =====

func test_combo_multiplier_100() -> void:
	# Given: combo_count=100
	# When: get_combo_multiplier is called
	# Then: result = 3.0 (locked at cap)
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(100)
	assert_that(result).is_equal(3.0)


# ===== Additional coverage tests =====

func test_damage_MEDIUM_no_combo() -> void:
	# Given: base=15, attack_type=MEDIUM, combo=0
	# When: calculate_damage is called
	# Then: final_damage = 15 * 1.0 = 15
	var cm := get_combat_manager()
	var result: int = cm.calculate_damage(15, "MEDIUM", 0)
	assert_that(result).is_equal(15)


func test_damage_SPECIAL_no_combo() -> void:
	# Given: base=15, attack_type=SPECIAL, combo=0
	# When: calculate_damage is called
	# Then: final_damage = 15 * 2.0 = 30
	var cm := get_combat_manager()
	var result: int = cm.calculate_damage(15, "SPECIAL", 0)
	assert_that(result).is_equal(30)


func test_combo_multiplier_20() -> void:
	# Given: combo_count=20
	# When: get_combo_multiplier is called
	# Then: result = 1.0 + 20*0.05 = 2.0
	var cm := get_combat_manager()
	var result: float = cm.get_combo_multiplier(20)
	assert_that(result).is_equal(2.0)


func test_damage_SPECIAL_high_combo() -> void:
	# Given: base=15, attack_type=SPECIAL, combo=20
	# When: calculate_damage is called
	# Then: combo_multiplier = min(1.0 + 20*0.05, 3.0) = 2.0
	#       final_damage = 15 * 2.0 * 2.0 = 60
	var cm := get_combat_manager()
	var result: int = cm.calculate_damage(15, "SPECIAL", 20)
	assert_that(result).is_equal(60)
