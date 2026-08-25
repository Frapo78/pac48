# PAC48 Architecture

This document distinguishes the **current implementation** from the **accepted target architecture**.

- Coding-agent rules: `AGENTS.md`
- Canonical backlog: `docs/TODO.md`
- Rendering decision and research: `docs/adr/0001-rendering-architecture.md`

## Target machine

- ZX Spectrum 48K
- Zilog Z80
- `ORG 32768` (`$8000`)
- Bitmap screen at `$4000`
- Attribute memory at `$5800`
- Real 48K hardware compatibility is mandatory
- No 128K banking or 128K-only runtime feature

Code and game data should remain in upper RAM (`$8000+`) unless a measured reason justifies another location. Screen RAM is contended and should be touched only by bounded video work.

## Coordinate spaces

PAC48 uses several coordinate spaces. They must not be mixed implicitly.

### Maze coordinates

- `x = 0 .. Maze_Width-1`
- `y = 0 .. Maze_Height-1`
- current map: 28x20
- persistent collision/background state lives here

### Screen cell coordinates

- 32x24 cells
- one cell = 8x8 pixels
- maze currently begins at `Maze_OffsetX=2`, `Maze_OffsetY=2`

### Screen pixel coordinates

- 256x192 pixels
- `Pac_PixelX`, `Pac_PixelY` are current player pixel coordinates
- actor movement may be sub-cell while collision decisions remain maze/tile based

### Bitmap addresses

Raw ZX Spectrum display addresses are a video-layer concern. Gameplay modules should not manipulate them directly.

## Current implementation

The code in `main` currently works approximately as follows:

```text
startup
  -> menu
  -> clear screen
  -> draw maze
  -> enable interrupts

frame
  -> HALT
  -> read input
  -> update player
  -> begin frame
  -> redraw complete maze
  -> draw player
  -> end frame
```

Current useful foundations:

- `Input_Read` abstracts keyboard/Kempston/Sinclair controls.
- `Pac_ReqDir` buffers requested direction.
- direction changes occur only when the player is aligned to the 8x8 grid.
- `Maze_CanMove` owns wall/out-of-map checks.
- player position is updated in pixels.
- directional 8x8 animation frames exist.
- `Video_DrawSpritePx` can position an 8x8 frame at arbitrary pixel X/Y.

Current rendering liabilities:

- the whole 28x20 maze is rebuilt every frame;
- sprite rows are shifted at runtime;
- `Video_DrawSpritePx` writes shifted bytes destructively rather than masking them over the background;
- the full-maze redraw is effectively being used as an expensive background restore mechanism;
- logic and time-critical screen work are not separated;
- attribute ownership for moving sprites is not stable.

These are migration targets, not design requirements.

## Accepted target architecture

ADR 0001 defines the target renderer. The important design is summarized here.

### Persistent background

`Maze_Map` is the source of truth for the playfield.

Maze cells own persistent state such as:

- wall
- pellet
- empty path
- later energizer/door/spawn/tunnel state

The full maze is drawn when a level starts. During gameplay only changed/touched cells are restored.

### Actor logic

Player and future enemy modules own simulation state only:

- pixel position
- logical direction
- requested direction
- animation state
- movement timers/speed
- collision decisions

After migration, gameplay modules should not draw themselves directly into screen RAM.

### Rendering layer

A dedicated `render.asm` module is the accepted destination for frame composition.

Responsibilities:

- maintain previous/current dirty-cell lists;
- build actor render descriptors;
- select animation frame and horizontal pre-shift phase;
- restore dirty maze cells;
- draw masked actor sprites;
- expose `Render_Prepare` and `Render_Commit` style interfaces.

`video.asm` remains lower level:

- screen clear
- attribute/tile primitive
- screen-line address table
- low-level masked scanline/cell routines

### Sprite representation

Actor sprites remain 8x8 at baseline.

Each canonical frame is expanded to eight horizontal phases for one-pixel movement. Each phase contains image and mask bytes suitable for:

```text
screen = (screen AND mask) OR image
```

The hot renderer must not perform repeated bit shifting for every sprite row.

Generated phase data should be reproducible at build time from compact source frames.

### Screen address lookup

