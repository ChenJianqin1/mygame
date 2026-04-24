# Story 004: Player Attack Zoom Response

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Events.attack_started signal triggers PLAYER_ATTACK state entry; attack type determines trauma amount via `_add_trauma_for_attack()`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Events autoload must be connected in `_ready()`. Godot 4.6 Callable syntax required.

**Control Manifest Rules (this layer)**:
- Required: Consumers connect signals in `_ready()` only
- Forbidden: No direct node references for cross-system communication
- Guardrail: Trauma values per ADR-ARCH-007 trauma table

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-3.1: Any player initiates attack → camera immediately enters PLAYER_ATTACK mode, zoom 0.9x, smoothing speed rises to 12.0
- [ ] AC-3.2: Attack ends — 0.3s later, camera smoothly returns to NORMAL mode

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Signal connection**: `Events.attack_started.connect(_on_attack_started)` in `_ready()`
2. **Handler**: `_on_attack_started(attack_type: String)` — calls `_transition_state("PLAYER_ATTACK")`, then `_add_trauma_for_attack(attack_type)`
3. **Trauma values by attack type**:
   - LIGHT: 0.15
   - MEDIUM: 0.25
   - HEAVY: 0.4
   - SPECIAL: 0.6
4. **Zoom/speed**: Handled by state machine (Story 003) — this story only wires the signal and adds trauma
5. **State return**: Handled by state machine hold timer (0.3s PLAYER_ATTACK hold)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: State machine implementation (transition logic, hold timers, zoom/speed changes)
- Story 001: Trauma shake implementation (shake calculation and offset application)
- Story 002: Player position tracking

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-3.1**: attack_started(LIGHT) → PLAYER_ATTACK + trauma 0.15
  - Given: CameraController in NORMAL state
  - When: Events.attack_started.emit("LIGHT") fired
  - Then: _on_attack_started called, _transition_state("PLAYER_ATTACK") called, trauma = 0.15
  - Edge cases: attack_started during existing PLAYER_ATTACK (should not reset hold timer)

- **AC-3.1**: attack_started(HEAVY) → PLAYER_ATTACK + trauma 0.4
  - Given: CameraController in NORMAL state
  - When: Events.attack_started.emit("HEAVY") fired
  - Then: trauma = 0.4
  - Edge cases: attack_started during higher-priority state (CRISIS) — should not override

- **AC-3.2**: Attack state auto-returns to NORMAL after 0.3s
  - Given: CameraController in PLAYER_ATTACK (triggered via attack_started)
  - When: 0.3s passes with no new attacks
  - Then: state returns to NORMAL (tested via Story 003 state machine)
  - Edge cases: New attack at 0.25s (reset hold timer, stay in PLAYER_ATTACK)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/camera/player_attack_zoom_test.gd` OR playtest doc

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003 (foundation + state machine)
- Unlocks: None (terminal story for this feature)
