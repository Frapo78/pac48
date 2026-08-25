# Changelog

All meaningful PAC48 development changes are recorded here.

This file is maintained alongside `docs/TODO.md`, `docs/INCIDENTS.md`, `docs/TESTING.md`, and `docs/adr/`.

AI agents must update `Unreleased` whenever they make a meaningful code, architecture, build, verification, release, rollback, or documentation change.

## Unreleased

### Added

- Dedicated `src/render.asm` frame-composition module with separate `Render_Prepare` and `Render_Commit` phases.
- Masked 8x8 actor compositing using `(screen AND mask) OR image`.
- Dirty-cell background restoration with bounded/de-duplicated cell lists.
- 192-entry bitmap scanline address lookup table initialized at startup.
- Build-time `tools/gen_shifted_sprites.py` generator producing eight horizontal phases and masks for every player animation frame.
- Deterministic architecture, maze, generated-asset, memory-budget and renderer checks.
- Headless 48K Z80 runtime harness.
- Runtime visual-baseline guards for representative maze wall/pellet attributes and wall bitmap bytes.
- Sixteen topology-selected 8x8 wall-boundary bitmap variants for thin maze outlines.
- `src/pellets.asm` with persistent normal-pellet consumption.
- Per-pixel full-edge player collision checking.
- Deterministic Z80 regressions for pellet mutation and one-pixel wall-collision drift.
- Contention-aware `Render_Commit` performance harness using SkoolKit directly on raw assembled code.
- Fresh-48K TAP load simulation proving the generated tape reaches entry point `$8000`.
- GitHub Actions verification using pinned sjasmplus 1.23.1 and SkoolKit 10.1.
- Automatic per-commit GitHub Releases for verified `main` builds, including stable `pac48-latest.tap`, versioned TAP, checksums and build metadata.
- Persistent incident registry, V0-V5 verification protocol, rendering ADR and structured AI-agent TODO workflow.
- Kempston FIRE can now select Kempston control and start the game directly from the control-selection menu (`P48-029`).
- `src/hud.asm` 3x5 minifont build stamp rendered once in the free top gameplay band (`P48-030`).
- Generated `src/generated/build_info.asm` containing the canonical menu title, screenshot-visible build label, version text and exact seven-character Git build ID.
- `tools/check_build_identity.py` guards VERSION single-source behavior, build-label format/centering, startup stamp wiring and Kempston FIRE menu shortcut.
- GitHub Releases now include an immutable/cache-safe version+build TAP name such as `pac48-0.3.5-beta-b91E4FCD.tap` in addition to the convenience `pac48-latest.tap`.

### Changed

- Semantic version advanced to `0.3.5-beta`.
- `VERSION` is now the source for the generated menu title and versioned TAP names; `src/menu.asm` no longer hardcodes a version string (`P48-007`).
- Main loop commits prepared rendering immediately after `HALT`, then performs input/game update/render preparation outside the short screen-write phase.
- Startup draws the build/version stamp after `Video_Clear` + `Video_InitLineTable` and before the maze; the maze starts at pixel y=16 so the stamp does not overlap gameplay.
- Maze is drawn once at startup instead of being redrawn in full every gameplay frame.
- Dirty-cell restoration performs one bitmap+attribute cell draw instead of redundantly writing the attribute twice.
- Player module owns simulation only; raw screen drawing is owned by the renderer.
- Moving actors do not write Spectrum attributes in the render hot path.
- Wall presentation changed from solid blue PAPER cells to black PAPER + bright-blue bitmap boundaries derived from neighboring wall topology.
- Normal pellet art is a small 2x2 dot.
- Empty and pellet walkable cells retain yellow ink on black paper so the current yellow player remains visible without actor attribute writes.
- `Maze_CanMove` and wall-topology lookup share the canonical maze cell source.
- Buffered turns remain grid-based; a more arcade-like queued-turn model is now tracked under `P48-028` / `INC-2026-012`.
- Build pipeline generates build identity plus sprite assets, runs deterministic checks, assembles, executes Z80 runtime tests, profiles timing, creates generic/versioned/version+build TAP files and simulates loading the resulting TAP.
- Renderer chooses animation direction from persistent facing state rather than defaulting to right when movement stops.
- Obsolete handwritten actor phase tables were removed; generated phase tables are authoritative.
- Documentation-only GitHub pushes do not create redundant binary releases.
- Manual V3 diagnosis now prefers the version+build filename and visible `V<version> B<build>` screen stamp when cache ambiguity is possible (`INC-2026-010`).

