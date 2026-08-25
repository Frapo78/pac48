# PAC48 Incident Registry

Persistent engineering memory for bugs, regressions, failed approaches, and architecture mistakes that future contributors and AI agents must not rediscover from scratch.

This file is append-oriented. Resolved incidents remain permanently. Use `docs/TODO.md` for planned work, `CHANGELOG.md` for what changed, `docs/adr/` for architecture decisions, and `docs/TESTING.md` for verification requirements.

## Mandatory agent rules

Before changing engine code, scan this file for incidents involving the modules, registers, input devices, renderer paths, build tools, release automation, or verification infrastructure being touched.

Create a new incident when a regression reaches `main`, a subtle bug could recur, a build/runtime/emulator/hardware/timing/input/CI/release failure reveals a missing invariant, or a non-obvious constraint is required for correctness.

Lifecycle: `DETECTED` -> `FIXED_PENDING_VERIFY` -> `CLOSED`, or `ACCEPTED_RISK` with rationale.

Stable IDs use `INC-YYYY-NNN`, monotonically increasing. Never delete, renumber, or reuse them.

Every incident records status, severity (`S0` corruption/crash/unusable output, `S1` major functional/performance, `S2` localized/tooling, `S3` minor), affected files, symptom, root cause or bounded uncertainty, corrective action, regression guard, and verification evidence.

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

---

## INC-2026-002 - Sinclair 1/2 directions were mapped to the wrong keys

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Affected:** `src/input.asm`
- **Related TODO:** `P48-002`

### Root cause
Incorrect Interface 2 keyboard-bit documentation was encoded directly into source.

### Corrective action
Correct mappings retained existing direction enum and `Input_Mode` values:
- Sinclair 1 (`6 7 8 9 0`): left, right, down, up, fire.
- Sinclair 2 (`1 2 3 4 5`): left, right, down, up, fire.

---

## INC-2026-003 - Full-maze redraw and destructive runtime-shift sprite path

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Affected:** `src/main.asm`, `src/video.asm`, `src/player.asm`, `src/render.asm`, asset/build pipeline
- **Related ADR:** `docs/adr/0001-rendering-architecture.md`
- **Related TODO:** `P48-003`, `P48-010`, `P48-011`, `P48-012`, `P48-013`, `P48-014`

### Root cause
Prototype simulation, background restoration, sprite transformation, and screen commit were mixed without a cycle budget.

### Corrective action
Dedicated renderer, prepare/commit split, masked pre-shifted sprites, line LUT, dirty restoration, simulation-only player ownership, static actor attributes and persistent facing state.

### Verification evidence
V1/V2/V4 pass. Owner V3 reports very fluid movement.

---

## INC-2026-004 - GitHub Actions Python cache required a dependency manifest

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `.github/workflows/verify.yml`

Removed pip caching. Do not enable dependency caching without a validated dependency manifest/path.

---

## INC-2026-005 - GUI-driven Fuse smoke test was unreliable in headless CI

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** former `tools/emulator_smoke.sh`, CI
- **Related TODO:** `P48-008`, `P48-023`

GUI/Xvfb automation was removed from canonical CI. Deterministic runtime coverage uses SkoolKit; visual V3 remains manual until a deterministic non-GUI capture path exists.

---

## INC-2026-006 - Snapshot round-trip invalidated exact renderer timing evidence

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `tests/perf_harness.asm`, `tools/run_perf_tests.sh`
- **Related TODO:** `P48-014`

Profile raw assembled bytes directly; inject state deterministically and validate the expected opcode at the measurement start.

---

## INC-2026-007 - Release succeeded but CI failed on unsupported `isLatest` field

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `.github/workflows/verify.yml`
- **Related TODO:** `P48-017`

Use only supported release-view fields, validate release-package checksums and require the complete publish job to finish green.

---

## INC-2026-008 - Maze attribute value overwritten by coordinate translation

- **Status:** `CLOSED`
- **Severity:** `S0`
- **Detected:** 2026-08-25
- **Affected:** `src/maze.asm`, `src/sprites.asm`, `tests/runtime_harness.asm`, maze presentation
- **Related TODO:** `P48-018`, `P48-023`, `P48-026`

### Symptom
An owner V3 screenshot showed broad colored bands/filled rectangles instead of a coherent maze.

### Root cause
`Maze_DrawAtOffset` overwrote the intended Spectrum attribute in `A` while translating coordinates. A first attempted repair also used the wrong AF/DE stack order and was caught by the new runtime guard.

### Corrective action
Preserve the intended attribute through coordinate translation, assert representative maze attributes through the real draw path, use black PAPER + bright-blue topology-selected wall boundaries and a small 2x2 pellet dot.

