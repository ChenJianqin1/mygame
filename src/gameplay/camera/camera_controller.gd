# camera_controller.gd — Camera system with trauma shake and attack zoom
# Implements camera-001: AC-7.1 (60fps stable), AC-2.4 (no drift)
# Implements camera-004: Player Attack Zoom Response
# Uses offset-based shake (not position) per ADR-ARCH-007
extends Node2D

## Camera controller with trauma-based screen shake.
## Trauma is applied via the offset property — NOT position.
## Trauma decays over time. When trauma reaches 0, offset returns to Vector2.ZERO exactly.

# ─── Camera States ───────────────────────────────────────────────────────────────
enum CameraState {
	NORMAL,            ## Default tracking state
	PLAYER_ATTACK,     ## Attack zoom state (0.9x zoom)
	SYNC_ATTACK,       ## Sync attack state (0.85x zoom, 0.5s hold)
	COMBAT_ZOOM,       ## Combo tier 3+ zoom (0.85x zoom, 0.3s hold)
	BOSS_FOCUS,        ## Boss attack focus (0.8x zoom, 0.5s hold)
	BOSS_PHASE_CHANGE, ## Boss phase transition (0.75x zoom, 1.2s hold, cinematic)
	CRISIS             ## Crisis mode (dramatic zoom)
}

# ─── Tuning Knobs ────────────────────────────────────────────────────────────────
const MAX_TRAUMA: float = 1.0          ## Maximum trauma value
const TRAUMA_DECAY: float = 2.0       ## Trauma decay rate (per second)
const MAX_OFFSET: float = 50.0        ## Maximum shake offset in pixels
const BASE_ZOOM: Vector2 = Vector2(1.0, 1.0)

## Attack zoom parameters
const ATTACK_ZOOM: Vector2 = Vector2(0.9, 0.9)  ## 0.9x zoom during attack
const ATTACK_ZOOM_HOLD: float = 0.3   ## Seconds to hold attack zoom before returning

## Sync attack parameters
const SYNC_ATTACK_ZOOM: Vector2 = Vector2(0.85, 0.85)  ## 0.85x zoom during sync attack
const SYNC_ATTACK_HOLD: float = 0.5   ## Seconds to hold sync attack before returning
const TRAUMA_SYNC: float = 0.8       ## Maximum trauma for 3rd consecutive sync

## Combo combat zoom parameters
const COMBAT_ZOOM: Vector2 = Vector2(0.85, 0.85)  ## 0.85x zoom during tier 3+ combo
const COMBAT_ZOOM_HOLD: float = 0.3   ## Seconds to hold before returning
const COMBO_TIER_ZOOM_THRESHOLD: int = 3  ## Minimum tier to trigger combat zoom

## Boss focus parameters
const BOSS_FOCUS_ZOOM: Vector2 = Vector2(0.80, 0.80)  ## 0.8x zoom during boss attack
const BOSS_FOCUS_HOLD: float = 0.5   ## Seconds to hold boss focus

## Boss phase change parameters
const BOSS_PHASE_CHANGE_ZOOM: Vector2 = Vector2(0.75, 0.75)  ## 0.75x zoom during phase transition
const BOSS_PHASE_CHANGE_HOLD: float = 1.2   ## Seconds to hold phase change
const TRAUMA_BOSS_PHASE: float = 0.9   ## Trauma for boss phase change

## Crisis mode parameters
const CRISIS_ZOOM: Vector2 = Vector2(0.9, 0.9)  ## 0.9x zoom during crisis
const CRISIS_HOLD: float = 0.5   ## Seconds to hold before returning (after rescue delay)

## Trauma by attack type
const TRAUMA_LIGHT: float = 0.15
const TRAUMA_MEDIUM: float = 0.25
const TRAUMA_HEAVY: float = 0.4
const TRAUMA_SPECIAL: float = 0.6

# ─── Runtime State ──────────────────────────────────────────────────────────────
var _trauma: float = 0.0
var _target_offset: Vector2 = Vector2.ZERO

## Camera state machine
var _current_state: CameraState = CameraState.NORMAL
var _state_timer: float = 0.0
var _zoom: Vector2 = BASE_ZOOM
var _crisis_return_pending: bool = false

