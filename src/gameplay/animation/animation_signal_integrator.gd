# animation_signal_integrator.gd — Signal wiring for animation system
# Implements animation-007 AC-8.1/8.2/8.3
# Subscribes to upstream signals, drives PlayerAnimationStateMachine, emits downstream signals
class_name AnimationSignalIntegrator
extends Node

## Player 1's animation state machine
var _p1_anim: PlayerAnimationStateMachine

## Player 2's animation state machine
var _p2_anim: PlayerAnimationStateMachine

## Downstream signals emitted by the animation system
signal animation_state_changed(player_id: int, state: String)
signal recovery_complete(player_id: int)
signal hitbox_activated(attack_type: String, position: Vector2)
signal sync_burst_visual(position: Vector2)
signal screen_edge_pulse(color: Color, duration: float)  ## For screen flash effects

## Sync Attack Visual Parameters
const SYNC_WINDOW_DURATION_FRAMES: int = 5
const SYNC_GLOW_RADIUS_MULTIPLIER: float = 1.15
const SYNC_PARTICLE_COUNT: int = 12
const SYNC_CHARGE_BLEND_RATE: float = 0.2  ## Per frame
const SCREEN_EDGE_PULSE_FREQUENCY: float = 2.0  ## Hz
const SCREEN_EDGE_PULSE_DURATION: float = 0.5  ## seconds

## Sync charge state tracking
var _sync_hitbox_expansion_active: bool = false
var _p1_sync_charge_active: bool = false
var _p2_sync_charge_active: bool = false
var _p1_anticipation_start_time: float = 0.0
var _p2_anticipation_start_time: float = 0.0
var _screen_edge_pulse_timer: float = 0.0

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_p1_anim = PlayerAnimationStateMachine.new()
	_p2_anim = PlayerAnimationStateMachine.new()
	_connect_upstream_signals()


func _connect_upstream_signals() -> void:
	# CombatSystem signals
	Events.attack_started.connect(_on_attack_started)
	Events.attack_hit.connect(_on_attack_hit)
	Events.hurt_received.connect(_on_hurt_received)

	# ComboSystem signals
	Events.sync_window_opened.connect(_on_sync_window_opened)
	Events.sync_burst_triggered.connect(_on_sync_burst)
	Events.combo_tier_escalated.connect(_on_combo_tier)

	# CoopSystem signals
	Events.player_downed.connect(_on_player_downed)
	Events.rescue_triggered.connect(_on_rescue_triggered)
	Events.player_rescued.connect(_on_player_rescued)
	Events.player_out.connect(_on_player_out)

	# BossAI signals
	Events.boss_phase_changed.connect(_on_boss_phase_changed)


# ─── Upstream Signal Handlers ───────────────────────────────────────────────────

func _on_attack_started(attack_type: String, player_id: int) -> void:
	var anim := _get_anim_for_player(player_id)
	if anim == null:
		return

	var state := _attack_type_to_state(attack_type)
	if state != null:
		anim.request_attack(state)


func _on_attack_hit(attack_id: int, is_grounded: bool, hit_count: int) -> void:
	pass  # Animation handles frame advancement via advance_frame()


func _on_hurt_received(damage: int, knockback: Vector2) -> void:
	# Both players can be hurt — but hurt_received only carries damage/knockback
	# Individual player hurt would need hurt_received(player_id, ...)
	# Placeholder: no per-player hurt signal available yet
	pass


func _on_sync_window_opened(player_id: int, partner_id: int) -> void:
	# Player opened sync window - apply charge glow to partner
	if player_id == 1:
		_apply_p1_sync_charge()
	elif player_id == 2:
		_apply_p2_sync_charge()


func _on_sync_burst(position: Vector2) -> void:
	# Sync burst VFX trigger
	sync_burst_visual.emit(position)

	# Activate hitbox expansion
	set_sync_hitbox_expansion(true)

	# Trigger screen edge pulse
	_trigger_screen_edge_pulse()


func _on_combo_tier(tier: int, player_color: Color) -> void:
	# Combo tier escalation — could trigger animation escalation
	# Currently tier changes don't directly affect animation state
	pass


func _on_player_downed(player_id: int) -> void:
	var anim := _get_anim_for_player(player_id)
	if anim != null:
		anim.request_hurt()


func _on_rescue_triggered(rescuer_id: int, downed_id: int) -> void:
	var anim := _get_anim_for_player(rescuer_id)
	if anim != null:
		# Trigger rescue animation state
		anim.request_hurt()  # Rescue uses hurt state as placeholder


