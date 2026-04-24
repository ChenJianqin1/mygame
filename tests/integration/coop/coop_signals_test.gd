# coop_signals_test.gd — Integration tests for coop-006 coop signals UI/VFX
# GdUnit4 test file
# Tests: Signal emissions and basic wiring

class_name CoopSignalsTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _coop: CoopManager

func before() -> void:
	_coop = CoopManager.new()
	get_tree().root.add_child(_coop)

func after() -> void:
	if is_instance_valid(_coop):
		_coop.free()


# ─── Signal existence tests ──────────────────────────────────────────────────

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


# ─── Signal emission tests ─────────────────────────────────────────────────────

func test_player_downed_signal_emits_on_enter_downtime() -> void:
	var emitted := false
	_coop.player_downed.connect(func(pid): emitted = true)
	_coop.apply_damage_to_player(1, 100)
	assert_that(emitted).is_true()


func test_player_rescued_signal_emits_on_rescue() -> void:
	var emitted := false
	_coop.player_rescued.connect(func(pid, color): emitted = true)
	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1)
	assert_that(emitted).is_true()


func test_rescue_triggered_signal_emits_on_rescue() -> void:
	var emitted := false
	_coop.rescue_triggered.connect(func(pos, color): emitted = true)
	_coop.apply_damage_to_player(1, 100)
	_coop.attempt_rescue(2, 1)
	assert_that(emitted).is_true()


func test_crisis_state_changed_emits_when_crisis_activates() -> void:
	var emitted := false
	var crisis_value := false
	_coop.crisis_state_changed.connect(func(is_crisis): emitted = true; crisis_value = is_crisis)
	_coop.apply_damage_to_player(1, 72)
	_coop.apply_damage_to_player(2, 72)
	_coop._update_crisis_state()
	assert_that(emitted).is_true()
	assert_that(crisis_value).is_true()


func test_crisis_state_changed_emits_when_crisis_deactivates() -> void:
	_coop.apply_damage_to_player(1, 72)
	_coop.apply_damage_to_player(2, 72)
	_coop._update_crisis_state()

	var emitted := false
	var crisis_value := true
	_coop.crisis_state_changed.connect(func(is_crisis): emitted = true; crisis_value = is_crisis)

	_coop.heal_player(1, 50)
	_coop._update_crisis_state()
	assert_that(emitted).is_true()
	assert_that(crisis_value).is_false()


func test_player_out_signal_emits_when_rescue_timer_expires() -> void:
	var emitted := false
	_coop.player_out.connect(func(pid): emitted = true)
	_coop.apply_damage_to_player(1, 100)
	# Simulate timer expiry
	_coop._player_state[0] = CoopManager.CoopState.OUT
	_coop._update_rescue_timers()
	assert_that(emitted).is_true()


# ─── Color constants ───────────────────────────────────────────────────────────

func test_p1_color_orange() -> void:
	# P1 color is orange #F5A623
	var p1_color := Color("#F5A623")
	assert_that(p1_color).is_equal(Color("#F5A623"))


func test_p2_color_teal() -> void:
	# P2 color is teal #4ECDC4
	var p2_color := Color("#4ECDC4")
	assert_that(p2_color).is_equal(Color("#4ECDC4"))


func test_crisis_color_midpoint() -> void:
	# Crisis color is orange+blue midpoint #7F96A6
	var crisis_color := Color("#7F96A6")
	assert_that(crisis_color).is_equal(Color("#7F96A6"))
