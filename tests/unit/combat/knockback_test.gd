# knockback_test.gd — Unit tests for combat-002 knockback system
# GdUnit4 test file
# Tests: knockback direction calculation, force magnitude, edge cases

class_name KnockbackTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _combat_manager: CombatManager
var _target: Node2D

func before() -> void:
	_combat_manager = CombatManager.new()
	_target = Node2D.new()
	_target.global_position = Vector2(200, 0)

func after() -> void:
	if is_instance_valid(_combat_manager):
		_combat_manager.free()
	if is_instance_valid(_target):
		_target.free()


# ─── AC-KB-001: Direction away from attacker ──────────────────────────────────

func test_knockback_direction_right() -> void:
	# Given: attacker=(100,0), target=(200,0)
	# When: apply_knockback is called
	# Then: direction = normalize((200-100, 0)) = (1, 0)
	_target.global_position = Vector2(200, 0)
	var attacker_pos := Vector2(100, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "LIGHT")

	# Knockback should be in positive X direction (away from attacker)
	assert_that(result.x).is_positive()
	assert_that(result.y).is_equal(0.0)


func test_knockback_direction_left() -> void:
	# Given: attacker=(200,0), target=(100,0)
	# When: apply_knockback is called
	# Then: direction = normalize((100-200, 0)) = (-1, 0)
	_target.global_position = Vector2(100, 0)
	var attacker_pos := Vector2(200, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "LIGHT")

	# Knockback should be in negative X direction (away from attacker)
	assert_that(result.x).is_negative()


# ─── AC-KB-010: LIGHT attack knockback force ───────────────────────────────────

func test_knockback_LIGHT_force() -> void:
	# Given: attack_type=LIGHT, direction=(1,0)
	# When: apply_knockback is called
	# Then: force = 50 * (1, 0) = (50, 0)
	_target.global_position = Vector2(200, 0)
	var attacker_pos := Vector2(100, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "LIGHT")

	assert_that(result.x).is_equal(50.0)
	assert_that(result.y).is_equal(0.0)


func test_knockback_HEAVY_force() -> void:
	# Given: attack_type=HEAVY, direction=(0,-1)
	# When: apply_knockback is called
	# Then: force = 200 * (0, -1) = (0, -200)
	_target.global_position = Vector2(0, 200)
	var attacker_pos := Vector2(0, 100)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "HEAVY")

	assert_that(result.x).is_equal(0.0)
	assert_that(result.y).is_equal(-200.0)


# ─── AC-KB-??? (edge case): Same position fallback ─────────────────────────────

func test_knockback_same_position_uses_fallback_direction() -> void:
	# Given: attacker and target at same position
	# When: apply_knockback is called
	# Then: uses fallback direction (1, 0)
	var attacker_pos := Vector2(100, 0)
	_target.global_position = Vector2(100, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "LIGHT")

	# Fallback direction is (1, 0), so force should be (50, 0) for LIGHT
	assert_that(result.x).is_equal(50.0)


# ─── Additional coverage tests ─────────────────────────────────────────────────

func test_knockback_MEDIUM_force() -> void:
	# Given: attack_type=MEDIUM
	# When: apply_knockback is called
	# Then: force = 100 * direction
	_target.global_position = Vector2(200, 0)
	var attacker_pos := Vector2(100, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "MEDIUM")

	assert_that(result.length()).is_equal(100.0)


func test_knockback_SPECIAL_force() -> void:
	# Given: attack_type=SPECIAL
	# When: apply_knockback is called
	# Then: force = 300 * direction
	_target.global_position = Vector2(200, 0)
	var attacker_pos := Vector2(100, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "SPECIAL")

	assert_that(result.length()).is_equal(300.0)


func test_knockback_diagonal_direction() -> void:
	# Given: attacker=(0,0), target=(100,100)
	# When: apply_knockback is called
	# Then: direction = normalize((100, 100)) ≈ (0.707, 0.707)
	_target.global_position = Vector2(100, 100)
	var attacker_pos := Vector2(0, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "LIGHT")

	# Direction should be normalized (length ≈ 1)
	var direction := result.normalized()
	assert_that(direction.x).is_close(0.707, 0.001)
	assert_that(direction.y).is_close(0.707, 0.001)
	# Force magnitude should be 50
	assert_that(result.length()).is_close(50.0, 0.001)


func test_knockback_invalid_attack_type_defaults_to_light() -> void:
	# Given: invalid attack_type
	# When: apply_knockback is called
	# Then: uses LIGHT force (50.0) as default
	_target.global_position = Vector2(200, 0)
	var attacker_pos := Vector2(100, 0)
	var result: Vector2 = _combat_manager.apply_knockback(_target, attacker_pos, "INVALID")

	# Should default to LIGHT knockback (50.0)
	assert_that(result.length()).is_equal(50.0)
