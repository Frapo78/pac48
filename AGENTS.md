# AGENTS.md - PAC48

Machine-oriented rules for AI coding agents working on PAC48.

PAC48 targets the ZX Spectrum 48K in Z80 assembly. The renderer architecture accepted in ADR 0001 is implemented in source and is awaiting full assembly/emulator/timing verification.

## Mandatory reading order

Before any code change read:

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. `docs/INCIDENTS.md`
5. `docs/TESTING.md`
6. `CHANGELOG.md`
7. `docs/TODO.md`

`docs/TODO.md` is the canonical work queue. `docs/INCIDENTS.md` is the persistent failure/regression memory. `docs/TESTING.md` defines the verification vocabulary and incident-closure evidence. Do not reconstruct priority or old mistakes from chat history when these files already contain the information.

## Task, incident, changelog, and verification discipline

- Use stable `P48-###` task IDs.
- Work the highest-priority unblocked task unless the user explicitly selects another.
- Do not silently broaden a task.
- Create a new task for newly discovered work.
- Do not renumber/reuse task IDs.
- `DONE` requires implementation plus required verification.
- If code exists but runtime/profiling verification is missing, use `VERIFY`.
- Before touching a module, scan `docs/INCIDENTS.md` for related historical failures and regression guards.
- Create/update an `INC-YYYY-NNN` record for subtle regressions, failed approaches, hardware/timing mistakes, or architecture failures that future agents could repeat.
- Never delete or renumber resolved incidents.
- Every substantive incident must end with a regression guard, not only a prose explanation.
- Update `CHANGELOG.md` under `Unreleased` for every meaningful code, build, architecture, verification, or documentation change.
- Report verification using V0-V5 from `docs/TESTING.md`; never describe `NOT RUN` as passed.

## Hard target constraints

- Machine: ZX Spectrum 48K.
- CPU: Zilog Z80.
- Entry/load address: `ORG 32768` (`$8000`).
- Do not change the load/start address without explicit approval and a new architecture decision.
- No 128K paging or 128K-only runtime dependency.
- No external Spectrum-side runtime libraries.
- Keep code/game data in upper RAM (`$8000+`) by default.
- Screen bitmap: `$4000-$57ff`.
- Attributes: `$5800-$5aff`.
- Avoid new ROM dependencies during gameplay. Existing menu ROM printing is legacy/tolerated.
- Real 48K hardware compatibility matters more than emulator-specific tricks.

## Current rendering architecture

Source follows `docs/adr/0001-rendering-architecture.md`:

- persistent tilemap-backed maze;
- full maze drawn once at level/startup, not per frame;
- pixel/sub-tile player movement retained;
- 8x8 masked software sprites;
- eight build-generated pre-shifted horizontal phases for one-pixel movement;
- generated image/mask data assembled in upper RAM;
- 192-line screen-address lookup table;
- dirty-cell background restoration;
- dedicated `src/render.asm` module;
- `Render_Prepare` separated from short `Render_Commit`;
- moving actors do not own/rewrite attributes in the baseline renderer;
- approximately 50 Hz target until profiling proves a fixed 25 Hz design is preferable.

The following legacy patterns must not be reintroduced into the normal actor path:

- `Maze_Draw` every frame;
- runtime sprite-row shifting;
- destructive opaque actor byte writes;
- direct actor drawing from `player.asm`/future `enemy.asm`;
- a full software framebuffer as the default solution.

## Optimization policy

Baseline optimization order:

1. correctness;
2. module ownership;
3. dirty restoration;
4. pre-shifted masked sprites;
5. screen-line lookup table;
6. profile T-states and memory;
7. optimize measured hot loops.

Beam racing, floating-bus synchronization, stack-as-screen drawing, large self-modifying/generated runtime render code, or full-screen double buffering require explicit justification and a new ADR if proposed as core architecture.

## Build and verification

Canonical build:

```sh
./tools/build.sh
```

The build performs these mandatory layers:

1. generate `src/generated/pac_shifted.asm` from canonical frames in `src/sprites.asm`;
2. structurally validate maze and generated sprite data;
3. assemble `src/main.asm` with `sjasmplus`;
4. enforce the current upper-RAM binary/headroom ceiling;
5. create normal and versioned TAP files.

Do not invoke `sjasmplus src/main.asm` from a clean checkout before generating the sprite include. Prefer the canonical build script.

For every code change:

1. run V0 static/source review;
2. run V1 deterministic checks where applicable;
3. run `./tools/build.sh` (V2) when required tools exist;
4. record the exact missing tool when V2 cannot run;
5. run V3 emulator/real-hardware checks when changing rendering, controls, loader or gameplay;
6. run V4 cycle-aware checks for renderer performance work;
7. update matching TODO verification notes;
8. update incident verification evidence when the work relates to an existing incident;
9. update `CHANGELOG.md`.

Rendering work must ultimately be checked in a cycle-aware environment. Estimates are allowed during development but must be labelled estimates.

## Module ownership

### `src/main.asm`

Entry, include order, startup, frame orchestration. No feature logic beyond orchestration/transitions.

Current frame order is intentionally:

