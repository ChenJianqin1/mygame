# combo_counter_test.gd — Unit tests for ui-004 combo counter tier logic
# GdUnit4 test file
# Tests: AC1 through AC8

class_name ComboCounterTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _counter: ComboCounter

func before() -> void:
	_counter = ComboCounter.new()
	add_child(_counter)

func after() -> void:
	if is_instance_valid(_counter):
		_counter.free()


# ─── AC1 / AC2: Tier calculation ───────────────────────────────────────────────

func test_tier_normal_for_combo_0() -> void:
	var tier := ComboCounter.get_tier(0)
	assert_that(tier).is_equal(ComboCounter.Tier.NORMAL)


func test_tier_normal_for_combo_9() -> void:
	var tier := ComboCounter.get_tier(9)
	assert_that(tier).is_equal(ComboCounter.Tier.NORMAL)


func test_tier_fury_at_threshold_10() -> void:
	var tier := ComboCounter.get_tier(10)
	assert_that(tier).is_equal(ComboCounter.Tier.FURY)


func test_tier_fury_for_combo_15() -> void:
	var tier := ComboCounter.get_tier(15)
	assert_that(tier).is_equal(ComboCounter.Tier.FURY)


func test_tier_fury_for_combo_24() -> void:
	var tier := ComboCounter.get_tier(24)
	assert_that(tier).is_equal(ComboCounter.Tier.FURY)


func test_tier_carnage_at_threshold_25() -> void:
	var tier := ComboCounter.get_tier(25)
	assert_that(tier).is_equal(ComboCounter.Tier.CARNAGE)


func test_tier_carnage_for_combo_30() -> void:
	var tier := ComboCounter.get_tier(30)
	assert_that(tier).is_equal(ComboCounter.Tier.CARNAGE)


func test_tier_carnage_for_combo_49() -> void:
	var tier := ComboCounter.get_tier(49)
	assert_that(tier).is_equal(ComboCounter.Tier.CARNAGE)


func test_tier_bloodshed_at_threshold_50() -> void:
	var tier := ComboCounter.get_tier(50)
	assert_that(tier).is_equal(ComboCounter.Tier.BLOODSHED)


func test_tier_bloodshed_for_combo_100() -> void:
	var tier := ComboCounter.get_tier(100)
	assert_that(tier).is_equal(ComboCounter.Tier.BLOODSHED)


func test_tier_bloodshed_for_max_combo() -> void:
	var tier := ComboCounter.get_tier(999)
	assert_that(tier).is_equal(ComboCounter.Tier.BLOODSHED)


# ─── AC3: Multiplier from tier ─────────────────────────────────────────────────

func test_multiplier_normal() -> void:
	var mult := ComboCounter.get_multiplier(ComboCounter.Tier.NORMAL)
	assert_that(mult).is_equal(1.00)


func test_multiplier_fury() -> void:
	var mult := ComboCounter.get_multiplier(ComboCounter.Tier.FURY)
	assert_that(mult).is_equal(1.15)


func test_multiplier_carnage() -> void:
	var mult := ComboCounter.get_multiplier(ComboCounter.Tier.CARNAGE)
	assert_that(mult).is_equal(1.30)


func test_multiplier_bloodshed() -> void:
	var mult := ComboCounter.get_multiplier(ComboCounter.Tier.BLOODSHED)
	assert_that(mult).is_equal(1.50)


# ─── AC3: Scale from tier ───────────────────────────────────────────────────────

func test_scale_normal() -> void:
	var scale := ComboCounter.get_scale(ComboCounter.Tier.NORMAL)
	assert_that(scale).is_equal(1.0)


func test_scale_fury() -> void:
	var scale := ComboCounter.get_scale(ComboCounter.Tier.FURY)
	assert_that(scale).is_equal(1.1)


func test_scale_carnage() -> void:
	var scale := ComboCounter.get_scale(ComboCounter.Tier.CARNAGE)
	assert_that(scale).is_equal(1.2)


func test_scale_bloodshed() -> void:
	var scale := ComboCounter.get_scale(ComboCounter.Tier.BLOODSHED)
	assert_that(scale).is_equal(1.3)


# ─── AC4: Tier color ───────────────────────────────────────────────────────────

func test_color_normal_is_white() -> void:
	var color := ComboCounter.get_tier_color(ComboCounter.Tier.NORMAL)
	assert_that(color).is_equal(Color.WHITE)


func test_color_fury_is_orange() -> void:
	var color := ComboCounter.get_tier_color(ComboCounter.Tier.FURY)
	assert_that(color).is_equal(Color("#FB923C"))


