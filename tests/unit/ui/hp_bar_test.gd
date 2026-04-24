# hp_bar_test.gd — Unit tests for ui-002 Player HP Bars
# GdUnit4 test file
# Tests: lerp formula (AC6), color thresholds, flash timing, overshoot prevention

class_name HPBarTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _bar: HPBar

func before() -> void:
	_bar = HPBar.new()

func after() -> void:
	if is_instance_valid(_bar):
		_bar.free()


# ─── AC6: Lerp stops exactly at actual HP (no overshoot) ─────────────────────

func test_lerp_converges_to_target_exactly() -> void:
	# Given: HP bar with display=100, target=50
	_bar._display_hp = 100.0
	_bar._target_hp = 50.0
	_bar._lerp_block_ms = 0.0

	# When: update called multiple times until convergence
	for i in range(50):
		_bar._process(0.1)  # 100ms per tick

	# Then: display_hp == target_hp (no overshoot)
	assert_that(_bar._display_hp).is_equal(50.0)


func test_lerp_no_overshoot() -> void:
	# Given: HP bar at 100, target 0
	_bar._display_hp = 100.0
	_bar._target_hp = 0.0
	_bar._lerp_block_ms = 0.0

	# When: Update with large delta
	_bar._process(0.5)  # 500ms

	# Then: display_hp >= 0 (no negative overshoot)
	assert_that(_bar._display_hp).is_greater_or_equal(0.0)
	# And: display_hp <= target_hp
	assert_that(_bar._display_hp).is_less_or_equal(_bar._target_hp)


func test_lerp_speed_constant_8() -> void:
	assert_that(HPBar.HP_LERP_SPEED).is_equal(8.0)


# ─── HP Percentage Color Thresholds ────────────────────────────────────────────

func test_color_healthy_above_60_percent() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 80.0

	assert_that(_bar.get_hp_percent()).is_equal(0.8)
	assert_that(_bar.get_hp_percent() >= HPBar.WARN_HP_THRESHOLD).is_true()


func test_color_wounded_between_30_and_60() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 50.0

	assert_that(_bar.get_hp_percent()).is_equal(0.5)
	assert_that(_bar.get_hp_percent() >= HPBar.CRITICAL_HP_THRESHOLD).is_true()
	assert_that(_bar.get_hp_percent() < HPBar.WARN_HP_THRESHOLD).is_true()


func test_color_critical_below_30() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 20.0

	assert_that(_bar.get_hp_percent()).is_equal(0.2)
	assert_that(_bar.get_hp_percent() < HPBar.CRITICAL_HP_THRESHOLD).is_true()


# ─── Flash Timing ───────────────────────────────────────────────────────────────

func test_flash_duration_150ms() -> void:
	assert_that(HPBar.DAMAGE_FLASH_DURATION_MS).is_equal(150)


func test_flash_block_lerp_50ms() -> void:
	assert_that(HPBar.HP_FLASH_BLOCK_MS).is_equal(50)


func test_flash_starts_timer_on_damage() -> void:
	_bar._flash_timer_ms = 0.0
	_bar.flash_damage()
	assert_that(_bar._flash_timer_ms).is_equal(150.0)


func test_flash_alpha_fades_over_duration() -> void:
	_bar._flash_timer_ms = 150.0
	_bar._update_flash_alpha()

	# At start of flash, alpha = full
	var full_alpha := _bar._flash_overlay.color.a
	assert_that(full_alpha).is_equal(HPBar.FLASH_COLOR.a)

	# After 75ms (half), alpha should be half
	_bar._flash_timer_ms = 75.0
	_bar._update_flash_alpha()
	assert_that(_bar._flash_overlay.color.a).is_less_than(full_alpha)


func test_flash_clears_at_zero() -> void:
	_bar._flash_timer_ms = 0.0
	_bar._update_flash_alpha()
	assert_that(_bar._flash_overlay.color.a).is_equal(0.0)


# ─── HP Text Format ─────────────────────────────────────────────────────────────

func test_hp_text_format() -> void:
	# "HP: {floor(actual_hp)}/{actual_max_hp}"
	_bar._max_hp = 100
	_bar._target_hp = 85.0
	_bar._update_label()
	assert_that(_bar._hp_label.text).is_equal("HP: 85/100")


func test_hp_text_floors_decimal() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 84.6  # decimal
	_bar._update_label()
	assert_that(_bar._hp_label.text).is_equal("HP: 84/100")


# ─── Overshoot Prevention ───────────────────────────────────────────────────────

func test_display_hp_clamped_to_zero() -> void:
	_bar._display_hp = 5.0
	_bar._target_hp = 0.0
	_bar._lerp_block_ms = 0.0
	_bar._process(1.0)  # Large delta

	# Should not go below 0
	assert_that(_bar._display_hp).is_greater_or_equal(0.0)


func test_display_hp_clamped_to_max() -> void:
	_bar._display_hp = 90.0
	_bar._target_hp = 100.0
	_bar._lerp_block_ms = 0.0
	_bar._process(1.0)

	# Should not exceed target
	assert_that(_bar._display_hp).is_less_or_equal(_bar._target_hp)


# ─── Multiple Rapid Hits (Flash Queueing) ─────────────────────────────────────

func test_second_damage_resets_flash_timer() -> void:
	_bar._flash_timer_ms = 150.0  # Flash in progress
	_bar.flash_damage()  # Second hit

	# Timer resets to full 150ms (no queue, just reset)
	assert_that(_bar._flash_timer_ms).is_equal(150.0)


# ─── HP Bar Configuration ────────────────────────────────────────────────────

func test_configure_sets_player_id() -> void:
	_bar.configure(2, 100)
	assert_that(_bar._player_id).is_equal(2)


func test_configure_sets_max_hp() -> void:
	_bar.configure(1, 200)
	assert_that(_bar._max_hp).is_equal(200)


func test_configure_initializes_display_to_max() -> void:
	_bar.configure(1, 100)
	assert_that(_bar._display_hp).is_equal(100.0)
	assert_that(_bar._target_hp).is_equal(100.0)


# ─── HP Color Constants ────────────────────────────────────────────────────────

func test_color_healthy_green() -> void:
	assert_that(HPBar.COLOR_HEALTHY).is_equal(Color("#4ADE80"))


func test_color_wounded_yellow() -> void:
	assert_that(HPBar.COLOR_WOUNDED).is_equal(Color("#FACC15"))


func test_color_critical_red() -> void:
	assert_that(HPBar.COLOR_CRITICAL).is_equal(Color("#EF4444"))


# ─── Threshold Constants ────────────────────────────────────────────────────────

func test_critical_threshold_0_30() -> void:
	assert_that(HPBar.CRITICAL_HP_THRESHOLD).is_equal(0.30)


func test_warn_threshold_0_60() -> void:
	assert_that(HPBar.WARN_HP_THRESHOLD).is_equal(0.60)


# ─── Edge Cases ────────────────────────────────────────────────────────────────

func test_hp_percent_zero_returns_zero() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 0.0
	assert_that(_bar.get_hp_percent()).is_equal(0.0)


func test_hp_percent_100_returns_one() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 100.0
	assert_that(_bar.get_hp_percent()).is_equal(1.0)


func test_set_target_hp_clamps_to_max() -> void:
	_bar._max_hp = 100
	_bar._target_hp = 100.0  # already at max
	_bar.set_target_hp(150)  # try to set above max
	assert_that(_bar._target_hp).is_equal(100.0)
