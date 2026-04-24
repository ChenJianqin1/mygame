# paper_texture.gd — Paper texture overlay controller
# Implements animation-005 AC-6.1 through AC-6.2
# Paper texture overlay with opacity 0.15, jitter ±1.0px at 8Hz, squash/stretch effects.
class_name PaperTexture
extends Node2D

## Paper texture overlay opacity
const PAPER_TEXTURE_OPACITY: float = 0.15

## Paper jitter amplitude in pixels
const PAPER_JITTER_AMPLITUDE: float = 1.0

## Paper jitter frequency in Hz
const PAPER_JITTER_FREQUENCY: float = 8.0

## Squash/stretch intensity multiplier
const SQUASH_STRETCH_INTENSITY: float = 1.2

## Normal scale (no squash/stretch)
const NORMAL_SCALE: float = 1.0

@onready var _sprite: Sprite2D = $Sprite
var _target_sprite: Sprite2D = null
var _jitter_offset: Vector2 = Vector2.ZERO
var _time_elapsed: float = 0.0
var _is_active: bool = true

func _ready() -> void:
	_setup_texture_layer()

## Set the target sprite to apply paper texture to
func set_target_sprite(sprite: Sprite2D) -> void:
	_target_sprite = sprite
	if _target_sprite:
		_target_sprite.modulate.a = 1.0 - PAPER_TEXTURE_OPACITY

## Trigger squash/stretch effect (call on hit/impact)
func trigger_squash_stretch() -> void:
	if not _target_sprite:
		return

	# Simple squash/stretch: scale X and Y inversely
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)

	# Squash: scale X up, Y down
	tween.tween_property(_target_sprite, "scale", Vector2(SQUASH_STRETCH_INTENSITY, 1.0 / SQUASH_STRETCH_INTENSITY), 0.05)
	# Stretch: return to normal
	tween.tween_property(_target_sprite, "scale", Vector2(NORMAL_SCALE, NORMAL_SCALE), 0.15)


func _setup_texture_layer() -> void:
	# The PaperTexture node itself can hold a paper texture sprite
	# This is a simplified implementation - actual implementation would use
	# a dedicated texture asset
	pass


func _process(delta: float) -> void:
	if not _is_active:
		return

	_time_elapsed += delta

	# Calculate jitter offset using sine waves at 8Hz
	var jitter_x: float = sin(_time_elapsed * PAPER_JITTER_FREQUENCY * TAU) * PAPER_JITTER_AMPLITUDE
	var jitter_y: float = cos(_time_elapsed * PAPER_JITTER_FREQUENCY * TAU * 1.3) * PAPER_JITTER_AMPLITUDE

	_jitter_offset = Vector2(jitter_x, jitter_y)

	# Apply jitter to this node's position relative to target
	if _target_sprite:
		_target_sprite.position = _jitter_offset


func enable() -> void:
	_is_active = true


func disable() -> void:
	_is_active = false
	if _target_sprite:
		_target_sprite.position = Vector2.ZERO
