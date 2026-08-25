# PAC48 Technical TODO

This is the canonical work queue for PAC48. Important work must not live only in chat or commit messages.

Read before implementation:

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. `docs/INCIDENTS.md`
5. `docs/TESTING.md`
6. `CHANGELOG.md`
7. this file

## Agent workflow

- Select the highest-priority unblocked task unless the owner explicitly selects another.
- Inspect all listed files and related incidents before editing.
- Use stable `P48-###` IDs; never renumber or reuse IDs.
- Create a new task for newly discovered scope instead of silently expanding another task.
- Run the canonical build for code/build changes.
- Update changelog and incident records when applicable.
- Code without required evidence is `VERIFY`, not `DONE`.
- A green build is not a substitute for V3 visual verification when the task changes what the player sees or how controls/collision feel.

## Status

- `READY` — ready to implement
- `IN_PROGRESS` — being implemented
- `BLOCKED` — dependency/decision prevents work
- `VERIFY` — implementation exists but required evidence remains
- `DONE` — implementation and required verification complete
- `WONTFIX` — intentionally rejected, rationale required

## Priority

- `P0` correctness/corruption
- `P1` architecture/compatibility/gameplay foundation
- `P2` maintainability/tooling/performance
- `P3` later enhancement

## Current verified baseline — 2026-08-25

Canonical GitHub Actions run `32801837183` on commit `5acf77665afc5187bcd0baae03a349177ff68955` proves the current collision/pellet baseline:

- V1 structural/architecture checks PASS;
- sjasmplus 1.23.1 assembly: 0 errors / 0 warnings;
- headless 48K Z80 runtime harness PASS, including maze visual guards, pellet mutation, and per-pixel wall-collision regression coverage;
- binary size 8503 bytes;
- conservative upper-RAM headroom 20169 bytes;
- TAP size 8583 bytes;
- fresh-48K simulated tape loading reaches `PC=32768 ($8000)`;
- V4 `Render_Commit` timing remains 4341 / 5497 / 9184 T-states for dirty1/dirty2/dirty4;
- verified release publication completed successfully.

The owner accepted the recovered visual baseline as "va molto meglio", confirmed controls respond and movement is very fluid, and then exposed two gameplay issues: occasional apparent wall penetration and pellets not being consumed. These now have dedicated tasks/tests below; fresh V3 confirmation remains required before they are `DONE`.

---

# ACTIVE MILESTONE — Visual/gameplay recovery toward the arcade reference

## Visual target

PAC48 should read immediately as a classic maze-chase game:

- black/dark playfield;
- one centered, coherent maze;
- thin bright-blue maze boundaries instead of large filled color rectangles;
- small regular pellets along corridors;
- four larger power pellets in deliberate positions;
- a central ghost-house/staging area;
- yellow player with readable directional animation;
- distinct ghost colors later, within Spectrum attribute constraints;
- score/high-score HUD above the maze;
- lives/bonus strip below or beside the maze;
- no diagnostic-looking color bands, test patterns, random blocks, or unexplained attribute changes.

The ZX Spectrum attribute model is a hard constraint. Visual similarity means preserving the reference composition and hierarchy, not attempting impossible per-pixel arcade color behavior.

## Milestone order

`P48-024 -> P48-025 -> P48-019 -> P48-023 -> P48-020 -> P48-021 -> P48-022 -> resume broader P48-009 gameplay`

Do not add enemies, sound, or broad gameplay until collision/pellet V3 is clean and the topology/visual gate is established.

---

## P48-018 — Recover a clean, readable maze baseline

- **Status:** `DONE`
- **Priority:** `P0`
- **Type:** rendering correctness + visual recovery
- **Files:** `src/maze.asm`, `src/sprites.asm`, `tests/runtime_harness.asm`, `docs/INCIDENTS.md`
- **Incident:** `INC-2026-008`

Implemented and verified:

- intended attributes survive maze-to-screen coordinate translation;
- headless Z80 harness asserts representative maze attributes and wall bitmap bytes;
- walls use black PAPER + bright-blue thin bitmap boundaries;
- normal pellet art is a small 2x2 dot;
- collision-map semantics were unchanged by visual recovery;
- V1/V2/V4 passed;
- owner V3 screenshot confirmed the large color bands/filled rectangles were gone and the result was a major visual improvement.

