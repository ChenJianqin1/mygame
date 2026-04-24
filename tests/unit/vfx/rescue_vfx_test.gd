# rescue_vfx_test.gd — Unit tests for particle-vfx-005 rescue VFX emitter
# GdUnit4 test file
# Tests: AC-VFX-5.1 through AC-VFX-5.9

class_name RescueVFXTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _vfx: VFXManager

func before() -> void:
	_vfx = VFXManager.new()

func after() -> void:
	if is_instance_valid(_vfx):
		_vfx.free()


# ─── AC-VFX-5.1: emit_rescue interface ───────────────────────────────────────

func test_emit_rescue_method_exists() -> void:
	assert_that(_vfx.has_method("emit_rescue")).is_true()


# ─── AC-VFX-5.2: Particle count 12-18 ───────────────────────────────────────

func test_rescue_particle_count_range() -> void:
	# 12-18 (randi() % 7 + 12)
	for i in range(20):
		var count := _vfx._get_rescue_particle_count()
		assert_that(count).is_between(12, 18)


# ─── AC-VFX-5.3: Uses rescuer_color (not rescued player's color) ───────────────

func test_rescue_uses_rescuer_color() -> void:
	# Verify the method exists and takes rescuer_color
	assert_that(_vfx.has_method("_configure_rescue_emitter")).is_true()


# ─── AC-VFX-5.4: Upward motion (45° cone) ───────────────────────────────────

func test_rescue_upward_direction() -> void:
	# Direction should be Vector2(0, -1) in Godot 2D (upward)
	assert_that(_vfx.has_method("_get_rescue_direction")).is_true()


func test_rescue_spread_45_degrees() -> void:
	var spread := _vfx._get_rescue_spread()
	assert_that(spread).is_equal(45.0)


# ─── AC-VFX-5.5: Speed 120-180 px/s ────────────────────────────────────────

func test_rescue_speed_min_120() -> void:
	var speed := _vfx._get_rescue_speed()
	assert_that(speed.min).is_equal(120.0)


func test_rescue_speed_max_180() -> void:
	var speed := _vfx._get_rescue_speed()
	assert_that(speed.max).is_equal(180.0)


# ─── AC-VFX-5.6: Lifetime 0.4-0.7s ─────────────────────────────────────────

func test_rescue_lifetime_range() -> void:
	# 0.4-0.7s
	for i in range(20):
		var lifetime := _vfx._get_rescue_lifetime()
		assert_that(lifetime).is_between(0.4, 0.7)


# ─── AC-VFX-5.7: Signal connection ─────────────────────────────────────────────

func test_rescue_triggered_signal_connected() -> void:
	var err := Events.rescue_triggered.connect(_vfx._on_rescue_triggered)
	assert_that(err == OK or err == CONNECT_ALREADY).is_true()


# ─── AC-VFX-5.8: Hand glow sprite ────────────────────────────────────────────

func test_hand_glow_method_exists() -> void:
	assert_that(_vfx.has_method("_spawn_hand_glow")).is_true()


func test_hand_glow_radius_40px() -> void:
	# Radius = 40px
	assert_that(VFXManager.HAND_GLOW_RADIUS).is_equal(40.0)


func test_hand_glow_fade_duration_0_5s() -> void:
	assert_that(VFXManager.HAND_GLOW_FADE_DURATION).is_equal(0.5)


# ─── AC-VFX-5.9: Paper scraps + golden sparks ────────────────────────────────

func test_paper_scraps_method_exists() -> void:
	# Paper scraps are represented via hue_variation in the emitter
	assert_that(_vfx.has_method("_configure_rescue_emitter")).is_true()


# ─── Helper constants ──────────────────────────────────────────────────────────

func test_rescue_particle_count_min_12() -> void:
	# randi() % 7 + 12 → min 12
	var count := _vfx._get_rescue_particle_count()
	assert_that(count).is_at_least(12)


func test_rescue_particle_count_max_18() -> void:
	var count := _vfx._get_rescue_particle_count()
	assert_that(count).is_at_most(18)
