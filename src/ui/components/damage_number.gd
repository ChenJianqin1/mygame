# damage_number.gd — Single floating damage number
# Implements ui-007: Damage Number Popup System
# Spawns at impact point, drifts upward, fades out
class_name DamageNumber
extends Label

## Tuning knobs (from story ui-007)
const DAMAGE_FLOAT_DURATION_MS: int = 800
const DAMAGE_FADE_START_MS: int = 600
const DAMAGE_FLOAT_DISTANCE: float = 60.0
const CRIT_SIZE_MULTIPLIER: float = 1.5
const MAX_DISPLAY_DAMAGE: int = 999
const SPAWN_OFFSET_Y: float = -20.0
const JITTER_RANGE: float = 10.0

## Damage types
enum DamageType { NORMAL, CRIT, BOSS, HEAL }

## Colors
const COLOR_NORMAL := Color.WHITE
const COLOR_CRIT := Color("#FACC15")      # Yellow
const COLOR_BOSS := Color("#FB923C")     # Orange
const COLOR_HEAL := Color("#4ADE80")      # Green

# ─── State ──────────────────────────────────────────────────────────────────────
var _damage_type: DamageType = DamageType.NORMAL
var _elapsed_ms: float = 0.0
var _initial_position: Vector2 = Vector2.ZERO
var _base_scale: float = 1.0
var _is_active: bool = false

# ─── Initialization ──────────────────────────────────────────────────────────────

func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func initialize(damage: int, damage_type: DamageType, position: Vector2) -> void:
	_damage_type = damage_type
	_elapsed_ms = 0.0
	_is_active = true

	# Set text
	var display_damage := mini(damage, MAX_DISPLAY_DAMAGE)
	if damage_type == DamageType.HEAL:
		text = "+%d" % display_damage
	else:
		text = "%d" % display_damage

	# Set color and scale based on type
	_apply_type_style()

	# Set initial position with jitter
	var jitter_x: float = randf_range(-JITTER_RANGE, JITTER_RANGE)
	var spawn_pos: Vector2 = position + Vector2(jitter_x, SPAWN_OFFSET_Y)
	global_position = spawn_pos
	_initial_position = spawn_pos

	# Start with initial scale (larger, then shrink)
	scale = Vector2(_base_scale * 1.2, _base_scale * 1.2)
	modulate.a = 1.0


func _apply_type_style() -> void:
	match _damage_type:
		DamageType.NORMAL:
			add_theme_color_override("font_color", COLOR_NORMAL)
			_base_scale = 1.0
		DamageType.CRIT:
			add_theme_color_override("font_color", COLOR_CRIT)
			add_theme_constant_override("bold", 1)
			_base_scale = 1.5
		DamageType.BOSS:
			add_theme_color_override("font_color", COLOR_BOSS)
			_base_scale = 1.2
		DamageType.HEAL:
			add_theme_color_override("font_color", COLOR_HEAL)
			_base_scale = 1.0


# ─── Animation ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed_ms += delta * 1000.0
	var elapsed := _elapsed_ms / 1000.0
	var duration := float(DAMAGE_FLOAT_DURATION_MS) / 1000.0
	var fade_start := float(DAMAGE_FADE_START_MS) / 1000.0
	var fade_duration := duration - fade_start

	# Vertical drift
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var y_offset: float = -DAMAGE_FLOAT_DISTANCE * t
	global_position.y = _initial_position.y + y_offset

	# Scale: 1.2 → 0.8 over duration
	var scale_t: float = clampf(elapsed / duration, 0.0, 1.0)
	var current_scale: float = lerpf(1.2, 0.8, scale_t) * _base_scale
	scale = Vector2(current_scale, current_scale)

	# Opacity: fade over final portion
	if elapsed > fade_start:
		var fade_t: float = clampf((elapsed - fade_start) / fade_duration, 0.0, 1.0)
		modulate.a = 1.0 - fade_t
	else:
		modulate.a = 1.0

	# Check if done
	if _elapsed_ms >= DAMAGE_FLOAT_DURATION_MS:
		_deactivate()


func _deactivate() -> void:
	_is_active = false
	visible = false


# ─── Query ─────────────────────────────────────────────────────────────────────

func is_active() -> bool:
	return _is_active
