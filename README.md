# PAC48

PAC48 is an open-source **Pac-Man-like game engine** for the **ZX Spectrum 48K**, written entirely in **Z80 assembly**.

The project aims to stay faithful to real 48K hardware constraints while remaining modular, readable, and practical for both human and AI-assisted development.

PAC48 is **not a binary clone of the original Pac-Man**. It is a learning-oriented and extensible engine inspired by classic maze-chase mechanics.

## Current state

The engine currently includes:

- startup control-selection menu
- Q/A/O/P keyboard input
- Kempston joystick input
- Sinclair 1 / Sinclair 2 input paths
- 28x20 maze data and collision checks
- attribute/bitmap maze rendering
- pixel/sub-tile player movement
- buffered requested directions at grid intersections
- directional 8x8 player animation
- cell-aligned and pixel-positioned sprite drawing
- BIN/TAP build script with versioned output

Core gameplay is still incomplete: pellets are not yet consumed, there is no score/HUD, enemies, lives, complete game-state loop, frightened mode, or sound system.

Several important engine fixes have been identified before feature expansion. They are tracked in the canonical backlog at [`docs/TODO.md`](docs/TODO.md).

## Target platform

- **Machine:** ZX Spectrum 48K
- **CPU:** Zilog Z80
- **Video:** bitmap + 8x8 attribute cells
- **Load/start address:** `ORG 32768`
- **Frame pacing:** interrupt-driven `HALT` loop
- **Compatibility goal:** real 48K hardware as well as emulators

No 128K memory banking or 128K-only runtime dependency should be required.

## Repository structure

```text
pac48/
├─ src/
│  ├─ main.asm       # entry point and frame orchestration
│  ├─ config.asm     # global hardware/color constants
│  ├─ memory.asm     # persistent runtime state
│  ├─ menu.asm       # startup menu and control selection
│  ├─ input.asm      # keyboard and joystick abstraction
│  ├─ video.asm      # bitmap/attribute drawing primitives
│  ├─ sprites.asm    # sprite data and animation tables
│  ├─ maze.asm       # maze data, rendering, restoration, collision
│  └─ player.asm     # pixel movement, turns, animation, drawing
│
├─ docs/
│  ├─ ARCHITECTURE.md # current implementation and coordinate model
│  └─ TODO.md         # canonical agent-friendly technical backlog
│
├─ tools/
│  └─ build.sh        # canonical build script
│
├─ AGENTS.md          # rules/workflow for AI coding agents
├─ VERSION             # release version source
├─ README.md
└─ .gitignore
```

`build/` is generated locally and ignored by Git.

## Documentation for contributors and agents

Use these files in this order before changing code:

1. [`AGENTS.md`](AGENTS.md) — hard constraints, module ownership, register/coordinate rules, verification workflow.
2. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — what the current code actually does.
3. [`docs/TODO.md`](docs/TODO.md) — prioritized tasks with stable IDs, resolution plans, acceptance criteria, and verification status.

The TODO file is the source of truth for planned technical work. New findings should receive a new stable `P48-###` ID rather than being left only in commit messages or chat history.

## Build

### Requirements

- `sjasmplus`
- Python 3 with SkoolKit's `bin2tap.py`
- a ZX Spectrum emulator such as Fuse, or real hardware for runtime verification

Example Debian-like setup:

```bash
sudo apt-get install sjasmplus
pip install --user skoolkit
```

### Canonical build command

From the repository root:

```bash
./tools/build.sh
```

The script creates:

```text
build/pac48.bin
build/pac48.tap
build/pac48-<VERSION>.tap
```

Manual equivalent:

```bash
mkdir -p build
sjasmplus --raw=build/pac48.bin src/main.asm
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap
```

A successful assembly/TAP build is the minimum verification for any code change. Rendering, input, timing, loader, and gameplay changes should also be checked in an emulator or on real hardware.

## Controls

At startup PAC48 currently offers:

1. Q/A/O/P keyboard
2. Kempston joystick
3. Sinclair joystick 1
4. Sinclair joystick 2

Gameplay consumes a single direction abstraction from `Input_Read`:

```text
0 = none
1 = up
2 = down
3 = left
4 = right
```

A non-zero direction becomes a buffered requested direction. The player keeps moving in the active direction and accepts a requested turn when aligned to the 8x8 maze grid and the destination tile is walkable.

**Known issue:** the current Sinclair 1/2 bit-to-direction mappings require correction. See `P48-002` in [`docs/TODO.md`](docs/TODO.md).

## Movement and rendering model

PAC48 is no longer a tile-at-a-time movement prototype.

The current player state includes pixel coordinates (`Pac_PixelX`, `Pac_PixelY`), active/requested directions, and tile coordinates synchronized from the pixel position. Player drawing uses `Video_DrawSpritePx`, allowing an 8x8 sprite to move across cell boundaries.

This creates two important ZX Spectrum concerns that are actively tracked:

- register/coordinate preservation during maze rendering (`P48-001`)
- attribute-cell visibility while a pixel-positioned sprite crosses 8x8 color boundaries (`P48-004`)

The current main loop also redraws the entire 28x20 maze every frame. That is intentionally tracked for replacement with localized restoration/dirty rendering in `P48-003`.

## Near-term development order

The current foundation should be stabilized before adding enemies or a larger gameplay system:

1. `P48-001` — fix maze coordinate corruption across tile drawing.
2. `P48-002` — fix Sinclair joystick mappings.
3. `P48-003` — remove full-maze redraw from every frame.
4. `P48-004` — make pixel movement safe across attribute cells.
5. build the first complete gameplay loop: pellets, score, level completion, lives, then one deterministic enemy.

See [`docs/TODO.md`](docs/TODO.md) for the exact plans and acceptance criteria.

## Design goals

- 48K-safe, with no bank switching
- deterministic behavior suitable for real hardware
- small, explicit Z80 interfaces
- clear module ownership
- incremental changes that always remain buildable
- no unnecessary full-screen work in steady gameplay
- AI-assisted work that leaves the repository easier for the next agent to understand

## License status

The repository has historically described PAC48 as GNU GPL software, but an explicit root `LICENSE` file and exact GPL version are not currently present.

This is tracked as `P48-006`. The exact GPL variant should be chosen explicitly by the project owner rather than guessed by an automated contributor.

## Contributing

Contributions are welcome. Keep changes focused, respect module boundaries, document non-obvious Z80/register assumptions, and verify every code change with the canonical build.

AI-assisted contributors must follow [`AGENTS.md`](AGENTS.md) and keep [`docs/TODO.md`](docs/TODO.md) current.

## Why PAC48?

PAC48 is both a low-level game-development learning project and a practical base for experimenting with maze-chase mechanics on the original ZX Spectrum 48K architecture.

Have fun hacking it.

Brought to you with ❤️ by Francesco Poltero
