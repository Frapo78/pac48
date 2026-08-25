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

# Current verified baseline — 0.3.8-beta

Verified code/release:

- commit: `d25c5f8304f510c76be638e95dbf14d5b946b096`;
- build ID: `D25C5F8`;
- CI run: `32834022347` — PASS;
- immutable TAP: `pac48-0.3.8-beta-bD25C5F8.tap`;
- TAP SHA-256: `d3189c5be91117de6ee97f0a34ed95590b371d4614a3df23d88ca688d123d70f`;
- fresh-48K TAP load reaches `$8000`;
- assembly: 0 errors / 0 warnings;
- control/runtime/render/performance harnesses: PASS;
- `Render_Commit`: 4341 / 5497 / 9184 T-states for dirty1 / dirty2 / dirty4.

0.3.8 also introduces the first arcade-inspired 4:3 maze candidate:

- 28 x 20 logical cells, preserving 8x8 tiles;
- horizontally symmetric;
- Pac start below centre at `(13,15)`, initially facing left;
- 234 player-reachable cells;
- 198 normal pellets, all reachable;
- zero accidental player dead ends;
- topology guard runs in every canonical build.

External research and design rationale are canonicalized in `docs/PACMAN_REFERENCE.md`.

---

# ACTIVE MILESTONE — Arcade-feel foundation

Recommended order after owner V3 on the 0.3.8 maze:

`P48-030 V3 -> P48-027/P48-019 V3 -> P48-031 -> P48-034 -> P48-032 -> P48-033/P48-039 -> P48-035 -> P48-036/P48-037 -> P48-038 -> broader P48-009`

The key change after Pac-Man arcade research is that `P48-031` supersedes further patches around exact 8-pixel turn alignment. The final control model should reproduce arcade-style pre-turn/centering rather than keep adding special cases to `%8 == 0`.

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
- **Implemented in:** `14e91f68b4c77b681adafb1d21a45f8cb599026c` + fixture alignment `d25c5f8304f510c76be638e95dbf14d5b946b096`

Implemented:
- replaced the prototype topology with the 0.3.8 connected landscape maze;
- `tools/check_maze_topology.py` flood-fills from canonical Pac start;
- every normal pellet must be player-reachable;
- current classic layout must remain horizontally symmetric;
- accidental player dead ends fail the build.

Evidence:
- 234 player-reachable cells;
- 198 reachable pellets;
- 0 unreachable pellets;
- 0 dead ends;
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

This fixes concrete stalls but owner feedback still describes overall cornering as sluggish. Do **not** keep extending this exact-alignment model indefinitely; final cornering is `P48-031`.

## P48-029 — Start Kempston from Kempston FIRE in menu
- **Status:** `VERIFY` | **Priority:** `P1`
- Structural/build guard passes; owner V3 confirmation remains.

## P48-030 — Readable version/build stamp in gameplay
- **Status:** `VERIFY` | **Priority:** `P1` | **Incident:** `INC-2026-013`
- Uses Spectrum ROM printable glyphs from `$3D00` after subtracting ASCII 32; generated version+commit identity; immutable TAP naming.
- [ ] owner V3 confirms the 0.3.8 stamp is clearly readable.

## P48-019 — Arcade-inspired 4:3 maze topology
- **Status:** `VERIFY` | **Priority:** `P1` | **Depends on:** `P48-027`
- **Reference:** `docs/PACMAN_REFERENCE.md`

Implemented first candidate in 0.3.8:
- keep original-class 28-tile width and 8x8 cells;
- compress vertical structure from the arcade's 31 maze rows to 20 Spectrum rows instead of shrinking tiles;
- retain recognizable upper blocks, central reserved structure, symmetric lower routes and below-centre Pac spawn;
- side tunnel silhouette is not faked as a dead end: functional warp metadata is deferred to `P48-034`.

Acceptance:
- [x] static topology/connectivity guard PASS;
- [x] no unreachable pellets/dead ends;
- [x] horizontal symmetry;
- [ ] owner V3 accepts landscape composition;
- [ ] future ghost-house/tunnel/power-pellet metadata added under `P48-034/021/022`.

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

## P48-031 — Replace exact-node turning with true arcade cornering
- **Status:** `READY` | **Priority:** `P0`
- **Files:** `src/input.asm`, `src/player.asm`, state memory, control harness
- **Reference:** `docs/PACMAN_REFERENCE.md`, Pac-Man Dossier cornering analysis
- **Supersedes final control scope of:** `P48-028`

### Problem
The current model still fundamentally waits for exact 8-pixel alignment for 90-degree turns. The original arcade allows a requested perpendicular turn around the junction and recentres the actor into the destination corridor. This is the main remaining source of "sluggish" steering.

### Plan
- represent current vector and requested/next vector independently;
- define a bounded pre-turn window before junction centre;
- begin a legal requested corner as soon as it enters that window;
- auto-centre the orthogonal coordinate onto the new corridor;
- support a bounded post-turn completion phase if required by the reference behavior;
- keep collision-box wall safety authoritative;
- use symmetric rules for all four directions/devices;
- remove obsolete exact-node special cases after tests pass.

### Acceptance
- [ ] holding a turn before an opening takes the first legal opening without a perceptible pause;
- [ ] late-but-valid input around the opening can still complete the turn;
- [ ] repeated diagonal steering feels continuous rather than stop/start;
- [ ] no wall clipping;
- [ ] deterministic pre-turn/post-turn harnesses pass;
- [ ] owner V3 describes controls as arcade-like/immediate.

## P48-032 — Add 50 Hz actor movement-pattern engine
- **Status:** `READY` | **Priority:** `P1` | **Depends on:** `P48-031`
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
- Functional side tunnels belong here.

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
- Pellet consumption exists. Remaining gameplay is now decomposed into `P48-031..039`, plus score/lives/level completion/sound.

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
