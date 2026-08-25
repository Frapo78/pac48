# PAC48 Technical TODO

This is the canonical work queue for PAC48.

Read in this order before implementation:

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. this file

## Agent workflow

- Select the highest-priority unblocked task unless the user explicitly requests another.
- Inspect every listed file before editing.
- Keep scope within the task.
- Use the stable `P48-###` ID in commits/PRs when practical.
- Never renumber or reuse IDs.
- If new work is discovered, create a new task rather than silently expanding scope.
- Run `./tools/build.sh` for every code change.
- Rendering, timing, input, loader and gameplay changes require emulator/real-hardware verification when their acceptance criteria say so.
- Code written but not fully verified is `VERIFY`, not `DONE`.

## Status values

- `READY` - understood and ready.
- `IN_PROGRESS` - actively being implemented.
- `BLOCKED` - dependency or decision prevents work.
- `VERIFY` - implementation exists but verification is incomplete.
- `DONE` - implementation and required verification complete.
- `WONTFIX` - intentionally not implemented, with reason.

## Priorities

- `P0` - correctness/corruption; fix first.
- `P1` - architecture/compatibility/gameplay foundation.
- `P2` - maintainability, tooling, profiling, development quality.
- `P3` - later enhancement.

## Recommended execution order

`P48-001 -> P48-002 -> P48-010 -> P48-011 -> P48-012 -> P48-003 -> P48-004 -> P48-008/P48-014 -> P48-009`

`P48-006` and `P48-007` can be completed independently when convenient.

---

## P48-001 - Preserve maze coordinates across attribute drawing

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** rendering correctness
- **Files:** `src/maze.asm`, `src/video.asm`
- **Depends on:** none

### Problem

`Maze_DrawTileAtOffset` calls `Video_DrawTile`, which uses `DE` internally. Callers then reuse `D/E` as if the maze coordinates were preserved. This can make the bitmap half of a maze-cell draw use corrupted coordinates.

### Resolution

1. Define/document the register contract of both routines.
2. Make `Maze_DrawTileAtOffset` preserve caller `DE`, or otherwise change every caller to a documented safe convention.
3. Audit every `Video_DrawTile` call that relies on `DE` afterwards.
4. Keep this a minimal correctness fix; do not combine with renderer migration.

### Acceptance

- [ ] attribute and bitmap for a cell use identical intended coordinates
- [ ] `Maze_DrawCell` is safe
- [ ] register contracts are documented
- [ ] `./tools/build.sh` passes
- [ ] maze/pellets visually verified

### Verification notes

Not implemented.

---

## P48-002 - Correct Sinclair 1 and Sinclair 2 directions

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** input correctness
- **Files:** `src/input.asm`
- **Depends on:** none

### Problem

Current Sinclair direction mappings do not match the Interface 2 key layout.

Expected:

- Sinclair 1 (`6 7 8 9 0`): `6=left`, `7=right`, `8=down`, `9=up`, `0=fire`
- Sinclair 2 (`1 2 3 4 5`): `1=left`, `2=right`, `3=down`, `4=up`, `5=fire`

### Resolution

Correct only bit-to-direction mapping. Keep `Input_Mode` values and public direction enum unchanged.

### Acceptance

- [ ] both Sinclair modes return correct four directions
- [ ] Q/A/O/P unchanged
- [ ] Kempston unchanged
- [ ] build passes
- [ ] manual control smoke test passes

### Verification notes

Not implemented.

---

## P48-003 - Remove full-maze redraw from gameplay frames

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** rendering architecture
- **Files:** `src/main.asm`, `src/maze.asm`, `src/render.asm`, `src/player.asm`
- **Depends on:** `P48-010`, `P48-011`, `P48-012`

### Problem

Current `MainLoop` redraws all 560 maze cells every frame. This is the wrong scaling model for a mostly static single-screen maze and is currently compensating for destructive actor drawing.

### Resolution

Implement the dirty-restoration model from ADR 0001:

1. draw the maze once at level start;
2. track cells touched by the displayed actor sprites;
3. on next commit restore only those cells from current `Maze_Map` state;
4. include cells whose persistent state changed (for example consumed pellets);
5. draw new actors;
6. record their touched cells for the next frame.

Start with a bounded short list and simple de-duplication. Do not introduce a full framebuffer.

