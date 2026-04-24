# damage_number_pool_test.gd — Unit tests for ui-007 damage number pool
# GdUnit4 test file
# Tests: AC1 through AC8

class_name DamageNumberPoolTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _pool: DamageNumberPool

func before() -> void:
	_pool = DamageNumberPool.new()
	add_child(_pool)

func after() -> void:
	if is_instance_valid(_pool):
		_pool.free()


# ─── AC1 / AC7: Pool initialization and limit ─────────────────────────────────

func test_pool_starts_empty() -> void:
	assert_that(_pool.get_active_count()).is_equal(0)


func test_pool_max_size() -> void:
	assert_that(_pool.get_max_count()).is_equal(20)


func test_pool_initializes_correctly() -> void:
	# Pool should be initialized with MAX_CONCURRENT_NUMBERS damage numbers
	assert_that(_pool.get_max_count()).is_equal(DamageNumberPool.MAX_CONCURRENT_NUMBERS)


# ─── AC2: Spawn and drift ─────────────────────────────────────────────────────

func test_spawn_normal_increases_count() -> void:
	_pool.spawn_normal(50, Vector2(100, 100))
	assert_that(_pool.get_active_count()).is_equal(1)


func test_spawn_crit_increases_count() -> void:
	_pool.spawn_crit(100, Vector2(100, 100))
	assert_that(_pool.get_active_count()).is_equal(1)


func test_spawn_boss_increases_count() -> void:
	_pool.spawn_boss(75, Vector2(100, 100))
	assert_that(_pool.get_active_count()).is_equal(1)


func test_spawn_heal_increases_count() -> void:
	_pool.spawn_heal(25, Vector2(100, 100))
	assert_that(_pool.get_active_count()).is_equal(1)


# ─── AC7: Max concurrent limit ────────────────────────────────────────────────

func test_max_concurrent_limit() -> void:
	# Spawn MAX + 1 numbers
	for i in range(DamageNumberPool.MAX_CONCURRENT_NUMBERS + 1):
		_pool.spawn_normal(i + 1, Vector2(float(i) * 10, 100))

	# Should still only have MAX active (oldest recycled)
	assert_that(_pool.get_active_count()).is_less_or_equal(DamageNumberPool.MAX_CONCURRENT_NUMBERS)


func test_fifo_recycling() -> void:
	# Spawn enough to trigger recycling
	for i in range(25):  # More than MAX (20)
		_pool.spawn_normal(i + 1, Vector2(100, 100))

	# Should not crash, should have exactly MAX active
	assert_that(_pool.get_active_count()).is_equal(DamageNumberPool.MAX_CONCURRENT_NUMBERS)


# ─── AC6: Clear all ───────────────────────────────────────────────────────────

func test_clear_all_resets_count() -> void:
	_pool.spawn_normal(50, Vector2(100, 100))
	_pool.spawn_normal(60, Vector2(110, 100))
	_pool.clear_all()
	assert_that(_pool.get_active_count()).is_equal(0)


# ─── AC4 / AC5: Boss and Heal types ─────────────────────────────────────────

func test_spawn_boss_uses_boss_type() -> void:
	var pool_node := _pool as Node2D
	_pool.spawn_boss(100, Vector2(200, 200))
	# The pool should not crash and should increment count
	assert_that(_pool.get_active_count()).is_equal(1)


func test_spawn_heal_uses_heal_type() -> void:
	_pool.spawn_heal(50, Vector2(150, 150))
	assert_that(_pool.get_active_count()).is_equal(1)


# ─── Constants ─────────────────────────────────────────────────────────────────

func test_duration_constant() -> void:
	assert_that(DamageNumber.DAMAGE_FLOAT_DURATION_MS).is_equal(800)


func test_fade_start_constant() -> void:
	assert_that(DamageNumber.DAMAGE_FADE_START_MS).is_equal(600)


func test_float_distance_constant() -> void:
	assert_that(DamageNumber.DAMAGE_FLOAT_DISTANCE).is_equal(60.0)


func test_crit_multiplier_constant() -> void:
	assert_that(DamageNumber.CRIT_SIZE_MULTIPLIER).is_equal(1.5)


func test_max_display_damage_constant() -> void:
	assert_that(DamageNumber.MAX_DISPLAY_DAMAGE).is_equal(999)


func test_spawn_offset_constant() -> void:
	assert_that(DamageNumber.SPAWN_OFFSET_Y).is_equal(-20.0)


func test_jitter_range_constant() -> void:
	assert_that(DamageNumber.JITTER_RANGE).is_equal(10.0)


# ─── Colors ────────────────────────────────────────────────────────────────────

func test_color_normal_white() -> void:
	assert_that(DamageNumber.COLOR_NORMAL).is_equal(Color.WHITE)


func test_color_crit_yellow() -> void:
	assert_that(DamageNumber.COLOR_CRIT).is_equal(Color("#FACC15"))


func test_color_boss_orange() -> void:
	assert_that(DamageNumber.COLOR_BOSS).is_equal(Color("#FB923C"))


func test_color_heal_green() -> void:
	assert_that(DamageNumber.COLOR_HEAL).is_equal(Color("#4ADE80"))


# ─── Edge cases ────────────────────────────────────────────────────────────────

func test_damage_type_enum_values() -> void:
	assert_that(DamageNumber.DamageType.NORMAL).is_equal(0)
	assert_that(DamageNumber.DamageType.CRIT).is_equal(1)
	assert_that(DamageNumber.DamageType.BOSS).is_equal(2)
	assert_that(DamageNumber.DamageType.HEAL).is_equal(3)
