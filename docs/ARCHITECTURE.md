# PAC48 Architecture

This document describes the architecture currently implemented in `main`.

- Coding-agent rules: `AGENTS.md`
- Canonical backlog: `docs/TODO.md`
- Rendering decision/research: `docs/adr/0001-rendering-architecture.md`
- Persistent incident/regression memory: `docs/INCIDENTS.md`
- Continuous development history: `CHANGELOG.md`

## Target machine

- ZX Spectrum 48K
- Zilog Z80
- `ORG 32768` (`$8000`)
- Bitmap screen at `$4000`
- Attribute memory at `$5800`
- Real 48K hardware compatibility mandatory
- No 128K banking or 128K-only runtime feature

Code, renderer state, generated sprite data, and lookup tables remain in upper RAM (`$8000+`). Screen RAM is contended and is touched only by bounded video/render work.

## Coordinate spaces

PAC48 uses distinct coordinate spaces and must not mix them implicitly.

### Maze coordinates

- `x = 0 .. Maze_Width-1`
- `y = 0 .. Maze_Height-1`
- current map: 28x20
- persistent collision/background state lives here

### Screen cell coordinates

- 32x24 cells
- one cell = 8x8 pixels
- maze offset: `Maze_OffsetX=2`, `Maze_OffsetY=2`

### Screen pixel coordinates

- 256x192 pixels
- `Pac_PixelX`, `Pac_PixelY` are player pixel coordinates
- movement is sub-cell while collision/turn decisions remain grid aligned

### Bitmap addresses

Raw ZX Spectrum display addresses are owned by video/render code only.

## Current startup

```text
DI
set stack
Menu_Run
Video_Clear
Video_InitLineTable
Maze_Draw                 # full persistent background once
Render_Init
Render_Prepare            # prepare first actor descriptor
EI
```

`Video_InitLineTable` fills a 192-entry (384-byte) table in upper RAM with the base bitmap address of every scanline.

## Current frame pipeline

```text
HALT
Render_Commit
Input_Read
Player_Update
Video_BeginFrame
Render_Prepare
Video_EndFrame
JP MainLoop
```

The order is intentional.

### Commit phase

`Render_Commit` performs bounded screen work:

1. restore maze cells touched by actors in the previously displayed frame;
2. draw the already-prepared masked player sprite;
3. promote the newly prepared dirty-cell list for the next commit.

### Update/prepare phase

After commit, the engine:

1. polls logical input;
2. updates player simulation/collision;
3. advances frame state;
4. selects animation frame and horizontal phase;
5. prepares the next sprite pointer/coordinates;
6. builds the next dirty-cell set.

This keeps gameplay/bookkeeping out of the time-critical screen-write phase.

## Persistent background model

`Maze_Map` is the source of truth for the playfield.

Maze cells currently represent:

- wall
- pellet
- empty path

Later cell types such as energizers, doors, spawn zones, or tunnels remain maze-owned.

`Maze_Draw` is a level/startup operation. Normal frames use `Maze_DrawCell` only for dirty restoration.

An arbitrary-position 8x8 actor touches at most four 8x8 maze cells. `render.asm` stores a bounded list of unique dirty cell coordinates rather than maintaining a framebuffer.

## Player simulation

`src/player.asm` owns simulation only:

- pixel position
- active/requested direction
- grid alignment
- candidate next tile
- maze collision requests
- synchronized maze coordinate

It contains no raw screen writes and does not choose a low-level renderer routine.

## Renderer

`src/render.asm` owns frame composition.

Current responsibilities:

- prepare player render descriptor (`x`, `y`, generated sprite pointer, horizontal phase);
- choose directional animation frame;
- build de-duplicated dirty-cell list;
- restore previous dirty cells from `Maze_Map`;
- composite masked 8x8 actor data;
- keep attributes outside the actor hot path.

Future enemies should extend the actor-descriptor/dirty-list model rather than draw directly.

## Sprite asset representation

Canonical player art remains in `src/sprites.asm`.

During `./tools/build.sh`, `tools/gen_shifted_sprites.py` generates:

```text
src/generated/pac_shifted.asm
```

for all 20 canonical directional frames.

Each frame expands to eight horizontal phases, giving 160 generated sprite phases total. Each generated scanline stores:

```text
maskL, imageL, maskR, imageR
```

The renderer uses:

```text
screen = (screen AND mask) OR image
```

The hot path performs no source-row bit shifting.

Generated assembly is ignored by Git and must never be edited manually.

## Screen-address lookup

`Video_LineAddrTable` contains 192 word addresses (384 bytes), initialized once at startup.

`Video_GetLineAddress` returns the byte-0 address for a pixel Y coordinate. The renderer then adds `x >> 3` for the screen byte column.

This removes repeated nonlinear Spectrum address calculations from the actor scanline loop.

## Attribute policy

Moving actors do not write attribute memory in the baseline renderer.

Current walkable cells use yellow ink on black paper for both pellet and empty states, so the yellow player remains visible while crossing cell boundaries. Walls remain maze-owned.

Distinct ghost colors are deferred until their clash/restoration policy is explicitly designed and measured.

## Input

`Input_Read` returns:

- `0` none
- `1` up
- `2` down
- `3` left
- `4` right

Physical paths:

- Q/A/O/P + cursor compatibility
- Kempston
- Sinclair 1
- Sinclair 2

Historical mapping failure and its regression guard are recorded in `INC-2026-002`.

## Register contracts

Public routines must document inputs, outputs, clobbers/preservation, and coordinate space.

The original maze coordinate corruption caused by implicit `DE` ownership is preserved as incident `INC-2026-001`. `Video_DrawTile`, `Maze_DrawTileAtOffset`, and `Maze_DrawAtOffset` now explicitly preserve the coordinate register contract relied on by callers.

## Build architecture

Canonical build:

```sh
./tools/build.sh
```

Pipeline:

1. generate masked pre-shifted sprite assembly;
2. validate maze and generated sprite structure;
3. assemble with `sjasmplus`;
4. enforce current binary/headroom budget;
5. create TAP and versioned TAP.

Current binary ceiling is 28,672 bytes from `$8000`, reserving 4 KiB of upper-RAM headroom for stack/runtime safety. This is a guardrail, not an assertion that all remaining RAM is otherwise free.

## Performance target

Primary presentation target: approximately 50 Hz.

ADR 0001 engineering targets:

- common-case `Render_Commit` around/below 12,000 T-states;
- roughly 14,000 T-states is a warning threshold;
- test worst case with planned actor count and dirty-cell count.

These timings are not yet verified and remain tracked by `P48-014`.

If a verified clean implementation cannot maintain stable 50 Hz, prefer a deliberate fixed 25 Hz mode over irregular frame collapse.

## Module ownership

- `src/main.asm` - entry/setup/frame orchestration only.
- `src/config.asm` - compile-time hardware/constants.
- `src/memory.asm` - persistent game/renderer state and line LUT storage.
- `src/menu.asm` - startup/control selection.
- `src/input.asm` - physical controls -> logical input.
- `src/video.asm` - low-level Spectrum screen primitives/address LUT.
- `src/maze.asm` - maze state/collision/background restoration.
- `src/player.asm` - player simulation only.
- `src/render.asm` - frame preparation/commit, dirty lists, masked composition.
- `src/sprites.asm` - canonical sprite/background bitmap data.
- `src/generated/pac_shifted.asm` - generated actor phase/mask data.
- future `src/enemy.asm` - enemy simulation only.

## Engineering memory system

Four files have intentionally different roles:

- `docs/TODO.md` - what remains and acceptance criteria;
- `docs/INCIDENTS.md` - failures/root causes/regression guards, retained permanently;
- `CHANGELOG.md` - what changed over time, updated continuously under `Unreleased`;
- `docs/adr/` - durable architecture decisions and rejected alternatives.

Agents must consult the incident registry before editing related modules. Resolved incidents are never deleted because they are part of the project's anti-regression memory.

## Optimization policy

Preferred order:

1. correct behavior;
2. verify dirty restoration/masked compositing;
3. measure T-states and memory;
4. optimize measured hot loops;
5. only then consider more aggressive Spectrum-specific techniques.

Beam racing, floating-bus synchronization, stack-as-screen rendering, broad self-modifying code, or a full software back buffer require a new ADR if proposed as core architecture.
