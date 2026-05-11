# AGENTS.md - PAC48

Machine-oriented instructions for AI coding agents working on PAC48.

PAC48 is a Pac-Man-like game for ZX Spectrum 48K, written entirely in Z80 assembly. The project is currently an incremental engine skeleton: menu, input abstraction, attribute-cell maze rendering, tile-based player movement, and 8x8 sprite data exist; pellet consumption, scoring, enemies, lives, sound, and complete game states are still to be implemented.

## Hard Target Constraints

- Target machine: ZX Spectrum 48K only.
- CPU: Zilog Z80.
- Entry point: `ORG 32768` in `src/main.asm`.
- Do not change the load/start address.
- Do not use 128K features, memory banking, AY-only assumptions, or external runtime libraries.
- Avoid ROM calls in gameplay code. Existing menu code currently uses ROM print/CLS; do not add new ROM dependencies unless the user explicitly requests it.
- Screen model: ZX Spectrum bitmap at `SCREEN_ADDR` plus attributes at `ATTR_ADDR`.
- Current renderer uses 8x8 cell-aligned sprites and attribute cells.
- Current gameplay position model is tile-based, using map coordinates, not pixels.

## Build And Verification

Preferred build command:

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

Every code change should be verified at least by assembling. If the tools are missing, report that verification was not possible and include the exact missing command.

## Current File Ownership

Keep responsibilities isolated. Modify the smallest correct module.

- `src/main.asm`
  - Owns `ORG 32768`, include order, boot sequence, and main loop.
  - Calls menu, input, update, and draw routines.
  - Do not put feature logic here unless it is orchestration only.

- `src/config.asm`
  - Owns global constants: ports, screen addresses, colors, fixed hardware constants.
  - Add only compile-time constants that are genuinely global.

- `src/memory.asm`
  - Owns RAM variables and persistent game state.
  - Add new variables here only when state must persist across frames or modules.
  - Do not silently reorder existing variables if other code relies on addresses.

- `src/menu.asm`
  - Owns start menu, control selection, and menu-facing text.
  - Existing code sets `Input_Mode` and resets `Pac_Dir`.
  - Keep menu input separate from gameplay input unless intentionally refactoring the menu.

- `src/input.asm`
  - Owns keyboard/joystick polling.
  - Public routine: `Input_Read`.
  - `Input_Read` returns direction in `A`: `0=none`, `1=up`, `2=down`, `3=left`, `4=right`.
  - Gameplay modules must not read keyboard or joystick ports directly.

- `src/video.asm`
  - Owns screen clearing, frame hooks, tile attributes, and cell-aligned sprite drawing.
  - Public routines currently include `Video_Clear`, `Video_BeginFrame`, `Video_EndFrame`, `Video_DrawSprite`, `Video_DrawTile`.
  - Keep ZX Spectrum bitmap addressing logic here.

- `src/maze.asm`
  - Owns maze constants, map data, map rendering, and map collision.
  - Public routines currently include `Maze_Draw`, `Maze_DrawAtOffset`, `Maze_CanMove`.
  - Current map size is `Maze_Width=28`, `Maze_Height=20`, rendered with offsets `Maze_OffsetX=2`, `Maze_OffsetY=2`.
  - Add maze cell types here when implementing pellets, energizers, doors, tunnels, or spawn zones.

- `src/player.asm`
  - Owns player movement, player collision requests, animation choice, and player drawing.
  - Current state variables are `Pac_X`, `Pac_Y`, `Pac_Dir`.
  - Do not poll input directly here; consume `Pac_Dir` set by the main loop.

- `src/sprites.asm`
  - Owns sprite bitmap data and sprite frame tables.
  - Current sprites are 8 bytes per 8x8 cell-aligned sprite.
  - README may mention `assets/sprites.asm`, but the actual included file is currently `src/sprites.asm`; keep include paths consistent with `src/main.asm`.

## Include And Symbol Rules

- `src/main.asm` is the only assembly entry file.
- Keep include order intentional:
  1. `config.asm`
  2. `memory.asm`
  3. `menu.asm`
  4. `input.asm`
  5. `video.asm`
  6. `sprites.asm`
  7. `maze.asm`
  8. `player.asm`
