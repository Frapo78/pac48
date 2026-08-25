# PAC48 Technical TODO

Canonical work queue for PAC48. Important work must not live only in chat or commit messages.

## Mandatory reading order for humans and AI agents

1. `AGENTS.md`
2. `docs/ARCHITECTURE.md`
3. `docs/adr/0001-rendering-architecture.md`
4. `docs/PACMAN_REFERENCE.md`
5. `docs/INCIDENTS.md`
6. `docs/TESTING.md`
7. `CHANGELOG.md`
8. this file

## Agent workflow

- Select the highest-priority unblocked task unless the owner explicitly selects another.
- Inspect related incidents/reference material before editing.
- Use stable `P48-###` IDs; never renumber or reuse IDs.
- Create a new task for newly discovered scope instead of silently expanding another task.
- Run the canonical build for code/build changes.
- Update changelog and incident records when applicable.
- Code without required evidence is `VERIFY`, not `DONE`.
- A green build is not a substitute for owner-visible V3 verification when graphics or control feel changes.
- Prefer immutable per-commit TAP filenames and SHA-256 during manual regression diagnosis.
- Every screenshot/video should preserve the visible `V<version> B<build-id>` stamp.

Statuses: `READY`, `IN_PROGRESS`, `BLOCKED`, `VERIFY`, `DONE`, `WONTFIX`.

Priorities: `P0` unusable/correctness, `P1` gameplay/architecture, `P2` tooling/performance/maintainability, `P3` later enhancement.

---

# Current verified baseline — 0.3.9-beta

Verified code/release:

- commit: `be20f9eb5575119b617d0cadeabf9b0d769c9733`;
- build ID: `BE20F9E`;
- CI run: `32835864703` — PASS;
- immutable TAP: `pac48-0.3.9-beta-bBE20F9E.tap`;
- TAP SHA-256: `471eb8c6cf8cf00a1d04191d04153578218ce6b023bb29067bbfdd1fff57f822`;
- fresh-48K TAP load reaches `$8000`;
- assembly: 0 errors / 0 warnings;
- control/runtime/render/performance harnesses: PASS;
- `Render_Commit`: 4341 / 5497 / 9184 T-states for dirty1 / dirty2 / dirty4;
- BIN: 9128 bytes, 19544-byte conservative headroom.

0.3.9 gameplay/maze baseline:

- 28 x 20 logical cells, preserving 8x8 tiles;
- horizontally symmetric arcade-inspired landscape composition;
- Pac start below centre at `(13,15)`, initially facing left;
- 246 player-reachable cells;
- 210 normal pellets, all reachable;
- zero accidental player dead ends;
- functional centre tunnel at row 9, wrapping `(0,9) <-> (27,9)`;
- topology guard models the tunnel edge adjacency;
- perpendicular turns use a +/-3 pixel turn window with automatic axis centering instead of exact `%8==0` only.

External research and design rationale are canonicalized in `docs/PACMAN_REFERENCE.md`.

---

# ACTIVE MILESTONE — Arcade-feel foundation

Recommended order after owner V3 on 0.3.9:

`P48-030 V3 -> P48-027/P48-019/P48-040 V3 -> P48-031 V3 -> P48-034 -> P48-032 -> P48-033/P48-039 -> P48-035 -> P48-036/P48-037 -> P48-038 -> broader P48-009`

The exact-node steering model is no longer the target architecture. `P48-031` introduces a bounded arcade-style turn window and auto-centering. Future control work must extend/test that model rather than reintroduce an exact `%8==0` gate.

---

## P48-018 — Recover a clean, readable maze baseline
- **Status:** `DONE` | **Priority:** `P0` | **Incident:** `INC-2026-008`
- Owner V3 accepted black playfield, thin blue walls, pellets and fluid renderer.

