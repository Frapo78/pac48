# AGENTS.md - PAC48

Machine-oriented rules for AI coding agents working on PAC48.

PAC48 targets the ZX Spectrum 48K in Z80 assembly. The current code is mid-migration from a full-maze-redraw/runtime-shift renderer to the performance architecture accepted in ADR 0001.

## Mandatory reading order

Before any code change read:

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. `docs/TODO.md`

`docs/TODO.md` is the canonical work queue. Do not reconstruct priority from chat, old PRs or stale roadmap prose.

## Task discipline

- Use stable `P48-###` IDs.
- Work the highest-priority unblocked task unless the user explicitly selects another.
- Do not silently broaden a task.
- Create a new task for newly discovered work.
- Do not renumber/reuse IDs.
- `DONE` requires implementation plus required verification.
- If code exists but runtime/profiling verification is missing, use `VERIFY`.

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

## Accepted rendering architecture

New rendering work must follow `docs/adr/0001-rendering-architecture.md`.

The target is:

- persistent tilemap-backed maze;
- full maze drawn once per level, not per frame;
- pixel/sub-tile actor movement retained;
- 8x8 masked software sprites;
- eight pre-shifted horizontal phases for one-pixel movement;
- generated image/mask data in upper RAM;
- 192-line screen-address lookup table;
- dirty-cell background restoration;
- dedicated `render.asm` module;
- preparation separated from short time-critical screen commit;
- approximately 50 Hz target until profiling proves a fixed 25 Hz design is preferable;
- moving actors do not own/rewrite attributes in the baseline renderer.

Legacy routines may remain during migration, but new features must not deepen dependence on:

- `Maze_Draw` every frame;
- runtime sprite-row shifting;
- destructive opaque actor byte writes;
- direct actor drawing from `player.asm`/future `enemy.asm`;
- a full software framebuffer.

## Optimization policy

Do not jump directly to exotic Spectrum tricks.

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

Manual equivalent:

```sh
mkdir -p build
sjasmplus --raw=build/pac48.bin src/main.asm
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap
```

Every code change:

1. must assemble/build;
2. must record missing tooling instead of claiming success when it was not run;
3. must run emulator/real-hardware checks when changing rendering, timing, controls, loader or gameplay;
4. must update the matching TODO verification notes.

Rendering work must ultimately be checked in a cycle-aware environment. Estimates are allowed during development but must be labelled estimates.

## Module ownership

### `src/main.asm`

Entry, include order, startup, frame orchestration. No feature logic beyond orchestration/transitions.

### `src/config.asm`

Global compile-time hardware/constants.

### `src/memory.asm`

Persistent mutable state. Do not casually reorder address-sensitive data.

### `src/menu.asm`

Startup/control-selection UI.

### `src/input.asm`

All physical keyboard/joystick reads. Public gameplay interface returns logical input; gameplay modules do not read ports.

### `src/video.asm`

Low-level Spectrum screen primitives and, after migration, screen-line address lookup data/routines. It should not own game rules.

### `src/maze.asm`

Maze cell constants/state, collision, lookup and background cell rendering/restoration.

### `src/player.asm`

Player simulation: pixel position, active/requested direction, movement and logical animation choice. Direct screen drawing is legacy and is scheduled for removal.

### `src/sprites.asm` / generated sprite include

Sprite data/tables only.

### future `src/render.asm`

Frame composition, dirty lists, actor descriptors, phase selection, `Render_Prepare`, `Render_Commit`, masked actor drawing.

### future `src/enemy.asm`

Enemy simulation only; submit render descriptors rather than drawing directly.

## Public routine contracts

Every public routine must comment:

- input registers/variables;
- output;
- clobbered registers;
- preserved registers when relied on;
- coordinate space.

Never assume undocumented register preservation. `P48-001` exists because implicit `DE` ownership caused a real rendering bug.

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

Keep keyboard, Kempston, Sinclair 1 and Sinclair 2 coherent.

## Maze rules

- `Maze_Map` contains exactly `Maze_Width * Maze_Height` cells.
- Maze state is the source of truth for persistent background.
- Pellet/energizer changes must be maze-owned, not arbitrary screen edits.
- `Maze_CanMove` owns wall/out-of-map decisions.

## Rendering invariants after migration

- Actor drawing uses `(screen AND mask) OR image` semantics.
- Horizontal phase is selected before the commit hot loop.
- Normal actor commit does not shift source rows at runtime.
- Normal actor commit does not change attributes.
- Dirty restoration happens before new actors are drawn.
- Actor clipping/wrap decisions happen outside the hot loop when possible.
- Renderer must know/record maximum dirty cells and actor count used for timing verification.

## Forbidden without explicit approval/new ADR

- changing `ORG 32768`;
- changing target away from 48K;
- replacing assembler/build system wholesale;
- rewriting the complete engine in one unverified step;
- making full-frame maze redraw the intended architecture;
- making a 6K/full-screen software back buffer the default renderer;
- relying on floating-bus/beam-racing behavior for correctness;
- putting gameplay rendering into ROM calls;
- changing to 128K-only sound/video features.

## Completion report

For each implementation task report:

- task ID;
- files changed;
- key interface/behavior change;
- build result;
- emulator/hardware result when required;
- timing/memory evidence when applicable;
- TODO status after the work.
