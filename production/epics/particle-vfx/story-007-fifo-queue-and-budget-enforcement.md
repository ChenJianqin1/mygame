# Story 007: FIFO Queue and Budget Enforcement

> **Epic**: particle-vfx
> **Status**: Done
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-23
> **Est**: 1 day

---

## Context

**GDD**: `design/gdd/particle-vfx-system.md`
**Requirement**: `TR-vfx-005`, `TR-vfx-006` — FIFO queue management; 300 particle / 15 emitter hard limit

**ADR Governing Implementation**: ADR-ARCH-008: VFX System
**ADR Decision Summary**: When `_can_emit()` returns false, events are queued (FIFO, max depth 10); queue full时 oldest event dropped; `_drain_queue()` called when emitter finishes

**Engine**: Godot 4.6 | **Risk**: LOW

---

## Acceptance Criteria

From GDD AC-10, AC-11, AC-14, AC-15:

- [ ] **AC-VFX-7.1**: `_can_emit(particle_count)` returns true only if `(_active_particle_count + particle_count < MAX_PARTICLES) AND (_active_emitter_count < MAX_EMITTERS)`
- [ ] **AC-VFX-7.2**: When `_can_emit()` returns false for a new event, event is enqueued via `_queue_emitter()`
- [ ] **AC-VFX-7.3**: `_queue_emitter(type, params)` appends to `_emitter_queue` Array
- [ ] **AC-VFX-7.4**: When queue depth reaches MAX_QUEUE_DEPTH (10), oldest entry is silently dropped (FIFO eviction)
- [ ] **AC-VFX-7.5**: `_drain_queue()` is called from `_on_emitter_finished()` when an emitter completes
- [ ] **AC-VFX-7.6**: `_drain_queue()` processes queue in FIFO order, calling `_process_queued()` for each entry
- [ ] **AC-VFX-7.7**: `_process_queued(entry)` calls the correct emit function based on `entry.type`
- [ ] **AC-VFX-7.8**: Queue is Array[Dictionary] with keys: `type` (String), `params` (Dictionary)

---

## Implementation Notes

1. **Queue Data Structure**:
   ```gdscript
   var _emitter_queue: Array[Dictionary] = []

   const MAX_QUEUE_DEPTH := 10
   const MAX_PARTICLES := 300
   const MAX_EMITTERS := 15
   ```

2. **Budget Check**:
   ```gdscript
   func _can_emit(particle_count: int) -> bool:
       return (_active_particle_count + particle_count < MAX_PARTICLES) \
           and (_active_emitter_count < MAX_EMITTERS)
   ```

3. **Queue with FIFO Eviction**:
   ```gdscript
   func _queue_emitter(type: String, params: Dictionary) -> void:
       if _emitter_queue.size() >= MAX_QUEUE_DEPTH:
           _emitter_queue.pop_front()  # FIFO eviction — drop oldest
       _emitter_queue.append({"type": type, "params": params})
   ```

4. **Drain Queue on Emitter Finish**:
   ```gdscript
   func _drain_queue() -> void:
       while _emitter_queue.size() > 0 and _can_emit(50):  # 50 = estimated avg particle count
           var entry: Dictionary = _emitter_queue.pop_front()
           _process_queued(entry)
   ```

5. **Process Queued Entry**:
   ```gdscript
   func _process_queued(entry: Dictionary) -> void:
       match entry.type:
           "hit_vfx":
               var p: Dictionary = entry.params
               emit_hit(p.position, p.attack_type, p.direction, p.player_color)
           "combo_escalation_vfx":
               var p: Dictionary = entry.params
               emit_combo_escalation(p.tier, p.player_color, p.position)
           # Other types as needed
   ```

6. **Integration with Emit Functions**:
   - Each emit function (emit_hit, emit_combo_escalation, etc.) calls `_queue_emitter()` when `_can_emit()` returns false
   - Example from emit_hit:
   ```gdscript
   func emit_hit(position: Vector2, attack_type: String, direction: Vector2, player_color: Color) -> void:
       var count := _get_particle_count(attack_type)
       if not _can_emit(count):
           _queue_emitter("hit_vfx", {
               "position": position,
               "attack_type": attack_type,
               "direction": direction,
               "player_color": player_color
           })
           return
       # ... proceed with emission
   ```

7. **Queue Processing During Budget Recovery**:
   - When an emitter finishes, `_active_particle_count` and `_active_emitter_count` are decremented
   - `_drain_queue()` is called to process waiting events
   - Queue drains until: queue empty OR budget insufficient for estimated next event

---

## Out of Scope

- Individual emitter implementations (Stories 002-006)
- Unit tests for queue behavior (Story 008)

---

## QA Test Cases

**Unit Test Specs (Logic story)**:

- **test_can_emit_within_budget**: Given _active_particle_count=100, _active_emitter_count=5, when _can_emit(50) called → then returns true
- **test_can_emit_false_when_over_particles**: Given _active_particle_count=280, _active_emitter_count=5, when _can_emit(30) called → then returns false
- **test_can_emit_false_when_over_emitters**: Given _active_particle_count=100, _active_emitter_count=15, when _can_emit(50) called → then returns false
- **test_queue_enqueues_event**: Given empty queue, when _queue_emitter("hit_vfx", {}) called → then _emitter_queue.size() == 1
- **test_queue_fifo_eviction**: Given queue of 10 entries, when _queue_emitter() adds 11th → then oldest entry removed, size stays 10
- **test_drain_queue_processes_fifo**: Given queue with [A, B, C] and budget available, when _drain_queue() called → then A processed first, then B, then C
- **test_drain_stops_when_budget_insufficient**: Given queue with events, when _can_emit(50) becomes false mid-drain → then drain stops, remaining events stay in queue
- **test_process_queued_routes_correctly**: Given entry with type="combo_escalation_vfx", when _process_queued called → then emit_combo_escalation is invoked

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/vfx/fifo_queue_test.gd` — must exist and pass

---

## Dependencies

- Depends on: Stories 001-006 (all emit functions implemented to integrate queue)
- Unlocks: Story 008 (budget tests)

---

## Completion Notes

**Completed**:
**Criteria**: X/X passing
**Test Evidence**:
