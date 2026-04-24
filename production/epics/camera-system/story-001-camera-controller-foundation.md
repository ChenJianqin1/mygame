# Story 001: CameraController Foundation + Trauma Shake

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-007, TR-camera-021
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Camera2D trauma shake via `offset` property (not `position`); 7-state machine with priority ordering; SMOOTHING_CENTER_OUT mode; dynamic zoom calculation via player distance and combat state.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Camera2D.smoothing (bool) deprecated in Godot 4.4+ — use `position_smoothing_enabled` (bool) + `position_smoothing_speed` (float). Godot 4.6 verified. `smoothing` mode enum still `Camera2DSmoothingMode`.

**Control Manifest Rules (this layer)**:
- Required: SMOOTHING_CENTER_OUT mode, trauma-based shake via `offset`
- Forbidden: Never apply screen shake to `position` — use `offset` only
- Guardrail: AC-7.1 — 3 chars + shake + zoom at 60fps

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-7.1: 3 characters + full-screen shake + full zoom animation — frame rate stable at 60fps
- [ ] AC-2.4: Shake ends — camera returns to exact pre-shake position, no drift (offset returns to Vector2.ZERO)

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Camera2D setup**: Set `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0` (NORMAL speed), `smoothing = Camera2D.SMOOTHING_CENTER_OUT`
2. **Trauma shake**: `trauma` float 0.0-1.0, decays at `trauma_decay = 2.0/s`. Shake offset = `randf_range(-1,1) * trauma * trauma * max_offset`. Apply to `offset` property.
3. **No drift**: When `trauma = 0`, `offset = Vector2.ZERO` — precise return to origin
4. **Physics process**: Use `_physics_process(delta)` for camera updates — fixed 60fps timestep
5. **Emit signal**: `Events.camera_shake_intensity.emit(trauma)` every frame when trauma > 0

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Player position tracking via PlayerManager
- Story 003: State machine transitions
- Story 004-008: Combat signal responses

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[For Logic / Integration stories — automated test specs]:**

- **AC-7.1**: 3 characters + full-screen shake + full zoom animation — frame rate stable at 60fps
  - Given: CameraController active, 3 character nodes in scene, trauma = 1.0
  - When: _physics_process runs for 60 frames (1 second)
  - Then: frame time remains <= 16.67ms (60fps), no dropped frames
  - Edge cases: trauma decay during measurement, zoom changes mid-measurement

- **AC-2.4**: Shake ends — camera returns to exact pre-shake position, no drift
  - Given: CameraController with trauma = 0.5, offset currently non-zero
  - When: trauma decays to 0.0 (simulated via 5+ seconds of _physics_process)
  - Then: offset == Vector2.ZERO, camera position unchanged from pre-shake
  - Edge cases: trauma clamped at 1.0, negative trauma prevented

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/camera/camera_controller_foundation_test.gd` — must exist and pass

**Status**: Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002, Story 003
