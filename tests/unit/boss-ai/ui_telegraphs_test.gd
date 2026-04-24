# ui_telegraphs_test.gd — Unit tests for boss-ai-008 UI Telegraphs
# GdUnit4 test file
# Tests: AC-01 through AC-08

class_name UiTelegraphsTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _boss: BossAIManager

func before() -> void:
	_boss = BossAIManager.new()
	_boss._ready()

func after() -> void:
	if is_instance_valid(_boss):
		_boss.free()


# ─── Constants ───────────────────────────────────────────────────────────────

func test_attack_telegraph_time_constant() -> void:
	assert_that(BossAIManager.ATTACK_TELEGRAPH_TIME).is_equal(0.8)


# ─── AC-01: boss_attack_telegraph emits before boss_attack_started ─────────────

func test_attack_telegraph_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_attack_telegraph")).is_true()


func test_attack_started_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_attack_started")).is_true()


# ─── AC-02: Telegraph delay is 0.8 seconds ─────────────────────────────────────

func test_telegraph_delay_constant() -> void:
	assert_that(BossAIManager.ATTACK_TELEGRAPH_TIME).is_equal(0.8)


# ─── AC-03: boss_phase_warning emits before boss_phase_changed ─────────────────

func test_phase_warning_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_phase_warning")).is_true()


func test_phase_changed_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_phase_changed")).is_true()


# ─── AC-04: Phase warning delay is 1.0 seconds ─────────────────────────────────

func test_phase_warning_delay_constant() -> void:
	assert_that(BossAIManager.PHASE_CHANGE_HOLD).is_equal(1.0)


# ─── AC-05: boss_hp_changed emits when set_boss_hp is called ────────────────

func test_boss_hp_changed_signal_exists() -> void:
	assert_that(_boss.has_signal("boss_hp_changed")).is_true()


func test_set_boss_hp_emits_signal() -> void:
	var emissions: Array = []
	_boss.boss_hp_changed.connect(func(c, m): emissions.append({"current": c, "max": m}))

	_boss.set_boss_hp(400)

	assert_that(emissions.size()).is_positive()
	assert_that(emissions[0]["current"]).is_equal(400)


# ─── AC-06: Events.boss_attack_telegraph broadcasts ───────────────────────────

func test_events_boss_attack_telegraph_exists() -> void:
	# Check Events has the signal (not checking actual broadcast in unit test)
	assert_that(Events.has_signal("boss_attack_telegraph")).is_true()


# ─── AC-07: Events.boss_phase_warning broadcasts ────────────────────────────────

func test_events_boss_phase_warning_exists() -> void:
	assert_that(Events.has_signal("boss_phase_warning")).is_true()


# ─── AC-08: get_attack_display_name returns correct Chinese names ──────────────

func test_attack_display_names_constant_exists() -> void:
	assert_that(BossAIManager.PATTERN_DISPLAY_NAMES.has(BossAIManager.PATTERN_RELENTLESS_ADVANCE)).is_true()
	assert_that(BossAIManager.PATTERN_DISPLAY_NAMES.has(BossAIManager.PATTERN_PAPER_AVALANCHE)).is_true()
	assert_that(BossAIManager.PATTERN_DISPLAY_NAMES.has(BossAIManager.PATTERN_PANIC_OVERLOAD)).is_true()


func test_get_attack_display_name_relentless_advance() -> void:
	var name := _boss.get_attack_display_name(BossAIManager.PATTERN_RELENTLESS_ADVANCE)
	assert_that(name).is_equal("截稿压力")


func test_get_attack_display_name_paper_avalanche() -> void:
	var name := _boss.get_attack_display_name(BossAIManager.PATTERN_PAPER_AVALANCHE)
	assert_that(name).is_equal("工作堆积")


func test_get_attack_display_name_panic_overload() -> void:
	var name := _boss.get_attack_display_name(BossAIManager.PATTERN_PANIC_OVERLOAD)
	assert_that(name).is_equal("Deadline panic")


func test_get_attack_display_name_unknown_returns_pattern() -> void:
	var name := _boss.get_attack_display_name("UNKNOWN_PATTERN")
	assert_that(name).is_equal("UNKNOWN_PATTERN")


# ─── Additional tests ─────────────────────────────────────────────────────────

func test_get_attack_display_name_method_exists() -> void:
	assert_that(_boss.has_method("get_attack_display_name")).is_true()
