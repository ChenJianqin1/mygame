# Story 004: Sync Attack Visual System

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/animation-system.md`, `design/gdd/combo-system.md`
**Requirement**: `TR-anim-010`, `TR-anim-011` — Sync attack animations; Sync burst visual effects

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: SYNC_ATTACK是视觉包装器不是独立状态机；同步爆发时双色粒子螺旋射出；P2蓄力光晕

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CanvasLayer for screen-edge effects; ParticleSystem for sync burst

---

## Acceptance Criteria

From GDD AC-3:

- [ ] **AC-3.1**: P1和P2在5帧窗口内各自命中 → 同步爆发触发，双色粒子螺旋射出（橙色#F5A623 + 蓝色#4ECDC4）
- [ ] **AC-3.2**: P1命中时P2处于anticipation → P2显示"同步蓄力"光晕（淡→强），P2在5帧内命中则爆发，未命中则光晕消散
- [ ] **AC-3.3**: 同步攻击时攻击hitbox半径×1.15（+15%）

**Sync Attack Parameters (GDD Section D.4, D.7)**:

| Parameter | Value |
|-----------|-------|
| SYNC_WINDOW_DURATION | 5帧 ≈ 83ms |
| sync_glow_radius_multiplier | 1.15 |
| sync_particle_count | 12 |
| sync_charge_blend_rate | 0.2/帧 |
| screen_edge_pulse_frequency | 2Hz |

**Sync Charge Blend Formula**:
```
sync_charge_blend(P2) = clamp((P1_hit_time - P2_anticipation_start_time) / SYNC_WINDOW_DURATION, 0.0, 1.0)
```

---

## Implementation Notes

1. **Sync Charge Glow (P2 in anticipation when P1 hits)**:
   - When `sync_window_opened` signal received
   - Apply glow shader to P2 sprite: alpha = sync_charge_blend * 0.8
   - Glow color: gradient from P2 color to white as blend increases

2. **Sync Burst Trigger**:
   - When `sync_burst_triggered(position)` signal received
   - Emit 12 particles alternating #F5A623 and #4ECDC4
   - Particle motion: spiral outward from hit position
   - Screen edge pulse: CanvasLayer with ColorRect, 2Hz toggle

3. **Hitbox Expansion**:
   - When sync burst triggered, call `CombatSystem.set_hitbox_radius_multiplier(1.15)`
   - Duration: until attack recovery complete

4. **Visual Wrapper Model**:
   - SYNC_ATTACK not a separate state
   - Visual layer applied on top of existing LIGHT/MEDIUM/HEavy/SPECIAL states
   - Both players retain their attack substates

---

## Out of Scope

- ComboSystem sync detection logic (combo epic)
- Hitbox radius change implementation (combat epic)
- Particle emission (particle-vfx epic) — just triggers emitter

---

## QA Test Cases

**Integration Test Specs (Integration story)**:

- **test_sync_burst_particles**: Given P1 and P2 hit within 5 frames, when sync_burst_triggered → then 12 particles spawn alternating orange and blue
- **test_sync_charge_glow_p2**: Given P1 hits while P2 is in anticipation, when → then P2 glow intensity increases over 5 frames from 0 to max
- **test_sync_charge_fade**: Given P1 hits while P2 in anticipation and P2 misses 5-frame window, when window expires → then glow fades to 0
- **test_sync_hitbox_expansion**: Given sync attack, when → then hitbox radius multiplied by 1.15
- **test_screen_edge_pulse**: Given sync burst, when → then screen edges pulse orange/blue alternating at 2Hz for 500ms

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test `tests/integration/animation/sync_attack_visual_test.gd` OR documented playtest

---

## Dependencies

- Depends on: Story 001 (player states), ComboSystem (sync_burst_triggered, sync_window_opened)
- Unlocks: Integration with combo epic

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
