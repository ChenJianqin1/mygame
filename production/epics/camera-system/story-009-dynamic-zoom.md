# Story 009: Dynamic Zoom (Player Distance-Based)

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-003, TR-camera-020
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Zoom calculated from player distance: <200px = 1.0x, 200-400px = 0.85x, >400px = 0.7x. Combines multiplicatively with combat state zoom.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Camera2D zoom property accepts Vector2; Tween for smooth transitions.

**Control Manifest Rules (this layer)**:
- Required: Distance-based zoom thresholds per ADR-ARCH-007
- Forbidden: Hardcoded zoom values outside formula
- Guardrail: Zoom does not affect CanvasLayer (UI stays fixed size)

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-1.3: Both players separated to 400px+ — camera auto-zooms to 0.7x, both players and Boss still visible
- [ ] AC-6.3: Player distance <200px — camera does not zoom in (stays 1.0x), maintains tight composition

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Zoom formula**: `effective_zoom = BASE_ZOOM * player_distance_zoom * combat_state_zoom * boss_phase_zoom`
2. **Distance zoom table**:
   - < 200px: `player_distance_zoom = 1.0`
   - 200-400px: `player_distance_zoom = 0.85`
   - > 400px: `player_distance_zoom = 0.7`
3. **Implementation**: `_calculate_target_zoom()` in `_update_zoom(delta)` — compares `dist = _get_player_distance()` against thresholds
4. **Smooth transitions**: Use Tween for zoom changes: `create_tween().tween_property(self, "zoom", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)`
5. **Camera bounds**: Ensure both players + Boss visible after zoom — boss contextual bias (Story 002) handles framing

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Player position tracking, `_get_player_distance()`, boss contextual bias
- Story 003: Combat state zoom factors (PLAYER_ATTACK=0.9x, SYNC_ATTACK=0.85x, etc.)
- Story 007: Boss phase zoom (0.75x for BOSS_PHASE_CHANGE)

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-1.3**: Players at 400px+ → zoom = 0.7x
  - Given: CameraController base_zoom=1.0, P1 at (100, 360), P2 at (600, 360) — distance=500px
  - When: _calculate_target_zoom() called
  - Then: player_distance_zoom = 0.7 (distance > 400px)
  - Edge cases: Exactly 400px (use 0.85x, boundary condition), exactly 200px (use 1.0x)

- **AC-1.3**: Players at 200-400px → zoom = 0.85x
  - Given: CameraController base_zoom=1.0, P1 at (100, 360), P2 at (450, 360) — distance=350px
  - When: _calculate_target_zoom() called
  - Then: player_distance_zoom = 0.85
  - Edge cases: Exactly 200px (use 1.0x), exactly 400px (use 0.85x)

- **AC-6.3**: Players <200px → zoom = 1.0x (no zoom in)
  - Given: CameraController base_zoom=1.0, P1 at (300, 360), P2 at (450, 360) — distance=150px
  - When: _calculate_target_zoom() called
  - Then: player_distance_zoom = 1.0 (no zoom change)
  - Edge cases: Players overlapping (distance=0, still 1.0x)

- **Zoom combines multiplicatively**: Players at 300px + PLAYER_ATTACK state
  - Given: distance=300px (player_distance_zoom=0.85), current_state="PLAYER_ATTACK" (combat_state_zoom=0.9)
  - When: effective_zoom calculated
  - Then: effective_zoom = 1.0 * 0.85 * 0.9 = 0.765
  - Edge cases: Multiple zoom factors, zoom clamping at reasonable bounds (0.5 min, 1.5 max)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/camera/dynamic_zoom_test.gd` — must exist and pass

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 002 (player tracking, distance calculation)
- Unlocks: None (terminal story)
