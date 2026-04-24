# Story: Attack Pattern Selection (Behavior Tree)

> **Epic**: Boss AI系统 (`production/epics/boss-ai/EPIC.md`)
> **GDD**: design/gdd/boss-ai-system.md
> **Type**: Logic
> **Status**: Done

---

## Overview

Implement the Behavior Tree attack pattern selection logic that chooses attacks based on current phase and player position.

---

## Task Description

Implement the微观行为决策 layer — the Behavior Tree that selects which attack pattern to execute based on phase and context.

**File location**: `src/core/ai/boss_ai_manager.gd`

### Implementation Details

1. **Attack patterns** (constants):
   ```gdscript
   const PATTERN_RELENTLESS_ADVANCE := "Pattern_1_Relentless_Advance"
   const PATTERN_PAPER_AVALANCHE := "Pattern_2_Paper_Avalanche"
   const PATTERN_PANIC_OVERLOAD := "Pattern_3_Panic_Overload"
   const PATTERN_NONE := "NONE"
   ```

2. **_select_attack_pattern() -> String method**:
   Implement priority order from GDD Rule 5:
   ```
   1. If rescue_suspension_timer > 0 → return "NONE" (pause attacks)
   2. If player downed → return "NONE" (pause attacks)
   3. Otherwise → select by phase
   ```

3. **Phase-based selection**:
   - Phase 1: Always return `PATTERN_RELENTLESS_ADVANCE` (no frontal attacks, just compression)
   - Phase 2: Call `_select_phase2_pattern()`
   - Phase 3: Call `_select_phase3_pattern()`

4. **_select_phase2_pattern() -> String method**:
   - Based on player position: if player.x < compression_wall_x + 300 → Paper Avalanche
   - Otherwise → Relentless Advance
   - (Paper Avalanche is used when player is close to the compression wall)

5. **_select_phase3_pattern() -> String method**:
   - Always return `PATTERN_PANIC_OVERLOAD` (all patterns available, highest aggression)

6. **Attack execution flow**:
   When FSM enters ATTACKING state (in _transition_to):
   ```gdscript
   match _boss_state:
       BossState.ATTACKING:
           var pattern: String = _select_attack_pattern()
           if pattern != PATTERN_NONE:
               boss_attack_started.emit(pattern)
               Events.boss_attack_started.emit(pattern)
               _attack_cooldown = _calculate_attack_cooldown()
   ```

7. **_calculate_attack_cooldown() -> float method**:
   Implement attack interval formula from GDD Formula 4:
   ```
   attack_cooldown = max(MIN_ATTACK_INTERVAL, base_cooldown * hp_multiplier)
   ```
   - base_cooldown = 2.5s at full HP
   - hp_multiplier = linear from 1.0 at 100% HP to 0.5 at 0% HP
   - MIN_ATTACK_INTERVAL = 1.5s floor

8. **Can_attack() helper**:
   ```gdscript
   func can_attack() -> bool:
       return _boss_state == BossState.IDLE and _attack_cooldown <= 0
   ```

9. **Signal emission for UI**:
   - Before attack: emit `boss_attack_telegraph(pattern)` (for UI warning)
   - After attack: emit `boss_attack_started(pattern)` (for hitbox management)

---

## Dependencies

| Dependency | Story | Why |
|------------|-------|-----|
| BossAIManager foundation | story-001 | Constants, signals |
| Macro FSM states | story-002 | _transition_to calls _select_attack_pattern |
| Compression wall | story-003 | _select_phase2_pattern uses compression_wall_x |

---

## Acceptance Criteria

| # | Criterion | Test Type |
|---|-----------|-----------|
| AC-01 | Phase 1: only PATTERN_RELENTLESS_ADVANCE selected | Unit test |
| AC-02 | Phase 2: PATTERN_PAPER_AVALANCHE or PATTERN_RELENTLESS_ADVANCE | Unit test |
| AC-03 | Phase 3: PATTERN_PANIC_OVERLOAD selected | Unit test |
| AC-04 | rescue_suspension_timer > 0: no attack selected | Unit test |
| AC-05 | Phase 2, player near wall: Paper Avalanche selected | Unit test |
| AC-06 | Phase 2, player far from wall: Relentless Advance | Unit test |
| AC-07 | Boss full HP, MIN_ATTACK_INTERVAL=1.5s: cooldown = 2.5s | Unit test |
| AC-08 | Boss 50% HP: cooldown = max(1.5, 2.5 * 0.75) = 1.875s | Unit test |
| AC-09 | can_attack() returns true only when IDLE + cooldown <= 0 | Unit test |
| AC-10 | Attack selected emits boss_attack_started signal | Unit test |

---

## Estimated Effort

- **Expected**: 1.5 days
- **Optimistic**: 1 day
- **Pessimistic**: 2 days

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/core/ai/boss_ai_manager.gd` | Modify (add BT logic) |

---

## Notes

- "Relentless Advance" in Phase 1 is the compression itself, not a frontal attack
- _select_attack_pattern is called from _transition_to when entering ATTACKING
- No actual attack animation/sprite changes in this story — that's AnimationSystem's job