### Acceptance

- [ ] `Maze_Draw` is absent from normal per-frame gameplay path
- [ ] player leaves no trails
- [ ] dirty cells restore current pellet/empty state
- [ ] overlapping dirty cells are not restored redundantly enough to break timing
- [ ] horizontal/vertical/turning movement visually correct
- [ ] build passes
- [ ] cycle-aware verification records common/worst dirty count

### Verification notes

Blocked on new render pipeline.

---

## P48-004 - Stabilize attribute ownership for moving actors

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** Spectrum attribute policy
- **Files:** `src/maze.asm`, `src/render.asm`, `src/video.asm`
- **Depends on:** `P48-012`, `P48-003`

### Problem

Spectrum colors belong to 8x8 attribute cells. Per-sprite attribute writes create color clash and restoration problems when actors move across cells.

### Resolution

Follow ADR 0001 baseline:

1. moving actors do not write attributes in the hot path;
2. walkable cells use an attribute that keeps actor pixels visible;
3. wall attributes remain maze-owned;
4. dirty restoration restores persistent maze attributes;
5. distinct ghost colors are deferred to a separate explicit extension.

### Acceptance

- [ ] actors remain visible at every sub-cell X/Y phase
- [ ] no permanent attribute trails
- [ ] walls retain correct colors
- [ ] no actor routine casually owns attribute memory
- [ ] build and visual tests pass

### Verification notes

Blocked on masked renderer/dirty restore.

---

## P48-005 - Synchronize documentation with pixel movement

- **Status:** `DONE`
- **Priority:** `P1`
- **Type:** documentation
- **Files:** `README.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/TODO.md`

### Completed

- [x] pixel/sub-tile movement documented
- [x] `Pac_ReqDir` documented
- [x] current repository structure documented
- [x] agent workflow points at canonical TODO

### Verification notes

Documentation-only.

---

## P48-006 - Add exact GPL license file

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** legal/project metadata
- **Files:** `LICENSE`, `README.md`
- **Depends on:** project owner chooses exact GPL variant

### Resolution

After explicit owner choice (for example `GPL-3.0-only` or `GPL-3.0-or-later`), add canonical license text and make README match exactly.

Do not let an agent guess the license variant.

---

## P48-007 - Make VERSION the single release-version source

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** build maintainability
- **Files:** `VERSION`, `tools/build.sh`, `src/menu.asm`

### Problem

`VERSION` and the menu currently duplicate the version string.

### Resolution

Generate an assembly include/string from `VERSION` during the build so a clean checkout edits the version in one place only.

### Acceptance

- [ ] one human-edited version source
- [ ] menu uses generated value
- [ ] clean build succeeds

---

## P48-008 - Establish repeatable verification baseline

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** testing/tooling
- **Files:** `tools/`, docs

### Resolution

1. Keep `./tools/build.sh` mandatory.
2. Add deterministic structural checks (maze size, generated-asset validity, output existence, memory-size limits).
3. Document a standard 48K emulator smoke test.
4. Report exactly which verification layers ran.

### Acceptance

- [ ] structural regression checks exist
- [ ] emulator smoke-test checklist exists
- [ ] generated sprite assets are validated once P48-011 lands

---

## P48-009 - Implement first complete gameplay loop

- **Status:** `BLOCKED`
- **Priority:** `P2`
- **Type:** gameplay milestone
- **Depends on:** `P48-001`, `P48-002`, `P48-003`, `P48-004`, `P48-012`

### Goal

After rendering foundation is stable, create child tasks for:

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

Do not begin broad gameplay work before the renderer migration is verified.

---

## P48-010 - Introduce dedicated render module and prepare/commit frame phases

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** core architecture migration
- **Files:** `src/main.asm`, new `src/render.asm`, `src/memory.asm`, `AGENTS.md` if interfaces differ
- **Depends on:** `P48-001`

### Problem

Gameplay logic and screen writes currently share the same phase and player code draws itself directly.

### Resolution

Create `render.asm` as a real module, not a placeholder.

Target orchestration:

```text
HALT
Render_Commit
Input_Read
Game_Update
Render_Prepare
```

Initial migration may still call legacy draw primitives internally, but module ownership must be established:

- renderer owns frame composition;
- player owns simulation;
- video owns low-level screen access.

