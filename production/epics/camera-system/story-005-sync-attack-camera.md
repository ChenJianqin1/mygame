# Story 005: Sync Attack Camera Response

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-006
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Events.sync_burst_triggered signal triggers SYNC_ATTACK state; sets trauma = 0.8 for maximum shake on 3rd consecutive sync.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Events autoload must be connected in `_ready()`. Godot 4.6 Callable syntax.

**Control Manifest Rules (this layer)**:
- Required: Consumers connect signals in `_ready()` only
- Forbidden: No direct node references for cross-system communication
- Guardrail: SYNC_ATTACK hold timer = 0.5s

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-2.3: Sync attack triggered — orange-blue alternating pulse visual, shake intensity ~0.3, lasts ~0.5s
- [ ] AC-3.1: Any player initiates attack → camera immediately enters PLAYER_ATTACK mode (SYNC_ATTACK also covered by same mechanism)

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Signal connection**: `Events.sync_burst_triggered.connect(_on_sync_burst_triggered)` in `_ready()`
2. **Handler**: `_on_sync_burst_triggered(position: Vector2)` — calls `_transition_state("SYNC_ATTACK")`, sets `trauma = maxf(trauma, 0.8)` (maximum for 3rd consecutive sync)
3. **Zoom/speed**: SYNC_ATTACK zoom = 0.85x, smoothing speed = 12.0 (handled by state machine)
4. **Visual note**: Orange-blue pulse is VFX system's responsibility (camera emits `camera_shake_intensity`); camera only triggers the state
5. **Hold timer**: SYNC_ATTACK hold = 0.5s before returning to NORMAL

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: State machine (transition logic, hold timers, zoom/speed)
- Story 001: Trauma shake implementation
- Story 002: Player position tracking

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-2.3**: sync_burst_triggered → SYNC_ATTACK state, trauma = 0.8
  - Given: CameraController in NORMAL, trauma = 0
  - When: Events.sync_burst_triggered.emit(Vector2(400, 360)) fired
  - Then: _on_sync_burst_triggered called, _transition_state("SYNC_ATTACK") called, trauma = 0.8
  - Edge cases: sync_burst during existing SYNC_ATTACK (trauma stays at max 0.8)

- **AC-2.3**: SYNC_ATTACK hold timer = 0.5s
  - Given: CameraController in SYNC_ATTACK (from sync_burst_triggered)
  - When: 0.5s passes
  - Then: state returns to NORMAL
  - Edge cases: New sync_burst at 0.4s (reset hold timer, stay in SYNC_ATTACK)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/camera/sync_attack_camera_test.gd` OR playtest doc

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003
- Unlocks: None
