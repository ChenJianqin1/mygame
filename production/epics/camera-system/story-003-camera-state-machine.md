# Story 003: 7-State Camera State Machine + Priority

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-008, TR-camera-009, TR-camera-010, TR-camera-011
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: 7 camera states (NORMAL/PLAYER_ATTACK/SYNC_ATTACK/BOSS_FOCUS/BOSS_PHASE_CHANGE/CRISIS/COMBAT_ZOOM) with hardcoded priority order. State transitions are instantaneous; zoom/speed/easing handled separately.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: State machine logic is pure GDScript — no engine API concerns.

**Control Manifest Rules (this layer)**:
- Required: 7 states per ADR-ARCH-007, priority: CRISIS > BOSS_PHASE_CHANGE > BOSS_FOCUS > SYNC_ATTACK > PLAYER_ATTACK > COMBAT_ZOOM > NORMAL
- Forbidden: State priority inversion
- Guardrail: No polling — all state changes driven by Events signals

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-3.1: Any player initiates attack → camera immediately enters PLAYER_ATTACK mode, zoom 0.9x, smoothing speed rises to 12.0
- [ ] AC-3.2: Attack ends — 0.3s later, camera smoothly returns to NORMAL mode
- [ ] AC-3.3: Combo Tier rises to 3+ → camera enters COMBAT_ZOOM mode, zoom 0.85x
- [ ] AC-3.4: Combo Tier drops below 3 — 0.3s内平滑返回NORMAL

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **State enum**: `NORMAL`, `PLAYER_ATTACK`, `SYNC_ATTACK`, `BOSS_FOCUS`, `BOSS_PHASE_CHANGE`, `CRISIS`, `COMBAT_ZOOM`
2. **Priority table** (higher index = higher priority):
   ```
   CRISIS (6) > BOSS_PHASE_CHANGE (5) > BOSS_FOCUS (4) > SYNC_ATTACK (3) > PLAYER_ATTACK (2) > COMBAT_ZOOM (1) > NORMAL (0)
   ```
3. **Transition logic**: `_transition_state(new_state)` — if `priority(new_state) > priority(current_state)`, override immediately; if lower, only transition if current state has elapsed hold time
4. **Hold timers**: PLAYER_ATTACK=0.3s, SYNC_ATTACK=0.5s, BOSS_FOCUS=0.5s, COMBAT_ZOOM=0.3s, BOSS_PHASE_CHANGE=1.0s
5. **State affects**:
   - Zoom target: via `_calculate_target_zoom()`
   - Smoothing speed: via `_get_target_speed_for_state()`
   - Trauma: some states add trauma on entry (BOSS_PHASE_CHANGE=0.9, CRISIS=1.0)
6. **Helper**: `get_current_state()` returns current state string

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: PLAYER_ATTACK entry trigger via Events.attack_started
- Story 005: SYNC_ATTACK entry trigger via Events.sync_burst_triggered
- Story 006: COMBAT_ZOOM entry trigger via Events.combo_tier_changed
- Story 007: BOSS_FOCUS/BOSS_PHASE_CHANGE entry triggers
- Story 008: CRISIS entry trigger via Events.player_downed

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-3.1**: Player attack → PLAYER_ATTACK state, zoom 0.9x, speed 12.0
  - Given: CameraController in NORMAL state, zoom=1.0, speed=8.0
  - When: _transition_state("PLAYER_ATTACK") called
  - Then: current_state="PLAYER_ATTACK", zoom target=0.9x, smoothing_speed=12.0
  - Edge cases: Transitioning from higher-priority state, concurrent state requests

- **AC-3.2**: Attack ends — 0.3s later returns to NORMAL
  - Given: CameraController in PLAYER_ATTACK after 0.3s
  - When: hold timer expires
  - Then: _transition_state("NORMAL"), zoom returns to calculated base zoom, speed=8.0
  - Edge cases: New attack arrives before 0.3s expires, higher-priority interrupt

- **AC-3.3/3.4**: Combo Tier 3+ → COMBAT_ZOOM, Tier <3 → NORMAL after 0.3s
  - Given: CameraController in NORMAL, combo_tier rises to 3
  - When: _transition_state("COMBAT_ZOOM")
  - Then: zoom target=0.85x, speed=10.0
  - When: combo_tier drops to 2 after 0.3s hold
  - Then: _transition_state("NORMAL")
  - Edge cases: Tier oscillates 3→2→3, interrupt by higher-priority state

- **State priority**: Higher priority state overrides lower
  - Given: CameraController in SYNC_ATTACK
  - When: player_downed triggers (CRISIS, priority 6 vs 3)
  - Then: immediately transitions to CRISIS, ignoring SYNC_ATTACK hold timer
  - Edge cases: CRISIS interrupted by BOSS_PHASE_CHANGE (5 < 6, no override)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/camera/camera_state_machine_test.gd` — must exist and pass

**Status**: Not yet created

---

## Dependencies

- Depends on: Story 001 (CameraController base)
- Unlocks: Story 004, Story 005, Story 006, Story 007, Story 008 (all integration stories)
