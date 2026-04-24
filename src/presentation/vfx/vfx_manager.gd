# vfx_manager.gd — Autoload singleton for VFX particle system
# Implements ADR-ARCH-008: VFX System
# Manages pre-allocated CPU/GPU particle emitter pools and budget enforcement
extends Node

## Autoload singleton managing VFX particle emitters.
## 20 pre-allocated CPUParticles2D emitters + 2 GPUParticles2D emitters.
## Budget: MAX_PARTICLES=300, MAX_EMITTERS=15.

# ─── Budget Constants ─────────────────────────────────────────────────────────────
const MAX_PARTICLES: int = 300      ## Hard limit: concurrent particles
const MAX_EMITTERS: int = 15       ## Hard limit: concurrent emitters
const MAX_QUEUE_DEPTH: int = 10     ## FIFO queue depth for overflow
const POOL_SIZE: int = 20          ## CPU emitter pool size
const GPU_POOL_SIZE: int = 2       ## GPU sync emitter pool size

# ─── Color Constants (from GDD) ─────────────────────────────────────────────────
const COLOR_P1 := Color("#F5A623")   ## 晨曦橙 — P1 sync/effects
const COLOR_P2 := Color("#4ECDC4")   ## 梦境蓝 — P2 sync/effects
const COLOR_GOLD := Color("#FFD700") ## 打勾金 — combo milestone
const COLOR_WHITE := Color.WHITE    ## Default

# ─── Hit VFX Particle Parameters (from GDD Rule 2 + Story 002) ────────────────
## Explosiveness and lifetime randomness (AC-VFX-2.9)
const EXPLOSIVENESS: float = 0.8
const LIFETIME_RANDOMNESS: float = 0.3

## Combo tier multipliers (GDD Rule 7)
const TIER_MULTIPLIERS := {
	1: 1.0,
	2: 1.2,
	3: 1.5,
	4: 2.0
}

## Particle count ranges per attack type
const _PARTICLE_COUNTS := {
	"light":   { "min": 5,  "max": 8  },
	"medium":  { "min": 10, "max": 15 },
	"heavy":   { "min": 18, "max": 25 },
	"special": { "min": 30, "max": 40 }
}

## Speed ranges per attack type (px/s)
const _SPEED_RANGES := {
	"light":   { "min": 180, "max": 250 },
	"medium":  { "min": 220, "max": 300 },
	"heavy":   { "min": 150, "max": 200 },
	"special": { "min": 200, "max": 280 }
}

## Spread angles per attack type (degrees — cone half-angle)
## LIGHT/MEDIUM: 180° = full radial (360°)
## HEAVY/SPECIAL: 60° = 120° cone
const _SPREAD_ANGLES := {
	"light":   180.0,
	"medium":  180.0,
	"heavy":   60.0,
	"special": 60.0
}

## Gravity per attack type (px/s², y-component)
const _GRAVITY_VALUES := {
	"light":   400.0,
	"medium":  400.0,
	"heavy":   200.0,
	"special": 200.0
}

## Confetti bonus count at tier 4
const TIER4_CONFETTI_COUNT: int = 30

## Rescue VFX parameters (AC-VFX-5.x)
const RESCUE_PARTICLE_COUNT_MIN: int = 12
const RESCUE_PARTICLE_COUNT_MAX: int = 18
const RESCUE_SPREAD: float = 45.0
const RESCUE_SPEED_MIN: float = 120.0
const RESCUE_SPEED_MAX: float = 180.0
const RESCUE_LIFETIME_MIN: float = 0.4
const RESCUE_LIFETIME_MAX: float = 0.7
const HAND_GLOW_RADIUS: float = 40.0
const HAND_GLOW_FADE_DURATION: float = 0.5

## Boss Death VFX parameters (AC-VFX-6.x)
const BOSS_DEATH_PARTICLE_COUNT: int = 60
const BOSS_DEATH_GOLD_CONFETTI_COUNT: int = 30
const BOSS_DEATH_SPREAD: float = 180.0
const BOSS_DEATH_VELOCITY_MIN: float = 200.0
const BOSS_DEATH_VELOCITY_MAX: float = 300.0
const BOSS_DEATH_GRAVITY: Vector2 = Vector2(0, 200)  ## Slow fall for paper rain

