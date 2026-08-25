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
- A green build is not a substitute for owner-visible V3 verification when player-visible graphics or control feel changes.
- During manual regression diagnosis, prefer an immutable per-commit release URL and verify the SHA-256 so a cached TAP cannot be mistaken for the current build.
- Every screenshot/manual video should include or preserve the on-screen `V<version> B<build-id>` stamp introduced by `P48-030`.

## Status

- `READY` — ready to implement
- `IN_PROGRESS` — being implemented
- `BLOCKED` — dependency/decision prevents work
- `VERIFY` — implementation exists but required evidence remains
- `DONE` — implementation and required verification complete
- `WONTFIX` — intentionally rejected, rationale required

## Priority

- `P0` correctness/corruption/unusable behavior
- `P1` architecture/compatibility/gameplay foundation
- `P2` maintainability/tooling/performance
- `P3` later enhancement

---

# Current verified baseline — 2026-08-25

Owner V3 video confirms the gameplay renderer is intact, Pac movement is fluid and normal pellets disappear persistently. The remaining control complaint was input semantics/turn buffering rather than frame-rate performance.

Current verified release:

- semantic version: `0.3.6-beta`;
- commit: `3cc091e0fa3fc3e65fef16382dec25768259e44b`;
- build ID: `3CC091E`;
- on-screen stamp: `V0.3.6 B3CC091E` rendered with the ZX Spectrum ROM 8x8 system font;
- tag: `build-3cc091e0fa3f`;
- CI run: `32806218254` — PASS;
- TAP size: 8882 bytes;
- TAP SHA-256: `8d340ddf14db9da5ac1b8c3d5786aacd242da2db1092e61e3e3cc6a7c0708ef8`;
- preferred immutable/manual-test filename: `pac48-0.3.6-beta-b3CC091E.tap`;
- fresh 48K TAP load reaches `$8000`;
- dedicated Z80 control-semantics harness: PASS;
- `Render_Commit` remains 4341 / 5497 / 9184 T-states for dirty1 / dirty2 / dirty4.

---

# ACTIVE MILESTONE — Gameplay usability before larger maze/HUD work

Recommended order:

`P48-029 V3 -> P48-030 V3 -> P48-028 V3 -> P48-027 -> P48-026/P48-023 -> P48-019 -> P48-020/021/022 -> broader P48-009`

---

## P48-018 — Recover a clean, readable maze baseline

- **Status:** `DONE`
- **Priority:** `P0`
- **Incident:** `INC-2026-008`

Owner V3 confirmed the corrected black playfield, thin blue wall boundaries, small pellets, responsive controls and fluid movement.

---

## P48-024 — Harden player collision at every pixel step

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Type:** gameplay correctness
- **Files:** `src/player.asm`, `tests/runtime_harness.asm`
- **Incident:** `INC-2026-009`

Implemented baseline:

- every one-pixel step validates both corners of the advancing 8x8 actor edge;
- wall/outside checks delegate to `Maze_CanMove`;
- deterministic one-pixel orthogonal-drift regression passes;
- owner V3 video shows sustained fluid play and did not reproduce the earlier wall-penetration symptom.

Keep `VERIFY` until the owner explicitly confirms the wall-penetration issue itself is gone during targeted sustained testing.

---

## P48-025 — Consume normal pellets persistently

- **Status:** `DONE`
- **Priority:** `P1`
- **Type:** gameplay state
- **Files:** `src/pellets.asm`, `src/player.asm`, `src/main.asm`, runtime tests

Verified:

- pellet cells mutate from `Maze_CellPellet` to `Maze_CellEmpty`;
- pickup is based on the player centre;
- spawn pellet is consumed before initial draw;
- dirty restoration renders consumed cells empty;
- deterministic Z80 tests pass;
- owner V3 video visibly confirms pellets disappear during traversal.

Pellet counter/score remain separate future work.

---

## P48-026 — Strengthen full startup-screen regression gate

- **Status:** `READY`
- **Priority:** `P1`
- **Type:** regression prevention / release safety
- **Files:** runtime/startup harness, `docs/TESTING.md`, build checks
- **Incidents:** `INC-2026-008`, `INC-2026-010`

### Goal

Go beyond representative-cell assertions and make whole-field screen correctness more deterministic while retaining manual V3 for composition/control feel.

