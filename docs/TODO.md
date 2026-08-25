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

Owner V3 video of the real `0.3.4-beta` gameplay build confirms:

- maze graphics are intact and readable;
- Pac movement is fluid;
- normal pellets disappear persistently as Pac traverses them;
- the earlier report of a completely corrupted screen was caused by loading a stale/cached TAP, not by the collision/pellet integration (`INC-2026-010`).

Current code/release after correcting the unnecessary rollback and adding Kempston FIRE menu start:

- commit: `b8959392da3ee4d37478082b26c53da80f237746`;
- tag: `build-b8959392da3e`;
- CI run: `32804161378` — PASS;
- TAP size: 8592 bytes;
- TAP SHA-256: `ede09a62b1398f9da70ada45e86eb5f69b16a9ec9667414068d7bb19ec44dac5`;
- fresh 48K TAP load reaches `$8000`;
- `Render_Commit` remains 4341 / 5497 / 9184 T-states for dirty1 / dirty2 / dirty4.

---

# ACTIVE MILESTONE — Gameplay usability before larger maze/HUD work

Recommended order:

`P48-029 V3 -> P48-027 -> P48-028 -> P48-026/P48-023 -> P48-019 -> P48-020/021/022 -> broader P48-009`

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

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** control feel / input semantics
- **Files:** `src/input.asm`, `src/player.asm`, deterministic input/player tests
- **Depends on:** none

### Symptom

Around some corridor exits Pac feels "stuck". Example expectation: while moving horizontally, holding `down + right` should queue `down` and Pac should take the first legal downward opening automatically. Equivalent behavior is required for every direction/junction combination.

### Current weakness

`Input_Read` collapses simultaneous directions to a single result using fixed priority, while `Player_TryRequestedDir` only executes a requested turn at exact 8-pixel alignment. This combination can lose the intended perpendicular turn or miss an opening if the request arrives just after the exact node.

### Resolution plan

- retain a true requested-turn queue independently from the current travel direction;
- when current+perpendicular directions are held together, prioritize the perpendicular component as the queued turn;
- preserve the queued turn until the first legal junction rather than replacing it each frame with the current travel direction;
- evaluate a small node lookahead/grace or deterministic snap-to-grid at a legal turn so input just before/around a junction feels arcade-like without allowing wall clipping;
- implement the same semantic model for Kempston, QAOP/cursors and Sinclair modes where simultaneous inputs are representable.

### Acceptance

- [ ] right + down while travelling horizontally turns down at the first legal opening;
- [ ] left/right/up/down symmetric cases pass;
- [ ] queued turn survives several blocked cells before becoming legal;
- [ ] no wall clipping or diagonal physical movement is introduced;
- [ ] owner V3 describes junction control as immediate/predictable rather than stuck.

---

## P48-029 — Start Kempston mode from Kempston FIRE in menu

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Type:** input/menu usability
- **Files:** `src/menu.asm`
- **Implemented in:** `b8959392da3ee4d37478082b26c53da80f237746`

### Implemented

The control-selection menu polls Kempston port 31 in addition to keys `1..4`. Active-high FIRE bit 4 selects `Input_Mode=1` and starts the game as Kempston.

### Acceptance

- [x] canonical build/runtime/TAP verification passes;
- [x] verified release published;
- [ ] V3: owner confirms pressing Kempston FIRE at the menu starts the game in Kempston mode.

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
- **Status:** `READY` | **Priority:** `P2`

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
