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
- A green build is not a substitute for V3 visual verification when the task changes what the player sees.

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

Canonical GitHub Actions run `32800960272` on commit `e0e4afce51442df193eb48de18226d53a42ab703` proves the current visual-recovery code baseline:

- V1 structural/architecture checks PASS;
- sjasmplus 1.23.1 assembly: 0 errors / 0 warnings;
- headless 48K Z80 runtime harness PASS, including maze attribute and wall-outline guards;
- binary size 8279 bytes;
- conservative upper-RAM headroom 20393 bytes;
- TAP size 8359 bytes;
- fresh-48K simulated tape loading reaches `PC=32768 ($8000)`;
- V4 `Render_Commit` timing with 48K contention:
  - dirty1: 4341 T-states;
  - dirty2: 5497 T-states;
  - arbitrary dirty4: 9184 T-states;
- all measured cases remain below the 12,000 T-state common target and 14,000 warning threshold;
- verified release publication completes successfully.

The owner-provided V3 screenshot exposed the visual regression that initiated this milestone. The deterministic cause has now been fixed and guarded, but the corrected screen still needs a fresh owner-visible V3 screenshot before the recovery task can be declared `DONE`.

---

# ACTIVE MILESTONE — Visual recovery toward the arcade reference

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

`P48-018 -> P48-019 -> P48-023 -> P48-020 -> P48-021 -> P48-022 -> resume P48-009 gameplay`

Do not add enemies, scoring logic, sound, or broad gameplay until P48-018 and P48-019 are at least `VERIFY` with a clean V3 screenshot and P48-023 provides a repeatable visual gate.

---

## P48-018 — Recover a clean, readable maze baseline

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Type:** rendering correctness + visual recovery
- **Files:** `src/maze.asm`, `src/sprites.asm`, `tests/runtime_harness.asm`, `docs/INCIDENTS.md`
- **Depends on:** none
- **Incident:** `INC-2026-008`

### Problem

The owner-provided V3 screenshot showed horizontal attribute-color bands and large solid blue/red areas instead of a readable maze. Root cause: `Maze_DrawAtOffset` received the intended attribute in `A`, then overwrote `A` while translating maze coordinates to screen coordinates, so the screen Y coordinate was passed to `Video_DrawSprite` as the Spectrum attribute.

Solid-blue PAPER wall cells were also too coarse for the desired arcade-like visual language.

### Implemented

1. the intended attribute survives maze-to-screen coordinate translation;
2. the headless Z80 harness asserts exact attributes for representative wall and pellet cells through the real `Maze_Draw` path;
3. walls use black PAPER + bright-blue INK;
4. wall cells select one of 16 thin bitmap boundary variants from neighboring wall topology;
5. normal pellet art is reduced to a 2x2 dot;
6. gameplay/collision map data is unchanged;
7. a failed first repair was caught by the new guard before release and is retained in `INC-2026-008`.

### Acceptance

- [x] no row/column coordinate is used as a Spectrum attribute by current maze drawing;
- [x] headless harness catches the attribute-contract regression;
- [x] wall cells use black PAPER and blue INK;
- [x] wall bitmap is boundary/outline based rather than a filled colored rectangle;
- [x] pellet bitmap is visibly smaller than the player;
- [x] collision map and player movement semantics unchanged;
- [x] V1/V2 PASS and fresh-48K TAP load reaches `$8000`;
- [x] V4 remains within budget: 4341 / 5497 / 9184 T-states;
- [ ] V3 screenshot shows a black playfield with blue maze lines and no large red/blue attribute bands.

### Verification evidence

- failing guard run `32800881885` correctly blocked publication on an incorrect stack-order repair (code 13);
- corrected run `32800960272` passed build, runtime harness, performance test, TAP load, artifact checks, and release publication;
- current BIN 8279 bytes, TAP 8359 bytes, headroom 20393 bytes.

---

## P48-019 — Redesign maze topology for a classic centered composition

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** level/visual design
- **Files:** `src/maze.asm`, tests/checker, documentation
- **Depends on:** `P48-018` visual baseline acceptance

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
- **Type:** presentation/HUD
- **Files:** new HUD module or centralized video/text data, `src/main.asm`, memory state
- **Depends on:** `P48-019`

### Goal

Create a clean top HUD resembling the reference hierarchy: score on the left, `HIGH SCORE`/best score centrally or right-aligned, without stealing maze readability.

### Acceptance

- [ ] HUD has dedicated screen cells outside maze playfield;
- [ ] score/high-score labels remain stable while maze redraw/dirty restore runs;
- [ ] no ROM printing in the gameplay hot path;
- [ ] numeric fields can later be updated without full-screen redraw.

---

## P48-021 — Add power-pellet visual/state cells and life/bonus strip

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** presentation + level state
- **Files:** maze cell model, sprites, HUD/presentation
- **Depends on:** `P48-019`, `P48-020`

