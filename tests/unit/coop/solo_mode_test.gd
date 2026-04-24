# solo_mode_test.gd — Unit tests for coop-005 solo mode damage
# GdUnit4 test file
# Tests: AC-05

class_name SoloModeTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _coop: CoopManager

func before() -> void:
	_coop = CoopManager.new()
	get_tree().root.add_child(_coop)

func after() -> void:
	if is_instance_valid(_coop):
		_coop.free()


# ─── AC-05: SOLO mode activates when partner is DOWN/OUT ─────────────────────

func test_solo_mode_on_partner_downtime() -> void:
	_coop.apply_damage_to_player(2, 100)  # P2 DOWNTIME
	assert_that(_coop.is_solo_mode(1)).is_true()


func test_solo_mode_on_partner_out() -> void:
	_coop._player_state[1] = CoopManager.CoopState.OUT
	assert_that(_coop.is_solo_mode(1)).is_true()


func test_solo_mode_not_active_both_alive() -> void:
	assert_that(_coop.is_solo_mode(1)).is_false()


func test_solo_mode_not_active_both_down() -> void:
	_coop.apply_damage_to_player(1, 100)
	_coop.apply_damage_to_player(2, 100)
	_coop._player_state[0] = CoopManager.CoopState.DOWNTIME
	_coop._player_state[1] = CoopManager.CoopState.DOWNTIME
	assert_that(_coop.is_solo_mode(1)).is_false()


func test_solo_mode_p2() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 DOWNTIME
	assert_that(_coop.is_solo_mode(2)).is_true()


# ─── SOLO damage multiplier ─────────────────────────────────────────────────────

func test_solo_damage_multiplier() -> void:
	_coop.apply_damage_to_player(2, 100)  # P2 DOWNTIME
	assert_that(_coop.get_solo_damage_multiplier()).is_equal(0.75)


# ─── Outgoing damage multiplier (COOP_BONUS) ────────────────────────────────────

func test_coop_bonus_no_partner() -> void:
	_coop._player_state[1] = CoopManager.CoopState.OUT
	assert_that(_coop.get_outgoing_damage_multiplier(1)).is_equal(1.0)


func test_coop_bonus_with_partner() -> void:
	assert_that(_coop.get_outgoing_damage_multiplier(1)).is_equal(1.10)


func test_coop_bonus_only_when_alive() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 DOWNTIME
	_coop.apply_damage_to_player(2, 100)  # P2 DOWNTIME
	assert_that(_coop.get_outgoing_damage_multiplier(1)).is_equal(1.0)


# ─── Constants ─────────────────────────────────────────────────────────────────

func test_solo_damage_reduction_constant() -> void:
	assert_that(CoopManager.SOLO_DAMAGE_REDUCTION).is_equal(0.25)


func test_coop_bonus_constant() -> void:
	assert_that(CoopManager.COOP_BONUS).is_equal(0.10)
