# combo_counter.gd — Combo counter display with tier scaling
# Implements ui-004: Combo Counter with Tier Scaling
# Shows current combo count, multiplier tier, tier name, and within-tier progress
class_name ComboCounter
extends Control

## Tuning knobs (from story ui-004)
const TIER_FURY_THRESHOLD: int = 10
const TIER_CARNAGE_THRESHOLD: int = 25
const TIER_BLOODSHED_THRESHOLD: int = 50
const TIER_FLASH_DURATION_MS: int = 500
const RESET_SHAKE_DURATION_MS: int = 200
const RESET_FADE_DURATION_MS: int = 500
const MAX_DISPLAY_COMBO: int = 999

## Tier definitions
enum Tier { NORMAL, FURY, CARNAGE, BLOODSHED }

## Tier colors
const COLOR_NORMAL := Color.WHITE
const COLOR_FURY := Color("#FB923C")      # Orange #FB923C
const COLOR_CARNAGE := Color("#EF4444")    # Red #EF4444
const COLOR_BLOODSHED := Color("#991B1B") # Dark Red #991B1B

## Tier scales
const SCALE_NORMAL: float = 1.0
const SCALE_FURY: float = 1.1
const SCALE_CARNAGE: float = 1.2
const SCALE_BLOODSHED: float = 1.3

## Tier multipliers
const MULTIPLIER_NORMAL: float = 1.00
const MULTIPLIER_FURY: float = 1.15
const MULTIPLIER_CARNAGE: float = 1.30
const MULTIPLIER_BLOODSHED: float = 1.50

## Tier names
const TIER_NAME_NORMAL := ""
const TIER_NAME_FURY := "FURY!"
const TIER_NAME_CARNAGE := "CARNAGE!"
const TIER_NAME_BLOODSHED := "BLOODSHED!"

## Tier thresholds for display (used for progress bar)
const TIER_STARTS: Array[int] = [0, 10, 25, 50]
const TIER_ENDS: Array[int] = [10, 25, 50, 999]

# ─── Node References ────────────────────────────────────────────────────────────
@onready var _count_label: Label = $ScaleAnchor/ComboPanel/CountLabel
@onready var _multiplier_label: Label = $ScaleAnchor/ComboPanel/MultiplierLabel
@onready var _tier_name_label: Label = $ScaleAnchor/ComboPanel/TierNameLabel
@onready var _progress_bar: ProgressBar = $ScaleAnchor/ComboPanel/TierProgressBar
@onready var _shake_anchor: Node2D = $ShakeAnchor
@onready var _scale_anchor: Node2D = $ScaleAnchor

## Current combo count
var _combo_count: int = 0

## Current tier
var _current_tier: Tier = Tier.NORMAL

## Flash timer in ms
var _tier_flash_timer_ms: float = 0.0

## Reset animation state
var _is_reset_animating: bool = false
var _reset_timer_ms: float = 0.0

## Original scale for animations
var _base_scale: Vector2 = Vector2.ONE

# ─── Tier Data ─────────────────────────────────────────────────────────────────

static func get_tier(combo_count: int) -> Tier:
	if combo_count < TIER_FURY_THRESHOLD:
		return Tier.NORMAL
	elif combo_count < TIER_CARNAGE_THRESHOLD:
		return Tier.FURY
	elif combo_count < TIER_BLOODSHED_THRESHOLD:
		return Tier.CARNAGE
	else:
		return Tier.BLOODSHED


static func get_multiplier(tier: Tier) -> float:
	match tier:
		Tier.NORMAL: return MULTIPLIER_NORMAL
		Tier.FURY: return MULTIPLIER_FURY
		Tier.CARNAGE: return MULTIPLIER_CARNAGE
		Tier.BLOODSHED: return MULTIPLIER_BLOODSHED
	return MULTIPLIER_NORMAL


