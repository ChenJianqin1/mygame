# hit_vfx_test.gd — Unit tests for particle-vfx-002 hit VFX emitter
# GdUnit4 test file
# Tests: AC-VFX-2.1 through AC-VFX-2.10

class_name HitVFXTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _vfx: VFXManager

func before() -> void:
	_vfx = VFXManager.new()

func after() -> void:
	if is_instance_valid(_vfx):
		_vfx.free()


# ─── AC-VFX-2.2: LIGHT particle count 5-8 ─────────────────────────────────────

func test_light_hit_particle_count_range() -> void:
	# LIGHT: 5-8 (randi() % 4 + 5)
	for i in range(20):
		var count := _vfx._get_particle_count("light")
		assert_that(count).is_between(5, 8)


# ─── AC-VFX-2.3: MEDIUM particle count 10-15 ─────────────────────────────────

func test_medium_hit_particle_count_range() -> void:
	# MEDIUM: 10-15 (randi() % 6 + 10)
	for i in range(20):
		var count := _vfx._get_particle_count("medium")
		assert_that(count).is_between(10, 15)


# ─── AC-VFX-2.4: HEAVY particle count 18-25 ──────────────────────────────────

func test_heavy_hit_particle_count_range() -> void:
	# HEAVY: 18-25 (randi() % 8 + 18)
	for i in range(20):
		var count := _vfx._get_particle_count("heavy")
		assert_that(count).is_between(18, 25)


# ─── AC-VFX-2.5: SPECIAL particle count 30-40 ───────────────────────────────

func test_special_hit_particle_count_range() -> void:
	# SPECIAL: 30-40 (randi() % 11 + 30)
	for i in range(20):
		var count := _vfx._get_particle_count("special")
		assert_that(count).is_between(30, 40)


# ─── AC-VFX-2.7: Combo tier 3 multiplier (1.5x + gold sparks) ────────────────

func test_combo_tier3_multiplier() -> void:
	# Tier 3: 1.5x multiplier, gold sparks floor(base * 0.10)
	var base := 10
	var tier := 3
	var result := _vfx._apply_combo_multiplier(base, tier, 3)  # p1
	# Gold sparks: floor(10 * 0.10) = 1
	assert_that(result.count).is_equal(15)  # 10 * 1.5 = 15
	assert_that(result.gold_sparks).is_equal(1)


func test_combo_tier2_multiplier() -> void:
	# Tier 2: 1.2x, no gold sparks
	var base := 10
	var tier := 2
	var result := _vfx._apply_combo_multiplier(base, tier, 1)  # p1
	assert_that(result.count).is_equal(12)  # 10 * 1.2 = 12
	assert_that(result.gold_sparks).is_equal(0)
	assert_that(result.confetti).is_equal(0)


# ─── AC-VFX-2.8: Combo tier 4 multiplier (2.0x + confetti +30) ─────────────

func test_combo_tier4_confetti() -> void:
	# Tier 4: 2.0x multiplier, +30 confetti
	var base := 10
	var tier := 4
	var result := _vfx._apply_combo_multiplier(base, tier, 1)
	assert_that(result.count).is_equal(20)  # 10 * 2.0 = 20
	assert_that(result.confetti).is_equal(30)
	assert_that(result.gold_sparks).is_positive()


# ─── Gold sparks calculation ───────────────────────────────────────────────────

func test_gold_sparks_floor_base_point_one() -> void:
	# Gold sparks = floor(base * 0.10)
	assert_that(_vfx._calc_gold_sparks(20)).is_equal(2)
	assert_that(_vfx._calc_gold_sparks(15)).is_equal(1)
	assert_that(_vfx._calc_gold_sparks(5)).is_equal(0)  # floor(0.5) = 0


# ─── AC-VFX-2.9: Particles use explosiveness=0.8, lifetime_randomness=0.3 ─────

func test_explosiveness_constant_is_0_8() -> void:
	assert_that(VFXManager.EXPLOSIVENESS).is_equal(0.8)


func test_lifetime_randomness_constant_is_0_3() -> void:
	assert_that(VFXManager.LIFETIME_RANDOMNESS).is_equal(0.3)


# ─── AC-VFX-2.9: Spread by attack type ───────────────────────────────────────

func test_light_has_full_spread() -> void:
	# LIGHT/MEDIUM: 180° spread (full 360° radial)
	assert_that(_vfx._get_spread("light")).is_equal(180.0)


func test_medium_has_full_spread() -> void:
	assert_that(_vfx._get_spread("medium")).is_equal(180.0)


func test_heavy_has_narrow_spread() -> void:
	# HEAVY/SPECIAL: 60° spread (120° cone)
	assert_that(_vfx._get_spread("heavy")).is_equal(60.0)


func test_special_has_narrow_spread() -> void:
	assert_that(_vfx._get_spread("special")).is_equal(60.0)


# ─── AC-VFX-2.9: Gravity by attack type ─────────────────────────────────────

func test_light_gravity_higher() -> void:
	# LIGHT/MEDIUM: 400 px/s²
	var grav := _vfx._get_gravity("light")
	assert_that(grav.y).is_equal(400.0)


func test_medium_gravity_higher() -> void:
	var grav := _vfx._get_gravity("medium")
	assert_that(grav.y).is_equal(400.0)


func test_heavy_gravity_lower() -> void:
	# HEAVY/SPECIAL: 200 px/s²
	var grav := _vfx._get_gravity("heavy")
	assert_that(grav.y).is_equal(200.0)


func test_special_gravity_lower() -> void:
	var grav := _vfx._get_gravity("special")
	assert_that(grav.y).is_equal(200.0)


# ─── Speed ranges ────────────────────────────────────────────────────────────

func test_light_speed_range() -> void:
	var speed := _vfx._get_speed("light")
	assert_that(speed.min).is_between(180, 250)
	assert_that(speed.max).is_between(180, 250)


func test_heavy_speed_range() -> void:
	var speed := _vfx._get_speed("heavy")
	assert_that(speed.min).is_between(150, 200)
	assert_that(speed.max).is_between(150, 200)


# ─── Player color constants ──────────────────────────────────────────────────

func test_color_p1_is_orange() -> void:
	assert_that(VFXManager.COLOR_P1).is_equal(Color("#F5A623"))


func test_color_p2_is_teal() -> void:
	assert_that(VFXManager.COLOR_P2).is_equal(Color("#4ECDC4"))


func test_color_gold_is_gold() -> void:
	assert_that(VFXManager.COLOR_GOLD).is_equal(Color("#FFD700"))


# ─── Combo tier multiplier map exists ────────────────────────────────────────

func test_tier_multiplier_tier1() -> void:
	assert_that(VFXManager.TIER_MULTIPLIERS[1]).is_equal(1.0)


func test_tier_multiplier_tier2() -> void:
	assert_that(VFXManager.TIER_MULTIPLIERS[2]).is_equal(1.2)


func test_tier_multiplier_tier3() -> void:
	assert_that(VFXManager.TIER_MULTIPLIERS[3]).is_equal(1.5)


func test_tier_multiplier_tier4() -> void:
	assert_that(VFXManager.TIER_MULTIPLIERS[4]).is_equal(2.0)


# ─── Unknown attack type fallback ─────────────────────────────────────────────

func test_unknown_attack_type_defaults_to_light() -> void:
	var count := _vfx._get_particle_count("unknown")
	assert_that(count).is_between(5, 8)
