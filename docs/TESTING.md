# PAC48 Verification Protocol

This is the repeatable verification checklist for PAC48 changes.

It complements:

- `docs/TODO.md` for acceptance criteria;
- `docs/INCIDENTS.md` for historical regressions and closure evidence;
- `CHANGELOG.md` for continuous change history.

An AI agent must report exactly which layers were run. Never collapse `not run`, `estimated`, and `passed` into the same statement.

## Verification layers

### V0 - Static/source review

Required for every change.

- inspect affected module contracts;
- check related incidents/regression guards;
- ensure no forbidden architecture pattern was reintroduced;
- ensure TODO/changelog/incident records are coherent.

V0 alone is never enough to close a runtime/render/input incident.

### V1 - Deterministic project and architecture checks

Run through the canonical build or directly when diagnosing tooling:

```sh
mkdir -p src/generated
python3 tools/gen_shifted_sprites.py src/sprites.asm src/generated/pac_shifted.asm
python3 tools/check_project.py \
  --maze src/maze.asm \
  --generated-sprites src/generated/pac_shifted.asm \
  --source-root src
```

Expected invariants include:

- maze is exactly 20 rows x 28 cells = 560 cells;
- generated player data has exactly 160 unique shifted phases;
- every generated phase is 8 scanlines x `maskL,imageL,maskR,imageR`;
- every direction table contains exactly the expected 40 frame/phase pointers;
- generator internal phase/mask invariants pass;
- `Maze_Draw` is not called from `MainLoop`;
- legacy `Video_DrawSpritePx` is absent;
- `player.asm` has no direct video/render ownership;
- obsolete hand-written `Pac_FrameTable*` tables are absent;
- dirty maze restoration has not reintroduced the redundant attribute-only pass.

These guards encode regression lessons so they are enforceable, not only documented.

### V2 - Canonical build, runtime harness, and TAP-load verification

```sh
./tools/build.sh
```

Required tools:

- Python 3
- `sjasmplus`
- SkoolKit `bin2tap.py`, `tap2sna.py`, `trace.py`, `snapinfo.py`

A successful V2 build must:

1. complete V1;
2. run renderer reference-model tests;
3. assemble the main game with zero errors and warnings;
4. enforce the current upper-RAM binary budget;
5. execute the headless 48K Z80 runtime harness;
6. generate `build/pac48.tap` and `build/pac48-<VERSION>.tap`;
7. simulate a freshly booted 48K Spectrum loading the generated TAP;
8. prove that simulated loading reaches PAC48 entry point `PC=32768` (`$8000`).

Durable TAP-load evidence is written to:

```text
build/tap_load.log
build/tap_load.z80
```

The tape-load test is deliberately part of V2: successful assembly alone is not enough to call a downloadable TAP usable.

If a required command is missing or tape simulation fails, record the exact failure and do not publish a Latest release.

### V3 - 48K emulator/manual visual and control smoke test

Use a 48K configuration, not a 128K-only mode that could hide compatibility mistakes.

Record emulator/version and machine mode.

#### Load/start

- TAP loads without returning unexpectedly to BASIC;
- menu appears;
- selecting a control method enters gameplay;
- maze appears at the expected offset;
- no obvious bitmap corruption before movement.

#### Keyboard

Using Q/A/O/P:

- Q moves up;
- A moves down;
- O moves left;
- P moves right;
- held direction continues;
- requested turn is buffered until a legal grid-aligned turn.

#### Kempston

Verify all four directions on a Kempston-emulated device.

#### Sinclair 1 regression (`INC-2026-002`)

- 6 = left
- 7 = right
- 8 = down
- 9 = up

#### Sinclair 2 regression (`INC-2026-002`)

- 1 = left
- 2 = right
- 3 = down
- 4 = up

#### Renderer/dirty restoration (`INC-2026-001`, `INC-2026-003`)

Move the player through long horizontal and vertical corridors and around several corners.

Confirm:

- no misplaced pellet/maze bitmap writes;
- no persistent player trails;
- background cells are restored after the player leaves;
- wall bitmap/attributes remain stable;
- pellet bitmap remains visible outside the opaque player silhouette;
- no permanent attribute-color trail follows the player.

#### Pixel-phase sweep

Inspect all eight `x & 7` horizontal phases and all eight `y & 7` phases across cell boundaries.

Confirm sprite shape remains coherent, spill bytes preserve neighboring maze pixels, and the player remains visible over pellet and empty corridor cells.

#### Turning and stopping

Test horizontal→up/down and vertical→left/right turns. Drive the player into a wall and confirm visual facing remains the last valid direction rather than snapping right.

### V4 - Cycle-aware performance test

Required before closing renderer performance work (`P48-014`, `INC-2026-003`).

Canonical automated timing uses SkoolKit `trace.py` directly on the raw assembled performance harness with 48K contention enabled. Exact-code timing must not pass through an unproven snapshot serialization boundary (`INC-2026-006`).

Record:

- tool/version and 48K timing mode;
- T-states/instruction count for `Render_Commit`;
- dirty-cell counts;
- actor count;
- assembled binary size/headroom.

Engineering targets:

- common `Render_Commit`: around/below 12,000 T-states;
- about 14,000 T-states: warning threshold;
- stable 50 Hz preferred.

Verified baseline on 2026-08-25:

```text
common_dirty1     4320 T-states / 547 instructions
cardinal_dirty2   5455 T-states / 690 instructions
arbitrary_dirty4  7800 T-states / 978 instructions
```

These measurements are for the current player-only renderer. Re-run V4 when actor count or renderer architecture materially changes.

### V5 - Real hardware regression test

Required before a release claims real-hardware-tested confidence for timing/input changes.

Record Spectrum/model or compatible hardware, loading method, input interface, and visible differences from emulator results.

## Verified-release publication gate

`pac48-latest.tap` may be published only from a successful canonical GitHub Actions build of `main`.

The publication job must consume the exact artifact already verified by the build job, validate `SHA256SUMS.txt`, attach a versioned TAP plus build metadata, create a per-commit release, and mark it Latest. It must not compile a second independent copy for publication.

Stable consumer URL:

```text
https://github.com/Frapo78/pac48/releases/latest/download/pac48-latest.tap
```

Documentation-only pushes are excluded from automatic releases so they do not create duplicate binary releases.

## Incident closure rule

An incident may move to `CLOSED` only when:

1. corrective code exists;
2. required verification layers have passed;
3. regression guard is documented and, where practical, executable in V1/V2;
4. TODO verification notes are updated;
5. `CHANGELOG.md` reflects the fix.

Examples:

- register-clobber rendering bug: V2 + V3 required;
- Sinclair mapping bug: V2 + relevant V3 control tests required;
- renderer performance architecture: V2 + V3 + V4 required;
- build/release tooling incident: deterministic CI/release evidence may be sufficient when no visual/hardware behavior is involved.

## Verification report template

```text
Date:
Commit/ref:
Environment:

V0 static: PASS/FAIL/NOT RUN
V1 structural/architecture: PASS/FAIL/NOT RUN
V2 build/runtime/TAP-load: PASS/FAIL/NOT RUN
V3 emulator/manual visual: PASS/FAIL/NOT RUN
V4 timing: PASS/FAIL/NOT RUN
V5 hardware: PASS/FAIL/NOT RUN

Binary bytes:
TAP bytes:
TAP load reached PC=$8000: YES/NO
Render_Commit T-states:
Dirty cells common/worst:
Actors tested:

Related tasks:
Related incidents:
Notes:
```

Store durable evidence in TODO/incident/changelog/release metadata; do not leave the only copy in chat history.
