# PAC48 Incident Registry

This file is the persistent engineering memory for bugs, regressions, failed approaches, and architecture mistakes that future contributors and AI agents must not rediscover from scratch.

It is **append-oriented**. Resolved incidents remain permanently.

For planned work use `docs/TODO.md`. For change history use `CHANGELOG.md`. For architecture decisions use `docs/adr/`. Verification layers and closure requirements are defined in `docs/TESTING.md`.

## Mandatory agent rules

Before changing engine code, agents must scan this file for incidents involving the modules, registers, input devices, renderer paths, build tools, or verification infrastructure they are about to touch.

Create a new incident when:

- a regression reaches `main`;
- a subtle bug could reasonably be repeated;
- code appeared correct but failed assembly, emulator, hardware, timing, memory, input, or CI verification;
- an architecture/test approach is abandoned because it caused measurable problems;
- a build/tooling failure reveals a missing invariant;
- a fix depends on a non-obvious register, memory, timing, hardware, or CI constraint.

Do not create incidents for normal feature TODOs or trivial typos caught before they affect the development baseline.

### Incident lifecycle

- `DETECTED` - problem known, root cause not yet fixed.
- `FIXED_PENDING_VERIFY` - corrective code exists but required verification is incomplete.
- `CLOSED` - fix is verified and a regression guard/repeat-prevention rule exists.
- `ACCEPTED_RISK` - understood problem intentionally remains; rationale required.

### Stable IDs

Use `INC-YYYY-NNN`, increasing monotonically. Never renumber, delete, or reuse an ID.

### Required fields

Every incident must contain Status, Severity (`S0` corruption/crash, `S1` major functional/performance, `S2` localized/tooling, `S3` minor), detected date, affected files/modules, symptom, root cause, corrective action, regression guard, verification evidence, and related TODO/ADR/changelog/commit references when available.

When an incident is fixed, update the existing entry instead of adding a second incident describing the fix.

---

## INC-2026-001 - Maze coordinates clobbered between attribute and bitmap drawing

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S0`
- **Detected:** 2026-08-25
- **Affected:** `src/maze.asm`, `src/video.asm`
- **Related TODO:** `P48-001`

### Symptom

A maze cell could write its attribute at the intended coordinates and then draw its bitmap/pellet using corrupted `DE` coordinates, producing misplaced bitmap writes and visual corruption.

### Root cause

`Maze_DrawTileAtOffset` converted maze coordinates in `DE` and called `Video_DrawTile`, which reused `DE` internally. Callers implicitly assumed the original coordinate survived. The deeper process failure was an undocumented register-preservation contract.

### Corrective action

- `Video_DrawTile` explicitly preserves caller `DE`.
- `Maze_DrawTileAtOffset` and `Maze_DrawAtOffset` preserve maze-coordinate `DE`.
- public routine comments document the contract.

### Regression guard

Public assembly routines whose callers may reuse coordinates must document input/output/clobbered/preserved registers. Architecture checks and review must reject reliance on undocumented register survival.

### Verification evidence

V1/V2 passed in GitHub Actions run `32797213612` on 2026-08-25 using sjasmplus 1.23.1 and SkoolKit 10.1: 0 assembler errors, 0 warnings, TAP generated successfully. V3 visual maze/pellet verification remains required before `CLOSED`.

---

## INC-2026-002 - Sinclair 1/2 directions were mapped to the wrong keys

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/input.asm`
- **Related TODO:** `P48-002`

### Symptom

Sinclair joystick menu modes returned incorrect logical directions while keyboard and Kempston paths appeared coherent.

### Root cause

The Interface 2 keyboard-bit mappings were documented incorrectly in source and then encoded from those incorrect comments.

Correct mappings:

- Sinclair 1 (`6 7 8 9 0`): left, right, down, up, fire.
- Sinclair 2 (`1 2 3 4 5`): left, right, down, up, fire.

### Corrective action

`src/input.asm` maps active-low bits to the correct logical directions while retaining existing `Input_Mode` values and the public direction enum.

### Regression guard

Hardware input mappings must be documented beside port/row access and all four directions must be checked whenever `input.asm` changes.

### Verification evidence

V1/V2 passed in GitHub Actions run `32797213612`: clean assembly and TAP generation. The Sinclair portions of V3 remain required before `CLOSED`.

---

