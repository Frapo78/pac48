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

### Verification evidence
V1/V2 canonical build/runtime/TAP-load pass. V3 maze/pellet restoration remains required.

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
V1/V2/V4 pass. Owner reports movement is very fluid. Broader V3 rendering/turning coverage remains required.

---

## INC-2026-004 - GitHub Actions Python cache required a dependency manifest

- **Status:** `CLOSED`
- **Severity:** `S2`
- **Affected:** `.github/workflows/verify.yml`

### Root cause
`cache: pip` was enabled without a committed dependency manifest.

### Corrective action / guard
Removed pip caching. Do not enable dependency caching without a real validated manifest/path; keep CI tool versions explicit.

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
`Maze_DrawAtOffset` overwrote the intended Spectrum attribute in `A` while translating maze coordinates to screen coordinates. A first attempted repair also used the wrong AF/DE stack order; the new runtime guard caught that attempt before release.

### Corrective action
Preserve the intended attribute across coordinate translation, test representative attributes through the real `Maze_Draw` path, use black PAPER + bright-blue topology-selected wall boundaries, and use a small 2x2 pellet dot.

### Verification evidence
Run `32800960272` passed. The owner then supplied a V3 screenshot, explicitly said the result was "molto meglio", confirmed responsive controls and very fluid movement, and the original color-band corruption was gone.

---

## INC-2026-009 - Alignment-only collision assumption could permit wall penetration

- **Status:** `DETECTED`
- **Severity:** `S1`
- **Detected:** 2026-08-25
- **Affected:** `src/player.asm`, `tests/runtime_harness.asm`
- **Related TODO:** `P48-024`

### Symptom
The owner reported that Pac occasionally appeared to pass through maze walls during otherwise smooth play.

### Root cause / evidence
Static/runtime analysis identified a real weakness: `Player_CanContinue` rechecked collision only when both pixel coordinates were multiples of 8 and otherwise returned success unconditionally. A deterministic one-pixel orthogonal-drift test demonstrated that weakness.

### Attempted corrective action
A per-pixel leading-edge 8x8 collision implementation passed deterministic tests, but it was introduced in the same integration batch as pellet mutation. The owner then reported an S0 visual regression (`INC-2026-010`). To restore usability, the entire gameplay batch was rolled back to the previously accepted visual runtime.

### Reimplementation rule
Do not simply reapply the old patch. Reintroduce collision alone after `P48-026` is complete, publish a uniquely-addressed TAP, obtain V3 visual/gameplay confirmation, then close this incident only if sustained play no longer penetrates walls.

---

## INC-2026-010 - Gameplay integration reintroduced an unusable visual screen

- **Status:** `FIXED_PENDING_VERIFY`
- **Severity:** `S0`
- **Detected:** 2026-08-25
- **Affected:** integration between `src/main.asm`, `src/player.asm`, pellet/collision changes and verification coverage
- **Related TODO:** `P48-023`, `P48-024`, `P48-025`, `P48-026`

### Symptom
After the combined collision/pellet release, the owner supplied a screen recording showing the maze area completely corrupted again with broad colored bands/patterns. Pac itself continued to move fluidly, but the game was unusable.

### Root cause status
The exact low-level trigger is **not yet proven**. Do not claim that collision or pellet code individually caused the corruption. What is proven is the integration boundary:

- commit `e0e4afce51442df193eb48de18226d53a42ab703` was visually accepted;
- the later combined collision/pellet release `5acf77665afc5187bcd0baae03a349177ff68955` was visually rejected as unusable;
- representative-cell CI checks remained green, proving they were insufficient as a release gate.

### Immediate corrective action
Rollback the runtime integration to the exact previously accepted visual baseline:

- `src/main.asm` restored to the pre-pellet startup path;
- `src/player.asm` restored to the pre-per-pixel-collision implementation;
- runtime/performance harnesses restored to the same baseline;
- `src/pellets.asm` may remain in-tree as quarantined/unreferenced work but must not be linked into the game until reintroduced deliberately.

The rollback release at commit `1765eb9128d9fa59b6e66121642af4b80fa5e494` produces `pac48-latest.tap` SHA-256 `3310d2f2577b2f63174d2aa0e60951557def7835b593f6e75b536e8e8ec8adda`, exactly matching the previously visually accepted TAP. GitHub Actions run `32803411922` passed build, runtime, timing, TAP load and publication.

### Regression guard / process change
`P48-026` must be completed before collision or pellet work resumes:

1. test the full startup drawing path, not only representative cells;
2. validate the whole 28x20 maze attribute field against authoritative maze state or an accepted deterministic signature;
3. preserve a known-good binary/TAP checksum as a rollback anchor;
4. reintroduce gameplay changes one at a time;
5. require V3 evidence after each visual/gameplay-affecting change before stacking the next one;
6. use per-commit release URLs for manual verification to eliminate ambiguity from cached `latest` downloads.

### Verification evidence
Rollback CI run `32803411922`: PASS. Published tag: `build-1765eb9128d9`. Manual V3 confirmation of the rollback TAP is still required before this incident becomes `CLOSED`.

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