- If a module depends on symbols from another module, prefer constants/routines that already exist.
- Do not copy routines between modules.
- Do not create duplicate labels with different local meaning.
- Use stable public routine names with module prefixes, e.g. `Maze_`, `Player_`, `Video_`, `Input_`.
- Local labels may use sjasmplus dot-label style when scoped and readable.

## Register Interface Rules

Preserve and document routine calling conventions.

Current important interfaces:

- `Input_Read`
  - Output: `A=direction`.
  - Direction enum: `0 none`, `1 up`, `2 down`, `3 left`, `4 right`.

- `Maze_CanMove`
  - Input: `D=x`, `E=y` in maze coordinates.
  - Output: `A=1` if walkable, `A=0` if blocked or outside map.

- `Video_DrawTile`
  - Input: `D=x`, `E=y` in screen attribute-cell coordinates, `A=attribute`.

- `Video_DrawSprite`
  - Input: `D=x`, `E=y` in screen cell coordinates, `HL=sprite_ptr`, `A=attribute`.
  - Sprite format: 8 bytes, one byte per bitmap row.

- `Maze_DrawAtOffset`
  - Input: `D=x`, `E=y` in maze coordinates, `HL=sprite_ptr`, `A=attribute`.
  - Applies `Maze_OffsetX` and `Maze_OffsetY`, then draws through video code.

When adding routines, state inputs, outputs, clobbered registers, and coordinate space in comments directly above the routine.

## Coordinate Spaces

Distinguish these explicitly:

- Maze coordinates: `x=0..Maze_Width-1`, `y=0..Maze_Height-1`.
- Screen cell coordinates: `x=0..31`, `y=0..23`.
- Bitmap addresses: raw ZX Spectrum screen memory; only video routines should manipulate these directly.

Player and maze logic should use maze coordinates. Rendering routines should convert to screen cell coordinates using maze offsets.

## Current Gameplay Pipeline

The main loop currently does:

```asm
HALT
CALL Input_Read
LD (Pac_Dir), A
CALL Player_Update
CALL Video_BeginFrame
CALL Maze_Draw
CALL Player_Draw
CALL Video_EndFrame
JP MainLoop
```

Implications:

- `Input_Read` is frame-polled.
- Movement currently happens once per frame if a direction is held.
- The whole maze is redrawn every frame.
- Player is drawn after the maze.
- No dirty-rectangle system exists yet.

Do not introduce a radically different loop unless the user specifically asks for engine restructuring. Prefer incremental changes.

## Implementation Priorities

When asked to complete the game, implement in small, independently buildable steps:

1. Stabilize constants and state names.
2. Add pellet state and pellet consumption.
3. Add score and lives variables.
4. Add a HUD renderer using attribute/sprite primitives or a dedicated text routine.
5. Add player animation frames for all directions.
6. Add enemy state variables and one enemy update routine.
7. Add enemy collision with player.
8. Add simple enemy AI using maze coordinates.
9. Add game states: menu, playing, life lost, game over, level complete.
10. Add sound effects only after core gameplay works.
11. Optimize rendering only after behavior is correct.

Each step must assemble before moving to the next.

## Pac-Man-Like Feature Guidance

This project should be inspired by Pac-Man mechanics, not a binary clone of original arcade code.

Expected mechanics:

- Tile maze with walls and paths.
- Player moves through walkable cells.
- Pellets disappear when collected.
- Score increases on collection.
- Enemies move through the maze.
- Contact with enemy costs a life unless an energizer mode is implemented.
- Level completes when all pellets are collected.

Keep behavior deterministic and simple first. Avoid complex AI until there is a verified gameplay loop.

## Memory And Performance Rules

- Treat 48K RAM as constrained.
- Prefer compact tables and byte variables.
- Avoid unnecessary full-screen clears during gameplay.
- Avoid stack-heavy routines inside per-tile loops.
- Do not allocate large buffers unless justified.
- Do not add self-modifying code unless explicitly requested or clearly documented.
- Be careful with `IX`/`IY`; they are slower on Z80 and should only be used when useful.
- Keep interrupt behavior simple. Current code enables interrupts after menu setup and uses `HALT` for frame pacing.

## Rendering Rules

