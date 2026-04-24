# hp_bar.gd — Reusable HP bar component with smooth lerp interpolation
# Implements ui-002: Player HP Bars with Smooth Interpolation
# Supports damage flash, HP color gradient, and independent dual-player tracking
class_name HPBar
extends Control

## Tuning knobs (from story ui-002)
const HP_LERP_SPEED: float = 8.0
const DAMAGE_FLASH_DURATION_MS: int = 150
const HP_FLASH_BLOCK_MS: int = 50
const CRITICAL_HP_THRESHOLD: float = 0.30
const WARN_HP_THRESHOLD: float = 0.60

## HP color gradient
const COLOR_HEALTHY := Color("#4ADE80")   # Green #4ADE80 (100-60%)
const COLOR_WOUNDED := Color("#FACC15")  # Yellow #FACC15 (59-30%)
const COLOR_CRITICAL := Color("#EF4444")  # Red #EF4444 (29-0%)

## Flash overlay color
const FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.4)

# ─── Node References ────────────────────────────────────────────────────────────
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _hp_label: Label = $HPValue
@onready var _flash_overlay: ColorRect = $FlashOverlay

## Current displayed HP (lerped)
var _display_hp: float = 100.0

## Target HP to lerp toward
var _target_hp: float = 100.0

## Maximum HP for this bar
var _max_hp: int = 100

## Player ID for signal routing (1 or 2)
var _player_id: int = 1

## Flash timer in seconds
var _flash_timer_ms: float = 0.0

## Lerp block timer (ms) — brief pause after damage flash
var _lerp_block_ms: float = 0.0

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()
	_display_hp = _max_hp
	_target_hp = _max_hp
	_update_bar_value()
	_update_label()
	_update_color()


func _process(delta: float) -> void:
	# Update timers
	if _flash_timer_ms > 0:
		_flash_timer_ms -= delta * 1000.0
		_update_flash_alpha()

	if _lerp_block_ms > 0:
		_lerp_block_ms -= delta * 1000.0

	# Lerp display HP toward target
	if _lerp_block_ms <= 0:
		var diff := _target_hp - _display_hp
		if absf(diff) < 0.1:
			_display_hp = _target_hp
		else:
			_display_hp = lerp(_display_hp, _target_hp, HP_LERP_SPEED * delta)

	_update_bar_value()


func _connect_signals() -> void:
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_healed.connect(_on_player_healed)
	Events.player_hp_changed.connect(_on_player_hp_changed)


# ─── Public API ────────────────────────────────────────────────────────────────

## Initialize the HP bar for a specific player.
func configure(player_id: int, max_hp: int) -> void:
	_player_id = player_id
	_max_hp = max_hp
	_display_hp = max_hp
	_target_hp = max_hp
	_update_bar_value()
	_update_label()
	_update_color()


## Set the target HP value (HP will lerp toward this).
func set_target_hp(hp: int) -> void:
	_target_hp = clampf(hp, 0, _max_hp)


## Trigger damage flash effect.
func flash_damage() -> void:
	_flash_timer_ms = DAMAGE_FLASH_DURATION_MS
	_lerp_block_ms = HP_FLASH_BLOCK_MS
	_flash_overlay.color = FLASH_COLOR


## Get the current display HP (after lerp).
func get_display_hp() -> int:
	return int(_display_hp)


## Get HP percentage (0.0 to 1.0).
func get_hp_percent() -> float:
	return clampf(_target_hp / _max_hp, 0.0, 1.0)


# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_player_damaged(player_id: int, damage: int) -> void:
	if player_id != _player_id:
		return
	flash_damage()


func _on_player_healed(player_id: int, amount: int) -> void:
	if player_id != _player_id:
		return
	# Heal is applied via player_hp_changed


func _on_player_hp_changed(player_id: int, current: int, max: int) -> void:
	if player_id != _player_id:
		return
	_max_hp = max
	set_target_hp(current)
	_update_label()
	_update_color()


# ─── Internal ─────────────────────────────────────────────────────────────────

func _update_bar_value() -> void:
	if _progress_bar != null:
		_progress_bar.value = _display_hp
		_progress_bar.max_value = _max_hp


func _update_label() -> void:
	if _hp_label != null:
		_hp_label.text = "HP: %d/%d" % [int(_target_hp), _max_hp]


func _update_color() -> void:
	if _progress_bar == null:
		return
	var percent := get_hp_percent()
	if percent >= WARN_HP_THRESHOLD:
		_progress_bar.modulate = COLOR_HEALTHY
	elif percent >= CRITICAL_HP_THRESHOLD:
		_progress_bar.modulate = COLOR_WOUNDED
	else:
		_progress_bar.modulate = COLOR_CRITICAL


func _update_flash_alpha() -> void:
	if _flash_overlay == null:
		return
	var t := clampf(_flash_timer_ms / DAMAGE_FLASH_DURATION_MS, 0.0, 1.0)
	var alpha := t * FLASH_COLOR.a
	_flash_overlay.color = Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, alpha)
	if _flash_timer_ms <= 0:
		_flash_overlay.color = Color(0, 0, 0, 0)
