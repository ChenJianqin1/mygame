# Cross-GDD Review Report

**Date**: 2026-04-17
**Review Mode**: Full
**Specialists**: game-designer (consistency), systems-designer (design theory)
**Verdict**: CONCERNS — 1 blocking issue found

---

## Executive Summary

One blocking issue (coop effective_damage formula missing `attack_type_multiplier`). Design theory has no blockers. The combo positive feedback loop is flagged as a warning but is a tuning concern, not a design flaw.

---

## Blocking Issues (must resolve before architecture)

### C1: coop effective_damage formula missing `attack_type_multiplier` 🔴

**Problem**: coop-system.md Formula 1 and entities.yaml both define:
```
effective_damage = base_damage * (1.0 + combo_multiplier) * (1.0 + COOP_BONUS)
```
But combat-system.md defines the full damage path as:
```
final_damage = base_damage * attack_type_multiplier * combo_multiplier
```
The `attack_type_multiplier` is always in the damage path. Coop bonus stacking should include it.

The numerical example (`base * 3.0 * 1.10 = 49.5`) happens to work out coincidentally:
`15 * 1.5 * 2.0 * 1.10 = 49.5` = `15 * 3.0 * 1.10` — but only by accident of the specific numbers chosen.

**Impact**: If implemented as written, coop bonus would incorrectly multiply damage ignoring attack type, leading to LIGHT attacks dealing disproportionately high coop-bonused damage.

**Fix required**:
- `coop-system.md` Formula 1 → `effective_damage = base_damage * attack_type_multiplier * (1.0 + combo_multiplier) * (1.0 + COOP_BONUS)`
- `design/registry/entities.yaml` entry `coop_damage_bonus` → update expression to include `attack_type_multiplier`

---

## Warnings (should resolve, won't block architecture)

### C2: combo-system.md — upstream dependency not declared
- combo-system.md consumes `attack_hit(attack_id, is_grounded, hit_count)` from collision-detection-system
- combo-system.md's Dependencies section lists no upstream dependencies at all
- Should formally list collision-detection-system as upstream for `attack_hit`

### C3: camera-system.md — `hit_confirmed` signal source attribution ambiguity
- camera-system.md L602: "战斗系统 | hit_confirmed"
- entities.yaml: `hit_confirmed` source = collision-detection-system.md
- Signal path may be indirect (collision → combat re-emits → camera) but attribution in dependency table is misleading

### C4: coop-system.md — downstream dependents not documented
- ui-system, particle-vfx-system, audio-system (pending) all consume coop signals
- coop-system Dependencies section does not list them as downstream dependents

### C5: combat-system.md — DOWNTIME state table exit not documented
- Player state table (L109) shows DOWNTIME with "—" as exit condition
- Rescue exit mechanism is in coop-system and animation-system, not combat
- Documentation gap, not a functional contradiction

### D1: Combo positive feedback loop — game gets easier over time
- Combo multiplier scales damage: more hits → higher multiplier → faster boss kill → less danger
- Boss HP scales linearly (×1.0 to ×2.5); player damage scales multiplicatively (base × attack_type × combo × coop × sync)
- At combo 40 sync: two players deal ~99/hit → Boss 3 (1800 HP) dies in ~9 seconds
- **Risk**: Intended difficulty ramp (phase 2/3) may be offset by combo accumulation
- **Not blocking**: tuning problem, not a design flaw. Adjustable via combo decay, boss HP, or phase thresholds.

### D2: Combo has no strategic sink (previously known — unresolved)
- Combo accumulates but there is nothing to spend it on
- No upgrade system, no threshold unlocks, no cash-out mechanic
- **Risk**: Limits long-term depth. Acceptable for MVP.
- **Recommendation**: Consider "combo break" move that spends combo for desperation attack (resets combo to 0, deals massive damage)

### D3: Difficulty curve inversion at phase transitions
- Phase 2/3 adds faster compression but players at combo 20+ are dealing 2.0-3.0× damage
- Intended difficulty spike may feel muted rather than escalating
- **Tuning concern**: prototype data needed before adjustment

---

## Cross-System Scenario Walkthroughs

### Scenario 1: Normal combat at combo 20+
**Systems firing**: Input → Combat → Collision Detection → Combo → Combat (damage) → Boss AI → Animation → Particle VFX → Camera → UI

✅ **No failure modes found.** Clean 10-system loop. Each system outputs valid inputs for the next.

