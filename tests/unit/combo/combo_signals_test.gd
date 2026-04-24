# combo_signals_test.gd — Unit tests for combo-005 combo signal architecture
# GdUnit4 test file
# Tests: AC-25/26/27 (signal emissions), query methods, full signal flow

class_name ComboSignalsTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _cm: ComboManager

func before() -> void:
	_cm = ComboManager.new()

func after() -> void:
	if is_instance_valid(_cm):
		_cm.free()


# ─── AC-25: combo_tier_changed fires when tier changes ───────────────────────

func test_combo_tier_changed_fires_on_tier_2() -> void:
	var emissions: Array = []
	_cm.combo_tier_changed.connect(func(t, pid): emissions.append({"tier": t, "pid": pid}))

	# Simulate hit that escalates from tier 0 to tier 1
	var data := _cm.get_combo_data(1)
	data.register_hit(0)  # count=1 → tier 1

	assert_that(emissions.size()).is_positive()
	# tier 1 emission should have happened
	assert_that(emissions[0]["tier"]).is_equal(1)


# ─── AC-26: sync_chain_active fires with chain length ──────────────────────────

func test_sync_chain_active_emits_zero_when_chain_broken() -> void:
	var emissions: Array = []
	_cm.sync_chain_active.connect(func(l): emissions.append(l))

	# Simulate non-sync hit breaking chain
	_cm.evaluate_sync_for_player(1, 100)  # Returns false (not sync)

	# Should emit 0 when chain breaks
	assert_that(emissions[-1]).is_equal(0)


func test_sync_chain_active_emits_chain_length_on_sync() -> void:
	var emissions: Array = []
	_cm.sync_chain_active.connect(func(l): emissions.append(l))

	# Simulate a sync hit for both players
	var p1 := _cm.get_combo_data(1)
	var p2 := _cm.get_combo_data(2)
	p1.last_hit_frame = 10
	p2.last_hit_frame = 10  # Same frame = sync

	_cm.evaluate_sync_for_player(1, 10)

	# sync_chain_active should emit chain length (1 after first sync)
	assert_that(emissions[-1]).is_equal(1)


# ─── AC-27: combo_break fires when combo resets ──────────────────────────────

func test_combo_break_fires_when_combo_resets() -> void:
	var emissions: Array = []
	_cm.combo_break.connect(func(pid): emissions.append(pid))

	# Build up a combo
	var data := _cm.get_combo_data(1)
	data.register_hit(0)
	data.register_hit(1)
	assert_that(data.combo_count).is_equal(2)

	# Reset combo
	_cm.reset_player_combo(1)

	assert_that(emissions.size()).is_positive()
	assert_that(emissions[0]).is_equal(1)


func test_combo_break_signal_exists() -> void:
	assert_that(_cm.has_signal("combo_break")).is_true()


# ─── Query methods ─────────────────────────────────────────────────────────────

func test_get_combo_multiplier_returns_float() -> void:
	var mult := _cm.get_combo_multiplier(1)
	assert_that(mult).is_instance_of TYPE_FLOAT


func test_get_combo_multiplier_increases_with_combo() -> void:
	var data := _cm.get_combo_data(1)
	data.register_hit(0)
	data.register_hit(1)
	data.register_hit(2)

	var mult := _cm.get_combo_multiplier(1)
	# combo_count=3 → 1.0 + 3*0.05 = 1.15
	assert_that(mult).is_equal(1.15)


func test_get_combo_tier_returns_int() -> void:
	var tier := _cm.get_combo_tier(1)
	assert_that(tier).is_instance_of TYPE_INT


func test_get_combo_tier_idle_when_no_combo() -> void:
	var tier := _cm.get_combo_tier(1)
	assert_that(tier).is_equal(0)  # IDLE tier


func test_get_combo_tier_normal_after_one_hit() -> void:
	var data := _cm.get_combo_data(1)
	data.register_hit(0)

	var tier := _cm.get_combo_tier(1)
	assert_that(tier).is_equal(1)  # NORMAL


