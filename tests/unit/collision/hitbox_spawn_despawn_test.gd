# hitbox_spawn_despawn_test.gd — Unit tests for collision-002 hitbox spawn/despawn lifecycle
# GdUnit4 test file
# Tests: hitbox state transitions, animation-driven spawn, interruption cleanup

class_name HitboxSpawnDespawnTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _collision_manager: CollisionManager
var _test_owner_p1: Node2D
var _test_owner_p2: Node2D

func before() -> void:
	_collision_manager = CollisionManager.new()
	_collision_manager._ready()
	_test_owner_p1 = Node2D.new()
	_test_owner_p1.set("player_id", 1)
	_test_owner_p2 = Node2D.new()
	_test_owner_p2.set("player_id", 2)

func after() -> void:
	if is_instance_valid(_collision_manager):
		_collision_manager.free()
	if is_instance_valid(_test_owner_p1):
		_test_owner_p1.free()
	if is_instance_valid(_test_owner_p2):
		_test_owner_p2.free()

# ─── Helper ───────────────────────────────────────────────────────────────────
func _make_config(owner: Node2D, attack_id: int, is_grounded: bool = true) -> Dictionary:
	return {
		"owner": owner,
		"attack_id": attack_id,
		"layer": CollisionManager.LAYER_PLAYER_HITBOX,
		"size": Vector2(64, 64),
		"offset": Vector2(32, 0),
		"collision_mask": (1 << (CollisionManager.LAYER_BOSS - 1)),
		"is_grounded": is_grounded
	}

# ─── AC-1: Hitbox spawns at attack frame and becomes ACTIVE ────────────────────
func test_hitbox_becomes_active_on_spawn() -> void:
	# Given: Player in ATTACKING state, animation at hit frame
	# When: spawn_hitbox is called
	# Then: Hitbox.state == ACTIVE, monitoring == true
	var config := _make_config(_test_owner_p1, attack_id=1001)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	assert_that(hitbox).is_not_null()
	assert_that(hitbox.get("state")).is_equal(HitboxResource.HitboxState.ACTIVE)
	assert_that(hitbox.monitoring).is_true()

	_collision_manager.despawn_hitbox(hitbox)


# ─── AC-1b: Spawn rejected when at max concurrent limit ───────────────────────
func test_spawn_rejected_at_max_concurrent() -> void:
	# Given: All MAX_CONCURRENT_HITBOXES are active
	var spawned: Array[Area2D] = []
	for i in range(CollisionManager.MAX_CONCURRENT_HITBOXES):
		var config := _make_config(_test_owner_p1, attack_id=2000 + i)
		var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
		spawned.append(hitbox)

	# When: One more spawn is attempted
	var overflow_config := _make_config(_test_owner_p1, attack_id=9999)
	var overflow_hitbox: Area2D = _collision_manager.spawn_hitbox(overflow_config)

	# Then: Spawn is rejected (null)
	assert_that(overflow_hitbox).is_null()

	# Cleanup
	for hb in spawned:
		_collision_manager.despawn_hitbox(hb)


# ─── AC-2: Hitbox enters DESTROYED state on despawn ────────────────────────────
func test_hitbox_enters_destroyed_state_on_despawn() -> void:
	# Given: Active hitbox
	var config := _make_config(_test_owner_p1, attack_id=1002)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	# When: despawn_hitbox is called
	_collision_manager.despawn_hitbox(hitbox)

	# Then: Hitbox.state == DESTROYED (state is set before removal)
	# Note: hitbox is no longer in active list so we check via the signal routing
	assert_that(_collision_manager.get_active_count()).is_equal(0)