---

### Scenario 2: Player downed mid-combo (P1 combo 40, P2 combo 20)
**Sequence**:
1. Combat: P1 HP→0 → `player_health_changed(0, 100, 1)`
2. Coop: P1 enters DOWNTIME, rescue timer starts (3s), P1 combo resets
3. P2 combo: **continues unchanged** (combo decay is time-only — no damage penalty)
4. Boss AI: `player_downed(1)` → compression_speed×0.5 for 2s
5. Animation: P1 downtime_loop, P2 continues normal
6. Camera: Enters CRISIS state (if P2 also <30% HP), smooth_speed→20.0
7. UI: P1 rescue timer spawns at P1 screen position
8. Particle VFX: P1 hit_vfx emitter deactivated

✅ **No broken state transitions.** Timer is real-time (not paused during hitstop). If rescue and timer expiration occur same frame, OUT takes priority.

---

### Scenario 3: CRISIS state activated (both <30% HP)
**Mechanical changes**:
- Coop: 25% damage reduction to BOTH players
- Boss AI: compression_speed×1.2 (20% faster — crisis_multiplier)
- UI: CrisisEdgeGlow pulses at #7F96A6 (orange+blue blend), 0.5s on/off
- Particle VFX: Paper debris density increases
- Camera: CRISIS state (priority: highest)

✅ **"Warm and powerful" — not dark and punishing.** Damage reduction is help, not punishment. Color palette is blended warm tones, not red. Rhythm is 0.5s on/off, not frantic. **Fantasy coherence maintained.**

---

## What's Working Well

| Strength | Detail |
|----------|--------|
| **Pillar alignment** | All 10 systems map to at least one pillar. No anti-pillar violations. |
| **Attention budget** | 3 active systems during combat (Input, Combat, Coop rescue). Under 4-system comfortable limit. |
| **No dominant strategies** | LIGHT has higher raw DPS but HEAVY wins at sustained combo. Neither dominates universally. |
| **Rescue trade-off sound** | CRISIS/SOLO reduction (25%) is compensation, not replacement for rescue. OUT (life loss) is the real stakes. |
| **Fantasy coherence** | "Capable action hero" + "vulnerable worker needing rescue" coexist — rescue visuals reframed as heroic. |
| **Signal contracts** | All 30+ cross-system signals properly defined with source and destination GDDs. |
| **DOWNTIME state** | All GDDs now use DOWNTIME consistently (fixed from prior review). |

---

## Previously Known Issues — Status

| ID | Issue | Status |
|----|-------|--------|
| B1 | `sync_window_opened` missing signal | ✅ FIXED |
| B2 | DEAD/DOWNTIME/DEFEAT naming | ✅ FIXED |
| B3 | input→boss-ai asymmetric dep | ✅ FIXED |
| B4 | boss-ai→combo asymmetric dep | ✅ FIXED |
| W1 | `boss_defeated` orphaned signal | Open — pending Boss AI formal adoption |
| W2 | `hit_landed` vs `hit_confirmed` mismatch | ✅ CLOSED — parallel chains, not a conflict |
| W3 | Combo has no strategic sink | Open — warning, not blocking |
| W4 | Boss kill time ~2.8s at theoretical max DPS | Open — prototype data needed |

---

## GDDs Flagged for Revision

| GDD | Issue | Type | Priority |
|-----|-------|------|----------|
| `coop-system.md` | Formula 1 missing `attack_type_multiplier` | Consistency | Blocking |
| `design/registry/entities.yaml` | `coop_damage_bonus` formula missing `attack_type_multiplier` | Consistency | Blocking |
| `combo-system.md` | No upstream dependencies declared | Consistency | Warning |
| `camera-system.md` | `hit_confirmed` source attribution ambiguous | Consistency | Warning |
| `coop-system.md` | Downstream dependents not documented | Consistency | Warning |
| `combat-system.md` | DOWNTIME exit not in state table | Consistency | Warning |

---

## Verdict: CONCERNS

One blocking issue (C1 — coop formula missing `attack_type_multiplier`). Fixing this is required before architecture. All other issues are warnings.

**Recommended actions before `/create-architecture`:**
1. Fix `coop-system.md` Formula 1: add `attack_type_multiplier`
2. Fix `entities.yaml` entry `coop_damage_bonus`: update expression
3. Optionally: add upstream/downstream dependency declarations to combo-system.md and animation-system.md
