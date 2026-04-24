# animation_performance_manager.gd — Performance optimization for animations
# Implements animation-008 AC-7.1 through AC-7.3
# Offscreen animation pause, memory budgets, frame time monitoring
class_name AnimationPerformanceManager
extends Node

## Performance budgets from GDD and technical preferences
const MAX_SPRITE_MEMORY_MB: float = 24.0
const MAX_TOTAL_MEMORY_MB: float = 40.0
const MAX_CONCURRENT_CHARACTERS: int = 3
const FRAME_TIME_BUDGET_MS: float = 12.0

## Offscreen optimization
const OFFSCREEN_OPTIMIZATION_THRESHOLD: int = 6

var _tracked_characters: Array[Node] = []
var _is_monitoring: bool = false
var _frame_time_history: Array[float] = []
var _current_frame_time: float = 0.0
var _is_over_budget: bool = false

signal frame_time_warning(frame_time_ms: float, budget_ms: float)
signal memory_warning(current_mb: float, budget_mb: float)
signal offscreen_pause_triggered(character: Node)
signal offscreen_resume_triggered(character: Node)

func _ready() -> void:
	_is_monitoring = true


## Track a character for performance optimization
func track_character(character: Node) -> void:
	if not _tracked_characters.has(character):
		_tracked_characters.append(character)


## Untrack a character when it's removed
func untrack_character(character: Node) -> void:
	_tracked_characters.erase(character)


## Monitor frame time - call at end of _process
func monitor_frame_time(delta: float) -> void:
	_current_frame_time = delta * 1000.0  # Convert to ms

	_frame_time_history.push_back(_current_frame_time)
	if _frame_time_history.size() > 60:
		_frame_time_history.pop_front()

	# Check if over budget (sustained)
	var over_budget_count := 0
	for ft in _frame_time_history:
		if ft > FRAME_TIME_BUDGET_MS:
			over_budget_count += 1

	_is_over_budget = over_budget_count > 30  # More than half of last 60 frames

	if _is_over_budget and _frame_time_history.size() >= 60:
		frame_time_warning.emit(_current_frame_time, FRAME_TIME_BUDGET_MS)


## Get average frame time over the last second (60 frames at 60fps)
func get_average_frame_time() -> float:
	if _frame_time_history.is_empty():
		return 0.0
	var total: float = 0.0
	for ft in _frame_time_history:
		total += ft
	return total / _frame_time_history.size()


## Returns true if frame time is currently over budget
func is_over_frame_budget() -> bool:
	return _is_over_budget


## Pause animation on character when it goes offscreen
## Call this from VisibleOnScreenNotifier2D.screen_exited
func on_character_exited_screen(character: Node) -> void:
	if not _tracked_characters.has(character):
		return

	_set_character_paused(character, true)
	offscreen_pause_triggered.emit(character)


## Resume animation on character when it returns to screen
## Call this from VisibleOnScreenNotifier2D.screen_entered
func on_character_entered_screen(character: Node) -> void:
	if not _tracked_characters.has(character):
		return

	_set_character_paused(character, false)
	offscreen_resume_triggered.emit(character)


func _set_character_paused(character: Node, paused: bool) -> void:
	# Try to pause AnimationTree if character has one
	if character.has_method("set_animation_paused"):
		character.set_animation_paused(paused)

	# Set process mode for offscreen optimization
	if paused:
		character.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		character.process_mode = Node.PROCESS_MODE_INHERIT


## Get estimated sprite memory usage in MB
## This is an approximation - actual usage depends on texture compression
func get_sprite_memory_mb() -> float:
	# In a real implementation, this would query the Renderer
	# For now, return a placeholder based on character count
	var base_memory_per_character: float = 8.0  # ~8MB per character with animations
	return float(_tracked_characters.size()) * base_memory_per_character


## Check if memory is within budget
func is_within_memory_budget() -> bool:
	return get_sprite_memory_mb() <= MAX_SPRITE_MEMORY_MB


## Get the number of actively tracked characters
func get_tracked_character_count() -> int:
	return _tracked_characters.size()


## Get the number of characters currently offscreen
func get_offscreen_character_count() -> int:
	var count := 0
	for character in _tracked_characters:
		if not _is_on_screen(character):
			count += 1
	return count


func _is_on_screen(character: Node) -> bool:
	if not is_instance_valid(character):
		return false
	var screen_rect := character.get_viewport().get_visible_rect()
	var character_pos := character.global_position
	return screen_rect.has_point(character_pos)


## Reset frame time history (call on scene change)
func reset_monitoring() -> void:
	_frame_time_history.clear()
	_current_frame_time = 0.0
	_is_over_budget = false