### Goal

Add four larger power pellets and reserve lower-screen presentation for remaining lives/bonus icons, matching the classic visual hierarchy without implementing frightened-mode behavior yet.

### Acceptance

- [ ] explicit power-pellet cell type/state;
- [ ] exactly four initial power-pellet positions;
- [ ] power pellet visually distinct from normal pellet;
- [ ] life/bonus strip does not overlap gameplay cells;
- [ ] dirty restoration preserves pellet/power-pellet state correctly.

---

## P48-022 — Add ghost-house geometry and actor color strategy

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** actor staging + Spectrum color policy
- **Files:** maze/actor/render architecture, sprite assets
- **Depends on:** `P48-019`, `P48-016`

### Goal

Create the central house/staging geometry and define how future ghosts get distinct readable colors under 8x8 attribute-cell limitations.

### Acceptance

- [ ] ghost house has entrance/exit semantics separate from normal walls;
- [ ] future ghost spawn slots are defined;
- [ ] actor color policy is documented and tested for attribute clash;
- [ ] no renderer rewrite is introduced without profiling/ADR evidence.

---

## P48-023 — Establish a visual regression gate

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** testing/regression prevention
- **Files:** `docs/TESTING.md`, runtime/emulator tooling where deterministic, incident registry
- **Depends on:** `P48-018`

### Goal

Prevent another build from being considered healthy while the actual game screen is visibly broken.

### Plan

- keep deterministic Z80 assertions for key bitmap/attribute cells in CI;
- define a canonical initial-frame V3 screenshot checklist;
- record emulator/machine mode and commit for accepted screenshots;
- automate screenshot comparison only if it can be made deterministic and non-GUI; do not reintroduce fragile X11 automation (`INC-2026-005`).

### Acceptance

- [x] CI validates representative wall/pellet attributes and wall bitmap bytes;
- [ ] `docs/TESTING.md` has an explicit initial-screen visual gate;
- [ ] accepted V3 screenshot evidence is recorded with commit/ref;
- [ ] a visibly banded/filled/corrupted maze cannot be marked release-quality solely because assembly passes.

---

# Existing foundation tasks

## P48-001 — Preserve maze coordinates across attribute drawing
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-001`
- V1/V2 PASS; V3 maze/pellet restoration still required.

## P48-002 — Correct Sinclair 1 and Sinclair 2 directions
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-002`
- V1/V2 PASS; V3 both Sinclair modes still required.

## P48-003 — Remove full-maze redraw from gameplay frames
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`
- Dirty restoration and timing implemented; V3 trail/background verification remains.

## P48-004 — Stabilize attribute ownership for moving actors
- **Status:** `VERIFY` | **Priority:** `P1`
- Moving actors do not write attributes; V3 clash/trail verification remains.

## P48-005 — Synchronize documentation with pixel movement
- **Status:** `DONE` | **Priority:** `P1`

## P48-006 — Add exact GPL license file
- **Status:** `BLOCKED` | **Priority:** `P1`
- Owner must explicitly choose the exact GPL variant; agents must not guess.

## P48-007 — Make VERSION the single release-version source
- **Status:** `READY` | **Priority:** `P2`
- Generate menu version from `VERSION`.

## P48-008 — Establish repeatable verification baseline
- **Status:** `VERIFY` | **Priority:** `P2`
- V1/V2/V4 automated; V3 visual/control suite remains.

## P48-009 — Implement first complete gameplay loop
- **Status:** `BLOCKED` | **Priority:** `P2`
- Blocked by visual recovery. Later children: pellet consumption, score, level completion, lives, enemies, collisions, game over, energizers, sound.

## P48-010 — Dedicated render module and prepare/commit phases
- **Status:** `VERIFY` | **Priority:** `P1`
- V1/V2/V4 PASS; V3 visual runtime confirmation remains.

## P48-011 — Generate masked pre-shifted 8x8 actor assets
- **Status:** `DONE` | **Priority:** `P1`

## P48-012 — Replace runtime-shift drawing with masked renderer
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`
- V1/V2/V4 PASS; V3 all phases/background preservation remains.

## P48-013 — Move player drawing out of player module
- **Status:** `VERIFY` | **Priority:** `P1`
- Simulation ownership complete; V3 direction/stopping behavior remains.

## P48-014 — Cycle-budget profiling and memory budget checks
- **Status:** `DONE` | **Priority:** `P2` | **Incident:** `INC-2026-006`
- Current visual-recovery baseline: 8279-byte BIN, 20393-byte headroom, 4341/5497/9184 T-states. Re-run when actor count or restore complexity changes materially.

## P48-015 — Persistent incident memory and changelog discipline
- **Status:** `DONE` | **Priority:** `P1`

## P48-016 — Support explicit canonical opacity masks for future actor art
- **Status:** `READY` | **Priority:** `P2`
- Required before actors needing opaque zero-valued pixels.

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
