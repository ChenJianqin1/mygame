# boss_macro_fsm_test.gd — Unit tests for boss-ai-002 Macro FSM States
# GdUnit4 test file
# Tests: AC-01 through AC-10

class_name BossMacroFSMTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _boss: BossAIManager

func before() -> void:
	_boss = BossAIManager.new()

func after() -> void:
	if is_instance_valid(_boss):
		_boss.free()


# ─── AC-01: IDLE → ATTACKING transition ────────────────────────────────────────

func test_idle_to_attacking_transition() -> void:
	# Given: Boss in IDLE state
	assert_that(_boss.get_boss_state()).is_equal("IDLE")

	# When: request_attack() is called
	_boss.request_attack()

	# Then: Boss is in ATTACKING state
	assert_that(_boss.get_boss_state()).is_equal("ATTACKING")


# ─── AC-02: Any state → DEFEATED transition ─────────────────────────────────────

func test_any_state_to_defeated() -> void:
	# From IDLE
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")

	# From ATTACKING
	_boss = BossAIManager.new()
	_boss.request_attack()
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")

	# From HURT
	_boss = BossAIManager.new()
	_boss.request_hurt(1.0)
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


# ─── AC-03: HURT blocks ATTACKING ─────────────────────────────────────────────

func test_hurt_blocks_attack_transition() -> void:
	# Given: Boss in HURT state
	_boss.request_hurt(1.0)
	assert_that(_boss.get_boss_state()).is_equal("HURT")

	# When: request_attack() is called
	_boss.request_attack()

	# Then: Boss remains in HURT (ATTACKING blocked)
	assert_that(_boss.get_boss_state()).is_equal("HURT")


# ─── AC-04: DEFEATED has no outgoing transitions ─────────────────────────────────

func test_defeated_is_terminal() -> void:
	# Given: Boss in DEFEATED state
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")

	# When: Transitions are attempted
	_boss.request_attack()
	_boss.request_hurt(1.0)

	# Then: Boss remains in DEFEATED
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


# ─── AC-05: get_boss_state() returns correct strings ────────────────────────────

func test_get_boss_state_idle() -> void:
	assert_that(_boss.get_boss_state()).is_equal("IDLE")


func test_get_boss_state_attacking() -> void:
	_boss.request_attack()
	assert_that(_boss.get_boss_state()).is_equal("ATTACKING")


func test_get_boss_state_hurt() -> void:
	_boss.request_hurt(1.0)
	assert_that(_boss.get_boss_state()).is_equal("HURT")


func test_get_boss_state_defeated() -> void:
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


# ─── AC-06: _state_timer increments ───────────────────────────────────────────

func test_state_timer_increments() -> void:
	# Given: Boss in IDLE
	var t0 := _boss._state_timer

	# When: update() called with delta
	_boss.update(0.5)

	# Then: Timer incremented
	assert_that(_boss._state_timer).is_equal(t0 + 0.5)


func test_state_timer_resets_on_transition() -> void:
	# Given: Boss in IDLE, timer at 1.0
	_boss.update(1.0)
	assert_that(_boss._state_timer).is_greater_than(0.0)

	# When: Transition to ATTACKING
	_boss.request_attack()

	# Then: Timer reset to 0
	assert_that(_boss._state_timer).is_equal(0.0)


# ─── AC-07: request_attack() from IDLE triggers ATTACKING ───────────────────────

func test_request_attack_from_idle() -> void:
	_boss.request_attack()
	assert_that(_boss.get_boss_state()).is_equal("ATTACKING")


func test_request_attack_from_attacking_is_noop() -> void:
	# Given: Already ATTACKING
	_boss.request_attack()
	_boss.request_attack()  # Second call

	assert_that(_boss.get_boss_state()).is_equal("ATTACKING")


# ─── AC-08: request_hurt() triggers HURT ───────────────────────────────────────

func test_request_hurt_triggers_hurt_state() -> void:
	_boss.request_hurt(1.5)
	assert_that(_boss.get_boss_state()).is_equal("HURT")


# ─── AC-09: force_defeated() always succeeds ────────────────────────────────────

func test_force_defeated_from_idle() -> void:
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


func test_force_defeated_from_attacking() -> void:
	_boss.request_attack()
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


func test_force_defeated_from_hurt() -> void:
	_boss.request_hurt(1.0)
	_boss.force_defeated()
	assert_that(_boss.get_boss_state()).is_equal("DEFEATED")


# ─── AC-10: ATTACKING emits boss_attack_started signal ───────────────────────────

func test_attacking_emits_boss_attack_started() -> void:
	var emissions: Array = []
	_boss.boss_attack_started.connect(func(p): emissions.append(p))

	_boss.request_attack()

	assert_that(emissions.size()).is_positive()


# ─── Additional: DEFEATED emits boss_defeated signal ────────────────────────────

func test_defeated_emits_boss_defeated_signal() -> void:
	var emissions: Array = []
	_boss.boss_defeated.connect(func: emissions.append(true))

	_boss.force_defeated()

	assert_that(emissions.size()).is_positive()


# ─── Additional: Transition to HURT emits no signal ────────────────────────────

func test_hurt_transition_no_signal() -> void:
	var attack_emissions: Array = []
	_boss.boss_attack_started.connect(func(p): attack_emissions.append(p))

	_boss.request_hurt(1.0)

	# No attack signal should emit for HURT
	assert_that(attack_emissions.size()).is_equal(0)


# ─── Additional: DEFEATED blocks request_attack ──────────────────────────────────

func test_defeated_blocks_attack() -> void:
	_boss.force_defeated()
	var prev := _boss.get_boss_state()
	_boss.request_attack()
	assert_that(_boss.get_boss_state()).is_equal(prev)


# ─── Additional: BossState enum values ─────────────────────────────────────────

func test_boss_state_enum_has_5_values() -> void:
	assert_that(BossAIManager.BossState.keys().size()).is_equal(5)
