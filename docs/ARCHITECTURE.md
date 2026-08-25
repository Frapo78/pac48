# PAC48 Architecture

This document describes the architecture that exists in `main` now. It is not a wish list.

For prioritized work, see `docs/TODO.md`. For coding-agent rules, see `AGENTS.md`.

## Target

- Machine: ZX Spectrum 48K
- CPU: Zilog Z80
- Entry/load address: `ORG 32768`
- Screen bitmap: `16384` (`$4000`)
- Attribute memory: `22528` (`$5800`)
- Frame pacing: interrupts enabled after setup; gameplay loop begins with `HALT`
- Runtime language: Z80 assembly only

The game must remain compatible with real 48K hardware, not only emulators.

## Source modules

### `src/main.asm`

Owns program entry, include order, setup, and frame orchestration.

Current setup:

1. Disable interrupts.
2. Set stack.
3. Run control-selection menu.
4. Clear display.
5. Draw initial maze.
6. Enable interrupts.
7. Enter the gameplay loop.

Current frame loop:

```asm
HALT
CALL Input_Read
; non-zero input updates Pac_ReqDir
CALL Player_Update
CALL Video_BeginFrame
CALL Maze_Draw
CALL Player_Draw
CALL Video_EndFrame
JP MainLoop
```

Important: the full-maze redraw is current behavior, not the intended long-term rendering strategy. See `P48-003`.

### `src/config.asm`

Owns global hardware constants and color constants.

Do not put gameplay state here.

### `src/memory.asm`

Owns persistent runtime state.

Current important player state:

- `Pac_X`, `Pac_Y`: synchronized maze-tile position.
- `Pac_PixelX`, `Pac_PixelY`: screen pixel position used by current movement/rendering.
- `Pac_Dir`: active movement direction.
- `Pac_ReqDir`: buffered requested direction.
- `FrameCounter`: animation/frame state.
- `Input_Mode`: selected control scheme.
- `GameState`: allocated but not yet driving a complete state machine.

### `src/menu.asm`

Owns startup menu and input-mode selection.

The menu currently uses ZX ROM routines for clearing/printing. Active gameplay should not add new ROM-output dependencies.

### `src/input.asm`

Owns all keyboard and joystick polling.

Public contract:

```text
Input_Read -> A
0 = no direction
1 = up
2 = down
3 = left
4 = right
```

Gameplay code should consume this abstraction and must not poll hardware ports directly.

Known issue: Sinclair 1/2 direction mapping is currently incorrect. See `P48-002`.

### `src/video.asm`

Owns ZX bitmap/attribute addressing and drawing primitives.

Current relevant routines:

- `Video_Clear`
- `Video_BeginFrame`
- `Video_EndFrame`
- `Video_DrawTile`
- `Video_DrawSprite`
- `Video_DrawSpritePx`
- `Video_NextScanline`
- `Video_DrawTileForPixel`

There are two sprite coordinate modes:

1. `Video_DrawSprite`: 8x8 cell-aligned drawing.
2. `Video_DrawSpritePx`: pixel-positioned 8x8 drawing, including horizontal byte-boundary splitting.

This distinction is important: the player engine is no longer purely tile-rendered.

Register preservation is not universally implicit. Callers must rely on documented interfaces, not assumptions. `P48-001` exists because maze code currently reuses `DE` across a call that clobbers it.

### `src/sprites.asm`

Owns bitmap data and frame tables.

Current player animation already includes frame tables for:

- right
- left
- up
- down

Each referenced sprite frame is currently 8 bytes / 8x8 pixels.

### `src/maze.asm`

Owns:

- maze cell constants
- maze dimensions and offsets
- maze rendering
- single-cell restoration
- walkability checks
- persistent map bytes

Current map:

- width: 28 cells
- height: 20 cells
- render offset: `(2,2)` cells
- storage: one byte per cell

Current cell types:

- `Maze_CellPellet = 0`
- `Maze_CellWall = 1`
- `Maze_CellEmpty = 2`

`Maze_CanMove` accepts maze coordinates in `D/E` and returns `A=1` for walkable cells, `A=0` for wall/out-of-range.

Pellets are currently visual map data only; no consumption/scoring loop exists yet.

### `src/player.asm`

Owns player movement, requested-direction handling, grid alignment, collision requests, tile synchronization, restoration helpers, animation selection, and drawing.

The current movement model is pixel/sub-tile based:

1. Read `Pac_ReqDir`.
2. A requested turn may be accepted only while aligned to the 8x8 grid and if the next maze tile is walkable.
3. The active direction continues pixel by pixel.
4. At aligned positions, the next tile is revalidated through `Maze_CanMove`.
5. `Pac_PixelX` / `Pac_PixelY` change by one pixel per update.
6. `Pac_X` / `Pac_Y` are synchronized from the pixel position.
7. Drawing selects an 8-frame directional animation table and uses `Video_DrawSpritePx`.

This pixel movement is an intentional current capability and must not be replaced by tile-at-a-time movement as a casual refactor.

## Coordinate spaces

PAC48 currently uses three distinct coordinate spaces.

### Maze coordinates

Logical maze cells:

```text
x = 0 .. Maze_Width-1
y = 0 .. Maze_Height-1
```

Collision logic belongs here.

### Screen cell coordinates

ZX 8x8 character/attribute cells:

```text
x = 0 .. 31
y = 0 .. 23
```

Maze rendering applies `Maze_OffsetX` / `Maze_OffsetY` when converting maze coordinates to this space.

### Screen pixel coordinates

Used by current player movement/rendering.

`Pac_PixelX` and `Pac_PixelY` refer to screen pixel position, not maze-local pixel position. `Player_LoadTile` converts them back to maze cells by dividing by 8 and subtracting maze offsets.

Do not mix these coordinate spaces silently. Every new public routine should document which space it accepts/returns.

## Current rendering model

At startup the maze is drawn once, but the current frame loop redraws it again every frame and then draws the player.

That produces simple restoration behavior but is expensive because 560 map cells are processed every frame.

`player.asm` already contains restoration helpers that can redraw only nearby maze cells, which provides a migration path to dirty rendering. See `P48-003`.

Because the ZX Spectrum stores color attributes per 8x8 cell while the player can move at arbitrary pixel offsets, shifted sprites can span attribute boundaries. Walkable-cell attributes therefore need to remain compatible with player visibility. See `P48-004`.

## Input model

`Input_Mode` values:

- `0`: Q/A/O/P keyboard
- `1`: Kempston
- `2`: Sinclair 1
- `3`: Sinclair 2

A non-zero `Input_Read` result updates `Pac_ReqDir`; releasing controls does not immediately stop the player. This gives the player a buffered turn request similar to arcade maze movement.

Do not replace this with direct assignment to `Pac_Dir` unless intentionally changing control semantics.

## Build model

Canonical command:

```sh
./tools/build.sh
```

The script:

1. reads `VERSION`
2. requires `sjasmplus`
3. requires `bin2tap.py`
4. assembles `src/main.asm` into `build/pac48.bin`
5. wraps it into `build/pac48.tap`
6. creates a versioned TAP copy

For code changes, a successful build is the minimum verification level. Rendering, controls, timing, and loader changes also require emulator or real-hardware smoke testing.

## Architectural direction

Near-term work should stabilize the current engine rather than rewrite it.

Required order is tracked in `docs/TODO.md`, with the critical foundation currently being:

1. fix coordinate/register corruption (`P48-001`)
2. fix Sinclair mappings (`P48-002`)
3. replace per-frame full-maze redraw (`P48-003`)
4. stabilize attribute-cell behavior for pixel movement (`P48-004`)
5. only then expand the gameplay loop

The preferred evolution is incremental, buildable, and reversible at every step.