# ─── Pool State ────────────────────────────────────────────────────────────────
var _cpu_particle_pool: Array[CPUParticles2D] = []
var _gpu_sync_pool: Array[GPUParticles2D] = []

## Currently active (emitting) CPU emitters
var _active_cpu_emitters: Array[CPUParticles2D] = []

## Currently active GPU emitters
var _active_gpu_emitters: Array[GPUParticles2D] = []

## Currently running combo escalation emitter (for tier regression cancellation)
var _active_escalation_emitter: CPUParticles2D = null

## Continuous sync burst emitters (one per player, GPU pool)
var _active_p1_sync_emitter: GPUParticles2D = null
var _active_p2_sync_emitter: GPUParticles2D = null

## FIFO emitter queue for budget overflow (MAX_QUEUE_DEPTH=10)
var _emitter_queue: Array[Dictionary] = []

# ─── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_pool()
	_connect_vfx_signals()


func _connect_vfx_signals() -> void:
	Events.combo_tier_escalated.connect(_on_combo_tier_escalated)
	Events.sync_burst_triggered.connect(_on_sync_burst_triggered)
	Events.sync_chain_active.connect(_on_sync_chain_active)
	Events.rescue_triggered.connect(_on_rescue_triggered)
	Events.boss_defeated.connect(_on_boss_defeated)


func _init_pool() -> void:
	## Pre-allocate CPU emitters
	for i in range(POOL_SIZE):
		var emitter := CPUParticles2D.new()
		emitter.emitting = false
		emitter.one_shot = true
		_cpu_particle_pool.append(emitter)

	## Pre-allocate GPU sync emitters
	for i in range(GPU_POOL_SIZE):
		var emitter := GPUParticles2D.new()
		emitter.emitting = false
		_gpu_sync_pool.append(emitter)


# ─── Pool Checkout ─────────────────────────────────────────────────────────────

## Checkout the first available CPUParticles2D emitter from the pool.
## Returns null if all emitters are active (pool exhausted).
func _checkout_cpu_emitter() -> CPUParticles2D:
	# Find first non-emitting emitter
	for emitter in _cpu_particle_pool:
		if not emitter.emitting:
			_active_cpu_emitters.append(emitter)
			return emitter
	return null  # Pool exhausted


## Checkout the first available GPUParticles2D emitter from the sync pool.
## Returns null if all GPU emitters are active.
func _get_gpu_sync_emitter() -> GPUParticles2D:
	for emitter in _gpu_sync_pool:
		if not emitter.emitting:
			_active_gpu_emitters.append(emitter)
			return emitter
	return null


## Called when an emitter finishes — returns it to the pool.
func _on_emitter_finished(emitter: CPUParticles2D) -> void:
	emitter.emitting = false
	_active_cpu_emitters.erase(emitter)


func _on_gpu_emitter_finished(emitter: GPUParticles2D) -> void:
	emitter.emitting = false
	_active_gpu_emitters.erase(emitter)


# ─── Budget Enforcement ─────────────────────────────────────────────────────────

## Returns true if emission is allowed under budget constraints.
func _can_emit(particle_count: int) -> bool:
	var current_particles := get_active_particle_count()
	var current_emitters := get_active_emitter_count()
	return (current_particles + particle_count <= MAX_PARTICLES) and (current_emitters < MAX_EMITTERS)


## Returns the current total active particle count across all emitters.
func get_active_particle_count() -> int:
	var total := 0
	for emitter in _active_cpu_emitters:
		if is_instance_valid(emitter):
			total += emitter.get_particle_count()
	for emitter in _active_gpu_emitters:
		if is_instance_valid(emitter):
			total += emitter.get_particle_count()
	return total


## Returns the current number of active emitters.
func get_active_emitter_count() -> int:
	return _active_cpu_emitters.size() + _active_gpu_emitters.size()