## INC-2026-003 - Full-maze redraw and destructive runtime-shift sprite path

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/main.asm`, `src/video.asm`, `src/player.asm`, `src/render.asm`, build asset pipeline
- **Related ADR:** `docs/adr/0001-rendering-architecture.md`
- **Related TODO:** `P48-003`, `P48-010`, `P48-011`, `P48-012`, `P48-013`, `P48-014`

### Symptom

The engine redrew all 560 maze cells every frame and shifted/wrote actor bytes destructively at runtime. Full redraw repaired the resulting trails but consumed frame budget that will be needed for enemies, score, collisions, and sound.

### Root cause

The incremental prototype mixed simulation, background restoration, sprite transformation, and screen commit. A temporary implementation became the renderer without an explicit cycle/memory budget.

### Corrective action

ADR 0001 is implemented at the code level:

- initial maze draw only;
- dedicated `render.asm`;
- `Render_Prepare` separated from `Render_Commit`;
- masked `(screen AND mask) OR image` composition;
- eight build-generated horizontal phases;
- 192-entry scanline LUT;
- dirty-cell restoration;
- player module has no raw screen ownership;
- moving actors do not rewrite attributes in the hot path;
- persistent facing direction is separate from active movement.

### Regression guard

- canonical build fails if discarded architecture patterns reappear;
- `Maze_Draw` must not return to normal frame orchestration;
- normal actor drawing must not reintroduce per-row runtime shifting;
- player/enemy simulation must not regain raw screen ownership;
- generated sprite structure and memory budget are checked automatically;
- renderer reference-model tests validate scanline addresses, all shift phases, masked compositing, and dirty-cell coverage;
- core renderer changes require profiling/new ADR when they alter strategy.

### Verification evidence

V1/V2 passed in run `32797213612`: structural/architecture checks passed; sjasmplus assembled 3,081 source lines with 0 errors/0 warnings; BIN and TAP artifacts were produced. Subsequent canonical builds include renderer reference-model regressions. V3 visual/runtime verification and V4 cycle-aware timing remain required before `CLOSED`.

---

## INC-2026-004 - GitHub Actions Python cache required a dependency manifest

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Detected:** 2026-08-25
- **Affected:** `.github/workflows/verify.yml`
- **Related TODO:** `P48-008`

### Symptom

The first verification workflow failed during `actions/setup-python` before any PAC48 checks ran. The action reported that no `requirements.txt` or `pyproject.toml` matched the requested pip-cache dependency path.

### Root cause

`cache: pip` was enabled even though PAC48 intentionally has no Python dependency manifest; the CI installs its small pinned tool dependency directly.

### Corrective action

Removed `cache: pip` from `actions/setup-python` and kept SkoolKit explicitly pinned in the workflow.

### Regression guard

Do not enable dependency caching unless a real cache dependency manifest/path is committed and validated. Keep CI tool versions explicit.

### Verification evidence

GitHub Actions run `32797213612` completed all setup/build/artifact steps successfully after the correction.

---

## INC-2026-005 - GUI-driven Fuse smoke test was unreliable in headless CI

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Detected:** 2026-08-25
- **Affected:** former `tools/emulator_smoke.sh`, `.github/workflows/verify.yml`
- **Related TODO:** `P48-008`

### Symptom

An experimental V3 CI harness launched Fuse under bare Xvfb and attempted to drive the emulator through X11/window automation. Runs became stuck during GUI interaction instead of producing deterministic pass/fail evidence.

### Root cause

The harness depended on GUI focus/window behavior that is not a stable contract in a bare headless X server. This made the verification mechanism less reliable than the code it was intended to test.

### Corrective action

Removed the GUI Fuse harness from the canonical workflow and deleted `tools/emulator_smoke.sh`. Canonical CI is again deterministic and bounded. V3 remains an explicit emulator/hardware layer until a non-GUI, deterministic simulator/replay approach is implemented.

### Regression guard

Do not add GUI/window-manager automation to required CI for PAC48. Automated runtime verification must use a deterministic simulator, replayable input mechanism, or an explicitly provisioned and bounded environment. Manual V3 remains valid evidence when recorded according to `docs/TESTING.md`.

### Verification evidence

The GUI path was removed from `main`; subsequent canonical CI no longer depends on Fuse/Xvfb/xdotool and concurrency cancels obsolete runs.

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