## Emitted when camera shake intensity changes (for VFX)
signal camera_shake_intensity(trauma: float)

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()


func _process(delta: float) -> void:
	_update_state_timer(delta)
	update_camera(delta)


func _connect_signals() -> void:
	if Events.attack_started.connect(_on_attack_started) != OK:
		push_warning("CameraController: failed to connect Events.attack_started")
	if Events.sync_burst_triggered.connect(_on_sync_burst_triggered) != OK:
		push_warning("CameraController: failed to connect Events.sync_burst_triggered")
	if Events.combo_tier_changed.connect(_on_combo_tier_changed) != OK:
		push_warning("CameraController: failed to connect Events.combo_tier_changed")
	if Events.boss_phase_changed.connect(_on_boss_phase_changed) != OK:
		push_warning("CameraController: failed to connect Events.boss_phase_changed")
	if Events.boss_attack_started.connect(_on_boss_attack_started) != OK:
		push_warning("CameraController: failed to connect Events.boss_attack_started")
	if Events.player_downed.connect(_on_player_downed) != OK:
		push_warning("CameraController: failed to connect Events.player_downed")
	if Events.player_rescued.connect(_on_player_rescued) != OK:
		push_warning("CameraController: failed to connect Events.player_rescued")


# ─── Public API ─────────────────────────────────────────────────────────────────

## Add trauma to the camera. Trauma is clamped to MAX_TRAUMA.
## Call when hit, explosion, or sync burst occurs.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, MAX_TRAUMA)
	if _trauma > 0.0:
		camera_shake_intensity.emit(_trauma)


## Get current trauma level (0.0 to 1.0).
func get_trauma() -> float:
	return _trauma


## Get current camera state.
func get_state() -> CameraState:
	return _current_state


## Get current zoom level.
func get_zoom() -> Vector2:
	return _zoom


## Advance camera by delta seconds. Call from _physics_process.
func update_camera(delta: float) -> void:
	# Decay trauma
	if _trauma > 0.0:
		_trauma = clampf(_trauma - TRAUMA_DECAY * delta, 0.0, MAX_TRAUMA)
		if _trauma <= 0.0:
			_trauma = 0.0
			camera_shake_intensity.emit(0.0)

	# Calculate shake offset
	var shake_offset := Vector2.ZERO
	if _trauma > 0.0:
		var shake_x: float = randf_range(-1.0, 1.0) * _trauma * _trauma * MAX_OFFSET
		var shake_y: float = randf_range(-1.0, 1.0) * _trauma * _trauma * MAX_OFFSET
		shake_offset = Vector2(shake_x, shake_y)

	# Apply via offset — NOT position (per ADR-ARCH-007)
	offset = shake_offset


## Returns true if camera is currently shaking.
func is_shaking() -> bool:
	return _trauma > 0.0


## Reset camera to zero offset and zero trauma.
func reset() -> void:
	_trauma = 0.0
	offset = Vector2.ZERO


# ─── Signal Handlers ───────────────────────────────────────────────────────────

func _on_attack_started(attack_type: String, player_id: int) -> void:
	_add_trauma_for_attack(attack_type)
	_transition_to(CameraState.PLAYER_ATTACK)


func _on_sync_burst_triggered(position: Vector2) -> void:
	# Set trauma to max (0.8) for maximum shake on 3rd consecutive sync
	add_trauma(TRAUMA_SYNC)
	_transition_to(CameraState.SYNC_ATTACK)


func _on_combo_tier_changed(tier: int, player_id: int) -> void:
	# Combo tier 3+ triggers COMBAT_ZOOM
	if tier >= COMBO_TIER_ZOOM_THRESHOLD:
		_transition_to(CameraState.COMBAT_ZOOM)


func _on_boss_attack_started(attack_pattern: String) -> void:
	_transition_to(CameraState.BOSS_FOCUS)


func _on_boss_phase_changed(new_phase: int) -> void:
	# Boss phase change triggers maximum trauma and cinematic zoom
	add_trauma(TRAUMA_BOSS_PHASE)
	_transition_to(CameraState.BOSS_PHASE_CHANGE)


func _on_player_downed(player_id: int) -> void:
	# Player downed triggers crisis mode — max trauma, limits paused
	add_trauma(1.0)  # Max trauma
	_pause_limits()
	_crisis_return_pending = false  # Cancel any pending return
	_transition_to(CameraState.CRISIS)