# ─── FIFO Queue (particle-vfx-007) ───────────────────────────────────────────────

## Queue an emitter event when budget is full (FIFO, max depth 10).
## If queue is full, oldest entry is silently dropped.
func _queue_emitter(type: String, params: Dictionary) -> void:
	if _emitter_queue.size() >= MAX_QUEUE_DEPTH:
		_emitter_queue.pop_front()  # FIFO eviction — drop oldest
	_emitter_queue.append({"type": type, "params": params})


## Drain the queue, processing entries in FIFO order while budget allows.
## Called from _on_emitter_finished() when an emitter completes.
func _drain_queue() -> void:
	while _emitter_queue.size() > 0:
		# Check if we have budget for estimated ~50 particles
		if not _can_emit(50):
			break
		var entry: Dictionary = _emitter_queue.pop_front()
		_process_queued(entry)


## Process a single queued entry, dispatching to the correct emit function.
func _process_queued(entry: Dictionary) -> void:
	var etype: String = entry.get("type", "")
	var params: Dictionary = entry.get("params", {})

	match etype:
		"hit_vfx":
			emit_hit(
				params.get("position", Vector2.ZERO),
				params.get("attack_type", "light"),
				params.get("direction", Vector2.RIGHT),
				params.get("player_color", Color.WHITE),
				params.get("combo_tier", 1)
			)
		"combo_escalation_vfx":
			emit_combo_escalation(
				params.get("tier", 1),
				params.get("player_color", Color.WHITE),
				params.get("position", Vector2.ZERO)
			)
		"rescue_vfx":
			emit_rescue(
				params.get("position", Vector2.ZERO),
				params.get("rescuer_color", Color.WHITE)
			)
		"sync_burst_vfx":
			emit_sync_burst(params.get("position", Vector2.ZERO))
		"boss_death_vfx":
			emit_boss_death(params.get("position", Vector2.ZERO))


# ─── Convenience: Get Pool Status ─────────────────────────────────────────────

## Returns how many CPU emitters are currently available (not emitting).
func get_available_cpu_count() -> int:
	return _cpu_particle_pool.size() - _active_cpu_emitters.size()


## Returns how many GPU emitters are currently available.
func get_available_gpu_count() -> int:
	return _gpu_sync_pool.size() - _active_gpu_emitters.size()


# ─── Hit VFX Emitter (particle-vfx-002) ─────────────────────────────────────────

## Emit a hit VFX burst at position.
## Called by CombatSystem directly (not via Events bus per ADR-ARCH-008).
## attack_type: "light" | "medium" | "heavy" | "special"
## direction: normalized direction vector for cone emission
## player_color: COLOR_P1 or COLOR_P2
## combo_tier: current combo tier for multiplier (1-4)
func emit_hit(position: Vector2, attack_type: String, direction: Vector2, player_color: Color, combo_tier: int = 1) -> void:
	var base_count: int = _get_particle_count(attack_type)
	var scaled := _apply_combo_multiplier(base_count, combo_tier, 1)  # player 1

	# Budget check — queue if full
	if not _can_emit(scaled.count):
		_queue_emitter("hit_vfx", {
			"position": position,
			"attack_type": attack_type,
			"direction": direction,
			"player_color": player_color,
			"combo_tier": combo_tier
		})
		return

	var emitter := _checkout_cpu_emitter()
	if emitter == null:
		return

	_configure_hit_emitter(emitter, attack_type, position, direction, player_color, scaled.count)
	emitter.restart()
	emitter.connect("finished", _on_emitter_finished.bind(emitter, scaled.count), CONNECT_ONE_SHOT)


## Returns random particle count for attack type.
func _get_particle_count(attack_type: String) -> int:
	var range_dict: Dictionary = _PARTICLE_COUNTS.get(attack_type.to_lower(), _PARTICLE_COUNTS["light"])
	return randi() % (range_dict["max"] - range_dict["min"] + 1) + range_dict["min"]


