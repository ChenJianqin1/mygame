# Story 005: rescue_vfx Emitter

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-23
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-001`, `TR-vfx-002` — rescue_vfx emitter type; CPUParticles2D for burst emitters

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: rescue_vfx driven by Events.rescue_triggered; CPUParticles2D one-shot burst; upward arc toward rescued player; color = rescuer_color (not rescued player's color); hand glow sprite

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-08, AC-08 Hand Glow:

- [ ] **AC-VFX-5.1**: `emit_rescue(position, rescuer_color)` fires CPUParticles2D burst at `position`
- [ ] **AC-VFX-5.2**: Particle count: 12-18 (randi() % 7 + 12)
- [ ] **AC-VFX-5.3**: Particle color = `rescuer_color` (rescuer's color, NOT rescued player's color)
- [ ] **AC-VFX-5.4**: Motion: 45° cone upward (Vector2.UP direction), spread 45°
- [ ] **AC-VFX-5.5**: Initial speed: 120-180 px/s, decelerating (negative acceleration)
- [ ] **AC-VFX-5.6**: Lifetime: 0.4-0.7s
- [ ] **AC-VFX-5.7**: `_on_rescue_triggered(position, rescuer_color)` connected to Events.rescue_triggered
- [ ] **AC-VFX-5.8**: Hand glow sprite: circular glow, radius 40px, color = rescuer_color, fades over 0.5s
- [ ] **AC-VFX-5.9**: Particles: small paper scraps + golden spark accents (6-12px)

---

## Implementation Notes

1. **Emit Interface**:
   ```gdscript
   func emit_rescue(position: Vector2, rescuer_color: Color) -> void:
       var emitter := _checkout_cpu_emitter()
       if emitter == null:
           return
       _configure_rescue_emitter(emitter, rescuer_color)
       emitter.restart()
       _active_particle_count += 18
   ```

2. **Rescue Emitter Configuration**:
   ```gdscript
   func _configure_rescue_emitter(emitter: CPUParticles2D, rescuer_color: Color) -> void:
       emitter.position = position
       emitter.amount = randi() % 7 + 12  # 12-18
       emitter.color = rescuer_color  # RESCUER's color, not rescued player's
       emitter.direction = Vector2(0, -1)  # Upward
       emitter.spread = 45.0  # 45-degree cone
       emitter.initial_velocity_min = 120.0
       emitter.initial_velocity_max = 180.0
       emitter.lifetime = 0.4 + randf() * 0.3  # 0.4-0.7s
       emitter.one_shot = true
   ```

3. **Hand Glow Sprite** (separate from particle emitter):
   ```gdscript
   # Hand glow is a Sprite2D or ShaderMaterial circle, not a particle effect
   # Created as a separate Node2D child of VFXLayer
   func _spawn_hand_glow(position: Vector2, rescuer_color: Color) -> void:
       var glow := Sprite2D.new()
       glow.texture = _create_glow_texture()  # Radial gradient circle
       glow.modulate = rescuer_color
       glow.scale = Vector2(80, 80)  # 40px radius * 2
       glow.position = position
       # Fade out over 0.5s via tween
       var tween := create_tween()
       tween.tween_property(glow, "modulate:a", 0.0, 0.5)
       tween.tween_callback(glow.queue_free)
       add_child(glow)
   ```

4. **Signal Connection**:
   ```gdscript
   func _connect_signals() -> void:
       Events.rescue_triggered.connect(_on_rescue_triggered)

   func _on_rescue_triggered(position: Vector2, rescuer_color: Color) -> void:
       emit_rescue(position, rescuer_color)
       _spawn_hand_glow(position, rescuer_color)
   ```

5. **Color Source** (Critical - GDD Rule 4):
   - `rescue_vfx` color = `rescuer_color` from signal
   - NOT the rescued player's color
   - This is intentional — "you伸手拉了我一把" — the rescuer's warmth is what is visualized

---

## Out of Scope

- hit_vfx emitter (Story 002)
- combo_escalation_vfx emitter (Story 003)
- sync_burst emitter (Story 004)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_rescue_particle_count**: When _get_rescue_particle_count() called → then result in range [12, 18]
- **test_rescue_uses_rescuer_color**: Given rescuer_color=COLOR_P1, when _configure_rescue_emitter called → then emitter.color = COLOR_P1
- **test_rescue_upward_motion**: Given rescue emitter, when direction read → then equals Vector2(0, -1) (upward in Godot 2D)
- **test_rescue_spread**: Given rescue emitter, when spread read → then equals 45.0 degrees
- **test_hand_glow_spawns**: Given rescue triggered, when _spawn_hand_glow called → then Sprite2D created with correct modulate color
- **test_hand_glow_fades**: Given hand glow spawned, when 0.5s passes → then sprite queue_free called
- **test_signal_connected**: Given VFXManager, when Events.rescue_triggered emitted → then _on_rescue_triggered is called

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/vfx/rescue_vfx_test.gd` — must exist and pass OR documented playtest

---

## Dependencies

- Depends on: Story 001 (VFXManager foundation, pool checkout), ADR-ARCH-005 (CoopSystem rescue_triggered signal)
- Unlocks: Story 007 (queue integration)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
