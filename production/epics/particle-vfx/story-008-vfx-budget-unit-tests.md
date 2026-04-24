# Story 008: VFX Budget Enforcement Unit Tests

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-23
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-004`, `TR-vfx-005`, `TR-vfx-006` — 20 pre-allocated emitter pool; FIFO queue management; 300 particle / 15 emitter hard limit enforcement

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: Pool exhaustion leads to queue; queue exhaustion leads to FIFO eviction; budget enforcement via `_can_emit()` check before every emission

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-10, AC-11, AC-14, AC-15, AC-17, AC-18:

- [ ] **AC-VFX-8.1**: `test_pool_checkout_all_available`: All 20 CPU emitters can be checked out sequentially
- [ ] **AC-VFX-8.2**: `test_pool_checkout_returns_null_when_exhausted`: After 20 checkouts, next checkout returns null
- [ ] **AC-VFX-8.3**: `test_emitter_return_to_pool`: After checked-out emitter finishes, it becomes available for next checkout
- [ ] **AC-VFX-8.4**: `test_queue_fifos_order`: Events enqueued in [A, B, C] order are processed in same order
- [ ] **AC-VFX-8.5**: `test_queue_drop_oldest_when_full`: Queue at max depth 10 drops oldest when new event arrives
- [ ] **AC-VFX-8.6**: `test_budget_particle_limit_enforced`: Cannot emit when _active_particle_count would exceed 300
- [ ] **AC-VFX-8.7**: `test_budget_emitter_limit_enforced`: Cannot emit when _active_emitter_count would exceed 15
- [ ] **AC-VFX-8.8**: `test_queue_drains_on_emitter_finish`: When emitter finishes and budget allows, queued event is processed
- [ ] **AC-VFX-8.9**: `test_combo_tier_regression_force_cancel`: When tier drops from 4 to 2, tier-4 emitter force-cancelled
- [ ] **AC-VFX-8.10**: `test_sync_burst_wins_over_rescue_same_frame`: When sync_burst and rescue fire same frame at same position, rescue dropped

---

## Implementation Notes

1. **Test File Location**:
   - `tests/unit/vfx/vfx_budget_test.gd` (or split into multiple test files)
   - Follow GdUnit4 naming: `test_[scenario]_[expected]`

2. **Test Pattern for Pool Exhaustion**:
   ```gdscript
   func test_pool_checkout_all_available():
       var checked_out: Array[CPUParticles2D] = []
       for i in range(20):
           var emitter = vfx_manager._checkout_cpu_emitter()
           assert_that(emitter).is_not_null()
           checked_out.append(emitter)
       assert_that(checked_out.size()).is_equal_to(20)

   func test_pool_checkout_returns_null_when_exhausted():
       # Exhaust pool first
       for i in range(20):
           vfx_manager._checkout_cpu_emitter()
       var result = vfx_manager._checkout_cpu_emitter()
       assert_that(result).is_null()
   ```

3. **Test Pattern for Budget Enforcement**:
   ```gdscript
   func test_budget_particle_limit_enforced():
       # Simulate near-limit: 299 active particles
       vfx_manager._active_particle_count = 299
       # Try to emit LIGHT (5-8 particles)
       var can_emit = vfx_manager._can_emit(5)  # Would be 304
       assert_that(can_emit).is_false()
   ```

4. **Test Pattern for FIFO Queue**:
   ```gdscript
   func test_queue_fifos_order():
       vfx_manager._queue_emitter("hit_vfx", {"id": "A"})
       vfx_manager._queue_emitter("hit_vfx", {"id": "B"})
       vfx_manager._queue_emitter("hit_vfx", {"id": "C"})
       # Drain and verify order
       var processed: Array = []
       # Mock emit_hit to record calls
       vfx_manager.emit_hit = func(pos, type, dir, color):
           processed.append("hit_vfx")
       vfx_manager._drain_queue()
       assert_that(processed[0]).is_equal_to("hit_vfx")  # A
       assert_that(processed[1]).is_equal_to("hit_vfx")  # B
       assert_that(processed[2]).is_equal_to("hit_vfx")  # C
   ```

5. **Test Pattern for Combo Tier Regression**:
   ```gdscript
   func test_combo_tier_regression_force_cancel():
       # Start tier-4 combo emitter
       vfx_manager.emit_combo_escalation(4, COLOR_P1, Vector2.ZERO)
       # Verify tier-4 emitter active
       var tier4_active = _find_active_tier_emitter(4)
       assert_that(tier4_active).is_not_null()
       # Simulate tier regression signal
       vfx_manager._on_combo_tier_escalated(2, COLOR_P1)
       # Verify tier-4 emitter cancelled
       tier4_active = _find_active_tier_emitter(4)
       assert_that(tier4_active).is_null()
   ```

6. **Test Pattern for Sync Burst Priority**:
   ```gdscript
   func test_sync_burst_wins_over_rescue_same_frame():
       # Simulate same-frame fire
       var sync_fired = false
       var rescue_fired = false
       vfx_manager.emit_sync_burst = func(pos):
           sync_fired = true
       vfx_manager.emit_rescue = func(pos, color):
           rescue_fired = true
       # Fire both same frame
       vfx_manager._on_sync_burst_triggered(Vector2.ZERO)
       vfx_manager._on_rescue_triggered(Vector2.ZERO, COLOR_P1)
       # Sync should fire, rescue should not
       assert_that(sync_fired).is_true()
       assert_that(rescue_fired).is_false()
   ```

7. **Isolation Requirement**:
   - Each test sets up and tears down its own state
   - Use `before_each()` to reset VFXManager state
   - No test depends on execution order of other tests

8. **Coverage Requirements** (per Coding Standards):
   - Pool checkout/checkin correctness
   - FIFO eviction behavior
   - Budget enforcement (particle and emitter limits)
   - Edge cases: tier regression, same-frame events

---

## Out of Scope

- Individual emitter implementation (Stories 002-006)
- Queue implementation (Story 007)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

All acceptance criteria above are the test cases. This story IS the test file — no separate test spec needed.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/vfx/vfx_budget_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Stories 001-007 (all VFXManager functionality must exist to test)
- Unlocks: None — final story in epic

---

## Completion Notes

**Completed**: 2026-04-23
**Criteria**: 10/10 passing (AC-VFX-8.1 through AC-VFX-8.10)
**Test Evidence**: `tests/unit/vfx/vfx_budget_test.gd`