## Returns speed range for attack type.
func _get_speed(attack_type: String) -> Dictionary:
	return _SPEED_RANGES.get(attack_type.to_lower(), _SPEED_RANGES["light"])


## Returns spread angle in degrees for attack type.
func _get_spread(attack_type: String) -> float:
	return _SPREAD_ANGLES.get(attack_type.to_lower(), 180.0)


## Returns gravity Vector2 for attack type.
func _get_gravity(attack_type: String) -> Vector2:
	var val: float = _GRAVITY_VALUES.get(attack_type.to_lower(), 400.0)
	return Vector2(0, val)


## Composite result of combo multiplier application.
class ComboScaledResult:
	var count: int
	var gold_sparks: int
	var confetti: int


## Apply combo tier multiplier to base particle count.
## Returns ComboScaledResult with final count, gold sparks, and confetti.
func _apply_combo_multiplier(base_count: int, tier: int, player_id: int) -> ComboScaledResult:
	var result := ComboScaledResult.new()
	result.gold_sparks = 0
	result.confetti = 0

	var multiplier: float = TIER_MULTIPLIERS.get(tier, 1.0)
	result.count = int(base_count * multiplier)

	if tier >= 3:
		result.gold_sparks = _calc_gold_sparks(base_count)
	if tier >= 4:
		result.confetti = TIER4_CONFETTI_COUNT
		result.count += TIER4_CONFETTI_COUNT

	return result


## Calculate gold spark count: floor(base * 0.10)
func _calc_gold_sparks(base_count: int) -> int:
	return int(base_count * 0.10)


## Configure a CPUParticles2D emitter for a hit VFX burst.
func _configure_hit_emitter(emitter: CPUParticles2D, attack_type: String, position: Vector2, direction: Vector2, player_color: Color, count: int) -> void:
	emitter.position = position
	emitter.emitting = true
	emitter.one_shot = true

	# Direction and spread
	var spread_rad: float = deg_to_rad(_get_spread(attack_type))
	emitter.direction = direction.normalized()
	emitter.spread = spread_rad

	# Speed
	var speed_range: Dictionary = _get_speed(attack_type)
	emitter.initial_velocity_min = speed_range["min"]
	emitter.initial_velocity_max = speed_range["max"]

	# Gravity
	emitter.gravity = _get_gravity(attack_type)

	# Particle parameters (AC-VFX-2.9)
	emitter.explosiveness = EXPLOSIVENESS
	emitter.lifetime_randomness = LIFETIME_RANDOMNESS

	# Color
	emitter.color = player_color
	emitter.hue_variation_max = 0.1

	# Lifetime
	emitter.lifetime = 0.5

	# Emission shape: radial burst
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 5.0

	# Amount
	emitter.amount = count


# ─── Combo Escalation VFX Emitter (particle-vfx-003) ───────────────────────────

## Emit combo escalation VFX burst on tier transition.
## Driven by Events.combo_tier_escalated.
## tier: new combo tier (2, 3, or 4)
## player_color: COLOR_P1 or COLOR_P2
## position: world position for the burst
func emit_combo_escalation(tier: int, player_color: Color, position: Vector2) -> void:
	var count := _get_combo_escalation_count(tier)

	if not _can_emit(count):
		_queue_emitter("combo_escalation_vfx", {
			"tier": tier,
			"player_color": player_color,
			"position": position
		})
		return

	# Cancel any running escalation emitter (tier regression handling)
	_cancel_escalation_emitter()

	var emitter := _checkout_cpu_emitter()
	if emitter == null:
		return

	_configure_combo_emitter(emitter, tier, player_color, position, count)
	emitter.restart()
	_active_escalation_emitter = emitter
	emitter.connect("finished", _on_escalation_finished.bind(emitter), CONNECT_ONE_SHOT)


## Returns total particle count for a given tier.
func _get_combo_escalation_count(tier: int) -> int:
	return tier * 15


## Returns burst particle count for a tier transition.
## Per spec: 1→2: 8, 2→3: 15, 3→4: 25
func _get_escalation_burst_count(from_tier: int, to_tier: int) -> int:
	match to_tier:
		2: return 8
		3: return 15
		4: return 25
	return 0


