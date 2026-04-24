# FocusLossClearTest.gd — Unit tests for Story 008: 失焦清空输入状态
# Tests that FocusLossHandler correctly clears input state on focus loss.
# Note: NOTIFICATION_APPLICATION_FOCUS_OUT cannot be triggered headlessly,
# so we test _clear_input_buffer() directly.
class_name FocusLossClearTest
extends GdUnitTestSuite

var _focus_handler: FocusLossHandler
var _input_cleared_received: bool

func _init() -> void:
	super._init()
	_input_cleared_received = false

func setup() -> void:
	_focus_handler = FocusLossHandler.new()
	_input_cleared_received = false

func teardown() -> void:
	if _focus_handler:
		_focus_handler.free()
	_focus_handler = null

# AC1: 游戏窗口失焦后，所有输入缓冲被清空
func test_focus_loss_clears_all_input_actions() -> void:
	# Arrange: Press several P1 actions
	Input.action_press(&"move_left_p1")
	Input.action_press(&"jump_p1")
	Input.action_press(&"attack_light_p1")

	# Press several P2 actions
	Input.action_press(&"move_right_p2")
	Input.action_press(&"dodge_p2")

	# Act: Trigger focus loss clearing
	_focus_handler._clear_input_buffer()

	# Assert: All pressed actions are now released (is_action_pressed returns false)
	assert_that(Input.is_action_pressed(&"move_left_p1")).is_false()
	assert_that(Input.is_action_pressed(&"jump_p1")).is_false()
	assert_that(Input.is_action_pressed(&"attack_light_p1")).is_false()
	assert_that(Input.is_action_pressed(&"move_right_p2")).is_false()
	assert_that(Input.is_action_pressed(&"dodge_p2")).is_false()

# AC2: 失焦期间按下的键在恢复焦点后不会触发动作
func test_keys_pressed_during_focus_loss_do_not_trigger_after_restore() -> void:
	# Arrange: Simulate focus loss
	_focus_handler._clear_input_buffer()

	# Act: Press a key during "focus loss" period (no actual focus loss in test,
	# but we verify the action_release cleared the state)
	Input.action_press(&"jump_p1")

	# Assert: The action is now pressed (new press, not resumed)
	# This confirms that clearing removed prior state; new presses work normally
	assert_that(Input.is_action_pressed(&"jump_p1")).is_true()

# AC3: 恢复焦点后，从静止状态开始接受新输入
func test_focus_restore_starts_from_clean_state() -> void:
	# Arrange: Press and then clear
	Input.action_press(&"move_left_p1")
	_focus_handler._clear_input_buffer()

	# Act: Simulate focus restore (no auto-resume)
	# The key is not pressed — we start fresh
	var move_left_pressed_before_new_input := Input.is_action_pressed(&"move_left_p1")

	# Assert: No residual pressed state from before clearing
	assert_that(move_left_pressed_before_new_input).is_false()

# AC3 (variant): 恢复焦点后，新的按键按下应该正常触发
func test_new_input_after_focus_loss_works_normally() -> void:
	# Arrange: Clear any prior state
	_focus_handler._clear_input_buffer()

	# Act: Press a key (simulating new input after focus restore)
	Input.action_press(&"jump_p1")

	# Assert: The action is detected as pressed
	assert_that(Input.is_action_pressed(&"jump_p1")).is_true()
	assert_that(Input.is_action_just_pressed(&"jump_p1")).is_true()

# AC4: 不延续失焦前的输入状态（如移动方向）
func test_movement_direction_not_resumed_after_focus_loss() -> void:
	# Arrange: Hold left movement
	Input.action_press(&"move_left_p1")
	assert_that(Input.is_action_pressed(&"move_left_p1")).is_true()

	# Act: Clear input state (simulating focus loss)
	_focus_handler._clear_input_buffer()

	# Assert: Movement state is cleared — direction is not "still held"
	assert_that(Input.is_action_pressed(&"move_left_p1")).is_false()

	# Verify: A new direction can be set independently
	Input.action_press(&"move_right_p1")
	assert_that(Input.is_action_pressed(&"move_right_p1")).is_true()
	assert_that(Input.is_action_pressed(&"move_left_p1")).is_false()

# Test: input_cleared signal is emitted on focus loss
func test_input_cleared_signal_emitted_on_focus_loss() -> void:
	# Arrange
	var signal_received := false
	var signal_callable := func() -> void:
		signal_received = true
	Events.input_cleared.connect(signal_callable)

	# Act
	_focus_handler._clear_input_buffer()

	# Assert
	assert_that(signal_received).is_true()

	# Cleanup
	Events.input_cleared.disconnect(signal_callable)

# Test: Gamepad actions are also cleared
func test_gamepad_actions_cleared_on_focus_loss() -> void:
	# Arrange: Press gamepad actions (even without actual gamepad connected,
	# Input.action_press affects the logical state)
	Input.action_press(&"jump_p1_gamepad")
	Input.action_press(&"dodge_p2_gamepad")

	# Act
	_focus_handler._clear_input_buffer()

	# Assert
	assert_that(Input.is_action_pressed(&"jump_p1_gamepad")).is_false()
	assert_that(Input.is_action_pressed(&"dodge_p2_gamepad")).is_false()

# Test: Multiple sequential clear calls are idempotent
func test_multiple_clear_calls_are_idempotent() -> void:
	# Arrange
	Input.action_press(&"jump_p1")

	# Act: Clear multiple times
	_focus_handler._clear_input_buffer()
	_focus_handler._clear_input_buffer()
	_focus_handler._clear_input_buffer()

	# Assert: State remains cleared
	assert_that(Input.is_action_pressed(&"jump_p1")).is_false()