# Accessibility Requirements: 今日Boss：打工吧！

> **Status**: Committed
> **Author**: producer
> **Last Updated**: 2026-04-17
> **Accessibility Tier Target**: Basic
> **Platform(s)**: PC (Steam)
> **External Standards Targeted**: None (PC-only, no platform certification required)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `docs/architecture/architecture.md`

---

## Accessibility Tier Definition

### This Project's Commitment

**Target Tier**: Basic

**Rationale**: This is a 2D co-op boss-rush game targeting PC (Steam) as the sole platform. The game has fast-twitch combat (boss attacks, combo timing, dodge windows) which creates inherent motor barriers that cannot be fully eliminated without changing the core design. Basic tier addresses the critical non-negotiable barriers: text legibility, color-as-only-indicator risks, brightness calibration, and photosensitivity. Full input remapping is included because the game requires simultaneous two-player input coordination — players need to remap when playing with different controller configurations. Timed inputs are core to the boss-rush mechanic and cannot be extended without breaking the game's difficulty identity. No platform certification (Xbox, PlayStation) is required, so XAG/Sony guidelines are not applicable.

**Features explicitly in scope**:
- Full input remapping (keyboard, mouse, gamepad)
- Minimum text size requirements for all UI
- Color-as-only-indicator audit with non-color backups
- Brightness/gamma controls
- Screen flash / strobe warning and Harding FPA audit
- Independent volume controls (Music, SFX, Voice)
- Pause anywhere