## Returns true if tier >= 3 should use gold tint.
func _uses_gold_tint(tier: int) -> bool:
	return tier >= 3


## Returns tier 3 color brightness (+40%).
func _apply_tier3_brightness(player_color: Color) -> Color:
	return player_color * 1.4


## Returns the gold color for tier 4.
func _get_tier4_color() -> Color:
	return COLOR_GOLD


## Configure a CPUParticles2D emitter for combo escalation burst.
func _configure_combo_emitter(emitter: CPUParticles2D, tier: int, player_color: Color, position: Vector2, count: int) -> void:
	emitter.position = position
	emitter.emitting = true
	emitter.one_shot = true

	# Amount
	emitter.amount = count

	# Direction: upward for escalating tiers
	emitter.direction = Vector2(0, -1)  # Rising arc
	emitter.spread = 90.0  # Wide spread for upward burst

	# Speed
	emitter.initial_velocity_min = 200
	emitter.initial_velocity_max = 400

	# Gravity: light upward drift then fall
	emitter.gravity = Vector2(0, -100)

	# Particle parameters
	emitter.explosiveness = 0.7
	emitter.lifetime_randomness = LIFETIME_RANDOMNESS
	emitter.lifetime = 0.8

	# Color
	if tier >= 4:
		emitter.color = COLOR_GOLD
	elif tier >= 3:
		emitter.color = _apply_tier3_brightness(player_color)
	else:
		emitter.color = player_color

	# Emission shape: point burst
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 3.0

	# Hue variation for visual interest
	emitter.hue_variation_max = 0.15


## Cancel any running escalation emitter (for tier regression).
func _cancel_escalation_emitter() -> void:
	if _active_escalation_emitter != null and is_instance_valid(_active_escalation_emitter):
		_active_escalation_emitter.emitting = false
		_active_escalation_emitter = null


## Called when an escalation emitter finishes.
func _on_escalation_finished(emitter: CPUParticles2D) -> void:
	emitter.emitting = false
	_active_cpu_emitters.erase(emitter)
	if _active_escalation_emitter == emitter:
		_active_escalation_emitter = null


## Signal handler for Events.combo_tier_escalated.
func _on_combo_tier_escalated(tier: int, player_color: Color) -> void:
	emit_combo_escalation(tier, player_color, Vector2.ZERO)  # Position from GameState


# ─── Sync Burst VFX Emitter (particle-vfx-004) ─────────────────────────────────

## Sync burst: activates continuous GPU emitter at position.
## Called by Events.sync_burst_triggered.
func emit_sync_burst(position: Vector2) -> void:
	# Sync burst uses 2 GPU emitters = 100 particles
	var count := SYNC_PARTICLE_COUNT * 2

	if not _can_emit(count):
		_queue_emitter("sync_burst_vfx", {
			"position": position
		})
		return

	# Get P1 emitter (clockwise) and P2 emitter (counterclockwise)
	var p1_emitter := _get_gpu_sync_emitter()
	var p2_emitter := _get_gpu_sync_emitter()

	if p1_emitter != null:
		_configure_p1_sync_emitter(p1_emitter, position)
		p1_emitter.restart()
		_active_p1_sync_emitter = p1_emitter

	if p2_emitter != null:
		_configure_p2_sync_emitter(p2_emitter, position)
		p2_emitter.restart()
		_active_p2_sync_emitter = p2_emitter


## Signal handler for Events.sync_burst_triggered.
func _on_sync_burst_triggered(position: Vector2) -> void:
	emit_sync_burst(position)


## Signal handler for Events.sync_chain_active.
## chain_length > 0: activate/keep continuous emitters
## chain_length == 0: deactivate continuous emitters
func _on_sync_chain_active(chain_length: int) -> void:
	if chain_length > 0:
		# Sync chain active — ensure continuous emitters are running
		pass  # Already handled by emit_sync_burst
	else:
		# Chain broken — deactivate continuous emitters
		_deactivate_sync_continuous()


