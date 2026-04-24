# Story 004: sync_burst_vfx Emitter (GPUParticles2D)

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-23
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-001`, `TR-vfx-003` — sync_burst_vfx emitter type; GPUParticles2D for continuous flow

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: sync_burst_vfx driven by Events.sync_burst_triggered; GPUParticles2D for continuous intertwined helical stream; additive blend (BR_MODE_ADD); 2 pre-allocated GPU emitters in pool

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: GPUParticles2D.orbital_velocity supported in Godot 4.6 for helical motion; BR_MODE_ADD for additive blend

---

## Acceptance Criteria

From GDD AC-05, AC-06, AC-07, AC-16:

- [ ] **AC-VFX-4.1**: `emit_sync_burst(position)` activates GPUParticles2D continuous emitter at `position`
- [ ] **AC-VFX-4.2**: Continuous mode: P1 (orange #F5A623) + P2 (blue #4ECDC4) particles emitted simultaneously
- [ ] **AC-VFX-4.3**: P1 particles spiral clockwise, P2 particles spiral counterclockwise (helical motion)
- [ ] **AC-VFX-4.4**: Helical radius 30-50px, pitch 40px/revolution achieved via `orbital_velocity`
- [ ] **AC-VFX-4.5**: Blend mode: `BR_MODE_ADD` (additive) — orange+blue overlap produces white-yellow glow
- [ ] **AC-VFX-4.6**: `_on_sync_burst_triggered(position)` connected to Events.sync_burst_triggered
- [ ] **AC-VFX-4.7**: When sync_chain_length drops to 0: continuous emitter immediately deactivated
- [ ] **AC-VFX-4.8**: Sync burst one-shot (3rd consecutive sync hit): 50 particles (orange+blue+gold), lifetime 1.2s, explosive outward
- [ ] **AC-VFX-4.9**: Continuous emitter uses `_gpu_sync_pool` (2 pre-allocated GPUParticles2D)
- [ ] **AC-VFX-4.10**: `get_active_emitter_count()` increments when sync_burst active

---

## Implementation Notes

1. **GPU Pool Usage**:
   - sync_burst uses `_gpu_sync_pool` (2 instances), NOT `_cpu_particle_pool`
   - `GPUParticles2D` vs `CPUParticles2D` — different pool, different configuration

2. **Continuous Mode Configuration**:
   ```gdscript
   func _configure_sync_emitter_continuous(emitter: GPUParticles2D, position: Vector2) -> void:
       emitter.position = position
       emitter.amount = 50
       emitter.lifetime = 1.2
       emitter.blend_mode = GPUParticles2D.BR_MODE_ADD
       # Helical motion via orbital_velocity
       emitter.orbital_velocity = 40.0  # pixels per revolution
       emitter.orbital_velocity_local = true  # local space orbital
   ```

3. **Helical Motion Implementation**:
   - Use `GPUParticles2D` with `orbital_velocity` parameter for spiral motion
   - P1 emitter configured for clockwise (positive orbital)
   - P2 emitter configured for counterclockwise (negative orbital)
   - Both at same position, same lifetime, additive blend

4. **Signal Handling**:
   ```gdscript
   func _on_sync_burst_triggered(position: Vector2) -> void:
       emit_sync_burst(position)

   func emit_sync_burst(position: Vector2) -> void:
       var emitter := _get_gpu_sync_emitter()
       if emitter == null:
           return
       _configure_sync_emitter(emitter, position)
       emitter.restart()
       _active_emitter_count += 1
   ```

5. **Sync Burst One-Shot**:
   - Triggered by `Events.sync_burst_triggered` (separate from continuous chain)
   - 50 particles: 25 orange + 25 blue + gold sparks
   - Explosive radial outward, lifetime 1.2s
   - Uses CPU pool (not GPU) for one-shot burst

6. **State Tracking**:
   - Track `sync_chain_length` from ComboSystem
   - When `sync_chain_length >= 1`: activate continuous emitter
   - When `sync_chain_length == 0`: deactivate continuous emitter

---

## Out of Scope

- hit_vfx emitter (Story 002)
- combo_escalation_vfx emitter (Story 003)
- FIFO queue (Story 007)

---

## QA Test Cases

**Integration Test Specs**:

- **test_sync_burst_uses_gpu_pool**: Given VFXManager, when emit_sync_burst called → then emitter is from _gpu_sync_pool, not _cpu_particle_pool
- **test_sync_burst_additive_blend**: Given GPU emitter configured for sync_burst, when blend_mode read → then equals BR_MODE_ADD
- **test_orbital_velocity_for_helical**: Given sync_burst emitter configured, when orbital_velocity read → then positive value (clockwise)
- **test_sync_chain_deactivate**: Given sync_chain_length=3, when sync_chain_length drops to 0 → then continuous emitter deactivated
- **test_signal_connected**: Given VFXManager, when Events.sync_burst_triggered emitted → then _on_sync_burst_triggered is called

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/vfx/sync_burst_vfx_test.gd` — must exist and pass OR documented playtest

---

## Dependencies

- Depends on: Story 001 (VFXManager foundation, GPU pool), ADR-ARCH-004 (ComboSystem sync_burst_triggered signal)
- Unlocks: Story 007 (queue integration)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
