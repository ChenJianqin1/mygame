# collision_detection_signals_test.gd — Unit tests for collision-003 collision detection signals
# GdUnit4 test file
# Tests: hit_confirmed signal, hitbox-level mutual exclusion, DESTROYED deferred queue

class_name CollisionDetectionSignalsTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _collision_manager: CollisionManager
var _test_owner: Node2D

func before() -> void:
	_collision_manager = CollisionManager.new()
	_collision_manager._ready()
	_test_owner = Node2D.new()

func after() -> void:
	if is_instance_valid(_collision_manager):
		_collision_manager.free()
	if is_instance_valid(_test_owner):
		_test_owner.free()


# ─── AC-1: hit_confirmed fires when PLAYER_HITBOX overlaps BOSS ──────────────

func test_hit_confirmed_signal_fires_on_area_enter() -> void:
	# Given: Spawned hitbox and a mock hurtbox area
	var config := _make_config(attack_id=1001)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
	var hurtbox: Area2D = _make_hurtbox()

	# Track signal emission
	var signal_fired := false
	var received_hitbox: Area2D
	var received_hurtbox: Area2D
	_collision_manager.hit_confirmed.connect(
		func(hb, hb_area, aid):
			signal_fired = true
			received_hitbox = hb
			received_hurtbox = hb_area
	)

	# When: area_entered is triggered (simulating collision)
	_hitbox_area_enter(hitbox, hurtbox)

	# Then: hit_confirmed fires with correct arguments
	assert_that(signal_fired).is_true()
	assert_that(received_hitbox).is_equal(hitbox)
	assert_that(received_hurtbox).is_equal(hurtbox)

	_collision_manager.despawn_hitbox(hitbox)


# ─── AC-2: Same Hitbox-Hurtbox pair does NOT trigger twice ───────────────────

func test_same_hitbox_hurtbox_no_double_hit() -> void:
	# Given: Hitbox already hit hurtbox once
	var config := _make_config(attack_id=1002)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
	var hurtbox: Area2D = _make_hurtbox()

	# Track hit count
	var hit_count := 0
	_collision_manager.hit_confirmed.connect(
		func(hb, hb_area, aid):
			hit_count += 1
	)

	# When: Same hitbox overlaps same hurtbox twice
	_hitbox_area_enter(hitbox, hurtbox)
	_hitbox_area_enter(hitbox, hurtbox)

	# Then: Only one hit_confirmed fires (second is blocked by _hit_hurtboxes)
	assert_that(hit_count).is_equal(1)

	_collision_manager.despawn_hitbox(hitbox)


# ─── AC-3: Different Hitboxes can hit same Hurtbox independently ──────────────

func test_different_hitboxes_hit_same_hurtbox_independently() -> void:
	# Given: Two different hitboxes, same hurtbox
	var config1 := _make_config(attack_id=2001)
	var config2 := _make_config(attack_id=2002)
	var hitbox1: Area2D = _collision_manager.spawn_hitbox(config1)
	var hitbox2: Area2D = _collision_manager.spawn_hitbox(config2)
	var hurtbox: Area2D = _make_hurtbox()

	# Track which hitboxes hit
	var hitboxes: Array = []
	_collision_manager.hit_confirmed.connect(
		func(hb, hb_area, aid):
			hitboxes.append(hb)
	)

	# When: Both hitboxes hit the same hurtbox
	_hitbox_area_enter(hitbox1, hurtbox)
	_hitbox_area_enter(hitbox2, hurtbox)

	# Then: Both hitboxes independently trigger hit_confirmed
	assert_that(hitboxes.size()).is_equal(2)
	assert_that(hitboxes).contains(hitbox1)
	assert_that(hitboxes).contains(hitbox2)

	_collision_manager.despawn_hitbox(hitbox1)
	_collision_manager.despawn_hitbox(hitbox2)


# ─── AC-4: DESTROYED hitbox stays in scene for frame N ─────────────────────

func test_destroyed_hitbox_not_immediately_removed_from_scene() -> void:
	# Given: Active hitbox
	var config := _make_config(attack_id=3001)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)

	# When: despawn_hitbox is called (marks DESTROYED)
	_collision_manager.despawn_hitbox(hitbox)

	# Then: Hitbox is NOT in _active_hitboxes (removed from collision tracking)
	assert_that(_collision_manager._active_hitboxes.has(hitbox)).is_false()

	# And: Hitbox is still in _pending_free (pending for next physics step)
	assert_that(_collision_manager._pending_free.has(hitbox)).is_true()

	# And: Hitbox state is DESTROYED
	assert_that(hitbox.get("state")).is_equal(HitboxResource.HitboxState.DESTROYED)


# ─── AC-5: queue_free executes in _physics_process ───────────────────────────

func test_pending_free_cleared_on_physics_process() -> void:
	# Given: Hitbox despawned and pending
	var config := _make_config(attack_id=4001)
	var hitbox: Area2D = _collision_manager.spawn_hitbox(config)
	_collision_manager.despawn_hitbox(hitbox)

	assert_that(_collision_manager._pending_free.size()).is_equal(1)

	# When: _physics_process runs
	_collision_manager._physics_process(0.0)

	# Then: _pending_free is cleared (hitbox queued for removal)
	assert_that(_collision_manager._pending_free.size()).is_equal(0)


# ─── Additional tests ──────────────────────────────────────────────────────────

func test_multiple_hitboxes_destroyed_same_frame() -> void:
	# Given: Multiple hitboxes spawned
	var configs := []
	var hitboxes := []
	for i in range(3):
		var cfg := _make_config(attack_id=5000 + i)
		var hb: Area2D = _collision_manager.spawn_hitbox(cfg)
		configs.append(cfg)
		hitboxes.append(hb)

	# When: All despawned simultaneously
	for hb in hitboxes:
		_collision_manager.despawn_hitbox(hb)

	# Then: All in pending_free
	assert_that(_collision_manager._pending_free.size()).is_equal(3)
	assert_that(_collision_manager._active_hitboxes.size()).is_equal(0)


func test_despawn_non_active_hitbox_warning() -> void:
	# Given: A hitbox that was never spawned
	var fake_hitbox: Area2D = Area2D.new()

	# When/Then: despawn_hitbox should push warning (not crash)
	_collision_manager.despawn_hitbox(fake_hitbox)

	fake_hitbox.free()


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_config(attack_id: int) -> Dictionary:
	return {
		"owner": _test_owner,
		"attack_id": attack_id,
		"layer": CollisionManager.LAYER_PLAYER_HITBOX,
		"size": Vector2(64, 64),
		"offset": Vector2.ZERO,
		"collision_mask": (1 << (CollisionManager.LAYER_BOSS - 1)),
		"is_grounded": true
	}

func _make_hurtbox() -> Area2D:
	var area := Area2D.new()
	area.set_script(load("res://src/collision/hitbox_resource.gd"))
	return area

## Simulate area_entered signal by directly invoking the handler
func _hitbox_area_enter(hitbox: Area2D, area: Area2D) -> void:
	# The hitbox's area_entered signal is connected to _on_hitbox_area_entered via bind
	# We call the handler directly to simulate the signal
	_hitbox_emit_area_entered(hitbox, area)

## Directly emit area_entered on the hitbox to trigger its callback chain
func _hitbox_emit_area_entered(hitbox: Area2D, area: Area2D) -> void:
	# Emit the area_entered signal — this triggers _on_area_entered via the connection in _ready()
	hitbox.emit_signal("area_entered", area)