## Deactivate continuous sync emitters.
func _deactivate_sync_continuous() -> void:
	if _active_p1_sync_emitter != null and is_instance_valid(_active_p1_sync_emitter):
		_active_p1_sync_emitter.emitting = false
		_active_p1_sync_emitter = null
	if _active_p2_sync_emitter != null and is_instance_valid(_active_p2_sync_emitter):
		_active_p2_sync_emitter.emitting = false
		_active_p2_sync_emitter = null


## Configure P1 continuous sync emitter (clockwise spiral, orange).
func _configure_p1_sync_emitter(emitter: GPUParticles2D, position: Vector2) -> void:
	emitter.position = position
	emitter.emitting = true

	# Continuous emission
	emitter.one_shot = false
	emitter.amount = 50
	emitter.lifetime = 1.2

	# Additive blend for orange+blue=white glow
	emitter.blend_mode = GPUParticles2D.BR_MODE_ADD

	# Color: orange
	emitter.color = COLOR_P1

	# Direction: upward
	emitter.direction = Vector2(0, -1)
	emitter.spread = 30.0
	emitter.initial_velocity_min = 80
	emitter.initial_velocity_max = 120

	# Helical motion — clockwise (positive orbital velocity)
	emitter.orbital_velocity = 40.0
	emitter.orbital_velocity_local = true

	# Gravity: light
	emitter.gravity = Vector2(0, 50)


## Configure P2 continuous sync emitter (counterclockwise spiral, teal).
func _configure_p2_sync_emitter(emitter: GPUParticles2D, position: Vector2) -> void:
	emitter.position = position
	emitter.emitting = true

	# Continuous emission
	emitter.one_shot = false
	emitter.amount = 50
	emitter.lifetime = 1.2

	# Additive blend for orange+blue=white glow
	emitter.blend_mode = GPUParticles2D.BR_MODE_ADD

	# Color: teal
	emitter.color = COLOR_P2

	# Direction: upward
	emitter.direction = Vector2(0, -1)
	emitter.spread = 30.0
	emitter.initial_velocity_min = 80
	emitter.initial_velocity_max = 120

	# Helical motion — counterclockwise (negative orbital velocity)
	emitter.orbital_velocity = -40.0
	emitter.orbital_velocity_local = true

	# Gravity: light
	emitter.gravity = Vector2(0, 50)


## Configure sync burst one-shot (explosive burst on 3rd consecutive sync hit).
## Uses CPU pool for one-shot burst.
func _configure_sync_oneshot(emitter: CPUParticles2D, position: Vector2) -> void:
	emitter.position = position
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = 50
	emitter.lifetime = 1.2

	# Additive blend
	emitter.blend_mode = CPUParticles2D.BR_MODE_ADD

	# Color: mixed orange + blue + gold
	emitter.color = COLOR_GOLD

	# Radial burst
	emitter.direction = Vector2(0, 1)  # Downward for impact
	emitter.spread = 180.0
	emitter.initial_velocity_min = 150
	emitter.initial_velocity_max = 250
	emitter.gravity = Vector2(0, 200)

	emitter.explosiveness = 0.9
	emitter.lifetime_randomness = 0.3

	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 10.0


# ─── Rescue VFX Emitter (particle-vfx-005) ─────────────────────────────────────

## Emit rescue VFX burst at position.
## Driven by Events.rescue_triggered.
## rescuer_color: Color — the RESCUER's color (not the rescued player's)
func emit_rescue(position: Vector2, rescuer_color: Color) -> void:
	var count := _get_rescue_particle_count()

	if not _can_emit(count):
		_queue_emitter("rescue_vfx", {
			"position": position,
			"rescuer_color": rescuer_color
		})
		return

	var emitter := _checkout_cpu_emitter()
	if emitter == null:
		return

	_configure_rescue_emitter(emitter, rescuer_color, position)
	emitter.restart()
	emitter.connect("finished", _on_emitter_finished.bind(emitter, count), CONNECT_ONE_SHOT)

	# Also spawn hand glow
	_spawn_hand_glow(position, rescuer_color)


