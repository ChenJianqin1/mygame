# FocusLossHandler.gd — Handles game window focus loss and clears input state
# Implements Story 008: 失焦清空输入状态
# Part of Foundation Layer — Input System.
extends Node
class_name FocusLossHandler

## FocusLossHandler — 监听窗口焦点丢失事件，清空所有输入状态。
## 当游戏窗口失焦（NOTIFICATION_APPLICATION_FOCUS_OUT）时：
##   1. 释放所有已按下的 InputMap actions
##   2. 发射 Events.input_cleared 信号通知其他系统
## 当焦点恢复（NOTIFICATION_APPLICATION_FOCUS_IN）时：
##   不自动恢复任何状态，必须重新按下按键才能触发动作。
## 遵循 ADR-ARCH-001，所有跨系统信号经 Events 中继。

# All InputMap actions that need to be released on focus loss
# P1 keyboard actions
const _P1_ACTIONS := [
	&"move_left_p1",
	&"move_right_p1",
	&"jump_p1",
	&"dodge_p1",
	&"attack_light_p1",
	&"attack_heavy_p1",
]

# P2 keyboard actions
const _P2_ACTIONS := [
	&"move_left_p2",
	&"move_right_p2",
	&"jump_p2",
	&"dodge_p2",
	&"attack_light_p2",
	&"attack_heavy_p2",
]

# Gamepad actions (shared, no player suffix in InputMap but device-specific at runtime)
const _GAMEPAD_ACTIONS := [
	&"move_p1_gamepad",
	&"move_p2_gamepad",
	&"jump_p1_gamepad",
	&"jump_p2_gamepad",
	&"dodge_p1_gamepad",
	&"dodge_p2_gamepad",
	&"attack_light_p1_gamepad",
	&"attack_light_p2_gamepad",
	&"attack_heavy_p1_gamepad",
	&"attack_heavy_p2_gamepad",
]

func _notification(what: int) -> void:
	match what:
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
			_clear_input_buffer()
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
			# Focus restored — do NOT auto-resume any state.
			# Input system must re-detect fresh presses.
			pass

## Clears all input state: releases all known InputMap actions and emits input_cleared.
## Called on focus loss. Made public so tests can call it directly.
func _clear_input_buffer() -> void:
	# Release all P1 keyboard actions
	for action in _P1_ACTIONS:
		Input.action_release(action)

	# Release all P2 keyboard actions
	for action in _P2_ACTIONS:
		Input.action_release(action)

	# Release all gamepad actions
	for action in _GAMEPAD_ACTIONS:
		Input.action_release(action)

	# Emit signal to notify other systems (e.g., input readers may have internal state)
	Events.input_cleared.emit()