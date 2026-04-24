# sync_attack_visual_test.gd — Integration tests for animation-004 Sync Attack Visual
# GdUnit4 test file
# Tests: AC-3.1, AC-3.2, AC-3.3

class_name SyncAttackVisualTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _integrator: AnimationSignalIntegrator

func before() -> void:
	_integrator = AnimationSignalIntegrator.new()
	add_child(_integrator)

func after() -> void:
	if is_instance_valid(_integrator):
		_integrator.free()


# ─── Constants ───────────────────────────────────────────────────────────────

func test_sync_window_duration_constant() -> void:
	assert_that(AnimationSignalIntegrator.SYNC_WINDOW_DURATION_FRAMES).is_equal(5)


func test_sync_glow_radius_multiplier_constant() -> void:
	assert_that(AnimationSignalIntegrator.SYNC_GLOW_RADIUS_MULTIPLIER).is_equal(1.15)


func test_sync_particle_count_constant() -> void:
	assert_that(AnimationSignalIntegrator.SYNC_PARTICLE_COUNT).is_equal(12)


func test_sync_charge_blend_rate_constant() -> void:
	assert_that(AnimationSignalIntegrator.SYNC_CHARGE_BLEND_RATE).is_equal(0.2)


func test_screen_edge_pulse_frequency_constant() -> void:
	assert_that(AnimationSignalIntegrator.SCREEN_EDGE_PULSE_FREQUENCY).is_equal(2.0)


# ─── AC-3.1: Sync burst particles (orange + blue) ───────────────────────────

func test_sync_burst_visual_signal_exists() -> void:
	assert_that(_integrator.has_signal("sync_burst_visual")).is_true()


func test_sync_burst_signal_re_emits() -> void:
	var emissions: Array = []
	_integrator.sync_burst_visual.connect(func(pos): emissions.append(pos))

	# Simulate sync burst triggered
	Events.sync_burst_triggered.emit(Vector2(400, 360))

	# Should have re-emitted the signal
	assert_that(emissions.size()).is_positive()
	assert_that(emissions[0]).is_equal(Vector2(400, 360))


# ─── AC-3.2: Sync charge glow on P2 ───────────────────────────────────────

func test_sync_window_opened_signal_handler_exists() -> void:
	assert_that(_integrator.has_method("_on_sync_window_opened")).is_true()


func test_p2_sync_charge_method_exists() -> void:
	assert_that(_integrator.has_method("_apply_p2_sync_charge")).is_true()


func test_sync_charge_fade_method_exists() -> void:
	assert_that(_integrator.has_method("_fade_sync_charge_glow")).is_true()


# ─── AC-3.3: Sync attack hitbox expansion ─────────────────────────────────

func test_set_hitbox_expansion_method_exists() -> void:
	assert_that(_integrator.has_method("set_sync_hitbox_expansion")).is_true()


func test_hitbox_expansion_active_flag_exists() -> void:
	# Should start with no expansion
	assert_that(_integrator._sync_hitbox_expansion_active).is_false()


# ─── Screen edge pulse ─────────────────────────────────────────────────────────

func test_screen_edge_pulse_method_exists() -> void:
	assert_that(_integrator.has_method("_trigger_screen_edge_pulse")).is_true()


func test_screen_edge_pulse_signal_exists() -> void:
	assert_that(_integrator.has_signal("screen_edge_pulse")).is_true()


# ─── Sync charge blend calculation ─────────────────────────────────────────────

func test_sync_charge_blend_calculation() -> void:
	# Blend = clamp((P1_hit_time - P2_anticipation_start_time) / SYNC_WINDOW_DURATION, 0.0, 1.0)
	# At 0 frames: blend = 0
	# At 5 frames: blend = 1
	# At 2.5 frames: blend = 0.5
	var blend_0 := _integrator._calculate_sync_charge_blend(0.0, 0.0, 5)
	assert_that(blend_0).is_equal(0.0)

	var blend_5 := _integrator._calculate_sync_charge_blend(5.0, 0.0, 5)
	assert_that(blend_5).is_equal(1.0)

	var blend_2_5 := _integrator._calculate_sync_charge_blend(2.5, 0.0, 5)
	assert_that(blend_2_5).is_equal(0.5)


# ─── Additional integration tests ──────────────────────────────────────────────

func test_p1_sync_charge_method_exists() -> void:
	assert_that(_integrator.has_method("_apply_p1_sync_charge")).is_true()


func test_sync_state_variables_exist() -> void:
	assert_that(_integrator.has_method("_apply_p1_sync_charge")).is_true()
	assert_that(_integrator.has_method("_apply_p2_sync_charge")).is_true()
	assert_that(_integrator.has_method("_fade_sync_charge_glow")).is_true()


func test_p1_and_p2_anim_variables_exist() -> void:
	# The integrator should have P1 and P2 animation state machines
	assert_that(_integrator._p1_anim != null).is_true()
	assert_that(_integrator._p2_anim != null).is_true()


func test_sync_burst_triggers_hitbox_expansion() -> void:
	# When sync burst is triggered, hitbox expansion should activate
	Events.sync_burst_triggered.emit(Vector2(400, 360))

	# The expansion should be active briefly
	assert_that(_integrator._sync_hitbox_expansion_active).is_true()


func test_update_method_exists() -> void:
	assert_that(_integrator.has_method("update")).is_true()