## Returns random rescue particle count (12-18).
func _get_rescue_particle_count() -> int:
	return randi() % (RESCUE_PARTICLE_COUNT_MAX - RESCUE_PARTICLE_COUNT_MIN + 1) + RESCUE_PARTICLE_COUNT_MIN


## Returns rescue direction (upward in Godot 2D).
func _get_rescue_direction() -> Vector2:
	return Vector2(0, -1)


## Returns rescue spread angle (45 degrees).
func _get_rescue_spread() -> float:
	return RESCUE_SPREAD


## Returns rescue speed range.
func _get_rescue_speed() -> Dictionary:
	return { "min": RESCUE_SPEED_MIN, "max": RESCUE_SPEED_MAX }


## Returns rescue lifetime range (0.4-0.7s).
func _get_rescue_lifetime() -> float:
	return randf_range(RESCUE_LIFETIME_MIN, RESCUE_LIFETIME_MAX)


## Configure a CPUParticles2D emitter for rescue VFX.
func _configure_rescue_emitter(emitter: CPUParticles2D, rescuer_color: Color, position: Vector2) -> void:
	emitter.position = position
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = _get_rescue_particle_count()

	# Color = rescuer's color (NOT rescued player's)
	emitter.color = rescuer_color

	# Upward motion, 45° cone
	emitter.direction = _get_rescue_direction()
	emitter.spread = _get_rescue_spread()

	# Speed
	emitter.initial_velocity_min = RESCUE_SPEED_MIN
	emitter.initial_velocity_max = RESCUE_SPEED_MAX

	# Lifetime
	emitter.lifetime = _get_rescue_lifetime()

	# Decelerating (negative acceleration)
	emitter.gravity = Vector2(0, 300)

	# Particle parameters
	emitter.explosiveness = 0.5
	emitter.lifetime_randomness = 0.2

	# Small paper scraps via small particle size + hue variation
	emitter.particle_flag_align_y = true
	emitter.hue_variation_max = 0.1

	# Emission shape: point
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 2.0


## Spawn a hand glow sprite at position (circular glow).
func _spawn_hand_glow(position: Vector2, rescuer_color: Color) -> void:
	var glow := Sprite2D.new()
	glow.modulate = rescuer_color
	glow.modulate.a = 0.8
	glow.position = position

	# Create a simple circular glow using a TextureRect with a circle texture
	# Since we can't create textures at runtime easily, use a ColorRect as placeholder
	# In production this would be replaced with a proper glow sprite
	var tex := ImageTexture.create_from_image(_create_glow_image())
	glow.texture = tex
	glow.scale = Vector2(HAND_GLOW_RADIUS * 2, HAND_GLOW_RADIUS * 2)

	add_child(glow)

	# Fade out over HAND_GLOW_FADE_DURATION
	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", 0.0, HAND_GLOW_FADE_DURATION)
	tween.tween_callback(glow.queue_free)


## Create a radial gradient glow image for hand glow sprite.
func _create_glow_image() -> Image:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var center := Vector2i(size / 2, size / 2)
	var radius := size / 2

	for x in range(size):
		for y in range(size):
			var dist := Vector2i(x, y).distance_to(center)
			if dist < radius:
				var alpha := 1.0 - (float(dist) / float(radius))
				img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return img


## Signal handler for Events.rescue_triggered.
func _on_rescue_triggered(rescuer_id: int, downed_id: int) -> void:
	# Position would come from GameState — use a placeholder for now
	emit_rescue(Vector2.ZERO, COLOR_P1)  # Color from rescuer


# ─── Boss Death VFX Emitter (particle-vfx-006) ─────────────────────────────────