## P48-024 — Harden player collision at every pixel step
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-009`
- Full 8x8 advancing edge is checked each pixel. Deterministic drift test passes. Close after sustained owner V3 confirms no wall penetration.

## P48-025 — Consume normal pellets persistently
- **Status:** `DONE` | **Priority:** `P1`
- `Maze_CellPellet -> Maze_CellEmpty`, centre-based pickup, dirty restoration and owner V3 confirmed.

## P48-026 — Strengthen whole-screen startup regression gate
- **Status:** `READY` | **Priority:** `P1`
- **Incidents:** `INC-2026-008`, `INC-2026-010`
- Validate all 28x20 attributes and a deterministic whole-maze bitmap/signature; keep manual V3 for composition.

## P48-027 — Remove unreachable pellet islands and enforce connectivity
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-011`
- **Implemented:** 0.3.8 topology replacement, extended by 0.3.9 functional tunnel.

Implemented/guarded:
- flood-fill from canonical Pac start;
- every normal pellet must be player-reachable;
- current classic layout must remain horizontally symmetric;
- accidental player dead ends fail the build;
- tunnel endpoints are graph-adjacent in validation.

Current evidence:
- 246 player-reachable cells;
- 210 reachable pellets;
- 0 unreachable pellets;
- 0 dead ends;
- functional tunnel `(0,9)<->(27,9)`;
- canonical CI PASS.

Remaining:
- [ ] owner V3 confirms no visually awkward/accidentally sealed routes.

## P48-028 — Interim direction-aware joystick queue
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-012`, `INC-2026-014`

Implemented and guarded:
- simultaneous direction mask;
- perpendicular preference;
- immediate 180-degree reversal;
- stale-turn cancellation;
- held-direction fallback at blocked diagonal dead ends.

This remains the input-intent layer. Actual geometric cornering is now owned by `P48-031`.

## P48-029 — Start Kempston from Kempston FIRE in menu
- **Status:** `VERIFY` | **Priority:** `P1`
- Structural/build guard passes; owner V3 confirmation remains.

## P48-030 — Readable version/build stamp in gameplay
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-013`
- Uses Spectrum ROM printable glyphs from `$3D00` after subtracting ASCII 32; generated version+commit identity; immutable TAP naming.
- 0.3.9 expected stamp: `V0.3.9 BBE20F9E`.
- [ ] owner V3 confirms the stamp is clearly readable.

## P48-019 — Arcade-inspired 4:3 maze topology
- **Status:** `VERIFY` | **Priority:** `P1` | **Depends on:** `P48-027`
- **Reference:** `docs/PACMAN_REFERENCE.md`

Implemented:
- retain original-class 28-tile width and 8x8 cells;
- compress vertical structure from the arcade's 31 maze rows to 20 Spectrum rows instead of shrinking tiles;
- recognizable upper blocks, central reserved structure, symmetric lower routes and below-centre Pac spawn;
- 0.3.9 opens the centre-height side corridor and gives it functional wrap via `P48-040`.

Acceptance:
- [x] static topology/connectivity guard PASS;
- [x] no unreachable pellets/dead ends;
- [x] horizontal symmetry;
- [x] functional centre tunnel exists;
- [ ] owner V3 accepts landscape composition and tunnel presentation;
- [ ] ghost-house/power-pellet metadata added under `P48-034/021/022`.

## P48-020 — Score/high-score HUD and reserved bands
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019` V3

## P48-021 — Power pellets and life/bonus strip
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`, `P48-020`, `P48-034`

