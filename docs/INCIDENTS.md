# PAC48 Incident Registry

This file is the persistent engineering memory for bugs, regressions, failed approaches, and architecture mistakes that future contributors and AI agents must not rediscover from scratch.

It is **append-oriented**. Resolved incidents remain in the file permanently.

For planned work use `docs/TODO.md`. For change history use `CHANGELOG.md`. For architecture decisions use `docs/adr/`. Verification layers and closure requirements are defined in `docs/TESTING.md`.

## Mandatory agent rules

Before changing engine code, agents must scan this file for incidents involving the modules, registers, input devices, renderer paths, or build tools they are about to touch.

Create a new incident when any of these happens:

- a regression reaches `main`;
- a bug is subtle enough that another contributor could reasonably repeat it;
- an implementation appeared correct but failed assembly, emulator, hardware, timing, memory, or input verification;
- an architecture choice is abandoned because it caused measurable correctness/performance problems;
- a build/tooling failure reveals a missing invariant;
- a fix requires a non-obvious register, memory, timing, or hardware constraint.

Do **not** create incidents for ordinary feature TODOs or trivial typos caught before they affect the development baseline.

### Incident lifecycle

- `DETECTED` - problem known, root cause not yet fixed.
- `FIXED_PENDING_VERIFY` - corrective code exists but required verification is incomplete.
- `CLOSED` - fix is verified and a regression guard or explicit repeat-prevention rule exists.
- `ACCEPTED_RISK` - understood problem intentionally remains; rationale required.

### Stable IDs

Use `INC-YYYY-NNN`, increasing monotonically. Never renumber, delete, or reuse an ID.

### Required fields

Every incident must contain:

- Status
- Severity (`S0` corruption/crash, `S1` major functional/performance, `S2` localized, `S3` minor)
- Detected date
- Affected files/modules
- Symptom
- Root cause
- Corrective action
- Regression guard
- Verification evidence
- Related TODO/ADR/changelog/commit references when available

When an incident is fixed, update the existing entry instead of adding a second incident describing the fix.

---

## INC-2026-001 - Maze coordinates clobbered between attribute and bitmap drawing

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S0`
- **Detected:** 2026-08-25
- **Affected:** `src/maze.asm`, `src/video.asm`
- **Related TODO:** `P48-001`

### Symptom

A maze cell could write its attribute at the intended coordinates and then draw its bitmap/pellet using corrupted `DE` coordinates. This could produce misplaced bitmap writes and visual corruption.

### Root cause

`Maze_DrawTileAtOffset` converted maze coordinates in `DE` to screen-cell coordinates and called `Video_DrawTile`. `Video_DrawTile` reused `DE` internally for `ATTR_ADDR`. Callers then continued as though original maze coordinates were still present.

The deeper process failure was an undocumented register-preservation contract between low-level video routines and maze wrappers.

### Corrective action

- `Video_DrawTile` now explicitly preserves caller `DE`.
- `Maze_DrawTileAtOffset` and `Maze_DrawAtOffset` explicitly preserve their maze-coordinate `DE` contract.
- routine comments state preservation/clobber behavior.

### Regression guard

Any public assembly routine whose caller may reuse coordinates must document input/output/clobbered or preserved registers. New renderer/video routines must not rely on undocumented register survival.

### Verification evidence

Code fix implemented on 2026-08-25. V2 canonical build and V3 visual maze/pellet test remain required. The current assistant execution environment does not contain `sjasmplus` or `bin2tap.py`, so V2 could not be run here.

---

## INC-2026-002 - Sinclair 1/2 directions were mapped to the wrong keys

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/input.asm`
- **Related TODO:** `P48-002`

### Symptom

Sinclair joystick menu modes returned incorrect logical directions even though keyboard and Kempston paths appeared coherent.

### Root cause

The Interface 2 keyboard-bit mappings were documented incorrectly in source and then encoded from those incorrect comments.

Correct mappings are:

- Sinclair 1 (`6 7 8 9 0`): left, right, down, up, fire.
- Sinclair 2 (`1 2 3 4 5`): left, right, down, up, fire.

### Corrective action

`src/input.asm` now maps the active-low bits to the correct logical directions while retaining the existing public direction enum and `Input_Mode` values.

### Regression guard

Hardware input mappings must be documented beside the port/row access and manually smoke-tested for all four directions whenever `input.asm` changes.

### Verification evidence

Code fix implemented on 2026-08-25. V2 build and the Sinclair sections of V3 in `docs/TESTING.md` remain required. The current assistant execution environment does not contain `sjasmplus` or `bin2tap.py`.

---

## INC-2026-003 - Full-maze redraw and destructive runtime-shift sprite path

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/main.asm`, `src/video.asm`, `src/player.asm`, `src/render.asm`, build asset pipeline
- **Related ADR:** `docs/adr/0001-rendering-architecture.md`
- **Related TODO:** `P48-003`, `P48-010`, `P48-011`, `P48-012`, `P48-013`, `P48-014`

### Symptom

The engine redrew all 560 maze cells every frame and used `Video_DrawSpritePx`, which shifted each sprite row at runtime and overwrote screen bytes rather than transparently compositing with the background.

The full redraw hid trails caused by destructive drawing but scaled badly and left insufficient headroom for enemies, scoring, collision work, sound, and stable 50 Hz timing.

### Root cause

The initial incremental prototype mixed gameplay, background restoration, sprite transformation, and screen commit into one per-frame path. A temporary implementation became the de facto renderer without an explicit cycle/memory budget.

### Corrective action

The engine now implements the ADR 0001 architecture:

- initial maze draw only;
- dedicated `render.asm`;
- `Render_Prepare` separated from `Render_Commit`;
- masked composition `(screen AND mask) OR image`;
- eight build-generated horizontal phases;
- 192-entry scanline address LUT;
- dirty-cell restoration instead of full-maze redraw;
- player module no longer owns raw screen writes;
- moving actors do not rewrite attributes in the hot path;
- persistent facing direction is separate from active movement direction.

### Regression guard

- `Maze_Draw` must not return to the normal gameplay frame path.
- normal actor rendering must not reintroduce per-row runtime shifting.
- player/enemy simulation modules must not regain raw screen ownership.
- any future renderer rewrite requires cycle-aware profiling and an ADR when it changes the core strategy.
- `tools/build.sh` generates and structurally validates sprite assets before assembly.
- `docs/TESTING.md` defines phase-sweep, dirty-restore, turning, timing, and incident-closure checks.

### Verification evidence

Architecture/code migration implemented on 2026-08-25. A local Python syntax/math smoke of the sprite-generation approach passed. Full V2 assembly/TAP could not run because `sjasmplus` and `bin2tap.py` are absent in the current execution environment. V3 emulator rendering tests and V4 cycle-aware timing remain required before closure.

---

## Incident template

```markdown
## INC-YYYY-NNN - Short title

- **Status:** `DETECTED`
- **Severity:** `S?`
- **Detected:** YYYY-MM-DD
- **Affected:** files/modules
- **Related TODO:** optional
- **Related ADR:** optional

### Symptom

### Root cause

### Corrective action

### Regression guard

### Verification evidence
```