---

## P48-024 — Harden player collision at every pixel step

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Type:** gameplay correctness
- **Files:** `src/player.asm`, `tests/runtime_harness.asm`
- **Incident:** `INC-2026-009`
- **Depends on:** none

### Problem

The owner reported that Pac occasionally appears to pass through walls. The previous collision path only revalidated the destination tile when both pixel coordinates were 8-pixel aligned; between nodes it returned success unconditionally. Normal movement intends to preserve orthogonal alignment, but that assumption is too fragile for a collision invariant.

### Implemented

- every one-pixel movement validates the complete 8x8 actor's leading edge;
- two leading-edge corner samples are converted from screen pixels to maze cells and checked through `Maze_CanMove`;
- requested turns are still grid-aligned/buffered, preserving the current responsive control feel;
- a Z80 regression case forces a one-pixel orthogonal drift near a wall: the old alignment-only code would advance, the new code must stop and clear `Pac_Dir`.

### Acceptance

- [x] per-pixel leading-edge collision exists for all four directions;
- [x] wall/outside remains blocked through canonical `Maze_CanMove`;
- [x] deterministic Z80 drift regression PASS;
- [x] normal legal movement regression PASS;
- [x] V1/V2 PASS;
- [x] Render_Commit V4 remains unchanged/in budget;
- [ ] V3: owner confirms sustained play no longer crosses/enters wall geometry.

### Verification evidence

GitHub Actions run `32801837183`: clean assembly, runtime harness PASS, fresh-48K TAP load PASS, release publication PASS. Current BIN 8503 bytes; TAP 8583 bytes; headroom 20169 bytes.

---

## P48-025 — Consume normal pellets persistently

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** gameplay state
- **Files:** `src/pellets.asm`, `src/player.asm`, `src/main.asm`, test harnesses
- **Depends on:** none

### Problem

Normal pellets were visual-only maze cells; no gameplay routine changed them after Pac passed over them.

### Implemented

- new `src/pellets.asm` owns persistent normal-pellet consumption;
- `Pellet_ConsumeAt` changes `Maze_CellPellet` to `Maze_CellEmpty` in `Maze_Map`;
- pickup uses the centre of the 8x8 player so entry from left/right/up/down is symmetric;
- pellet pickup runs after every successful pixel move;
- the spawn pellet is consumed before the initial maze draw;
- dirty-cell restoration automatically renders consumed cells as empty without a full-maze redraw;
- Z80 tests prove the spawn pellet and a centre-threshold target pellet mutate to `Maze_CellEmpty`.

### Acceptance

- [x] persistent cell state changes from pellet to empty;
- [x] centre-based pickup is direction-anchor independent;
- [x] dirty restoration reads the mutated map state;
- [x] deterministic Z80 pickup regressions PASS;
- [x] V1/V2 PASS;
- [ ] V3: owner confirms pellets visibly disappear while traversing corridors;
- [ ] pellet counter/score increment is intentionally deferred to a later child task.

### Verification evidence

GitHub Actions run `32801837183` passed the expanded runtime harness, canonical build, TAP load, V4 timing and release publication.

---

## P48-019 — Redesign maze topology for a classic centered composition

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** level/visual design
- **Files:** `src/maze.asm`, tests/checker, documentation
- **Depends on:** clean V3 confirmation of `P48-024` and `P48-025`

### Goal

Replace the current generic 28x20 topology with a deliberate, symmetric arcade-style maze that reads clearly at a glance while remaining an original PAC48 layout.

### Plan

- preserve a compact grid suitable for 8x8 actor movement;
- use bilateral symmetry where useful;
- create long readable corridors and loops instead of noisy micro-cells;
- reserve central geometry for the ghost house;
- provide left/right tunnel opportunities;
- reserve four power-pellet positions;
- ensure player and future ghosts have valid spawn tiles;
- validate every required gameplay region remains reachable.

### Acceptance