## P48-022 — Ghost-house presentation and actor color strategy
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-019`, `P48-016`, `P48-034`

## P48-023 — Visual regression gate
- **Status:** `READY` | **Priority:** `P1` | **Depends on:** `P48-018`

---

# Arcade-research-derived tasks

## P48-031 — Replace exact-node turning with arcade turn-window cornering
- **Status:** `VERIFY` | **Priority:** `P0`
- **Files:** `src/config.asm`, `src/player.asm`, `tests/control_harness.asm`
- **Incident:** `INC-2026-015`
- **Reference:** `docs/PACMAN_REFERENCE.md`, Pac-Man Dossier cornering analysis
- **Supersedes final control scope of:** `P48-028`
- **Implemented in:** `6276c675e162a51e3e0a7975394e9e7a2963fac5`, tests completed in `be20f9eb5575119b617d0cadeabf9b0d769c9733`

### Implemented

- perpendicular requests no longer require exact 8-pixel node alignment;
- `Pac_TurnWindow=3` permits the closest legal node up to three pixels before or after centre;
- when the requested branch is legal, the old travel axis is snapped exactly to the node before the new direction advances;
- the new corridor therefore always starts centered, preventing accumulated off-axis states from blocking later turns;
- 180-degree reversals remain immediate;
- full-edge collision remains authoritative after the turn;
- successful snap also synchronizes tile/pellet state before continuing.

### Deterministic evidence

The Z80 control harness verifies:
- pre-turn from three pixels before a junction;
- post-turn recovery from two pixels after the junction;
- four-pixel midpoint remains outside the +/-3 window;
- turned actor is exactly centered on the new corridor axis;
- existing reversal/dead-end regressions still pass.

CI run `32835864703`: PASS.

### Remaining acceptance

- [x] deterministic pre-turn/post-turn harnesses pass;
- [x] auto-centering is asserted after a turn;
- [x] no wall clipping regression in runtime harness;
- [ ] owner V3 confirms first-opening turns are materially more fluid;
- [ ] owner V3 confirms Pac no longer becomes unable to turn in the next corridor.

## P48-032 — Add 50 Hz actor movement-pattern engine
- **Status:** `READY` | **Priority:** `P1` | **Depends on:** `P48-031` V3
- Use rotating bit patterns to decide per-frame one-pixel movement rather than fractional arithmetic.
- Define data-driven patterns for Pac normal/energized and ghost normal/frightened/tunnel/Elroy.
- Preserve arcade speed ratios/feel but derive Spectrum 50 Hz patterns rather than copying ~60 Hz values blindly.
- Add deterministic distance-per-N-frames tests.

## P48-033 — Deterministic 50 Hz gameplay state machine and event order
- **Status:** `READY` | **Priority:** `P1`
- Formal states: at minimum READY, PLAY, DYING, LEVEL_CLEAR, GAME_OVER.
- Make one authoritative per-frame event order around `HALT`.
- Centralize timers/counters rather than scattering frame logic across modules.
- Document when pellet/energizer, ghost transitions, fruit, collisions, score and level completion take effect.

## P48-034 — Layer maze geometry, collectibles and special metadata
- **Status:** `READY` | **Priority:** `P1` | **Depends on:** `P48-019` V3
- Keep geometry/player walkability separate from collectible state and special flags.
- Add explicit metadata for tunnel/warp endpoints, ghost tunnel slow zones, ghost house, door, actor spawns, energizers, fruit and arcade no-UP ghost intersections.
- Extend topology validator for player-only/ghost-only regions instead of weakening generic connectivity checks.
- The first functional player tunnel is implemented by `P48-040`; migrate its hard constants into the metadata layer here.

## P48-035 — Common tile-target ghost navigation core
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-031`, `P48-034`
- No runtime A*/BFS for ordinary pursuit.
- Decide at/approaching intersections, enumerate legal directions, normally remove reversal, evaluate next-tile distance to target, deterministic tie priority UP -> LEFT -> DOWN -> RIGHT.
- Common code owns navigation; personality code supplies targets.

## P48-036 — Implement Blinky/Pinky/Inky/Clyde target functions
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-035`
- Blinky targets Pac; Pinky targets ahead; Inky combines Pac/Blinky vector; Clyde switches based on distance.
- Preserve intentional arcade quirks only when verified/documented; do not accidentally recreate bugs without a decision.

## P48-037 — Scatter / Chase / Frightened global ghost commander
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-033`, `P48-035`
- Table-driven schedule, reversal requests on mode changes, frightened override/expiry and per-ghost state integration.

