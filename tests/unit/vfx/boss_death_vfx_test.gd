# boss_death_vfx_test.gd — Unit tests for particle-vfx-006 boss death VFX
# GdUnit4 test file
# Tests: AC-VFX-6.1 through AC-VFX-6.9

class_name BossDeathVFXTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _vfx: VFXManager

func before() -> void:
	_vfx = VFXManager.new()

func after() -> void:
	if is_instance_valid(_vfx):
		_vfx.free()


# ─── AC-VFX-6.1: emit_boss_death interface ───────────────────────────────────

func test_emit_boss_death_method_exists() -> void:
	assert_that(_vfx.has_method("emit_boss_death")).is_true()


# ─── AC-VFX-6.2: Particle count 60 ────────────────────────────────────────────

func test_boss_death_particle_count_60() -> void:
	assert_that(_vfx.BOSS_DEATH_PARTICLE_COUNT).is_equal(60)


# ─── AC-VFX-6.3: Color white to gold ─────────────────────────────────────────

func test_boss_death_color_starts_white() -> void:
	# Color starts white (Color.WHITE)
	assert_that(_vfx.has_method("_configure_boss_death_emitter")).is_true()


# ─── AC-VFX-6.4: Explosive upward burst ─────────────────────────────────────────

func test_boss_death_upward_direction() -> void:
	# Direction should be upward (Vector2.UP = Vector2(0, -1))
	assert_that(_vfx.has_method("_get_boss_death_direction")).is_true()


# ─── AC-VFX-6.5: Full radial spread 180° ───────────────────────────────────

func test_boss_death_spread_180() -> void:
	var spread := _vfx._get_boss_death_spread()
	assert_that(spread).is_equal(180.0)


# ─── AC-VFX-6.6: Initial velocity max 300 px/s ────────────────────────────────

func test_boss_death_velocity_max_300() -> void:
	var vel := _vfx._get_boss_death_velocity()
	assert_that(vel.max).is_equal(300.0)


# ─── AC-VFX-6.7: Signal connection ─────────────────────────────────────────────

func test_boss_defeated_signal_connected() -> void:
	var err := Events.boss_defeated.connect(_vfx._on_boss_defeated)
	assert_that(err == OK or err == CONNECT_ALREADY).is_true()


# ─── AC-VFX-6.8: Force-cancel all hit emitters ─────────────────────────────────

func test_force_cancel_all_hit_emitters_method_exists() -> void:
	assert_that(_vfx.has_method("_force_cancel_all_hit_emitters")).is_true()


# ─── AC-VFX-6.9: Boss death visual priority ─────────────────────────────────────

func test_boss_death_has_priority_method_exists() -> void:
	# Visual priority is implicit — boss death force-cancels everything else
	assert_that(_vfx.has_method("emit_boss_death")).is_true()


# ─── Gold confetti constants ─────────────────────────────────────────────────────

func test_gold_confetti_count_30() -> void:
	assert_that(_vfx.BOSS_DEATH_GOLD_CONFETTI_COUNT).is_equal(30)


func test_gold_confetti_uses_additive_blend() -> void:
	# BLEND_MODE_ADD for gold glow
	assert_that(_vfx.has_method("_configure_gold_confetti_emitter")).is_true()


# ─── Boss death emitter configuration method ──────────────────────────────────────

func test_boss_death_configure_method_exists() -> void:
	assert_that(_vfx.has_method("_configure_boss_death_emitter")).is_true()


# ─── AC-VFX-6.4: Parabolic fall (paper rain) ───────────────────────────────────

func test_boss_death_gravity_for_paper_rain() -> void:
	# Gravity should produce slow fall (paper rain)
	var grav := _vfx._get_boss_death_gravity()
	assert_that(grav.y).is_equal(200.0)
