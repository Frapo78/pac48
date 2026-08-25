# AGENTS.md - PAC48

Machine-oriented instructions for AI coding agents working on PAC48.

PAC48 is a Pac-Man-like game engine for the ZX Spectrum 48K, written entirely in Z80 assembly. The current engine already has menu/input abstraction, maze collision/rendering, buffered direction changes, pixel/sub-tile player movement, and directional 8x8 animation. Pellet consumption, scoring, enemies, lives, full game states, and sound are still incomplete.

## Mandatory reading order

Before making a code change, read:

1. `AGENTS.md` — hard rules and module ownership.
2. `docs/ARCHITECTURE.md` — current implementation, coordinate spaces, and runtime pipeline.
3. `docs/TODO.md` — canonical prioritized work queue and acceptance criteria.

Do not reconstruct priorities from old commits, README roadmap prose, or chat history when `docs/TODO.md` already contains the task.

## TODO discipline

`docs/TODO.md` is the source of truth for planned technical work.

For each task:

- Use its stable `P48-###` ID in commits/PRs when practical.
- Work highest priority first unless the user explicitly requests another task.
- Do not mark a task `DONE` until its acceptance criteria and required verification are complete.
- If code is implemented but emulator/hardware verification is still required, use `VERIFY`, not `DONE`.
- Add newly discovered work as a new stable task instead of silently expanding scope.
- Never renumber or reuse task IDs.
- Update the task record when implementation changes the known state of the repository.

## Hard target constraints

- Target machine: ZX Spectrum 48K only.
- CPU: Zilog Z80.
- Entry point: `ORG 32768` in `src/main.asm`.
- Do not change the load/start address.
- Do not use 128K memory banking or other 128K-only features.
- Do not introduce external runtime libraries.
- Avoid ROM calls in gameplay code. Existing menu code uses ROM print/CLS; do not add new gameplay ROM dependencies unless explicitly requested.
- Screen bitmap begins at `SCREEN_ADDR=16384` (`$4000`).
- Attribute memory begins at `ATTR_ADDR=22528` (`$5800`).
- Current player movement is pixel/sub-tile based. Do not revert it to tile-at-a-time movement as a casual refactor.
- Keep behavior compatible with real hardware, not only emulators.

## Build and verification

Canonical build command:

```sh
./tools/build.sh
```

Manual equivalent:

```sh
mkdir -p build
sjasmplus --raw=build/pac48.bin src/main.asm
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap
```

Required tools:

- `sjasmplus`
- `bin2tap.py` from SkoolKit

For every code change:

1. Assemble with `./tools/build.sh` at minimum.
2. If tools are missing, report the exact missing command and do not claim the task fully verified.
3. Rendering, input, loader, timing, and gameplay changes require an emulator or real-hardware smoke test when the task acceptance criteria call for it.
4. Record verification evidence in the corresponding `docs/TODO.md` task.

## Current file ownership

Keep responsibilities isolated and modify the smallest correct module.

### `src/main.asm`

Owns `ORG 32768`, include order, boot sequence, and frame orchestration.

Do not put feature logic here unless it is orchestration/state transition logic.

### `src/config.asm`

Owns global compile-time constants such as hardware ports, screen addresses, and colors.

Do not put mutable game state here.

### `src/memory.asm`

Owns persistent runtime state.

Current important state includes:

- `FrameCounter`
- `GameState`
- `Pac_X`, `Pac_Y`
- `Pac_PixelX`, `Pac_PixelY`
- `Pac_Dir`
- `Pac_ReqDir`
- `Input_Mode`

Add variables here only when state must persist across calls/frames. Do not silently reorder existing state if address stability could matter.

### `src/menu.asm`

Owns startup menu, control selection, and menu-facing text.

The menu sets `Input_Mode` and resets player direction state.

### `src/input.asm`

Owns keyboard/joystick polling.

Public routine:

```text
Input_Read
A=0 none
A=1 up
A=2 down
A=3 left
A=4 right
```

Gameplay modules must not poll keyboard or joystick ports directly.

Known active task: Sinclair 1/2 mapping is incorrect; see `P48-002`.

### `src/video.asm`

Owns screen clearing, bitmap/attribute address calculations, frame hooks, tile drawing, cell-aligned sprites, and pixel-positioned sprites.

Current relevant routines include:

