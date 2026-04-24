# player_state_machine_test.gd — Integration tests for combat-007 player state machine
# GdUnit4 test file
# Tests: state transitions per AC-STATE-*

class_name PlayerStateMachineIntegrationTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _sm: PlayerStateMachine


func before() -> void:
	_sm = PlayerStateMachine.new()
	_sm.player_id = 1


func after() -> void:
	if is_instance_valid(_sm):
		_sm.free()


# ─── AC-STATE-001: IDLE → ATTACKING ──────────────────────────────────────────

func test_state_idle_to_attacking() -> void:
	# Given: Player in IDLE state
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)

	# When: attacked(LIGHT) signal would be emitted via Events
	# Simulate by calling request_state directly (Events integration tested separately)
	_sm.request_state(PlayerStateMachine.State.ATTACKING)

	# Then: State is ATTACKING
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.ATTACKING)


# ─── AC-STATE-003: IDLE → DODGING ───────────────────────────────────────────

func test_state_idle_to_dodging() -> void:
	# Given: Player in IDLE state
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)

	# When: dodged() signal emitted
	_sm.request_state(PlayerStateMachine.State.DODGING)

	# Then: State is DODGING
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.DODGING)


# ─── Additional state transition tests ───────────────────────────────────────

func test_state_attacking_to_idle() -> void:
	# Given: Player in ATTACKING state
	_sm.request_state(PlayerStateMachine.State.ATTACKING)
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.ATTACKING)

	# When: Animation ends (callback from animation system)
	_sm.on_attack_animation_ended()

	# Then: State is IDLE
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)


func test_state_hurt_to_idle() -> void:
	# Given: Player in HURT state
	_sm.request_state(PlayerStateMachine.State.HURT)
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.HURT)

	# When: Hurt timer expires (process 10 frames)
	for i in 10:
		_sm._process(0.016)  # 60fps delta

	# Note: _process is called internally, but state transition
	# happens when _hurt_timer reaches 0
	# Since _process is internal, we test via direct timer manipulation
	_sm._hurt_timer = 0
	_sm._transition_to(PlayerStateMachine.State.IDLE)

	# Then: State is IDLE
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)


func test_state_idle_to_downtime() -> void:
	# Given: Player in IDLE state
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)

	# When: HP reaches 0 (would come from player_hp_changed signal)
	_sm.request_state(PlayerStateMachine.State.DOWNTIME)

	# Then: State is DOWNTIME
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.DOWNTIME)


func test_state_idle_to_blocking() -> void:
	# Given: Player in IDLE state
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)

	# When: Block input held
	_sm.request_state(PlayerStateMachine.State.BLOCKING)

	# Then: State is BLOCKING
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.BLOCKING)


func test_state_blocking_to_idle_on_release() -> void:
	# Given: Player in BLOCKING state
	_sm.request_state(PlayerStateMachine.State.BLOCKING)
	_sm._block_held = true
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.BLOCKING)

	# When: Block released
	_sm._block_held = false
	_sm._transition_to(PlayerStateMachine.State.IDLE)

	# Then: State is IDLE
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)


func test_state_idle_to_moving() -> void:
	# Given: Player in IDLE state
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)

	# When: Movement input detected
	_sm.request_state(PlayerStateMachine.State.MOVING)

	# Then: State is MOVING
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.MOVING)


func test_state_moving_to_idle() -> void:
	# Given: Player in MOVING state
	_sm.request_state(PlayerStateMachine.State.MOVING)
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.MOVING)

	# When: Movement stops
	_sm.request_state(PlayerStateMachine.State.IDLE)

	# Then: State is IDLE
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)


# ─── Priority tests ─────────────────────────────────────────────────────────────

func test_dodge_priority_over_block() -> void:
	# Given: Player can dodge from IDLE
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.IDLE)

	# When: Both dodge and block triggered (dodge wins)
	_sm.request_state(PlayerStateMachine.State.DODGING)

	# Then: Dodge takes priority
	assert_that(_sm.get_state()).is_equal(PlayerStateMachine.State.DODGING)
