# attack_pattern_selection_test.gd — Unit tests for boss-ai-005 Attack Pattern Selection
# GdUnit4 test file
# Tests: AC-01 through AC-10

class_name AttackPatternSelectionTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _boss: BossAIManager

func before() -> void:
	_boss = BossAIManager.new()
	_boss._ready()

func after() -> void:
	if is_instance_valid(_boss):
		_boss.free()


# ─── Attack Pattern Constants ─────────────────────────────────────────────────────

func test_pattern_constants_exist() -> void:
	assert_that(BossAIManager.PATTERN_RELENTLESS_ADVANCE).is_equal("Pattern_1_Relentless_Advance")
	assert_that(BossAIManager.PATTERN_PAPER_AVALANCHE).is_equal("Pattern_2_Paper_Avalanche")
	assert_that(BossAIManager.PATTERN_PANIC_OVERLOAD).is_equal("Pattern_3_Panic_Overload")
	assert_that(BossAIManager.PATTERN_NONE).is_equal("NONE")


# ─── AC-01: Phase 1: only PATTERN_RELENTLESS_ADVANCE selected ───────────────

func test_phase1_selects_relentless_advance() -> void:
	# Phase 1: no damage dealt
	assert_that(_boss.get_current_phase()).is_equal(1)

	_boss._rescue_suspension_timer = 0.0  # Not in rescue suspension
	_boss._players_behind = false

	var pattern := _boss._select_attack_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_RELENTLESS_ADVANCE)


# ─── AC-02: Phase 2: PATTERN_PAPER_AVALANCHE or PATTERN_RELENTLESS_ADVANCE ──

func test_phase2_selects_pattern() -> void:
	# Deal 250 damage to trigger phase 2
	_boss.apply_damage_to_boss(250)
	assert_that(_boss.get_current_phase()).is_equal(2)


# ─── AC-03: Phase 3: PATTERN_PANIC_OVERLOAD selected ──────────────────────────

func test_phase3_selects_panic_overload() -> void:
	# Deal 400 damage to trigger phase 3
	_boss.apply_damage_to_boss(400)
	assert_that(_boss.get_current_phase()).is_equal(3)

	_boss._rescue_suspension_timer = 0.0
	_boss._players_behind = false

	var pattern := _boss._select_attack_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_PANIC_OVERLOAD)


# ─── AC-04: rescue_suspension_timer > 0: no attack selected ──────────────────

func test_rescue_suspension_blocks_attack() -> void:
	_boss._rescue_suspension_timer = 1.0

	var pattern := _boss._select_attack_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_NONE)


func test_rescue_suspension_expired_allows_attack() -> void:
	_boss._rescue_suspension_timer = 0.0

	var pattern := _boss._select_attack_pattern()
	assert_that(pattern).is_not_equal(BossAIManager.PATTERN_NONE)


# ─── AC-05: Phase 2, player near wall: Paper Avalanche selected ──────────────

func test_phase2_player_near_wall_selects_paper_avalanche() -> void:
	# Set phase 2
	_boss.apply_damage_to_boss(250)
	assert_that(_boss.get_current_phase()).is_equal(2)

	# Set compression wall and player position
	_boss._compression_wall_x = 500.0
	# Player at 650 is within 300px of wall (650 < 500 + 300 = 800)
	_boss._players_behind = false
	_boss._rescue_suspension_timer = 0.0

	var pattern := _boss._select_attack_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_PAPER_AVALANCHE)


# ─── AC-06: Phase 2, player far from wall: Relentless Advance ─────────────────

func test_phase2_player_far_from_wall_selects_relentless_advance() -> void:
	# Set phase 2
	_boss.apply_damage_to_boss(250)
	assert_that(_boss.get_current_phase()).is_equal(2)

	# Set compression wall and player position (player far behind wall)
	_boss._compression_wall_x = 500.0
	_boss._players_behind = true  # Player behind mercy zone
	_boss._rescue_suspension_timer = 0.0

	var pattern := _boss._select_attack_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_RELENTLESS_ADVANCE)


# ─── AC-07: Boss full HP, MIN_ATTACK_INTERVAL=1.5s: cooldown = 2.5s ─────────

func test_full_hp_attack_cooldown_is_2_5s() -> void:
	# Full HP (500/500 = 100%)
	var cooldown := _boss._calculate_attack_cooldown()
	assert_that(cooldown).is_equal(2.5)


func test_min_attack_interval_constant_is_1_5() -> void:
	assert_that(BossAIManager.MIN_ATTACK_INTERVAL).is_equal(1.5)


# ─── AC-08: Boss 50% HP: cooldown = max(1.5, 2.5 * 0.75) = 1.875s ────────

