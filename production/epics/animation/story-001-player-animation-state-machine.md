# Story 001: Player Animation State Machine Foundation

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 3 days

---

## Context

**GDD**: `design/gdd/animation-system.md`
**Requirement**: `TR-anim-001`, `TR-anim-003`, `TR-anim-004` — Hybrid animation architecture; Animation frame ratios; Player animation states

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: Hybrid AnimatedSprite2D + AnimationPlayer + AnimationTree; Frame ratios: anticipation/active/recovery = 3:1:2; AnimationTree with BlendTree for state transitions

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Godot 4.6 — AnimationTree.active deprecated in 4.3+; use AnimationMixer.active instead

---

## Acceptance Criteria

From GDD AC-1:

- [ ] **AC-1.1**: 玩家从IDLE输入LIGHT攻击 → 动画正确播放16帧（8 anticipation + 2 active + 6 recovery）→ 返回IDLE
- [ ] **AC-1.2**: 玩家在anticipation阶段受创 → 立即切换到HURT状态，攻击被取消
- [ ] **AC-1.3**: 玩家在recovery帧期间输入攻击 → 输入被忽略，动画不被打断
- [ ] **AC-1.4**: MEDIUM攻击anticipation可以被LIGHT攻击anticipation中断（8帧 vs 14帧），但MEDIUM active阶段不行
- [ ] **AC-1.5**: BOSS_ATTACK_A播放时受到玩家命中 → Boss保持在ATTACK_A状态，VULNERABLE不在攻击中进入

**Animation Frame Ratios (TR-anim-003)**:

| Attack | anticipation | active | recovery | Total |
|--------|-------------|--------|----------|-------|
| LIGHT | 8 | 2 | 6 | 16帧 |
| MEDIUM | 14 | 3 | 10 | 27帧 |
| HEAVY | 20 | 4 | 16 | 40帧 |
| SPECIAL | 28 | 6 | 24 | 58帧 |

**State Transitions**: Full transition table from GDD Section 2.1 must be implemented

---

## Implementation Notes

1. **Hybrid Architecture Setup**:
   - `AnimatedSprite2D` for sprite sheet animations (idle, walk, attack loops)
   - `AnimationPlayer` for programmatic transforms (squash/stretch, position offset)
   - `AnimationTree` with `BlendTree` for state blending and transitions

2. **Player States to Implement**:
   - IDLE, MOVE, LIGHT_ATTACK, MEDIUM_ATTACK, HEAVY_ATTACK, SPECIAL_ATTACK, HURT, RESCUE, SYNC_ATTACK, DEFEAT

3. **Attack Phase Sub-states**:
   - Each attack has: anticipation / active / recovery phases
   - Phase transitions driven by AnimationPlayer `advance()` calls

4. **AnimationBlendTree Configuration**:
   ```
   BlendTree
   ├── Idle (AnimationNodeAnimation)
   ├── Move (AnimationNodeAnimation)
   ├── LightAttack (AnimationNodeBlendSpace1D or AnimationNodeState)
   ├── MediumAttack (...)
   ├── HeavyAttack (...)
   ├── SpecialAttack (...)
   ├── Hurt (AnimationNodeAnimation)
   └── Defeat (AnimationNodeAnimation)
   ```

5. **Transition Rules**:
   - Rule A: anticipation阶段快速攻击可中断慢速攻击（8帧 interrupt 14帧）
   - Rule B: HURT中断一切（强制转换，最高优先级）
   - Rule C: 禁止自中断

---

## Out of Scope

- Hitbox activation timing (Story 002)
- Sync attack visuals (Story 004)
- Boss animation states (Story 003)
- Paper texture effects (Story 005)
- Rescue animation sequences (Story 006)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_light_attack_full_cycle**: Given P1 in IDLE, when LIGHT attack input → then animation plays 16 frames and returns to IDLE
- **test_hurt_interrupts_anticipation**: Given P1 in LIGHT anticipation, when hurt_received → then HURT state activates, attack cancelled
- **test_recovery_ignores_input**: Given P1 in LIGHT recovery, when attack input → then input ignored
- **test_light_interrupts_medium_anticipation**: Given P1 in MEDIUM anticipation (14 frames), when LIGHT input at frame 8 → then MEDIUM cancelled, LIGHT starts
- **test_no_self_interrupt**: Given P1 in LIGHT recovery, when LIGHT input → then no transition (self-interrupt forbidden)
- **test_hurt_has_highest_priority**: Given P1 in SPECIAL attack (any phase), when hurt_received → then HURT activates

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/player_state_machine_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Events Autoload (ADR-ARCH-001)
- Unlocks: Story 002 (hitbox sync), Story 004 (sync attack visuals), Story 006 (rescue)

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
