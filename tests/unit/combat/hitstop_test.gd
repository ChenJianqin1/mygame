# hitstop_test.gd — Unit tests for combat-003 hitstop system
# GdUnit4 test file
# Tests: base hitstop per attack type, bonus per target type, total calculation

class_name HitstopTest
extends GdUnitTestSuite

# ─── Base hitstop per attack type ─────────────────────────────────────────────

# AC-HS-001: LIGHT → 3 frames
func test_hitstop_LIGHT() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("LIGHT", "PLAYER")
	assert_that(frames).is_equal(3)
	cm.free()


func test_hitstop_MEDIUM() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("MEDIUM", "PLAYER")
	assert_that(frames).is_equal(5)
	cm.free()


func test_hitstop_HEAVY() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("HEAVY", "PLAYER")
	assert_that(frames).is_equal(8)
	cm.free()


# AC-HS-004: SPECIAL → 12 frames
func test_hitstop_SPECIAL() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("SPECIAL", "PLAYER")
	assert_that(frames).is_equal(12)
	cm.free()


# ─── Bonus hitstop per target type ─────────────────────────────────────────────

# AC-HS-010: LIGHT on BOSS → 3 + 2 = 5 frames
func test_hitstop_LIGHT_on_BOSS() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("LIGHT", "BOSS")
	assert_that(frames).is_equal(5)
	cm.free()


func test_hitstop_LIGHT_on_ELITE() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("LIGHT", "ELITE")
	assert_that(frames).is_equal(4)  # 3 + 1
	cm.free()


func test_hitstop_HEAVY_on_BOSS() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("HEAVY", "BOSS")
	assert_that(frames).is_equal(10)  # 8 + 2
	cm.free()


func test_hitstop_SPECIAL_on_BOSS() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("SPECIAL", "BOSS")
	assert_that(frames).is_equal(14)  # 12 + 2
	cm.free()


func test_hitstop_on_PLAYER_zero_bonus() -> void:
	var cm := CombatManager.new()
	# All attack types against PLAYER get 0 bonus
	assert_that(cm.calculate_hitstop("LIGHT", "PLAYER")).is_equal(3)
	assert_that(cm.calculate_hitstop("MEDIUM", "PLAYER")).is_equal(5)
	assert_that(cm.calculate_hitstop("HEAVY", "PLAYER")).is_equal(8)
	assert_that(cm.calculate_hitstop("SPECIAL", "PLAYER")).is_equal(12)
	cm.free()


# ─── Edge cases ───────────────────────────────────────────────────────────────

func test_hitstop_invalid_attack_type_defaults_to_zero() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("INVALID", "PLAYER")
	assert_that(frames).is_equal(0)  # base = 0 for unknown
	cm.free()


func test_hitstop_invalid_target_type_zero_bonus() -> void:
	var cm := CombatManager.new()
	var frames: int = cm.calculate_hitstop("LIGHT", "UNKNOWN")
	assert_that(frames).is_equal(3)  # 3 + 0
	cm.free()


func test_hitstop_constants_match_ac() -> void:
	# Verify constants match acceptance criteria
	assert_that(CombatManager.BASE_HITSTOP["LIGHT"]).is_equal(3)
	assert_that(CombatManager.BASE_HITSTOP["MEDIUM"]).is_equal(5)
	assert_that(CombatManager.BASE_HITSTOP["HEAVY"]).is_equal(8)
	assert_that(CombatManager.BASE_HITSTOP["SPECIAL"]).is_equal(12)
	assert_that(CombatManager.BONUS_HITSTOP["PLAYER"]).is_equal(0)
	assert_that(CombatManager.BONUS_HITSTOP["BOSS"]).is_equal(2)
	assert_that(CombatManager.BONUS_HITSTOP["ELITE"]).is_equal(1)
