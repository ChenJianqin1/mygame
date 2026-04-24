# Epics Index

**Last Updated**: 2026-04-22
**Engine**: Godot 4.6 / GDScript / 2D Native Rendering
**Review Mode**: lean

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| input-system | Foundation | 输入系统 | design/gdd/input-system.md | Not yet created | Ready |
| collision-detection | Foundation | 碰撞检测系统 | design/gdd/collision-detection-system.md | Not yet created | Ready |
| camera-system | Foundation | 摄像机系统 | design/gdd/camera-system.md | Not yet created | Ready |
| combat | Core | 战斗系统 | design/gdd/combat-system.md | Not yet created | Ready |
| combo | Core | Combo连击系统 | design/gdd/combo-system.md | Not yet created | Ready |
| coop | Core | 双人协作系统 | design/gdd/coop-system.md | Not yet created | Ready |
| boss-ai | Core | Boss AI系统 | design/gdd/boss-ai-system.md | Not yet created | Ready |
| instant-difficulty | Feature | 即时难度调整 | 无GDD | Not yet created | Ready (占位) |
| scene-management | Feature | 场景管理系统 | 无GDD | Not yet created | Ready (占位) |
| ui | Presentation | UI系统 | design/gdd/ui-system.md | Not yet created | Ready |
| particle-vfx | Presentation | 粒子特效系统 | design/gdd/particle-vfx-system.md | Not yet created | Ready |
| animation | Presentation | 动画系统 | design/gdd/animation-system.md | 8 stories created | Ready-for-Dev |
| audio | Presentation | 音频系统 | ADR-ARCH-011 | Not yet created | Ready |

---

## Layer Progress

| Layer | Epics | Status |
|-------|-------|--------|
| Foundation | 1 (input-system) | Ready — stories not created |
| Core | 4 (combat, combo, coop, boss-ai) | Not started |
| Feature | 2 (instant-difficulty, scene-management) | Not started |
| Presentation | 4 (camera, vfx, animation, ui) | Not started |
| Persistence | 1 (save-system) | Not started |

---

## Next Steps

1. Run `/create-stories input-system` to create stories for the first epic
2. Foundation + Core complete → run `/gate-check production`
3. All epics complete → ready for Pre-Production → Production transition
