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
- A green build is **not** a substitute for V3 visual verification when the task changes what the player sees, movement/collision, or mutable maze state.
- After `INC-2026-010`, do not stack two gameplay/renderer changes into one V3 validation batch. Reintroduce one change, release it, verify it, then continue.

## Status

- `READY` — ready to implement
- `IN_PROGRESS` — being implemented
- `BLOCKED` — dependency/decision prevents work
- `VERIFY` — implementation exists but required evidence remains
- `DONE` — implementation and required verification complete
- `WONTFIX` — intentionally rejected, rationale required

## Priority

- `P0` correctness/corruption/unusable release
- `P1` architecture/compatibility/gameplay foundation
- `P2` maintainability/tooling/performance
- `P3` later enhancement

---

# Current rollback baseline — 2026-08-25

The combined collision/pellet release was rejected by the owner because its maze graphics were completely corrupted despite fluid player motion (`INC-2026-010`). The runtime has therefore been rolled back to the exact previously accepted visual baseline.

Canonical rollback release:

- commit: `1765eb9128d9fa59b6e66121642af4b80fa5e494`;
- tag: `build-1765eb9128d9`;
- CI run: `32803411922` — PASS;
- TAP size: 8359 bytes;
- `pac48-latest.tap` SHA-256: `3310d2f2577b2f63174d2aa0e60951557def7835b593f6e75b536e8e8ec8adda`;
- checksum is identical to the owner-accepted visual build;
- `Render_Commit`: 4341 / 5497 / 9184 T-states for dirty1 / dirty2 / dirty4;
- fresh 48K TAP load reaches `$8000`.

Manual V3 confirmation of this rollback remains required before `INC-2026-010` is closed.

---

# ACTIVE MILESTONE — Make visual correctness a release invariant

## Mandatory order

`P48-026 -> owner V3 rollback confirmation -> P48-024 alone -> V3 -> P48-025 alone -> V3 -> P48-019 -> P48-023 -> P48-020/021/022`

No enemies, HUD expansion, sound, broad gameplay, or combined collision+pellet integration until the above sequence is respected.

---

## P48-026 — Full startup-screen invariant and known-good release anchor

- **Status:** `READY`
- **Priority:** `P0`
- **Type:** regression prevention / release safety
- **Files:** `tests/runtime_harness.asm` or a dedicated startup harness, `tools/build.sh`, `docs/TESTING.md`
- **Incidents:** `INC-2026-008`, `INC-2026-010`
- **Depends on:** rollback baseline only

### Problem

The CI checked representative wall/pellet cells and still allowed a release whose complete maze was unusable. A few sample cells are not a sufficient visual-state invariant.

### Resolution plan

1. execute the same deterministic startup drawing order used by the game after the menu;
2. validate **all 28x20 maze attribute cells**, not two samples;
3. for every maze coordinate, derive the expected attribute from authoritative `Maze_Map` state and compare the corresponding screen attribute;
4. add deterministic whole-maze bitmap evidence where practical (signature/checksum or complete expected boundary/pellet model), without fragile GUI/X11 automation;
5. record the accepted TAP SHA-256 `3310d2f2577b2f63174d2aa0e60951557def7835b593f6e75b536e8e8ec8adda` as the rollback anchor;
6. document that manual testing must use a **per-commit release URL** while diagnosing visual regressions, not only `/releases/latest/...`;
7. CI must fail before Release publication on any full-field mismatch.

### Acceptance

- [ ] every one of the 560 maze attribute cells is checked against maze state;
- [ ] test runs after the real startup drawing sequence;
- [ ] a deliberate wrong attribute in any maze row causes CI failure;
- [ ] deterministic bitmap evidence covers enough of the full maze to reject broad band/fill corruption;
- [ ] `docs/TESTING.md` records rollback checksum and per-commit V3 procedure;
- [ ] V1/V2/V4 remain green;
- [ ] no Release is published if startup-screen invariant fails.

---

## P48-018 — Recover a clean, readable maze baseline

- **Status:** `DONE`
- **Priority:** `P0`
- **Incident:** `INC-2026-008`

