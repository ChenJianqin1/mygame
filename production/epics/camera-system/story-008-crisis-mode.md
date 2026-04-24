# Story 008: Crisis Mode (Player Downed)

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-015, TR-camera-016, TR-camera-017
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Events.player_downed triggers CRISIS state; pauses camera limit constraints so downed player visible at arena edge; Events.player_rescued resumes limits after 0.5s delay.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Events autoload must be connected in `_ready()`. Limit manipulation via Camera2D.limit_* properties.

**Control Manifest Rules (this layer)**:
- Required: Consumers connect signals in `_ready()` only
- Forbidden: No direct node references for cross-system communication
- Guardrail: CRISIS priority = 6 (highest), limit pause via `_pause_limits()` / `_resume_limits()`

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-5.1: Any player downed → camera immediately enters CRISIS mode, smoothing speed rises to 20.0 (near-instant follow)
- [ ] AC-5.2: Downed player at arena edge — camera boundary constraints pause, downed player remains visible
- [ ] AC-5.3: Player rescued — 0.5s later, smoothly returns to NORMAL, boundary constraints restore

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Signal connections**:
   - `Events.player_downed.connect(_on_player_downed)` in `_ready()`
   - `Events.player_rescued.connect(_on_player_rescued)` in `_ready()`
2. **CRISIS handler**: `_on_player_downed(player_id: int)` — calls `_transition_state("CRISIS")`, `trauma = 1.0` (max), `_pause_limits()`, smoothing_speed = 20.0
3. **CRISIS zoom**: 0.9x (handled by state machine)
4. **_pause_limits()**: Sets `limit_left = -99999`, `limit_right = 99999`, `limit_top = -99999`, `limit_bottom = 99999`
5. **RESCUE handler**: `_on_player_rescued(player_id: int, rescuer_color: Color)` — calls `_resume_limits()`, waits 0.5s via `await get_tree().create_timer(0.5).timeout`, then `_transition_state("NORMAL")`
6. **_resume_limits()**: Gets arena bounds from `_get_current_arena()` and restores limits with BUFFER_MARGIN=50px

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: State machine (transition logic, hold timers, zoom/speed)
- Story 001: Trauma shake implementation
- Story 002: Player position tracking
- Arena bounds retrieval: `_get_current_arena()` stub (to be connected to ArenaManager later)

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-5.1**: player_downed → CRISIS state, trauma=1.0, speed=20.0
  - Given: CameraController in NORMAL, trauma=0
  - When: Events.player_downed.emit(1) fired
  - Then: _transition_state("CRISIS"), trauma=1.0, smoothing_speed=20.0
  - Edge cases: player_downed during existing CRISIS (no change), during BOSS_PHASE_CHANGE (CRISIS overrides)

- **AC-5.2**: CRISIS → limit constraints pause
  - Given: CameraController in NORMAL, limits set to arena (e.g., left=0, right=1280)
  - When: Events.player_downed.emit(1) fired
  - Then: limits set to -99999/99999/-99999/99999 (pause)
  - Edge cases: Limits already paused (re-pause is no-op)

- **AC-5.3**: player_rescued → 0.5s delay, resume limits, return to NORMAL
  - Given: CameraController in CRISIS, limits paused
  - When: Events.player_rescued.emit(1, Color.ORANGE) fired
  - Then: limits restored to arena bounds, after 0.5s _transition_state("NORMAL")
  - Edge cases: player_downed again before 0.5s expires (cancel NORMAL transition, stay in CRISIS)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/camera/crisis_mode_test.gd` OR playtest doc

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003
- Unlocks: None
