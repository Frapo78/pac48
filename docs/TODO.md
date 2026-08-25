# PAC48 Technical TODO

This is the canonical work queue for PAC48.

Read in this order before implementation:

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. `docs/INCIDENTS.md`
5. `docs/TESTING.md`
6. `CHANGELOG.md`
7. this file

## Agent workflow

- Select the highest-priority unblocked task unless the user explicitly requests another.
- Inspect every listed file before editing.
- Keep scope within the task.
- Use the stable `P48-###` ID in commits/PRs when practical.
- Never renumber or reuse IDs.
- If new work is discovered, create a new task rather than silently expanding scope.
- Run `./tools/build.sh` for every code change.
- Use `docs/TESTING.md` to report exactly which verification layers ran.
- Rendering, timing, input, loader and gameplay changes require emulator/real-hardware verification when their acceptance criteria say so.
- Code written but not fully verified is `VERIFY`, not `DONE`.
- Update `CHANGELOG.md` for meaningful changes.
- Record subtle regressions/failures in `docs/INCIDENTS.md` and link the preventive guard.

## Status values

- `READY` - understood and ready.
- `IN_PROGRESS` - actively being implemented.
- `BLOCKED` - dependency or decision prevents work.
- `VERIFY` - implementation exists but required verification is incomplete.
- `DONE` - implementation and required verification complete.
- `WONTFIX` - intentionally not implemented, with reason.

## Priorities

- `P0` - correctness/corruption; fix first.
- `P1` - architecture/compatibility/gameplay foundation.
- `P2` - maintainability, tooling, profiling, development quality.
- `P3` - later enhancement.

## Current execution order

The renderer migration is implemented but not yet fully verified. Do not start broad gameplay work until the `VERIFY` items below are either `DONE` or explicitly accepted with documented risk.

Recommended order:

`P48-001/P48-002 -> P48-010/P48-011/P48-012/P48-013 -> P48-003/P48-004 -> P48-008/P48-014 -> P48-009`

`P48-006` and `P48-007` remain independent. Complete `P48-016` before introducing actor art that needs explicit opaque-zero pixels.

---

## P48-001 - Preserve maze coordinates across attribute drawing

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Type:** rendering correctness
- **Files:** `src/maze.asm`, `src/video.asm`
- **Depends on:** none
- **Incident:** `INC-2026-001`

### Implemented

- `Video_DrawTile` preserves caller `DE`.
- `Maze_DrawTileAtOffset` and `Maze_DrawAtOffset` explicitly preserve maze-coordinate `DE`.
- public routine comments document the contract.

### Acceptance

- [x] attribute and bitmap paths use a documented coordinate contract
- [x] `Maze_DrawCell` is protected from the original clobber pattern
- [x] register contracts documented
- [ ] V2 canonical build passes
- [ ] V3 maze/pellet rendering visually verified

### Verification notes

Code implemented 2026-08-25. Build/runtime verification still required.

---

## P48-002 - Correct Sinclair 1 and Sinclair 2 directions

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Type:** input correctness
- **Files:** `src/input.asm`
- **Depends on:** none
- **Incident:** `INC-2026-002`

### Implemented

- Sinclair 1 (`6 7 8 9 0`) now maps left/right/down/up/fire.
- Sinclair 2 (`1 2 3 4 5`) now maps left/right/down/up/fire.
- public direction enum and `Input_Mode` values are unchanged.

### Acceptance

- [x] source bit-to-direction mapping corrected
- [x] Q/A/O/P path unchanged
- [x] Kempston path unchanged
- [ ] V2 build passes
- [ ] V3 both Sinclair modes manually smoke-tested

### Verification notes

Code implemented 2026-08-25. Manual device/emulator verification still required.

---

## P48-003 - Remove full-maze redraw from gameplay frames

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** rendering architecture
- **Files:** `src/main.asm`, `src/maze.asm`, `src/render.asm`, `src/player.asm`
- **Depends on:** `P48-010`, `P48-011`, `P48-012`
- **Incident:** `INC-2026-003`

