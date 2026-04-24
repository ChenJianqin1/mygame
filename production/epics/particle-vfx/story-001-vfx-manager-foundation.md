# Story 001: VFXManager Foundation and Pool Initialization

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-23
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-003`, `TR-vfx-004`, `TR-vfx-006` — CPUParticles2D for burst emitters; 20 pre-allocated emitter pool; 300 particle / 15 emitter hard limit

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: CPUParticles2D for burst emitters (hit/combo/rescue/boss_death); GPUParticles2D for continuous flow (sync_burst); 20 pre-allocated emitters (18 CPU + 2 GPU); FIFO queue (MAX_QUEUE_DEPTH=10); 300 particle / 15 emitter limits enforced in `_can_emit()`

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CPUParticles2D / GPUParticles2D API stable in Godot 4.4-4.6

---

## Acceptance Criteria

From GDD AC-14, AC-15, AC-10:

- [ ] **AC-VFX-1.1**: VFXManager autoload initializes in `_ready()` with 20 CPUParticles2D emitters pre-allocated in `_cpu_particle_pool`
- [ ] **AC-VFX-1.2**: VFXManager autoload initializes 2 GPUParticles2D emitters in `_gpu_sync_pool`
- [ ] **AC-VFX-1.3**: All pooled emitters have `emitting = false` and `one_shot = true` (CPU) on checkout
- [ ] **AC-VFX-1.4**: `_checkout_cpu_emitter()` returns first available non-emitting CPUParticles2D from pool
- [ ] **AC-VFX-1.5**: `_checkout_cpu_emitter()` returns `null` when pool is exhausted (all emitting)
- [ ] **AC-VFX-1.6**: `_get_gpu_sync_emitter()` returns first available non-emitting GPUParticles2D
- [ ] **AC-VFX-1.7**: Constants `MAX_PARTICLES = 300`, `MAX_EMITTERS = 15`, `MAX_QUEUE_DEPTH = 10`, `POOL_SIZE = 20` are defined
- [ ] **AC-VFX-1.8**: `_on_emitter_finished()` returns emitter to pool and updates active counts
- [ ] **AC-VFX-1.9**: `get_active_particle_count()` and `get_active_emitter_count()` return correct running totals

---

## Implementation Notes

1. **Autoload Setup**:
   - Create `VFXManager.gd` as autoload singleton
   - File location: `src/presentation/vfx/vfx_manager.gd`

2. **Pool Initialization (`_init_pool`)**:
   ```gdscript
   const POOL_SIZE := 20  # CPU emitters
   const GPU_POOL_SIZE := 2  # sync burst emitters

   var _cpu_particle_pool: Array[CPUParticles2D] = []
   var _gpu_sync_pool: Array[GPUParticles2D] = []

   func _init_pool() -> void:
       for i in range(POOL_SIZE):
           var emitter := CPUParticles2D.new()
           emitter.emitting = false
           emitter.one_shot = true
           _cpu_particle_pool.append(emitter)
       for i in range(GPU_POOL_SIZE):
           var emitter := GPUParticles2D.new()
           emitter.emitting = false
           _gpu_sync_pool.append(emitter)
   ```

3. **Color Constants**:
   ```gdscript
   const COLOR_P1 := Color("#F5A623")   # 晨曦橙
   const COLOR_P2 := Color("#4ECDC4")   # 梦境蓝
   const COLOR_GOLD := Color("#FFD700") # 打勾金
   ```

4. **Signal Connections** (to be implemented as stories 2-6 are completed):
   - Events.combo_tier_escalated.connect(_on_combo_tier_escalated)
   - Events.sync_burst_triggered.connect(_on_sync_burst_triggered)
   - Events.rescue_triggered.connect(_on_rescue_triggered)
   - Events.boss_defeated.connect(_on_boss_defeated)

5. **Pool Checkout Pattern**:
   - All emit functions follow: check `_can_emit()` → checkout emitter → configure → `restart()` → connect `finished` signal

---

## Out of Scope

- Individual emitter configuration (Stories 002-006)
- FIFO queue implementation (Story 007)
- Budget enforcement tests (Story 008)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_pool_initializes_20_cpu_emitters**: Given VFXManager._ready(), when pool is initialized → then _cpu_particle_pool.size() == 20
- **test_pool_initializes_2_gpu_emitters**: Given VFXManager._ready(), when pool is initialized → then _gpu_sync_pool.size() == 2
- **test_checkout_returns_available_emitter**: Given pool with 1 emitting and 19 idle emitters, when _checkout_cpu_emitter() called → then returns an idle emitter
- **test_checkout_returns_null_when_exhausted**: Given pool with all 20 emitters emitting, when _checkout_cpu_emitter() called → then returns null
- **test_gpu_checkout_returns_available_emitter**: Given GPU pool with 1 emitting and 1 idle, when _get_gpu_sync_emitter() called → then returns idle emitter
- **test_active_counts_start_at_zero**: Given fresh VFXManager, when get_active_particle_count() and get_active_emitter_count() called → then both return 0
- **test_constants_are_correct**: When constants read → then MAX_PARTICLES=300, MAX_EMITTERS=15, MAX_QUEUE_DEPTH=10, POOL_SIZE=20

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/vfx/vfx_manager_pool_test.gd` — must exist and pass

---

## Dependencies

- Depends on: ADR-ARCH-001 (Events Autoload) for signal bus structure
- Unlocks: Stories 002-006 (individual emitter implementations), Story 007 (queue)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
