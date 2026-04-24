# sync_detection_test.gd — Unit tests for combo-003 sync detection and sync burst
# GdUnit4 test file
# Tests: is_sync_hit, should_trigger_sync_burst, evaluate_sync_for_player

class_name SyncDetectionTest
extends GdUnitTestSuite

# ─── TierLogic: is_sync_hit tests ─────────────────────────────────────────────

# AC-09: P1 hits frame N, P2 hits frame N+3 → is_sync = TRUE (3 <= 5)
func test_is_sync_hit_3_frames_apart() -> void:
	var result: bool = TierLogic.is_sync_hit(100, 103)
	assert_that(result).is_true()


# AC-10: P1 hits frame N, P2 hits frame N+7 → is_sync = FALSE (7 > 5)
func test_is_sync_hit_7_frames_apart() -> void:
	var result: bool = TierLogic.is_sync_hit(100, 107)
	assert_that(result).is_false()


# Boundary: exactly 5 frames apart → TRUE (at boundary)
func test_is_sync_hit_exactly_5_frames_apart() -> void:
	var result: bool = TierLogic.is_sync_hit(100, 105)
	assert_that(result).is_true()


# Boundary: exactly 6 frames apart → FALSE (beyond boundary)
func test_is_sync_hit_exactly_6_frames_apart() -> void:
	var result: bool = TierLogic.is_sync_hit(100, 106)
	assert_that(result).is_false()


# Same frame → TRUE (0 <= 5)
func test_is_sync_hit_same_frame() -> void:
	var result: bool = TierLogic.is_sync_hit(100, 100)
	assert_that(result).is_true()


# Negative frames → FALSE
func test_is_sync_hit_negative_frame() -> void:
	var result: bool = TierLogic.is_sync_hit(-1, 100)
	assert_that(result).is_false()


# P2 ahead of P1 (reversed order) → still works
func test_is_sync_hit_p2_ahead() -> void:
	var result: bool = TierLogic.is_sync_hit(103, 100)
	assert_that(result).is_true()


# ─── TierLogic: should_trigger_sync_burst tests ──────────────────────────────

# AC-11: chain >= 3 → TRUE
func test_should_trigger_sync_burst_at_3() -> void:
	var result: bool = TierLogic.should_trigger_sync_burst(3)
	assert_that(result).is_true()


# Above threshold
func test_should_trigger_sync_burst_at_5() -> void:
	var result: bool = TierLogic.should_trigger_sync_burst(5)
	assert_that(result).is_true()


# Below threshold → FALSE
func test_should_trigger_sync_burst_at_2() -> void:
	var result: bool = TierLogic.should_trigger_sync_burst(2)
	assert_that(result).is_false()


func test_should_trigger_sync_burst_at_0() -> void:
	var result: bool = TierLogic.should_trigger_sync_burst(0)
	assert_that(result).is_false()


# ─── ComboManager: evaluate_sync_for_player tests ───────────────────────────

var _combo_manager: ComboManager

func before() -> void:
	_combo_manager = ComboManager.new()
	_combo_manager._ready()

func after() -> void:
	if is_instance_valid(_combo_manager):
		_combo_manager.free()


# AC-09: P1 hits frame 100, P2 hits frame 103 (3 apart) → is_sync = TRUE
func test_evaluate_sync_p1_ahead_3_frames() -> void:
	var p1_data := _combo_manager.get_combo_data(1)
	var p2_data := _combo_manager.get_combo_data(2)

	# P1 hits at frame 100
	p1_data.register_hit(100)
	var is_sync := _combo_manager.evaluate_sync_for_player(1, 100)

	# P2 hits at frame 103 (3 apart, within 5-frame window)
	p2_data.register_hit(103)
	var is_sync_2 := _combo_manager.evaluate_sync_for_player(2, 103)

	assert_that(is_sync_2).is_true()


