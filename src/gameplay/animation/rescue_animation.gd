# rescue_animation.gd — Rescue animation sequence controller
# Implements animation-006 AC-7.1 through AC-7.3
# Rescue timing: execute (12 frames), revive (18 frames), downtime loop (180 frames), rescued iframes (90 frames)
class_name RescueAnimation
extends Node2D

## Frame counts at 60fps
const RESCUE_EXECUTE_FRAMES: int = 12       ## Animation execution
const RESCUE_REVIVE_FRAMES: int = 18        ## Revive animation
const DOWNTIME_LOOP_FRAMES: int = 180       ## Downtime looping animation (3 seconds)
const RESCUED_IFRAMES_FRAMES: int = 90      ## Invincibility after rescue (1.5 seconds)

## Rescue window timing (in seconds)
const RESCUE_WINDOW_TOTAL: float = 3.0     ## Total rescue window
const RESCUE_MUST_START_BY: float = 2.5     ## Must start rescue by this time

## Animation states
enum RescueAnimState {
	IDLE,
	DOWNTIME,
	RESCUE_EXECUTE,
	RESCUE_REVIVE,
	RESCUED_IFRAMES
}

signal rescue_complete(player_id: int)
signal downtime_loop_started(player_id: int)
signal rescued_iframes_started(player_id: int, duration: float)

var _current_state: RescueAnimState = RescueAnimState.IDLE
var _player_id: int = 1
var _downtime_timer: float = 0.0
var _rescue_timer: float = 0.0
var _is_rescue_in_progress: bool = false
var _can_rescue: bool = false

func _ready() -> void:
	_current_state = RescueAnimState.IDLE

## Start the downtime animation sequence
func start_downtime(player_id: int) -> void:
	_player_id = player_id
	_current_state = RescueAnimState.DOWNTIME
	_downtime_timer = 0.0
	_can_rescue = true
	downtime_loop_started.emit(_player_id)

## Attempt to start rescue (returns true if rescue can be initiated)
func attempt_rescue() -> bool:
	if not _can_rescue:
		return false

	if _current_state == RescueAnimState.DOWNTIME:
		# Check if within rescue window
		if _downtime_timer < RESCUE_MUST_START_BY:
			_start_rescue_execute()
			return true
		else:
			# Too late - rescue window expired
			_can_rescue = false
			return false

	return false


func _start_rescue_execute() -> void:
	_current_state = RescueAnimState.RESCUE_EXECUTE
	_is_rescue_in_progress = true
	_rescue_timer = 0.0


func _process(delta: float) -> void:
	match _current_state:
		RescueAnimState.DOWNTIME:
			_downtime_timer += delta
			if _downtime_timer >= RESCUE_WINDOW_TOTAL:
				# Rescue window expired - player is OUT
				_can_rescue = false

		RescueAnimState.RESCUE_EXECUTE:
			_rescue_timer += delta
			var frame_count := int(_rescue_timer * 60.0)
			if frame_count >= RESCUE_EXECUTE_FRAMES:
				_start_rescue_revive()

		RescueAnimState.RESCUE_REVIVE:
			_rescue_timer += delta
			var frame_count := int(_rescue_timer * 60.0)
			if frame_count >= RESCUE_REVIVE_FRAMES:
				_start_rescued_iframes()

		RescueAnimState.RESCUED_IFRAMES:
			_rescue_timer += delta
			var frame_count := int(_rescue_timer * 60.0)
			if frame_count >= RESCUED_IFRAMES_FRAMES:
				_complete_rescue()


func _start_rescue_revive() -> void:
	_current_state = RescueAnimState.RESCUE_REVIVE
	_rescue_timer = 0.0


func _start_rescued_iframes() -> void:
	_current_state = RescueAnimState.RESCUED_IFRAMES
	_rescue_timer = 0.0
	var iframe_duration := float(RESCUED_IFRAMES_FRAMES) / 60.0
	rescued_iframes_started.emit(_player_id, iframe_duration)


func _complete_rescue() -> void:
	_current_state = RescueAnimState.IDLE
	_is_rescue_in_progress = false
	rescue_complete.emit(_player_id)


## Get remaining rescue time as a ratio (1.0 = full window, 0.0 = expired)
func get_rescue_time_remaining() -> float:
	if _current_state != RescueAnimState.DOWNTIME:
		return 0.0
	return clampf(1.0 - (_downtime_timer / RESCUE_WINDOW_TOTAL), 0.0, 1.0)


## Returns true if rescue can still be attempted
func is_rescue_available() -> bool:
	return _can_rescue and _current_state == RescueAnimState.DOWNTIME


## Get current animation state
func get_state() -> RescueAnimState:
	return _current_state


## Reset the rescue animation (call on respawn)
func reset() -> void:
	_current_state = RescueAnimState.IDLE
	_downtime_timer = 0.0
	_rescue_timer = 0.0
	_is_rescue_in_progress = false
	_can_rescue = false