- `Video_Clear`
- `Video_BeginFrame`
- `Video_EndFrame`
- `Video_DrawTile`
- `Video_DrawSprite`
- `Video_DrawSpritePx`
- `Video_NextScanline`
- `Video_DrawTileForPixel`

Keep raw ZX bitmap addressing here.

Do not assume registers are preserved unless the routine contract says so. Current maze rendering has a known `DE` preservation bug tracked as `P48-001`.

### `src/sprites.asm`

Owns sprite bitmap data and frame tables.

Current player animation already has tables for right, left, up, and down. Sprite frames are currently 8x8 / 8 bytes each.

### `src/maze.asm`

Owns maze constants, cell types, map data, rendering, single-cell restoration, and collision/walkability.

Current map:

- `Maze_Width=28`
- `Maze_Height=20`
- `Maze_OffsetX=2`
- `Maze_OffsetY=2`

Current cell types:

- `Maze_CellPellet=0`
- `Maze_CellWall=1`
- `Maze_CellEmpty=2`

Pellet state changes must be owned through maze routines rather than unrelated direct writes.

### `src/player.asm`

Owns player movement, requested-direction handling, alignment checks, collision requests, pixel/tile synchronization, restoration helpers, animation selection, and player drawing.

Do not poll input directly here; consume `Pac_ReqDir` / `Pac_Dir` state set by orchestration.

## Include and symbol rules

`src/main.asm` is the only assembly entry file.

Keep include order intentional:

1. `config.asm`
2. `memory.asm`
3. `menu.asm`
4. `input.asm`
5. `video.asm`
6. `sprites.asm`
7. `maze.asm`
8. `player.asm`

Rules:

- Do not duplicate routines between modules.
- Do not create duplicate public labels with different meanings.
- Use module-prefixed public names such as `Maze_`, `Player_`, `Video_`, `Input_`.
- Local sjasmplus dot-labels are fine when scoped and readable.
- Add a new module only when responsibility is substantial and clearly distinct.

## Register interface rules

Every new or changed public routine must document:

- input registers/state
- output registers/state
- clobbered registers
- preserved registers when relied on
- coordinate space

Important current interfaces:

### `Input_Read`

Output: `A=direction`, enum `0..4` as documented above.

### `Maze_CanMove`

Input: `D=x`, `E=y` in maze coordinates.

Output: `A=1` walkable, `A=0` blocked/outside map.

### `Video_DrawTile`

Input: `D=x`, `E=y` in screen cell coordinates, `A=attribute`.

Do not assume `DE` survives this call unless the implementation contract is explicitly changed and documented.

### `Video_DrawSprite`

Input: `D=x`, `E=y` in screen cell coordinates, `HL=sprite_ptr`, `A=attribute`.

### `Video_DrawSpritePx`

Input: `D=x`, `E=y` in screen pixel coordinates, `HL=sprite_ptr`, `A=attribute`.

This is the current player drawing path.

### `Maze_DrawAtOffset`

Input: `D=x`, `E=y` in maze coordinates, `HL=sprite_ptr`, `A=attribute`.

Applies maze cell offsets before calling video code.

## Coordinate spaces

Never mix these silently.

### Maze coordinates

Logical cells:

```text
x=0..Maze_Width-1
y=0..Maze_Height-1
```

### Screen cell coordinates

8x8 ZX cells:

```text
x=0..31
y=0..23
```

### Screen pixel coordinates

Used by `Pac_PixelX`, `Pac_PixelY`, and `Video_DrawSpritePx`.

`Player_LoadTile` converts screen pixel coordinates back into maze coordinates by dividing by 8 and subtracting maze offsets.

## Current gameplay pipeline

Current `main.asm` behavior is conceptually:

```asm
HALT
CALL Input_Read
; if A != 0, store requested direction in Pac_ReqDir
CALL Player_Update
CALL Video_BeginFrame
CALL Maze_Draw
CALL Player_Draw
CALL Video_EndFrame
JP MainLoop
```

Important implications:

- Input is frame-polled.
- Releasing input does not stop movement immediately; the last active direction continues.
- `Pac_ReqDir` buffers turns.
- Requested turns are accepted only when the player is grid-aligned and the destination tile is walkable.
- Player position moves one pixel per update.
- The whole maze is currently redrawn every frame; this is known technical debt, not a desired permanent design. See `P48-003`.