### Acceptance

- [ ] validate all 28x20 maze attribute cells against authoritative maze state;
- [ ] add deterministic whole-maze bitmap/signature evidence where practical;
- [ ] document immutable per-commit TAP + checksum procedure for V3;
- [ ] a deliberate broad attribute/bitmap corruption fails before release publication.

---

## P48-027 — Remove unreachable pellet islands and add connectivity guard

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** maze/gameplay correctness
- **Files:** `src/maze.asm`, structural tests, `docs/TODO.md`
- **Depends on:** none

### Proven problem

The current `Maze_Map` has 264 walkable cells, but only 246 are connected to the player spawn `(1,1)`. Eighteen pellet cells are unreachable in three isolated 6-cell components:

- left island: `x=1..2, y=9..11`;
- centre island: `(14,9)`, `(14,10)`, `(12,11)`, `(13,11)`, `(14,11)`, `(15,11)`;
- right island: `x=25..26, y=9..11`.

### Resolution plan

- minimally open/connect the current topology without degrading the accepted visual readability;
- add a deterministic flood-fill/reachability check from the player spawn;
- require every normal pellet/power-pellet candidate to belong to the player-reachable component;
- preserve future ghost-house reservations explicitly rather than accidentally creating sealed pellet regions.

### Acceptance

- [ ] zero pellet cells outside the player-reachable component;
- [ ] connectivity test fails if a future edit creates an unreachable pellet;
- [ ] V3 maze remains readable after the minimal topology correction.

---

## P48-028 — Make joystick turning behave like a queued arcade turn

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Type:** control feel / input semantics
- **Files:** `src/input.asm`, `src/player.asm`, `tests/control_harness.asm`, `tools/run_control_tests.sh`
- **Incident:** `INC-2026-012`
- **Implemented in:** `3cc091e0fa3fc3e65fef16382dec25768259e44b`

### Implemented

- physical directions are first collected as a simultaneous four-bit mask instead of being collapsed immediately by fixed priority;
- while travelling horizontally, a vertical component is treated as the queued turn; while travelling vertically, a horizontal component is treated as the queued turn;
- holding only the current travel direction returns `0`, so it cannot erase an already queued perpendicular turn;
- holding a diagonal naturally alternates the desired perpendicular axis after each successful turn, matching arcade-style diagonal steering;
- 180-degree reversals are applied immediately inside the current corridor instead of waiting for the next 8-pixel node;
- 90-degree turns remain grid/legal-opening constrained, preserving collision safety;
- semantics are shared by Kempston, keyboard/cursors and Sinclair modes.

### Deterministic evidence

The dedicated Z80 control harness verifies:

- right travel + down/right => DOWN request;
- down travel + down/right => RIGHT request;
- current-direction-only input does not erase a queued turn;
- symmetric up/left case;
- opposite cardinal input remains valid;
- mid-cell 180-degree reversal changes direction immediately and moves one pixel safely.

CI run `32806218254`: PASS.

### Acceptance

- [x] direction-aware diagonal semantics pass Z80 tests;
- [x] current direction no longer overwrites queued turns;
- [x] immediate reversal passes Z80 test;
- [x] no diagonal physical movement is introduced;
- [ ] V3: owner confirms first-opening turns feel immediate/predictable rather than sluggish/stuck.

---

## P48-029 — Start Kempston mode from Kempston FIRE in menu

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** input/menu usability
- **Files:** `src/menu.asm`
- **Implemented in:** `b8959392da3ee4d37478082b26c53da80f237746`

### Implemented

The control-selection menu polls Kempston port 31 in addition to keys `1..4`. Active-high FIRE bit 4 selects `Input_Mode=1` and starts the game as Kempston. `tools/check_build_identity.py` guards this behavior structurally.

### Acceptance

- [x] canonical build/runtime/TAP verification passes;
- [x] verified release published;
- [ ] V3: owner confirms pressing Kempston FIRE at the menu starts the game in Kempston mode.

---

## P48-030 — Version/build stamp visible in every gameplay screenshot

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** release identity / visual diagnostics
- **Files:** `VERSION`, `tools/build.sh`, `tools/check_build_identity.py`, `src/generated/build_info.asm`, `src/hud.asm`, `src/main.asm`, `src/menu.asm`, release workflow
- **Current implementation:** `3cc091e0fa3fc3e65fef16382dec25768259e44b`