func _on_player_rescued(player_id: int, rescuer_color: Color) -> void:
	var anim := _get_anim_for_player(player_id)
	if anim != null:
		anim.request_idle()


func _on_player_out(player_id: int) -> void:
	var anim := _get_anim_for_player(player_id)
	if anim != null:
		anim.request_hurt()  # Defeat state


func _on_boss_phase_changed(new_phase: int) -> void:
	# Boss phase change doesn't directly affect player animation state
	pass


# ─── Sync Attack Visual Methods ─────────────────────────────────────────────────

## Activate/deactivate sync hitbox expansion (1.15x radius).
func set_sync_hitbox_expansion(active: bool) -> void:
	_sync_hitbox_expansion_active = active
	# Notify CombatManager of hitbox multiplier change
	if Events:
		if active:
			Events.sync_burst_triggered.emit(Vector2.ZERO)  # Signal that sync is active
		else:
			pass  # Sync ended, normal hitbox radius restored


## Apply sync charge glow to P1.
func _apply_p1_sync_charge() -> void:
	_p1_sync_charge_active = true
	_p1_anticipation_start_time = Time.get_ticks_msec() / 1000.0


## Apply sync charge glow to P2.
func _apply_p2_sync_charge() -> void:
	_p2_sync_charge_active = true
	_p2_anticipation_start_time = Time.get_ticks_msec() / 1000.0


## Fade out sync charge glow.
func _fade_sync_charge_glow(player_id: int) -> void:
	if player_id == 1:
		_p1_sync_charge_active = false
	elif player_id == 2:
		_p2_sync_charge_active = false


## Calculate sync charge blend (0.0 to 1.0) based on timing.
## Formula: clamp((P1_hit_time - P2_anticipation_start_time) / SYNC_WINDOW_DURATION, 0.0, 1.0)
func _calculate_sync_charge_blend(p1_hit_time: float, p2_anticipation_start: float, window_frames: int) -> float:
	var window_duration: float = window_frames / 60.0  # Convert frames to seconds
	var elapsed: float = p1_hit_time - p2_anticipation_start
	var blend: float = elapsed / window_duration
	return clampf(blend, 0.0, 1.0)


## Trigger screen edge pulse effect.
func _trigger_screen_edge_pulse() -> void:
	_screen_edge_pulse_timer = SCREEN_EDGE_PULSE_DURATION
	# Emit alternating orange (#F5A623) and blue (#4ECDC4) pulse
	var pulse_color := Color("#F5A623") if fmod(_screen_edge_pulse_timer, 1.0 / SCREEN_EDGE_PULSE_FREQUENCY) < 0.5 else Color("#4ECDC4")
	screen_edge_pulse.emit(pulse_color, SCREEN_EDGE_PULSE_DURATION)


# ─── Internal ─────────────────────────────────────────────────────────────────

func _get_anim_for_player(player_id: int) -> PlayerAnimationStateMachine:
	if player_id == 1:
		return _p1_anim
	elif player_id == 2:
		return _p2_anim
	return null


func _attack_type_to_state(attack_type: String) -> int:
	match attack_type:
		"light":  return PlayerAnimationStateMachine.State.LIGHT_ATTACK
		"medium": return PlayerAnimationStateMachine.State.MEDIUM_ATTACK
		"heavy":  return PlayerAnimationStateMachine.State.HEAVY_ATTACK
		"special": return PlayerAnimationStateMachine.State.SPECIAL_ATTACK
		"sync":   return PlayerAnimationStateMachine.State.SYNC_ATTACK
	return PlayerAnimationStateMachine.State.IDLE


# ─── Per-Frame Update ───────────────────────────────────────────────────────────

## Call each animation frame to advance both players' state machines
func update() -> void:
	_p1_anim.advance_frame()
	_p2_anim.advance_frame()

	# Update screen edge pulse timer
	if _screen_edge_pulse_timer > 0:
		_screen_edge_pulse_timer -= get_process_delta_time()
		if _screen_edge_pulse_timer <= 0:
			_screen_edge_pulse_timer = 0.0


# ─── Downstream Signal Emission ───────────────────────────────────────────────

## Call when a recovery animation completes
func _emit_recovery_complete(player_id: int) -> void:
	recovery_complete.emit(player_id)


## Call when animation state changes
func _emit_animation_state_changed(player_id: int, state: int) -> void:
	var state_name := PlayerAnimationStateMachine.State.keys()[state]
	animation_state_changed.emit(player_id, state_name)