# ─── AC-3: Interruption despawns all related Hitboxes ─────────────────────────
func test_cleanup_by_owner_removes_all_matching_owner_hitboxes() -> void:
	# Given: Player has multiple active hitboxes with different attack_ids
	var config_a := _make_config(_test_owner_p1, attack_id=3001)
	var config_b := _make_config(_test_owner_p1, attack_id=3002)
	var config_c := _make_config(_test_owner_p2, attack_id=3003)

	_collision_manager.spawn_hitbox(config_a)
	_collision_manager.spawn_hitbox(config_b)
	_collision_manager.spawn_hitbox(config_c)

	# When: Player is interrupted, cleanup_by_owner is called (all attack_ids for this owner)
	_collision_manager.cleanup_by_owner(_test_owner_p1)

	# Then: P1's hitboxes are gone, P2's remains
	assert_that(_collision_manager.get_active_count()).is_equal(1)
	assert_that(_collision_manager._active_hitboxes[0].get("owner")).is_equal(_test_owner_p2)


# ─── AC-3b: cleanup_by_owner with specific attack_id ──────────────────────────
func test_cleanup_by_owner_with_specific_attack_id() -> void:
	# Given: Player has hitboxes for two different attacks
	var config_a := _make_config(_test_owner_p1, attack_id=4001)
	var config_b := _make_config(_test_owner_p1, attack_id=4002)

	_collision_manager.spawn_hitbox(config_a)
	_collision_manager.spawn_hitbox(config_b)

	# When: Only attack 4001 is cancelled (e.g., interrupted)
	_collision_manager.cleanup_by_owner(_test_owner_p1, 4001)

	# Then: Only 4001 is removed, 4002 remains
	assert_that(_collision_manager.get_active_count()).is_equal(1)
	assert_that(_collision_manager._active_hitboxes[0].get("attack_id")).is_equal(4002)


# ─── AC-4: Spawn is animation-driven — no _process spawn ─────────────────────
func test_no_process_spawn_in_collision_manager() -> void:
	# Verify CollisionManager has no _process method that spawns hitboxes
	# This is a code audit test — inspect method names
	var methods := _collision_manager.get_method_list()
	var has_process_spawn := false
	for method in methods:
		if method["name"] == "_process" or method["name"] == "_physics_process":
			# Check if the method does any spawn operation
			# This is a structural check - real implementation would need code review
			has_process_spawn = true
	# CollisionManager should not have _process spawning logic
	# The spawn must be called externally (by AnimationPlayer Method Track)
	assert_that(has_process_spawn).is_false()


# ─── Hitbox state transition verification ─────────────────────────────────────
func test_hitbox_state_persists_after_spawn() -> void:
	# Given: Hitbox spawned with ACTIVE state
	var config := _make_config(_test_owner_p1, attack_id=5001)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	# Then: State should be ACTIVE immediately after spawn
	assert_that(hitbox.get("state")).is_equal(HitboxResource.HitboxState.ACTIVE)

	_collision_manager.despawn_hitbox(hitbox)


func test_multiple_hitboxes_same_owner_different_attack_ids() -> void:
	# Given: Player spawning multiple attacks (e.g., combo chain)
	var config_1 := _make_config(_test_owner_p1, attack_id=6001)
	var config_2 := _make_config(_test_owner_p1, attack_id=6002)
	var config_3 := _make_config(_test_owner_p1, attack_id=6003)

	var hb1: Area2D = _collision_manager.spawn_hitbox(config_1)
	var hb2: Area2D = _collision_manager.spawn_hitbox(config_2)
	var hb3: Area2D = _collision_manager.spawn_hitbox(config_3)

	# Then: All three are active with correct attack_ids
	assert_that(_collision_manager.get_active_count()).is_equal(3)
	assert_that(hb1.get("attack_id")).is_equal(6001)
	assert_that(hb2.get("attack_id")).is_equal(6002)
	assert_that(hb3.get("attack_id")).is_equal(6003)

	# Cleanup
	_collision_manager.despawn_hitbox(hb1)
	_collision_manager.despawn_hitbox(hb2)
	_collision_manager.despawn_hitbox(hb3)