Use a 192-entry table of screen-line base addresses (384 bytes).

The renderer obtains a line address from Y and adds `x >> 3` for the byte column. An aligned (`x & 7 == 0`) fast path is encouraged.

### Dirty restoration

An arbitrary-position 8x8 actor touches at most four 8x8 cells.

For each displayed frame:

1. retain the cells touched by actors;
2. at the next commit, redraw those cells from current `Maze_Map` state;
3. redraw cells whose persistent maze state changed;
4. draw the new actor sprites;
5. record the cells touched by the new actors.

Do not redraw the entire maze as a normal frame operation.

### Attribute policy

Baseline moving actors do not rewrite attributes each frame.

Walkable cells must have an attribute combination that keeps actor bitmap pixels visible. This intentionally prioritizes stable fast rendering over distinct per-actor colors.

Per-ghost colors are a later optional extension and must explicitly define clash and restoration behavior.

## Target frame pipeline

The accepted pipeline separates simulation/preparation from time-critical screen writes:

```text
Game_Init
Render_PrepareInitial

MainLoop:
    HALT
    Render_Commit
    Input_Read
    Game_Update
    Render_Prepare
    JP MainLoop
```

`Render_Commit` should do only bounded video-memory work using descriptors prepared in the previous frame.

`Game_Update`/`Render_Prepare` can spend the rest of the frame on uncontended game data without extending the critical video-write section.

The exact routine names may evolve. The phase separation is architectural.

## Timing target

Primary presentation target: approximately 50 Hz, one actor presentation per ULA interrupt.

Engineering budget for the baseline renderer:

- common-case `Render_Commit`: target <= about 12,000 T-states;
- roughly 14,000 T-states is a warning threshold for top-border-only rendering on a 48K timing model;
- measure worst case with player plus planned enemy count and maximum dirty-cell set.

If a clean dirty/preshift implementation cannot hold a stable 50 Hz rate after profiling, use a deliberate fixed 25 Hz mode rather than irregular frame-rate collapse.

## Module ownership

### `src/main.asm`

Entry point, include order, setup, high-level frame orchestration only.

### `src/config.asm`

Global compile-time hardware/constants only.

### `src/memory.asm`

Persistent game/runtime state. Do not silently reorder state that may be address-sensitive.

### `src/menu.asm`

Startup menu and control selection. Existing ROM text calls are tolerated only in the menu.

### `src/input.asm`

Physical keyboard/joystick polling to logical input enum. Gameplay must not read ports directly.

### `src/maze.asm`

Maze cell constants, `Maze_Map`, cell lookup, collision, cell/background restoration data.

### `src/player.asm`

Player simulation: position, requested direction, movement, animation choice. Direct drawing is legacy behavior to be removed during migration.

### `src/sprites.asm`

Canonical/generated sprite data and frame/phase tables. No gameplay logic.

### future `src/render.asm`

Frame composition, dirty lists, actor render descriptors, `Render_Prepare`, `Render_Commit`, masked sprite composition.

### future `src/enemy.asm`

Enemy simulation only. It should submit actor render data rather than owning low-level screen code.

## Register-interface rule

Every public assembly routine must document:

- inputs
- outputs
- clobbered registers
- preserved registers when callers rely on them
- coordinate space

Do not rely on undocumented preservation. The existing `DE` corruption finding in maze/video code is tracked as `P48-001` precisely because the interface contract was implicit.

## Optimization policy

Preferred order:

1. correct behavior;
2. dirty restoration;
3. pre-shifted masked sprites;
4. screen-line lookup table;
5. measure T-states;
6. optimize hot loops based on evidence.

Do not begin with beam racing, floating-bus synchronization, stack-as-screen rendering, broad self-modifying code, or a full software back buffer. Those techniques require a new ADR if profiling later proves they are necessary.

## Migration

The current engine is not to be rewritten in one step.

`docs/TODO.md` defines independently verifiable migration tasks. During the transition some legacy draw routines may remain, but new features must not add further dependence on:

- full-maze redraw each frame;
- runtime sprite shifting as the final hot path;
- destructive opaque byte writes for actors;
- direct screen ownership inside player/enemy logic.
