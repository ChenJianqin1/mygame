# damage_number_pool.gd — Object pool for damage numbers
# Implements ui-007: Damage Number Popup System
# Manages up to MAX_CONCURRENT_NUMBERS damage numbers with FIFO recycling
class_name DamageNumberPool
extends Node2D

## Tuning knobs (from story ui-007)
const MAX_CONCURRENT_NUMBERS: int = 20

## Pool storage
var _pool: Array[DamageNumber] = []
var _active_count: int = 0

## For FIFO recycling
var _spawn_order: Array[int] = []  # Indices into _pool in spawn order

# ─── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_initialize_pool()


func _initialize_pool() -> void:
	for i in range(MAX_CONCURRENT_NUMBERS):
		var number := _create_damage_number()
		_pool.append(number)
		_spawn_order.append(i)


func _create_damage_number() -> DamageNumber:
	var number := DamageNumber.new()
	number.visible = false
	add_child(number)
	return number


# ─── Public API ────────────────────────────────────────────────────────────────

## Spawn a damage number at the given position.
## If pool is full, recycles the oldest number (FIFO).
func spawn(damage: int, damage_type: int, position: Vector2) -> void:
	var idx: int = _get_recyclable_index()
	var number: DamageNumber = _pool[idx]

	# Update spawn order (move to end = most recently used)
	_spawn_order.erase(idx)
	_spawn_order.append(idx)

	number.initialize(damage, damage_type, position)
	number.visible = true
	_active_count += 1


## Spawn normal damage number.
func spawn_normal(damage: int, position: Vector2) -> void:
	spawn(damage, DamageNumber.DamageType.NORMAL, position)


## Spawn critical damage number.
func spawn_crit(damage: int, position: Vector2) -> void:
	spawn(damage, DamageNumber.DamageType.CRIT, position)


## Spawn boss damage number.
func spawn_boss(damage: int, position: Vector2) -> void:
	spawn(damage, DamageNumber.DamageType.BOSS, position)


## Spawn heal number.
func spawn_heal(amount: int, position: Vector2) -> void:
	spawn(amount, DamageNumber.DamageType.HEAL, position)


## Clear all active damage numbers.
func clear_all() -> void:
	for number in _pool:
		number._deactivate()
		number.visible = false
	_active_count = 0
	_spawn_order.clear()


# ─── Internal ──────────────────────────────────────────────────────────────────

func _get_recyclable_index() -> int:
	# If not full, find first inactive
	for i in range(MAX_CONCURRENT_NUMBERS):
		if not _pool[i].is_active():
			return i

	# Pool full — recycle oldest (FIFO)
	var oldest_idx: int = _spawn_order[0] if _spawn_order.size() > 0 else 0
	_pool[oldest_idx]._deactivate()
	_spawn_order.erase(oldest_idx)
	_spawn_order.append(oldest_idx)
	return oldest_idx


# ─── Query ─────────────────────────────────────────────────────────────────────

func get_active_count() -> int:
	return _active_count


func get_max_count() -> int:
	return MAX_CONCURRENT_NUMBERS
