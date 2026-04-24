# Story 006: Combo Tier Zoom (Tier 3+)

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-010, TR-camera-011
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Events.combo_tier_changed(tier, player_id) triggers COMBAT_ZOOM state when tier >= 3; returns to NORMAL when tier drops below 3.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Events autoload must be connected in `_ready()`. Godot 4.6 Callable syntax.

**Control Manifest Rules (this layer)**:
- Required: Consumers connect signals in `_ready()` only
- Forbidden: No direct node references for cross-system communication
- Guardrail: COMBAT_ZOOM hold timer = 0.3s

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-3.3: Combo Tier rises to 3+ → camera enters COMBAT_ZOOM mode, zoom 0.85x
- [ ] AC-3.4: Combo Tier drops below 3 — 0.3s内平滑返回NORMAL

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Signal connection**: `Events.combo_tier_changed.connect(_on_combo_tier_changed)` in `_ready()`
2. **Handler**: `_on_combo_tier_changed(tier: int, player_id: int)` — if tier >= 3, calls `_transition_state("COMBAT_ZOOM")`; if tier < 3 and current state is COMBAT_ZOOM, initiates return timer
3. **Zoom/speed**: COMBAT_ZOOM zoom = 0.85x, smoothing speed = 10.0 (handled by state machine)
4. **Priority**: COMBAT_ZOOM (priority 1) can be interrupted by PLAYER_ATTACK (2), SYNC_ATTACK (3), etc.
5. **Hold timer**: COMBAT_ZOOM hold = 0.3s before returning to NORMAL

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: State machine (transition logic, hold timers, zoom/speed)
- Story 001: Trauma shake implementation

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-3.3**: combo_tier_changed(3, 1) → COMBAT_ZOOM state
  - Given: CameraController in NORMAL
  - When: Events.combo_tier_changed.emit(3, 1) fired
  - Then: _on_combo_tier_changed called, _transition_state("COMBAT_ZOOM") called
  - Edge cases: tier=2 (should not trigger), tier=4 (should trigger)

- **AC-3.4**: Combo drops below 3 → return to NORMAL after 0.3s
  - Given: CameraController in COMBAT_ZOOM (from tier 3)
  - When: Events.combo_tier_changed.emit(2, 1) fired
  - Then: after 0.3s, state returns to NORMAL
  - Edge cases: tier rises back to 3 before 0.3s expires (cancel return)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/camera/combo_tier_zoom_test.gd` OR playtest doc

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003
- Unlocks: None