### Fixed

- Preserved maze coordinates across attribute/bitmap drawing to prevent `DE` clobber corruption (`INC-2026-001`, `P48-001`).
- Fixed the S0 maze color-band regression where coordinate translation overwrote the intended Spectrum attribute (`INC-2026-008`, `P48-018`).
- Corrected the first attempted attribute-preservation repair after the runtime guard caught the wrong AF/DE stack order before release.
- Corrected Sinclair 1 and Sinclair 2 Interface 2 direction mappings (`INC-2026-002`, `P48-002`).
- Replaced the destructive runtime-shift actor path and removed full-maze redraw from the normal frame path (`INC-2026-003`).
- Prevented the stopped player from visually snapping to the right-facing animation when blocked.
- Hardened continuation collision by validating the advancing edge on every pixel step (`INC-2026-009`, `P48-024`).
- Normal pellets now disappear persistently when Pac traverses them (`P48-025`).
- Replaced the performance profiler's raw→snapshot→reload measurement path with deterministic direct-raw execution (`INC-2026-006`).
- Fixed GitHub Release post-publication verification after an unsupported CLI JSON field was used (`INC-2026-007`).

### Corrected verification record

- The previously reported "new visual regression" after collision/pellet integration was a false diagnosis caused by loading a stale/cached TAP (`INC-2026-010`).
- Owner V3 video of the correct gameplay build shows intact maze graphics, fluid Pac motion and pellets disappearing during traversal.
- The temporary rollback performed after the false report was reversed; collision and pellet code remain the active baseline.

### Current verification

Current code build verified by GitHub Actions run `32805223975`, commit `91e4fcdb944972cb38476f1e1e21ff6d613df4c3`:

- version: **0.3.5-beta**;
- build ID: **91E4FCD**;
- generated on-screen stamp: **`V0.3.5 B91E4FCD`**;
- canonical build: **PASS**;
- build-identity checks: **PASS**;
- sjasmplus assembly: **0 errors / 0 warnings**;
- headless 48K Z80 runtime harness: **PASS**, including collision and pellet regressions;
- renderer reference model: **PASS**;
- fresh 48K tape simulation reaches **PC=32768 ($8000)**;
- `Render_Commit`: **4341 / 5497 / 9184 T-states** for dirty1 / dirty2 / dirty4;
- BIN size: **8823 bytes** with **19849 bytes** conservative upper-RAM headroom;
- TAP size: **8903 bytes**;
- Release publication: **PASS**;
- release tag: `build-91e4fcdb9449`;
- preferred manual-test asset: `pac48-0.3.5-beta-b91E4FCD.tap`;
- TAP SHA-256: **d792d7765591dcbf435faf2d718ec200c35dcd7fffe99c01305ce5743025c12b**.

### V3 evidence

- `P48-018`: owner accepted the recovered visual baseline as a major improvement.
- `P48-025`: owner video visibly confirms normal pellets disappear while traversed.
- `P48-024`: current owner video does not visibly reproduce wall penetration, but explicit targeted confirmation remains desirable before closing the incident.
- `P48-029`: Kempston FIRE menu-start behavior is compiled/released and awaits owner V3 confirmation.
- `P48-030`: on-screen mini version/build stamp is compiled/released and awaits owner confirmation that it is readable and unobtrusive in the actual emulator/device view.

### Known limitations / next work

- Current maze has **18 unreachable pellet cells** in three isolated components (`INC-2026-011`, `P48-027`).
- Current junction input can feel stuck because simultaneous directions are collapsed with fixed priority and turns require exact node alignment (`INC-2026-012`, `P48-028`).
- Current maze topology is still the earlier generic layout; `P48-019` follows the connectivity correction.
- Pellet count, score, level completion, full score HUD, power pellets, ghost house, enemies, lives, bonus presentation and sound remain future work.
- Current renderer prepares/draws the player only; actor descriptor/dirty-cell support still needs extension to enemies.
- Current generated masks infer transparency from zero bits; future sprites needing opaque zero-valued pixels require explicit canonical mask support (`P48-016`).
- Actor color remains constrained by static Spectrum attributes; distinct per-ghost colors are deferred.
- Real-hardware V5 testing remains required before claiming hardware-tested release status.

## 0.3.4-beta

Baseline before the 2026-08-25 renderer architecture migration. The project already had menu/input abstraction, maze collision/rendering, pixel/sub-tile player movement and directional player animation.
