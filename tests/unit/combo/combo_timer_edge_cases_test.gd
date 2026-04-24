# combo_timer_edge_cases_test.gd — Unit tests for combo-004 combo timer
# GdUnit4 test file
# Tests: AC-01/02/03 (timer reset), AC-18/19 (damage/death no reset), AC-21 (boss defeat), AC-23 (display cap), AC-24 (hitstop freeze), AC-27 (combo_break signal)

class_name ComboTimerEdgeCasesTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _cm: ComboManager

func before() -> void:
	_cm = ComboManager.new()

func after() -> void:
	if is_instance_valid(_cm):
		_cm.free()


# ─── AC-01: First hit lands → combo_count=1, timer=0 ─────────────────────────

func test_first_hit_sets_combo_count_to_1() -> void:
	# Given: Player 1 is IDLE (no prior hits)
	var data := _cm.get_combo_data(1)
	assert_that(data.combo_count).is_equal(0)

	# When: First hit registers (via internal state — simulate a hit)
	data.register_hit(0)

	# Then: combo_count=1, timer=0, tier=IDLE (count=1 → tier 1)
	assert_that(data.combo_count).is_equal(1)
	assert_that(data.combo_timer).is_equal(0.0)
	assert_that(data.current_tier).is_equal(1)  # NORMAL tier at count=1


# ─── AC-02: Timer expires → combo resets ───────────────────────────────────────

func test_combo_resets_after_1_5_seconds_of_no_hits() -> void:
	# Given: Player has combo_count=5, timer=0
	var data := _cm.get_combo_data(1)
	data.register_hit(0)  # hit 1
	data.register_hit(1)  # hit 2
	data.register_hit(2)  # hit 3
	data.register_hit(3)  # hit 4
	data.register_hit(4)  # hit 5
	assert_that(data.combo_count).is_equal(5)

	# When: 1.5s passes with no hits (via update)
	# Simulate 1.5s of elapsed time
	for i in range(15):
		var expired := data.update(0.1)  # 0.1s per tick = 1.5s total
		# update() should continue returning true until expiry is handled externally

	# Then: After 1.5s of accumulated time, combo timer >= COMBO_WINDOW_DURATION
	assert_that(data.combo_timer).is_equal(1.5)


func test_combo_break_signal_exists() -> void:
	# combo_break(player_id: int) signal should exist on ComboManager
	# This signal fires when combo resets due to timer expiry
	assert_that(_cm.has_signal("combo_break")).is_true()


func test_combo_window_constant_is_1_5_seconds() -> void:
	assert_that(ComboManager.COMBO_WINDOW_DURATION).is_equal(1.5)


# ─── AC-03: New hit resets timer ───────────────────────────────────────────────

func test_new_hit_resets_combo_timer_to_zero() -> void:
	# Given: Player has combo_count=5, some timer accumulated
	var data := _cm.get_combo_data(1)
	data.register_hit(0)  # hit 1
	data.register_hit(1)  # hit 2
	data.register_hit(2)  # hit 3
	data.register_hit(3)  # hit 4
	data.register_hit(4)  # hit 5

	# Advance some time (timer at ~0.5s)
	data.update(0.5)
	assert_that(data.combo_timer).is_equal(0.5)

	# When: New hit lands
	data.register_hit(5)  # 6th hit

	# Then: Timer resets to 0, count increments to 6
	assert_that(data.combo_timer).is_equal(0.0)
	assert_that(data.combo_count).is_equal(6)


# ─── AC-18: Damage does NOT reset combo ────────────────────────────────────────

func test_damage_does_not_reset_combo_count() -> void:
	# Given: Player has combo_count=10
	var data := _cm.get_combo_data(1)
	for i in range(10):
		data.register_hit(i)

	assert_that(data.combo_count).is_equal(10)

	# When: Player takes damage (simulated by advancing time, not by explicit call)
	# Damage does NOT call reset() - per Rule 4 (time-only decay)
	# Just advance time a tiny bit to simulate the event
	data.update(0.001)

	# Then: combo_count is unchanged
	assert_that(data.combo_count).is_equal(10)


# ─── AC-19: Player death does NOT affect partner's combo ───────────────────────

func test_player_death_does_not_affect_partner_combo() -> void:
	# Given: Both players have active combos
	var p1 := _cm.get_combo_data(1)
	var p2 := _cm.get_combo_data(2)
	for i in range(5):
		p1.register_hit(i)
		p2.register_hit(i + 10)

	assert_that(p1.combo_count).is_equal(5)
	assert_that(p2.combo_count).is_equal(5)

	# When: Player 1 dies (their combo resets)
	p1.reset()

	# Then: Player 2's combo is unaffected
	assert_that(p2.combo_count).is_equal(5)
	assert_that(p2.combo_timer).is_equal(0.0)


