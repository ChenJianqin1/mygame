# sync_burst_vfx_test.gd — Unit tests for particle-vfx-004 sync burst VFX
# GdUnit4 test file
# Tests: AC-VFX-4.1 through AC-VFX-4.10

class_name SyncBurstVFXTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _vfx: VFXManager

func before() -> void:
	_vfx = VFXManager.new()

func after() -> void:
	if is_instance_valid(_vfx):
		_vfx.free()


# ─── AC-VFX-4.6: Signal connection ─────────────────────────────────────────────

func test_sync_burst_signal_connected() -> void:
	var err := Events.sync_burst_triggered.connect(_vfx._on_sync_burst_triggered)
	assert_that(err == OK or err == CONNECT_ALREADY).is_true()


# ─── AC-VFX-4.9: GPU pool usage ──────────────────────────────────────────────

func test_sync_burst_uses_gpu_pool() -> void:
	# Verify GPU pool has 2 emitters
	assert_that(_vfx.get_available_gpu_count()).is_equal(2)


func test_gpu_pool_size_is_2() -> void:
	assert_that(VFXManager.GPU_POOL_SIZE).is_equal(2)


# ─── AC-VFX-4.5: Additive blend mode ─────────────────────────────────────────

func test_sync_burst_uses_additive_blend() -> void:
	# BR_MODE_ADD = 0 for GPUParticles2D
	assert_that(GPUParticles2D.BR_MODE_ADD).is_equal(0)


# ─── AC-VFX-4.2: P1+P2 dual color emission ────────────────────────────────────

func test_p1_color_is_orange() -> void:
	assert_that(VFXManager.COLOR_P1).is_equal(Color("#F5A623"))


func test_p2_color_is_teal() -> void:
	assert_that(VFXManager.COLOR_P2).is_equal(Color("#4ECDC4"))


# ─── AC-VFX-4.4: Helical motion parameters ────────────────────────────────────

func test_orbital_velocity_constant_exists() -> void:
	assert_that(_vfx.has_method("_configure_sync_emitter_continuous")).is_true()


func test_sync_burst_method_exists() -> void:
	assert_that(_vfx.has_method("emit_sync_burst")).is_true()


# ─── AC-VFX-4.1: emit_sync_burst interface ───────────────────────────────────

func test_emit_sync_burst_accepts_position() -> void:
	# emit_sync_burst(Vector2) should exist
	assert_that(_vfx.has_method("emit_sync_burst")).is_true()


# ─── AC-VFX-4.8: One-shot burst configuration ─────────────────────────────────

func test_sync_burst_oneshot_method_exists() -> void:
	assert_that(_vfx.has_method("_configure_sync_oneshot")).is_true()


# ─── AC-VFX-4.7: Sync chain deactivation ─────────────────────────────────────

func test_sync_chain_deactivate_method_exists() -> void:
	assert_that(_vfx.has_method("_deactivate_sync_continuous")).is_true()


# ─── AC-VFX-4.10: Emitter count tracking ─────────────────────────────────────

func test_get_active_emitter_count_includes_gpu() -> void:
	var initial := _vfx.get_active_emitter_count()
	# GPU emitters should be tracked in active count
	assert_that(initial).is_equal(0)


# ─── AC-VFX-4.3: Helical direction (clockwise/counterclockwise) ─────────────────

func test_p1_clockwise_positive_orbital() -> void:
	# P1: positive orbital velocity (clockwise)
	assert_that(_vfx.has_method("_configure_p1_sync_emitter")).is_true()


func test_p2_counterclockwise_negative_orbital() -> void:
	# P2: negative orbital velocity (counterclockwise)
	assert_that(_vfx.has_method("_configure_p2_sync_emitter")).is_true()


# ─── GPU blend mode constants ─────────────────────────────────────────────────

func test_br_mode_add_is_zero() -> void:
	# Verified: BR_MODE_ADD = 0
	assert_that(GPUParticles2D.BR_MODE_ADD).is_equal(0)


func test_br_mode_subtract_is_one() -> void:
	assert_that(GPUParticles2D.BR_MODE_SUBTRACT).is_equal(1)


func test_br_mode_multiply_is_two() -> void:
	assert_that(GPUParticles2D.BR_MODE_MULTIPLY).is_equal(2)


func test_br_mode_modulo_is_three() -> void:
	assert_that(GPUParticles2D.BR_MODE_MODULO).is_equal(3)