## Rendering rules

- Gameplay sprites must not use ROM character output.
- Use video-module drawing primitives.
- Pixel movement crosses 8x8 bitmap/attribute boundaries, so ZX attribute color behavior must be considered explicitly.
- Do not solve color clash by adding broad new rendering complexity before evaluating the uniform walkable-cell attribute strategy in `P48-004`.
- Avoid full-screen or full-maze clears/redraws during steady gameplay once `P48-003` is implemented.

## Input rules

- Keep `Input_Mode` abstraction intact.
- Keep `Input_Read` direction enum stable unless a deliberate API change is approved.
- Fire/start/pause may extend input through clearly named routines or a documented bitfield.
- Keyboard, Kempston, Sinclair 1, and Sinclair 2 paths must remain independently testable.

## Maze rules

- Maintain exactly `Maze_Width * Maze_Height` map cells.
- `Maze_CanMove` must block walls and out-of-map positions.
- New cell types belong in maze ownership.
- Pellet consumption should mutate maze state through maze-owned routines.
- Tunnels/wrap behavior, if added, must be explicit in collision and coordinate conversion logic.

## Player rules

- Preserve current pixel/sub-tile movement unless explicitly redesigning it.
- Direction changes should remain buffered through `Pac_ReqDir` and accepted at valid grid alignment.
- Maze collision stays in maze routines; do not duplicate map lookup in player code.
- Persistent player timers/animation/gameplay state belong in `memory.asm`.

## Enemy rules

When enemies are added:

- Persistent enemy state belongs in `memory.asm`.
- A substantial enemy system may justify `src/enemy.asm`.
- Enemies must use maze collision routines rather than duplicating maze lookup.
- Start with one deterministic enemy before multiple personalities.
- Do not add complex pathfinding before the core gameplay loop is stable.

## Game state rules

`GameState` exists but does not yet drive a complete state machine.

When implementing states:

- Define named constants instead of scattering magic numbers.
- Centralize transitions or give them one clear owner.
- Avoid letting menu, player, maze, and enemy modules mutate global state independently.

## Memory and performance rules

- Treat RAM and CPU time as constrained.
- Prefer compact byte state and tables.
- Avoid stack-heavy inner loops when simpler register usage is possible.
- Avoid `IX`/`IY` unless their benefit justifies cost.
- Do not add large buffers without a measured reason.
- Do not add self-modifying code casually.
- Keep interrupt behavior simple and deterministic.

## Style rules

- Keep source ASCII unless an existing file requires otherwise.
- Comment interfaces, hardware assumptions, and non-obvious address math.
- Do not narrate trivial instructions line by line.
- Prefer named constants over repeated magic numbers.
- Avoid unrelated formatting churn.

## Forbidden changes without explicit user approval

- Changing `ORG 32768`.
- Replacing sjasmplus/build system.
- Introducing C or another runtime language.
- Adding 128K-only features.
- Rewriting the whole engine.
- Moving all state/data into one monolithic file.
- Broad memory-layout refactors.
- Reverting pixel movement to tile-at-a-time movement.
- Adding emulator-specific runtime behavior.
- Adding ROM calls to active gameplay.
- Guessing the exact GPL version; see `P48-006`.

## Agent execution workflow

For each implementation task:

1. Select/read the relevant `P48-###` task.
2. Inspect all affected modules.
3. Confirm coordinate/register interfaces.
4. Make the smallest coherent change.
5. Build with `./tools/build.sh`.
6. Run task-specific emulator/hardware checks when required.
7. Update `docs/TODO.md` status, acceptance checkboxes, and verification notes.
8. Update `docs/ARCHITECTURE.md` if the actual architecture changed.
9. Report changed files, build result, verification performed, and remaining limitations.

If implementation reveals a separate problem, create a new TODO ID rather than hiding it inside the current task.

## Current high-priority queue

Do not duplicate the full backlog here. The canonical details are in `docs/TODO.md`.

Current foundation order:

1. `P48-001` — preserve maze coordinates across attribute drawing.
2. `P48-002` — correct Sinclair joystick direction mapping.
3. `P48-003` — remove full-maze redraw from every gameplay frame.
4. `P48-004` — stabilize pixel movement across ZX attribute cells.
5. `P48-009` — begin complete gameplay loop only after the foundation is stable.