### Acceptance

- [ ] `render.asm` included from `main.asm`
- [ ] public prepare/commit interfaces documented
- [ ] player state can be represented by a render descriptor without renderer reading input ports
- [ ] screen writes are isolated to render/video/maze restoration paths
- [ ] build passes

### Verification notes

Not implemented.

---

## P48-011 - Generate masked pre-shifted 8x8 actor assets

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** asset/build architecture
- **Files:** `tools/`, canonical sprite source, generated assembly include, `tools/build.sh`, `.gitignore` as needed
- **Depends on:** none

### Problem

Current actor renderer shifts sprite rows at runtime. The accepted architecture spends upper-RAM data to remove shifting from the hot path.

### Resolution

Create a dependency-free build tool (Python stdlib is acceptable) that converts canonical 8x8 frames into eight horizontal phases.

Each phase must provide image and mask data for two screen bytes per row as needed by `screen=(screen AND mask) OR image`.

Requirements:

- canonical art remains human/AI editable;
- generated output is deterministic;
- generator validates frame dimensions and values;
- a clean build generates everything before assembly;
- generated data lives in upper RAM with the program.

### Acceptance

- [ ] eight phases generated for each required frame
- [ ] phase 0 reproduces canonical frame exactly
- [ ] phase 1..7 correctly spill into adjacent byte
- [ ] masks preserve transparent background
- [ ] build works from clean checkout
- [ ] structural generator tests/checks pass

### Verification notes

Not implemented.

---

## P48-012 - Replace runtime-shift actor drawing with masked fast renderer

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** renderer implementation
- **Files:** `src/render.asm`, `src/video.asm`, generated sprite data, `src/player.asm`
- **Depends on:** `P48-010`, `P48-011`

### Problem

`Video_DrawSpritePx` shifts at runtime and destructively writes bytes, forcing expensive background redraw.

### Resolution

1. Add 192-entry screen-line address table (384 bytes).
2. Select pre-shift phase using `x & 7` during `Render_Prepare`.
3. Precompute descriptor fields needed by commit.
4. In commit use masked composition, no runtime row shifting.
5. Add aligned fast path for phase 0 if it materially reduces cost.
6. Keep clipping outside the hot loop when maze invariants guarantee on-screen actors.
7. Stop using legacy `Video_DrawSpritePx` for normal actors once verified.

### Acceptance

- [ ] actor can move at every pixel X phase without damaging surrounding maze bitmap
- [ ] pellets/background remain visible outside opaque sprite pixels
- [ ] no per-row runtime shifting in normal actor hot path
- [ ] screen-line LUT used
- [ ] build passes
- [ ] cycle-aware timing recorded for one actor and planned maximum actor count

### Verification notes

Blocked on render module/assets.

---

## P48-013 - Move player drawing out of player module

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** module ownership
- **Files:** `src/player.asm`, `src/render.asm`, `src/main.asm`
- **Depends on:** `P48-010`, `P48-012`

### Resolution

Replace direct `Player_Draw` screen ownership with a player-to-render descriptor/interface. Player chooses logical animation state; renderer resolves phase/address and draws.

### Acceptance

- [ ] `player.asm` contains no raw screen writes
- [ ] animation direction/frame behavior preserved
- [ ] renderer can later accept enemies through the same actor-descriptor concept
- [ ] build/runtime tests pass

---

## P48-014 - Add cycle-budget profiling and memory budget checks

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** performance engineering
- **Files:** `tools/`, docs, build outputs
- **Depends on:** `P48-008`; meaningful render measurements depend on `P48-012`

### Resolution

Track two explicit budgets:

1. **Render timing:** common/worst `Render_Commit` T-states, with initial goal around <=12,000 and warning near 14,000.
2. **Upper RAM:** assembled binary/generated-data size plus safe stack/headroom below `$10000`.

Prefer profiler/emulator measurements. If only estimates exist, label them estimates.

### Acceptance

- [ ] binary size/headroom checked automatically or reported deterministically
- [ ] commit timing measured in a cycle-aware environment
- [ ] maximum tested actors and dirty cells recorded
- [ ] decision on 50 Hz vs fixed 25 Hz is evidence-based

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
### Resolution
### Acceptance
### Verification notes
```

Never encode important new work only in chat history or a commit message.