The P48-018 renderer itself was visually accepted. `INC-2026-010` was introduced later by a gameplay integration batch and is being handled separately.

---

## P48-024 — Harden player collision at every pixel step

- **Status:** `BLOCKED`
- **Priority:** `P0`
- **Type:** gameplay correctness
- **Files:** `src/player.asm`, runtime tests
- **Incident:** `INC-2026-009`
- **Depends on:** `P48-026` + owner V3 confirmation of rollback baseline

### Current state

A per-pixel leading-edge implementation was written and passed deterministic Z80 tests, but it has been **rolled back from the runtime** because it was part of the same integration batch as the S0 visual regression. Do not simply cherry-pick/reapply the old patch.

### Safe reimplementation plan

1. start from the visually confirmed rollback runtime;
2. add collision hardening **only**;
3. do not link or call pellet mutation code in the same release;
4. run V1/V2/V4 + P48-026 full startup-screen gate;
5. publish a unique per-commit TAP;
6. require V3 sustained movement/corner testing;
7. only after accepted V3 may this task become `DONE` and P48-025 be unblocked.

### Acceptance

- [ ] no wall penetration during sustained V3 play;
- [ ] legal movement/turn buffering remains fluid;
- [ ] full startup-screen invariant remains identical/valid;
- [ ] collision-specific deterministic drift tests pass;
- [ ] owner accepts the unique per-commit release.

---

## P48-025 — Consume normal pellets persistently

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Type:** gameplay state
- **Files:** quarantined `src/pellets.asm`, `src/player.asm`, `src/main.asm`, tests
- **Depends on:** `P48-024 DONE` with separate accepted V3

### Current state

`src/pellets.asm` may remain in the repository as quarantined work, but it is **not linked into the current game runtime**. The prior pellet implementation passed state tests but belonged to the visually rejected combined integration.

### Safe reimplementation plan

1. begin from the V3-approved collision-only release;
2. introduce pellet mutation **without any other gameplay/renderer change**;
3. run the P48-026 full startup-screen invariant before publication;
4. verify consumed cells restore to empty through dirty rendering;
5. publish a unique per-commit TAP;
6. obtain V3 confirmation that pellets disappear and graphics remain intact.

### Acceptance

- [ ] pellet cell mutates persistently to empty;
- [ ] no visual corruption at startup or during consumption;
- [ ] dirty restore uses mutated state correctly;
- [ ] V1/V2/V4 + full visual invariant PASS;
- [ ] owner V3 confirms visible pellet disappearance and intact maze.

---

## P48-019 — Redesign maze topology for a classic centered composition

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Depends on:** `P48-024 DONE`, `P48-025 DONE`

Goal: deliberate, symmetric original arcade-style maze with long corridors/loops, central ghost-house reservation, tunnel route, four power-pellet positions, legal player/ghost spawns, and no isolated walkable regions.

---

## P48-023 — Establish a visual regression gate

- **Status:** `IN_PROGRESS`
- **Priority:** `P0`
- **Depends on:** `P48-026`

P48-026 is now the deterministic implementation core of this broader task. Remaining work after P48-026: document accepted screenshot evidence format (emulator/machine/commit), V3 checklist, and release-quality policy.

---

## P48-020 — Add score/high-score HUD and reserve screen bands
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`

## P48-021 — Add power-pellet visual/state cells and life/bonus strip
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`, `P48-020`

## P48-022 — Add ghost-house geometry and actor color strategy
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`, `P48-016`

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
- Collision/pellet children are quarantined until the visual gate is complete.

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
- Rollback renderer timing: 4341 / 5497 / 9184 T-states.

## P48-015 — Persistent incident memory and changelog discipline
- **Status:** `DONE` | **Priority:** `P1`

## P48-016 — Support explicit canonical opacity masks for future actor art
- **Status:** `READY` | **Priority:** `P2`

## P48-017 — Publish latest compiled and verified TAP from GitHub
- **Status:** `DONE` | **Priority:** `P1` | **Incident:** `INC-2026-007`

---

## Adding tasks

Use the next unused ID and include status, priority, files, dependencies, related incident/ADR, problem/goal, resolution plan, acceptance and verification evidence. Never leave important work only in chat or commit messages.
