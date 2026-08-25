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
- Deterministic architecture, maze, generated-asset, memory-budget, renderer, collision, and pellet-state checks.
- Headless 48K Z80 runtime harness executed by the canonical build.
- Runtime visual-baseline guards for representative maze wall/pellet attributes and wall bitmap bytes.
- Sixteen topology-selected 8x8 wall-boundary bitmap variants for thin maze outlines.
- New `src/pellets.asm` gameplay-state module. Normal pellet consumption mutates the authoritative `Maze_Map` cell from `Maze_CellPellet` to `Maze_CellEmpty`.
- Centre-based player pellet pickup so consumption is symmetric when entering a cell from any direction.
- Z80 regression coverage for pellet mutation at spawn and when the player centre crosses into a new pellet cell.
- Z80 regression coverage for a deliberately one-pixel-misaligned player approaching a wall.
- Contention-aware `Render_Commit` performance harness using SkoolKit directly on raw assembled code.
- Fresh-48K TAP load simulation; the build proves the generated tape reaches entry point `$8000`.
- GitHub Actions verification using pinned sjasmplus 1.23.1 and SkoolKit 10.1.
- Automatic per-commit GitHub Releases for verified `main` builds, including stable `pac48-latest.tap`, versioned TAP, checksums, and build metadata.
- Persistent incident registry, V0-V5 verification protocol, rendering ADR, and structured AI-agent TODO workflow.

### Changed

- Main loop commits prepared rendering immediately after `HALT`, then performs input/game update/render preparation outside the short screen-write phase.
- Maze is drawn once at startup instead of being redrawn in full every gameplay frame.
- Dirty-cell restoration performs one bitmap+attribute cell draw instead of redundantly writing the attribute twice.
- Player module owns simulation only; raw screen drawing is owned by the renderer.
- Moving actors do not write Spectrum attributes in the render hot path.
- Wall presentation changed from solid blue PAPER cells to black PAPER + bright-blue bitmap boundaries derived from neighboring wall topology.
- Normal pellet art is a small 2x2 dot.
- Empty and pellet walkable cells retain yellow ink on black paper so the current yellow player remains visible without actor attribute writes.
- `Maze_CanMove` and wall-topology lookup share the canonical maze cell source.
- Player continuation collision is no longer an "aligned node only" test. Every one-pixel step now samples both corners of the advancing edge of the full 8x8 actor box and checks the corresponding maze cells.
- Buffered direction changes remain grid-aligned, preserving the responsive movement behavior while wall collision is enforced independently every pixel.
- Player pellet pickup uses the 8x8 sprite centre rather than its top-left anchor.
- The pellet beneath the initial player spawn is consumed before the first maze draw.
- Build pipeline generates assets, runs deterministic checks, assembles, executes Z80 runtime tests, profiles timing, creates TAP files, and simulates loading the resulting TAP.
- Renderer chooses animation direction from persistent facing state rather than defaulting to right when movement stops.
- Obsolete handwritten actor phase tables were removed; generated phase tables are authoritative.
- Documentation-only GitHub pushes do not create redundant binary releases.

### Fixed

- Preserved maze coordinates across attribute/bitmap drawing to prevent `DE` clobber corruption (`INC-2026-001`, `P48-001`).
- Fixed the S0 maze color-band regression where coordinate translation overwrote the intended Spectrum attribute (`INC-2026-008`, `P48-018`).
- Corrected the first attempted attribute-preservation repair after the new runtime guard caught the wrong AF/DE stack order before release.
- Corrected Sinclair 1 and Sinclair 2 Interface 2 direction mappings (`INC-2026-002`, `P48-002`).
- Replaced the destructive runtime-shift actor path and removed full-maze redraw from the normal frame path (`INC-2026-003`).
- Prevented the stopped player from visually snapping to the right-facing animation when blocked.
- Hardened wall collision against transient sub-tile misalignment by replacing unconditional between-node continuation with per-pixel leading-edge collision checks (`INC-2026-009`, `P48-024`).
- Normal pellets now disappear persistently when Pac crosses them instead of remaining visual-only maze cells (`P48-025`).
- Replaced the performance profiler's raw→snapshot→reload measurement path with deterministic direct-raw execution (`INC-2026-006`).
- Fixed GitHub Release post-publication verification after an unsupported CLI JSON field was used (`INC-2026-007`).

### Verification

Current collision/pellet baseline verified by GitHub Actions run `32801837183`, commit `5acf77665afc5187bcd0baae03a349177ff68955`:

- sjasmplus 1.23.1: **0 errors / 0 warnings**.
- SkoolKit 10.1 headless 48K runtime harness: **PASS**.
- Runtime harness includes:
  - maze attribute/wall-outline guards;
  - legal player movement;
  - blocked movement;
  - persistent pellet mutation;
  - centre-threshold pellet pickup;
  - one-pixel orthogonal-drift wall-collision regression.
- Renderer reference model: **PASS**.
- Binary size: **8503 bytes**.
- Conservative upper-RAM safety-ceiling headroom: **20169 bytes**.
- Generated TAP size: **8583 bytes**.
- Fresh 48K tape simulation stops with **PC=32768 ($8000)**.
- `Render_Commit` with 48K contention remains:
  - dirty1: **4341 T-states / 549 instructions**;
  - dirty2: **5497 T-states / 694 instructions**;
  - dirty4: **9184 T-states / 1145 instructions**.
- All measured renderer cases remain below the 12,000 T-state common target and 14,000 warning threshold.
- Verified per-commit Release publication completed successfully and GitHub Latest points to `build-5acf77665afc`.
- Current `pac48-latest.tap` SHA-256: `05c5636e687d86750c36c63170f6ee97a7a4aab794106cf1594ff93a3d675331`.

### V3 evidence

- Owner screenshot after `P48-018` confirmed the previous large colored bands/solid rectangles were gone; owner described the screen as "molto meglio" and reported controls responsive and movement very fluid.
- `P48-018` / `INC-2026-008` are therefore visually accepted and closed.
- Fresh owner V3 confirmation is still required for `P48-024` (no wall penetration during sustained play) and `P48-025` (pellets visibly disappear while traversed).

### Known limitations

- Current 28x20 maze topology is still the earlier generic layout. `P48-019` will replace it with a more deliberate symmetric arcade-style composition after collision/pellet V3 confirmation.
- Pellet count, score increment, level completion, HUD, power pellets, ghost house, enemies, lives, bonus presentation, and sound remain future work.
- Current renderer prepares/draws the player only; actor descriptor/dirty-cell support still needs extension to enemies.
- Current generated masks infer transparency from zero bits. Future sprites needing opaque zero-valued pixels require explicit canonical mask support (`P48-016`).
- Actor color remains constrained by static Spectrum attributes; distinct per-ghost colors are deferred.
- Real-hardware V5 testing remains required before claiming hardware-tested release status.

## 0.3.4-beta

Baseline before the 2026-08-25 renderer architecture migration. The project already had menu/input abstraction, maze collision/rendering, pixel/sub-tile player movement, and directional player animation.
