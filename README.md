# PAC48

PAC48 is a **Pac-Man-like game engine for the ZX Spectrum 48K**, written entirely in Z80 assembly.

The project targets real 48K hardware and treats CPU time, contended screen RAM, memory size, and attribute-cell limitations as first-class design constraints.

PAC48 is not a binary clone of the original Pac-Man. It is an extensible maze-chase engine inspired by classic arcade mechanics.

## Download latest verified TAP

The latest build that passed the canonical verification pipeline is always available at this stable URL:

**[Download `pac48-latest.tap`](https://github.com/Frapo78/pac48/releases/latest/download/pac48-latest.tap)**

You can also browse the full release history at [GitHub Releases](https://github.com/Frapo78/pac48/releases/latest).

Every published `latest` release is created only after the same build has passed:

- structural and architecture regression checks;
- renderer reference-model tests;
- sjasmplus assembly with zero errors and zero warnings;
- headless 48K Z80 runtime harness;
- contention-aware `Render_Commit` timing measurements;
- TAP generation;
- simulated fresh-48K tape loading that reaches PAC48 entry point `32768` (`$8000`);
- SHA-256 verification of the release package before publication.

Each release also contains the versioned TAP, `SHA256SUMS.txt`, and `BUILD-INFO.txt`. Releases are per-commit and historical builds are retained; GitHub simply marks the newest verified one as **Latest**.

## Current verification snapshot

The renderer/build foundation has passed deterministic V1/V2 and cycle-aware V4 verification in GitHub Actions using sjasmplus 1.23.1 and SkoolKit 10.1.

Current measured `Render_Commit` costs with 48K contention enabled:

```text
common_dirty1     4320 T-states
cardinal_dirty2   5455 T-states
arbitrary_dirty4  7800 T-states
```

The engineering target is about 12,000 T-states in the common case, with 14,000 as a warning threshold, so the current single-actor renderer has substantial timing headroom.

Current binary size is about 8 KiB, leaving more than 20 KiB beneath the project's conservative upper-RAM safety ceiling. The generated TAP has also been loaded from a fresh simulated 48K machine and verified to reach `PC=$8000`.

Manual visual/control V3 testing and eventual real-hardware V5 testing remain separate evidence layers; see [`docs/TESTING.md`](docs/TESTING.md).

## Current engine state

Implemented:

- startup control-selection menu;
- Q/A/O/P keyboard input;
- Kempston input;
- corrected Sinclair 1 / Sinclair 2 input paths;
- 28x20 maze data and collision;
- pixel/sub-tile player movement;
- buffered requested direction at grid intersections;
- persistent visual facing direction when movement stops;
- directional 8x8 player animation;
- full maze draw only during startup/level initialization;
- dedicated renderer with prepare/commit frame phases;
- dirty-cell background restoration;
- masked actor compositing;
- build-generated eight-phase horizontally pre-shifted player sprites;
- 192-entry Spectrum bitmap scanline lookup table;
- deterministic structural, runtime, timing, and TAP-load verification;
- automatic publication of the latest verified TAP to GitHub Releases;
- persistent incident/regression registry, continuous changelog, and repeatable verification protocol.

Still incomplete:

- consumable pellets;
- scoring/HUD;
- enemies;
- lives;
- complete game-state loop;
- frightened/energizer mode;
- sound;
- full manual visual/control verification on the current renderer;
- real-hardware verification before a release claims hardware-tested status.

## Rendering architecture

The performance architecture is defined by [`docs/adr/0001-rendering-architecture.md`](docs/adr/0001-rendering-architecture.md).

PAC48 uses:

- maze tilemap as persistent background source of truth;
- full maze drawn once per level/startup;
- masked 8x8 software actors;
- eight pre-shifted horizontal phases for one-pixel movement;
- build-generated sprite image/mask data;
- 192-entry screen-line address lookup table;
- dirty-cell restoration only where actors moved/state changed;
- dedicated `render.asm`;
- simulation/preparation separated from a short screen-commit phase immediately after `HALT`;
- 50 Hz as the target while measured timing remains inside budget.

Normal actor rendering performs no per-row runtime bit shifting and does not depend on redrawing all 560 maze cells each frame.

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

`Render_Commit` restores previous dirty cells and draws already prepared masked actors. Gameplay and preparation run outside the short screen-write phase.

## Target platform

- **Machine:** ZX Spectrum 48K
- **CPU:** Zilog Z80
- **Load/start:** `ORG 32768` (`$8000`)
- **Bitmap:** `$4000-$57ff`
- **Attributes:** `$5800-$5aff`
- **Frame synchronization:** ULA interrupt / `HALT`
- **Compatibility goal:** real 48K hardware and accurate emulators

Code, generated sprite data, renderer state, and lookup tables normally remain at `$8000+`.

## Repository structure

```text
pac48/
├─ .github/workflows/verify.yml
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
│  └─ generated/              # generated during build, ignored by Git
├─ tests/
│  ├─ runtime_harness.asm
│  └─ perf_harness.asm
├─ tools/
│  ├─ build.sh
│  ├─ gen_shifted_sprites.py
│  ├─ check_project.py
│  ├─ test_render_model.py
│  ├─ run_runtime_tests.sh
│  └─ run_perf_tests.sh
├─ docs/
│  ├─ ARCHITECTURE.md
│  ├─ TODO.md
│  ├─ INCIDENTS.md
│  ├─ TESTING.md
│  └─ adr/0001-rendering-architecture.md
├─ AGENTS.md
├─ CHANGELOG.md
├─ VERSION
└─ README.md
```

## Engineering memory for humans and AI agents

Before modifying code, read in this order:

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
3. [`docs/adr/0001-rendering-architecture.md`](docs/adr/0001-rendering-architecture.md)
4. [`docs/INCIDENTS.md`](docs/INCIDENTS.md)
5. [`docs/TESTING.md`](docs/TESTING.md)
6. [`CHANGELOG.md`](CHANGELOG.md)
7. [`docs/TODO.md`](docs/TODO.md)

Roles:

- `TODO.md` — planned work, dependencies, acceptance criteria, verification status;
- `INCIDENTS.md` — permanent record of subtle bugs, failed approaches, root causes, and regression guards;
- `TESTING.md` — V0-V5 verification protocol and incident-closure requirements;
- `CHANGELOG.md` — continuous record of what changed;
- `docs/adr/` — durable architecture decisions and rejected alternatives.

Resolved incidents remain in the repository so future agents do not repeat them. Where practical, lessons are encoded as executable build checks.

## Build

Requirements:

- Python 3;
- `sjasmplus`;
- SkoolKit (`bin2tap.py`, `tap2sna.py`, `trace.py`, `snapinfo.py`).

Canonical build:

```bash
./tools/build.sh
```

The supported build path:

1. generates shifted/masked sprite data;
2. runs structural and architecture guards;
3. runs renderer reference-model tests;
4. assembles with sjasmplus;
5. executes the headless Z80 runtime harness;
6. profiles `Render_Commit` with 48K contention;
7. creates normal and versioned TAP files;
8. simulates loading the produced TAP from a fresh 48K Spectrum until `PC=$8000`;
9. reports binary size, RAM headroom, and timing evidence.

On a qualifying push to `main`, GitHub Actions publishes that exact verified TAP as the new Latest release. Documentation-only pushes do not create redundant releases.

## Controls

Startup menu exposes:

1. Keyboard — Q/A/O/P
2. Kempston
3. Sinclair 1
4. Sinclair 2

Sinclair mapping history and the anti-regression rule are recorded in `INC-2026-002`.

## License

The repository historically states GNU GPL intent, but the exact GPL variant and root `LICENSE` file are not yet finalized. This remains tracked as `P48-006`; agents must not choose the legal variant without owner approval.

## Project principles

- 48K first;
- correctness before cleverness;
- tilemap owns persistent maze state;
- gameplay logic does not own raw screen memory;
- spend a small amount of upper RAM to save repeated hot-loop work;
- optimize measured bottlenecks;
- keep changes independently verifiable;
- document non-obvious Z80 register/timing contracts;
- preserve incident history and regression guards;
- turn repeatable incident lessons into executable checks;
- never publish a Latest TAP from an unverified build.

Brought to you with ❤️ by Francesco Poltero
