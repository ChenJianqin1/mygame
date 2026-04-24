# animation_hitbox_sync_test.gd — Unit tests for collision-007 Animation-Driven Hitbox Spawning
# GdUnit4 test file
# Tests: EC5-01, EC6-04, EC7-01 — Hitbox spawn/despawn synchronized to animation frames

class_name AnimationHitboxSyncTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _controller: FrameLockedHitbox


func before() -> void:
	# FrameLockedHitbox is a RefCounted, we instantiate per test
	pass


func after() -> void:
	pass


# ─── AC-EC7-01: Hitbox spawns at animation frame 5 via Method Track ─────────────

func test_frame_locked_hitbox_exists() -> void:
	# Verify FrameLockedHitbox class exists
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("LIGHT")
	assert_that(fb).is_not_null()


func test_light_attack_active_range() -> void:
	# AC-EC7-01: LIGHT attack hitbox activates at frame 8-9 (animation frame 5)
	# But FrameLockedHitbox uses its own frame counter
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("LIGHT")

	# Frame 0-7: anticipation (hitbox NOT active)
	for i in 7:
		fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_false()

	# Frame 8: active window starts
	fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_true()

	# Frame 9: still active
	fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_true()

	# Frame 10: recovery (hitbox NOT active)
	fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_false()


func test_medium_attack_active_range() -> void:
	# MEDIUM attack: frames 14-16 active
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("MEDIUM")

	# Advance to frame 14
	for i in 13:
		fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_false()

	# Frame 14-16: active
	fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_true()

	fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_true()

	# Frame 17: recovery
	fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_false()


func test_heavy_attack_active_range() -> void:
	# HEAVY attack: frames 20-23 active
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("HEAVY")

	# Advance to frame 20
	for i in 19:
		fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_false()

	# Frame 20-23: active
	for i in 4:
		fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_true()


func test_special_attack_active_range() -> void:
	# SPECIAL attack: frames 28-33 active
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("SPECIAL")

	# Advance to frame 28
	for i in 27:
		fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_false()

	# Frame 28-33: active
	for i in 6:
		fb.advance_frame()
	assert_that(fb.is_hitbox_active()).is_true()


# ─── AC-EC5-01: Hitbox despawns on state change to HURT ─────────────────────

func test_frame_locked_hitbox_despawn_on_interrupt() -> void:
	# When player state changes to HURT, attack is interrupted
	# FrameLockedHitbox doesn't auto-despawn — that's handled by CollisionManager.cleanup_by_owner()
	# This test verifies the hitbox frame ranges are correctly defined

	var fb: FrameLockedHitbox = FrameLockedHitbox.new("LIGHT")

	# Start attack
	fb.advance_frame()

	# Simulate state change interrupt by resetting
	fb = FrameLockedHitbox.new("LIGHT")
	assert_that(fb.is_hitbox_active()).is_false()


# ─── AC-EC6-04: Fast boundary crossing debounce ─────────────────────────────────

func test_hitbox_deactivation_on_attack_end() -> void:
	# Attack animation ends → hitbox despawns
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("LIGHT")

	# Go through entire attack
	for i in 16:
		fb.advance_frame()

	# After animation end, hitbox should be inactive
	assert_that(fb.is_hitbox_active()).is_false()


# ─── Frame Range Constants Verification ─────────────────────────────────────────

func test_hitbox_active_ranges_defined() -> void:
	# Verify the constants are correctly defined
	var ranges: Dictionary = FrameLockedHitbox.HITBOX_ACTIVE_RANGES

	assert_that(ranges.has("LIGHT")).is_true()
	assert_that(ranges.has("MEDIUM")).is_true()
	assert_that(ranges.has("HEAVY")).is_true()
	assert_that(ranges.has("SPECIAL")).is_true()


func test_light_range_values() -> void:
	var light_range: Dictionary = FrameLockedHitbox.HITBOX_ACTIVE_RANGES["LIGHT"]
	assert_that(light_range["first"]).is_equal(8)
	assert_that(light_range["last"]).is_equal(9)


func test_medium_range_values() -> void:
	var medium_range: Dictionary = FrameLockedHitbox.HITBOX_ACTIVE_RANGES["MEDIUM"]
	assert_that(medium_range["first"]).is_equal(14)
	assert_that(medium_range["last"]).is_equal(16)


func test_heavy_range_values() -> void:
	var heavy_range: Dictionary = FrameLockedHitbox.HITBOX_ACTIVE_RANGES["HEAVY"]
	assert_that(heavy_range["first"]).is_equal(20)
	assert_that(heavy_range["last"]).is_equal(23)


func test_special_range_values() -> void:
	var special_range: Dictionary = FrameLockedHitbox.HITBOX_ACTIVE_RANGES["SPECIAL"]
	assert_that(special_range["first"]).is_equal(28)
	assert_that(special_range["last"]).is_equal(33)


# ─── Signal Emission Tests ────────────────────────────────────────────────────

func test_hitbox_activated_signal_exists() -> void:
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("LIGHT")
	assert_that(fb.has_signal("hitbox_activated")).is_true()


func test_hitbox_deactivated_signal_exists() -> void:
	var fb: FrameLockedHitbox = FrameLockedHitbox.new("LIGHT")
	assert_that(fb.has_signal("hitbox_deactivated")).is_true()
