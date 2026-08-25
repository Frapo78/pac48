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
V1/V2 canonical build/runtime/TAP-load pass. V3 visual maze/pellet verification remains required.

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
V1/V2/V4 pass. Current post-visual-recovery measurements are 4341 / 5497 / 9184 T-states for representative dirty cases; TAP reaches `$8000`. V3 visual rendering/turning remains required.

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

- **Status:** `FIXED_PENDING_VERIFY`
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
- preserve `DE`, then push the intended attribute `AF`, translate coordinates, pop `AF`, and call `Video_DrawSprite`;
- document that the input attribute survives coordinate translation even though AF may be clobbered by the lower-level callee;
- add runtime checks for known wall/pellet attributes through the real `Maze_Draw` path;
- replace solid blue PAPER wall cells with black PAPER + bright-blue topology-selected bitmap boundary tiles;
- shrink normal pellet art to a 2x2 dot.

### Regression guard
The headless Z80 harness fails if:
- maze wall `(0,0)` does not produce `Maze_AttrWall` at screen cell `(2,2)`;
- maze pellet `(1,1)` does not produce `Maze_AttrPellet` at screen cell `(3,3)`;
- the top-left wall bitmap does not contain the expected thin top/left boundary bytes.

Visual V3 remains mandatory because deterministic cell assertions cannot judge overall maze composition.

### Verification evidence
- run `32800881885` correctly failed with code 13 on the incorrect stack-order repair and prevented release publication;
- corrected commit `e0e4afce51442df193eb48de18226d53a42ab703` passed GitHub Actions run `32800960272` completely;
- sjasmplus: 0 errors / 0 warnings;
- headless Z80 harness: PASS including the new maze attribute and wall-outline assertions;
- V4 `Render_Commit`: dirty1 4341, dirty2 5497, dirty4 9184 T-states, all within budget;
- binary 8279 bytes with 20393 bytes conservative headroom;
- TAP 8359 bytes and fresh-48K tape simulation reaches `PC=$8000`;
- verified release publication job: PASS.

The incident stays `FIXED_PENDING_VERIFY` until a fresh V3 screenshot confirms that the visible color-band/fill corruption is gone on the actual game screen.

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
