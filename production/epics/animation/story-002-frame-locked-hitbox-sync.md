# Story 002: Frame-Locked Hitbox Synchronization

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 2 days

---

## Context

**GDD**: `design/gdd/animation-system.md`
**Requirement**: `TR-anim-002` — Frame-locked hitbox activation via AnimationPlayer keyframe callbacks

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: Hitbox activation时机是动画轨道上的关键帧，不是计时器。动画师在"active"阶段的第一帧设置关键帧值，战斗系统读取该值来决定是否触发伤害。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: AnimationPlayer.call_on_frame() method for keyframe callbacks

---

## Acceptance Criteria

From GDD AC-2:

- [ ] **AC-2.1**: LIGHT攻击的hitbox只在帧8-9（active帧）激活，帧10+关闭
- [ ] **AC-2.2**: HEAVY攻击的hitbox只在帧20-23（active帧）激活，帧24+关闭
- [ ] **AC-2.3**: 帧跳帧（lag）期间，hitbox激活时机与视觉动画帧同步延迟，不出现"视觉未到但伤害已触发"

**Hitbox Activation Formulas (GDD Section D.2)**:
```
hitbox_first_active_frame(attack_type) = anticipation_frames(attack_type)
hitbox_last_active_frame(attack_type) = anticipation_frames(attack_type) + active_frames(attack_type) - 1
```

**Verification Examples**:
- LIGHT: first=8, last=8+2-1=9 ✓
- HEAVY: first=20, last=20+4-1=23 ✓

---

## Implementation Notes

1. **AnimationPlayer Keyframe Callbacks**:
   - Use `AnimationPlayer.call_on_frame()` to trigger hitbox activation
   - Keyframe at frame N sets `hitbox_active = true`
   - Keyframe at frame N+active_frames-1 sets `hitbox_active = false`

2. **Hitbox State Signal**:
   ```gdscript
   signal hitbox_activated(attack_type: String, position: Vector2)
   signal hitbox_deactivated()
   ```

3. **Frame-Locked Principle**:
   - Hitbox activation tied to animation `advance(frame)` calls
   - If animation delays, hitbox activation delays proportionally
   - No separate timer for hitbox — always sync with visual

4. **Integration with CombatSystem**:
   - CombatSystem subscribes to `hitbox_activated` signal
   - On activation: check collision with hurtboxes, apply damage
   - Hitbox position read from AnimationPlayer track at activation frame

---

## Out of Scope

- Player animation state machine (Story 001)
- Collision detection itself (collision-detection epic)
- Sync attack hitbox expansion (Story 004)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_light_hitbox_active_frames**: Given LIGHT attack, when animation advances to frame 8 → then hitbox_activated emits; when advances to frame 9 → then hitbox still active; when advances to frame 10 → then hitbox_deactivated
- **test_heavy_hitbox_active_frames**: Given HEAVY attack, when animation advances to frame 20 → then hitbox_activated; when advances to frame 23 → then hitbox still active; when advances to frame 24 → then hitbox_deactivated
- **test_hitbox_sync_with_animation**: Given lag spike causing 3-frame delay, when animation advances → then hitbox activation also delays by 3 frames
- **test_hitbox_position_matches_animation**: Given attack at frame 8, when hitbox_activated → then position matches Sprite2D transform at frame 8

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/frame_locked_hitbox_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Story 001 (player animation foundation), CombatSystem signals
- Unlocks: Story 004 (sync attack hitbox expansion)

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
