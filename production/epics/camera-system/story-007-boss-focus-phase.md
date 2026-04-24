# Story 007: Boss Focus + Phase Transition

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-012, TR-camera-013, TR-camera-014
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: Events.boss_attack_started triggers BOSS_FOCUS; Events.boss_phase_changed triggers BOSS_PHASE_CHANGE with trauma=0.9 and zoom=0.75x.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Events autoload must be connected in `_ready()`. Godot 4.6 Callable syntax.

**Control Manifest Rules (this layer)**:
- Required: Consumers connect signals in `_ready()` only
- Forbidden: No direct node references for cross-system communication
- Guardrail: BOSS_PHASE_CHANGE priority = 5 (below CRISIS=6), zoom=0.75x, speed=4.0 (cinematic)

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-4.1: Boss attacks (boss_attack_started) → camera enters BOSS_FOCUS mode, zoom 0.8x
- [ ] AC-4.2: Boss phase transition (HP crosses threshold) → shake 10px + zoom 0.75x + smoothing drops to 4.0 (cinematic), lasts ~1.2s
- [ ] AC-4.3: Boss at any screen position — always visible (not clipped beyond boundary)

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Signal connections**:
   - `Events.boss_attack_started.connect(_on_boss_attack_started)` in `_ready()`
   - `Events.boss_phase_changed.connect(_on_boss_phase_changed)` in `_ready()`
2. **BOSS_FOCUS handler**: `_on_boss_attack_started(attack_pattern: String)` — calls `_transition_state("BOSS_FOCUS")`, zoom=0.8x, speed=8.0
3. **BOSS_PHASE_CHANGE handler**: `_on_boss_phase_changed(new_phase: int)` — calls `_transition_state("BOSS_PHASE_CHANGE")`, sets `trauma = 0.9`, zoom=0.75x via `_apply_zoom_tween()`, speed=4.0 (cinematic)
4. **Tween zoom transition**: Use `create_tween().tween_property(self, "zoom", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)`
5. **Hold timers**: BOSS_FOCUS = 0.5s, BOSS_PHASE_CHANGE = 1.0s
6. **Boss visibility**: Boss always in frame — handled by Story 002 tracking (boss contextual bias)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: State machine (transition logic, hold timers, zoom/speed)
- Story 001: Trauma shake implementation
- Story 002: Player + boss position tracking, boss contextual bias

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-4.1**: boss_attack_started → BOSS_FOCUS state, zoom 0.8x, speed 8.0
  - Given: CameraController in NORMAL
  - When: Events.boss_attack_started.emit("BEAM") fired
  - Then: _transition_state("BOSS_FOCUS"), zoom target = 0.8x, smoothing_speed = 8.0
  - Edge cases: boss_attack_started during higher-priority state (CRISIS=6 > BOSS_FOCUS=4, no override)

- **AC-4.2**: boss_phase_changed → BOSS_PHASE_CHANGE, trauma=0.9, zoom=0.75x, speed=4.0
  - Given: CameraController in NORMAL, trauma = 0
  - When: Events.boss_phase_changed.emit(2) fired
  - Then: _transition_state("BOSS_PHASE_CHANGE"), trauma = 0.9, zoom target = 0.75x, smoothing_speed = 4.0
  - Edge cases: boss_phase_changed during CRISIS (priority 5 < 6, no override)

- **AC-4.3**: Boss always visible — boss position tracking
  - Given: Boss at position (1000, 360), players at (200, 360) and (400, 360)
  - When: Camera calculates target
  - Then: Boss is within camera frustum (no explicit test needed — validated by Story 002)
  - Edge cases: Boss at extreme screen edge

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/camera/boss_focus_phase_test.gd` OR playtest doc

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003
- Unlocks: None
