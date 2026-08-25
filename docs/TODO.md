# PAC48 Technical TODO

This file is the canonical work queue for PAC48.

It is intentionally structured so that human contributors and AI coding agents can pick up work without reconstructing project history from commits or chat logs.

## Agent workflow

Before changing code:

1. Read `AGENTS.md`.
2. Read `docs/ARCHITECTURE.md`.
3. Read this file from the top and select the highest-priority task that is not blocked.
4. Inspect every file listed in the task before editing.
5. Keep the change limited to the selected task unless another task is an unavoidable dependency.

While working:

- Keep the task ID in commit/PR messages when practical, for example `P48-001: preserve maze coordinates during tile drawing`.
- Do not change a task to `DONE` merely because code was written.
- If implementation is complete but required verification cannot be performed, set it to `VERIFY` and record exactly what is missing.
- If a new bug or prerequisite is discovered, add a new task with a new stable ID. Do not silently broaden an existing task.
- Never reuse or renumber task IDs, including completed or cancelled tasks.

After changing code:

1. Run `./tools/build.sh` at minimum.
2. Perform emulator or real-hardware verification when the task changes timing, rendering, controls, loader behavior, or gameplay.
3. Update the task's checkboxes and `Status`.
4. Add concise evidence under `Verification notes`.
5. Update `docs/ARCHITECTURE.md` or `AGENTS.md` if an architectural assumption changed.

## Status values

- `READY` — understood and ready to implement.
- `IN_PROGRESS` — actively being implemented.
- `BLOCKED` — cannot proceed until the listed dependency is resolved.
- `VERIFY` — implementation exists but required verification is incomplete.
- `DONE` — implementation and required verification are complete.
- `WONTFIX` — intentionally not being implemented; explain why.

## Priority values

- `P0` — correctness/corruption issue; fix before feature development.
- `P1` — major correctness, compatibility, or gameplay-foundation issue.
- `P2` — important maintainability, performance, or development-quality work.
- `P3` — enhancement or later milestone.

---

## P48-001 — Preserve maze coordinates across attribute drawing

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** rendering correctness
- **Owner:** unassigned
- **Files:** `src/maze.asm`, `src/video.asm`
- **Depends on:** none

### Problem

`Maze_Draw` and `Maze_DrawCell` draw a tile attribute and then immediately draw the bitmap/sprite for the same maze coordinates.

`Maze_DrawTileAtOffset` calls `Video_DrawTile`. `Video_DrawTile` uses `DE` internally to build `ATTR_ADDR`, so it returns with `DE` no longer containing the caller's coordinates. The maze code then reuses `D/E` as if the original coordinates were still present.

This can make pellet/empty bitmap drawing use corrupted coordinates and can cause writes to the wrong bitmap location.

### Resolution plan

Use the smallest interface-safe fix first:

1. Make `Maze_DrawTileAtOffset` preserve the caller's original `DE` around its coordinate conversion and `Video_DrawTile` call.
2. Document the actual clobbered/preserved registers for both `Maze_DrawTileAtOffset` and `Video_DrawTile`.
3. Audit other call sites that invoke `Video_DrawTile` and then reuse `DE`.
4. Do not perform a broad renderer rewrite as part of this task.

A possible minimal implementation shape is to save `DE` before offset conversion and restore it before returning. The exact register strategy should be chosen after inspecting the current routines and cycle impact.

### Acceptance criteria

- [ ] `Maze_DrawTileAtOffset` returns with the caller's maze coordinates intact in `DE`.
- [ ] `Maze_Draw` draws attribute and bitmap using the same intended cell coordinates.
- [ ] `Maze_DrawCell` does the same.
- [ ] Routine comments document register behavior.
- [ ] `./tools/build.sh` succeeds.
- [ ] Maze/pellet rendering is visually checked in an emulator or on real hardware.

### Verification notes

Not yet implemented.

---