static func get_scale(tier: Tier) -> float:
	match tier:
		Tier.NORMAL: return SCALE_NORMAL
		Tier.FURY: return SCALE_FURY
		Tier.CARNAGE: return SCALE_CARNAGE
		Tier.BLOODSHED: return SCALE_BLOODSHED
	return SCALE_NORMAL


static func get_tier_color(tier: Tier) -> Color:
	match tier:
		Tier.NORMAL: return COLOR_NORMAL
		Tier.FURY: return COLOR_FURY
		Tier.CARNAGE: return COLOR_CARNAGE
		Tier.BLOODSHED: return COLOR_BLOODSHED
	return COLOR_NORMAL


static func get_tier_name(tier: Tier) -> String:
	match tier:
		Tier.NORMAL: return TIER_NAME_NORMAL
		Tier.FURY: return TIER_NAME_FURY
		Tier.CARNAGE: return TIER_NAME_CARNAGE
		Tier.BLOODSHED: return TIER_NAME_BLOODSHED
	return TIER_NAME_NORMAL


static func get_tier_progress(combo_count: int, tier: Tier) -> float:
	var tier_idx: int = tier as int
	var tier_start: int = TIER_STARTS[tier_idx]
	var tier_end: int = TIER_ENDS[tier_idx]
	var progress: float = float(combo_count - tier_start) / float(tier_end - tier_start)
	return clampf(progress, 0.0, 1.0)


# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()
	_base_scale = _scale_anchor.scale
	hide()


func _process(delta: float) -> void:
	_update_flash_timer(delta)
	_update_reset_animation(delta)


# ─── Signal Connections ─────────────────────────────────────────────────────────

func _connect_signals() -> void:
	if Events.combo_hit.connect(_on_combo_hit) != OK:
		push_error("ComboCounter: failed to connect Events.combo_hit")
	if Events.combo_break.connect(_on_combo_break) != OK:
		push_error("ComboCounter: failed to connect Events.combo_break")
	if Events.combo_multiplier_updated.connect(_on_combo_multiplier_updated) != OK:
		push_error("ComboCounter: failed to connect Events.combo_multiplier_updated")


# ─── Event Handlers ─────────────────────────────────────────────────────────────

func _on_combo_hit(attack_type: String, combo_count: int, is_grounded: bool) -> void:
	_update_combo(combo_count)


func _on_combo_break() -> void:
	_reset_combo()


func _on_combo_multiplier_updated(multiplier: float, tier: int) -> void:
	# Tier changed — trigger flash animation
	_trigger_tier_flash()


# ─── Combo State Updates ────────────────────────────────────────────────────────

func _update_combo(new_count: int) -> void:
	var old_tier: Tier = _current_tier
	_combo_count = mini(new_count, MAX_DISPLAY_COMBO)
	_current_tier = get_tier(_combo_count)

	# Show counter on first hit
	if _combo_count == 1:
		show()
		_scale_anchor.scale = _base_scale * get_scale(_current_tier)

	# Update tier
	if _current_tier != old_tier:
		_trigger_tier_transition(old_tier, _current_tier)
	else:
		_refresh_display()


func _reset_combo() -> void:
	if _combo_count == 0:
		return

	_combo_count = 0
	_current_tier = Tier.NORMAL
	_is_reset_animating = true
	_reset_timer_ms = float(RESET_SHAKE_DURATION_MS + RESET_FADE_DURATION_MS)


func _trigger_tier_transition(old_tier: Tier, new_tier: Tier) -> void:
	_trigger_tier_flash()
	_trigger_tier_pulse(new_tier)
	_refresh_display()


func _trigger_tier_flash() -> void:
	_tier_flash_timer_ms = float(TIER_FLASH_DURATION_MS)


func _trigger_tier_pulse(new_tier: Tier) -> void:
	# Pulse: scale to 1.2x, then back to tier scale
	var target_scale: float = get_scale(new_tier)
	var pulse_scale: float = target_scale * 1.2

	var tween := create_tween()
	tween.tween_property(_scale_anchor, "scale", _base_scale * pulse_scale, 0.15)
	tween.tween_property(_scale_anchor, "scale", _base_scale * target_scale, 0.15)


