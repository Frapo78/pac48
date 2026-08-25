# PAC48

PAC48 is a **Pac-Man-like game engine for the ZX Spectrum 48K**, written entirely in Z80 assembly.

The project targets real 48K hardware and treats CPU time, contended screen RAM, memory size, and attribute-cell limitations as first-class design constraints.

PAC48 is not a binary clone of the original Pac-Man. It is an extensible maze-chase engine inspired by classic arcade mechanics.

## Current engine state

Implemented in source:

- startup control-selection menu
- Q/A/O/P keyboard input
- Kempston input
- corrected Sinclair 1 / Sinclair 2 input paths
- 28x20 maze data and collision
- pixel/sub-tile player movement
- buffered requested direction at grid intersections
- directional 8x8 player animation
- full maze draw only during startup/level initialization
- dedicated renderer with prepare/commit frame phases
- dirty-cell background restoration
- masked actor compositing
- build-generated eight-phase horizontally pre-shifted player sprites
- 192-entry Spectrum bitmap scanline lookup table
- structural build checks for maze/assets and upper-RAM binary budget
- persistent incident/regression registry and continuous changelog

Still incomplete:

- consumable pellets
- scoring/HUD
- enemies
- lives
- complete game-state loop
- frightened/energizer mode
- sound
- full emulator/hardware/timing verification of the new renderer

## Rendering architecture

The performance architecture is defined by:

[`docs/adr/0001-rendering-architecture.md`](docs/adr/0001-rendering-architecture.md)

PAC48 now uses:

- maze tilemap as persistent background source of truth;
- full maze drawn once per level/startup;
- masked 8x8 software actors;
- eight pre-shifted horizontal phases for one-pixel movement;
- build-generated sprite image/mask data;
- 192-entry screen-line address lookup table;
- dirty-cell restoration only where actors moved/state changed;
- dedicated `render.asm`;
- simulation/preparation separated from a short screen-commit phase immediately after `HALT`;
- 50 Hz as the initial measured target, with fixed 25 Hz only if profiling proves necessary.

Normal actor rendering no longer performs per-row runtime bit shifting and no longer depends on redrawing all 560 maze cells each frame.

## Frame pipeline

```text
HALT
Render_Commit
Input_Read
Player_Update
Video_BeginFrame
Render_Prepare
Video_EndFrame
```

`Render_Commit` restores previous dirty cells and draws the already prepared masked actor. Gameplay and preparation then run outside the short screen-write phase.

## Target platform

- **Machine:** ZX Spectrum 48K
- **CPU:** Zilog Z80
- **Load/start:** `ORG 32768` (`$8000`)
- **Bitmap:** `$4000-$57ff`
- **Attributes:** `$5800-$5aff`
- **Frame synchronization:** ULA interrupt / `HALT`
- **Compatibility:** real 48K hardware and accurate emulators

Code, generated sprite data, renderer state, and lookup tables remain at `$8000+` by default.

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
│  ├─ player.asm
│  ├─ render.asm
│  └─ generated/
│     └─ pac_shifted.asm      # generated during build, ignored by Git
│
├─ docs/
│  ├─ ARCHITECTURE.md
│  ├─ TODO.md
│  ├─ INCIDENTS.md
│  └─ adr/
│     └─ 0001-rendering-architecture.md
│
├─ tools/
│  ├─ build.sh
│  ├─ gen_shifted_sprites.py
│  └─ check_project.py
│
├─ AGENTS.md
├─ CHANGELOG.md
├─ VERSION
├─ README.md
└─ .gitignore
```

`build/` and `src/generated/` are generated locally and ignored by Git.

## Engineering memory for humans and AI agents

Before modifying code, read in this order:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
3. [`docs/adr/0001-rendering-architecture.md`](docs/adr/0001-rendering-architecture.md)
4. [`docs/INCIDENTS.md`](docs/INCIDENTS.md)
5. [`CHANGELOG.md`](CHANGELOG.md)
6. [`docs/TODO.md`](docs/TODO.md)

The files have different roles:

- `TODO.md` — planned work, dependencies, acceptance criteria, verification status;
- `INCIDENTS.md` — permanent record of subtle bugs, failed approaches, root causes, and regression guards;
- `CHANGELOG.md` — continuous record of what changed under `Unreleased`;
- `docs/adr/` — durable architecture decisions and rejected alternatives.

Resolved incidents are intentionally retained so future agents do not repeat them.

## Current verification priorities

The renderer/input migration is implemented but remains `VERIFY` until evidence is complete.

Before broad gameplay work:

1. run the canonical build successfully;
2. visually verify maze restoration and all pixel phases;
3. smoke-test keyboard, Kempston, Sinclair 1, and Sinclair 2;
4. measure `Render_Commit` in a cycle-aware emulator;
5. record common/worst actor and dirty-cell counts;
6. close or update `INC-2026-001`, `INC-2026-002`, and `INC-2026-003` with verification evidence.

See [`docs/TODO.md`](docs/TODO.md) for exact criteria.

## Build

Requirements:

- Python 3
- `sjasmplus`
- SkoolKit `bin2tap.py`
- a 48K-capable emulator such as Fuse or real hardware for runtime testing

Canonical build:

```bash
./tools/build.sh
```

The build script:

1. generates `src/generated/pac_shifted.asm` from canonical frames in `src/sprites.asm`;
2. validates maze and generated asset structure;
3. assembles the game;
4. checks the current binary/headroom budget;
5. creates normal and versioned TAP files.

Do not run a clean manual `sjasmplus src/main.asm` build without first generating the sprite include. The build script is the supported path.

## Controls

Startup menu exposes:

1. Keyboard - Q/A/O/P
2. Kempston
3. Sinclair 1
4. Sinclair 2

Sinclair mapping history and the anti-regression rule are recorded in `INC-2026-002`.

## License

The repository historically states GNU GPL intent, but the exact GPL variant and root `LICENSE` file are not yet finalized. This remains tracked as `P48-006`; agents must not choose the legal variant without owner approval.

## Project principles

- 48K first
- correctness before cleverness
- tilemap owns persistent maze state
- gameplay logic does not own raw screen memory
- spend a small amount of upper RAM to save repeated hot-loop work
- optimize measured bottlenecks
- keep changes independently verifiable
- document non-obvious Z80 register/timing contracts
- preserve incident history and regression guards
- update the changelog continuously during development

Brought to you with ❤️ by Francesco Poltero
