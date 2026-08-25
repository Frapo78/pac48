# Changelog

All meaningful PAC48 development changes are recorded here.

This file is maintained alongside `docs/TODO.md`, `docs/INCIDENTS.md`, `docs/TESTING.md`, and `docs/adr/`.

AI agents must update `Unreleased` whenever they make a meaningful code, architecture, build, verification, release, or documentation change.

## Unreleased

### Added

- Dedicated `src/render.asm` frame-composition module with separate `Render_Prepare` and `Render_Commit` phases.
- Masked 8x8 actor compositing using `(screen AND mask) OR image`.
- Dirty-cell background restoration with bounded/de-duplicated cell lists.
- 192-entry bitmap scanline address lookup table initialized at startup.
- Build-time `tools/gen_shifted_sprites.py` generator producing eight horizontal phases and masks for every player animation frame.
- Deterministic architecture, maze, generated-asset, memory-budget, and renderer reference-model checks.
- Headless 48K Z80 runtime harness executed by the canonical build.
- Contention-aware `Render_Commit` performance harness using SkoolKit `trace.py` directly on the raw assembled code.
- Fresh-48K TAP load simulation using `tap2sna.py`; the build now proves that the generated tape reaches PAC48 entry point `32768` (`$8000`).
- GitHub Actions verification using pinned sjasmplus 1.23.1 and SkoolKit 10.1.
- Automatic per-commit GitHub Releases for verified `main` builds.
- Stable release asset name `pac48-latest.tap` and stable download path `/releases/latest/download/pac48-latest.tap`.
- Versioned TAP, `SHA256SUMS.txt`, and `BUILD-INFO.txt` attached to every published verified release.
- Persistent engineering incident registry at `docs/INCIDENTS.md`.
- Repeatable V0-V5 verification protocol at `docs/TESTING.md`.
- Rendering architecture ADR at `docs/adr/0001-rendering-architecture.md`.
- Persistent `Pac_FacingDir` state so visual facing remains stable when movement stops against a wall.

### Changed

- Main loop now commits prepared rendering immediately after `HALT`, then performs input/game update/render preparation outside the short screen-write phase.
- Maze is drawn once at startup instead of being redrawn in full every gameplay frame.
- Dirty-cell restoration performs one bitmap+attribute cell draw instead of redundantly writing the attribute twice.
- Player module now owns simulation only; raw screen drawing moved to the renderer.
- Moving actors no longer write Spectrum attributes in the render hot path.
- Empty walkable maze cells use yellow ink on black paper so the yellow player remains visible while crossing empty/pellet cells.
- Build pipeline now generates sprite assets, runs deterministic tests, assembles, executes Z80 runtime tests, profiles timing, creates TAP files, and simulates loading the resulting TAP.
- Renderer chooses animation direction from persistent facing state rather than defaulting to right when `Pac_Dir=0`.
- Removed obsolete handwritten `Pac_FrameTable*` runtime pointer tables; generated phase tables are authoritative.
- Structural validation now requires exactly 20 maze rows of 28 cells, 160 unique generated phases, 8 scanlines x 4 bytes per phase, and exact 40-pointer tables per direction.
- GitHub Actions no longer creates redundant builds/releases for documentation-only pushes.
- Release publication is downstream of the verified build job and republishes the exact already-tested artifact rather than recompiling separately.

### Fixed

- Preserved maze coordinates across attribute/bitmap drawing to prevent `DE` clobber corruption (`INC-2026-001`, `P48-001`).
- Corrected Sinclair 1 and Sinclair 2 Interface 2 direction mappings (`INC-2026-002`, `P48-002`).
- Replaced the destructive runtime-shift actor path and removed full-maze redraw from the normal frame path (`INC-2026-003`).
- Prevented the stopped player from visually snapping to the right-facing animation when blocked.
- Replaced the performance profiler's raw→snapshot→reload measurement path with deterministic direct-raw execution after an exact-code mismatch was detected (`INC-2026-006`).
- Fixed GitHub Release post-publication verification after `gh release view` rejected the unsupported `isLatest` JSON field (`INC-2026-007`).

### Verification

Verified in GitHub Actions on 2026-08-25:

- sjasmplus 1.23.1: game assembly completed with **0 errors / 0 warnings**.
- SkoolKit 10.1 headless 48K runtime harness: PASS.
- Renderer reference model: scanline addressing, shift/mask generation, and dirty-cell coverage PASS.
- Binary size: **8042 bytes**.
- Conservative upper-RAM safety-ceiling headroom: **20630 bytes**.
- Generated TAP size: **8122 bytes**.
- Fresh 48K tape simulation: loaded code block at 32768 and stopped with **PC=32768 ($8000)**.
- `Render_Commit` with 48K contention:
  - common, 1 previous dirty cell: **4320 T-states / 547 instructions**;
  - cardinal, 2 previous dirty cells: **5455 T-states / 690 instructions**;
  - arbitrary 4-cell case: **7800 T-states / 978 instructions**.
- All measured renderer cases remain below the 12,000 T-state common engineering target and 14,000 warning threshold.
- Release-package SHA-256 checks pass before GitHub publication.

### Known limitations

- Current renderer prepares/draws the player only; the actor descriptor/dirty-cell model still needs extension to enemies.
- Current generated masks infer transparency from zero bits in canonical bitmap data. Future sprites needing opaque zero-valued pixels require explicit canonical mask support (`P48-016`).
- Actor color is currently constrained by static maze attributes; distinct per-ghost colors are deferred.
- Manual visual/control V3 testing is still required for complete current-renderer confidence.
- Real-hardware V5 testing remains required before claiming hardware-tested release status.

## 0.3.4-beta

Baseline before the 2026-08-25 renderer architecture migration. The project already had menu/input abstraction, maze collision/rendering, pixel/sub-tile player movement, and directional player animation.
