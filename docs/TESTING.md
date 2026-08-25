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

These architecture guards encode regression lessons from `INC-2026-001` and `INC-2026-003` so they are enforceable, not only documented.

### V2 - Canonical assembly/TAP build

```sh
./tools/build.sh
```

Required tools:

- Python 3
- `sjasmplus`
- SkoolKit `bin2tap.py`

A successful build must produce:

- `build/pac48.bin`
- `build/pac48.tap`
- `build/pac48-<VERSION>.tap`

The build also enforces the current upper-RAM binary budget and reruns V1 before/after assembly.

If a required command is missing, record the exact command as missing and leave relevant tasks/incidents at `VERIFY`.

### V3 - 48K emulator smoke test

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

For horizontal movement, visually inspect all eight `x & 7` phases between two byte boundaries.

For vertical movement, inspect all eight `y & 7` phases across cell boundaries.

Confirm:

- sprite shape remains coherent;
- spill byte does not erase neighboring maze pixels;
- player stays visible over both pellet and empty corridor cells.

#### Turning and stopping

Test turns in each orientation:

- horizontal -> up
- horizontal -> down
- vertical -> left
- vertical -> right

Also drive the player into a wall and confirm its visual facing remains the last valid direction rather than snapping to right.

Confirm no one-frame corruption is left at the old/new dirty-cell intersection.

### V4 - Cycle-aware performance test

Required before closing renderer performance work (`P48-014`, `INC-2026-003`).

Use an emulator/debugger/profiler that reports Z80 timing or traceable T-states.

Record:

- emulator/tool and version;
- 48K timing mode;
- T-states for `Render_Commit` with player only;
- current dirty-cell count;
- worst observed dirty-cell count;
- later: player + planned maximum enemy count;
- assembled binary size.

Current engineering targets from ADR 0001:

- common `Render_Commit`: around/below 12,000 T-states;
- about 14,000 T-states: warning threshold requiring investigation;
- stable 50 Hz preferred;
- if verified impossible after optimization, choose deliberate fixed 25 Hz rather than irregular missed frames.

### V5 - Real hardware regression test

Required before a release that claims real-hardware confidence for timing/input changes.

Record:

- Spectrum/model or compatible hardware;
- loading method;
- input interface used;
- visible differences from emulator results.

## Incident closure rule

An incident may move to `CLOSED` only when:

1. corrective code exists;
2. required verification layers have passed;
3. regression guard is documented and, where practical, executable in V1;
4. TODO verification notes are updated;
5. `CHANGELOG.md` reflects the fix.

Examples:

- register-clobber rendering bug: V2 + V3 required;
- Sinclair mapping bug: V2 + relevant V3 control tests required;
- renderer performance architecture: V2 + V3 + V4 required.

## Verification report template

```text
Date:
Commit/ref:
Environment:

V0 static: PASS/FAIL/NOT RUN
V1 structural/architecture: PASS/FAIL/NOT RUN
V2 build: PASS/FAIL/NOT RUN
V3 emulator: PASS/FAIL/NOT RUN
V4 timing: PASS/FAIL/NOT RUN
V5 hardware: PASS/FAIL/NOT RUN

Binary bytes:
Render_Commit T-states:
Dirty cells common/worst:
Actors tested:

Related tasks:
Related incidents:
Notes:
```

Store durable evidence in the relevant TODO/incident entries; do not leave the only copy in chat history.