## P48-002 — Correct Sinclair 1 and Sinclair 2 joystick directions

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** input correctness
- **Owner:** unassigned
- **Files:** `src/input.asm`, optionally `docs/controls.md` if created
- **Depends on:** none

### Problem

The current Sinclair joystick direction comments and returned direction values do not match the standard Interface 2 key mapping.

Expected mapping:

- Sinclair 1 / keys `6 7 8 9 0`: `6=left`, `7=right`, `8=down`, `9=up`, `0=fire`.
- Sinclair 2 / keys `1 2 3 4 5`: `1=left`, `2=right`, `3=down`, `4=up`, `5=fire`.

The current code maps these bits to different directions, so menu modes 3 and 4 do not behave correctly.

### Resolution plan

1. Keep `Input_Mode` values unchanged.
2. Correct only the bit-to-direction mapping inside `.read_sinclair1` and `.read_sinclair2`.
3. Keep the public `Input_Read` enum unchanged: `0=none`, `1=up`, `2=down`, `3=left`, `4=right`.
4. Add or update concise comments showing physical key, direction, and active-low behavior.
5. Verify all four directions for both Sinclair modes.

### Acceptance criteria

- [ ] Sinclair 1 returns the correct direction for keys 6/7/8/9.
- [ ] Sinclair 2 returns the correct direction for keys 1/2/3/4.
- [ ] Keyboard Q/A/O/P behavior is unchanged.
- [ ] Kempston behavior is unchanged.
- [ ] `./tools/build.sh` succeeds.
- [ ] Both Sinclair modes are manually checked in an emulator or on compatible hardware.

### Verification notes

Not yet implemented.

---

## P48-003 — Remove full-maze redraw from every gameplay frame

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** performance / rendering architecture
- **Owner:** unassigned
- **Files:** `src/main.asm`, `src/player.asm`, `src/maze.asm`, possibly `src/video.asm`
- **Depends on:** `P48-001`

### Problem

`MainLoop` currently calls `Maze_Draw` every frame. The maze is 28x20, so 560 cells are rebuilt repeatedly before drawing the player.

This is wasteful on a 48K Spectrum and will leave very little timing headroom for pellet logic, HUD, enemies, collisions, game states, and sound.

The code already contains partial dirty-rendering primitives (`Player_Erase`, `Player_RestoreBlock3x3`, `Maze_DrawCell`) that are not currently used by the main loop.

### Resolution plan

Implement incrementally rather than replacing the renderer wholesale:

1. Keep the initial `Maze_Draw` during game setup.
2. Before moving the player, restore only the cells covered by the player's previous pixel position.
3. Update input and player position.
4. Draw the player at the new pixel position.
5. Redraw only maze cells whose persistent state changes, such as a consumed pellet.
6. Measure or at least reason about the worst-case number of restored cells per frame.
7. Keep a temporary way to compare the optimized result against the full redraw during development if useful, but do not leave two permanent rendering paths without justification.

### Acceptance criteria

- [ ] `Maze_Draw` is not called on every gameplay frame.
- [ ] The initial maze is still rendered correctly.
- [ ] Moving Pac does not leave bitmap trails.
- [ ] Old Pac pixels are restored from current maze state.
- [ ] No visible maze corruption occurs at cell boundaries.
- [ ] `./tools/build.sh` succeeds.
- [ ] Movement is visually verified for horizontal and vertical travel and turns.

### Verification notes

Not yet implemented.

---

## P48-004 — Make pixel movement safe across ZX attribute cells

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** rendering / ZX attribute handling
- **Owner:** unassigned
- **Files:** `src/maze.asm`, `src/video.asm`, `src/player.asm`
- **Depends on:** `P48-001`; coordinate work should be evaluated together with `P48-003`

### Problem

`Video_DrawSpritePx` allows an 8x8 sprite to be shifted across byte/cell boundaries, while ZX Spectrum color attributes remain 8x8-cell based.

