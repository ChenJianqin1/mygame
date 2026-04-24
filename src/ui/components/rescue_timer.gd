# rescue_timer.gd — Radial countdown timer for rescue window
# Implements ui-005: Rescue Timer Radial Countdown
# Shows radial countdown when a player is downed, with pulse animation as time runs low
class_name RescueTimer
extends Control

## Tuning knobs (from story ui-005)
const RESCUE_DURATION: float = 10.0
const WARN_THRESHOLD: float = 5.0
const CRITICAL_THRESHOLD: float = 2.0
const PULSE_MIN_FREQ: float = 1.0
const PULSE_MAX_FREQ: float = 4.0

## Colors
const COLOR_NORMAL := Color("#4ADE80")    # Green — healthy
const COLOR_WARN := Color("#FACC15")      # Yellow — warning
const COLOR_CRITICAL := Color("#EF4444") # Red — critical
const VIGNETTE_FLASH_COLOR := Color(1.0, 0.0, 0.0, 0.3)

## Pulse scale range
const PULSE_SCALE_MIN: float = 1.0
const PULSE_SCALE_MAX: float = 1.15

# ─── Node References ────────────────────────────────────────────────────────────
@onready var _downed_label: Label = $Panel/DownedLabel
@onready var _radial_progress: TextureProgressBar = $Panel/RadialProgress
@onready var _time_label: Label = $Panel/TimeLabel
@onready var _vignette_flash: ColorRect = $VignetteFlash
@onready var _pulse_anchor: Node2D = $PulseAnchor

## Player ID (1 or 2)
var _player_id: int = 1

## Timer state
var _time_remaining: float = RESCUE_DURATION
var _is_active: bool = false
var _is_paused: bool = false

## Pulse animation state
var _pulse_timer: float = 0.0
var _pulse_direction: int = 1

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()
	_hide_timer()


func _process(delta: float) -> void:
	if not _is_active or _is_paused:
		return

	_time_remaining = maxi(0.0, _time_remaining - delta)
	_update_display()

	if _time_remaining <= 0.0:
		_trigger_death()


# ─── Signal Connections ─────────────────────────────────────────────────────────

func _connect_signals() -> void:
	if Events.player_downed.connect(_on_player_downed) != OK:
		push_error("RescueTimer: failed to connect Events.player_downed")
	if Events.player_rescued.connect(_on_player_rescued) != OK:
		push_error("RescueTimer: failed to connect Events.player_rescued")
	if Events.player_out.connect(_on_player_out) != OK:
		push_error("RescueTimer: failed to connect Events.player_out")


# ─── Event Handlers ────────────────────────────────────────────────────────────

func _on_player_downed(player_id: int) -> void:
	if player_id == _player_id:
		_start_timer()


func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
	if player_id == _player_id:
		_hide_timer()


func _on_player_out(player_id: int) -> void:
	if player_id == _player_id:
		_hide_timer()


# ─── Timer Control ─────────────────────────────────────────────────────────────

func _start_timer() -> void:
	_is_active = true
	_is_paused = false
	_time_remaining = RESCUE_DURATION
	show()
	_update_display()


func _pause_timer() -> void:
	_is_paused = true


func _resume_timer() -> void:
	_is_paused = false


func _stop_timer() -> void:
	_is_active = false
	_hide_timer()


func _trigger_death() -> void:
	_is_active = false
	# Fire event for permanent death
	# Note: CoopManager handles the actual death logic
	# This just triggers the visual
	_hide_timer()


func _hide_timer() -> void:
	_is_active = false
	_is_paused = false
	hide()


# ─── Display Updates ────────────────────────────────────────────────────────────

func _update_display() -> void:
	_update_radial_fill()
	_update_time_label()
	_update_color()
	_update_pulse()


func _update_radial_fill() -> void:
	var fill_percent: float = (_time_remaining / RESCUE_DURATION) * 100.0
	_radial_progress.value = fill_percent


func _update_time_label() -> void:
	_time_label.text = "TIME: %.1fs" % _time_remaining


func _update_color() -> void:
	var color: Color
	if _time_remaining > WARN_THRESHOLD:
		color = COLOR_NORMAL
	elif _time_remaining > CRITICAL_THRESHOLD:
		color = COLOR_WARN
	else:
		color = COLOR_CRITICAL

	_radial_progress.add_theme_color_override("fill", color)

	# Vignette flash at critical
	if _time_remaining <= CRITICAL_THRESHOLD:
		_show_vignette_flash()
	else:
		_hide_vignette_flash()


func _update_pulse() -> void:
	# Pulse frequency increases as time runs out
	var time_ratio: float = _time_remaining / RESCUE_DURATION
	var pulse_freq: float = lerp(PULSE_MAX_FREQ, PULSE_MIN_FREQ, time_ratio)

	_pulse_timer += get_process_delta_time() * pulse_freq
	var pulse_t: float = (sin(_pulse_timer * TAU) + 1.0) / 2.0
	var scale: float = lerp(PULSE_SCALE_MIN, PULSE_SCALE_MAX, pulse_t)
	_pulse_anchor.scale = Vector2(scale, scale)


# ─── Vignette Flash ─────────────────────────────────────────────────────────────

func _show_vignette_flash() -> void:
	_vignette_flash.visible = true
	# Flash by toggling alpha
	var flash_alpha: float = (sin(_time_remaining * 10.0) + 1.0) / 2.0 * 0.3
	_vignette_flash.modulate.a = flash_alpha


func _hide_vignette_flash() -> void:
	_vignette_flash.visible = false


# ─── Query Methods ─────────────────────────────────────────────────────────────

func is_active() -> bool:
	return _is_active


func get_time_remaining() -> float:
	return _time_remaining


func get_fill_percent() -> float:
	return (_time_remaining / RESCUE_DURATION) * 100.0