func test_50_percent_hp_attack_cooldown() -> void:
	# Deal 250 damage to get to 50% HP
	_boss.apply_damage_to_boss(250)

	# hp_multiplier = 0.5 + 0.5 * (250/500) = 0.5 + 0.25 = 0.75
	# cooldown = max(1.5, 2.5 * 0.75) = max(1.5, 1.875) = 1.875
	var cooldown := _boss._calculate_attack_cooldown()
	assert_that(cooldown).is_equal(1.875)


func test_low_hp_uses_min_interval() -> void:
	# At very low HP, cooldown should floor at MIN_ATTACK_INTERVAL
	# Deal 475 damage (5% HP remaining)
	_boss.apply_damage_to_boss(475)

	# hp_multiplier = 0.5 + 0.5 * (25/500) = 0.5 + 0.025 = 0.525
	# cooldown = max(1.5, 2.5 * 0.525) = max(1.5, 1.3125) = 1.5
	var cooldown := _boss._calculate_attack_cooldown()
	assert_that(cooldown).is_equal(1.5)


# ─── AC-09: can_attack() returns true only when IDLE + cooldown <= 0 ──────────

func test_can_attack_when_idle_no_cooldown() -> void:
	assert_that(_boss.get_boss_state()).is_equal("IDLE")
	_boss._attack_cooldown = 0.0

	assert_that(_boss.can_attack()).is_true()


func test_cannot_attack_when_cooldown_active() -> void:
	_boss._attack_cooldown = 1.0

	assert_that(_boss.can_attack()).is_false()


func test_cannot_attack_when_not_idle() -> void:
	_boss._attack_cooldown = 0.0
	_boss.request_attack()  # Enter ATTACKING state

	assert_that(_boss.can_attack()).is_false()


func test_cannot_attack_when_both_not_idle_and_cooldown() -> void:
	_boss._attack_cooldown = 1.0
	_boss.request_attack()

	assert_that(_boss.can_attack()).is_false()


# ─── AC-10: Attack selected emits boss_attack_started signal ──────────────────

func test_attack_transition_emits_signal() -> void:
	var emissions: Array = []
	_boss.boss_attack_started.connect(func(p): emissions.append(p))

	_boss._attack_cooldown = 0.0
	_boss.request_attack()

	assert_that(emissions.size()).is_positive()


func test_none_pattern_does_not_emit_attack() -> void:
	# When rescue suspension is active, pattern is NONE, no attack signal
	var emissions: Array = []
	_boss.boss_attack_started.connect(func(p): emissions.append(p))

	_boss._rescue_suspension_timer = 1.0
	_boss.request_attack()

	# Should transition to ATTACKING but pattern is NONE
	assert_that(_boss.get_boss_state()).is_equal("ATTACKING")
	# No attack started signal when pattern is NONE
	assert_that(emissions.size()).is_equal(0)


# ─── Additional tests ─────────────────────────────────────────────────────────

func test_select_phase2_pattern_far_from_wall() -> void:
	_boss.apply_damage_to_boss(250)  # Phase 2
	_boss._compression_wall_x = 500.0
	_boss._players_behind = true  # Player behind

	var pattern := _boss._select_phase2_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_RELENTLESS_ADVANCE)


func test_select_phase2_pattern_close_to_wall() -> void:
	_boss.apply_damage_to_boss(250)  # Phase 2
	_boss._compression_wall_x = 500.0
	_boss._players_behind = false  # Player not behind

	var pattern := _boss._select_phase2_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_PAPER_AVALANCHE)


func test_select_phase3_pattern_always_panic_overload() -> void:
	_boss.apply_damage_to_boss(400)  # Phase 3

	var pattern := _boss._select_phase3_pattern()
	assert_that(pattern).is_equal(BossAIManager.PATTERN_PANIC_OVERLOAD)


func test_attack_sets_cooldown() -> void:
	_boss._attack_cooldown = 0.0
	_boss._boss_hp = 500  # Full HP

	_boss.request_attack()

	# Cooldown should be set to 2.5s (full HP)
	assert_that(_boss._attack_cooldown).is_equal(2.5)


func test_attack_telegraph_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_attack_telegraph")).is_true()


func test_attack_telegraph_emits_before_attack() -> void:
	var telegraphs: Array = []
	var attacks: Array = []
	_boss.boss_attack_telegraph.connect(func(p): telegraphs.append(p))
	_boss.boss_attack_started.connect(func(p): attacks.append(p))

	_boss._attack_cooldown = 0.0
	_boss.request_attack()

	# Telegraph should emit before attack started
	assert_that(telegraphs.size()).is_positive()