### Implemented

- `Maze_Draw` remains in startup/level initialization only.
- `Render_Commit` restores previous dirty maze cells via `Maze_DrawCell`.
- `Render_Prepare` builds a bounded, de-duplicated dirty-cell list for the prepared 8x8 player sprite.
- normal frame path no longer calls `Maze_Draw`.
- maze restoration uses one bitmap+attribute operation per dirty cell; the earlier redundant attribute write was removed.

### Acceptance

- [x] `Maze_Draw` absent from normal per-frame gameplay path
- [x] dirty list bounded and de-duplicated in code
- [x] no duplicate attribute write in normal `Maze_DrawCell` restoration path
- [ ] V3 player leaves no trails
- [ ] V3 dirty cells restore current pellet/empty state visually
- [ ] V3 horizontal/vertical/turning movement visually correct
- [ ] V2 build passes
- [ ] V4 common/worst dirty count and timing recorded

### Verification notes

Implementation complete; runtime/timing verification pending.

---

## P48-004 - Stabilize attribute ownership for moving actors

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** Spectrum attribute policy
- **Files:** `src/maze.asm`, `src/render.asm`, `src/video.asm`
- **Depends on:** `P48-012`, `P48-003`

### Implemented

- moving actors do not write attribute memory in `render.asm`;
- empty and pellet corridor cells both use yellow ink on black paper;
- wall attributes remain maze-owned;
- dirty restoration restores maze bitmap/attributes through `Maze_DrawCell`.

### Acceptance

- [x] actor renderer performs no attribute writes
- [x] walkable cells use a player-visible attribute baseline
- [x] wall attributes remain maze-owned
- [ ] V3 actor visible at every sub-cell X/Y phase
- [ ] V3 no permanent attribute trails
- [ ] V2/V3 build and visual tests pass

### Verification notes

Source policy implemented; visual verification pending.

---

## P48-005 - Synchronize documentation with pixel movement

- **Status:** `DONE`
- **Priority:** `P1`
- **Type:** documentation

### Completed

- [x] pixel/sub-tile movement documented
- [x] `Pac_ReqDir` documented
- [x] repository structure documented
- [x] agent workflow points at canonical TODO

---

## P48-006 - Add exact GPL license file

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** legal/project metadata
- **Files:** `LICENSE`, `README.md`
- **Depends on:** project owner chooses exact GPL variant

### Resolution

After explicit owner choice (for example `GPL-3.0-only` or `GPL-3.0-or-later`), add canonical license text and make README match exactly. Agents must not guess the variant.

---

## P48-007 - Make VERSION the single release-version source

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** build maintainability
- **Files:** `VERSION`, `tools/build.sh`, `src/menu.asm`

### Problem

`VERSION` and the menu still duplicate the version string.

### Acceptance

- [ ] one human-edited version source
- [ ] menu uses generated value
- [ ] clean build succeeds

---

## P48-008 - Establish repeatable verification baseline

- **Status:** `VERIFY`
- **Priority:** `P2`
- **Type:** testing/tooling
- **Files:** `tools/check_project.py`, `tools/build.sh`, `docs/TESTING.md`

### Implemented

- `docs/TESTING.md` defines V0 static, V1 structural, V2 build, V3 emulator, V4 cycle-aware timing, and V5 hardware layers;
- build always runs sprite generation before assembly;
- checker enforces exactly 20 maze rows x 28 cells and valid cell values;
- checker enforces 160 unique generated phases, exactly 8 scanlines x 4 bytes per phase, and exact 40-pointer tables for each direction;
- post-assembly check enforces a 28,672-byte binary ceiling, reserving upper-RAM stack/headroom.

### Acceptance

- [x] deterministic structural regression checks exist
- [x] generated sprite assets validated structurally
- [x] binary/headroom guard exists
- [x] emulator/hardware/timing checklist documented
- [ ] V2 exact current build result recorded
- [ ] V3 protocol completed at least once on current renderer