# ─── Display Updates ────────────────────────────────────────────────────────────

func _refresh_display() -> void:
	_update_count_label()
	_update_multiplier_label()
	_update_tier_name_label()
	_update_progress_bar()
	_update_tier_color()


func _update_count_label() -> void:
	_count_label.text = "COMBO: %d" % _combo_count


func _update_multiplier_label() -> void:
	var multiplier: float = get_multiplier(_current_tier)
	_multiplier_label.text = "%.2fx" % multiplier


func _update_tier_name_label() -> void:
	_tier_name_label.text = get_tier_name(_current_tier)


func _update_progress_bar() -> void:
	if _current_tier == Tier.NORMAL:
		_progress_bar.value = 0.0
		_progress_bar.max_value = 1.0
		return

	var progress: float = get_tier_progress(_combo_count, _current_tier)
	_progress_bar.value = progress * 100.0
	_progress_bar.max_value = 100.0


func _update_tier_color() -> void:
	var color: Color = get_tier_color(_current_tier)
	_multiplier_label.add_theme_color_override("font_color", color)

	# Glow effect for BLOODSHED tier
	if _current_tier == Tier.BLOODSHED:
		_add_glow_effect()
	else:
		_remove_glow_effect()


# ─── Animation Updates ──────────────────────────────────────────────────────────

func _update_flash_timer(delta: float) -> void:
	if _tier_flash_timer_ms > 0:
		_tier_flash_timer_ms -= delta * 1000.0
		_update_flash_visibility()


func _update_flash_visibility() -> void:
	# Flash by toggling tier name label visibility
	var visible: bool = fmod(_tier_flash_timer_ms / 100.0, 2.0) < 1.0
	_tier_name_label.visible = visible


func _update_reset_animation(delta: float) -> void:
	if not _is_reset_animating:
		return

	_reset_timer_ms -= delta * 1000.0

	var shake_duration: float = float(RESET_SHAKE_DURATION_MS)
	var fade_start: float = shake_duration
	var total_duration: float = float(RESET_SHAKE_DURATION_MS + RESET_FADE_DURATION_MS)

	if _reset_timer_ms > fade_start:
		# Shake phase
		var shake_progress: float = 1.0 - ((_reset_timer_ms - fade_start) / float(RESET_SHAKE_DURATION_MS))
		_apply_shake(shake_progress)
	elif _reset_timer_ms > 0:
		# Fade phase
		var fade_progress: float = 1.0 - (_reset_timer_ms / fade_start)
		_apply_fade(fade_progress)
	else:
		# Animation complete
		_is_reset_animating = false
		_reset_shake_anchor()
		hide()


func _apply_shake(progress: float) -> void:
	# Position jitter ±5px, decreasing over time
	var intensity: float = 5.0 * (1.0 - progress)
	var offset_x: float = randf_range(-intensity, intensity)
	var offset_y: float = randf_range(-intensity, intensity)
	_shake_anchor.position = Vector2(offset_x, offset_y)


func _apply_fade(progress: float) -> void:
	modulate.a = 1.0 - progress


func _reset_shake_anchor() -> void:
	_shake_anchor.position = Vector2.ZERO
	modulate.a = 1.0


# ─── Glow Effect ────────────────────────────────────────────────────────────────

func _add_glow_effect() -> void:
	# Add a shadow/glow to the combo panel for BLOODSHED tier
	# In production this would use a proper glow shader
	pass


func _remove_glow_effect() -> void:
	pass


# ─── Query Methods ─────────────────────────────────────────────────────────────

## Returns the current tier name string for external use.
func get_tier_display_name() -> String:
	return get_tier_name(_current_tier)


## Returns whether the counter is currently visible.
func is_visible_combo() -> bool:
	return visible and _combo_count > 0
