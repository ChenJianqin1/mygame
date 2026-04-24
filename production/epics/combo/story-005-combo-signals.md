# Story: Combo Signal Architecture

> **Type**: Integration
> **Epic**: Combo连击系统 (`production/epics/combo/EPIC.md`)
> **GDD**: `design/gdd/combo-system.md` (Interactions with Other Systems)
> **ADR**: ADR-ARCH-004 (Signal Routing)
> **Status**: Done

## Overview

Implement all combo system signals and their routing through the Events autoload. Signals connect ComboManager to downstream systems (UI, VFX, Combat, Audio, Boss AI).

## Player Fantasy

**玩家幻想：** "连击升级了！视觉和音效跟着变。"

The combo system is the "information hub" — it broadcasts state changes so UI, VFX, audio, and boss AI can respond in sync. Players feel the escalation through every sense.

## Detailed Rules

### Input Signals (Consumed by ComboManager)

| Signal | Source | Payload | Description |
|--------|--------|---------|-------------|
| `Events.combo_hit` | CombatSystem | (attack_type, combo_count, is_grounded) | Each hit increments combo |

### Output Signals (Produced by ComboManager)

| Signal | Payload | Consumers | Description |
|--------|---------|-----------|-------------|
| `Events.combo_multiplier_updated` | (multiplier: float, player_id: int) | CombatSystem | Damage calculation |
| `Events.combo_tier_changed` | (tier: int, player_id: int) | UI | Tier-based UI scaling |
| `Events.sync_chain_active` | (chain_length: int) | UI, VFX | Sync chain building |
| `Events.sync_burst_triggered` | (position: Vector2) | VFX | 3+ consecutive SYNC hits |
| `Events.sync_window_opened` | (player_id: int, partner_id: int) | AnimationSystem | Animation system consumption |
| `Events.combo_tier_escalated` | (tier: int, player_color: Color) | VFX | Tier escalation VFX |
| `Events.combo_break` | (player_id: int) | UI | Combo break visual (no penalty) |
| `Events.combo_tier_audio` | (tier: int) | AudioSystem | Different sounds per tier |

### Public Query Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `ComboManager.get_combo_multiplier(player_id, is_sync)` | float | Query current multiplier |
| `ComboManager.get_combo_tier(player_id)` | int | Query current tier |
| `ComboManager.get_sync_chain_length(player_id)` | int | Query sync chain length |

## Signal Flow

```
CombatSystem
    └─> Events.combo_hit
            └─> ComboManager._on_combo_hit()
                    ├─> Events.combo_multiplier_updated (to CombatSystem)
                    ├─> Events.combo_tier_changed (to UI)
                    ├─> Events.sync_chain_active (to UI/VFX)
                    ├─> Events.sync_burst_triggered (to VFX)
                    ├─> Events.combo_tier_escalated (to VFX)
                    └─> Events.combo_break (to UI)
```

## Formulas

None — this story is about signal routing, not game logic.

## Edge Cases

- **Signal emitted with stale data**: Signals carry data snapshots, not references
- **Multiple signals fire same frame**: All signals fire in deterministic order (multiplier → tier → sync)
- **Tier does not change**: `combo_tier_changed` does NOT fire if tier is unchanged

## Dependencies

**Upstream:**
- Stories 001-004: All logic implementation must be complete first

**Downstream:**
- UI system: consumes combo_tier_changed, sync_chain_active, combo_break
- VFX system: consumes sync_burst_triggered, combo_tier_escalated
- Combat system: consumes combo_multiplier_updated
- Boss AI system: consumes combo_hit signal
- Audio system: consumes combo_tier_audio

## Tuning Knobs

None — signal architecture is fixed.

## Acceptance Criteria

| ID | GIVEN | WHEN | THEN |
|----|-------|------|------|
| AC-25 | combo_tier changes 2→3 | UI update | combo_tier_changed(3, player_id) fires |
| AC-26 | Sync chain breaks | Visual state | sync_chain_active(0) fires |
| AC-27 | combo_count resets | UI signal | combo_break(player_id) fires |
| — | combo_hit received | — | All downstream signals fire with correct payloads |
| — | get_combo_multiplier called | valid player_id | Returns correct float value |
| — | get_combo_tier called | valid player_id | Returns correct int tier |
| — | get_sync_chain_length called | valid player_id | Returns correct int chain length |

## Tasks

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|-------------|-------------------|
| 1 | Define all signal payloads in Events autoload | — | 0.5 | ADR-ARCH-001 | All 8 signals defined with correct types |
| 2 | Connect Events.combo_hit in ComboManager._ready() | — | 0.25 | Story 001 | Connection established |
| 3 | Implement signal emissions in ComboManager | — | 0.5 | Stories 002-004 | All signals fire at correct moments |
| 4 | Implement public query methods | — | 0.25 | Stories 001-002 | Methods return correct values |
| 5 | Write integration test verifying full signal flow | — | 0.5 | Tasks 1-4 | All signals fire with correct payloads |

## Definition of Done

- [x] All 8 signals defined in Events autoload with correct payloads
- [x] Events.combo_hit connected in ComboManager._ready()
- [x] combo_multiplier_updated fires on each hit
- [x] combo_tier_changed fires only when tier changes
- [x] sync_chain_active fires with chain length (0 when broken)
- [x] sync_burst_triggered fires at 3+ consecutive SYNC
- [x] combo_tier_escalated fires on tier changes
- [x] combo_break fires when combo resets
- [x] combo_tier_audio fires on tier changes
- [x] get_combo_multiplier() returns correct value
- [x] get_combo_tier() returns correct tier
- [x] get_sync_chain_length() returns correct chain length
- [x] Integration test passes verifying complete signal flow
