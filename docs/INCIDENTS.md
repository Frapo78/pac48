# PAC48 Incident Registry

Persistent engineering memory for bugs, regressions, failed approaches, and architecture mistakes that future contributors and AI agents must not rediscover from scratch.

This file is append-oriented. Resolved incidents remain permanently. Use `docs/TODO.md` for planned work, `CHANGELOG.md` for what changed, `docs/adr/` for architecture decisions, and `docs/TESTING.md` for verification requirements.

## Mandatory agent rules

Before changing engine code, scan this file for incidents involving the modules, registers, input devices, renderer paths, build tools, release automation, or verification infrastructure being touched.

Create a new incident when a regression reaches `main`, a subtle bug could recur, a build/runtime/emulator/hardware/timing/input/CI/release failure reveals a missing invariant, or a non-obvious constraint is required for correctness.

Lifecycle: `DETECTED` -> `FIXED_PENDING_VERIFY` -> `CLOSED`, or `ACCEPTED_RISK` with rationale.

Stable IDs use `INC-YYYY-NNN`, monotonically increasing. Never delete, renumber, or reuse them.

Every incident records status, severity (`S0` corruption/crash, `S1` major functional/performance, `S2` localized/tooling, `S3` minor), affected files, symptom, root cause, corrective action, regression guard, and verification evidence.

---

## INC-2026-001 - Maze coordinates clobbered between attribute and bitmap drawing

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S0`
- **Affected:** `src/maze.asm`, `src/video.asm`
- **Related TODO:** `P48-001`

### Symptom
A maze cell could write its attribute at the intended coordinate then draw bitmap/pellet data using corrupted `DE`, producing misplaced screen writes.

### Root cause
Callers relied on undocumented `DE` survival across video helpers.

### Corrective action
`Video_DrawTile`, `Maze_DrawTileAtOffset`, and `Maze_DrawAtOffset` preserve maze coordinates where required and document the register contract.

### Regression guard
Public assembly routines with reusable coordinates must document preserved/clobbered registers. Runtime and visual maze tests must exercise actual screen writes.

### Verification evidence
V1/V2 canonical build/runtime/TAP-load pass. V3 visual maze/pellet restoration remains required.

---

## INC-2026-002 - Sinclair 1/2 directions were mapped to the wrong keys

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Affected:** `src/input.asm`
- **Related TODO:** `P48-002`

### Symptom
Sinclair joystick modes returned incorrect logical directions.

### Root cause
Incorrect Interface 2 keyboard-bit documentation was encoded directly into source.

### Corrective action
Correct mappings retained existing public direction enum and `Input_Mode` values:
- Sinclair 1 (`6 7 8 9 0`): left, right, down, up, fire.
- Sinclair 2 (`1 2 3 4 5`): left, right, down, up, fire.

### Regression guard
Keep hardware mappings beside port access and manually smoke-test all four directions whenever `input.asm` changes.

### Verification evidence
V1/V2 pass; relevant V3 control tests remain required.

---

## INC-2026-003 - Full-maze redraw and destructive runtime-shift sprite path

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Affected:** `src/main.asm`, `src/video.asm`, `src/player.asm`, `src/render.asm`, asset/build pipeline
- **Related ADR:** `docs/adr/0001-rendering-architecture.md`
- **Related TODO:** `P48-003`, `P48-010`, `P48-011`, `P48-012`, `P48-013`, `P48-014`

### Symptom
The engine redrew all 560 maze cells every frame and shifted actor bytes at runtime, consuming budget needed for gameplay.

### Root cause
Prototype simulation, background restoration, sprite transformation, and screen commit were mixed without a cycle budget.

### Corrective action
Dedicated renderer, prepare/commit split, masked pre-shifted sprites, line LUT, dirty restoration, simulation-only player ownership, static actor attributes, persistent facing state.

### Regression guard
Canonical build rejects full-maze redraw in `MainLoop`, legacy runtime-shift drawing, simulation-owned screen writes, obsolete actor tables, invalid generated assets, and excessive binary/timing budgets.

### Verification evidence
V1/V2/V4 pass. Current post-visual-recovery measurements are 4341 / 5497 / 9184 T-states for representative dirty cases; TAP reaches `$8000`. Owner reports movement is very fluid. Broader V3 rendering/turning coverage remains required.

---

## INC-2026-004 - GitHub Actions Python cache required a dependency manifest

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `.github/workflows/verify.yml`

### Root cause
`cache: pip` was enabled without a committed dependency manifest.

### Corrective action / guard
Removed pip caching. Do not enable dependency caching without a real validated manifest/path; keep CI tool versions explicit.

### Verification evidence
Subsequent canonical CI setup/build/artifact runs pass.

---

## INC-2026-005 - GUI-driven Fuse smoke test was unreliable in headless CI

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** former `tools/emulator_smoke.sh`, CI
- **Related TODO:** `P48-008`, `P48-023`

### Root cause
Bare-Xvfb GUI focus/window automation was not deterministic enough to be a required verification mechanism.

### Corrective action / guard
Removed GUI automation from canonical CI. Deterministic runtime coverage uses SkoolKit simulation. Visual V3 evidence remains manual until a deterministic non-GUI capture path exists.

---

## INC-2026-006 - Snapshot round-trip invalidated exact renderer timing evidence

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `tests/perf_harness.asm`, `tools/run_perf_tests.sh`
- **Related TODO:** `P48-014`

### Root cause
Raw -> snapshot -> reload altered the exact instruction byte at the measurement boundary.

### Corrective action / guard
Profile raw assembled bytes directly; inject state deterministically; validate expected opcode at measurement start before accepting timing evidence.

### Verification evidence
Canonical V4 currently reports 4341 / 5497 / 9184 T-states under 48K contention after visual-recovery wall restoration changes; all remain within budget.

---

## INC-2026-007 - Release succeeded but CI failed on unsupported `isLatest` field

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `.github/workflows/verify.yml`
- **Related TODO:** `P48-017`

### Root cause
The workflow assumed `gh release view` exposed the same JSON fields as release listing.

### Corrective action / guard
Use only supported view fields and check Latest status separately. Validate release-package checksums before publication and require the entire publish job to finish green.

### Verification evidence
Later runs publish `pac48-latest.tap` successfully after canonical verification and fresh-48K TAP loading.

---

## INC-2026-008 - Maze attribute value overwritten by coordinate translation

- **Status:** `CLOSED`
- **Severity:** `S0`
- **Detected:** 2026-08-25
- **Affected:** `src/maze.asm`, `src/sprites.asm`, `tests/runtime_harness.asm`, maze presentation
- **Related TODO:** `P48-018`, `P48-023`

### Symptom
The owner-provided V3 screenshot showed an unreadable game screen: rows of different colors, large blue/red attribute rectangles, and diagnostic-looking bands instead of a coherent maze.

### Root cause
`Maze_DrawAtOffset` accepted the intended Spectrum attribute in `A`, then reused `A` to add `Maze_OffsetX/Y` to `D/E`. The final screen Y value therefore reached `Video_DrawSprite` as the attribute. This escaped earlier CI because the runtime harness verified `Video_DrawTile` directly but did not assert attributes produced through the full maze drawing path.

During the first attempted repair, `AF` and `DE` were pushed in the wrong stack order (`PUSH AF`, `PUSH DE`, then `POP AF`). The new runtime guard immediately failed with code 13, proving the test could catch the same class of error before release.

### Corrective action
- preserve the intended attribute across coordinate translation;
- add runtime checks for known wall/pellet attributes through the real `Maze_Draw` path;
- replace solid blue PAPER wall cells with black PAPER + bright-blue topology-selected bitmap boundary tiles;
- shrink normal pellet art to a 2x2 dot.

### Regression guard
The headless Z80 harness fails if representative maze attributes or wall-boundary bitmap bytes differ from expected values. Visual V3 remains mandatory because cell assertions cannot judge overall composition.

### Verification evidence
Run `32800960272` passed clean assembly, runtime harness, V4, TAP load and release publication. The owner then supplied a new V3 screenshot, explicitly said the result was "molto meglio", confirmed the controls respond and movement is very fluid, and the previous color-band/filled-rectangle corruption was gone. `P48-018` is therefore `DONE` and this incident is closed.

---

## INC-2026-009 - Alignment-only collision assumption could permit wall penetration

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/player.asm`, `tests/runtime_harness.asm`
- **Related TODO:** `P48-024`