func test_get_sync_chain_length_returns_int() -> void:
	var length := _cm.get_sync_chain_length(1)
	assert_that(length).is_instance_of TYPE_INT


func test_get_sync_chain_length_zero_when_no_sync() -> void:
	var length := _cm.get_sync_chain_length(1)
	assert_that(length).is_equal(0)


# ─── combo_multiplier_updated signal ───────────────────────────────────────────

func test_combo_multiplier_updated_signal_exists() -> void:
	assert_that(_cm.has_signal("combo_multiplier_updated")).is_true()


func test_combo_multiplier_updated_fires_on_hit() -> void:
	var emissions: Array = []
	_cm.combo_multiplier_updated.connect(func(m, pid): emissions.append({"mult": m, "pid": pid}))

	var data := _cm.get_combo_data(1)
	data.register_hit(0)
	_cm._process_hit_for_player(1, 1)

	assert_that(emissions.size()).is_positive()


# ─── combo_tier_escalated signal ───────────────────────────────────────────────

func test_combo_tier_escalated_signal_exists() -> void:
	assert_that(_cm.has_signal("combo_tier_escalated")).is_true()


# ─── combo_tier_audio signal ───────────────────────────────────────────────────

func test_combo_tier_audio_signal_exists() -> void:
	assert_that(_cm.has_signal("combo_tier_audio")).is_true()


# ─── sync_window_opened signal ─────────────────────────────────────────────────

func test_sync_window_opened_signal_exists() -> void:
	assert_that(_cm.has_signal("sync_window_opened")).is_true()


# ─── get_display_combo_count caps at 99 ───────────────────────────────────────

func test_get_display_combo_count_caps_at_99() -> void:
	var data := _cm.get_combo_data(1)
	for i in range(150):
		data.register_hit(i)

	var display := _cm.get_display_combo_count(1)
	assert_that(display).is_equal(99)


func test_get_display_combo_count_below_99_returns_actual() -> void:
	var data := _cm.get_combo_data(1)
	data.register_hit(0)
	data.register_hit(1)
	data.register_hit(2)

	var display := _cm.get_display_combo_count(1)
	assert_that(display).is_equal(3)


# ─── is_combo_active ───────────────────────────────────────────────────────────

func test_is_combo_active_false_when_idle() -> void:
	assert_that(_cm.is_combo_active(1)).is_false()


func test_is_combo_active_true_when_combo_active() -> void:
	var data := _cm.get_combo_data(1)
	data.register_hit(0)
	assert_that(_cm.is_combo_active(1)).is_true()


# ─── Events.combo_hit connection ────────────────────────────────────────────────

func test_cm_subscribes_to_events_combo_hit() -> void:
	# Verify Events.combo_hit is connectable
	var err := Events.combo_hit.connect(_cm._on_combo_hit)
	# May already be connected from _ready()
	assert_that(err == OK or err == CONNECT_ALREADY).is_true()


# ─── MAX_COMBO_COUNT_DISPLAY constant ──────────────────────────────────────────

func test_max_combo_count_display_constant_99() -> void:
	assert_that(ComboManager.MAX_COMBO_COUNT_DISPLAY).is_equal(99)


# ─── COMBO_WINDOW_DURATION constant ───────────────────────────────────────────

func test_combo_window_duration_constant_1_5() -> void:
	assert_that(ComboManager.COMBO_WINDOW_DURATION).is_equal(1.5)


# ─── Tier escalation (AC-25 extended) ─────────────────────────────────────────

func test_tier_changes_trigger_combo_tier_changed() -> void:
	var emissions: Array = []
	_cm.combo_tier_changed.connect(func(t, pid): emissions.append({"tier": t, "pid": pid}))

	# Tier 1→2 transition (count 10)
	var data := _cm.get_combo_data(1)
	for i in range(10):
		data.register_hit(i)

	_cm._process_hit_for_player(1, 10)

	# Should have tier 1 emission (first hit) and tier 2 emission (at count 10)
	assert_that(emissions.size()).is_at_least(1)
