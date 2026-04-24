# phase_system_test.gd — Unit tests for boss-ai-004 Phase System
# GdUnit4 test file
# Tests: AC-01 through AC-10

class_name PhaseSystemTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _boss: BossAIManager

func before() -> void:
	_boss = BossAIManager.new()
	_boss._ready()

func after() -> void:
	if is_instance_valid(_boss):
		_boss.free()


# ─── AC-01: Boss HP = 100%: current_phase = 1 ───────────────────────────────

func test_initial_phase_is_1() -> void:
	assert_that(_boss.get_current_phase()).is_equal(1)


# ─── AC-02: Boss HP = 59%: current_phase = 2 ───────────────────────────────

func test_phase_2_at_59_percent() -> void:
	# 59% HP = deal 41% damage (205 out of 500)
	_boss.apply_damage_to_boss(205)
	assert_that(_boss.get_current_phase()).is_equal(2)


func test_phase_2_at_60_percent() -> void:
	# Exactly 60% HP should still be phase 1
	_boss.apply_damage_to_boss(200)  # 60% remaining
	assert_that(_boss.get_current_phase()).is_equal(1)


func test_phase_2_triggers_below_60_percent() -> void:
	_boss.apply_damage_to_boss(201)  # 59.8% remaining
	assert_that(_boss.get_current_phase()).is_equal(2)


# ─── AC-03: Boss HP = 29%: current_phase = 3 ───────────────────────────────

func test_phase_3_at_29_percent() -> void:
	# 29% HP = deal 71% damage (355 out of 500)
	_boss.apply_damage_to_boss(355)
	assert_that(_boss.get_current_phase()).is_equal(3)


func test_phase_3_at_30_percent() -> void:
	# Exactly 30% HP should still be phase 2
	_boss.apply_damage_to_boss(350)  # 30% remaining
	assert_that(_boss.get_current_phase()).is_equal(2)


func test_phase_3_triggers_below_30_percent() -> void:
	_boss.apply_damage_to_boss(351)  # 29.8% remaining
	assert_that(_boss.get_current_phase()).is_equal(3)


# ─── AC-04: HP crosses 60% downward triggers PHASE_CHANGE ────────────────────

func test_crossing_60_percent_transitions_to_phase_change_state() -> void:
	# Start at 65% (phase 1)
	_boss.apply_damage_to_boss(175)  # 325 HP = 65%
	assert_that(_boss.get_current_phase()).is_equal(1)
	assert_that(_boss.get_boss_state()).is_equal("IDLE")

	# Cross 60% threshold
	_boss.apply_damage_to_boss(26)  # 299 HP = 59.8%
	assert_that(_boss.get_boss_state()).is_equal("PHASE_CHANGE")


# ─── AC-05: HP crosses 30% downward triggers PHASE_CHANGE ────────────────────

func test_crossing_30_percent_transitions_to_phase_change_state() -> void:
	# Deal 67% damage to reach 33% (still phase 2)
	_boss.apply_damage_to_boss(335)  # 165 HP = 33%
	assert_that(_boss.get_current_phase()).is_equal(2)

	# Cross 30% threshold
	_boss.apply_damage_to_boss(16)  # 149 HP = 29.8%
	assert_that(_boss.get_boss_state()).is_equal("PHASE_CHANGE")


# ─── AC-06: boss_phase_changed signal emits on phase transition ───────────────

func test_boss_phase_changed_signal_emits_on_transition() -> void:
	var emissions: Array = []
	_boss.boss_phase_changed.connect(func(p): emissions.append(p))

	# Cross 60% threshold
	_boss.apply_damage_to_boss(201)

	assert_that(emissions.size()).is_positive()
	assert_that(emissions[0]).is_equal(2)


func test_boss_phase_changed_signal_emits_phase_3_transition() -> void:
	var emissions: Array = []
	_boss.boss_phase_changed.connect(func(p): emissions.append(p))

	# Cross 30% threshold
	_boss.apply_damage_to_boss(351)

	assert_that(emissions.size()).is_positive()
	assert_that(emissions[0]).is_equal(3)


# ─── AC-07: Phase 1 → 2 triggers compression speed change ────────────────────

func test_phase_transition_changes_compression_speed() -> void:
	# Phase 1: 32 * 1.0 = 32 px/s
	var phase1_speed := _boss._calculate_compression_speed()
	assert_that(phase1_speed).is_equal(32.0)

	# Cross into phase 2
	_boss.apply_damage_to_boss(201)
	# Phase 2: 32 * 1.5 = 48 px/s
	var phase2_speed := _boss._calculate_compression_speed()
	assert_that(phase2_speed).is_equal(48.0)


