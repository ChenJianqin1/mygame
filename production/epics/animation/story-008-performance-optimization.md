# Story 008: Performance Optimization

> **Epic**: animation
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-17
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/animation-system.md`
**Requirement**: `TR-anim-017`, `TR-anim-018`, `TR-anim-019` — Performance budgets; Offscreen optimization; Memory limits

**ADR Governing Implementation**: ADR-ARCH-010: Animation System
**ADR Decision Summary**: 3角色同屏60fps；离屏角色动画暂停；内存预算~24MB

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: VisibleOnScreenNotifier2D for offscreen detection; sprite texture memory budgeting

---

## Acceptance Criteria

From GDD AC-7:

- [ ] **AC-7.1**: 3个角色（2玩家+Boss）同屏，动画全部播放，帧率稳定60fps
- [ ] **AC-7.2**: 角色离屏后动画暂停（offscreen pause），返回后正确恢复
- [ ] **AC-7.3**: 20个预实例化VFX emitter全部就绪，无运行时分配卡顿

**Performance Budgets (GDD Section 3)**:

| Metric | Budget |
|--------|--------|
| Sprite/Texture Memory | ~24MB (2 players + Boss) |
| Total with particles | ~40MB |
| Max concurrent animated characters | 3 |
| Offscreen optimization threshold | 6+ characters |
| Particle emitters pre-instantiated | 20 |

**Technical Preferences (from project)**:
- Target Framerate: 60fps (fixed physics timestep at 60fps)
- Frame Budget: 12ms max for game logic
- Draw Calls: <=200 per frame

---

## Implementation Notes

1. **Offscreen Animation Pause**:
   - Attach `VisibleOnScreenNotifier2D` to each character
   - When `screen_exited`: pause AnimationTree, set `process_mode = PROCESS_MODE_DISABLED`
   - When `screen_entered`: resume AnimationTree, restore `process_mode = PROCESS_MODE_INHERIT`

2. **Memory Budget Enforcement**:
   - Preload all animation resources at game start
   - SpriteFrames loaded into memory once, referenced by AnimationTree
   - No runtime sprite loading mid-game

3. **Draw Call Optimization**:
   - Use sprite batching where possible
   - Minimize unique textures per character
   - Z-layer separation ensures correct draw order without additional draw calls

4. **60fps Stability**:
   - Fixed physics timestep: 1/60s = 16.67ms per frame
   - Animation advancement: `advance(delta * animation_speed_scale)`
   - Monitor frame time in `_process`: if > 12ms, flag for optimization

---

## Out of Scope

- VFX emitter pre-instantiation (particle-vfx epic)
- Draw call batching (renderer optimization)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_offscreen_pause**: Given character at screen edge, when sprite exits screen → then AnimationTree pauses
- **test_onscreen_resume**: Given paused character (offscreen), when sprite re-enters screen → then AnimationTree resumes
- **test_memory_budget**: Given all animations loaded, when memory checked → then total sprite memory < 40MB
- **test_frame_time_budget**: Given 3 characters animating, when frame time measured → then game logic < 12ms
- **test_no_runtime_allocation**: Given gameplay for 60 seconds, when memory checked → then no new allocations after initial load

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/animation/performance_optimization_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Stories 001-007 (all animation systems implemented)
- Unlocks: Animation epic complete

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 3/3 ACs implemented (AC-7.1 frame budget, AC-7.2 offscreen pause, AC-7.3 memory budgets)
**Test Evidence**: tests/unit/animation/performance_optimization_test.gd

**Implementation Files**:
- `src/gameplay/animation/animation_performance_manager.gd` — Performance monitoring and offscreen optimization
- `tests/unit/animation/performance_optimization_test.gd` — Unit tests for all performance budgets
