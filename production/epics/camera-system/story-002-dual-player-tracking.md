# Story 002: Dual-Player Weighted Centroid Tracking

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-001, TR-camera-002, TR-camera-018, TR-camera-019, TR-camera-020
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Camera targets weighted centroid of P1+P2; active attacker weight 1.5x, passive defender weight 0.8x; boss contextual bias 0.15x when boss > 200px from midpoint.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Camera2D.position_smoothing_enabled + position_smoothing_speed in Godot 4.6.

**Control Manifest Rules (this layer)**:
- Required: Weighted centroid formula per ADR-ARCH-007 rules
- Forbidden: Camera never uses direct node references to players — must use Events/published interface
- Guardrail: Camera offset drift prevention

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-1.1: Single player moving in arena — camera smoothly follows, no jitter or breakup
- [ ] AC-1.2: Both players moving simultaneously — camera follows both centroids, both always visible
- [ ] AC-1.3: Both players separated to 400px+ — camera auto-zooms to 0.7x, both players and Boss still visible
- [ ] AC-6.1: P1 left, P2 right, Boss in middle — all three visible simultaneously, no clipping
- [ ] AC-6.2: P1 attacking — camera weighted toward P1 (P1 weight 1.5, P2 weight 0.8), but P2 still in frame
- [ ] AC-6.3: Player distance <200px — camera does not zoom in (stays 1.0x), maintains tight composition

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Weighted centroid formula**: `camera_target = (P1_pos * P1_weight + P2_pos * P2_weight) / (P1_weight + P2_weight)`
2. **Weight rules**:
   - Default: P1_weight = 1.0, P2_weight = 1.0
   - Active attacker: weight = 1.5 (from `attack_started` signal)
   - Passive defender (teammate attacking): weight = 0.8
3. **Boss contextual offset**: If `|boss_pos - midpoint| > 200px`, apply `boss_bias = (boss_pos - midpoint) * 0.15`
4. **Player position retrieval**: `_get_player_position(player_id)` — stub to be connected to PlayerManager later (Events interface)
5. **Zoom thresholds**: <200px = 1.0x, 200-400px = 0.85x, >400px = 0.7x

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: CameraController base + trauma shake
- Story 003: State machine (zoom changes from state transitions handled separately)
- Story 004: Player attack signal response (weight changes from Events.attack_started)

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-1.1**: Single player moving in arena — camera smoothly follows, no jitter or breakup
  - Given: CameraController, P1 at (100, 360), P2 non-existent
  - When: P1 moves to (500, 360) over 2 seconds
  - Then: camera position follows smoothly, no teleporting
  - Edge cases: P2 node missing, P2 at exact same position as P1

- **AC-1.2**: Both players moving simultaneously — camera follows both centroids, both always visible
  - Given: CameraController, P1 at (100, 360), P2 at (300, 360)
  - When: P1 moves to (200, 360) and P2 moves to (400, 360) simultaneously
  - Then: camera centroid = (300, 360), both players visible
  - Edge cases: Players moving in opposite directions, one player stationary

- **AC-1.3**: Both players separated to 400px+ — camera auto-zooms to 0.7x
  - Given: CameraController at base zoom 1.0, P1 at (100, 360), P2 at (600, 360)
  - When: Player distance = 500px (> 400px threshold)
  - Then: zoom = 0.7x (auto-calculated, not state-based zoom)
  - Edge cases: Exactly 400px (boundary), players diagonal (500px Euclidean)

- **AC-6.2**: P1 attacking — camera weighted toward P1 (P1 weight 1.5, P2 weight 0.8)
  - Given: CameraController, P1 at (200, 360), P2 at (400, 360), P1_weight=1.5, P2_weight=0.8
  - When: centroid calculated
  - Then: centroid_x = (200*1.5 + 400*0.8) / 2.3 ≈ 282 — biased toward P1
  - Edge cases: P2 also attacking (both 1.5), P1 at screen edge

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/camera/dual_player_tracking_test.gd` — must exist and pass

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001 (CameraController base must exist)
- Unlocks: Story 003, Story 004, Story 005, Story 006, Story 007, Story 008
