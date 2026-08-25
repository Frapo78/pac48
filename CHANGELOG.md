# Changelog

All meaningful PAC48 development changes are recorded here.

This file is maintained alongside `docs/TODO.md` and `docs/INCIDENTS.md`:

- `CHANGELOG.md` records what changed.
- `docs/TODO.md` records what remains to be done and how completion is judged.
- `docs/INCIDENTS.md` records failures/regressions and the rules that prevent repeating them.
- `docs/adr/` records durable architecture decisions and rejected alternatives.

AI agents must update the `Unreleased` section whenever they make a meaningful code, architecture, build, verification, or documentation change. Do not wait for a release tag to record work.

Use concise entries grouped under `Added`, `Changed`, `Fixed`, `Verification`, and `Known limitations`. On release, move the accumulated entries under a dated version heading and create a fresh `Unreleased` section.

## Unreleased

### Added

- Dedicated `src/render.asm` frame-composition module with separate `Render_Prepare` and `Render_Commit` phases.
- Masked 8x8 actor compositing using `(screen AND mask) OR image`.
- Dirty-cell background restoration with bounded/de-duplicated x/y cell lists.
- 192-entry bitmap scanline address lookup table initialized at startup.
- Build-time `tools/gen_shifted_sprites.py` generator producing eight horizontal phases and masks for every player animation frame.
- `tools/check_project.py` deterministic checks for maze size, generated sprite structure, and upper-RAM binary budget.
- Persistent engineering incident registry at `docs/INCIDENTS.md`.
- Rendering architecture ADR at `docs/adr/0001-rendering-architecture.md`.

### Changed

- Main loop now commits prepared rendering immediately after `HALT`, then runs input/game update/render preparation outside the short screen-write phase.
- Maze is drawn once at startup instead of being redrawn in full every gameplay frame.
- Player module now owns simulation only; raw screen drawing moved to the renderer.
- Moving actors no longer write Spectrum attributes in the render hot path.
- Empty walkable maze cells use yellow ink on black paper so the yellow player remains visible while crossing empty/pellet cells.
- Build pipeline now generates sprite assets and runs structural checks before assembly, then checks final binary size/headroom.

### Fixed

- Preserved maze coordinates across attribute/bitmap drawing to prevent `DE` clobber corruption (`INC-2026-001`, `P48-001`).
- Corrected Sinclair 1 and Sinclair 2 Interface 2 direction mappings (`INC-2026-002`, `P48-002`).
- Replaced the destructive runtime-shift actor path and removed full-maze redraw from the normal frame path (`INC-2026-003`).

### Verification

- Python generator includes internal invariants for phase-0 and mask generation.
- Structural checks require exactly 560 maze cells and 160 generated player sprite phases.
- Full assembly/TAP, emulator/hardware smoke testing, and cycle-aware renderer profiling remain required for this migration before related incidents can be closed.

### Known limitations

- Current renderer prepares/draws the player only; the actor descriptor/dirty-cell model is intended to be extended to enemies.
- Actor color is currently constrained by static maze attributes; distinct per-ghost colors are intentionally deferred.
- Exact 50 Hz timing budget has not yet been measured in a cycle-aware emulator.

## 0.3.4-beta

Baseline before the 2026-08-25 renderer architecture migration. The project already had menu/input abstraction, maze collision/rendering, pixel/sub-tile player movement, and directional player animation.