## P48-038 — Data-driven level progression, release rules and Cruise Elroy
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-032`, `P48-033`, `P48-037`
- Tables for actor speed patterns, frightened duration, tunnel speed, house release, scatter/chase schedule, Elroy thresholds/speeds and fruit parameters.
- Avoid `IF level == ...` logic scattered throughout gameplay modules.

## P48-039 — Same-frame gameplay-order regression harness
- **Status:** `BLOCKED` | **Priority:** `P1` | **Depends on:** `P48-033`
- Deterministically test simultaneous/adjacent events:
  - pellet/energizer + collision;
  - frightened expiry + collision;
  - final pellet + death;
  - fruit expiry + pickup;
  - ghost mode change + house transition;
  - tunnel/warp + movement-pattern skip.
- Once an event order is selected, future agents must not silently reorder it.

## P48-040 — Functional centre side-tunnel wrap
- **Status:** `VERIFY` | **Priority:** `P1`
- **Files:** `src/config.asm`, `src/maze.asm`, `src/player.asm`, `tools/check_maze_topology.py`, `tests/control_harness.asm`
- **Reference:** `docs/PACMAN_REFERENCE.md`
- **Implemented in:** `be20f9eb5575119b617d0cadeabf9b0d769c9733`

Implemented:
- maze row 9 opens to both side edges;
- left/right endpoints are explicit canonical constants;
- moving LEFT from `(0,9)` wraps to `(27,9)` and vice versa;
- player remains in valid maze coordinates; no out-of-range collision exception is needed;
- topology flood-fill treats tunnel endpoints as adjacent;
- both wrap directions are covered by Z80 control tests.

Evidence:
- 246 reachable cells / 210 reachable pellets / zero dead ends;
- left->right and right->left wrap tests PASS;
- canonical CI/TAP load PASS.

Remaining:
- [ ] owner V3 confirms tunnel is visually obvious and wrap feels correct;
- [ ] later `P48-034` adds metadata/ghost tunnel-speed semantics rather than hard-coding more tunnel behavior.

---

# Existing foundation tasks

## P48-001 — Preserve maze coordinates across attribute drawing
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-001`

## P48-002 — Correct Sinclair 1/2 directions
- **Status:** `VERIFY` | **Priority:** `P0` | **Incident:** `INC-2026-002`

## P48-003 — Remove full-maze redraw from gameplay frames
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`

## P48-004 — Stabilize attribute ownership for moving actors
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-005 — Synchronize documentation with pixel movement
- **Status:** `DONE` | **Priority:** `P1`

## P48-006 — Add exact project license file
- **Status:** `BLOCKED` | **Priority:** `P1`
- Owner must explicitly choose exact license/variant; agents must not infer it from third-party GPL research.

## P48-007 — VERSION as single semantic-version source
- **Status:** `DONE` | **Priority:** `P2`

## P48-008 — Repeatable verification baseline
- **Status:** `VERIFY` | **Priority:** `P2`

## P48-009 — First complete gameplay loop
- **Status:** `BLOCKED` | **Priority:** `P2`
- Pellet consumption exists. Remaining gameplay is decomposed into `P48-031..040`, plus score/lives/level completion/sound.

## P48-010 — Dedicated render module / prepare-commit phases
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-011 — Generated masked pre-shifted actors
- **Status:** `DONE` | **Priority:** `P1`

## P48-012 — Masked actor renderer
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-003`

## P48-013 — Simulation-only player module
- **Status:** `VERIFY` | **Priority:** `P1`

## P48-014 — Cycle/memory budget profiling
- **Status:** `DONE` | **Priority:** `P2`

## P48-015 — Persistent incidents/changelog discipline
- **Status:** `DONE` | **Priority:** `P1`

## P48-016 — Explicit canonical opacity masks for future actor art
- **Status:** `READY` | **Priority:** `P2`

## P48-017 — Publish latest verified TAP from GitHub
- **Status:** `DONE` | **Priority:** `P1`

---

## Adding tasks

Use the next unused `P48-###` ID. Include status, priority, files/dependencies, related incident/reference, problem, plan and acceptance evidence. Never leave important development intent only in chat.