- Attribute address range starts at `ATTR_ADDR=22528`.
- Bitmap address range starts at `SCREEN_ADDR=16384`.
- Current sprite drawing assumes 8x8 cell alignment.
- Do not draw gameplay sprites with ROM character output.
- Use `Video_DrawSprite` or add new video routines in `src/video.asm`.
- If adding directional player frames, store bitmap data in `src/sprites.asm` and select frames from `src/player.asm`.
- If adding HUD/text rendering, implement the renderer in `src/video.asm` or a clearly justified new display module; do not scatter text drawing into gameplay modules.

## Input Rules

- Keep `Input_Mode` abstraction intact.
- Gameplay code must consume direction enum only.
- Add fire/start/pause inputs by extending `Input_Read` or adding clearly named input routines in `src/input.asm`.
- Document bit layout if returning a bitfield.
- Ensure keyboard, Kempston, and Sinclair paths remain coherent after changes.

## Maze Rules

- Maintain exactly `Maze_Width * Maze_Height` bytes in `Maze_Map`.
- If adding cell types, define constants in `src/maze.asm`.
- `Maze_CanMove` must block walls and out-of-map positions.
- Pellet consumption should update maze/game state through maze-owned routines, not by direct writes from unrelated modules.
- If tunnels wrap around the map, implement and document wrap behavior in maze/player boundary logic.

## Player Rules

- Player movement should remain maze-coordinate based until a deliberate pixel/subtile movement change is requested.
- `Player_Update` may call `Maze_CanMove`; maze collision logic must remain in `src/maze.asm`.
- Player drawing must account for `Maze_OffsetX` and `Maze_OffsetY`.
- Store direction, requested direction, animation frame, and timers in `src/memory.asm` if they persist.

## Enemy Rules

If adding enemies:

- Put persistent enemy variables in `src/memory.asm`.
- Put enemy update/draw routines in a new `src/enemy.asm` only if the feature is substantial; otherwise ask before adding a new module.
- If adding `src/enemy.asm`, include it from `src/main.asm` after maze/sprites and before or after player as dependencies require.
- Enemies must use maze coordinates first.
- Enemies must call maze collision routines; do not duplicate maze lookup code.
- Start with one enemy and simple deterministic movement before adding multiple personalities.

## Game State Rules

Existing variable:

- `GameState`: currently documented as `0=menu`, `1=play`, `2=gameover`.

When implementing states:

- Define state constants instead of using magic numbers in multiple modules.
- Keep state transitions centralized or clearly owned.
- Do not let menu, player, maze, and enemy modules all mutate state arbitrarily.

## Style Rules

- Keep source ASCII unless an existing file already requires non-ASCII.
- Use concise comments for interfaces, hardware assumptions, and non-obvious address math.
- Do not over-comment simple `LD`, `INC`, `RET` sequences.
- Prefer explicit constants over repeated magic numbers.
- Keep labels readable and module-prefixed for exported routines/data.
- Keep changes focused; avoid formatting churn across unrelated files.

## Forbidden Changes Without Explicit User Approval

- Changing `ORG 32768`.
- Replacing the assembler or build system.
- Introducing C, BASIC loaders beyond TAP wrapping, or external libraries.
- Rewriting the whole engine.
- Moving all data into one file.
- Changing memory layout as a broad refactor.
- Replacing tile movement with pixel movement.
- Adding 128K-only features.
- Adding emulator-specific behavior.
- Using ROM calls for active gameplay.

## Agent Workflow

For each task:

1. Inspect the relevant module before editing.
2. Identify the public routine/data interface affected.
3. Make the smallest coherent change.
4. Build with `./tools/build.sh` or the manual commands.
5. Report changed files, build result, and any known limitations.

If a task spans multiple modules, state the module boundary reason before editing. Example: adding pellet consumption may require `maze.asm` for cell state, `memory.asm` for score, and `player.asm` for triggering collection after movement.

## Known Gaps In Current Code

- README structure mentions `assets/sprites.asm`, but the actual included sprite file is `src/sprites.asm`.
- Menu still uses ROM calls (`CALL $0DAF`, `RST 16`).
- Maze is redrawn in full every frame.
- Pellets are visual only and are not consumed.
- No score, lives, ghosts, frightened mode, level completion, pause, or game over loop.
- Player animation currently faces right only.
- `Input_Mode=2` reads both Sinclair keyboard layouts in one path; there is no separate Sinclair 1/2 menu distinction.

Agents should treat these as implementation opportunities, not reasons to rewrite the project.
