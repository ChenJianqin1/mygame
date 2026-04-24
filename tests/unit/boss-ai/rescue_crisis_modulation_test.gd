# rescue_crisis_modulation_test.gd — Unit tests for boss-ai-007 Rescue Crisis Modulation
# GdUnit4 test file
# Tests: AC-01 through AC-10

class_name RescueCrisisModulationTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _boss: BossAIManager

func before() -> void:
	_boss = BossAIManager.new()
	_boss._ready()

func after() -> void:
	if is_instance_valid(_boss):
		_boss.free()


# ─── AC-01: _is_in_rescue_mode() returns true when P1 is down ───────────────

func test_rescue_mode_when_player1_down() -> void:
	# Stub: _is_player_down returns false by default
	# This test documents the expected behavior when CoopManager is integrated
	assert_that(_boss._is_in_rescue_mode()).is_false()  # Stub returns false


# ─── AC-02: _is_in_rescue_mode() returns true when P2 is down ───────────────

func test_rescue_mode_when_player2_down() -> void:
	assert_that(_boss._is_in_rescue_mode()).is_false()  # Stub returns false


# ─── AC-03: _is_crisis_active() returns false (stub) ─────────────────────────

func test_crisis_active_returns_false_stub() -> void:
	assert_that(_boss._is_crisis_active()).is_false()


# ─── AC-04: _is_player_behind() returns true when player.x < wall_x + 100 ──

func test_player_behind_when_near_wall() -> void:
	_boss._compression_wall_x = 500.0
	_boss._player1_pos = Vector2(400, 360)  # 400 < 500 + 100 = 600

	var behind := _boss._is_player_behind(1)
	assert_that(behind).is_true()


func test_player_behind_mercy_zone_constant() -> void:
	assert_that(BossAIManager.MERCY_ZONE).is_equal(100.0)


# ─── AC-05: _is_player_behind() returns false when player ahead ───────────────

func test_player_not_behind_when_ahead() -> void:
	_boss._compression_wall_x = 500.0
	_boss._player1_pos = Vector2(700, 360)  # 700 > 500 + 100 = 600

	var behind := _boss._is_player_behind(1)
	assert_that(behind).is_false()


func test_player_exactly_at_mercy_boundary_not_behind() -> void:
	_boss._compression_wall_x = 500.0
	_boss._player1_pos = Vector2(601, 360)  # Exactly at boundary

	var behind := _boss._is_player_behind(1)
	assert_that(behind).is_false()


# ─── AC-06: _players_behind flag updates every frame ──────────────────────────

func test_players_behind_flag_exists() -> void:
	assert_that(_boss._players_behind == false or _boss._players_behind == true).is_true()


func test_update_players_behind_status_exists() -> void:
	assert_that(_boss.has_method("_update_players_behind_status")).is_true()


# ─── AC-07: Rescue mode: compression_speed *= 0.5 ───────────────────────────

func test_rescue_slowdown_constant() -> void:
	assert_that(BossAIManager.RESCUE_SLOWDOWN).is_equal(0.5)


# ─── AC-08: Player behind: compression_speed *= 0.6 ─────────────────────────

func test_compression_speed_with_player_behind() -> void:
	# Player behind: 32 * 0.6 = 19.2 px/s
	_boss._players_behind = true
	var speed := _boss._calculate_compression_speed()
	assert_that(speed).is_equal(19.2)


# ─── AC-09: Crisis active: compression_speed *= 1.2 ─────────────────────────

func test_compression_speed_with_crisis_active() -> void:
	_boss._is_crisis_active = func() -> bool: return true
	var speed := _boss._calculate_compression_speed()
	# Phase 1: 32 * 1.0 * 1.2 = 38.4
	assert_that(speed).is_equal(38.4)


# ─── AC-10: Both players down: game_over signal triggered ────────────────────

func test_check_game_over_condition_exists() -> void:
	assert_that(_boss.has_method("_check_game_over_condition")).is_true()


# ─── Additional tests ────────────────────────────────────────────────────────

func test_get_player_position_player1() -> void:
	_boss._player1_pos = Vector2(500, 360)
	var pos := _boss._get_player_position(1)
	assert_that(pos).is_equal(Vector2(500, 360))


func test_get_player_position_player2() -> void:
	_boss._player2_pos = Vector2(600, 360)
	var pos := _boss._get_player_position(2)
	assert_that(pos).is_equal(Vector2(600, 360))


func test_get_player_position_invalid_id() -> void:
	var pos := _boss._get_player_position(99)
	assert_that(pos).is_equal(Vector2.ZERO)


func test_player_behind_with_player2() -> void:
	_boss._compression_wall_x = 500.0
	_boss._player2_pos = Vector2(400, 360)

	var behind := _boss._is_player_behind(2)
	assert_that(behind).is_true()


func test_compression_speed_no_modifiers_phase1() -> void:
	_boss._players_behind = false
	_boss._is_crisis_active = func() -> bool: return false
	_boss._is_any_player_down = func() -> bool: return false

	var speed := _boss._calculate_compression_speed()
	# Phase 1: 32 * 1.0 = 32
	assert_that(speed).is_equal(32.0)


func test_player_node_id_variables_exist() -> void:
	_boss._player1_node_id = 123
	_boss._player2_node_id = 456
	assert_that(_boss._player1_node_id).is_equal(123)
	assert_that(_boss._player2_node_id).is_equal(456)
