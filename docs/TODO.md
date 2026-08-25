# PAC48 Technical TODO

This is the canonical work queue for PAC48.

Read before implementation:

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. `docs/INCIDENTS.md`
5. `docs/TESTING.md`
6. `CHANGELOG.md`
7. this file

## Agent workflow

- select the highest-priority unblocked task unless the user explicitly selects another;
- inspect all listed files and related incidents before editing;
- use stable `P48-###` IDs and never reuse/renumber them;
- create a new task for newly discovered scope;
- run the canonical build for code/build changes;
- update changelog and incident records when applicable;
- code without required evidence is `VERIFY`, not `DONE`.

## Status

- `READY` — ready to implement
- `IN_PROGRESS` — being implemented
- `BLOCKED` — dependency/decision prevents work
- `VERIFY` — implementation exists but required evidence remains
- `DONE` — implementation and required verification complete
- `WONTFIX` — intentionally rejected, rationale required

## Priority

- `P0` correctness/corruption
- `P1` architecture/compatibility/gameplay foundation
- `P2` maintainability/tooling/performance
- `P3` later enhancement

## Current verified baseline — 2026-08-25

Canonical GitHub Actions currently proves:

- V1 structural/architecture checks PASS;
- sjasmplus 1.23.1 assembly: 0 errors / 0 warnings;
- headless 48K Z80 runtime harness PASS;
- binary size 8042 bytes;
- conservative upper-RAM headroom 20630 bytes;
- TAP size 8122 bytes;
- fresh-48K simulated tape loading reaches `PC=32768 ($8000)`;
- V4 `Render_Commit` timing with 48K contention:
  - dirty1: 4320 T-states;
  - dirty2: 5455 T-states;
  - arbitrary dirty4: 7800 T-states;
- verified release publication produces `pac48-latest.tap`, versioned TAP, checksum and build metadata.

Manual visual/control V3 remains the main gate before broad gameplay expansion. V5 hardware testing remains a release-quality goal.

---

## P48-001 — Preserve maze coordinates across attribute drawing

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Files:** `src/maze.asm`, `src/video.asm`
- **Incident:** `INC-2026-001`

Implemented: explicit `DE` preservation/contracts in video/maze drawing.

Remaining:

- [x] V1/V2 canonical build/runtime/TAP-load PASS
- [ ] V3 visually confirm maze/pellet restoration has no coordinate corruption

---

## P48-002 — Correct Sinclair 1 and Sinclair 2 directions

- **Status:** `VERIFY`
- **Priority:** `P0`
- **Files:** `src/input.asm`
- **Incident:** `INC-2026-002`

Implemented correct Interface 2 mappings while retaining public direction enum and `Input_Mode` values.

Remaining:

- [x] V1/V2 PASS
- [ ] V3 manually test all four directions in both Sinclair modes

---

## P48-003 — Remove full-maze redraw from gameplay frames

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Files:** `src/main.asm`, `src/maze.asm`, `src/render.asm`, `src/player.asm`
- **Incident:** `INC-2026-003`

Implemented dirty restoration, bounded/de-duplicated dirty cells, initial-only full maze draw, and single bitmap+attribute restore per dirty cell.

Evidence:

- [x] architecture guard rejects `Maze_Draw` in `MainLoop`
- [x] V2 PASS
- [x] V4 dirty1/dirty2/dirty4 timings recorded and under budget
- [ ] V3 verify no trails, correct turns, and current maze state restoration

---

## P48-004 — Stabilize attribute ownership for moving actors

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Files:** `src/maze.asm`, `src/render.asm`, `src/video.asm`

Implemented: moving actors do not write attributes; walkable cells use compatible visibility attributes; walls remain maze-owned.

Remaining:

- [x] V2 PASS
- [ ] V3 all pixel phases show no permanent attribute trails/clash regressions

---

## P48-005 — Synchronize documentation with pixel movement

- **Status:** `DONE`
- **Priority:** `P1`

Pixel/sub-tile movement, requested direction, renderer ownership, repository layout, and AI workflow are documented.

---

## P48-006 — Add exact GPL license file

- **Status:** `BLOCKED`
- **Priority:** `P1`
- **Files:** `LICENSE`, `README.md`
- **Depends on:** project owner chooses exact GPL variant

Owner must explicitly choose e.g. `GPL-3.0-only` or `GPL-3.0-or-later`; agents must not guess.

---

## P48-007 — Make VERSION the single release-version source

- **Status:** `READY`
- **Priority:** `P2`
- **Files:** `VERSION`, `tools/build.sh`, `src/menu.asm`

Generate the menu/version assembly data from `VERSION` so release version is edited in one place only.

---

## P48-008 — Establish repeatable verification baseline

- **Status:** `VERIFY`
- **Priority:** `P2`
- **Files:** build/test tools, `docs/TESTING.md`, CI

