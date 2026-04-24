# coop_manager_hp_pool_test.gd — Unit tests for coop-001 CoopManager HP pool
# GdUnit4 test file
# Tests: initial HP, damage, healing, downtime, co-op bonus, solo mode, crisis detection

class_name CoopManagerHpPoolTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _coop_manager: CoopManager

func before() -> void:
	_coop_manager = CoopManager.new()
	_coop_manager._ready()

func after() -> void:
	if is_instance_valid(_coop_manager):
		_coop_manager.free()


# ─── AC-01 / AC-02: Initial HP and Damage ─────────────────────────────────────

func test_initial_hp() -> void:
	# Given: Game start
	# Then: Both players have 100 HP
	assert_that(_coop_manager.get_player_hp(1)).is_equal(100)
	assert_that(_coop_manager.get_player_hp(2)).is_equal(100)


func test_apply_damage() -> void:
	# Given: P1 at 100 HP
	# When: 30 damage applied
	_coop_manager.apply_damage_to_player(1, 30)
	# Then: P1 has 70 HP
	assert_that(_coop_manager.get_player_hp(1)).is_equal(70)


func test_damage_to_zero_triggers_downtime() -> void:
	# Given: P1 at 20 HP
	_coop_manager.apply_damage_to_player(1, 20)
	assert_that(_coop_manager.get_player_state(1)).is_equal(CoopManager.CoopState.ACTIVE)

	# When: 30 more damage (total 50, exceeds 20 HP)
	_coop_manager.apply_damage_to_player(1, 30)

	# Then: P1 HP is 0 and state is DOWNTIME
	assert_that(_coop_manager.get_player_hp(1)).is_equal(0)
	assert_that(_coop_manager.get_player_state(1)).is_equal(CoopManager.CoopState.DOWNTIME)


func test_heal() -> void:
	# Given: P1 at 50 HP
	_coop_manager.apply_damage_to_player(1, 50)
	assert_that(_coop_manager.get_player_hp(1)).is_equal(50)

	# When: Heal 30 HP
	_coop_manager.heal_player(1, 30)

	# Then: P1 has 80 HP
	assert_that(_coop_manager.get_player_hp(1)).is_equal(80)


func test_heal_capped_at_max() -> void:
	# Given: P1 at 90 HP
	_coop_manager.apply_damage_to_player(1, 10)
	# When: Heal 30 (would be 120)
	_coop_manager.heal_player(1, 30)
	# Then: Capped at 100
	assert_that(_coop_manager.get_player_hp(1)).is_equal(100)


# ─── Simultaneous Downtime (AC-08) ─────────────────────────────────────────────

func test_simultaneous_damage_both_at_zero() -> void:
	# Given: Both at 10 HP
	_coop_manager.apply_damage_to_player(1, 10)
	_coop_manager.apply_damage_to_player(2, 10)
	assert_that(_coop_manager.get_player_state(1)).is_equal(CoopManager.CoopState.ACTIVE)
	assert_that(_coop_manager.get_player_state(2)).is_equal(CoopManager.CoopState.ACTIVE)

	# When: Both take 15 damage simultaneously
	_coop_manager.apply_damage_to_player(1, 15)
	_coop_manager.apply_damage_to_player(2, 15)

	# Then: Both in DOWNTIME
	assert_that(_coop_manager.get_player_state(1)).is_equal(CoopManager.CoopState.DOWNTIME)
	assert_that(_coop_manager.get_player_state(2)).is_equal(CoopManager.CoopState.DOWNTIME)


# ─── Co-op Bonus (AC-01) ────────────────────────────────────────────────────────

func test_coop_bonus_active_both_alive() -> void:
	# Given: Both players ACTIVE
	assert_that(_coop_manager.is_coop_bonus_active()).is_true()


func test_coop_bonus_not_active_when_one_down() -> void:
	# Given: P1 in DOWNTIME
	_coop_manager.apply_damage_to_player(1, 100)
	# Then: Co-op bonus is not active
	assert_that(_coop_manager.is_coop_bonus_active()).is_false()


# ─── Solo Mode ─────────────────────────────────────────────────────────────────

func test_solo_mode_when_partner_down() -> void:
	# Given: P1 ACTIVE, P2 DOWNTIME
	_coop_manager.apply_damage_to_player(2, 100)
	# Then: P1 is in solo mode
	assert_that(_coop_manager.is_solo_mode(1)).is_true()
	assert_that(_coop_manager.is_solo_mode(2)).is_false()  # P2 is the one down


func test_solo_mode_not_active_both_alive() -> void:
	assert_that(_coop_manager.is_solo_mode(1)).is_false()
	assert_that(_coop_manager.is_solo_mode(2)).is_false()


# ─── Crisis Detection ──────────────────────────────────────────────────────────

func test_crisis_detection_both_below_30_percent() -> void:
	# Given: P1 at 29 HP (29%), P2 at 29 HP (29%)
	_coop_manager.apply_damage_to_player(1, 71)  # 29 HP left
	_coop_manager.apply_damage_to_player(2, 71)  # 29 HP left
	_coop_manager.update(0.0)  # Trigger crisis check

	assert_that(_coop_manager.is_crisis_active()).is_true()


func test_crisis_not_active_above_threshold() -> void:
	# Given: P1 at 31 HP (31%), P2 at 31 HP
	_coop_manager.apply_damage_to_player(1, 69)
	_coop_manager.apply_damage_to_player(2, 69)
	_coop_manager.update(0.0)

	assert_that(_coop_manager.is_crisis_active()).is_false()


# ─── HP Percent ────────────────────────────────────────────────────────────────

func test_hp_percent_calculation() -> void:
	assert_that(_coop_manager.get_player_hp_percent(1)).is_equal(1.0)
	_coop_manager.apply_damage_to_player(1, 50)
	assert_that(_coop_manager.get_player_hp_percent(1)).is_equal(0.5)


# ─── Rescue ────────────────────────────────────────────────────────────────────

func test_attempt_rescue_success() -> void:
	# Given: P1 in DOWNTIME
	_coop_manager.apply_damage_to_player(1, 100)
	assert_that(_coop_manager.get_player_state(1)).is_equal(CoopManager.CoopState.DOWNTIME)

	# When: P2 attempts rescue
	var success: bool = _coop_manager.attempt_rescue(2, 1)

	# Then: Rescue succeeds, P1 is RESCUED
	assert_that(success).is_true()
	assert_that(_coop_manager.get_player_state(1)).is_equal(CoopManager.CoopState.RESCUED)


func test_attempt_rescue_fails_if_not_down() -> void:
	# Given: P1 is ACTIVE
	# When: Attempt rescue
	var success: bool = _coop_manager.attempt_rescue(2, 1)
	# Then: Fails (not in downtime)
	assert_that(success).is_false()
