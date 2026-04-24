# Story 003: combo_escalation_vfx Emitter

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-23
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-001`, `TR-vfx-002` — combo_escalation_vfx emitter type; CPUParticles2D for burst emitters

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: combo_escalation_vfx driven by Events.combo_tier_escalated; CPUParticles2D one-shot burst; tier-based particle count scaling; color brightness increases per tier

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-03, AC-04, AC-12, AC-13:

- [ ] **AC-VFX-3.1**: `emit_combo_escalation(tier, player_color, position)` fires CPUParticles2D burst at `position`
- [ ] **AC-VFX-3.2**: Tier 1→2 transition: 8 burst particles, player_color +20% brightness, rising arc motion
- [ ] **AC-VFX-3.3**: Tier 2→3 transition: 15 burst particles, player_color +40% brightness + glow, burst outward
- [ ] **AC-VFX-3.4**: Tier 3→4 transition: 25 burst particles, gold #FFD700, explosive upward burst
- [ ] **AC-VFX-3.5**: `_on_combo_tier_escalated(tier, player_color)` connected to Events.combo_tier_escalated
- [ ] **AC-VFX-3.6**: combo_tier_escalated signal provides `position` (retrieved from GameState or passed as param per implementation)
- [ ] **AC-VFX-3.7**: At tier >= 3: emitter color modulated with gold tint (COLOR_GOLD overlay)

---

## Implementation Notes

1. **Emit Interface**:
   ```gdscript
   func emit_combo_escalation(tier: int, player_color: Color, position: Vector2) -> void:
       var count := tier * 15  # 15, 30, 45, 60 for tiers 1-4
       # ...budget check...
       var emitter := _checkout_cpu_emitter()
       if emitter == null:
           return
       _configure_combo_emitter(emitter, tier, player_color)
       emitter.restart()
       _active_particle_count += count
   ```

2. **Tier-Based Configuration** (GDD Section Rule 7):

   | From Tier | To Tier | Burst Count | Color Effect | Motion |
   |-----------|---------|-------------|-------------|--------|
   | 1 | 2 | 8 | +20% brightness | Rising arc |
   | 2 | 3 | 15 | +40% brightness + glow | Burst outward |
   | 3 | 4 | 25 | Gold #FFD700 | Explosive upward |

3. **Color Brightness Calculation**:
   ```gdscript
   func _configure_combo_emitter(emitter: CPUParticles2D, tier: int, player_color: Color) -> void:
       emitter.amount = tier * 15
       emitter.color = player_color
       if tier >= 3:
           emitter.color = player_color * 1.4  # +40% brightness
           emitter.modulate = COLOR_GOLD
   ```

4. **Signal Connection**:
   ```gdscript
   func _connect_signals() -> void:
       Events.combo_tier_escalated.connect(_on_combo_tier_escalated)

   func _on_combo_tier_escalated(tier: int, player_color: Color) -> void:
       emit_combo_escalation(tier, player_color, Vector2.ZERO)  # position from GameState
   ```

5. **Tier Regression Handling** (GDD Edge Cases):
   - If `combo_tier_escalated` fires with lower tier than current: force-cancel any running higher-tier emitter
   - No de-escalation animation

---

## Out of Scope

- hit_vfx emitter configuration (Story 002)
- sync_burst continuous emitter (Story 004)
- FIFO queue (Story 007)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_tier2_escalation_count**: Given tier=2, when emit_combo_escalation configured → then emitter.amount = 30 (tier * 15)
- **test_tier3_escalation_brightness**: Given tier=3 and player_color, when _configure_combo_emitter called → then emitter.color = player_color * 1.4
- **test_tier4_escalation_gold**: Given tier=4, when _configure_combo_emitter called → then emitter.modulate = COLOR_GOLD
- **test_signal_connected**: Given VFXManager, when Events.combo_tier_escalated emitted → then _on_combo_tier_escalated is called
- **test_tier_regression_no_de_escalation**: Given tier=4 emitter running, when combo_tier_escalated(2) fires → then tier-4 emitter force-cancelled

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/vfx/combo_escalation_vfx_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (VFXManager foundation, pool checkout), ADR-ARCH-001 (Events Autoload)
- Unlocks: Story 007 (queue integration)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