### Verification evidence
The corrected visual baseline was owner-accepted as "molto meglio" with responsive controls and fluid movement.

---

## INC-2026-009 - Alignment-only collision assumption could permit wall penetration

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/player.asm`, `tests/runtime_harness.asm`
- **Related TODO:** `P48-024`

### Symptom
Pac occasionally appeared to pass through maze walls.

### Root cause / evidence
`Player_CanContinue` previously rechecked collision only at exact 8-pixel alignment. A deterministic one-pixel orthogonal-drift state demonstrated that the previous assumption could permit wall entry.

### Corrective action
Every one-pixel step now checks both corners of the advancing edge of the full 8x8 player box through `Maze_CanMove`.

### Verification evidence
Deterministic Z80 regression passes. The owner V3 video of the real collision/pellet build shows sustained fluid play and does not visibly reproduce wall penetration, but explicit targeted owner confirmation is still required before `CLOSED`.

---

## INC-2026-010 - Cached stale TAP was mistaken for a new visual regression

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Detected:** 2026-08-25
- **Affected:** manual release verification / download procedure
- **Related TODO:** `P48-023`, `P48-026`

### Symptom
The owner initially reported that the collision/pellet build had completely broken the graphics again. A rollback was performed in response.

### Actual root cause
The reported broken screen came from a stale/cached `.tap`, not from the intended current `0.3.4-beta` artifact. After downloading/loading the correct build, owner V3 video showed the maze intact, Pac moving fluidly and pellets disappearing correctly.

Therefore the earlier claim that the collision/pellet integration caused an S0 visual regression was false. The gameplay integration itself was not the source of that screen.

### Corrective action
- restore the verified collision + pellet code baseline;
- reverse the unnecessary rollback;
- use immutable per-commit release URLs and compare SHA-256 during visual-regression diagnosis;
- keep `P48-026` as a useful whole-screen regression improvement, but not as a blocker caused by this incident.

### Verification evidence
Commit `b8959392da3ee4d37478082b26c53da80f237746` restores the collision/pellet baseline and adds only the requested Kempston FIRE menu shortcut. GitHub Actions run `32804161378` passed build, runtime, timing, TAP-load and publication. Published TAP SHA-256: `ede09a62b1398f9da70ada45e86eb5f69b16a9ec9667414068d7bb19ec44dac5`.

### Process guard
When a manual test result contradicts recent deterministic evidence or an immediately prior accepted visual baseline, first identify the exact loaded artifact/tag/checksum before rolling back source code.

---

## INC-2026-011 - Eighteen pellet cells are isolated from the player spawn

- **Status:** `DETECTED`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/maze.asm`, maze validation
- **Related TODO:** `P48-027`, `P48-019`

### Symptom
The owner observed pellets confined inside areas Pac cannot enter.

### Proven root cause
A flood-fill of the authoritative 28x20 `Maze_Map` shows 264 walkable cells but only 246 connected to spawn `(1,1)`. Three isolated six-cell components contain 18 normal pellets:

- `x=1..2, y=9..11`;
- `(14,9)`, `(14,10)`, `(12,11)`, `(13,11)`, `(14,11)`, `(15,11)`;
- `x=25..26, y=9..11`.

### Corrective action
Minimally connect or remove these accidental islands, then add a structural reachability test requiring every player-collectible pellet to be connected to the player spawn.

### Regression guard
Future maze validation must use graph reachability, not only row length/dimensions/cell-value checks.

---

## INC-2026-012 - Junction turn request can feel stuck or miss the first opening

- **Status:** `DETECTED`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/input.asm`, `src/player.asm`, control tests
- **Related TODO:** `P48-028`

### Symptom
Around some exits Pac feels stuck. Example: while travelling horizontally, holding `down + right` is expected to queue a downward turn and take the first legal downward opening.

### Current contributing design
- `Input_Read` collapses simultaneous directions to one direction using fixed per-device priority;
- `Pac_ReqDir` stores only that collapsed result;
- `Player_TryRequestedDir` executes a turn only when both pixel axes are exactly 8-pixel aligned.

This is sufficient for basic movement but not yet the forgiving queued-turn behavior expected from an arcade maze game.

### Corrective action plan
Implement direction-aware requested-turn buffering: preserve a perpendicular requested turn while the current direction remains held, execute it at the first legal junction, and evaluate a bounded junction grace/lookahead that does not permit wall clipping.

### Regression guard
Add deterministic symmetric cases for all four turn directions, including a requested turn held across multiple blocked cells before the first legal opening.

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

### Root cause / bounded uncertainty

### Corrective action

### Regression guard

### Verification evidence
```
