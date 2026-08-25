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
- Contention-aware `Render_Commit` performance harness using SkoolKit directly on raw assembled code.
- Fresh-48K TAP load simulation proving the generated tape reaches entry point `$8000`.
- GitHub Actions verification using pinned sjasmplus 1.23.1 and SkoolKit 10.1.
- Automatic per-commit GitHub Releases for verified `main` builds, including stable `pac48-latest.tap`, versioned TAP, checksums and build metadata.
- Persistent incident registry, V0-V5 verification protocol, rendering ADR and structured AI-agent TODO workflow.
- `src/pellets.asm` and a per-pixel collision implementation were developed experimentally; both are currently quarantined/rolled back from the playable runtime after `INC-2026-010`.

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
- Buffered direction changes remain grid-aligned in the current rollback baseline.
- Build pipeline generates assets, runs deterministic checks, assembles, executes Z80 runtime tests, profiles timing, creates TAP files and simulates loading the resulting TAP.
- Renderer chooses animation direction from persistent facing state rather than defaulting to right when movement stops.
- Obsolete handwritten actor phase tables were removed; generated phase tables are authoritative.
- Documentation-only GitHub pushes do not create redundant binary releases.
- After `INC-2026-010`, gameplay changes that affect rendering/collision/mutable maze state must be reintroduced one at a time with a unique per-commit V3 release before stacking the next change.

### Fixed

- Preserved maze coordinates across attribute/bitmap drawing to prevent `DE` clobber corruption (`INC-2026-001`, `P48-001`).
- Fixed the S0 maze color-band regression where coordinate translation overwrote the intended Spectrum attribute (`INC-2026-008`, `P48-018`).
- Corrected the first attempted attribute-preservation repair after the runtime guard caught the wrong AF/DE stack order before release.
- Corrected Sinclair 1 and Sinclair 2 Interface 2 direction mappings (`INC-2026-002`, `P48-002`).
- Replaced the destructive runtime-shift actor path and removed full-maze redraw from the normal frame path (`INC-2026-003`).
- Prevented the stopped player from visually snapping to the right-facing animation when blocked.
- Replaced the performance profiler's raw→snapshot→reload measurement path with deterministic direct-raw execution (`INC-2026-006`).
- Fixed GitHub Release post-publication verification after an unsupported CLI JSON field was used (`INC-2026-007`).

### Rolled back / quarantined

- The combined `P48-024` per-pixel collision + `P48-025` pellet-consumption integration was rolled back after the owner supplied a video showing the maze graphics completely corrupted while player motion remained fluid (`INC-2026-010`).
- `src/main.asm`, `src/player.asm`, `tests/runtime_harness.asm` and `tests/perf_harness.asm` were restored to the previously owner-accepted visual runtime.
- `src/pellets.asm` may remain in-tree as quarantined source but is not linked into the current game.
- `P48-024` and `P48-025` are blocked until the full startup-screen invariant `P48-026` is complete; they will then return separately, never in the same unverified batch.

### Current verification / rollback anchor

Rollback baseline verified by GitHub Actions run `32803411922`, commit `1765eb9128d9fa59b6e66121642af4b80fa5e494`:

- sjasmplus 1.23.1: **0 errors / 0 warnings**;
- headless SkoolKit 48K runtime harness: **PASS**;
- renderer reference model: **PASS**;
- binary size returned to **8279 bytes**;
- TAP size returned to **8359 bytes**;
- fresh 48K tape simulation reaches **PC=32768 ($8000)**;
- `Render_Commit` remains **4341 / 5497 / 9184 T-states** for dirty1 / dirty2 / dirty4;
- Release publication: **PASS**;
- release tag: `build-1765eb9128d9`;
- `pac48-latest.tap` SHA-256: **3310d2f2577b2f63174d2aa0e60951557def7835b593f6e75b536e8e8ec8adda**.

That TAP checksum is exactly the same as the previously owner-accepted visual build, making it the canonical rollback anchor.

### V3 evidence

- Owner screenshot after `P48-018` confirmed the recovered maze: no broad color bands, controls responsive, movement very fluid.
- Owner later video of the combined collision/pellet release showed an S0 visual regression; that release is rejected and must not be used as a baseline.
- Fresh V3 confirmation of rollback tag `build-1765eb9128d9` is required before `INC-2026-010` becomes `CLOSED`.

### Known limitations / next safety work

- Current rollback runtime intentionally does **not** contain pellet consumption or the experimental per-pixel collision fix.
- `P48-026` is now the highest-priority task: validate the full 28x20 startup attribute field and stronger deterministic whole-maze visual evidence before any gameplay reintroduction.
- Current maze topology is still the earlier generic layout; `P48-019` waits until collision and pellet changes have each passed separate V3 gates.
- Pellet count, score, level completion, HUD, power pellets, ghost house, enemies, lives, bonus presentation and sound remain future work.
- Current renderer prepares/draws the player only; actor descriptor/dirty-cell support still needs extension to enemies.
- Current generated masks infer transparency from zero bits; future sprites needing opaque zero-valued pixels require explicit canonical mask support (`P48-016`).
- Actor color remains constrained by static Spectrum attributes; distinct per-ghost colors are deferred.
- Real-hardware V5 testing remains required before claiming hardware-tested release status.

## 0.3.4-beta

Baseline before the 2026-08-25 renderer architecture migration. The project already had menu/input abstraction, maze collision/rendering, pixel/sub-tile player movement and directional player animation.