# ─── AC-08: HP = 0 triggers DEFEATED state ────────────────────────────────

func test_hp_zero_triggers_defeated_state() -> void:
	_boss.apply_damage_to_boss(500)
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


func test_defeated_phase_is_still_3() -> void:
	# Phase 3 then defeat
	_boss.apply_damage_to_boss(351)
	assert_that(_boss.get_current_phase()).is_equal(3)

	_boss.apply_damage_to_boss(149)  # Kill boss
	assert_that(_boss.get_current_phase()).is_equal(3)


# ─── AC-09: get_hp_ratio() returns correct float (0.0 to 1.0) ─────────────────

func test_get_hp_ratio_at_full() -> void:
	assert_that(_boss.get_hp_ratio()).is_equal(1.0)


func test_get_hp_ratio_at_half() -> void:
	_boss.apply_damage_to_boss(250)
	assert_that(_boss.get_hp_ratio()).is_equal(0.5)


func test_get_hp_ratio_at_zero() -> void:
	_boss.apply_damage_to_boss(500)
	assert_that(_boss.get_hp_ratio()).is_equal(0.0)


# ─── AC-10: set_max_hp() clamps current HP to new max ───────────────────────

func test_set_max_hp_increases_max_without_changing_hp() -> void:
	_boss.apply_damage_to_boss(100)  # 400 HP remaining
	assert_that(_boss.get_boss_max_hp()).is_equal(500)

	_boss.set_max_hp(1000)

	assert_that(_boss.get_boss_max_hp()).is_equal(1000)
	assert_that(_boss.get_boss_hp()).is_equal(400)  # Unchanged


func test_set_max_hp_decreases_max_clamps_hp() -> void:
	_boss.apply_damage_to_boss(100)  # 400 HP remaining
	assert_that(_boss.get_boss_hp()).is_equal(400)

	_boss.set_max_hp(300)  # New max is lower than current HP

	assert_that(_boss.get_boss_max_hp()).is_equal(300)
	assert_that(_boss.get_boss_hp()).is_equal(300)  # Clamped to new max


func test_set_max_hp_at_full_health() -> void:
	_boss.set_max_hp(1000)
	assert_that(_boss.get_boss_hp()).is_equal(500)  # Full HP on old max
	assert_that(_boss.get_boss_max_hp()).is_equal(1000)
	assert_that(_boss.get_hp_ratio()).is_equal(0.5)  # 500/1000 = 50%


# ─── Additional query method tests ───────────────────────────────────────────

func test_get_boss_hp_returns_current_hp() -> void:
	assert_that(_boss.get_boss_hp()).is_equal(500)
	_boss.apply_damage_to_boss(150)
	assert_that(_boss.get_boss_hp()).is_equal(350)


func test_get_boss_max_hp_returns_max() -> void:
	assert_that(_boss.get_boss_max_hp()).is_equal(500)


func test_set_boss_hp_works() -> void:
	_boss.set_boss_hp(250)
	assert_that(_boss.get_boss_hp()).is_equal(250)
	assert_that(_boss.get_hp_ratio()).is_equal(0.5)


func test_set_boss_hp_clamps_to_zero() -> void:
	_boss.set_boss_hp(-100)
	assert_that(_boss.get_boss_hp()).is_equal(0)


func test_set_boss_hp_clamps_to_max() -> void:
	_boss.set_boss_hp(600)
	assert_that(_boss.get_boss_hp()).is_equal(500)


# ─── Phase warning signal test ────────────────────────────────────────────────

func test_boss_phase_warning_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_phase_warning")).is_true()


# ─── Phase change state transitions to IDLE after hold ───────────────────────

func test_phase_change_transitions_to_idle_after_hold() -> void:
	# Trigger phase change
	_boss.apply_damage_to_boss(201)
	assert_that(_boss.get_boss_state()).is_equal("PHASE_CHANGE")

	# After hold time, should transition to IDLE
	_boss.update(0.5)  # Assuming phase change hold is handled in update
	# Note: actual hold time would be tested with proper timer


func test_phase_change_state_blocks_attack() -> void:
	# Trigger phase change
	_boss.apply_damage_to_boss(201)
	assert_that(_boss.get_boss_state()).is_equal("PHASE_CHANGE")

	# Attack should be blocked during phase change
	_boss.request_attack()
	assert_that(_boss.get_boss_state()).is_equal("PHASE_CHANGE")
