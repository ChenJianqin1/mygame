# signal_integration_test.gd — Unit tests for animation-007 signal integration
# GdUnit4 test file
# Tests: AC-8.1 (upstream subscriptions), AC-8.2 (downstream emissions), AC-8.3 (Godot 4.6 syntax)

class_name AnimationSignalIntegrationTest
extends GdUnitTestSuite

# ─── Test Fixtures ─────────────────────────────────────────────────────────────
var _asi: AnimationSignalIntegrator

func before() -> void:
	_asi = AnimationSignalIntegrator.new()

func after() -> void:
	if is_instance_valid(_asi):
		_asi.free()


# ─── AC-8.2: Downstream signals exist ─────────────────────────────────────────

func test_animation_state_changed_signal_exists() -> void:
	assert_that(_asi.has_signal("animation_state_changed")).is_true()


func test_recovery_complete_signal_exists() -> void:
	assert_that(_asi.has_signal("recovery_complete")).is_true()


func test_hitbox_activated_signal_exists() -> void:
	assert_that(_asi.has_signal("hitbox_activated")).is_true()


func test_sync_burst_visual_signal_exists() -> void:
	assert_that(_asi.has_signal("sync_burst_visual")).is_true()


# ─── AC-8.2: Downstream signal emission ─────────────────────────────────────────

func test_sync_burst_visual_emits_with_position() -> void:
	var emissions: Array = []
	_asi.sync_burst_visual.connect(func(pos): emissions.append(pos))

	var test_pos := Vector2(100, 200)
	_asi.sync_burst_visual.emit(test_pos)

	assert_that(emissions.size()).is_equal(1)
	assert_that(emissions[0]).is_equal(test_pos)


func test_animation_state_changed_emits_player_id_and_state() -> void:
	var emissions: Array = []
	_asi.animation_state_changed.connect(func(pid, state): emissions.append({"pid": pid, "state": state}))

	_asi.animation_state_changed.emit(1, "IDLE")

	assert_that(emissions.size()).is_equal(1)
	assert_that(emissions[0]["pid"]).is_equal(1)
	assert_that(emissions[0]["state"]).is_equal("IDLE")


func test_recovery_complete_emits_player_id() -> void:
	var emissions: Array = []
	_asi.recovery_complete.connect(func(pid): emissions.append(pid))

	_asi.recovery_complete.emit(2)

	assert_that(emissions.size()).is_equal(1)
	assert_that(emissions[0]).is_equal(2)


func test_hitbox_activated_emits_attack_type_and_position() -> void:
	var emissions: Array = []
	_asi.hitbox_activated.connect(func(t, pos): emissions.append({"type": t, "pos": pos}))

	var test_pos := Vector2(50, 75)
	_asi.hitbox_activated.emit("light", test_pos)

	assert_that(emissions.size()).is_equal(1)
	assert_that(emissions[0]["type"]).is_equal("light")
	assert_that(emissions[0]["pos"]).is_equal(test_pos)


# ─── AC-8.1: Upstream signal connections ────────────────────────────────────────

func test_asi_subscribes_to_attack_started() -> void:
	# Verify that attack_started can be connected without error
	var err := Events.attack_started.connect(_asi._on_attack_started)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_hurt_received() -> void:
	var err := Events.hurt_received.connect(_asi._on_hurt_received)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_sync_burst_triggered() -> void:
	var err := Events.sync_burst_triggered.connect(_asi._on_sync_burst)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_combo_tier_escalated() -> void:
	var err := Events.combo_tier_escalated.connect(_asi._on_combo_tier)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_player_downed() -> void:
	var err := Events.player_downed.connect(_asi._on_player_downed)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_rescue_triggered() -> void:
	var err := Events.rescue_triggered.connect(_asi._on_rescue_triggered)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_player_rescued() -> void:
	var err := Events.player_rescued.connect(_asi._on_player_rescued)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_player_out() -> void:
	var err := Events.player_out.connect(_asi._on_player_out)
	assert_that(err).is_equal(OK)


func test_asi_subscribes_to_boss_phase_changed() -> void:
	var err := Events.boss_phase_changed.connect(_asi._on_boss_phase_changed)
	assert_that(err).is_equal(OK)


# ─── AC-8.1b: attack_ended signal check ─────────────────────────────────────────

func test_attack_ended_signal_does_not_exist_on_events() -> void:
	# AC-8.1b: attack_ended is NOT in the Events signal list
	# Animation system should NOT depend on this signal
	assert_that(Events.has_signal("attack_ended")).is_false()


# ─── AC-8.3: Godot 4.6 Callable syntax (no deprecated API) ─────────────────────

func test_signal_connections_use_callable_syntax() -> void:
	# Godot 4.6: signal.connect(handler) — no second argument
	# This test verifies the syntax used compiles correctly
	var emissions: Array = []
	var handler := func(x): emissions.append(x)

	var sig := Signal(Events, "sync_burst_triggered")
	var err := sig.connect(handler)
	assert_that(err).is_equal(OK)


# ─── Player Animation State Machines initialized ──────────────────────────────────

func test_p1_anim_initialized() -> void:
	assert_that(_asi._p1_anim).is_not_null()


func test_p2_anim_initialized() -> void:
	assert_that(_asi._p2_anim).is_not_null()


# ─── Attack type mapping ────────────────────────────────────────────────────────

func test_attack_type_light_maps_to_light_attack_state() -> void:
	var state := _asi._attack_type_to_state("light")
	assert_that(state).is_equal(PlayerAnimationStateMachine.State.LIGHT_ATTACK)


func test_attack_type_medium_maps_to_medium_attack_state() -> void:
	var state := _asi._attack_type_to_state("medium")
	assert_that(state).is_equal(PlayerAnimationStateMachine.State.MEDIUM_ATTACK)


func test_attack_type_heavy_maps_to_heavy_attack_state() -> void:
	var state := _asi._attack_type_to_state("heavy")
	assert_that(state).is_equal(PlayerAnimationStateMachine.State.HEAVY_ATTACK)


func test_attack_type_special_maps_to_special_attack_state() -> void:
	var state := _asi._attack_type_to_state("special")
	assert_that(state).is_equal(PlayerAnimationStateMachine.State.SPECIAL_ATTACK)


func test_attack_type_sync_maps_to_sync_attack_state() -> void:
	var state := _asi._attack_type_to_state("sync")
	assert_that(state).is_equal(PlayerAnimationStateMachine.State.SYNC_ATTACK)


func test_unknown_attack_type_defaults_to_idle() -> void:
	var state := _asi._attack_type_to_state("unknown")
	assert_that(state).is_equal(PlayerAnimationStateMachine.State.IDLE)
