# boss_hp_bar.gd — Boss HP bar with phase color transitions
# Implements ui-003: Boss HP Bar with Phase Color Transitions
# Phase colors: white (Phase 1), yellow (Phase 2), red (Phase 3)
class_name BossHPBar
extends Control

## Tuning knobs (from story ui-003)
const PHASE_2_THRESHOLD: float = 0.60
const PHASE_3_THRESHOLD: float = 0.30
const BOSS_BAR_WIDTH: float = 600.0

## Phase colors
const COLOR_PHASE1 := Color("#FFFFFF")   # White
const COLOR_PHASE2 := Color("#FBBF24")  # Yellow
const COLOR_PHASE3 := Color("#EF4444")  # Red

## Track tints per phase
const TRACK_PHASE1 := Color("#6B7280")   # Gray
const TRACK_PHASE2 := Color("#D97706")   # Orange
const TRACK_PHASE3 := Color("#991B1B")   # Dark Red

# ─── Node References ────────────────────────────────────────────────────────────
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _hp_label: Label = $HPValue
@onready var _phase_label: Label = $PhaseLabel
@onready var _boss_name_label: Label = $BossNameLabel

## Internal state
var _current_phase: int = 1
var _boss_hp: int = 0
var _boss_max_hp: int = 1

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()
	_update_phase_display()


func _connect_signals() -> void:
	Events.boss_hp_changed.connect(_on_boss_hp_changed)
	Events.boss_phase_changed.connect(_on_boss_phase_changed)
	Events.boss_defeated.connect(_on_boss_defeated)


# ─── Public API ────────────────────────────────────────────────────────────────

## Initialize the boss HP bar with boss name and max HP.
func configure(boss_name: String, max_hp: int) -> void:
	_boss_max_hp = max_hp
	_boss_hp = max_hp
	if _boss_name_label:
		_boss_name_label.text = boss_name
	_update_display()


## Set the boss HP directly (for non-signal updates).
func set_boss_hp(current: int, max_hp: int) -> void:
	_boss_hp = current
	_boss_max_hp = max_hp
	_update_display()


## Get current phase number (1, 2, or 3).
func get_phase() -> int:
	return _current_phase


# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_boss_hp_changed(current_hp: int, max_hp: int) -> void:
	_boss_hp = current_hp
	_boss_max_hp = max_hp
	_update_display()
	_check_phase_transition(current_hp, max_hp)


func _on_boss_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase
	_update_phase_display()


func _on_boss_defeated() -> void:
	# Hide bar on boss defeat
	visible = false


# ─── Internal ─────────────────────────────────────────────────────────────────

func _update_display() -> void:
	if _progress_bar:
		_progress_bar.value = _boss_hp
		_progress_bar.max_value = _boss_max_hp

	if _hp_label:
		_hp_label.text = "HP: %d/%d" % [_boss_hp, _boss_max_hp]


func _update_phase_display() -> void:
	# Update bar color based on phase
	if _progress_bar:
		match _current_phase:
			1:
				_progress_bar.modulate = COLOR_PHASE1
			2:
				_progress_bar.modulate = COLOR_PHASE2
			3:
				_progress_bar.modulate = COLOR_PHASE3

	# Update phase label
	if _phase_label:
		_phase_label.text = "Phase %d" % _current_phase


func _check_phase_transition(current_hp: int, max_hp: int) -> void:
	var percent := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var new_phase := _calculate_phase(percent)

	if new_phase != _current_phase:
		_current_phase = new_phase
		_update_phase_display()


func _calculate_phase(hp_percent: float) -> int:
	if hp_percent > PHASE_2_THRESHOLD:
		return 1
	elif hp_percent > PHASE_3_THRESHOLD:
		return 2
	else:
		return 3
