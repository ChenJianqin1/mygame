# Story 007: Signal Integration

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/animation-system.md`
**Requirement**: `TR-anim-016` — Signal contract compliance

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: 动画系统作为信号消费者和生产者；所有信号使用Godot 4.6 Callable语法

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot 4.6 Callable syntax: `signal.connect(_handler)` without second argument

---

## Acceptance Criteria

From GDD AC-8:

- [ ] **AC-8.1**: 动画系统正确订阅并响应所有上游信号（attack_started, attack_hit, hurt_received, sync_burst_triggered, combo_tier_escalated, player_downed, rescue_triggered, player_rescued, player_out, boss_phase_changed）
- [ ] **AC-8.1b**: `attack_ended` 信号是否存在？如不存在，从 AC-8.1 中移除并确认 animation-system 不依赖此信号
- [ ] **AC-8.2**: 动画系统正确发射2个下游信号（animation_state_changed, recovery_complete）
- [ ] **AC-8.3**: 所有信号连接使用Godot 4.6 Callable语法（无废弃API警告）

**Consumed Signals (Upstream)**:

| Signal | Source | Handler |
|--------|--------|---------|
| attack_started(attack_type, player_id) | CombatSystem | _on_attack_started |
| hurt_received(player_id) | CombatSystem | _on_hurt_received |
| sync_window_opened(player_id, partner_id) | ComboSystem | _on_sync_window |
| sync_burst_triggered(position) | ComboSystem | _on_sync_burst |
| combo_tier_escalated(tier, player_color) | ComboSystem | _on_combo_tier |
| player_downed(player_id) | CoopSystem | _on_player_downed |
| rescue_triggered(rescuer_id, downed_id) | CoopSystem | _on_rescue_triggered |
| player_rescued(player_id, rescuer_color) | CoopSystem | _on_player_rescued |
| player_out(player_id) | CoopSystem | _on_player_out |
| boss_phase_changed(new_phase) | BossAI | _on_boss_phase_changed |

**Emitted Signals (Downstream)**:

| Signal | Payload | Consumer |
|--------|---------|----------|
| animation_state_changed(player_id, state) | int, String | CombatSystem |
| recovery_complete(player_id) | int | CombatSystem |
| hitbox_activated(attack_type, position) | String, Vector2 | VFXSystem |
| sync_burst_visual(position) | Vector2 | VFXSystem |

---

## Implementation Notes

1. **Signal Connection Setup**:
   ```gdscript
   func _ready() -> void:
       CombatSystem.connect("attack_started", _on_attack_started)
       CombatSystem.connect("hurt_received", _on_hurt_received)
       ComboSystem.connect("sync_burst_triggered", _on_sync_burst)
       # ... etc

   func _on_attack_started(attack_type: String, player_id: int) -> void:
       # Trigger animation state transition
   ```

2. **Signal Emission**:
   ```gdscript
   func _on_hitbox_active_frame(attack_type: String) -> void:
       animation_state_changed.emit(player_id, current_state)
       hitbox_activated.emit(attack_type, global_position)
   ```

3. **Open Question O-1 Resolution**:
   - UI interface: Use signal subscription (Option B) — AnimationSystem emits, UISystem subscribes
   - Keep loose coupling

---

## Out of Scope

- Individual signal handler logic (other stories cover each)
- UI subscription implementation (ui epic)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_animation_subscribes_to_upstream_signals**: Given AnimationSystem ready, when → then all 10 upstream signals are connected
- **test_animation_emits_downstream_signals**: Given animation triggers state change, when → then animation_state_changed emits with correct payload
- **test_godot_46_callable_syntax**: Given signal connections, when → then no deprecation warnings in Godot 4.6
- **test_signal_handler_signature**: Given each signal, when received → then handler processes without error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/signal_integration_test.gd` — must exist and pass

---

## Dependencies

- Depends on: All other animation stories (integrates all signals)
- Unlocks: Full system integration complete

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
