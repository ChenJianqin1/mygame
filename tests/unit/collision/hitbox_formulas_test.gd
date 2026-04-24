# hitbox_formulas_test.gd — Unit tests for collision-006 hitbox formulas
# GdUnit4 test file
# Tests: F1-01, F1-02, F4-01, F4-02, edge cases

class_name HitboxFormulasTest
extends GdUnitTestSuite

# ─── F1-01: LIGHT attack player hitbox size ───────────────────────────────────

func test_hitbox_size_light_player() -> void:
	# AC-F1-01: base_size=(64,64), attack_type="LIGHT", entity_type="PLAYER"
	# Expected: Vector2(38.4, 38.4)
	# Formula: 64 * 0.6 * 1.0 = 38.4
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "LIGHT", "PLAYER")
	assert_that(result.x).is_equal(38.4)
	assert_that(result.y).is_equal(38.4)


# ─── F1-02: HEAVY attack Boss hitbox size ────────────────────────────────────

func test_hitbox_size_heavy_boss() -> void:
	# AC-F1-02: base_size=(64,64), attack_type="HEAVY", entity_type="BOSS"
	# Expected: Vector2(192, 192)
	# Formula: 64 * 1.5 * 2.0 = 192
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "HEAVY", "BOSS")
	assert_that(result.x).is_equal(192.0)
	assert_that(result.y).is_equal(192.0)


# ─── Additional attack type tests ───────────────────────────────────────────────

func test_hitbox_size_medium_player() -> void:
	# MEDIUM: 64 * 1.0 * 1.0 = 64
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "MEDIUM", "PLAYER")
	assert_that(result.x).is_equal(64.0)
	assert_that(result.y).is_equal(64.0)


func test_hitbox_size_special_player() -> void:
	# SPECIAL: 64 * 2.0 * 1.0 = 128
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "SPECIAL", "PLAYER")
	assert_that(result.x).is_equal(128.0)
	assert_that(result.y).is_equal(128.0)


func test_hitbox_size_light_boss() -> void:
	# LIGHT * BOSS: 64 * 0.6 * 2.0 = 76.8
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "LIGHT", "BOSS")
	assert_that(result.x).is_equal(76.8)
	assert_that(result.y).is_equal(76.8)


func test_hitbox_size_special_boss() -> void:
	# SPECIAL * BOSS: 64 * 2.0 * 2.0 = 256
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "SPECIAL", "BOSS")
	assert_that(result.x).is_equal(256.0)
	assert_that(result.y).is_equal(256.0)


# ─── F4-01: Single player/boss max hitboxes ───────────────────────────────────

func test_max_hitboxes_single_player_boss() -> void:
	# AC-F4-01: player_count=1, boss_count=1
	# Expected: 1*4 + 1*6 + 2 = 12
	var result := CollisionManager.calculate_max_hitboxes(1, 1)
	assert_that(result).is_equal(12)


# ─── F4-02: Two player/boss max hitboxes ─────────────────────────────────────

func test_max_hitboxes_two_players_boss() -> void:
	# AC-F4-02: player_count=2, boss_count=1
	# Expected: 2*4 + 1*6 + 2 = 16
	# Note: 16 exceeds SAFE_MAX_CONCURRENT=13, should trigger warning
	var result := CollisionManager.calculate_max_hitboxes(2, 1)
	assert_that(result).is_equal(16)


# ─── Edge cases ───────────────────────────────────────────────────────────────

func test_hitbox_size_unknown_attack_type() -> void:
	# Unknown attack type defaults to 1.0 multiplier
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "UNKNOWN", "PLAYER")
	assert_that(result.x).is_equal(64.0)
	assert_that(result.y).is_equal(64.0)


func test_hitbox_size_unknown_entity_type() -> void:
	# Unknown entity type defaults to 1.0 multiplier
	var result := CollisionManager.calculate_hitbox_size(Vector2(64, 64), "LIGHT", "UNKNOWN")
	assert_that(result.x).is_equal(38.4)
	assert_that(result.y).is_equal(38.4)


func test_hitbox_size_custom_base() -> void:
	# Custom base size
	var result := CollisionManager.calculate_hitbox_size(Vector2(32, 32), "MEDIUM", "PLAYER")
	assert_that(result.x).is_equal(32.0)
	assert_that(result.y).is_equal(32.0)


func test_check_spawn_allowed_under_limit() -> void:
	# When active hitboxes < SAFE_MAX_CONCURRENT, spawn should be allowed
	# Note: This depends on current pool state
	var allowed := CollisionManager.check_spawn_allowed()
	# Initially should be allowed since pool is empty
	assert_that(allowed).is_true()


func test_max_hitboxes_zero_players() -> void:
	# Edge case: 0 players
	var result := CollisionManager.calculate_max_hitboxes(0, 1)
	assert_that(result).is_equal(8)  # 0*4 + 1*6 + 2 = 8


func test_max_hitboxes_zero_bosses() -> void:
	# Edge case: 0 bosses
	var result := CollisionManager.calculate_max_hitboxes(1, 0)
	assert_that(result).is_equal(6)  # 1*4 + 0*6 + 2 = 6
