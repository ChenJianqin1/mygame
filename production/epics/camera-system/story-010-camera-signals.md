# Story 010: Camera Signal Contracts (Events Integration)

> **Epic**: 摄像机系统
> **Status**: Done
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-17

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: TR-camera-008 (partial — signal contract verification)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-ARCH-007: Camera System
**ADR Decision Summary**: CameraController subscribes to 8 upstream Events signals and emits 3 downstream Events signals. All signal routing via Events autoload (not direct node references).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Events autoload must be connected in `_ready()`. Godot 4.6 Callable syntax: `Events.signal_name.connect(method_name)`.

**Control Manifest Rules (this layer)**:
- Required: All cross-system signals via Events autoload; consumers connect in `_ready()`
- Forbidden: No direct node references for cross-system communication
- Guardrail: Signal subscription/emmision correctness

---

## Acceptance Criteria

*From GDD `design/gdd/camera-system.md`, scoped to this story:*

- [ ] AC-8.1: Camera correctly subscribes to all 8 upstream signals (attack_started, hit_confirmed, combo_tier_changed, sync_burst_triggered, boss_attack_started, boss_phase_changed, player_downed, player_rescued)
- [ ] AC-8.2: Camera correctly emits 3 downstream signals (camera_shake_intensity, camera_zoom_changed, camera_framed_players)
- [ ] AC-8.3: All signals use Godot 4.6 Callable syntax

---

## Implementation Notes

*Derived from ADR-ARCH-007 Implementation Guidelines:*

1. **Upstream signal subscriptions** (connect in `_ready()`):
   - `Events.attack_started.connect(_on_attack_started)`
   - `Events.hit_confirmed.connect(_on_hit_confirmed)`
   - `Events.combo_tier_changed.connect(_on_combo_tier_changed)`
   - `Events.sync_burst_triggered.connect(_on_sync_burst_triggered)`
   - `Events.boss_attack_started.connect(_on_boss_attack_started)`
   - `Events.boss_phase_changed.connect(_on_boss_phase_changed)`
   - `Events.player_downed.connect(_on_player_downed)`
   - `Events.player_rescued.connect(_on_player_rescued)`

2. **Downstream signal emissions**:
   - `Events.camera_shake_intensity.emit(trauma)` — every frame when trauma > 0
   - `Events.camera_zoom_changed.emit(_current_zoom)` — when zoom changes
   - `Events.camera_framed_players.emit([P1_pos, P2_pos])` — every frame with player positions

3. **Signal data types** (per ADR-ARCH-007 signal routing table):
   - `attack_started(attack_type: String)`
   - `hit_confirmed(hitbox_id: int, hurtbox_id: int, attack_id: int)`
   - `combo_tier_changed(tier: int, player_id: int)`
   - `sync_burst_triggered(position: Vector2)`
   - `boss_attack_started(attack_pattern: String)`
   - `boss_phase_changed(new_phase: int)`
   - `player_downed(player_id: int)`
   - `player_rescued(player_id: int, rescuer_color: Color)`

4. **Verification approach**: This story tests that all 8 handlers are registered and that the 3 emit calls fire correctly. Handler logic tested in Stories 004-008.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 004-008: Individual signal handler logic (attack response, combo tier, boss focus, crisis)
- Story 001: Trauma calculation for camera_shake_intensity emit
- Story 002: Player position retrieval for camera_framed_players emit

---

## QA Test Cases

**[For Logic / Integration stories — automated test specs]:**

- **AC-8.1**: All 8 upstream signals subscribed
  - Given: CameraController._ready() completed
  - When: Each Events signal is emitted (simulated)
  - Then: Respective handler is called
  - Edge cases: Signal emitted before _ready() (should not connect), duplicate emissions

- **AC-8.2**: 3 downstream signals emit correctly
  - Given: CameraController with known state
  - When: State changes trigger emission (e.g., zoom changes, trauma changes)
  - Then: Events.camera_shake_intensity, camera_zoom_changed, camera_framed_players emit with correct data
  - Edge cases: Signals fire every frame vs on-change only

- **AC-8.3**: Godot 4.6 Callable syntax
  - Given: GDScript source
  - When: Compiled in Godot 4.6
  - Then: No syntax errors, signal.connect() accepts Callable
  - Edge cases: Lambda vs method reference

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/camera/signal_contracts_test.gd` OR playtest doc

**Status**: Not yet created

---

## Dependencies

- Depends on: Stories 001-008 (all signal handlers must exist before verifying contracts)
- Unlocks: None (final integration story)