---

## P48-009 - Implement first complete gameplay loop

- **Status:** `BLOCKED`
- **Priority:** `P2`
- **Type:** gameplay milestone
- **Depends on:** verified completion/acceptance of `P48-001`, `P48-002`, `P48-003`, `P48-004`, `P48-012`, `P48-014`

### Goal

After renderer/input foundation is verified, create child tasks for:

1. pellet consumption
2. remaining-pellet count
3. score/HUD
4. level complete
5. lives
6. one deterministic enemy
7. actor collision/life loss
8. game over/restart
9. further enemy personalities
10. energizers/frightened mode and sound

---

## P48-010 - Dedicated render module and prepare/commit phases

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** core architecture migration
- **Files:** `src/main.asm`, `src/render.asm`, `src/memory.asm`
- **Depends on:** `P48-001`

### Implemented

- `render.asm` is a real module included by `main.asm`;
- startup initializes renderer and prepares the first descriptor;
- frame order is `HALT -> Render_Commit -> input/update -> Render_Prepare`;
- renderer owns composition and dirty bookkeeping;
- player owns simulation only.

### Acceptance

- [x] `render.asm` included
- [x] prepare/commit public interfaces documented
- [x] renderer does not read input ports
- [x] screen writes isolated to render/video/maze restoration paths
- [ ] V2 build passes
- [ ] V3 runtime smoke test passes

---

## P48-011 - Generate masked pre-shifted 8x8 actor assets

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** asset/build architecture
- **Files:** `tools/gen_shifted_sprites.py`, `src/sprites.asm`, generated `src/generated/pac_shifted.asm`, `tools/build.sh`, `.gitignore`
- **Depends on:** none

### Implemented

- Python-stdlib generator extracts all 20 canonical player frames;
- emits eight phases per frame = 160 generated sprite phases;
- each generated row stores `maskL,imageL,maskR,imageR`;
- internal generator assertions validate phase 0 and mask/image invariants;
- build creates the generated include before assembly;
- generated directory is ignored by Git;
- obsolete handwritten mobile-actor `Pac_FrameTable*` tables were removed so generated tables are authoritative.

### Acceptance

- [x] eight phases generated for every required frame
- [x] phase-0 invariant encoded in generator self-check
- [x] masks are generated as inverse opaque occupancy for current Pac art
- [x] clean build path generates the include before assembly
- [x] structural checker validates phase row layout and exact pointer tables
- [ ] V2 actual build succeeds with `sjasmplus`

---

## P48-012 - Replace runtime-shift drawing with masked renderer

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** renderer implementation
- **Files:** `src/render.asm`, `src/video.asm`, generated sprite data
- **Depends on:** `P48-010`, `P48-011`
- **Incident:** `INC-2026-003`

### Implemented

- old `Video_DrawSpritePx` runtime-shift path removed from `video.asm`;
- 192-entry line-address LUT allocated in upper RAM and initialized at startup;
- phase is selected during prepare using `x & 7`;
- commit performs `(screen AND mask) OR image` over two bytes per row;
- no per-row source shifting in normal actor path;
- clipping is kept out of the hot loop under maze position invariants.

### Acceptance

- [x] normal actor hot path has no runtime bit shifting
- [x] masked compositing implemented
- [x] screen-line LUT used
- [ ] V3 actor verified at every x phase without maze damage
- [ ] V3 pellets/background visually preserved outside actor silhouette
- [ ] V2 build passes
- [ ] V4 timing recorded for 1 actor and planned maximum actor count

---

## P48-013 - Move player drawing out of player module

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** module ownership
- **Files:** `src/player.asm`, `src/render.asm`, `src/main.asm`
- **Depends on:** `P48-010`, `P48-012`

### Implemented

`src/player.asm` now contains movement/collision-coordinate simulation only. Player sprite selection and screen drawing are owned by `render.asm`. `Pac_FacingDir` preserves visual direction independently from a stopped `Pac_Dir`.