**Features explicitly out of scope**:
- Colorblind modes (Standard tier) — significant UI architecture work, not required for PC-only release
- Input method switching mid-session (Standard tier) — game is session-based, switching not needed
- Subtitle speaker identification (Standard tier) — single-player dialogue only, no voice acting
- Screen reader support — Godot 4.6 AccessKit covers menus only; not a v1.0 requirement
- UI scaling (Standard tier) — 2D art style has fixed resolution targets
- Any platform accessibility API integration (Xbox/PlayStation)

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menu UI | Basic | All menu screens | Not Started | 20px minimum at 1080p. Menu text is primarily Chinese — use a font with clear Chinese glyph rendering at small sizes. |
| Minimum text size — HUD | Basic | In-game HUD | Not Started | 16px minimum for critical information (health, combo count). Chinese font must be legible at this size. |
| Text contrast — UI text on backgrounds | Basic | All UI text | Not Started | Minimum 4.5:1 ratio (WCAG AA). Test all text/background combinations. Key contrast pairs: orange (#F5A623) on dark backgrounds must be verified. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | **Critical**: P1 color = orange (#F5A623), P2 color = blue (#4ECDC4). These colors must not be the sole differentiator. Icon shapes must differentiate players. |
| Brightness/gamma controls | Basic | Global | Not Started | Exposed in graphics settings. Range: -50% to +50% from default. |
| Screen flash / strobe warning | Basic | All cutscenes, VFX | Not Started | (1) Launch warning: photosensitivity seizure notice. (2) Audit all flash-heavy VFX against Harding FPA standard. VFX system has 300-particle budget — review emitter configs for flash potential. |
| Motion/animation reduction mode | Basic | UI transitions | Not Started | Menu transitions can be instant cuts. Camera shake and combat VFX are CORE TO THE GAME — cannot be disabled. |
| Subtitles — on/off | Basic | All voiced content | Not Started | No voice acting at v1.0 — no subtitles required. Revisit if voice-over is added post-launch. |
| Independent volume controls | Basic | Music / SFX / UI audio | Not Started | Three independent sliders: BGM, SFX, UI. ADR-ARCH-011 defines WCOSS bus routing. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| HP Bar P1 | Orange (#F5A623) | Player 1's health | Player icon/avatar adjacent to bar; "P1" label | Not Started |
| HP Bar P2 | Blue (#4ECDC4) | Player 2's health | Player icon/avatar adjacent to bar; "P2" label | Not Started |
| Combo counter | Gold tier color | Combo tier level | Tier number always shown; size scaling shows tier | Not Started |
| Boss HP bar | Color shifts by phase (orange→red) | Boss phase | Phase number shown on bar; percentage always visible | Not Started |
| Crisis edge glow | Red tint | Both players below 30% HP | "CRISIS" text label flashes; audio warning | Not Started |
| Sync indicator | Orange + Blue intertwine | Both players hitting sync window | Chain count number shown (e.g., "×2") | Not Started |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Basic | All gameplay inputs | Not Started | Every input must be rebindable. Persist to player profile. Two-player local co-op — each player's bindings stored independently. |
| Hold-to-press alternatives | Basic | Dodge (hold) | Not Started | "Hold to dodge" can be toggle. Attack cannot be toggled — this is a design constraint. |
| Rapid input alternatives | Basic | Combo inputs | Not Started | Combo system requires rhythmic button presses. No toggle alternative — this is a core skill-ceiling mechanic. |
| Input timing adjustments | Basic | Dodge window | Not Started | Dodge window is a fixed 12 frames. Timing adjustment NOT applicable — extending would break boss difficulty. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Pause anywhere | Basic | All gameplay states | Not Started | Must pause during boss intro, gameplay, and boss defeat sequences. |
| Tutorial persistence | Basic | All tutorials | Not Started | First-launch tutorial is mandatory. After dismissal, retrievable from pause menu Help section. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | Basic | N/A | Not Applicable | No voice acting in v1.0. |
| Independent volume controls | Basic | Music / SFX / UI | Not Started | Three buses minimum. ADR-ARCH-011 audio routing must expose these as separate controls. |
| Visual representations for audio-only information | Basic | Boss attack telegraphs | Not Started | Boss attack telegraphs are primarily visual (animation + UI icon). Audio is secondary. Verify all telegraphs have visual component. |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Steam (PC) | SDL / Steam Input | Controller remapping via Steam Input | Not Started | In-game remapping is required independently of Steam Input. |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Combat | HP bar color by player; combo color tiers | Rapid input combos; hold-to-dodge | Track boss patterns + cooldowns + combo | Boss attack audio cues | Partial | Color backup icons on HP bars; no toggle for combos |
| Combo | Gold color = high tier | Rhythm button presses | Combo decay timer | Sync burst audio | Partial | Timer always visible |
| Coop | P1 orange, P2 blue | Two-player simultaneous input | Rescue timer awareness | Rescue audio cue | Partial | Player labels on HP bars |
| Boss AI | Boss HP color by phase | None | Boss phase awareness | Phase transition audio | Partial | Phase number on boss HP bar |
| VFX | None — visual-only system | None | None | None | N/A | |
| UI | Color-coded elements | None | Pause menu always accessible | None | Partial | Color backup icons |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Colorblind modes | Standard | 2D art style uses P1 orange / P2 blue as primary identity; palette change would require significant art rework | Affects colorblind players who cannot distinguish P1/P2 | P1/P2 labels always visible on HP bars |
| Subtitle customization | Standard | No voice acting in v1.0 | N/A | N/A |
| Screen reader for menus | Standard | Godot AccessKit covers menus only partially | Blind players cannot navigate menus independently | Evaluate post-launch if Godot AccessKit improves |
| UI scaling | Standard | Fixed 2D art resolution targets | Players with low vision may struggle at small resolutions | Support 1080p minimum; higher resolutions use UI scaling if implemented |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-04-17 | producer | Internal review | Pre-gate accessibility audit | 6 items verified. Color-as-only-indicator audit identified 6 locations needing non-color backup. All have backup icons or labels. | Committed |

---

## Open Questions

| Question | Owner | Resolution |
|----------|-------|------------|
| Godot 4.6 AccessKit — does it support menu screen reader for Chinese text? | godot-specialist | Unresolved — verify before implementation |
