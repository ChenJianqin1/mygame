# boss_ai_manager_test.gd — Unit tests for boss-ai-001 BossAIManager foundation
# GdUnit4 test file
# Tests: constants, state enum, member variables, query methods

class_name BossAIManagerTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _boss_ai: BossAIManager

func before() -> void:
	_boss_ai = BossAIManager.new()
	_boss_ai._ready()

func after() -> void:
	if is_instance_valid(_boss_ai):
		_boss_ai.free()


# ─── AC-02: Constants verification ──────────────────────────────────────────

func test_base_boss_hp_constant() -> void:
	assert_that(BossAIManager.BASE_BOSS_HP).is_equal(500)


func test_phase_thresholds() -> void:
	assert_that(BossAIManager.PHASE_2_THRESHOLD).is_equal(0.60)
	assert_that(BossAIManager.PHASE_3_THRESHOLD).is_equal(0.30)


func test_rescue_constants() -> void:
	assert_that(BossAIManager.RESCUE_SLOWDOWN).is_equal(0.5)
	assert_that(BossAIManager.RESCUE_SUSPENSION).is_equal(2.0)


func test_compression_constants() -> void:
	assert_that(BossAIManager.BASE_COMPRESSION_SPEED).is_equal(32.0)
	assert_that(BossAIManager.COMPRESSION_DAMAGE_RATE).is_equal(5.0)


func test_attack_constants() -> void:
	assert_that(BossAIManager.MIN_ATTACK_INTERVAL).is_equal(1.5)
	assert_that(BossAIManager.MERCY_ZONE).is_equal(100.0)


# ─── AC-03: BossState enum ─────────────────────────────────────────────────────

func test_boss_state_enum_has_all_states() -> void:
	assert_that(BossAIManager.BossState.keys().size()).is_equal(5)
	assert_that(BossAIManager.BossState.IDLE).is_equal(0)
	assert_that(BossAIManager.BossState.ATTACKING).is_equal(1)
	assert_that(BossAIManager.BossState.HURT).is_equal(2)
	assert_that(BossAIManager.BossState.PHASE_CHANGE).is_equal(3)
	assert_that(BossAIManager.BossState.DEFEATED).is_equal(4)


# ─── AC-05 / AC-06: Query methods ─────────────────────────────────────────────

func test_get_boss_state_on_init() -> void:
	assert_that(_boss_ai.get_boss_state()).is_equal("IDLE")


func test_get_current_phase_on_init() -> void:
	assert_that(_boss_ai.get_current_phase()).is_equal(1)


# ─── AC-07: Member variable defaults ───────────────────────────────────────────

func test_boss_hp_initialized_to_base() -> void:
	assert_that(_boss_ai.get_boss_hp_percent()).is_equal(1.0)


func test_boss_state_initialized_to_idle() -> void:
	assert_that(_boss_ai.is_boss_attacking()).is_false()


# ─── HP and Phase tests ────────────────────────────────────────────────────────

func test_apply_damage_to_boss() -> void:
	var actual: int = _boss_ai.apply_damage_to_boss(100)
	assert_that(actual).is_equal(100)
	assert_that(_boss_ai.get_boss_hp_percent()).is_close(0.8, 0.001)


func test_apply_damage_respects_zero_floor() -> void:
	_boss_ai.apply_damage_to_boss(600)
	assert_that(_boss_ai.get_boss_hp_percent()).is_equal(0.0)


func test_phase_transition_at_60_percent() -> void:
	# Deal 40% damage (200 HP out of 500)
	_boss_ai.apply_damage_to_boss(200)
	assert_that(_boss_ai.get_current_phase()).is_equal(1)  # Still phase 1 (60% threshold)

	# Deal 1 more HP to cross 60% threshold
	_boss_ai.apply_damage_to_boss(1)
	assert_that(_boss_ai.get_current_phase()).is_equal(2)


func test_phase_transition_at_30_percent() -> void:
	# Deal 70% damage (350 HP) → phase 2
	_boss_ai.apply_damage_to_boss(350)
	assert_that(_boss_ai.get_current_phase()).is_equal(2)

	# Deal 150 more HP (500 total) → crosses 30% into phase 3
	_boss_ai.apply_damage_to_boss(150)
	assert_that(_boss_ai.get_current_phase()).is_equal(3)


func test_defeated_boss_takes_no_damage() -> void:
	_boss_ai.apply_damage_to_boss(500)
	assert_that(_boss_ai.get_boss_state()).is_equal("DEFEATED")

	var extra_damage: int = _boss_ai.apply_damage_to_boss(100)
	assert_that(extra_damage).is_equal(0)
