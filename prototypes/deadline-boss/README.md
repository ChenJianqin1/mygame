# Deadline Boss Prototype

## Purpose
Prototyping the core Deadline Boss mechanic: **compression wall that advances from behind, pushing players forward.**

## Core Mechanic
- Compression wall advances at `BASE_COMPRESSION_SPEED` (32px/s phase 1, faster in later phases)
- Players must stay ahead of the wall or take damage
- Wall visualizes as a red gradient/line advancing from the left
- Game over if both players are pushed off screen or HP depletes

## Systems to Verify
1. **BossAIManager** - compression wall advance, speed by phase
2. **CoopManager** - shared HP, player damage from wall
3. **CameraController** - follow both players, shake on hits
4. **ComboManager** - combo tracking, sync detection
5. **CollisionManager** - hitbox/hurtbox detection

## Controls (Prototype)
- **P1**: WASD to move, J to attack
- **P2**: Arrow keys to move, Numpad 1 to attack

## Success Criteria
- [ ] Wall advances continuously from left
- [ ] Wall respects phase multipliers (speeds up at 60% and 30% HP)
- [ ] Players take damage when in danger zone (left of wall)
- [ ] Both players can attack and deal damage to boss
- [ ] Boss HP triggers phase transitions
- [ ] Game over when both players die OR wall pushes players off screen

## Files
- `project.godot` - Godot project config
- `deadline_boss_main.tscn` - Main scene (players, boss, UI)
- `player_controller.gd` - Basic 2D player controller (movement + attack)
- `deadline_boss_main.gd` - Main game logic (compression wall, camera, win/lose)