`Maze_AttrPellet` uses yellow ink on black paper, but `Maze_AttrEmpty` currently uses black ink on black paper. After pellets become consumable, Pac can therefore cross an empty path cell whose attribute makes his bitmap invisible or partially black. Similar boundary artifacts must be considered whenever a shifted sprite spans multiple attribute cells.

### Resolution plan

Prefer the cheapest stable strategy compatible with the current art:

1. Give all walkable corridor cells a compatible player-visible ink/paper combination even when their bitmap is empty. For the current yellow player, yellow ink on black paper is the natural baseline.
2. Keep wall attributes independent.
3. Verify shifted horizontal and vertical frames at every `x mod 8` / `y mod 8` phase.
4. Only add multi-attribute sprite painting if a uniform walkable-cell attribute is insufficient for future graphics.
5. Ensure dirty restoration from `P48-003` restores the correct maze attributes after the player leaves.

### Acceptance criteria

- [ ] Pac remains visible while crossing pellet and empty corridor cells.
- [ ] No new permanent color trails are left behind.
- [ ] Walls retain their intended attributes.
- [ ] Horizontal and vertical sub-cell movement is visually checked.
- [ ] `./tools/build.sh` succeeds.

### Verification notes

Not yet implemented.

---

## P48-005 — Synchronize documentation with the current pixel-movement engine

- **Status:** `DONE`
- **Priority:** `P1`
- **Type:** documentation
- **Owner:** documentation pass 2026-08-25
- **Files:** `README.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/TODO.md`
- **Depends on:** none

### Problem

Previous documentation described the player model as tile-based and the sprite renderer as cell-aligned only. The current code already uses `Pac_PixelX`, `Pac_PixelY`, `Pac_ReqDir`, grid-aligned direction changes, and `Video_DrawSpritePx` for sub-cell movement.

The old README also listed planned directories/files as if they already existed.

### Resolution completed

- Documentation now treats pixel/sub-tile movement as the current design.
- The current real repository structure is documented.
- `AGENTS.md` points agents to this backlog before implementation work.
- Known findings are tracked as stable task IDs instead of stale prose bullets.

### Acceptance criteria

- [x] Pixel movement is documented as current behavior.
- [x] `Pac_ReqDir` and grid-aligned direction changes are documented.
- [x] `Video_DrawSpritePx` is documented.
- [x] README structure reflects files that actually exist or clearly marks generated paths.
- [x] AI workflow points to this TODO file.

### Verification notes

Documentation-only change; no executable code changed.

---

## P48-006 — Add an explicit license file and exact GPL identifier

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** project/legal metadata
- **Owner:** unassigned
- **Files:** `LICENSE`, `README.md`
- **Depends on:** owner decision on exact license variant

### Problem

README historically stated that PAC48 is released under the GNU GPL and referred to a `LICENSE` file, but no license file currently exists in the repository and no exact GPL version is pinned.

### Resolution plan

1. Project owner chooses the exact license, for example GPL-3.0-only or GPL-3.0-or-later.
2. Add the canonical license text as `LICENSE`.
3. Update README to use the exact SPDX-style identifier/name.
4. Do not let an AI agent guess the license variant on behalf of the owner.

### Acceptance criteria

- [ ] Exact GPL variant explicitly approved by project owner.
- [ ] `LICENSE` exists at repository root.
- [ ] README names the same exact license.

### Verification notes

Blocked only on the owner's license-version choice; implementation itself is trivial.

---

## P48-007 — Make VERSION the single source of release version

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** build / maintainability
- **Owner:** unassigned
- **Files:** `VERSION`, `tools/build.sh`, `src/menu.asm`, generated include if adopted
- **Depends on:** none

### Problem

The repository has a canonical `VERSION` file (`0.3.4-beta` at the time this task was created), but the same version string is also hard-coded in `src/menu.asm`.

The two values can drift on the next release.

### Resolution plan

Prefer a build-generated assembly include:

