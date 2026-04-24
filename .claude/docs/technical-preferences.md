# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: 2D原生渲染（Godot内置2D渲染管线）
- **Physics**: Godot内置2D物理

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC
- **Input Methods**: Keyboard/Mouse, Gamepad (本地双人合作)
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial
- **Touch Support**: None
- **Platform Notes**: 无特殊平台约束

## Naming Conventions

- **Classes**: PascalCase (e.g., PlayerController)
- **Variables**: snake_case (e.g., move_speed)
- **Signals/Events**: snake_case过去式 (e.g., health_changed)
- **Files**: snake_case (e.g., player_controller.gd)
- **Scenes/Prefabs**: PascalCase (e.g., PlayerController.tscn)
- **Constants**: UPPER_SNAKE_CASE (e.g., MAX_SPEED)

## Performance Budgets

> Sourced from architecture decisions in `docs/architecture/`. Hard limits are enforced in code via budget trackers.

- **Target Framerate**: 60fps (fixed physics timestep at 60fps)
- **Frame Budget**: 12ms max for game logic (16.67ms total / 60fps — 4ms headroom for rendering/OS)
- **Draw Calls**: ≤200 draw calls per frame at target framerate
- **Memory Ceiling**: 512MB total runtime memory (ART, audio, particle pools)

### Hard Limits (enforced in code)

| System | Limit | Source |
|--------|-------|--------|
| Concurrent Particles | 300 max | ADR-ARCH-008 (VFX System) |
| Concurrent Emitters | 15 max | ADR-ARCH-008 (VFX System) |
| Concurrent Hitboxes | 13 max (2P×4 + 1Boss×6, minus overlaps) | ADR-ARCH-002 (Collision Detection) |
| Particle Pool Size | 20 pre-allocated emitters | ADR-ARCH-008 (VFX System) |

## Testing

- **Framework**: GdUnit4 (Godot 4 asset — install via Godot AssetLib)
- **Minimum Coverage**: Logic stories require passing unit tests; Integration stories require integration tests or documented playtest
- **Required Tests**: Balance formulas, combat state machine transitions, combo decay math, coop HP/share formulas, hitbox pool correctness, VFX budget enforcement
- **CI Gate**: `.github/workflows/tests.yml` — tests must pass on every PR before merge

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- ADR-ARCH-001: Events Autoload — signal bus architecture
- ADR-ARCH-002: Collision Detection — Area2D hitbox/hurtbox pool pattern
- ADR-ARCH-003: Combat State Machine — attack/buff/debuff/hit/stagger states
- ADR-ARCH-004: Combo System Data Structures — multiplier, decay, reset rules
- ADR-ARCH-005: Coop System HP Pools & Rescue — shared HP, rescue trigger, crisis slowdown
- ADR-ARCH-006: Boss AI System — phase state machine, attack patterns, compression wall
- ADR-ARCH-007: Camera System — 7-state machine, trauma shake, dual-player tracking
- ADR-ARCH-008: VFX System — 5 emitter types, 300-particle/15-emitter budget, FIFO queue
- ADR-ARCH-009: UI System — layered CanvasLayer, 5-panel layout
- ADR-ARCH-010: Animation System — AnimatedSprite2D+AnimationPlayer, frame-locked hitboxes
- ADR-ARCH-011: Audio System — WCOSS bus routing, 5-layer spatial blend

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
