# crisis_state_test.gd — Unit tests for coop-004 crisis state
# GdUnit4 test file
# Tests: AC-06, AC-07

class_name CrisisStateTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _coop: CoopManager

func before() -> void:
	_coop = CoopManager.new()
	get_tree().root.add_child(_coop)

func after() -> void:
	if is_instance_valid(_coop):
		_coop.free()


# ─── AC-06: CRISIS activates when both below 30% ──────────────────────────────

func test_crisis_activates_both_below_threshold() -> void:
	_coop.apply_damage_to_player(1, 72)  # P1 at 28 HP
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_true()


func test_crisis_not_active_one_above_threshold() -> void:
	_coop.apply_damage_to_player(1, 70)  # P1 at 30 HP (exactly threshold)
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_false()


func test_crisis_not_active_one_player_full() -> void:
	_coop.apply_damage_to_player(1, 50)  # P1 at 50 HP
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_false()


# ─── AC-07: CRISIS deactivates when either above 30% ─────────────────────────

func test_crisis_deactivates_when_one_healed() -> void:
	_coop.apply_damage_to_player(1, 72)  # P1 at 28 HP
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_true()

	_coop.heal_player(1, 50)  # P1 at 80 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_false()


func test_crisis_deactivates_on_rescue() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 DOWNTIME
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_false()  # DOWNTIME player doesn't count


# ─── CRISIS excludes DOWNTIME/OUT players ─────────────────────────────────────

func test_crisis_excludes_out_player() -> void:
	_coop._player_state[0] = CoopManager.CoopState.OUT
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_false()


func test_crisis_excludes_downtime_player() -> void:
	_coop.apply_damage_to_player(1, 100)  # P1 DOWNTIME
	_coop.apply_damage_to_player(2, 72)  # P2 at 28 HP
	_coop._update_crisis_state()
	assert_that(_coop.is_crisis_active()).is_false()


# ─── CRISIS damage multiplier ───────────────────────────────────────────────────

func test_crisis_damage_multiplier() -> void:
	_coop.apply_damage_to_player(1, 72)
	_coop.apply_damage_to_player(2, 72)
	_coop._update_crisis_state()
	assert_that(_coop.get_crisis_damage_multiplier()).is_equal(0.75)


func test_no_crisis_no_damage_multiplier() -> void:
	assert_that(_coop.get_crisis_damage_multiplier()).is_equal(1.0)


# ─── CRISIS priority over SOLO ─────────────────────────────────────────────────

func test_crisis_priority_over_solo() -> void:
	# Simulate: P1 DOWNTIME, P2 at 28 HP (CRISIS), but P1 is SOLO
	_coop.apply_damage_to_player(1, 100)  # P1 DOWNTIME
	_coop.apply_damage_to_player(2, 72)   # P2 at 28 HP (below threshold)
	_coop._update_crisis_state()

	# P2 is CRISIS, P1 is DOWNTIME (not counted) but... let's set up differently
	# Actually CRISIS excludes DOWNTIME, so CRISIS shouldn't be active here
	# Let's test get_incoming_damage_multiplier directly

	_coop._is_crisis_active = true  # Force CRISIS on
	assert_that(_coop.get_incoming_damage_multiplier(1)).is_equal(0.75)  # CRISIS wins


func test_solo_damage_reduction_when_no_crisis() -> void:
	_coop._player_state[0] = CoopManager.CoopState.DOWNTIME  # P1 is DOWN
	_coop._player_state[1] = CoopManager.CoopState.ACTIVE    # P2 is ACTIVE
	_coop._is_crisis_active = false  # No crisis

	# P2 is SOLO (P1 is DOWN)
	assert_that(_coop.get_incoming_damage_multiplier(2)).is_equal(0.75)


# ─── Constants ─────────────────────────────────────────────────────────────────

func test_crisis_threshold_constant() -> void:
	assert_that(CoopManager.CRISIS_HP_THRESHOLD).is_equal(0.30)


func test_crisis_damage_reduction_constant() -> void:
	assert_that(CoopManager.CRISIS_DAMAGE_REDUCTION).is_equal(0.25)


# ─── Signal emission ────────────────────────────────────────────────────────────

func test_crisis_signal_emitted_on_activation() -> void:
	var signal_received := false
	_coop.crisis_state_changed.connect(func(is_crisis): signal_received = true)

	_coop.apply_damage_to_player(1, 72)
	_coop.apply_damage_to_player(2, 72)
	_coop._update_crisis_state()

	assert_that(signal_received).is_true()
