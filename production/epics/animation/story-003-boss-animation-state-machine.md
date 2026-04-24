# Story 003: Boss Animation State Machine

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 3 days

---

## Context

**GDD**: `design/gdd/boss-ai-system.md`, `design/gdd/animation-system.md`
**Requirement**: `TR-anim-005`, `TR-anim-008` — Boss phase transition animations; Boss animation states

**ADR Governing Implementation**: ADR-ARCH-010: Animation System, ADR-ARCH-006: Boss AI System
**ADR Decision Summary**: Boss动画状态机支持3个相位；僵硬感主要由VFX实现非关键帧；相位转换60帧，DEFEAT 90帧

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Boss animation uses same AnimationTree pattern as player

---

## Acceptance Criteria

From GDD AC-4:

- [ ] **AC-4.1**: Boss从Phase 1→2（HP穿越60%）→ BOSS_PHASE_TRANSITION播放60帧 → 进入Phase 2状态机
- [ ] **AC-4.2**: Boss进入Phase 2后，idle动画帧率加快（20帧 vs 24帧），VFX增加垂直抖动
- [ ] **AC-4.3**: Boss进入Phase 3（HP穿越30%）→ idle动画帧率继续加快（16帧），全身颤抖明显
- [ ] **AC-4.4**: Boss HP归零 → BOSS_DEFEAT播放90帧 → 便签爆炸粒子主导视觉效果

**Boss States by Phase**:

| Phase | HP Range | States |
|-------|----------|--------|
| Phase 1 | 100%-60% | BOSS_IDLE, BOSS_ATTACK_A, BOSS_ATTACK_B, BOSS_VULNERABLE |
| Phase 2 | 60%-30% | +BOSS_RAGE_ATTACK, BOSS_PHASE_TRANSITION |
| Phase 3 | 30%-0% | +BOSS_CRISIS_MODE |

**Boss Stiffness Progression (GDD Section 2.2.1)**:

| Phase | anticipation | Visual特征 | Attack Interval |
|-------|------------|------------|----------------|
| Phase 1 | 24-30帧 | 有节制的纸张沙沙声 | 2.5s基准 |
| Phase 2 | 18-24帧 | 轻微垂直抖动 | 2.0s基准 |
| Phase 3 | 12-18帧 | 全身颤抖，急促 | 1.5s基准 |

---

## Implementation Notes

1. **Boss AnimationTree Structure**:
   ```
   BlendTree
   ├── BossIdle (blend by phase: phase1_idle, phase2_idle, phase3_idle)
   ├── BossAttackA
   ├── BossAttackB
   ├── BossVulnerable
   ├── BossRageAttack
   ├── BossPhaseTransition
   ├── BossCrisis
   └── BossDefeat
   ```

2. **Phase Transition Animation**:
   - Trigger: `boss_phase_changed(new_phase)` signal from BossAI
   - Play BOSS_PHASE_TRANSITION (60 frames, 1.0s)
   - After transition: switch to new phase's idle animation

3. **BossVulnerable Rule**:
   - BOSS_VULNERABLE not entered during active attack
   - Player hit registered → attack animation completes → then VULNERABLE
   - From GDD Edge Case E-8

4. **Defeat Sequence**:
   - Trigger: `boss_hp_changed(0, max)` signal
   - Play BOSS_DEFEAT (90 frames, 1.5s)
   - Particle system takes over visual (paper explosion)
   - AnimationTree set to BOSS_DEFEAT and plays to completion

---

## Out of Scope

- Boss AI decision logic (boss-ai epic)
- Boss attack hitbox detection (collision-detection epic)
- VFX for phase transitions (particle-vfx epic)
- Paper explosion on defeat (Story 005)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_phase1_to_phase2_transition**: Given Boss at 60% HP, when phase changes → then BOSS_PHASE_TRANSITION plays for 60 frames, then phase2 idle (20 frames)
- **test_phase2_to_phase3_transition**: Given Boss at 30% HP, when phase changes → then BOSS_PHASE_TRANSITION plays, then phase3 idle (16 frames)
- **test_boss_idle_phase_frames**: Given Boss in phase1 idle → then idle animation is 24 frames; phase2 → 20 frames; phase3 → 16 frames
- **test_boss_vulnerable_after_attack**: Given Boss in BOSS_ATTACK_A and player hits → then Boss completes attack animation before entering VULNERABLE
- **test_boss_defeat_sequence**: Given Boss HP=0, when → then BOSS_DEFEAT plays for 90 frames

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/boss_animation_state_machine_test.gd` — must exist and pass

---

## Dependencies

- Depends on: BossAI signals (boss_phase_changed, boss_hp_changed, boss_state_changed)
- Unlocks: Integration with boss-ai epic

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
