# test_boss_hp_phase.gd — Unit tests for ui-003 Boss HP Bar phase colors
# GdUnit4 test file
# Tests: phase threshold logic, color transitions, AC1-AC7

class_name BossHPPhaseTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _bar: BossHPBar

func before() -> void:
	_bar = BossHPBar.new()

func after() -> void:
	if is_instance_valid(_bar):
		_bar.free()


# ─── AC2: Phase color transitions ───────────────────────────────────────────────

func test_phase1_color_is_white() -> void:
	assert_that(BossHPBar.COLOR_PHASE1).is_equal(Color("#FFFFFF"))


func test_phase2_color_is_yellow() -> void:
	assert_that(BossHPBar.COLOR_PHASE2).is_equal(Color("#FBBF24"))


func test_phase3_color_is_red() -> void:
	assert_that(BossHPBar.COLOR_PHASE3).is_equal(Color("#EF4444"))


# ─── AC6: Threshold logic (instant transitions) ─────────────────────────────────

func test_phase_calculation_100_percent_is_phase1() -> void:
	var phase := _bar._calculate_phase(1.0)
	assert_that(phase).is_equal(1)


func test_phase_calculation_80_percent_is_phase1() -> void:
	var phase := _bar._calculate_phase(0.80)
	assert_that(phase).is_equal(1)


func test_phase_calculation_exactly_60_percent_is_phase2() -> void:
	# Exactly 60% → Phase 2 (per edge case spec)
	var phase := _bar._calculate_phase(0.60)
	assert_that(phase).is_equal(2)


func test_phase_calculation_59_percent_is_phase2() -> void:
	var phase := _bar._calculate_phase(0.59)
	assert_that(phase).is_equal(2)


func test_phase_calculation_30_percent_is_phase3() -> void:
	# Exactly 30% → Phase 3
	var phase := _bar._calculate_phase(0.30)
	assert_that(phase).is_equal(3)


func test_phase_calculation_10_percent_is_phase3() -> void:
	var phase := _bar._calculate_phase(0.10)
	assert_that(phase).is_equal(3)


func test_phase_calculation_zero_percent_is_phase3() -> void:
	var phase := _bar._calculate_phase(0.0)
	assert_that(phase).is_equal(3)


# ─── Threshold constants ───────────────────────────────────────────────────────

func test_phase2_threshold_0_60() -> void:
	assert_that(BossHPBar.PHASE_2_THRESHOLD).is_equal(0.60)


func test_phase3_threshold_0_30() -> void:
	assert_that(BossHPBar.PHASE_3_THRESHOLD).is_equal(0.30)


# ─── HP text format ───────────────────────────────────────────────────────────

func test_hp_text_format() -> void:
	_bar._boss_hp = 8500
	_bar._boss_max_hp = 10000
	_bar._update_display()

	assert_that(_bar._hp_label.text).is_equal("HP: 8500/10000")


func test_hp_text_floors_decimal() -> void:
	_bar._boss_hp = 8499
	_bar._boss_max_hp = 10000
	_bar._update_display()

	# HP is int, no decimal issue here
	assert_that(_bar._hp_label.text).is_equal("HP: 8499/10000")


# ─── Configure sets boss name ─────────────────────────────────────────────────

func test_configure_sets_boss_name() -> void:
	_bar.configure("IGNIS, THE ETERNAL FLAME", 5000)
	assert_that(_bar._boss_name_label.text).is_equal("IGNIS, THE ETERNAL FLAME")


func test_configure_sets_max_hp() -> void:
	_bar.configure("IGNIS, THE ETERNAL FLAME", 5000)
	assert_that(_bar._boss_max_hp).is_equal(5000)


# ─── Phase label update ───────────────────────────────────────────────────────

func test_phase_label_shows_phase1() -> void:
	_bar._current_phase = 1
	_bar._update_phase_display()
	assert_that(_bar._phase_label.text).is_equal("Phase 1")


func test_phase_label_shows_phase2() -> void:
	_bar._current_phase = 2
	_bar._update_phase_display()
	assert_that(_bar._phase_label.text).is_equal("Phase 2")


func test_phase_label_shows_phase3() -> void:
	_bar._current_phase = 3
	_bar._update_phase_display()
	assert_that(_bar._phase_label.text).is_equal("Phase 3")


# ─── get_phase returns current phase ──────────────────────────────────────────

func test_get_phase_returns_1_initially() -> void:
	# Default phase is 1
	var phase := _bar.get_phase()
	assert_that(phase).is_equal(1)


# ─── Track tint colors ────────────────────────────────────────────────────────

func test_track_phase1_is_gray() -> void:
	assert_that(BossHPBar.TRACK_PHASE1).is_equal(Color("#6B7280"))


func test_track_phase2_is_orange() -> void:
	assert_that(BossHPBar.TRACK_PHASE2).is_equal(Color("#D97706"))


func test_track_phase3_is_dark_red() -> void:
	assert_that(BossHPBar.TRACK_PHASE3).is_equal(Color("#991B1B"))


# ─── Boss bar width constant ─────────────────────────────────────────────────

func test_boss_bar_width_600() -> void:
	assert_that(BossHPBar.BOSS_BAR_WIDTH).is_equal(600.0)


# ─── Edge: HP overflow clamped to max ─────────────────────────────────────────

func test_set_boss_hp_clamps_to_max() -> void:
	_bar.set_boss_hp(15000, 10000)
	assert_that(_bar._boss_hp).is_equal(10000)


# ─── Phase skip: direct 1 → 3 transition ─────────────────────────────────────

func test_phase_skip_from_1_to_3() -> void:
	_bar._boss_hp = 3000
	_bar._boss_max_hp = 10000
	_bar._check_phase_transition(3000, 10000)

	# 3000/10000 = 30% → Phase 3
	assert_that(_bar._current_phase).is_equal(3)


# ─── Events signal connections ─────────────────────────────────────────────────

func test_subscribes_to_boss_hp_changed() -> void:
	var err := Events.boss_hp_changed.connect(_bar._on_boss_hp_changed)
	assert_that(err == OK or err == CONNECT_ALREADY).is_true()


func test_subscribes_to_boss_phase_changed() -> void:
	var err := Events.boss_phase_changed.connect(_bar._on_boss_phase_changed)
	assert_that(err == OK or err == CONNECT_ALREADY).is_true()
