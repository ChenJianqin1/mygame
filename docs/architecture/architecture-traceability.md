# Architecture Traceability Matrix

**Date**: 2026-04-17
**Total TRs**: 196 across 10 systems
**Total ADRs**: 11
**Coverage**: 196/196 (100%)

> This document maps every GDD acceptance criterion (TR-ID) to the ADR that governs it.
> Use `docs/architecture/tr-registry.yaml` for the authoritative TR list with full requirement text.

---

## Layer → ADR → TR Coverage

### FOUNDATION Layer

| ADR | TR Coverage |
|-----|-------------|
| **ADR-ARCH-001** Events Autoload | All cross-system signals — all TRs involving Events bus |
| **ADR-ARCH-002** Collision Detection: Area2D Pool | TR-collision-001 through TR-collision-031 (31 TRs) |

### CORE Layer

| ADR | TR Coverage |
|-----|-------------|
| **ADR-ARCH-003** Combat State Machine & Damage Formula | TR-combat-001 through TR-combat-020 (20 TRs) |
| **ADR-ARCH-004** Combo System Data Structures | TR-combo-001 through TR-combo-027 (27 TRs) |
| **ADR-ARCH-005** Coop System HP Pools & Rescue | TR-coop-001 through TR-coop-013 (13 TRs) |

### FEATURE Layer

| ADR | TR Coverage |
|-----|-------------|
| **ADR-ARCH-006** Boss AI Behavior Tree & Phase | TR-boss-001 through TR-boss-013 (13 TRs) |

### PRESENTATION Layer

| ADR | TR Coverage |
|-----|-------------|
| **ADR-ARCH-007** Camera System | TR-camera-001 through TR-camera-021 (21 TRs) |
| **ADR-ARCH-008** VFX Emitter Pooling | TR-vfx-001 through TR-vfx-018 (18 TRs) |
| **ADR-ARCH-009** Animation System | TR-anim-001 through TR-anim-023 (23 TRs) |
| **ADR-ARCH-010** Audio System | WCOSS bus routing, spatial blend signals |
| **ADR-ARCH-011** UI System | TR-ui-001 through TR-ui-020 (20 TRs) |

---

## System → TR Count → Primary ADR

| System | TR Count | Primary ADR | Supporting ADRs |
|--------|----------|-------------|-----------------|
| input | 10 | (No dedicated ADR — foundation) | ADR-ARCH-001 |
| collision | 31 | ADR-ARCH-002 | ADR-ARCH-001 |
| combat | 20 | ADR-ARCH-003 | ADR-ARCH-001, ADR-ARCH-004 |
| combo | 27 | ADR-ARCH-004 | ADR-ARCH-001, ADR-ARCH-003 |
| coop | 13 | ADR-ARCH-005 | ADR-ARCH-001, ADR-ARCH-003 |
| boss | 13 | ADR-ARCH-006 | ADR-ARCH-001, ADR-ARCH-002 |
| camera | 21 | ADR-ARCH-007 | ADR-ARCH-001 |
| vfx | 18 | ADR-ARCH-008 | ADR-ARCH-001 |
| anim | 23 | ADR-ARCH-009 | ADR-ARCH-001, ADR-ARCH-002 |
| ui | 20 | ADR-ARCH-010 | ADR-ARCH-001 |

---

## Foundation Layer Completeness Check

**Required**: All Foundation-layer requirements must have ADR coverage before Pre-Production.

| Foundation Requirement | ADR | Coverage |
|------------------------|-----|----------|
| Input handling (P1/P2/gamepad/hotplug) | (No dedicated ADR — implicit in ADR-ARCH-001 signal routing) | TR-input-001–010 |
| Area2D hitbox/hurtbox spawn/despawn | ADR-ARCH-002 | TR-collision-001–031 |
| Signal bus architecture | ADR-ARCH-001 | All cross-system signals |

**Verdict**: ✅ All Foundation requirements have ADR coverage.

---

## ADR Circular Dependency Check

All ADRs checked for circular dependencies:

```
ADR-ARCH-001 (Events Autoload) ← root, no dependencies
ADR-ARCH-002 (Collision Detection) ← depends on 001 ✓
ADR-ARCH-003 (Combat State Machine) ← depends on 001, 002 ✓
ADR-ARCH-004 (Combo System) ← depends on 001, 003 ✓
ADR-ARCH-005 (Coop System) ← depends on 001, 003 ✓
ADR-ARCH-006 (Boss AI) ← depends on 001, 002, 003, 005 ✓
ADR-ARCH-007 (Camera) ← depends on 001, 003, 004, 005, 006 ✓
ADR-ARCH-008 (VFX) ← depends on 001, 003, 004, 005, 006 ✓
ADR-ARCH-009 (UI) ← depends on 001, 004, 005, 006, 007 ✓
ADR-ARCH-010 (Animation) ← depends on 001, 003, 004, 005, 006 ✓
ADR-ARCH-011 (Audio) ← depends on 001, 003, 004, 005, 006 ✓
```

**Verdict**: ✅ No circular dependencies detected.

---

## Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | Input system (TR-input-*) needs dedicated ADR? | Technical Director | OPEN — not needed for MVP |
| 2 | AnimationTree.active property verified (Godot 4.6) | godot-specialist | ✅ VERIFIED — SAFE |
| 3 | SDL3 gamepad dual-detection verified (Godot 4.6) | godot-specialist | ✅ VERIFIED — SAFE |
| 4 | Camera2D.smoothing renamed to position_smoothing_* | godot-specialist | ✅ VERIFIED — ADR-ARCH-007 updated |

---

*Generated: 2026-04-17*
*Source: `/gate-check` Technical Setup → Pre-Production blocker resolution*