Implemented:

- deterministic V1 guards;
- canonical V2 assembly/runtime/TAP-load pipeline;
- GitHub-hosted reproducible toolchain;
- documented V3/V4/V5 procedures.

Remaining:

- [x] V1 PASS
- [x] V2 PASS, including fresh-48K TAP load to `$8000`
- [x] automated V4 baseline PASS
- [ ] complete and record V3 manual visual/control suite on current renderer

---

## P48-009 — Implement first complete gameplay loop

- **Status:** `BLOCKED`
- **Priority:** `P2`
- **Depends on:** acceptance/verification of P48-001, P48-002, P48-003, P48-004, P48-012

After foundation verification create child tasks for:

1. pellet consumption
2. remaining-pellet count
3. score/HUD
4. level complete
5. lives
6. one deterministic enemy
7. player/enemy collision and life loss
8. game over/restart
9. additional enemy personalities
10. energizers/frightened mode and sound

---

## P48-010 — Dedicated render module and prepare/commit phases

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Files:** `src/main.asm`, `src/render.asm`, `src/memory.asm`

Implemented module boundary and `HALT -> Render_Commit -> simulation -> Render_Prepare` pipeline.

- [x] V1/V2 PASS
- [x] V4 timing PASS
- [ ] V3 visual runtime confirmation

---

## P48-011 — Generate masked pre-shifted 8x8 actor assets

- **Status:** `DONE`
- **Priority:** `P1`
- **Files:** `tools/gen_shifted_sprites.py`, canonical sprite source, generated include

Verified: 20 canonical frames, 8 phases each = 160 generated phases; exact row/table structures; clean build regeneration; V2 assembly PASS.

Future opacity extensibility is separately tracked by P48-016.

---

## P48-012 — Replace runtime-shift drawing with masked renderer

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Files:** `src/render.asm`, `src/video.asm`, generated sprite data
- **Incident:** `INC-2026-003`

Implemented: masked two-byte composition, pre-selected phase, 192-line LUT, no runtime source shifting.

- [x] V1 reference model PASS
- [x] V2 runtime/TAP-load PASS
- [x] V4 timing PASS
- [ ] V3 visually verify all x/y phases and background preservation

---

## P48-013 — Move player drawing out of player module

- **Status:** `VERIFY`
- **Priority:** `P1`
- **Files:** `src/player.asm`, `src/render.asm`, `src/main.asm`

Implemented simulation-only player ownership and persistent `Pac_FacingDir`.

- [x] V1/V2 PASS
- [ ] V3 verify directional animation/stopping behavior

---

## P48-014 — Cycle-budget profiling and memory budget checks

- **Status:** `DONE`
- **Priority:** `P2`
- **Files:** performance/build tools, `docs/TESTING.md`
- **Incident:** `INC-2026-006`

Baseline complete:

- binary 8042 bytes;
- headroom 20630 bytes beneath conservative ceiling;
- common dirty1 4320 T-states;
- cardinal dirty2 5455;
- arbitrary dirty4 7800;
- all below 12k common target / 14k warning threshold;
- profiler executes exact raw assembled bytes and verifies measurement opcode.

Re-run V4 when enemies materially increase actor/dirty counts.

---

## P48-015 — Persistent incident memory and changelog discipline

- **Status:** `DONE`
- **Priority:** `P1`

Append-oriented incidents, changelog, ADRs, verification protocol, and executable regression guards are established and mandatory for AI agents.

---

## P48-016 — Support explicit canonical opacity masks for future actor art

- **Status:** `READY`
- **Priority:** `P2`
- **Files:** canonical sprite source, generator/checker, renderer only if layout changes

Current masks infer transparency from zero image bits. Before adding actors needing opaque zero-valued pixels, introduce explicit canonical opacity masks while preserving deterministic generated phases.

---

## P48-017 — Publish the latest compiled and verified TAP from GitHub

- **Status:** `DONE`
- **Priority:** `P1`
- **Files:** `.github/workflows/verify.yml`, `tools/build.sh`, release docs
- **Incidents:** `INC-2026-007`

Implemented and verified:

- [x] qualifying `main` pushes run the pinned canonical build
- [x] release is downstream of the same verified artifact, with no second compilation
- [x] TAP load is simulated from a fresh 48K machine to `PC=$8000` before release
- [x] per-commit releases retain history
- [x] newest verified release is marked Latest
- [x] stable asset `pac48-latest.tap`
- [x] versioned TAP attached
- [x] `SHA256SUMS.txt` and `BUILD-INFO.txt` attached
- [x] release-package checksum validated before publication
- [x] documentation-only pushes do not create redundant binary releases

Stable download:

```text
https://github.com/Frapo78/pac48/releases/latest/download/pac48-latest.tap
```

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
Implemented or resolution plan
Acceptance / verification evidence
```

Never leave important work only in chat or commit messages.
