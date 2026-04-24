# Story 006: boss_death_vfx Emitter

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-23
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-001`, `TR-vfx-002` — boss_death_vfx emitter type; CPUParticles2D for burst emitters

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: boss_death_vfx driven by Events.boss_defeated; CPUParticles2D one-shot burst; force-cancels all active hit_vfx emitters; gold confetti explosion

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-09, AC-17:

- [ ] **AC-VFX-6.1**: `emit_boss_death(position)` fires CPUParticles2D burst at `position`
- [ ] **AC-VFX-6.2**: Particle count: 60 (large explosion)
- [ ] **AC-VFX-6.3**: Color: starts white, fades to #FFD700 gold
- [ ] **AC-VFX-6.4**: Motion: explosive upward burst, then parabolic fall (paper rain)
- [ ] **AC-VFX-6.5**: Spread: 180° (full radial)
- [ ] **AC-VFX-6.6**: Initial velocity max: 300 px/s
- [ ] **AC-VFX-6.7**: `_on_boss_defeated(position, boss_type)` connected to Events.boss_defeated
- [ ] **AC-VFX-6.8**: All active hit_vfx emitters force-cancelled when boss_death fires (per GDD Edge Case)
- [ ] **AC-VFX-6.9**: boss_death has visual priority — no other VFX competes when boss dies

---

## Implementation Notes

1. **Emit Interface**:
   ```gdscript
   func emit_boss_death(position: Vector2) -> void:
       # Force-cancel all active hit emitters first
       _force_cancel_all_hit_emitters()

       var emitter := _checkout_cpu_emitter()
       if emitter == null:
           return
       _configure_boss_death_emitter(emitter, position)
       emitter.restart()
       _active_particle_count += 60
   ```

2. **Force-Cancel All Hit Emitters**:
   ```gdscript
   func _force_cancel_all_hit_emitters() -> void:
       for emitter in _cpu_particle_pool:
           if emitter.emitting:
               emitter.emitting = false
               # Note: active particle count decrement handled by finished signal
   ```
   - This is a special case — boss death is the climactic end-state
   - All in-flight hit VFX immediately cancelled to not compete visually

3. **Boss Death Emitter Configuration**:
   ```gdscript
   func _configure_boss_death_emitter(emitter: CPUParticles2D, position: Vector2) -> void:
       emitter.position = position
       emitter.amount = 60
       emitter.color = Color.WHITE
       emitter.spread = 180.0  # Full radial
       emitter.initial_velocity_min = 200.0
       emitter.initial_velocity_max = 300.0
       emitter.gravity = Vector2(0, 200)  # Slow fall (paper rain)
       emitter.lifetime = 1.5
       emitter.lifetime_randomness = 0.4
       emitter.explosiveness = 0.7
       emitter.one_shot = true
   ```

4. **Gold Confetti Addition**:
   - 30 extra gold particles added to the burst at tier 4-equivalent behavior
   - Use separate emitter or additive layer for gold confetti
   ```gdscript
   # Additional gold confetti burst
   var gold_emitter := _checkout_cpu_emitter()
   if gold_emitter != null:
       gold_emitter.position = position
       gold_emitter.amount = 30
       gold_emitter.color = COLOR_GOLD
       gold_emitter.spread = 180.0
       gold_emitter.initial_velocity_min = 150.0
       gold_emitter.initial_velocity_max = 250.0
       gold_emitter.gravity = Vector2(0, 100)  # Slow float down
       gold_emitter.lifetime = 2.0
       gold_emitter.blend_mode = CPUParticles2D.BLEND_MODE_ADD  # Additive for gold glow
       gold_emitter.restart()
       _active_particle_count += 30
   ```

5. **Signal Connection**:
   ```gdscript
   func _connect_signals() -> void:
       Events.boss_defeated.connect(_on_boss_defeated)

   func _on_boss_defeated(position: Vector2, boss_type: String) -> void:
       emit_boss_death(position)
   ```

6. **Note on boss_defeated Signal** (GDD Open Question #1):
   - Signal signature: `boss_defeated(position: Vector2, boss_type: String)`
   - Still pending BossAI adoption — verify with BossAI epic before implementation

---

## Out of Scope

- hit_vfx emitter (Story 002)
- combo_escalation_vfx emitter (Story 003)
- sync_burst emitter (Story 004)
- rescue_vfx emitter (Story 005)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_boss_death_particle_count**: Given emit_boss_death called, when emitter.amount read → then equals 60
- **test_boss_death_white_to_gold**: Given boss death emitter, when color initial read → then equals Color.WHITE
- **test_boss_death_full_radial**: Given boss death emitter, when spread read → then equals 180.0
- **test_force_cancel_on_boss_death**: Given 3 active hit_vfx emitters, when emit_boss_death called → then all 3 set to non-emitting
- **test_signal_connected**: Given VFXManager, when Events.boss_defeated emitted → then _on_boss_defeated is called

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/vfx/boss_death_vfx_test.gd` — must exist and pass OR documented playtest

---

## Dependencies

- Depends on: Story 001 (VFXManager foundation, pool checkout), BossAI epic (boss_defeated signal — verify signature)
- Unlocks: Story 007 (queue integration)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