### Symptom
After the visual recovery, the owner reported that Pac occasionally appeared to pass through maze walls during otherwise smooth play.

### Root cause
The exact input sequence observed by the owner was not captured, so the trigger is not claimed with certainty. Static/runtime analysis did identify a real collision weakness: `Player_CanContinue` rechecked collision only when both pixel coordinates were multiples of 8 and otherwise returned success unconditionally. Wall safety therefore depended on a separate invariant that the orthogonal axis could never become even one pixel misaligned.

A deterministic harness state with `y=25` while moving horizontally toward a wall proves the weakness: the old implementation would advance without checking that wall.

### Corrective action
- validate every one-pixel movement using the advancing edge of the full 8x8 player box;
- sample both leading-edge corners for all four cardinal directions;
- convert screen-pixel samples to maze cells and delegate to canonical `Maze_CanMove`;
- preserve grid-aligned buffered turning so the current responsive control feel is unchanged.

### Regression guard
The headless Z80 harness forces an orthogonal one-pixel drift beside a known wall. Pac must remain at the previous coordinate and `Pac_Dir` must be cleared. Legal corridor movement remains separately tested.

### Verification evidence
GitHub Actions run `32801837183` passed clean assembly, the expanded Z80 runtime harness, renderer tests, fresh-48K TAP loading, V4 timing, artifact checks and release publication. Current binary is 8503 bytes with 20169 bytes conservative headroom; TAP is 8583 bytes. Owner V3 confirmation during sustained play is still required before `CLOSED`.

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
