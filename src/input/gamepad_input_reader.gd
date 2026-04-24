# GamepadInputReader.gd — Dual gamepad input reader
# Reads InputMap actions for two gamepads and emits Events.input_action signals.
# Part of Foundation Layer (Story 003).
extends Node
class_name GamepadInputReader

## GamepadInputReader — 读取两个手柄输入并发射到 Events 信号总线。
## P1 手柄 device_index=joypads[0]，P2 手柄 device_index=joypads[1]。
## 遵循 ADR-ARCH-001，所有跨系统信号经 Events 中继。

# Player ID constants
const PLAYER_ID_P1 := 1
const PLAYER_ID_P2 := 2

# Dead zone threshold
const DEAD_ZONE_THRESHOLD := 0.15

# Input action name constants (InputMap actions — must match project.godot)
const ACTION_MOVE_P1 := &"move_p1_gamepad"
const ACTION_MOVE_P2 := &"move_p2_gamepad"
const ACTION_JUMP_P1 := &"jump_p1_gamepad"
const ACTION_JUMP_P2 := &"jump_p2_gamepad"
const ACTION_DODGE_P1 := &"dodge_p1_gamepad"
const ACTION_DODGE_P2 := &"dodge_p2_gamepad"
const ACTION_ATTACK_LIGHT_P1 := &"attack_light_p1_gamepad"
const ACTION_ATTACK_LIGHT_P2 := &"attack_light_p2_gamepad"
const ACTION_ATTACK_HEAVY_P1 := &"attack_heavy_p1_gamepad"
const ACTION_ATTACK_HEAVY_P2 := &"attack_heavy_p2_gamepad"

## 语义 action 名称（无 player 后缀），因为 player_id 已区分玩家
const ACTION_JUMP := &"jump"
const ACTION_DODGE := &"dodge"
const ACTION_ATTACK_LIGHT := &"attack_light"
const ACTION_ATTACK_HEAVY := &"attack_heavy"
const ACTION_MOVE_HORIZONTAL := &"move_horizontal"

var _p1_device: int = -1
var _p2_device: int = -1

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Events.input_cleared.connect(_on_input_cleared)
	_detect_joypads()

func _on_input_cleared() -> void:
	# No internal state to clear — Input action states are released by FocusLossHandler.
	# This subscription exists to ensure future internal state would be reset and
	# to make integration testable via signal observation.
	pass

func _physics_process(_delta: float) -> void:
	if _p1_device >= 0:
		_process_gamepad(_p1_device, PLAYER_ID_P1)
	if _p2_device >= 0:
		_process_gamepad(_p2_device, PLAYER_ID_P2)

func _detect_joypads() -> void:
	var joypads: Array[int] = Input.get_connected_joypads()
	_p1_device = joypads[0] if joypads.size() > 0 else -1
	_p2_device = joypads[1] if joypads.size() > 1 else -1

func _on_joy_connection_changed(device_index: int, connected: bool) -> void:
	if connected:
		_handle_joypad_connect(device_index)
	else:
		_handle_joypad_disconnect(device_index)

func _handle_joypad_connect(device_index: int) -> void:
	var joypads: Array[int] = Input.get_connected_joypads()
	# Only first two gamepads are used (P1 and P2)
	if joypads.size() > 2 and device_index != joypads[0] and device_index != joypads[1]:
		_debug_log("Unknown device index %d ignored — only first two gamepads are used" % device_index)
		return  # Third+ gamepad ignored silently
	_detect_joypads()
	# Emit mode changed for the connected device's player slot
	if device_index == _p1_device:
		Events.device_assigned.emit(PLAYER_ID_P1, device_index)
		Events.device_mode_changed.emit(PLAYER_ID_P1, &"gamepad")
		Events.device_status_message.emit(PLAYER_ID_P1, "Player 1 手柄已连接")
	elif device_index == _p2_device:
		Events.device_assigned.emit(PLAYER_ID_P2, device_index)
		Events.device_mode_changed.emit(PLAYER_ID_P2, &"gamepad")
		Events.device_status_message.emit(PLAYER_ID_P2, "Player 2 手柄已连接")

func _debug_log(message: String) -> void:
	# Debug logging for unknown device events — does not affect gameplay
	push_debug(message)

func _handle_joypad_disconnect(device_index: int) -> void:
	var player_id := -1
	if device_index == _p1_device:
		_p1_device = -1
		player_id = PLAYER_ID_P1
	elif device_index == _p2_device:
		_p2_device = -1
		player_id = PLAYER_ID_P2
	if player_id > 0:
		Events.device_mode_changed.emit(player_id, &"keyboard")
		Events.device_status_message.emit(player_id, "Player %d 手柄已断开" % player_id)

func _process_gamepad(device_index: int, player_id: int) -> void:
	# Defensive: verify device is still connected before processing
	if not Input.is_joypad_connected(device_index):
		return
	# Discrete actions — emit on just pressed (one-shot)
	if Input.is_action_just_pressed(ACTION_JUMP_P1 if player_id == PLAYER_ID_P1 else ACTION_JUMP_P2, device_index):
		Events.input_action.emit(player_id, ACTION_JUMP, 1.0)

	if Input.is_action_just_pressed(ACTION_DODGE_P1 if player_id == PLAYER_ID_P1 else ACTION_DODGE_P2, device_index):
		Events.input_action.emit(player_id, ACTION_DODGE, 1.0)

	if Input.is_action_just_pressed(ACTION_ATTACK_LIGHT_P1 if player_id == PLAYER_ID_P1 else ACTION_ATTACK_LIGHT_P2, device_index):
		Events.input_action.emit(player_id, ACTION_ATTACK_LIGHT, 1.0)

	if Input.is_action_just_pressed(ACTION_ATTACK_HEAVY_P1 if player_id == PLAYER_ID_P1 else ACTION_ATTACK_HEAVY_P2, device_index):
		Events.input_action.emit(player_id, ACTION_ATTACK_HEAVY, 1.0)

	# Continuous movement — apply dead zone
	var move_action := ACTION_MOVE_P1 if player_id == PLAYER_ID_P1 else ACTION_MOVE_P2
	var raw_strength := Input.get_action_raw_strength(move_action, device_index)
	var clamped := _apply_dead_zone(raw_strength)
	if clamped != 0.0:
		Events.input_action.emit(player_id, ACTION_MOVE_HORIZONTAL, clamped)

func _apply_dead_zone(raw: float) -> float:
	if abs(raw) < DEAD_ZONE_THRESHOLD:
		return 0.0
	# Linear remap: (raw - threshold) / (1.0 - threshold), preserving sign
	var sign_val := 1.0 if raw > 0 else -1.0
	var magnitude := 1.0 - DEAD_ZONE_THRESHOLD
	if magnitude <= 0.0:
		return sign_val  # Degenerate case: threshold too high, return raw direction only
	return sign_val * (abs(raw) - DEAD_ZONE_THRESHOLD) / magnitude