### Implemented

- version advanced to `0.3.6-beta`;
- `VERSION` remains the semantic-version source for generated menu title and TAP filenames;
- the build derives a seven-character uppercase build ID from the exact Git commit; local dirty builds are marked with a leading `D`;
- the rejected custom 3x5 minifont was removed;
- `V<core-version> B<build-id>` is now drawn with the ZX Spectrum ROM/system 8x8 font at `$3C00`, centered in the free top character row;
- current release displays `V0.3.6 B3CC091E`;
- release assets include `pac48-0.3.6-beta.tap` and immutable/cache-safe `pac48-0.3.6-beta-b3CC091E.tap`;
- build identity checks fail if the ROM font is replaced by the old mini-font or if centering/build metadata becomes inconsistent.

### Acceptance

- [x] canonical build passes with generated version/build metadata;
- [x] CI proves build ID equals the release commit prefix;
- [x] versioned and version+build TAP assets are published;
- [x] build-specific TAP passes fresh-48K load verification;
- [x] build guard requires ROM 8x8 system font rather than custom mini-font;
- [ ] V3: owner confirms `V0.3.6 B3CC091E` is clearly readable in the gameplay screenshot.

---

## P48-019 — Redesign maze topology for a classic centered composition

- **Status:** `READY`
- **Priority:** `P1`
- **Depends on:** `P48-027`

Goal: replace the generic 28x20 topology with a deliberate symmetric arcade-style maze, while preserving guaranteed reachability, central ghost-house reservation, tunnel opportunities and four power-pellet positions.

---

## P48-020 — Add score/high-score HUD and reserve screen bands
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`

## P48-021 — Add power-pellet visual/state cells and life/bonus strip
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`, `P48-020`

## P48-022 — Add ghost-house geometry and actor color strategy
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`, `P48-016`

## P48-023 — Establish a visual regression gate
- **Status:** `READY` | **Priority:** `P1` | **Depends on:** `P48-018`

---

# Existing foundation tasks

## P48-001 — Preserve maze coordinates across attribute drawing
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-001`

## P48-002 — Correct Sinclair 1 and Sinclair 2 directions
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-002`

## P48-003 — Remove full-maze redraw from gameplay frames
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`

## P48-004 — Stabilize attribute ownership for moving actors
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-005 — Synchronize documentation with pixel movement
- **Status:** `DONE` | **Priority:** `P1`

## P48-006 — Add exact GPL license file
- **Status:** `BLOCKED` | **Priority:** `P1`
- Owner must explicitly choose the exact GPL variant; agents must not guess.

## P48-007 — Make VERSION the single release-version source
- **Status:** `DONE` | **Priority:** `P2`
- `tools/build.sh` generates menu/build strings and all versioned filenames from `VERSION`; `src/menu.asm` no longer hardcodes a semantic version. Guarded by `tools/check_build_identity.py`.

## P48-008 — Establish repeatable verification baseline
- **Status:** `VERIFY` | **Priority:** `P2`

## P48-009 — Implement first complete gameplay loop
- **Status:** `BLOCKED` | **Priority:** `P2`
- Pellet consumption is complete. Remaining children include pellet count, score, level completion, lives, enemies, collisions, game over, energizers and sound.

## P48-010 — Dedicated render module and prepare/commit phases
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-011 — Generate masked pre-shifted 8x8 actor assets
- **Status:** `DONE` | **Priority:** `P1`

## P48-012 — Replace runtime-shift drawing with masked renderer
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`

## P48-013 — Move player drawing out of player module
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-014 — Cycle-budget profiling and memory budget checks
- **Status:** `DONE` | **Priority:** `P2` | **Incident:** `INC-2026-006`

## P48-015 — Persistent incident memory and changelog discipline
- **Status:** `DONE` | **Priority:** `P1`

## P48-016 — Support explicit canonical opacity masks for future actor art
- **Status:** `READY` | **Priority:** `P2`

## P48-017 — Publish latest compiled and verified TAP from GitHub
- **Status:** `DONE` | **Priority:** `P1` | **Incident:** `INC-2026-007`

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
