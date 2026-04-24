# Story 005: Paper Texture Implementation

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/animation-system.md`
**Requirement**: `TR-anim-012`, `TR-anim-013` — Paper texture overlay; Squash/stretch effects

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: 每个角色由两层构成：底层是主要色块精灵，顶层是纸张纹理叠加层；撕裂边缘通过粒子特效系统实现

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ShaderMaterial with noise texture for paper jitter; Sprite2D.scale for squash/stretch

---

## Acceptance Criteria

From GDD AC-6:

- [ ] **AC-6.1**: 所有角色精灵有纸张纹理叠加层（opacity=0.15），可见微抖动（±1.0px，8Hz）
- [ ] **AC-6.2**: 打击帧（active帧）触发squash/stretch效果，Sprite2D.scale峰值=1.2

**Paper Texture Parameters (GDD Section G.4)**:

| Parameter | Default | Safe Range |
|-----------|---------|------------|
| paper_texture_opacity | 0.15 | 0.0-0.4 |
| paper_jitter_amplitude | 1.0px | 0.0-3.0px |
| paper_jitter_frequency | 8Hz | 2-20Hz |
| squash_stretch_intensity | 1.2 | 1.0-1.5 |

**Layer Z-Order**:
- Player main sprite: Z=20
- Paper texture overlay: Z=+1 (21)
- Effects: Z=+10 (30)

---

## Implementation Notes

1. **Paper Texture Overlay**:
   - Create `TextureRect` or `Sprite2D` layered on top of main character sprite
   - Use ShaderMaterial with noise texture for paper grain effect
   - opacity = 0.15 (adjustable via tuning knob)

2. **Jitter Effect**:
   - Implement via `_process(delta)` offsetting position by noise
   - noise_offset = sin(time * frequency) * amplitude
   - Frequency: 8Hz, Amplitude: ±1.0px

3. **Squash/Stretch**:
   - On `hitbox_activated` signal (active frame)
   - Set Sprite2D.scale to Vector2(1.2, 0.8) for 2 frames
   - Then return to Vector2(1.0, 1.0)
   - Keyframed in AnimationPlayer for precision

4. **Paper Tear Effect**:
   - Triggered at active frame via signal to particle-vfx system
   - Emit paper tear particles (irregular paper shapes)
   - NOT sprite deformation

---

## Out of Scope

- Particle emission for paper tears (particle-vfx epic)
- Integration with hitbox activation (Story 002)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_paper_texture_opacity**: Given character sprite, when paper overlay active → then opacity = 0.15
- **test_jitter_frequency**: Given character with jitter, when 1 second passes → then position oscillates 8 times
- **test_jitter_amplitude**: Given character with jitter amplitude=1.0px, when peak → then offset = ±1.0px from base
- **test_squash_on_hit**: Given attack reaches active frame, when → then Sprite2D.scale peaks at 1.2 on X, 0.8 on Y
- **test_squash_recovery**: Given squash/stretch peak, when 2 frames pass → then scale returns to 1.0, 1.0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/paper_texture_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 002 (hitbox activation triggers squash/stretch)
- Unlocks: Visual polish complete

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
