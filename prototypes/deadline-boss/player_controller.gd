# player_controller.gd — Basic 2D player controller for Deadline Boss prototype
extends CharacterBody2D

## Player movement and combat for prototype testing

signal player_damaged(player_id: int, damage: int)
signal player_attack_started(player_id: int, attack_type: String)

# Movement
const MOVE_SPEED: float = 300.0
const JUMP_FORCE: float = -500.0
const GRAVITY: float = 1200.0

# Combat
const LIGHT_ATTACK_DAMAGE: int = 10
const MEDIUM_ATTACK_DAMAGE: int = 20
const HEAVY_ATTACK_DAMAGE: int = 35

@export var player_id: int = 1

var _health: int = 100
var _max_health: int = 100
var _is_attacking: bool = false
var _attack_cooldown: float = 0.0
var _combo_count: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	add_to_group("players")
	_hitbox.monitoring = false


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Handle movement
	var input_dir := Vector2.ZERO
	if player_id == 1:
		input_dir.x = Input.get_axis("p1_left", "p1_right")
		if Input.is_action_just_pressed("p1_jump") and is_on_floor():
			velocity.y = JUMP_FORCE
		if Input.is_action_just_pressed("p1_attack") and not _is_attacking:
			_perform_light_attack()
	else:
		input_dir.x = Input.get_axis("p2_left", "p2_right")
		if Input.is_action_just_pressed("p2_jump") and is_on_floor():
			velocity.y = JUMP_FORCE
		if Input.is_action_just_pressed("p2_attack") and not _is_attacking:
			_perform_light_attack()

	velocity.x = input_dir.x * MOVE_SPEED
	move_and_slide()

	# Update cooldowns
	if _attack_cooldown > 0:
		_attack_cooldown -= delta
	if _is_attacking and _attack_cooldown <= 0:
		_is_attacking = false

	# Flip sprite based on direction
	if input_dir.x != 0:
		_sprite.flip_h = input_dir.x < 0


func _perform_light_attack() -> void:
	_is_attacking = true
	_attack_cooldown = 0.3  # 300ms attack duration
	_hitbox.monitoring = true
	player_attack_started.emit(player_id, "light")

	# Deal damage to boss if in range
	var boss_node := get_tree().get_first_node_in_group("boss")
	if boss_node and is_instance_valid(boss_node):
		var dist := global_position.distance_to(boss_node.global_position)
		if dist < 150:  # Attack range
			BossAIManager.apply_damage_to_boss(LIGHT_ATTACK_DAMAGE)

	# Reset hitbox after short delay
	await get_tree().create_timer(0.15).timeout
	_hitbox.monitoring = false


func take_damage(damage: int) -> void:
	if _health <= 0:
		return  # Already down

	_health = maxi(0, _health - damage)
	player_damaged.emit(player_id, damage)

	# Visual feedback - flash red
	_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	_sprite.modulate = Color.WHITE

	if _health <= 0:
		_die()


func _die() -> void:
	# Play death animation or effects
	_sprite.modulate = Color(0.3, 0.3, 0.3)  # Gray out
	set_physics_process(false)


func get_health() -> int:
	return _health


func get_max_health() -> int:
	return _max_health


func is_alive() -> bool:
	return _health > 0
