# player_state_machine_test.gd — Unit tests for animation-001 player animation state machine
# GdUnit4 test file
# Tests: state transitions, attack interruption, HURT priority, recovery blocking

class_name PlayerStateMachineTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _sm: PlayerAnimationStateMachine

func before() -> void:
	_sm = PlayerAnimationStateMachine.new()

func after() -> void:
	if is_instance_valid(_sm):
		_sm.free()


# ─── AC-1.1: LIGHT attack full cycle ────────────────────────────────────────

func test_light_attack_full_cycle_returns_to_idle() -> void:
	# Given: Player in IDLE state
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.IDLE)

	# When: LIGHT attack is requested
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)
	assert_that(accepted).is_true()

	# Then: State is LIGHT_ATTACK
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# Advance 16 frames (8 anticipation + 2 active + 6 recovery)
	for i in 16:
		_sm.advance_frame()

	# Then: After total frames, request_idle to return to IDLE
	_sm.request_idle()
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.IDLE)


func test_light_attack_phase_progression() -> void:
	# Given: LIGHT attack started
	_sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# Anticipation: frames 0-7
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.ANTICIPATION)

	# Advance to active phase (frames 8-9)
	_sm.advance_frame()  # frame 9
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.ACTIVE)

	# Advance through active (frame 10 enters recovery)
	_sm.advance_frame()  # frame 10
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.RECOVERY)


# ─── AC-1.2: HURT interrupts anticipation ────────────────────────────────────

func test_hurt_interrupts_anticipation() -> void:
	# Given: Player in LIGHT attack anticipation
	_sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.LIGHT_ATTACK)
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.ANTICIPATION)

	# When: hurt is received
	_sm.request_hurt()

	# Then: State immediately becomes HURT
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.HURT)


func test_hurt_interrupts_any_attack_phase() -> void:
	# Given: Player in SPECIAL attack active phase
	_sm.request_attack(PlayerAnimationStateMachine.State.SPECIAL_ATTACK)
	# Advance through anticipation (28 frames)
	for i in 28:
		_sm.advance_frame()
	# Now in active phase
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.ACTIVE)

	# When: hurt is received
	_sm.request_hurt()

	# Then: HURT has highest priority (Rule B)
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.HURT)


# ─── AC-1.3: Recovery ignores input ─────────────────────────────────────────

func test_recovery_ignores_attack_input() -> void:
	# Given: Player in LIGHT attack, advanced to recovery phase
	_sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)
	# Advance through anticipation (8) + active (2) = 10 frames
	for i in 10:
		_sm.advance_frame()
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.RECOVERY)

	# When: Another attack is requested during recovery
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.MEDIUM_ATTACK)

	# Then: Input is ignored (no self-interrupt in recovery)
	# AC-1.3 says recovery ignores input — MEDIUM attack is blocked
	assert_that(accepted).is_false()


# ─── AC-1.4: LIGHT interrupts MEDIUM anticipation ───────────────────────────

func test_light_interrupts_medium_anticipation() -> void:
	# Given: Player in MEDIUM attack anticipation
	_sm.request_attack(PlayerAnimationStateMachine.State.MEDIUM_ATTACK)

	# Advance 8 frames into MEDIUM anticipation (out of 14)
	for i in 8:
		_sm.advance_frame()
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.MEDIUM_ATTACK)
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.ANTICIPATION)

	# When: LIGHT attack is requested
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# Then: LIGHT can interrupt MEDIUM anticipation (LIGHT total=16 >= MEDIUM ant=14)
	assert_that(accepted).is_true()
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.LIGHT_ATTACK)


func test_light_cannot_interrupt_medium_active() -> void:
	# Given: Player in MEDIUM attack active phase
	_sm.request_attack(PlayerAnimationStateMachine.State.MEDIUM_ATTACK)

	# Advance through anticipation (14 frames)
	for i in 14:
		_sm.advance_frame()
	assert_that(_sm.get_attack_phase()).is_equal(PlayerAnimationStateMachine.AttackPhase.ACTIVE)

	# When: LIGHT attack is requested during MEDIUM active
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# Then: MEDIUM active phase cannot be interrupted
	assert_that(accepted).is_false()
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.MEDIUM_ATTACK)


# ─── Additional tests ─────────────────────────────────────────────────────────

func test_no_self_interrupt_in_anticipation() -> void:
	# Given: Player in LIGHT attack anticipation
	_sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# When: Same LIGHT attack is requested again
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# Then: Self-interrupt is forbidden (Rule C)
	assert_that(accepted).is_false()


func test_idle_blocks_attack_when_hurt() -> void:
	# Given: Player in HURT state
	_sm.request_hurt()

	# When: Attack is requested
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# Then: Attack is blocked
	assert_that(accepted).is_false()


func test_move_to_idle_transitions() -> void:
	# Given: Player in IDLE
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.IDLE)

	# When: MOVE is requested
	_sm.request_move()

	# Then: State is MOVE
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.MOVE)

	# When: Stop move
	_sm.request_stop_move()

	# Then: Back to IDLE
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.IDLE)


func test_heavy_interrupt_light_anticipation() -> void:
	# Given: Player in LIGHT attack anticipation
	_sm.request_attack(PlayerAnimationStateMachine.State.LIGHT_ATTACK)

	# When: HEAVY attacks (HEAVY total=40 >= LIGHT anticipation=8)
	var accepted := _sm.request_attack(PlayerAnimationStateMachine.State.HEAVY_ATTACK)

	# Then: HEAVY can interrupt LIGHT
	assert_that(accepted).is_true()
	assert_that(_sm.get_state()).is_equal(PlayerAnimationStateMachine.State.HEAVY_ATTACK)


func test_attack_frames_config() -> void:
	# Verify frame counts match GDD
	var light := PlayerAnimationStateMachine.ATTACK_FRAMES[PlayerAnimationStateMachine.State.LIGHT_ATTACK]
	assert_that(light["total"]).is_equal(16)
	assert_that(light["anticipation"]).is_equal(8)
	assert_that(light["active"]).is_equal(2)
	assert_that(light["recovery"]).is_equal(6)

	var medium := PlayerAnimationStateMachine.ATTACK_FRAMES[PlayerAnimationStateMachine.State.MEDIUM_ATTACK]
	assert_that(medium["total"]).is_equal(27)

	var heavy := PlayerAnimationStateMachine.ATTACK_FRAMES[PlayerAnimationStateMachine.State.HEAVY_ATTACK]
	assert_that(heavy["total"]).is_equal(40)

	var special := PlayerAnimationStateMachine.ATTACK_FRAMES[PlayerAnimationStateMachine.State.SPECIAL_ATTACK]
	assert_that(special["total"]).is_equal(58)