## Emit boss death VFX explosion at position.
## Driven by Events.boss_defeated.
## Force-cancels all active hit emitters for visual priority.
func emit_boss_death(position: Vector2) -> void:
	# Force-cancel all active hit emitters (visual priority)
	_force_cancel_all_hit_emitters()

	# Check particle budget (60 + 30 = 90)
	var total_count := BOSS_DEATH_PARTICLE_COUNT + BOSS_DEATH_GOLD_CONFETTI_COUNT
	if not _can_emit(total_count):
		_queue_emitter("boss_death_vfx", {
			"position": position
		})
		return

	var emitter := _checkout_cpu_emitter()
	if emitter == null:
		return

	_configure_boss_death_emitter(emitter, position)
	emitter.restart()
	emitter.connect("finished", _on_emitter_finished.bind(emitter, BOSS_DEATH_PARTICLE_COUNT), CONNECT_ONE_SHOT)

	# Gold confetti burst (additive)
	var gold_emitter := _checkout_cpu_emitter()
	if gold_emitter != null:
		_configure_gold_confetti_emitter(gold_emitter, position)
		gold_emitter.restart()
		gold_emitter.connect("finished", _on_emitter_finished.bind(gold_emitter, BOSS_DEATH_GOLD_CONFETTI_COUNT), CONNECT_ONE_SHOT)


## Force-cancel all active CPU hit emitters.
## Called when boss dies — boss death has visual priority.
func _force_cancel_all_hit_emitters() -> void:
	for emitter in _active_cpu_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = false
	_active_cpu_emitters.clear()


## Returns boss death particle count (60).
func _get_boss_death_particle_count() -> int:
	return BOSS_DEATH_PARTICLE_COUNT


## Returns boss death direction (upward).
func _get_boss_death_direction() -> Vector2:
	return Vector2(0, -1)


## Returns boss death spread (180° full radial).
func _get_boss_death_spread() -> float:
	return BOSS_DEATH_SPREAD


## Returns boss death velocity range.
func _get_boss_death_velocity() -> Dictionary:
	return { "min": BOSS_DEATH_VELOCITY_MIN, "max": BOSS_DEATH_VELOCITY_MAX }


## Returns boss death gravity for paper rain.
func _get_boss_death_gravity() -> Vector2:
	return BOSS_DEATH_GRAVITY


## Configure a CPUParticles2D emitter for boss death explosion.
func _configure_boss_death_emitter(emitter: CPUParticles2D, position: Vector2) -> void:
	emitter.position = position
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = BOSS_DEATH_PARTICLE_COUNT

	# Color: starts white, fades to gold
	emitter.color = Color.WHITE
	emitter.hue_variation_max = 0.1

	# Explosive upward burst
	emitter.direction = Vector2(0, -1)
	emitter.spread = BOSS_DEATH_SPREAD
	emitter.initial_velocity_min = BOSS_DEATH_VELOCITY_MIN
	emitter.initial_velocity_max = BOSS_DEATH_VELOCITY_MAX

	# Slow fall (paper rain)
	emitter.gravity = BOSS_DEATH_GRAVITY

	# Lifetime
	emitter.lifetime = 1.5
	emitter.lifetime_randomness = 0.4

	# Particle parameters
	emitter.explosiveness = 0.7
	emitter.particle_flag_align_y = true

	# Emission shape: sphere burst
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 10.0


## Configure gold confetti burst emitter (additive blend).
func _configure_gold_confetti_emitter(emitter: CPUParticles2D, position: Vector2) -> void:
	emitter.position = position
	emitter.emitting = true
	emitter.one_shot = true
	emitter.amount = BOSS_DEATH_GOLD_CONFETTI_COUNT

	# Color: gold
	emitter.color = COLOR_GOLD
	emitter.hue_variation_max = 0.05

	# Full radial burst
	emitter.direction = Vector2(0, -1)
	emitter.spread = BOSS_DEATH_SPREAD
	emitter.initial_velocity_min = 150.0
	emitter.initial_velocity_max = 250.0

	# Slow float down
	emitter.gravity = Vector2(0, 100)

	# Lifetime
	emitter.lifetime = 2.0
	emitter.lifetime_randomness = 0.3

	# Additive blend for gold glow
	emitter.blend_mode = CPUParticles2D.BR_MODE_ADD

	emitter.explosiveness = 0.6

	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 20.0


## Signal handler for Events.boss_defeated.
func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
	emit_boss_death(position)

