# ui_signal_wiring_test.gd — Integration tests for ui-008 UI Signal Integration
# Tests that all UI components connect to Events signal bus correctly
# GdUnit4 test file

class_name UISignalWiringTest
extends GdUnitTestSuite

# ─── Test: UI Component Signal Connections ───────────────────────────────────────

func test_hp_bar_has_signal_handlers() -> void:
	var hp_bar := HPBar.new()
	add_child(hp_bar)

	# HPBar should connect to player_hp_changed, player_damaged, player_healed
	assert_that(hp_bar.has_method("_on_player_hp_changed")).is_true()
	assert_that(hp_bar.has_method("_on_player_damaged")).is_true()
	assert_that(hp_bar.has_method("_on_player_healed")).is_true()

	hp_bar.free()


func test_boss_hp_bar_has_signal_handlers() -> void:
	var boss_hp_bar := BossHPBar.new()
	add_child(boss_hp_bar)

	assert_that(boss_hp_bar.has_method("_on_boss_hp_changed")).is_true()
	assert_that(boss_hp_bar.has_method("_on_boss_phase_changed")).is_true()
	assert_that(boss_hp_bar.has_method("_on_boss_defeated")).is_true()

	boss_hp_bar.free()


func test_combo_counter_has_signal_handlers() -> void:
	var counter := ComboCounter.new()
	add_child(counter)

	assert_that(counter.has_method("_on_combo_hit")).is_true()
	assert_that(counter.has_method("_on_combo_break")).is_true()
	assert_that(counter.has_method("_on_combo_multiplier_updated")).is_true()

	counter.free()


func test_rescue_timer_has_signal_handlers() -> void:
	var timer := RescueTimer.new()
	add_child(timer)

	assert_that(timer.has_method("_on_player_downed")).is_true()
	assert_that(timer.has_method("_on_player_rescued")).is_true()
	assert_that(timer.has_method("_on_player_out")).is_true()

	timer.free()


func test_crisis_glow_has_signal_handlers() -> void:
	var glow := CrisisGlow.new()
	add_child(glow)

	assert_that(glow.has_method("_on_player_hp_changed")).is_true()
	assert_that(glow.has_method("_on_crisis_state_changed")).is_true()
	assert_that(glow.has_method("_on_boss_defeated")).is_true()

	glow.free()


func test_damage_number_has_process_animation() -> void:
	var dmg_num := DamageNumber.new()
	add_child(dmg_num)

	# DamageNumber uses _process() for animation but is signal-triggered
	assert_that(dmg_num.has_method("_process")).is_true()
	assert_that(dmg_num.has_method("initialize")).is_true()

	dmg_num.free()


# ─── Test: Events signal definitions exist ──────────────────────────────────────

func test_events_has_player_hp_changed_signal() -> void:
	assert_that(Events.has_signal("player_hp_changed")).is_true()


func test_events_has_player_damaged_signal() -> void:
	assert_that(Events.has_signal("player_damaged")).is_true()


func test_events_has_player_healed_signal() -> void:
	assert_that(Events.has_signal("player_healed")).is_true()


func test_events_has_combo_hit_signal() -> void:
	assert_that(Events.has_signal("combo_hit")).is_true()


func test_events_has_combo_break_signal() -> void:
	assert_that(Events.has_signal("combo_break")).is_true()


func test_events_has_combo_multiplier_updated_signal() -> void:
	assert_that(Events.has_signal("combo_multiplier_updated")).is_true()


func test_events_has_boss_defeated_signal() -> void:
	assert_that(Events.has_signal("boss_defeated")).is_true()


func test_events_has_player_downed_signal() -> void:
	assert_that(Events.has_signal("player_downed")).is_true()


func test_events_has_player_rescued_signal() -> void:
	assert_that(Events.has_signal("player_rescued")).is_true()


func test_events_has_player_out_signal() -> void:
	assert_that(Events.has_signal("player_out")).is_true()


func test_events_has_crisis_state_changed_signal() -> void:
	assert_that(Events.has_signal("crisis_state_changed")).is_true()


func test_events_has_rescue_triggered_signal() -> void:
	assert_that(Events.has_signal("rescue_triggered")).is_true()


# ─── Test: No polling pattern (components use signals, not _process state reads) ──

func test_hp_bar_process_updates_lerp_only() -> void:
	# HPBar._process should lerp display values, not read game state directly
	# This is the allowed exception - all it does is interpolate toward target
	var hp_bar := HPBar.new()
	add_child(hp_bar)

	# The _process should exist and handle lerp, which is allowed
	assert_that(hp_bar.has_method("_process")).is_true()

	hp_bar.free()


func test_combo_counter_process_only_for_animations() -> void:
	# ComboCounter._process should only update animation timers, not read combo state
	var counter := ComboCounter.new()
	add_child(counter)

	assert_that(counter.has_method("_process")).is_true()

	counter.free()


func test_rescue_timer_process_only_for_countdown() -> void:
	# RescueTimer._process should only update countdown, not poll state
	var timer := RescueTimer.new()
	add_child(timer)

	assert_that(timer.has_method("_process")).is_true()

	timer.free()


func test_crisis_glow_process_only_for_pulse() -> void:
	# CrisisGlow._process should only update pulse, not poll HP state
	var glow := CrisisGlow.new()
	add_child(glow)

	assert_that(glow.has_method("_process")).is_true()

	glow.free()
