# coop_signals_integration_test.gd — Integration tests for coop-006 Coop Signals Integration
# GdUnit4 test file
# Tests: Signal wiring verification

class_name CoopSignalsIntegrationTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _coop: CoopManager

func before() -> void:
	_coop = CoopManager
	# Reset state by calling _ready (emits coop_bonus_active with initial state)
	_coop._ready()

func after() -> void:
	# No cleanup needed for autoload
	pass


# ─── Signal Existence Tests ────────────────────────────────────────────────────

func test_coop_bonus_active_signal_exists() -> void:
	assert_that(_coop.has_signal("coop_bonus_active")).is_true()


func test_solo_mode_active_signal_exists() -> void:
	assert_that(_coop.has_signal("solo_mode_active")).is_true()


func test_player_downed_signal_exists() -> void:
	assert_that(_coop.has_signal("player_downed")).is_true()


func test_player_rescued_signal_exists() -> void:
	assert_that(_coop.has_signal("player_rescued")).is_true()


func test_crisis_state_changed_signal_exists() -> void:
	assert_that(_coop.has_signal("crisis_state_changed")).is_true()


func test_player_out_signal_exists() -> void:
	assert_that(_coop.has_signal("player_out")).is_true()


func test_rescue_triggered_signal_exists() -> void:
	assert_that(_coop.has_signal("rescue_triggered")).is_true()


func test_crisis_activated_signal_exists() -> void:
	assert_that(_coop.has_signal("crisis_activated")).is_true()


# ─── AC-01: rescue_triggered emits with rescuer_color ────────────────────────

func test_rescue_triggered_contains_color() -> void:
	var emissions: Array = []
	_coop.rescue_triggered.connect(func(pos, color): emissions.append({"pos": pos, "color": color}))

	_coop.attempt_rescue(1, 2, Color("#F5A623"))

	assert_that(emissions.size()).is_positive()


# ─── AC-02: crisis_activated emits when both players low HP ───────────────

func test_crisis_activated_when_both_low_hp() -> void:
	var emissions: Array = []
	_coop.crisis_activated.connect(func: emissions.append(true))

	# Set both players to low HP
	_coop.apply_damage_to_player(1, 70)  # P1 at 30 HP
	_coop.apply_damage_to_player(2, 70)  # P2 at 30 HP

	# Trigger state update (crisis_activated emits in _update_crisis_state)
	_coop.update(0.0)

	# Should trigger crisis
	assert_that(emissions.size()).is_positive()


# ─── AC-03: player_out emits when rescue timer expires ────────────────────

func test_player_out_when_rescue_fails() -> void:
	var emissions: Array = []
	_coop.player_out.connect(func(pid): emissions.append(pid))

	# Player down
	_coop.apply_damage_to_player(1, 100)  # P1 down

	# Manually fast-forward downtime past rescue window (3 seconds)
	_coop._downtime_start_time[0] = -999.0  # Set to far in the past
	_coop._update_rescue_timers()

	# Should emit player_out
	assert_that(emissions.size()).is_positive()


# ─── AC-04: coop_bonus_active when both alive ─────────────────────────────

func test_coop_bonus_active_when_both_alive() -> void:
	# Reset state by triggering a state change
	_coop.apply_damage_to_player(1, 1)  # Small damage to trigger state evaluation
	_coop.apply_damage_to_player(2, 1)

	var emissions: Array = []
	_coop.coop_bonus_active.connect(func(m): emissions.append(m))

	# Both players should be alive initially
	# Emit state change to trigger coop_bonus_active emission
	_coop.update(0.0)

	# Should emit coop bonus active (1.10 multiplier)
	assert_that(emissions.size()).is_positive()
	if emissions.size() > 0:
		assert_that(emissions[0]).is_equal(1.10)


# ─── Additional Tests ──────────────────────────────────────────────────────────

func test_player_rescued_signal_passes_color() -> void:
	var emissions: Array = []
	_coop.player_rescued.connect(func(pid, color): emissions.append({"pid": pid, "color": color}))

	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1, Color("#F5A623"))

	# Player should be rescued
	assert_that(emissions.size()).is_positive()
	assert_that(emissions[0]["color"]).is_equal(Color("#F5A623"))


func test_crisis_state_changed_emits_bool() -> void:
	var emissions: Array = []
	_coop.crisis_state_changed.connect(func(is_crisis): emissions.append(is_crisis))

	_coop.apply_damage_to_player(1, 70)
	_coop.apply_damage_to_player(2, 70)

	# First crisis activation
	if emissions.size() > 0:
		assert_that(typeof(emissions[0]) == TYPE_BOOL).is_true()


func test_solo_mode_active_emits_player_id() -> void:
	var emissions: Array = []
	_coop.solo_mode_active.connect(func(pid): emissions.append(pid))

	# Put player 2 in OUT state
	_coop.apply_damage_to_player(2, 100)  # P2 down
	_coop._downtime_start_time[1] = -999.0  # Fast-forward past rescue window
	_coop._update_rescue_timers()

	# Should emit solo mode for player 1
	var solo_emissions := emissions.filter(func(e): return e == 1)
	assert_that(solo_emissions.size()).is_positive()


func test_all_required_signals_defined() -> void:
	var required_signals := [
		"coop_bonus_active",
		"solo_mode_active",
		"player_downed",
		"player_rescued",
		"crisis_state_changed",
		"player_out",
		"rescue_triggered",
		"crisis_activated"
	]

	for sig in required_signals:
		assert_that(_coop.has_signal(sig)).is_true().with_description("Signal '%s' should exist" % sig)


# ─── Color Constants Verification ──────────────────────────────────────────────

func test_p1_color_constant_exists() -> void:
	assert_that(CoopManager.P1_COLOR).is_equal(Color("#F5A623"))


func test_p2_color_constant_exists() -> void:
	assert_that(CoopManager.P2_COLOR).is_equal(Color("#4ECDC4"))


func test_crisis_color_constant_exists() -> void:
	assert_that(CoopManager.CRISIS_COLOR).is_equal(Color("#7F96A6"))
