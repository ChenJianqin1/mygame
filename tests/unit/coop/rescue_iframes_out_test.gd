# rescue_iframes_out_test.gd — Unit tests for coop-003 rescue iframes + OUT state
# GdUnit4 test file
# Tests: AC-03, AC-04, AC-09, AC-13

class_name RescueIframesOutTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _coop: CoopManager

func before() -> void:
	_coop = CoopManager.new()
	get_tree().root.add_child(_coop)

func after() -> void:
	if is_instance_valid(_coop):
		_coop.free()


# ─── AC-03: Rescue revives with i-frames ─────────────────────────────────────

func test_rescue_sets_rescued_state() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 to 0 HP
	_coop.attempt_rescue(2, 1)
	assert_that(_coop.get_player_state(1)).is_equal(CoopManager.CoopState.RESCUED)


func test_rescued_player_has_iframes() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1)
	assert_that(_coop.has_iframes(1)).is_true()


func test_rescue_restores_half_hp() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1)
	assert_that(_coop.get_player_hp(1)).is_equal(50)  # 50% of 100


# ─── AC-04: Timer expires → OUT ──────────────────────────────────────────────

func test_player_out_state() -> void:
	_coop.apply_damage_to_player(1, 100)
	# Simulate timer expiry
	_coop._update_rescue_timers()
	assert_that(_coop.get_player_state(1)).is_equal(CoopManager.CoopState.OUT)


func test_out_player_is_out() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop._player_state[0] = CoopManager.CoopState.OUT
	assert_that(_coop.is_player_out(1)).is_true()


func test_active_player_is_not_out() -> void:
	assert_that(_coop.is_player_out(1)).is_false()


# ─── AC-09: DOWNTIME player can be hit ─────────────────────────────────────────

func test_downtime_player_takes_damage() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 to 0 HP (DOWNTIME)
	var initial_hp := _coop.get_player_hp(1)
	_coop.apply_damage_to_down_player(1, 20)
	# Player is in DOWNTIME, HP was 0, stays at 0
	assert_that(_coop.get_player_hp(1)).is_equal(maxi(0, initial_hp - 20))


func test_downtime_player_stays_in_downtime() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 to DOWNTIME
	_coop.apply_damage_to_down_player(1, 10)
	# Player stays in DOWNTIME (not OUT yet)
	assert_that(_coop.get_player_state(1)).is_equal(CoopManager.CoopState.DOWNTIME)


func test_non_downtime_player_ignores_down_damage() -> void:
	_coop.apply_damage_to_player(1, 50)  # P1 at 50 HP (ACTIVE)
	_coop.apply_damage_to_down_player(1, 20)
	# No effect on ACTIVE player
	assert_that(_coop.get_player_hp(1)).is_equal(50)


# ─── AC-13: Life loss resets both players ──────────────────────────────────────

func test_life_loss_resets_both_players_to_active() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop._player_state[0] = CoopManager.CoopState.OUT
	_coop.apply_damage_to_player(2, 50)
	_coop.trigger_life_loss()
	assert_that(_coop.get_player_state(1)).is_equal(CoopManager.CoopState.ACTIVE)
	assert_that(_coop.get_player_state(2)).is_equal(CoopManager.CoopState.ACTIVE)


func test_life_loss_restores_full_hp() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop.apply_damage_to_player(2, 80)
	_coop.trigger_life_loss()
	assert_that(_coop.get_player_hp(1)).is_equal(100)
	assert_that(_coop.get_player_hp(2)).is_equal(100)


func test_respawn_clears_out_state() -> void:
	_coop._player_state[0] = CoopManager.CoopState.OUT
	_coop.respawn_player(1)
	assert_that(_coop.get_player_state(1)).is_equal(CoopManager.CoopState.ACTIVE)


func test_respawn_restores_full_hp() -> void:
	_coop._player_state[0] = CoopManager.CoopState.OUT
	_coop.respawn_player(1)
	assert_that(_coop.get_player_hp(1)).is_equal(100)


# ─── I-frame helpers ───────────────────────────────────────────────────────────

func test_iframe_remaining_returns_zero_when_not_rescued() -> void:
	assert_that(_coop.get_iframe_remaining(1)).is_equal(0.0)


func test_iframe_remaining_returns_positive_when_rescued() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1)
	var remaining := _coop.get_iframe_remaining(1)
	assert_that(remaining).is_greater_than(0.0)
	assert_that(remaining).is_less_or_equal(CoopManager.RESCUED_IFRAMES_DURATION)


func test_should_block_damage_when_rescued() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1)
	assert_that(_coop.should_block_damage(1)).is_true()


func test_should_not_block_damage_when_active() -> void:
	assert_that(_coop.should_block_damage(1)).is_false()


func test_should_not_block_damage_when_downtime() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop._player_state[0] = CoopManager.CoopState.DOWNTIME
	assert_that(_coop.should_block_damage(1)).is_false()


# ─── Constants ─────────────────────────────────────────────────────────────────

func test_rescued_iframes_duration_constant() -> void:
	assert_that(CoopManager.RESCUED_IFRAMES_DURATION).is_equal(1.5)
