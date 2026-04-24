# boss_animation_state_machine_test.gd — Unit tests for animation-003 Boss Animation SM
# GdUnit4 test file
# Tests: AC-4.1 through AC-4.4

class_name BossAnimationStateMachineTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _b: BossAnimationStateMachine

func before() -> void:
	_b = BossAnimationStateMachine.new()

func after() -> void:
	if is_instance_valid(_b):
		_b.free()


# ─── AC-4.1: Phase 1→2 transition ──────────────────────────────────────────────

func test_phase1_to_phase2_transition() -> void:
	# Given: Boss at Phase 1
	assert_that(_b.get_phase()).is_equal(1)
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_IDLE)

	# When: request_phase_change(2) is called
	_b.request_phase_change(2)

	# Then: State is PHASE_TRANSITION, phase updated
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_PHASE_TRANSITION)
	assert_that(_b.get_phase()).is_equal(2)


func test_phase_transition_is_in_transition() -> void:
	_b.request_phase_change(2)
	assert_that(_b.is_in_transition()).is_true()


func test_phase_transition_completes_after_60_frames() -> void:
	_b.request_phase_change(2)

	# Advance 59 frames — not complete
	_b._animation_frame = 59
	assert_that(_b.is_phase_transition_complete()).is_false()

	# Advance to frame 60 — complete
	_b._animation_frame = 60
	assert_that(_b.is_phase_transition_complete()).is_true()


func test_complete_phase_transition_returns_to_idle() -> void:
	_b.request_phase_change(2)
	_b._animation_frame = 60
	_b.complete_phase_transition()

	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_IDLE)
	assert_that(_b.is_in_transition()).is_false()


# ─── AC-4.2: Phase 2 idle animation speed ──────────────────────────────────────

func test_phase2_idle_frame_count_20() -> void:
	_b.request_phase_change(2)
	_b.complete_phase_transition()

	assert_that(_b.get_idle_frame_count()).is_equal(20)


func test_phase1_idle_frame_count_24() -> void:
	assert_that(_b.get_idle_frame_count()).is_equal(24)


# ─── AC-4.3: Phase 3 transition and idle speed ──────────────────────────────

func test_phase2_to_phase3_transition() -> void:
	_b.request_phase_change(2)
	_b.complete_phase_transition()
	_b.request_phase_change(3)

	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_PHASE_TRANSITION)
	assert_that(_b.get_phase()).is_equal(3)


func test_phase3_idle_frame_count_16() -> void:
	_b.request_phase_change(2)
	_b.complete_phase_transition()
	_b.request_phase_change(3)
	_b.complete_phase_transition()

	assert_that(_b.get_idle_frame_count()).is_equal(16)


# ─── AC-4.4: Defeat sequence ──────────────────────────────────────────────────

func test_defeat_sequence_sets_defeat_state() -> void:
	_b.request_defeat()

	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_DEFEAT)
	assert_that(_b.is_in_transition()).is_true()


func test_defeat_is_complete_after_90_frames() -> void:
	_b.request_defeat()

	_b._animation_frame = 89
	assert_that(_b.is_defeat_complete()).is_false()

	_b._animation_frame = 90
	assert_that(_b.is_defeat_complete()).is_true()


# ─── Idle state ────────────────────────────────────────────────────────────────

func test_initial_state_is_idle() -> void:
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_IDLE)


func test_initial_phase_is_1() -> void:
	assert_that(_b.get_phase()).is_equal(1)


# ─── Attack requests ───────────────────────────────────────────────────────────

func test_attack_a_transitions_to_attack_state() -> void:
	var result := _b.request_attack_a()
	assert_that(result).is_true()
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_ATTACK_A)


func test_attack_b_transitions_to_attack_state() -> void:
	var result := _b.request_attack_b()
	assert_that(result).is_true()
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_ATTACK_B)


func test_rage_attack_blocked_in_phase1() -> void:
	var result := _b.request_rage_attack()
	assert_that(result).is_false()
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_IDLE)


func test_rage_attack_allowed_in_phase2() -> void:
	_b.request_phase_change(2)
	_b.complete_phase_transition()

	var result := _b.request_rage_attack()
	assert_that(result).is_true()
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_RAGE_ATTACK)


# ─── Vulnerable state ──────────────────────────────────────────────────────────

func test_request_vulnerable_transitions_to_vulnerable() -> void:
	_b.request_vulnerable()
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_VULNERABLE)


func test_vulnerable_blocked_during_attack() -> void:
	_b.request_attack_a()
	_b.request_vulnerable()
	# Should not interrupt attack
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_ATTACK_A)


# ─── Blocked during transition ────────────────────────────────────────────────

func test_attack_blocked_during_phase_transition() -> void:
	_b.request_phase_change(2)
	var result := _b.request_attack_a()
	assert_that(result).is_false()


func test_attack_blocked_during_defeat() -> void:
	_b.request_defeat()
	var result := _b.request_attack_a()
	assert_that(result).is_false()


# ─── Phase constants ──────────────────────────────────────────────────────────

func test_phase_transition_frames_60() -> void:
	assert_that(BossAnimationStateMachine.PHASE_TRANSITION_FRAMES).is_equal(60)


func test_defeat_frames_90() -> void:
	assert_that(BossAnimationStateMachine.DEFEAT_FRAMES).is_equal(90)


# ─── is_in_attack ──────────────────────────────────────────────────────────────

func test_is_in_attack_during_attack_a() -> void:
	_b.request_attack_a()
	assert_that(_b.is_in_attack()).is_true()


func test_is_in_attack_false_in_idle() -> void:
	assert_that(_b.is_in_attack()).is_false()


# ─── Advance frame ─────────────────────────────────────────────────────────────

func test_advance_frame_increments_counter() -> void:
	var initial := _b._animation_frame
	_b.advance_frame()
	assert_that(_b._animation_frame).is_equal(initial + 1)


# ─── Same phase noop ──────────────────────────────────────────────────────────

func test_phase_change_same_phase_is_noop() -> void:
	_b.request_phase_change(1)  # Already phase 1
	assert_that(_b.get_phase()).is_equal(1)
	assert_that(_b.get_state()).is_equal(BossAnimationStateMachine.BossAnimState.BOSS_IDLE)