1. Keep `VERSION` as the human-edited source of truth.
2. Have `tools/build.sh` generate a small file under `build/` (or another intentionally generated path) containing an assembly string/constant derived from `VERSION`.
3. Include that generated symbol from the menu/version display path without changing the load address.
4. Ensure a clean build creates everything it needs from a fresh checkout.
5. Do not require developers to edit two version locations manually.

### Acceptance criteria

- [ ] Version is edited in one source file only.
- [ ] Menu displays the version from that source.
- [ ] Clean `./tools/build.sh` succeeds.
- [ ] Generated version data is ignored by Git if appropriate.

### Verification notes

Not yet implemented.

---

## P48-008 — Establish a repeatable verification baseline

- **Status:** `READY`
- **Priority:** `P2`
- **Type:** development quality
- **Owner:** unassigned
- **Files:** `tools/`, documentation, optionally emulator/test scripts
- **Depends on:** none

### Problem

Historical PRs frequently recorded `Testing: not run`, and the project has no repeatable regression checks beyond assembly/TAP generation.

For low-level Z80 work, a successful assembly is necessary but does not prove rendering, control mapping, loader behavior, or timing correctness.

### Resolution plan

Build this in layers:

1. Treat `./tools/build.sh` as mandatory for every code change.
2. Add lightweight static checks that are deterministic and useful, such as maze byte count (`Maze_Width * Maze_Height`) and required output existence.
3. Document a standard Fuse/emulator smoke-test sequence covering load, menu, each input mode, maze render, horizontal/vertical movement, and turning.
4. If automation is added later, keep it compatible with local development and do not make emulator-only behavior part of the game runtime.

### Acceptance criteria

- [ ] Mandatory local build procedure is documented.
- [ ] At least one deterministic structural regression check exists beyond mere output-file existence.
- [ ] Emulator smoke-test checklist is documented.
- [ ] Contributors can report exactly which verification layers were completed.

### Verification notes

Not yet implemented.

---

## P48-009 — Implement the first complete gameplay loop

- **Status:** `BLOCKED`
- **Priority:** `P2`
- **Type:** gameplay milestone
- **Owner:** unassigned
- **Files:** expected to span `src/maze.asm`, `src/memory.asm`, `src/player.asm`, `src/main.asm`, `src/video.asm`; new module only when justified
- **Depends on:** `P48-001`, `P48-002`, `P48-003`, `P48-004`

### Goal

Move PAC48 from an engine movement demo to a small but complete playable loop without prematurely implementing complex ghost AI.

### Recommended sequence

Create child tasks with new IDs when implementation starts. Suggested order:

1. Pellet consumption owned by maze logic.
2. Remaining-pellet count.
3. Score state and minimal HUD.
4. Level-complete state when pellet count reaches zero.
5. Lives state.
6. One deterministic enemy using maze collision.
7. Player/enemy collision and life loss.
8. Game over and restart flow.
9. Additional enemies/personality only after one enemy is stable.
10. Energizers/frightened mode and sound after the core loop is verified.

### Acceptance criteria

- [ ] Child tasks exist before broad gameplay work begins.
- [ ] Each child task is independently buildable/verifiable.
- [ ] Core engine fixes are complete before feature expansion.

### Verification notes

Blocked on rendering/input foundation work.

---

## Adding new tasks

Copy this template and allocate the next unused `P48-###` ID:

```md
## P48-### — Short imperative title

- **Status:** `READY`
- **Priority:** `P0|P1|P2|P3`
- **Type:** bug | performance | gameplay | build | docs | refactor | compatibility
- **Owner:** unassigned
- **Files:** `path`, `path`
- **Depends on:** none | `P48-###`

### Problem

Describe the observable problem and why it matters.

### Resolution plan

1. Smallest safe step.
2. Next step.
3. Explicit non-goals if scope could expand.

### Acceptance criteria

- [ ] Observable criterion.
- [ ] `./tools/build.sh` succeeds for code changes.
- [ ] Emulator/hardware verification when relevant.

### Verification notes

Not yet implemented.
```
