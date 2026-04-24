# Story 006: Rescue Animation Sequence

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/animation-system.md`, `design/gdd/coop-system.md`
**Requirement**: `TR-anim-014`, `TR-anim-015` — Rescue animations; Downtime/revive sequences

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: 倒地玩家播放downtime_loop；救援者播放RESCUE_APPROACH→EXECUTE→REVIVE；救援后1.5s无敌帧

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Animation blend tree for rescue states; timer for downtime_loop duration

---

## Acceptance Criteria

From GDD AC-5:

- [ ] **AC-5.1**: P1倒地 → downtime_loop播放，180帧（3.0s）后P1自动OUT
- [ ] **AC-5.2**: P2在P1倒地后进入RESCUE_RANGE（175px内）并按下救援 → RESCUE_EXECUTE（12帧）→ RESCUE_REVIVE（18帧）→ P1起身
- [ ] **AC-5.3**: P2在RESCUE_APPROACH途中受创 → RESCUE取消，P2进入HURT，P1继续downtime_loop，计时器不暂停
- [ ] **AC-5.4**: P2在t=2.5s后开始救援 → 500ms动画序列在RESCUE_WINDOW=3.0s内完成，P1被救起
- [ ] **AC-5.5**: 救援成功后P1显示rescued_invincible动画（90帧，柔和脉冲光晕），期间完全减伤

**Rescue Animation Timings (GDD Section D.6)**:

| Phase | Duration | Frames |
|-------|----------|--------|
| RESCUE_EXECUTE | 200ms | 12帧 |
| RESCUE_REVIVE | 300ms | 18帧 |
| RESCUE_TOTAL | 500ms | 30帧 |
| downtime_loop | 3.0s | 180帧 (loops) |
| rescued_iframes | 1.5s | 90帧 |

**Constraint**: P2 must start RESCUE_APPROACH by t=2.5s to complete rescue before downtime expires

---

## Implementation Notes

1. **Downtime Loop**:
   - Triggered by `player_downed(player_id)` signal
   - Animation: player flat, paper flutter, desaturated color
   - Loops until rescue or OUT signal
   - Timer: 180 frames = 3.0s at 60fps

2. **Rescue Sequence**:
   - Triggered by `rescue_triggered(rescuer_id, downed_id)` signal
   - RESCUE_APPROACH: Move toward downed player until within RESCUE_RANGE (175px)
   - RESCUE_EXECUTE (12 frames): Arm extended, glow at 100%
   - RESCUE_REVIVE (18 frames): Pull up downed player, paper spark particles

3. **Rescued Iframes**:
   - Triggered by `player_rescued(player_id)` signal
   - rescued_invincible animation: soft pulsing glow, color saturation 70%
   - Duration: 90 frames (1.5s)
   - All damage reduced to 0 during this period

4. **Edge Case: Rescuer Hurt**:
   - If HURT received during RESCUE_APPROACH: cancel rescue, continue downtime timer
   - AnimationSystem does not pause rescue_window timer — CoopSystem manages timing

---

## Out of Scope

- Rescue range detection (coop epic)
- Iframe damage reduction logic (coop epic)
- Timer management (CoopSystem)

---

## QA Test Cases

**Integration Test Specs (Integration story)**:

- **test_downtime_loop_duration**: Given player_downed signal, when → then downtime_loop plays for 180 frames then player_out signal fires
- **test_rescue_sequence_timing**: Given P2 in range and rescue input at t=2.5s, when → then rescue completes (12+18=30 frames) before downtime expires
- **test_rescuer_hurt_cancels_rescue**: Given P2 in RESCUE_APPROACH, when hurt_received → then rescue cancelled, P2 enters HURT
- **test_rescued_iframes**: Given player_rescued signal, when → then rescued_invincible plays for 90 frames with pulsing glow
- **test_rescue_timing_constraint**: Given P2 starts rescue at t=2.95s, when → then rescue fails (3.0s window closes)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test `tests/integration/animation/rescue_animation_test.gd` OR documented playtest

---

## Dependencies

- Depends on: CoopSystem signals (player_downed, rescue_triggered, player_rescued, player_out)
- Unlocks: Full integration with coop epic

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
