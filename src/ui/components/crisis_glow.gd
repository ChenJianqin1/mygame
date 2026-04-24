# crisis_glow.gd — Crisis edge glow effect
# Implements ui-006: Crisis Edge Glow Effect
# Full-screen red vignette pulse when both players are below 30% HP
class_name CrisisGlow
extends CanvasLayer

## Tuning knobs (from story ui-006)
const CRISIS_THRESHOLD: float = 0.30
const PULSE_FREQUENCY: float = 1.0
const MIN_OPACITY: float = 0.3
const MAX_OPACITY: float = 0.6
const FADE_DURATION_MS: int = 500

## Pulse amplitude (sine wave half-range)
const PULSE_AMPLITUDE: float = 0.15

## Color
const GLOW_COLOR := Color(1.0, 0.0, 0.0, 1.0)

# ─── Node References ────────────────────────────────────────────────────────────
@onready var _glow_rect: ColorRect = $GlowRect

## Crisis state
var _is_crisis_active: bool = false

## Current opacity (for tweening)
var _target_opacity: float = 0.0
var _current_opacity: float = 0.0

## Time for pulse calculation
var _pulse_time: float = 0.0

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()
	_current_opacity = 0.0
	_glow_rect.color = GLOW_COLOR
	_glow_rect.color.a = 0.0


func _process(delta: float) -> void:
	if _is_crisis_active:
		_pulse_time += delta
		_update_pulse()


# ─── Signal Connections ─────────────────────────────────────────────────────────

func _connect_signals() -> void:
	if Events.player_hp_changed.connect(_on_player_hp_changed) != OK:
		push_error("CrisisGlow: failed to connect Events.player_hp_changed")
	if Events.crisis_state_changed.connect(_on_crisis_state_changed) != OK:
		push_error("CrisisGlow: failed to connect Events.crisis_state_changed")
	if Events.boss_defeated.connect(_on_boss_defeated) != OK:
		push_error("CrisisGlow: failed to connect Events.boss_defeated")


# ─── Event Handlers ────────────────────────────────────────────────────────────

func _on_player_hp_changed(player_id: int, current_hp: int, max_hp: int) -> void:
	_check_crisis_condition()


func _on_crisis_state_changed(is_crisis: bool) -> void:
	if is_crisis:
		_enter_crisis()
	else:
		_exit_crisis()


func _on_boss_defeated() -> void:
	_exit_crisis()


# ─── Crisis State Management ───────────────────────────────────────────────────

func _check_crisis_condition() -> void:
	# Both players must be below threshold and alive
	var p1_hp := CoopManager.get_player_hp_percent(1)
	var p2_hp := CoopManager.get_player_hp_percent(2)
	var p1_alive := CoopManager.get_player_state(1) != CoopManager.CoopState.OUT
	var p2_alive := CoopManager.get_player_state(2) != CoopManager.CoopState.OUT

	var should_be_crisis: bool = (
		p1_alive and p2_alive and
		p1_hp < CRISIS_THRESHOLD and
		p2_hp < CRISIS_THRESHOLD
	)

	if should_be_crisis and not _is_crisis_active:
		_enter_crisis()
	elif not should_be_crisis and _is_crisis_active:
		_exit_crisis()


func _enter_crisis() -> void:
	_is_crisis_active = true
	_target_opacity = _calculate_base_opacity()
	_tween_opacity(_target_opacity, 0.3)  # Quick fade in


func _exit_crisis() -> void:
	_is_crisis_active = false
	_target_opacity = 0.0
	_tween_opacity(0.0, float(FADE_DURATION_MS) / 1000.0)


# ─── Intensity Calculation ──────────────────────────────────────────────────────

func _calculate_base_opacity() -> float:
	var p1_hp := CoopManager.get_player_hp_percent(1)
	var p2_hp := CoopManager.get_player_hp_percent(2)
	var combined_hp: float = (p1_hp + p2_hp) / 2.0

	# intensity: 0 at 100% combined, 1 at 0%
	var intensity: float = clampf(1.0 - combined_hp, 0.0, 1.0)

	# base_opacity: lerp from MIN to MAX based on intensity
	return lerpf(MIN_OPACITY, MAX_OPACITY, intensity)


func _calculate_current_opacity() -> float:
	var base_opacity := _target_opacity if _is_crisis_active else _current_opacity

	# Pulse: sine wave centered on base opacity
	var pulse: float = sin(_pulse_time * TAU * PULSE_FREQUENCY) * PULSE_AMPLITUDE

	return clampf(base_opacity + pulse, 0.0, MAX_OPACITY)


# ─── Animation ─────────────────────────────────────────────────────────────────

func _update_pulse() -> void:
	_current_opacity = _calculate_current_opacity()
	_glow_rect.color.a = _current_opacity


func _tween_opacity(target: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "_current_opacity", target, duration)
	tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	# Update after tween completes
	_glow_rect.color.a = _current_opacity


# ─── Query Methods ─────────────────────────────────────────────────────────────

func is_crisis_active() -> bool:
	return _is_crisis_active


func get_current_opacity() -> float:
	return _current_opacity
