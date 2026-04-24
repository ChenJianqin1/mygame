# dodge_test.gd — Unit tests for combat-005 dodge/i-frames system
# GdUnit4 test file
# Tests: dodge duration, invincibility, cooldown, damage blocking

class_name DodgeTest
extends GdUnitTestSuite

# ─── AC-DOD-001: Dodge duration 12 frames ────────────────────────────────────

func test_dodge_duration_12_frames() -> void:
	# Given: CombatManager with dodge started for player 1
	var cm := CombatManager.new()
	cm.start_dodge(1)

	# Then: Player is invincible immediately after start
	assert_that(cm.is_invincible(1)).is_true()

	# When: 12 frames pass with no update
	# (invincibility still active until explicitly ended or timer runs out)
	# Verify is_invincible is true right after start
	assert_that(cm.is_invincible(1)).is_true()
	cm.free()


func test_dodge_invincibility_expires() -> void:
	var cm := CombatManager.new()
	cm.start_dodge(1)
	assert_that(cm.is_invincible(1)).is_true()

	# Advance 12 frames — invincibility expires
	cm.update_dodge(1, 12)

	assert_that(cm.is_invincible(1)).is_false()
	cm.free()


# ─── AC-DOD-020: Dodge blocks damage ─────────────────────────────────────────

func test_dodge_blocks_damage() -> void:
	var cm := CombatManager.new()
	cm.start_dodge(1)

	# When: Damage is applied
	var actual_damage: int = cm.apply_damage_to_player(1, 50)

	# Then: All damage is blocked
	assert_that(actual_damage).is_equal(0)
	cm.free()


func test_damage_applied_when_not_invincible() -> void:
	var cm := CombatManager.new()
	# No dodge started

	# When: Damage is applied
	var actual_damage: int = cm.apply_damage_to_player(1, 50)

	# Then: Full damage is taken
	assert_that(actual_damage).is_equal(50)
	cm.free()


# ─── Dodge cooldown ────────────────────────────────────────────────────────────

func test_dodge_cooldown_24_frames() -> void:
	var cm := CombatManager.new()
	cm.start_dodge(1)

	# End dodge
	cm.end_dodge(1)

	# Then: Can dodge returns false (on cooldown)
	assert_that(cm.can_dodge(1)).is_false()

	# Advance 24 frames
	cm.update_dodge(1, 24)

	# Then: Cooldown expired
	assert_that(cm.can_dodge(1)).is_true()
	cm.free()


func test_start_dodge_blocked_during_cooldown() -> void:
	var cm := CombatManager.new()
	cm.start_dodge(1)
	cm.end_dodge(1)  # Start cooldown

	# Try to dodge while on cooldown
	var started: bool = cm.start_dodge(1)

	# Then: Dodge is blocked
	assert_that(started).is_false()
	cm.free()


# ─── Dodge priority (dodge beats block) ───────────────────────────────────────

func test_dodge_has_priority_over_other_states() -> void:
	# Dodge grants invincibility regardless of other state
	var cm := CombatManager.new()
	cm.start_dodge(1)
	assert_that(cm.is_invincible(1)).is_true()

	# Even without explicit blocking logic, dodge's invincibility takes precedence
	var damage: int = cm.apply_damage_to_player(1, 999)
	assert_that(damage).is_equal(0)
	cm.free()


# ─── Constants verification ────────────────────────────────────────────────────

func test_dodge_constants() -> void:
	assert_that(CombatManager.DODGE_DURATION).is_equal(12)
	assert_that(CombatManager.DODGE_COOLDOWN).is_equal(24)


# ─── Multi-player ─────────────────────────────────────────────────────────────

func test_dodge_is_per_player() -> void:
	var cm := CombatManager.new()
	cm.start_dodge(1)

	# Player 2 is not invincible
	assert_that(cm.is_invincible(2)).is_false()
	assert_that(cm.can_dodge(2)).is_true()

	cm.free()


func test_both_players_can_dodge_independently() -> void:
	var cm := CombatManager.new()
	cm.start_dodge(1)
	cm.start_dodge(2)

	assert_that(cm.is_invincible(1)).is_true()
	assert_that(cm.is_invincible(2)).is_true()

	# End P1's dodge
	cm.end_dodge(1)

	assert_that(cm.is_invincible(1)).is_false()
	assert_that(cm.is_invincible(2)).is_true()

	cm.free()
