# frame_locked_hitbox_test.gd — Unit tests for animation-002 frame-locked hitbox synchronization
# GdUnit4 test file
# Tests: hitbox activation windows, deactivation timing, lag spike synchronization

class_name FrameLockedHitboxTest
extends GdUnitTestSuite

# ─── AC-2.1: LIGHT hitbox active frames 8-9 ────────────────────────────────

func test_light_hitbox_activates_at_frame_8() -> void:
	# Given: FrameLockedHitbox for LIGHT attack
	var hb := FrameLockedHitbox.new("LIGHT")

	# Advance to frame 7 (just before active)
	for i in 7:
		hb.advance_frame()

	# Then: hitbox not yet active
	assert_that(hb.is_hitbox_active()).is_false()

	# When: Advance to frame 8
	hb.advance_frame()

	# Then: hitbox activates
	assert_that(hb.is_hitbox_active()).is_true()
	assert_that(hb.get_current_frame()).is_equal(8)


func test_light_hitbox_still_active_at_frame_9() -> void:
	# Given: FrameLockedHitbox for LIGHT attack, at frame 9
	var hb := FrameLockedHitbox.new("LIGHT")
	for i in 9:
		hb.advance_frame()

	# Then: still active at frame 9
	assert_that(hb.is_hitbox_active()).is_true()
	assert_that(hb.get_current_frame()).is_equal(9)


func test_light_hitbox_deactivates_at_frame_10() -> void:
	# Given: FrameLockedHitbox for LIGHT attack, at frame 10
	var hb := FrameLockedHitbox.new("LIGHT")
	for i in 10:
		hb.advance_frame()

	# Then: deactivated at frame 10 (last active is frame 9)
	assert_that(hb.is_hitbox_active()).is_false()
	assert_that(hb.get_current_frame()).is_equal(10)


# ─── AC-2.2: HEAVY hitbox active frames 20-23 ─────────────────────────────

func test_heavy_hitbox_activates_at_frame_20() -> void:
	var hb := FrameLockedHitbox.new("HEAVY")
	for i in 20:
		hb.advance_frame()

	# At frame 20, should be active
	assert_that(hb.is_hitbox_active()).is_true()
	assert_that(hb.get_current_frame()).is_equal(20)


func test_heavy_hitbox_still_active_at_frame_23() -> void:
	var hb := FrameLockedHitbox.new("HEAVY")
	for i in 23:
		hb.advance_frame()

	# At frame 23, still active (last active frame)
	assert_that(hb.is_hitbox_active()).is_true()


func test_heavy_hitbox_deactivates_at_frame_24() -> void:
	var hb := FrameLockedHitbox.new("HEAVY")
	for i in 24:
		hb.advance_frame()

	# At frame 24, deactivated
	assert_that(hb.is_hitbox_active()).is_false()


# ─── AC-2.3: Lag spike causes hitbox activation to delay ─────────────────────

func test_hitbox_activation_delays_with_lag_spike() -> void:
	# Given: LIGHT hitbox, 3-frame lag spike at frame 6
	var hb := FrameLockedHitbox.new("LIGHT")

	# Advance to frame 6 (just before active window)
	for i in 6:
		hb.advance_frame()
	assert_that(hb.get_current_frame()).is_equal(6)
	assert_that(hb.is_hitbox_active()).is_false()

	# Simulate 3-frame lag (advance 3 frames but only advance 1)
	hb.advance_frames(3)

	# Then: hitbox activates at frame 9 (lag spike delayed activation)
	# Normal: would be at frame 10 with no lag
	# With lag: frame 6 + 3 lag = frame 9
	assert_that(hb.get_current_frame()).is_equal(9)
	assert_that(hb.is_hitbox_active()).is_true()  # Still in active window (8-9)


func test_hitbox_activation_delays_with_lag_spike_ending_before_active() -> void:
	# Given: LIGHT hitbox, lag spike before active window
	var hb := FrameLockedHitbox.new("LIGHT")

	# 2-frame lag at frame 5
	for i in 5:
		hb.advance_frame()
	assert_that(hb.get_current_frame()).is_equal(5)

	# Simulate 2-frame lag
	hb.advance_frames(2)
	assert_that(hb.get_current_frame()).is_equal(7)

	# Normal advance without lag
	hb.advance_frame()  # frame 8 — should activate
	assert_that(hb.is_hitbox_active()).is_true()


# ─── Additional coverage ────────────────────────────────────────────────────────

func test_medium_hitbox_active_range() -> void:
	# MEDIUM: first=14, last=16
	var hb := FrameLockedHitbox.new("MEDIUM")

	# Not active at frame 13
	for i in 13:
		hb.advance_frame()
	assert_that(hb.is_hitbox_active()).is_false()

	# Active at frame 14
	hb.advance_frame()
	assert_that(hb.is_hitbox_active()).is_true()
	assert_that(hb.get_current_frame()).is_equal(14)

	# Active at frame 16
	for i in 2:
		hb.advance_frame()
	assert_that(hb.is_hitbox_active()).is_true()

	# Not active at frame 17
	hb.advance_frame()
	assert_that(hb.is_hitbox_active()).is_false()


func test_special_hitbox_active_range() -> void:
	# SPECIAL: first=28, last=33
	var hb := FrameLockedHitbox.new("SPECIAL")

	for i in 28:
		hb.advance_frame()
	assert_that(hb.is_hitbox_active()).is_true()

	for i in 5:
		hb.advance_frame()
	assert_that(hb.is_hitbox_active()).is_true()

	hb.advance_frame()  # frame 34
	assert_that(hb.is_hitbox_active()).is_false()


func test_hitbox_activated_signal_fires() -> void:
	var hb := FrameLockedHitbox.new("LIGHT")
	var activations := 0
	hb.hitbox_activated.connect(func(t, p): activations += 1)

	# Advance to frame 8
	for i in 8:
		hb.advance_frame()

	assert_that(activations).is_equal(1)


func test_hitbox_deactivated_signal_fires() -> void:
	var hb := FrameLockedHitbox.new("LIGHT")
	var deactivations := 0
	hb.hitbox_deactivated.connect(func(): deactivations += 1)

	# Advance past active window (frame 10)
	for i in 10:
		hb.advance_frame()

	assert_that(deactivations).is_equal(1)
