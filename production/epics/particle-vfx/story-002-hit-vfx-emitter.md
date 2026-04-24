# Story 002: hit_vfx Emitter (CPUParticles2D)

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-23
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-001`, `TR-vfx-002` — 5 emitter types including hit_vfx; CPUParticles2D for burst emitters

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: hit_vfx driven by CombatSystem.hit_landed; CPUParticles2D one-shot burst; particle count/speed/spread/gravity vary by attack_type; direction-biased radial emission

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-01, AC-02, AC-12, AC-13:

- [ ] **AC-VFX-2.1**: `emit_hit(position, attack_type, direction, player_color)` fires CPUParticles2D burst at `position`
- [ ] **AC-VFX-2.2**: LIGHT attack: 5-8 particles, speed 180-250 px/s, spread 180° (360°), gravity 400 px/s²
- [ ] **AC-VFX-2.3**: MEDIUM attack: 10-15 particles, speed 220-300 px/s, spread 180° (360°), gravity 400 px/s²
- [ ] **AC-VFX-2.4**: HEAVY attack: 18-25 particles, speed 150-200 px/s, spread 60° (120° cone in direction), gravity 200 px/s²
- [ ] **AC-VFX-2.5**: SPECIAL attack: 30-40 particles, speed 200-280 px/s, spread 60° (120° cone), gravity 200 px/s²
- [ ] **AC-VFX-2.6**: Particle color = `player_color` (COLOR_P1 or COLOR_P2)
- [ ] **AC-VFX-2.7**: At combo tier >= 3: particle count multiplied by 1.5x, gold sparks appear (floor(base * 0.10))
- [ ] **AC-VFX-2.8**: At combo tier = 4: particle count multiplied by 2.0x, confetti bonus +30 particles
- [ ] **AC-VFX-2.9**: Particles use `explosiveness = 0.8`, `lifetime_randomness = 0.3`
- [ ] **AC-VFX-2.10**: Hit VFX emits via `emit_hit()` called by CombatSystem (direct, not via Events bus per ADR-ARCH-008)

---

## Implementation Notes

1. **Emit Interface**:
   ```gdscript
   func emit_hit(position: Vector2, attack_type: String, direction: Vector2, player_color: Color) -> void:
       var count := _get_particle_count(attack_type)
       # ...budget check...
       var emitter := _checkout_cpu_emitter()
       if emitter == null:
           return
       _configure_hit_emitter(emitter, attack_type, position, direction, player_color)
       emitter.restart()
       _active_particle_count += count
       emitter.connect("finished", _on_emitter_finished.bind(emitter, count), CONNECT_ONE_SHOT)
   ```

2. **Particle Count by Attack Type** (per GDD Rule 2):
   | Attack | Count Range |
   |--------|-------------|
   | LIGHT | 5–8 (randi() % 4 + 5) |
   | MEDIUM | 10–15 (randi() % 6 + 10) |
   | HEAVY | 18–25 (randi() % 8 + 18) |
   | SPECIAL | 30–40 (randi() % 11 + 30) |

3. **Speed by Attack Type** (GDD Rule 2):
   | Attack | Speed Range |
   |--------|-------------|
   | LIGHT | 180–250 px/s |
   | MEDIUM | 220–300 px/s |
   | HEAVY | 150–200 px/s |
   | SPECIAL | 200–280 px/s |

4. **Spread and Gravity** (GDD Rule 2):
   | Attack | Spread | Gravity |
   |--------|--------|---------|
   | LIGHT/MEDIUM | 180° (full 360°) | 400 px/s² |
   | HEAVY/SPECIAL | 60° (120° cone in direction) | 200 px/s² |

5. **Combo Tier Multiplier** (GDD Rule 7):
   | Tier | Multiplier | Gold Sparks | Confetti |
   |------|-----------|-------------|----------|
   | 1 | 1.0 | No | No |
   | 2 | 1.2 | No | No |
   | 3 | 1.5 | Yes (floor(base * 0.10)) | No |
   | 4 | 2.0 | Yes | +30 |

6. **Direction Handling**:
   - For LIGHT/MEDIUM: `emitter.direction = direction.normalized()`, spread 180° creates full radial
   - For HEAVY/SPECIAL: `emitter.direction = direction.normalized()`, spread 60° creates cone

---

## Out of Scope

- Sync burst continuous emitter (Story 004)
- FIFO queue (Story 007)
- Boss death emitter (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_light_hit_particle_count**: Given attack_type="LIGHT", when _get_particle_count() called → then result in range [5, 8]
- **test_heavy_hit_particle_count**: Given attack_type="HEAVY", when _get_particle_count() called → then result in range [18, 25]
- **test_combo_tier3_multiplier**: Given attack_type="LIGHT" (base 6) and tier=3, when composite count calculated → then result = 6 * 1.5 + floor(6 * 0.10) = 9 + 0 = 9
- **test_combo_tier4_confetti**: Given attack_type="LIGHT" (base 6) and tier=4, when composite count calculated → then result = 6 * 2.0 + floor(6 * 0.10) + 30 = 12 + 0 + 30 = 42
- **test_gold_sparks_tier3**: Given base=20 and tier=3, when gold_sparks calculated → then floor(20 * 0.10) = 2
- **test_heavy_has_narrow_spread**: Given attack_type="HEAVY", when _get_spread() called → then result = 60.0 (degrees)
- **test_light_has_full_spread**: Given attack_type="LIGHT", when _get_spread() called → then result = 180.0 (degrees)
- **test_heavy_gravity_lower**: Given attack_type="HEAVY", when _get_gravity() called → then result = Vector2(0, 200)
- **test_light_gravity_higher**: Given attack_type="LIGHT", when _get_gravity() called → then result = Vector2(0, 400)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/vfx/hit_vfx_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (VFXManager foundation, pool checkout)
- Unlocks: Story 007 (queue integration)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
