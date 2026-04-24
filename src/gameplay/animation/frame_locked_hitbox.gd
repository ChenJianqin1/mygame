# frame_locked_hitbox.gd — Frame-locked hitbox activation controller
# Implements animation-002 AC-2.1 through AC-2.3
# Hitbox activation is synchronized to animation frames, not timers.
# This class is instantiated per attack to manage the hitbox's active window.
class_name FrameLockedHitbox
extends RefCounted

## Signals emitted by the frame-locked hitbox controller
signal hitbox_activated(attack_type: String, position: Vector2)
signal hitbox_deactivated()

## Attack frame ranges from PlayerAnimationStateMachine.ATTACK_FRAMES
const HITBOX_ACTIVE_RANGES := {
	"LIGHT": { "first": 8, "last": 9 },    # frames 8-9 active
	"MEDIUM": { "first": 14, "last": 16 }, # frames 14-16 active
	"HEAVY": { "first": 20, "last": 23 },  # frames 20-23 active
	"SPECIAL": { "first": 28, "last": 33 } # frames 28-33 active
}

## Derived from formula:
## first = anticipation_frames
## last = anticipation_frames + active_frames - 1

var _attack_type: String
var _current_frame: int = 0
var _is_active: bool = false

func _init(attack_type: String) -> void:
	_attack_type = attack_type
	_current_frame = 0
	_is_active = false

## Advance by one animation frame.
## Returns true if hitbox is currently in its active window.
func advance_frame() -> bool:
	_current_frame += 1
	return _check_active_state()

## Advance by multiple frames (for lag simulation)
func advance_frames(count: int) -> bool:
	for i in count:
		_current_frame += 1
		_check_active_state()
	return _is_active

## Get the current animation frame
func get_current_frame() -> int:
	return _current_frame

## Get the active range for the current attack type
func get_active_range() -> Dictionary:
	return HITBOX_ACTIVE_RANGES.get(_attack_type, { "first": 0, "last": 0 })

## Returns true if hitbox is currently in its active window
func is_hitbox_active() -> bool:
	return _is_active

func _check_active_state() -> bool:
	var range_dict: Dictionary = HITBOX_ACTIVE_RANGES.get(_attack_type, { "first": 0, "last": 0 })
	if range_dict.is_empty():
		return false

	var first: int = range_dict.get("first", 0)
	var last: int = range_dict.get("last", 0)

	var was_active := _is_active
	_is_active = (_current_frame >= first) and (_current_frame <= last)

	# Emit signals on state transitions
	if _is_active and not was_active:
		hitbox_activated.emit(_attack_type, Vector2.ZERO)  # Position set by caller
	elif not _is_active and was_active:
		hitbox_deactivated.emit()

	return _is_active
