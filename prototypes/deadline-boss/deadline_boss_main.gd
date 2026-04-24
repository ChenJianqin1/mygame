# deadline_boss_main.gd — Main game controller for Deadline Boss prototype
extends Node2D

## Deadline Boss Prototype Main Controller

signal game_over()
signal game_win()

# Arena settings
const ARENA_LEFT: float = 0.0
const ARENA_RIGHT: float = 1280.0
const ARENA_TOP: float = 0.0
const ARENA_BOTTOM: float = 720.0

# Compression wall
const WALL_DAMAGE_RATE: float = 10.0  # HP per second in danger zone

var _players: Array = []
var _boss_ai: Node = null
var _camera: Node = null
var _game_over: bool = false
var _game_won: bool = false

@onready var _wall_line: Line2D = $CompressionWall/Line2D
@onready var _wall_color: ColorRect = $CompressionWall/ColorRect
@onready var _boss_hp_bar: ProgressBar = $UI/BossHPBar
@onready var _p1_hp_bar: ProgressBar = $UI/P1HPBar
@onready var _p2_hp_bar: ProgressBar = $UI/P2HPBar
@onready var _p1_hp_label: Label = $UI/P1HPLabel
@onready var _p2_hp_label: Label = $UI/P2HPLabel
@onready var _phase_label: Label = $UI/PhaseLabel
@onready var _compression_label: Label = $UI/CompressionLabel

func _ready() -> void:
	# Get references to players
	_players = get_tree().get_nodes_in_group("players")
	_boss_ai = BossAIManager
	# BossAIManager is autoload - _ready() is called by Godot automatically
	# but we need to ensure initial state is set
	_boss_ai._ready()

	# Setup camera - CameraController is autoload, _ready() already called
	_camera = CameraController

	# Connect to events
	_boss_ai.boss_hp_changed.connect(_on_boss_hp_changed)
	_boss_ai.boss_phase_changed.connect(_on_boss_phase_changed)

	# Initialize UI
	_update_hp_bars()
	_update_phase_label()

	print("Deadline Boss Prototype initialized")
	print("P1: WASD + J to attack")
	print("P2: Arrows + Numpad0 to attack")


func _process(delta: float) -> void:
	if _game_over or _game_won:
		return

	# Update boss AI
	_boss_ai.update(delta)

	# Update compression wall visual
	_update_compression_wall_visual()

	# Apply compression wall damage to players in danger zone
	_apply_wall_damage(delta)

	# Update camera
	_update_camera()

	# Update UI
	_update_hp_bars()
	_update_compression_label()

	# Check win/lose conditions
	_check_game_over_conditions()


func _update_compression_wall_visual() -> void:
	var wall_x := _boss_ai.get_compression_wall_x()

	# Update line position
	_wall_line.clear_points()
	_wall_line.add_point(Vector2(wall_x, ARENA_TOP))
	_wall_line.add_point(Vector2(wall_x, ARENA_BOTTOM))

	# Update color rect (gradient effect)
	_wall_color.position.x = wall_x - 50
	_wall_color.size.x = 50  # 50px gradient width


func _apply_wall_damage(delta: float) -> void:
	var wall_x := _boss_ai.get_compression_wall_x()

	for player in _players:
		if not player.is_alive():
			continue

		var player_x := player.global_position.x
		if player_x < wall_x:
			# Player is in danger zone
			var damage := WALL_DAMAGE_RATE * delta
			player.take_damage(int(damage))


func _update_camera() -> void:
	if _players.size() < 2:
		return

	var p1_pos: Vector2 = _players[0].global_position if _players[0].is_alive() else Vector2.ZERO
	var p2_pos: Vector2 = _players[1].global_position if _players[1].is_alive() else p1_pos

	# Camera follows midpoint between players with some offset
	var midpoint := (p1_pos + p2_pos) / 2.0
	_camera.global_position = midpoint


func _update_hp_bars() -> void:
	# Boss HP
	var boss_hp := _boss_ai.get_boss_hp()
	var boss_max := _boss_ai.get_boss_max_hp()
	_boss_hp_bar.max_value = boss_max
	_boss_hp_bar.value = boss_hp

	# Player HP
	if _players.size() >= 1:
		var p1 := _players[0]
		_p1_hp_bar.max_value = p1.get_max_health()
		_p1_hp_bar.value = p1.get_health()
		_p1_hp_label.text = "P1: %d/%d" % [p1.get_health(), p1.get_max_health()]

	if _players.size() >= 2:
		var p2 := _players[1]
		_p2_hp_bar.max_value = p2.get_max_health()
		_p2_hp_bar.value = p2.get_health()
		_p2_hp_label.text = "P2: %d/%d" % [p2.get_health(), p2.get_max_health()]


func _update_phase_label() -> void:
	var phase := _boss_ai.get_current_phase()
	_phase_label.text = "Phase %d" % phase


func _update_compression_label() -> void:
	var wall_x := _boss_ai.get_compression_wall_x()
	var speed := _boss_ai.get_compression_speed()
	_compression_label.text = "Wall: %.0fpx | Speed: %.1fpx/s" % [wall_x, speed]


func _on_boss_hp_changed(current: int, max_hp: int) -> void:
	_update_hp_bars()


func _on_boss_phase_changed(new_phase: int) -> void:
	_update_phase_label()
	# Camera shake on phase change
	_camera.add_trauma(0.9)


func _check_game_over_conditions() -> void:
	# Check if boss is defeated
	if _boss_ai.get_boss_state() == "DEFEATED":
		_game_won = true
		game_win.emit()
		print("YOU WIN! Boss defeated!")
		return

	# Check if both players are down
	var alive_count := 0
	for player in _players:
		if player.is_alive():
			alive_count += 1

	if alive_count == 0:
		_game_over = true
		game_over.emit()
		print("GAME OVER - Both players down!")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()  # ESC to quit