```text
HALT
Render_Commit
Input_Read / Player_Update
Video_BeginFrame
Render_Prepare
```

Do not move expensive gameplay work back into the commit phase without measured justification.

### `src/config.asm`

Global compile-time hardware/constants.

### `src/memory.asm`

Persistent mutable state, renderer descriptors, dirty buffers, and line-address table storage. Do not casually reorder address-sensitive data.

### `src/menu.asm`

Startup/control-selection UI.

### `src/input.asm`

All physical keyboard/joystick reads. Public gameplay interface returns logical input; gameplay modules do not read ports.

Historical warning: see `INC-2026-002` before editing Sinclair mappings.

### `src/video.asm`

Low-level Spectrum screen primitives and screen-line lookup initialization/access. It must not own game rules or actor animation selection.

Historical warning: see `INC-2026-001` for register-preservation requirements.

### `src/maze.asm`

Maze cell constants/state, collision, lookup and background cell rendering/restoration. Maze state is the persistent source of truth for background restoration.

### `src/player.asm`

Player simulation only: pixel position, active/requested direction, movement and collision decisions. It must not write raw screen memory or call actor drawing routines.

### `src/render.asm`

Frame composition, dirty lists, player/actor descriptors, phase/frame selection, `Render_Prepare`, `Render_Commit`, and masked actor composition.

### `src/sprites.asm`

Canonical human/AI-editable sprite frames and simple background sprites.

### `src/generated/pac_shifted.asm`

Generated build artifact. Never edit manually. Change canonical frames or `tools/gen_shifted_sprites.py` instead.

### future `src/enemy.asm`

Enemy simulation only; submit/extend render descriptors rather than drawing directly.

## Public routine contracts

Every public routine must comment:

- input registers/variables;
- output;
- clobbered registers;
- preserved registers when relied on;
- coordinate space.

Never assume undocumented register preservation. `INC-2026-001` exists because implicit `DE` ownership caused a real rendering bug.

## Coordinate rules

- Maze coordinates: cell index inside 28x20 maze.
- Screen-cell coordinates: 32x24 cells.
- Screen-pixel coordinates: 256x192.
- Bitmap addresses: video/render concern only.

Current player movement uses pixel coordinates and grid-aligned collision/turn decisions. Do not revert to tile-at-a-time movement as an incidental refactor.

## Input interface

`Input_Read` direction enum remains:

- `0` none
- `1` up
- `2` down
- `3` left
- `4` right

Keep keyboard, Kempston, Sinclair 1 and Sinclair 2 coherent. Sinclair physical mappings are documented in `src/input.asm` and incident `INC-2026-002`.

## Maze rules

- `Maze_Map` contains exactly `Maze_Width * Maze_Height` cells; build tooling enforces 20 rows x 28 cells.
- Maze state is the source of truth for persistent background.
- Pellet/energizer changes must be maze-owned, not arbitrary screen edits.
- `Maze_CanMove` owns wall/out-of-map decisions.
- `Maze_Draw` is an initialization/level-redraw operation, not a normal per-frame operation.
- Dirty restoration should perform the minimum required screen writes; do not reintroduce duplicate attribute writes.

## Rendering invariants

- Actor drawing uses `(screen AND mask) OR image` semantics.
- Horizontal phase is selected during prepare, before the commit hot loop.
- Normal actor commit does not shift source rows at runtime.
- Normal actor commit does not change attributes.
- Dirty restoration happens before new actors are drawn.
- Actor clipping/wrap decisions happen outside the hot loop when possible.
- Generated sprite data uses `maskL,imageL,maskR,imageR` for each of 8 rows.
- Renderer must know/record maximum dirty cells and actor count used for timing verification.
- `Pac_FacingDir` preserves visual facing independently from `Pac_Dir` stopping at a wall.

## Generated-asset rules

`tools/gen_shifted_sprites.py` is part of the engine architecture, not optional convenience tooling.

- Canonical player art stays in `src/sprites.asm`.
- Generated assembly is deterministic and ignored by Git.
- A clean build must recreate all generated data before assembly.
- Generated phase pointer tables are authoritative; do not restore parallel hand-written mobile-actor tables.
- Current masks infer transparency from zero bits in canonical Pac bitmaps. Before introducing art requiring opaque zero-valued pixels, implement `P48-016` explicit canonical mask support.
- If changing generator layout, update renderer expectations, structural checks, ADR/docs, TODO, incidents when relevant, and changelog together.

## Forbidden without explicit approval/new ADR

- changing `ORG 32768`;
- changing target away from 48K;
- replacing assembler/build system wholesale;
- rewriting the complete engine in one unverified step;
- restoring full-frame maze redraw as intended architecture;
- making a 6K/full-screen software back buffer the default renderer;
- relying on floating-bus/beam-racing behavior for correctness;
- putting gameplay rendering into ROM calls;
- changing to 128K-only sound/video features.

## Completion report

For each implementation task report:

- task ID;
- files changed;
- key interface/behavior change;
- V0-V5 verification results;
- emulator/hardware result when required;
- timing/memory evidence when applicable;
- incident IDs affected/created;
- changelog update;
- TODO status after the work.
