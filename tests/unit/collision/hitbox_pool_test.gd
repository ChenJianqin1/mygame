# hitbox_pool_test.gd — Unit tests for CollisionManager hitbox pool
# Implements ADR-ARCH-002 validation criteria
# Tests: pool checkout/checkin, max concurrent limit, cleanup by owner

class_name HitboxPoolTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _collision_manager: CollisionManager
var _test_owner_p1: Node2D
var _test_owner_p2: Node2D

func before() -> void:
	## Set up a clean CollisionManager instance for each test
	_collision_manager = CollisionManager.new()
	_collision_manager._ready()

	## Create minimal owner nodes for testing
	_test_owner_p1 = Node2D.new()
	_test_owner_p1.set("player_id", 1)
	_test_owner_p2 = Node2D.new()
	_test_owner_p2.set("player_id", 2)

func after() -> void:
	## Clean up
	if is_instance_valid(_collision_manager):
		_collision_manager.free()
	if is_instance_valid(_test_owner_p1):
		_test_owner_p1.free()
	if is_instance_valid(_test_owner_p2):
		_test_owner_p2.free()

# ─── Pool Size Tests ───────────────────────────────────────────────────────────
func test_pool_initializes_with_full_size() -> void:
	## ARRANGE & ACT
	var pool_size := _collision_manager._pool.size()

	## ASSERT
	assert_that(pool_size).is_equal(CollisionManager.POOL_SIZE)

func test_pool_starts_empty_on_spawn() -> void:
	## ARRANGE — spawn one hitbox
	var config := _make_config(_test_owner_p1, attack_id=100)
	_collision_manager.spawn_hitbox(config)

	## ASSERT — pool count decreases by 1
	var pool_remaining := _collision_manager._pool.size()
	assert_that(pool_remaining).is_equal(CollisionManager.POOL_SIZE - 1)

# ─── Checkout / Checkin Tests ──────────────────────────────────────────────────
func test_spawn_hitbox_returns_valid_area2d() -> void:
	## ARRANGE
	var config := _make_config(_test_owner_p1, attack_id=1)

	## ACT
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	## ASSERT
	assert_that(hitbox).is_not_null()
	assert_that(hitbox).is_instance_of(Area2D)

func test_despawn_hitbox_returns_to_pool() -> void:
	## ARRANGE
	var config := _make_config(_test_owner_p1, attack_id=2)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
	var pool_before := _collision_manager._pool.size()

	## ACT
	_collision_manager.despawn_hitbox(hitbox)

	## ASSERT
	assert_that(_collision_manager._pool.size()).is_equal(pool_before + 1)

func test_spawn_despawn_cycle_preserves_pool_integrity() -> void:
	## ARRANGE & ACT — spawn and despawn multiple hitboxes
	for i in range(5):
		var config := _make_config(_test_owner_p1, attack_id=10 + i)
		var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
		_collision_manager.despawn_hitbox(hitbox)

	## ASSERT — pool should be back to full size
	assert_that(_collision_manager._pool.size()).is_equal(CollisionManager.POOL_SIZE)

# ─── Max Concurrent Limit Tests ────────────────────────────────────────────────
func test_max_concurrent_hitboxes_enforced() -> void:
	## ARRANGE — spawn up to the max
	var spawned: Array[Area2D] = []
	for i in range(CollisionManager.MAX_CONCURRENT_HITBOXES):
		var config := _make_config(_test_owner_p1, attack_id=1000 + i)
		var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
		spawned.append(hitbox)

	## ACT — try to spawn one more
	var config_over := _make_config(_test_owner_p1, attack_id=9999)
	var overflow_hitbox: Area2D = _collision_manager.spawn_hitbox(config_over)

	## ASSERT — overflow should be rejected
	assert_that(overflow_hitbox).is_null()
	assert_that(_collision_manager.get_active_count()).is_equal(CollisionManager.MAX_CONCURRENT_HITBOXES)

	## CLEANUP
	for hb in spawned:
		_collision_manager.despawn_hitbox(hb)

func test_active_count_reflects_spawned_hitboxes() -> void:
	## ARRANGE & ACT
	var config := _make_config(_test_owner_p1, attack_id=200)
	_collision_manager.spawn_hitbox(config)

	## ASSERT
	assert_that(_collision_manager.get_active_count()).is_equal(1)

func test_active_count_decreases_on_despawn() -> void:
	## ARRANGE
	var config := _make_config(_test_owner_p1, attack_id=201)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	## ACT
	_collision_manager.despawn_hitbox(hitbox)

	## ASSERT
	assert_that(_collision_manager.get_active_count()).is_equal(0)

# ─── Cleanup by Owner Tests ────────────────────────────────────────────────────
func test_cleanup_by_owner_removes_matching_hitboxes() -> void:
	## ARRANGE — spawn hitboxes for two owners
	var config_p1_1 := _make_config(_test_owner_p1, attack_id=301)
	var config_p1_2 := _make_config(_test_owner_p1, attack_id=302)
	var config_p2_1 := _make_config(_test_owner_p2, attack_id=401)

	_collision_manager.spawn_hitbox(config_p1_1)
	_collision_manager.spawn_hitbox(config_p1_2)
	_collision_manager.spawn_hitbox(config_p2_1)

	## ACT — cleanup P1's hitboxes
	_collision_manager.cleanup_by_owner(_test_owner_p1, 301)
	_collision_manager.cleanup_by_owner(_test_owner_p1, 302)

	## ASSERT — P1 hitboxes gone, P2 remains
	assert_that(_collision_manager.get_active_count()).is_equal(1)
	assert_that(_collision_manager._active_hitboxes[0].get("owner")).is_equal(_test_owner_p2)

func test_cleanup_by_owner_idempotent() -> void:
	## ARRANGE
	var config := _make_config(_test_owner_p1, attack_id=500)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	## ACT — cleanup twice (second call should be no-op)
	_collision_manager.cleanup_by_owner(_test_owner_p1, 500)
	_collision_manager.cleanup_by_owner(_test_owner_p1, 500)

	## ASSERT — no crash, pool intact
	assert_that(_collision_manager._pool.size()).is_equal(CollisionManager.POOL_SIZE - 1)

# ─── Hitbox State Tests ────────────────────────────────────────────────────────
func test_hitbox_state_transitions_on_spawn() -> void:
	## ARRANGE
	var config := _make_config(_test_owner_p1, attack_id=600)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	## ASSERT — state should be ACTIVE
	assert_that(hitbox.get("state")).is_equal(HitboxResource.HitboxState.ACTIVE)

func test_hitbox_owner_and_attack_id_set_correctly() -> void:
	## ARRANGE
	var config := _make_config(_test_owner_p1, attack_id=700)

	## ACT
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	## ASSERT
	assert_that(hitbox.get("owner")).is_equal(_test_owner_p1)
	assert_that(hitbox.get("attack_id")).is_equal(700)

# ─── Helper Methods ────────────────────────────────────────────────────────────
## Factory to create a standard hitbox config dictionary
func _make_config(owner: Node2D, attack_id: int, is_grounded: bool = true) -> Dictionary:
	return {
		"owner": owner,
		"attack_id": attack_id,
		"layer": CollisionManager.LAYER_PLAYER_HITBOX,
		"size": Vector2(64, 64),
		"offset": Vector2(32, 0),
		"collision_mask": (1 << (CollisionManager.LAYER_BOSS - 1)),  # Detect Boss layer
		"is_grounded": is_grounded
	}
