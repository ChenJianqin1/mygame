# P2InputReader.gd — P2 keyboard input reader
# Reads InputMap actions and emits Events.input_action signals.
# Part of Foundation Layer (Story 002).
extends Node
class_name P2InputReader

## P2InputReader — 读取 P2 键盘输入并发射到 Events 信号总线。
## P2 使用方向键（↑↓←→）和 Numpad（1, 2）控制。
## 遵循 ADR-ARCH-001，所有跨系统信号经 Events 中继。

# Player ID constant
const PLAYER_ID_P2 := 2

# Input action name constants (must match project.godot InputMap)
const ACTION_MOVE_LEFT := &"move_left_p2"
const ACTION_MOVE_RIGHT := &"move_right_p2"
## move_horizontal 是左右 strength 计算出的 Net 结果，非原始 InputMap action
const ACTION_MOVE_HORIZONTAL := &"move_horizontal"
## 语义 action 名称（无 player 后缀），因为 player_id 已区分玩家
const ACTION_JUMP := &"jump"
const ACTION_DODGE := &"dodge"
const ACTION_ATTACK_LIGHT := &"attack_light"
const ACTION_ATTACK_HEAVY := &"attack_heavy"

func _ready() -> void:
	Events.input_cleared.connect(_on_input_cleared)

func _physics_process(_delta: float) -> void:
	_process_p2_input()

func _on_input_cleared() -> void:
	# No internal state to clear — Input action states are released by FocusLossHandler.
	# This subscription exists to ensure future internal state would be reset and
	# to make integration testable via signal observation.
	pass

func _process_p2_input() -> void:
	# Discrete actions — emit on just pressed (one-shot)
	if Input.is_action_just_pressed(ACTION_JUMP):
		Events.input_action.emit(PLAYER_ID_P2, ACTION_JUMP, 1.0)

	if Input.is_action_just_pressed(ACTION_DODGE):
		Events.input_action.emit(PLAYER_ID_P2, ACTION_DODGE, 1.0)

	if Input.is_action_just_pressed(ACTION_ATTACK_LIGHT):
		Events.input_action.emit(PLAYER_ID_P2, ACTION_ATTACK_LIGHT, 1.0)

	if Input.is_action_just_pressed(ACTION_ATTACK_HEAVY):
		Events.input_action.emit(PLAYER_ID_P2, ACTION_ATTACK_HEAVY, 1.0)

	# Continuous movement — emit raw strength for analog movement
	var move_left_strength := Input.get_action_raw_strength(ACTION_MOVE_LEFT)
	var move_right_strength := Input.get_action_raw_strength(ACTION_MOVE_RIGHT)

	# Net horizontal movement: right is positive, left is negative
	var net_move := move_right_strength - move_left_strength
	if net_move != 0.0:
		Events.input_action.emit(PLAYER_ID_P2, ACTION_MOVE_HORIZONTAL, net_move)