- [ ] visually coherent/symmetric maze;
- [ ] no isolated walkable regions;
- [ ] central ghost-house reservation;
- [ ] four power-pellet candidate cells;
- [ ] tunnel route defined;
- [ ] player spawn defined and legal;
- [ ] V3 screenshot accepted by owner as directionally close to the reference.

---

## P48-020 — Add score/high-score HUD and reserve screen bands

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Depends on:** `P48-019`

Goal: clean top HUD with score and high score outside the maze playfield, no ROM printing in the hot path, independently updatable numeric fields.

---

## P48-021 — Add power-pellet visual/state cells and life/bonus strip

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Depends on:** `P48-019`, `P48-020`

Goal: four distinct power pellets plus reserved life/bonus presentation without implementing frightened mode yet.

---

## P48-022 — Add ghost-house geometry and actor color strategy

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Depends on:** `P48-019`, `P48-016`

Goal: central ghost staging/exit semantics and a documented Spectrum-safe actor color policy.

---

## P48-023 — Establish a visual regression gate

- **Status:** `READY`
- **Priority:** `P1`
- **Depends on:** `P48-018`

### Goal
Prevent another build from being considered healthy while the actual game screen is visibly broken.

### Acceptance

- [x] CI validates representative wall/pellet attributes and wall bitmap bytes;
- [x] an owner-visible V3 screenshot has established the first accepted recovered baseline;
- [ ] `docs/TESTING.md` has an explicit initial-screen visual gate;
- [ ] accepted screenshot evidence format (emulator/machine/commit) is documented;
- [ ] a visibly corrupted maze cannot be marked release-quality solely because assembly passes.

---

# Existing foundation tasks

## P48-001 — Preserve maze coordinates across attribute drawing
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-001`

## P48-002 — Correct Sinclair 1 and Sinclair 2 directions
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-002`

## P48-003 — Remove full-maze redraw from gameplay frames
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`

## P48-004 — Stabilize attribute ownership for moving actors
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-005 — Synchronize documentation with pixel movement
- **Status:** `DONE` | **Priority:** `P1`

## P48-006 — Add exact GPL license file
- **Status:** `BLOCKED` | **Priority:** `P1`
- Owner must explicitly choose the exact GPL variant; agents must not guess.

## P48-007 — Make VERSION the single release-version source
- **Status:** `READY` | **Priority:** `P2`

## P48-008 — Establish repeatable verification baseline
- **Status:** `VERIFY` | **Priority:** `P2`

## P48-009 — Implement first complete gameplay loop
- **Status:** `BLOCKED` | **Priority:** `P2`
- Normal pellet consumption has been extracted and implemented as `P48-025`. Remaining children include pellet count, score, level completion, lives, enemies, collisions, game over, energizers and sound.

## P48-010 — Dedicated render module and prepare/commit phases
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-011 — Generate masked pre-shifted 8x8 actor assets
- **Status:** `DONE` | **Priority:** `P1`

## P48-012 — Replace runtime-shift drawing with masked renderer
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`

## P48-013 — Move player drawing out of player module
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-014 — Cycle-budget profiling and memory budget checks
- **Status:** `DONE` | **Priority:** `P2` | **Incident:** `INC-2026-006`
- Current baseline: 8503-byte BIN, 20169-byte headroom, 4341/5497/9184 Render_Commit T-states.

## P48-015 — Persistent incident memory and changelog discipline
- **Status:** `DONE` | **Priority:** `P1`

## P48-016 — Support explicit canonical opacity masks for future actor art
- **Status:** `READY` | **Priority:** `P2`

## P48-017 — Publish latest compiled and verified TAP from GitHub
- **Status:** `DONE` | **Priority:** `P1` | **Incident:** `INC-2026-007`
- Stable download: `https://github.com/Frapo78/pac48/releases/latest/download/pac48-latest.tap`

---

## Adding tasks

Use the next unused ID and include at minimum:

```text
## P48-XXX — Title
- Status
- Priority
- Files
- Depends on
- Related incident/ADR if applicable

Problem / goal
Resolution plan
Acceptance / verification evidence
```

Never leave important work only in chat or commit messages.