### Acceptance

- [x] `player.asm` contains no raw screen writes
- [x] renderer consumes player state through prepared descriptor variables
- [x] facing state remains logically independent from movement stop state
- [ ] V3 directional animation/stopping behavior verified
- [ ] V2 build passes

---

## P48-014 - Cycle-budget profiling and memory budget checks

- **Status:** `VERIFY`
- **Priority:** `P2`
- **Type:** performance engineering
- **Files:** `tools/check_project.py`, `tools/build.sh`, `docs/TESTING.md`
- **Depends on:** `P48-008`, meaningful timing on `P48-012`

### Implemented

- binary safe ceiling is checked automatically at 28,672 bytes from `ORG 32768`, reserving 4 KiB of upper-RAM headroom;
- ADR target remains common-case `Render_Commit` around/below 12,000 T-states, warning near 14,000;
- V4 protocol defines required timing evidence.

### Acceptance

- [x] binary/headroom checked deterministically
- [ ] V4 commit timing measured in cycle-aware environment
- [ ] maximum tested actors/dirty cells recorded
- [ ] evidence-based decision confirms 50 Hz or chooses fixed 25 Hz

---

## P48-015 - Persistent incident memory and changelog discipline

- **Status:** `DONE`
- **Priority:** `P1`
- **Type:** engineering process / AI regression prevention
- **Files:** `docs/INCIDENTS.md`, `CHANGELOG.md`, `docs/TESTING.md`, `AGENTS.md`, `docs/TODO.md`

### Implemented

- append-oriented incident registry with stable `INC-YYYY-NNN` IDs;
- incident lifecycle and severity model;
- required root-cause, corrective-action, regression-guard and verification fields;
- initial incidents record coordinate clobber, Sinclair mapping, and failed legacy renderer architecture;
- changelog has permanent `Unreleased` workflow;
- verification protocol defines what is required to close an incident;
- agents are required to read incident history before modifying affected modules and update incident/changelog records when appropriate.

### Acceptance

- [x] incident records survive resolution and are never renumbered/deleted
- [x] regression guards are mandatory for substantive incidents
- [x] changelog updated continuously, not only at releases
- [x] verification layers/closure rule documented
- [x] TODO/ADR/incident/changelog/testing roles are explicitly separated

---

## P48-016 - Support explicit canonical opacity masks for future actor art

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** sprite asset extensibility
- **Files:** `src/sprites.asm` or new canonical asset source, `tools/gen_shifted_sprites.py`, `tools/check_project.py`, `src/render.asm` only if generated layout changes
- **Depends on:** none for design; must be complete before using art that needs opaque zero-valued pixels

### Problem

The current generator treats every zero bit in a canonical sprite bitmap as transparent and derives the mask as the inverse of generated image occupancy. This is correct for current Pac frames.

Future actor art may need an opaque pixel whose displayed bitmap value is zero, or may require a silhouette mask different from the visible one-bit pattern. The current inferred-mask format cannot express that.

### Resolution

Before such art is introduced:

1. define a compact human/AI-editable canonical mask representation paired with each frame;
2. generate shifted image and shifted opacity mask independently;
3. keep the renderer's `maskL,imageL,maskR,imageR` hot format if possible;
4. extend structural checks so every canonical frame has a valid matching opacity mask;
5. retain backwards compatibility or migrate all current Pac frames deterministically.

### Acceptance

- [ ] canonical art can express opaque zero-valued pixels
- [ ] generator shifts image and opacity independently
- [ ] structural checks reject missing/malformed masks
- [ ] current Pac visuals remain equivalent
- [ ] V2/V3 verification passes after migration

---

## Adding tasks

Use the next unused ID and this minimum structure:

```text
## P48-XXX - Title
- Status
- Priority
- Type
- Files
- Depends on

### Problem
### Resolution / Implemented
### Acceptance
### Verification notes
```

Never encode important new work only in chat history or a commit message.