func test_color_carnage_is_red() -> void:
	var color := ComboCounter.get_tier_color(ComboCounter.Tier.CARNAGE)
	assert_that(color).is_equal(Color("#EF4444"))


func test_color_bloodshed_is_dark_red() -> void:
	var color := ComboCounter.get_tier_color(ComboCounter.Tier.BLOODSHED)
	assert_that(color).is_equal(Color("#991B1B"))


# ─── AC4: Tier name ────────────────────────────────────────────────────────────

func test_tier_name_normal_empty() -> void:
	var name := ComboCounter.get_tier_name(ComboCounter.Tier.NORMAL)
	assert_that(name).is_equal("")


func test_tier_name_fury() -> void:
	var name := ComboCounter.get_tier_name(ComboCounter.Tier.FURY)
	assert_that(name).is_equal("FURY!")


func test_tier_name_carnage() -> void:
	var name := ComboCounter.get_tier_name(ComboCounter.Tier.CARNAGE)
	assert_that(name).is_equal("CARNAGE!")


func test_tier_name_bloodshed() -> void:
	var name := ComboCounter.get_tier_name(ComboCounter.Tier.BLOODSHED)
	assert_that(name).is_equal("BLOODSHED!")


# ─── AC5: Progress within tier ─────────────────────────────────────────────────

func test_progress_at_tier_start() -> void:
	# At combo 10 (FURY start), progress should be 0
	var progress := ComboCounter.get_tier_progress(10, ComboCounter.Tier.FURY)
	assert_that(progress).is_equal(0.0)


func test_progress_mid_fury() -> void:
	# At combo 17, FURY tier (10-25), progress = (17-10)/(25-10) = 7/15 ≈ 0.467
	var progress := ComboCounter.get_tier_progress(17, ComboCounter.Tier.FURY)
	assert_that(progress).is_close(0.467, 0.01)


func test_progress_end_fury() -> void:
	# At combo 24, FURY tier (10-25), progress = (24-10)/(25-10) = 14/15 ≈ 0.933
	var progress := ComboCounter.get_tier_progress(24, ComboCounter.Tier.FURY)
	assert_that(progress).is_close(0.933, 0.01)


func test_progress_carnage_mid() -> void:
	# At combo 35, CARNAGE tier (25-50), progress = (35-25)/(50-25) = 10/25 = 0.4
	var progress := ComboCounter.get_tier_progress(35, ComboCounter.Tier.CARNAGE)
	assert_that(progress).is_equal(0.4)


func test_progress_bloodshed_mid() -> void:
	# At combo 75, BLOODSHED tier (50-999), progress = (75-50)/(999-50) = 25/949 ≈ 0.026
	var progress := ComboCounter.get_tier_progress(75, ComboCounter.Tier.BLOODSHED)
	assert_that(progress).is_close(0.026, 0.01)


func test_progress_normal_is_zero() -> void:
	var progress := ComboCounter.get_tier_progress(5, ComboCounter.Tier.NORMAL)
	assert_that(progress).is_equal(0.0)


# ─── AC7: Counter hidden when combo = 0 ─────────────────────────────────────────

func test_counter_hidden_initially() -> void:
	assert_that(_counter.visible).is_false()


# ─── AC8: Both P1+P2 hits update counter ──────────────────────────────────────

func test_combo_hit_signal_handler_exists() -> void:
	assert_that(_counter.has_method("_on_combo_hit")).is_true()


func test_combo_break_signal_handler_exists() -> void:
	assert_that(_counter.has_method("_on_combo_break")).is_true()


func test_combo_multiplier_updated_handler_exists() -> void:
	assert_that(_counter.has_method("_on_combo_multiplier_updated")).is_true()


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_negative_combo_clamped_to_normal() -> void:
	var tier := ComboCounter.get_tier(-5)
	assert_that(tier).is_equal(ComboCounter.Tier.NORMAL)


func test_tier_enum_values() -> void:
	assert_that(ComboCounter.Tier.NORMAL).is_equal(0)
	assert_that(ComboCounter.Tier.FURY).is_equal(1)
	assert_that(ComboCounter.Tier.CARNAGE).is_equal(2)
	assert_that(ComboCounter.Tier.BLOODSHED).is_equal(3)


func test_tier_thresholds_constants() -> void:
	assert_that(ComboCounter.TIER_FURY_THRESHOLD).is_equal(10)
	assert_that(ComboCounter.TIER_CARNAGE_THRESHOLD).is_equal(25)
	assert_that(ComboCounter.TIER_BLOODSHED_THRESHOLD).is_equal(50)
