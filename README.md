# PAC48

PAC48 is a **Pac-Man-like game engine for the ZX Spectrum 48K**, written entirely in Z80 assembly.

The project targets real 48K hardware and intentionally treats CPU time, contended screen RAM, memory size and attribute-cell limitations as first-class design constraints.

PAC48 is not a binary clone of the original Pac-Man. It is an extensible maze-chase engine inspired by classic arcade mechanics.

## Current engine state

Already implemented:

- startup control-selection menu
- Q/A/O/P keyboard input
- Kempston input
- Sinclair 1 / Sinclair 2 input paths
- 28x20 maze data and collision
- pixel/sub-tile player movement
- buffered requested direction at grid intersections
- directional 8x8 player animation
- direct bitmap/attribute drawing
- BIN/TAP build script and `VERSION`

Still incomplete:

- consumable pellets
- scoring/HUD
- enemies
- lives
- complete game-state loop
- frightened/energizer mode
- sound

## Rendering architecture migration

A performance review of established ZX Spectrum techniques found that the existing renderer is not the right long-term architecture.

The current code still:

- redraws all 560 maze cells every gameplay frame;
- shifts actor sprite rows at runtime;
- writes shifted actor bytes destructively;
- relies on full-maze redraw to repair the background.

The accepted replacement architecture is documented in:

[`docs/adr/0001-rendering-architecture.md`](docs/adr/0001-rendering-architecture.md)

The target design keeps smooth pixel movement but changes rendering to:

- maze tilemap as persistent background source of truth;
- full maze drawn once per level;
- masked 8x8 software actors;
- eight pre-shifted horizontal phases;
- build-generated sprite image/mask data;
- 192-entry screen-line address lookup table;
- dirty-cell restoration only where actors moved/state changed;
- dedicated render module;
- simulation/preparation separated from a short screen-commit phase after `HALT`;
- 50 Hz as the initial measured target, with fixed 25 Hz only if profiling proves necessary.

The architecture deliberately avoids making full software double buffering, beam racing, floating-bus tricks or heavy self-modifying drawing code part of the baseline engine.

## Target platform

- **Machine:** ZX Spectrum 48K
- **CPU:** Zilog Z80
- **Load/start:** `ORG 32768` (`$8000`)
- **Bitmap:** `$4000-$57ff`
- **Attributes:** `$5800-$5aff`
- **Frame synchronization:** ULA interrupt / `HALT`
- **Compatibility:** real 48K hardware and accurate emulators

Code and game data should normally remain at `$8000+`, leaving screen-memory contention limited to unavoidable video accesses.

## Repository structure

```text
pac48/
├─ src/
│  ├─ main.asm
│  ├─ config.asm
│  ├─ memory.asm
│  ├─ menu.asm
│  ├─ input.asm
│  ├─ video.asm
│  ├─ sprites.asm
│  ├─ maze.asm
│  └─ player.asm
│
├─ docs/
│  ├─ ARCHITECTURE.md
│  ├─ TODO.md
│  └─ adr/
│     └─ 0001-rendering-architecture.md
│
├─ tools/
│  └─ build.sh
│
├─ AGENTS.md
├─ VERSION
├─ README.md
└─ .gitignore
```

Planned by the accepted renderer migration:

```text
src/render.asm             # frame composition / dirty lists / commit
build/generated-*.asm      # reproducible generated sprite phase/mask data
```

Generated `build/` output is ignored by Git.

## Documentation order

Before modifying code, humans and AI agents should read:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
3. [`docs/adr/0001-rendering-architecture.md`](docs/adr/0001-rendering-architecture.md)
4. [`docs/TODO.md`](docs/TODO.md)

`docs/TODO.md` contains the canonical prioritized migration/work queue with stable `P48-###` IDs and verification criteria.

## Immediate priorities

Before new gameplay features:

1. `P48-001` - fix maze/video register corruption
2. `P48-002` - correct Sinclair joystick mapping
3. `P48-010` - introduce render prepare/commit module boundary
4. `P48-011` - generate masked pre-shifted sprite data
5. `P48-012` - implement fast masked actor renderer + screen-line LUT
6. `P48-003` - remove full-maze redraw using dirty restoration
7. `P48-004` - stabilize attribute ownership
8. profile timing/memory before continuing gameplay expansion

See [`docs/TODO.md`](docs/TODO.md) for exact acceptance criteria.

## Build

Requirements:

- `sjasmplus`
- Python 3 + SkoolKit `bin2tap.py`
- a 48K-capable emulator such as Fuse or real hardware for runtime testing

Canonical build:

```bash
./tools/build.sh
```

Manual equivalent:

```bash
mkdir -p build
sjasmplus --raw=build/pac48.bin src/main.asm
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap
```

Every code change must assemble. Rendering/timing/control changes also require runtime verification, and renderer work must eventually include cycle-budget evidence.

## Controls

Startup menu currently exposes:

1. Keyboard - Q/A/O/P
2. Kempston
3. Sinclair 1
4. Sinclair 2

The known Sinclair mapping bug is tracked as `P48-002`.

## License

The repository historically states GNU GPL intent, but the exact GPL variant and root `LICENSE` file are not yet finalized. This is explicitly tracked as `P48-006`; agents must not choose the legal variant without owner approval.

## Project principles

- 48K first
- correctness before cleverness
- tilemap owns persistent maze state
- gameplay logic does not own raw screen memory
- spend a small amount of RAM to save repeated hot-loop work when profiling supports it
- optimize measured bottlenecks
- keep changes incremental and independently verifiable
- document non-obvious Z80 register/timing contracts

Brought to you with ❤️ by Francesco Poltero