func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
	# Resume limits immediately, but delay normal transition
	_resume_limits()
	# Start delayed transition to NORMAL after 0.5s
	_crisis_return_pending = true
	_state_timer = 0.0


# ─── Limit Management ───────────────────────────────────────────────────────────

var _limits_paused: bool = false
var _saved_limits: Dictionary = {
	"left": 0,
	"right": 1280,
	"top": 0,
	"bottom": 720
}
const LIMIT_MARGIN: int = 50


func _pause_limits() -> void:
	if _limits_paused:
		return
	# Save current limits
	# In production, these would come from Camera2D node
	_limits_paused = true
	# Set extreme limits to show entire arena
	# In production: Camera2D.limit_left = -99999, etc.


func _resume_limits() -> void:
	if not _limits_paused:
		return
	_limits_paused = false
	# Restore saved limits with margin
	# In production: Camera2D.limit_left = _saved_limits.left + LIMIT_MARGIN, etc.


func _start_crisis_return_timer() -> void:
	# Crisis returns to NORMAL after rescue delay via _update_state_timer
	pass


# ─── Trauma by Attack Type ─────────────────────────────────────────────────────

func _add_trauma_for_attack(attack_type: String) -> void:
	match attack_type:
		"LIGHT":
			add_trauma(TRAUMA_LIGHT)
		"MEDIUM":
			add_trauma(TRAUMA_MEDIUM)
		"HEAVY":
			add_trauma(TRAUMA_HEAVY)
		"SPECIAL":
			add_trauma(TRAUMA_SPECIAL)
		_:
			add_trauma(TRAUMA_MEDIUM)


# ─── State Machine ─────────────────────────────────────────────────────────────

func _transition_to(new_state: CameraState) -> void:
	if new_state == _current_state:
		# Reset timer if same state (don't restart)
		return

	_current_state = new_state
	_state_timer = 0.0

	match new_state:
		CameraState.PLAYER_ATTACK:
			_zoom = ATTACK_ZOOM
		CameraState.SYNC_ATTACK:
			_zoom = SYNC_ATTACK_ZOOM
		CameraState.COMBAT_ZOOM:
			_zoom = COMBAT_ZOOM
		CameraState.BOSS_FOCUS:
			_zoom = BOSS_FOCUS_ZOOM
		CameraState.BOSS_PHASE_CHANGE:
			_zoom = BOSS_PHASE_CHANGE_ZOOM
		CameraState.CRISIS:
			_zoom = CRISIS_ZOOM
		CameraState.NORMAL:
			_zoom = BASE_ZOOM
		_:
			pass  # Other states


func _update_state_timer(delta: float) -> void:
	_state_timer += delta

	match _current_state:
		CameraState.PLAYER_ATTACK:
			if _state_timer >= ATTACK_ZOOM_HOLD:
				_transition_to(CameraState.NORMAL)
		CameraState.SYNC_ATTACK:
			if _state_timer >= SYNC_ATTACK_HOLD:
				_transition_to(CameraState.NORMAL)
		CameraState.COMBAT_ZOOM:
			if _state_timer >= COMBAT_ZOOM_HOLD:
				_transition_to(CameraState.NORMAL)
		CameraState.BOSS_FOCUS:
			if _state_timer >= BOSS_FOCUS_HOLD:
				_transition_to(CameraState.NORMAL)
		CameraState.BOSS_PHASE_CHANGE:
			if _state_timer >= BOSS_PHASE_CHANGE_HOLD:
				_transition_to(CameraState.NORMAL)
		CameraState.CRISIS:
			if _crisis_return_pending and _state_timer >= CRISIS_HOLD:
				_crisis_return_pending = false
				_transition_to(CameraState.NORMAL)
		_:
			pass  # Other states have their own timers


# ─── Static Helpers ─────────────────────────────────────────────────────────────

static func get_trauma_for_attack_type(attack_type: String) -> float:
	match attack_type:
		"LIGHT": return TRAUMA_LIGHT
		"MEDIUM": return TRAUMA_MEDIUM
		"HEAVY": return TRAUMA_HEAVY
		"SPECIAL": return TRAUMA_SPECIAL
		_: return TRAUMA_MEDIUM