# AC-10: P1 hits frame 100, P2 hits frame 107 (7 apart) → is_sync = FALSE
func test_evaluate_sync_p2_7_frames_apart() -> void:
	var p1_data := _combo_manager.get_combo_data(1)
	var p2_data := _combo_manager.get_combo_data(2)

	p1_data.register_hit(100)
	_combo_manager.evaluate_sync_for_player(1, 100)

	p2_data.register_hit(107)
	var is_sync := _combo_manager.evaluate_sync_for_player(2, 107)

	assert_that(is_sync).is_false()


# AC-11: 3rd consecutive SYNC hit triggers sync_burst_triggered
func test_sync_burst_triggered_at_3_consecutive_sync_hits() -> void:
	var p1_data := _combo_manager.get_combo_data(1)
	var p2_data := _combo_manager.get_combo_data(2)

	# Track signal
	var burst_fired := false
	_combo_manager.sync_burst_triggered.connect(
		func(pos): burst_fired = true
	)

	# First SYNC hit (frames 100, 102)
	p1_data.register_hit(100)
	_combo_manager.evaluate_sync_for_player(1, 100)
	p2_data.register_hit(102)
	_combo_manager.evaluate_sync_for_player(2, 102)
	assert_that(burst_fired).is_false()

	# Second SYNC hit (frames 104, 106)
	p1_data.register_hit(104)
	_combo_manager.evaluate_sync_for_player(1, 104)
	p2_data.register_hit(106)
	_combo_manager.evaluate_sync_for_player(2, 106)
	assert_that(burst_fired).is_false()

	# Third SYNC hit — should trigger burst
	p1_data.register_hit(108)
	_combo_manager.evaluate_sync_for_player(1, 108)
	p2_data.register_hit(110)
	var is_sync := _combo_manager.evaluate_sync_for_player(2, 110)

	assert_that(is_sync).is_true()
	assert_that(burst_fired).is_true()


# AC-12: Non-SYNC hit resets chain and ends burst
func test_non_sync_hit_resets_chain() -> void:
	var p1_data := _combo_manager.get_combo_data(1)
	var p2_data := _combo_manager.get_combo_data(2)

	# Build up to sync chain of 2
	p1_data.register_hit(100)
	_combo_manager.evaluate_sync_for_player(1, 100)
	p2_data.register_hit(102)
	_combo_manager.evaluate_sync_for_player(2, 102)

	assert_that(p1_data.sync_chain_length).is_equal(2)

	# Non-SYNC hit (10 frames apart)
	p1_data.register_hit(200)
	_combo_manager.evaluate_sync_for_player(1, 200)

	assert_that(p1_data.sync_chain_length).is_equal(0)


# AC-26: sync_chain_active emits on chain change
func test_sync_chain_active_emits_on_chain_break() -> void:
	var p1_data := _combo_manager.get_combo_data(1)
	var p2_data := _combo_manager.get_combo_data(2)

	# Track sync_chain_active emissions
	var emitted_lengths: Array = []
	_combo_manager.sync_chain_active.connect(
		func(length): emitted_lengths.append(length)
	)

	# First sync hit
	p1_data.register_hit(100)
	_combo_manager.evaluate_sync_for_player(1, 100)
	p2_data.register_hit(102)
	_combo_manager.evaluate_sync_for_player(2, 102)

	# Non-sync breaks chain
	p1_data.register_hit(200)
	_combo_manager.evaluate_sync_for_player(1, 200)

	# Last emission should be 0 (chain broken)
	assert_that(emitted_lengths.back()).is_equal(0)


# Sync chain increments for both players together
func test_sync_chain_increments_for_both_players() -> void:
	var p1_data := _combo_manager.get_combo_data(1)
	var p2_data := _combo_manager.get_combo_data(2)

	p1_data.register_hit(100)
	_combo_manager.evaluate_sync_for_player(1, 100)
	p2_data.register_hit(102)
	_combo_manager.evaluate_sync_for_player(2, 102)

	assert_that(p1_data.sync_chain_length).is_equal(1)
	assert_that(p2_data.sync_chain_length).is_equal(1)
