# Epic: 战斗系统

> **Layer**: Core
> **GDD**: design/gdd/combat-system.md
> **Architecture Module**: 战斗系统
> **Status**: Ready
> **Stories**: 7 created — see table below

---

## Overview

战斗系统管理玩家的攻击、受伤、回避状态，以及伤害计算公式。玩家状态机包含 IDLE/MOVING/ATTACKING/HURT/DODGING/BLOCKING/DOWNTIME 7个状态。伤害公式为 `final_damage = base_damage × attack_type_multiplier × combo_multiplier`。Hitstop 基于攻击类型和目标类型计算。系统作为生产者发出 `attack_started`、`hit_confirmed`、`hurt_received`、`player_hp_changed` 信号。

核心职责：
- 7个玩家状态机转换（IDLE/MOVING/ATTACKING/HURT/DODGING/BLOCKING/DOWNTIME）
- 伤害公式计算（base × attack_type_multiplier × combo_multiplier）
- Hitstop 帧级控制
- 击退方向计算（远离攻击者）
- 无敌帧（i-frames）管理

---

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-ARCH-003: Combat State Machine | 7状态机；伤害公式；Hitstop计算；击退方向计算 | LOW |

---

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-combat-001 | 7-state player state machine | ADR-ARCH-003 ✅ |
| TR-combat-002 | Damage formula: base × attack_type × combo_multiplier | ADR-ARCH-003 ✅ |
| TR-combat-003 | Hitstop: base + bonus per attack/target type | ADR-ARCH-003 ✅ |
| TR-combat-004 | Knockback direction away from attacker | ADR-ARCH-003 ✅ |
| TR-combat-005 | i-frames during dodge | ADR-ARCH-003 ✅ |
| ... | (all 20 TR-combat requirements) | All ✅ |

**Total**: 20/20 TRs covered by ADRs ✅

---

## Definition of Done

This epic is complete when:
- All 7 player states transition correctly under all documented conditions
- Damage formula applies correctly: `final_damage = base × attack_type_multiplier × combo_multiplier`
- Hitstop triggers and lasts correct frame count per attack/target type combination
- Knockback direction is always away from attacker
- i-frames activate and count down correctly during dodge
- All Logic stories have passing unit tests
- All Integration stories have passing integration tests or documented playtest
- All Acceptance Criteria from `design/gdd/combat-system.md` are verified

---

## Stories

| ID | Story | Type | Status |
|----|-------|------|--------|
| 001 | CombatManager Autoload + Damage Formula | Logic | Ready-for-Dev |
| 002 | Knockback System | Logic | Ready-for-Dev |
| 003 | Hitstop System | Logic | Ready-for-Dev |
| 004 | Defense System | Logic | Ready-for-Dev |
| 005 | Dodge/i-frames System | Logic | Ready-for-Dev |
| 006 | Boss HP Formula | Logic | Ready-for-Dev |
| 007 | Player State Machine Integration | Integration | Ready-for-Dev |

---

## Next Step

Run `/story-readiness story-001` to begin implementation of the first story.