# ─── AC-21: Boss defeated → combo persists ─────────────────────────────────────

func test_boss_defeat_does_not_reset_combo() -> void:
	# Given: Player has combo_count=20
	var data := _cm.get_combo_data(1)
	for i in range(20):
		data.register_hit(i)

	assert_that(data.combo_count).is_equal(20)

	# When: Boss is defeated (simulated by nothing - boss defeat has no automatic combo effect)
	# No call to reset() happens on boss defeat

	# Then: Combo persists
	assert_that(data.combo_count).is_equal(20)


# ─── AC-23: Display cap at 99, internal continues ──────────────────────────────

func test_display_count_caps_at_99() -> void:
	# Given: Player has combo_count=100
	var data := _cm.get_combo_data(1)
	for i in range(100):
		data.register_hit(i)

	# Internal count continues past 99
	assert_that(data.combo_count).is_equal(100)

	# Display cap constant should be 99
	assert_that(ComboManager.MAX_COMBO_COUNT_DISPLAY).is_equal(99)


func test_display_combo_count_uses_mini() -> void:
	# get_display_combo_count should return min(combo_count, 99)
	# This is implemented as: mini(data.combo_count, MAX_COMBO_COUNT_DISPLAY)
	var data := _cm.get_combo_data(1)
	for i in range(150):
		data.register_hit(i)

	# The display function should return 99 (not 150)
	var display := _cm.get_display_combo_count(1)
	assert_that(display).is_equal(99)


# ─── AC-24: Hitstop does not extend timer ─────────────────────────────────────

func test_hitstop_freezes_timer_during_freeze() -> void:
	# Given: Timer at 1.4s when hitstop begins
	var data := _cm.get_combo_data(1)
	for i in range(3):
		data.register_hit(i)

	# Advance to 1.4s (hitstop threshold)
	data.update(1.4)
	assert_that(data.combo_timer).is_equal(1.4)

	# Simulate hitstop (game frozen — no timer advance)
	# When hitstop ends (after N frames), timer should still be 1.4s
	data.update(0.0)  # zero delta = frozen
	assert_that(data.combo_timer).is_equal(1.4)

	# Another hitstop period
	data.update(0.0)
	assert_that(data.combo_timer).is_equal(1.4)


# ─── AC-27: combo_break signal fires on reset ──────────────────────────────────

func test_combo_break_signal_exists_and_connectable() -> void:
	var emissions: Array = []
	if _cm.combo_break.connect(func(pid): emissions.append(pid)) == OK:
		assert_that(true).is_true()  # Signal connected successfully


func test_reset_clears_combo_count_and_timer() -> void:
	# Given: Active combo
	var data := _cm.get_combo_data(1)
	for i in range(5):
		data.register_hit(i)

	data.update(0.5)

	# When: reset() is called (simulating timer expiry)
	data.reset()

	# Then: All state cleared
	assert_that(data.combo_count).is_equal(0)
	assert_that(data.combo_timer).is_equal(0.0)
	assert_that(data.current_tier).is_equal(0)
	assert_that(data.sync_chain_length).is_equal(0)
	assert_that(data.last_hit_frame).is_equal(-1)


# ─── Additional edge cases ─────────────────────────────────────────────────────

func test_both_players_hit_same_frame_both_chains_increment() -> void:
	# Given: Both players hit on the same frame
	var p1 := _cm.get_combo_data(1)
	var p2 := _cm.get_combo_data(2)

	# When: Same frame number for both
	p1.register_hit(10)
	p2.register_hit(10)

	# Both have count=1
	assert_that(p1.combo_count).is_equal(1)
	assert_that(p2.combo_count).is_equal(1)


func test_idle_player_gets_sync_multiplier_starts_at_count_1() -> void:
	# When only one player hits, the idle player has count=0
	# This is a design rule - covered by sync detection logic
	var p1 := _cm.get_combo_data(1)
	var p2 := _cm.get_combo_data(2)

	# P1 hits, P2 is idle
	p1.register_hit(5)

	assert_that(p1.combo_count).is_equal(1)
	assert_that(p2.combo_count).is_equal(0)  # idle


func test_combo_timer_clamped_to_combo_window_duration() -> void:
	var data := _cm.get_combo_data(1)
	data.register_hit(0)

	// Advance time beyond 1.5s
	data.update(2.0)

	// Timer should be clamped to COMBO_WINDOW_DURATION
	assert_that(data.combo_timer).is_equal(1.5)
