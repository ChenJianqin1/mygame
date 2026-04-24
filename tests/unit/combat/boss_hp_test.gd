# boss_hp_test.gd — Unit tests for combat-006 boss HP formula
# GdUnit4 test file
# Tests: AC-BHP-001, AC-BHP-010, edge cases

class_name BossHPTest
extends GdUnitTestSuite

# ─── AC-BHP-001: Boss 1 solo ─────────────────────────────────────────────────

func test_boss_hp_boss1_solo() -> void:
	# AC-BHP-001: boss_index=1, is_coop=false, progression=1.0
	# Expected: floor(500 × 1.0 × 1.0 × 1.0) = 500
	var result := CombatManager.calculate_boss_hp(1, false, 1.0)
	assert_that(result).is_equal(500)


# ─── AC-BHP-002: Boss 1 co-op ───────────────────────────────────────────────

func test_boss_hp_boss1_coop() -> void:
	# Expected: floor(500 × 1.0 × 1.0 × 1.5) = 750
	var result := CombatManager.calculate_boss_hp(1, true, 1.0)
	assert_that(result).is_equal(750)


# ─── AC-BHP-003: Boss 4 solo ───────────────────────────────────────────────

func test_boss_hp_boss4_solo() -> void:
	# boss_index=4 → BOSS_INDEX_MULTIPLIER[4] = 2.0
	# Expected: floor(500 × 1.0 × 2.0 × 1.0) = 1000
	var result := CombatManager.calculate_boss_hp(4, false, 1.0)
	assert_that(result).is_equal(1000)


# ─── AC-BHP-010: Boss 3 co-op with progression ──────────────────────────────

func test_boss_hp_boss3_coop_progression() -> void:
	# AC-BHP-010: boss_index=3, is_coop=true, progression=1.5
	# BOSS_INDEX_MULTIPLIER[3] = 1.6
	# Expected: floor(500 × 1.5 × 1.6 × 1.5) = floor(1800.0) = 1800
	var result := CombatManager.calculate_boss_hp(3, true, 1.5)
	assert_that(result).is_equal(1800)


# ─── AC-BHP-011: Max scaling ────────────────────────────────────────────────

func test_boss_hp_max_scaling() -> void:
	# boss_index=4, is_coop=true, progression=2.5
	# Expected: floor(500 × 2.5 × 2.0 × 1.5) = floor(3750.0) = 3750
	var result := CombatManager.calculate_boss_hp(4, true, 2.5)
	assert_that(result).is_equal(3750)


# ─── Edge cases ─────────────────────────────────────────────────────────────

func test_boss_hp_default_progression() -> void:
	# When progression not specified, defaults to 1.0
	var result := CombatManager.calculate_boss_hp(1, false)
	assert_that(result).is_equal(500)


func test_boss_hp_invalid_index_uses_default() -> void:
	# boss_index out of bounds → uses 1.0 multiplier
	var result := CombatManager.calculate_boss_hp(99, false, 1.0)
	assert_that(result).is_equal(500)


func test_boss_hp_boss2_solo() -> void:
	# boss_index=2 → BOSS_INDEX_MULTIPLIER[2] = 1.3
	# Expected: floor(500 × 1.0 × 1.3 × 1.0) = 650
	var result := CombatManager.calculate_boss_hp(2, false, 1.0)
	assert_that(result).is_equal(650)
