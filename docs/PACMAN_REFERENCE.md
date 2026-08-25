# PAC48 — Pac-Man arcade programming reference

This document records external research that may shape PAC48. It is a design/reference document, not a claim that PAC48 contains Namco arcade source code.

## Source status and provenance

No official public release of the original Namco Pac-Man source code was found during this research. Do not describe third-party recreations as "the original source".

Useful references:

1. **Marco Leal — ZX Spectrum Pac-Man Arcade**
   - https://marco-leal-zx.itch.io/zx-pacman-arcade
   - A released ZX Spectrum 48K conversion reporting 50 fps, sound, no tearing/flicker, arcade-style level progression, rules, timing and ghost logic.
   - PAC48 uses it as feasibility evidence: a highly faithful Pac-Man-class game at 50 Hz is realistic on a 48K Spectrum.

2. **Jamey Pittman — The Pac-Man Dossier**
   - https://pacman.holenet.info/
   - Based on disassembly output from original Pac-Man code ROMs plus gameplay testing.
   - Primary behavioral reference for 8x8 logical tiles, pixel-level actor motion, cornering, tunnel behavior, target-tile ghost decisions, scatter/chase/frightened and ghost personalities.

3. **Shaun Williams / Shaun LeBron — open Pac-Man recreation**
   - https://github.com/shaunlebron/pacman
   - `src/maps.js` contains an independently reconstructed 28x36 map representation for Pac-Man, including the 31 maze rows, ghost-house area and special ghost-turn restrictions.
   - This is a third-party GPL recreation/reverse-engineering resource, not Namco source.
   - PAC48 may use its topology as a research reference, but should keep its own independently encoded map/data structures.

4. **Shaun LeBron — Pac-Man maze generation constraints**
   - https://shaunlebron.github.io/pacman-mazegen/
   - Useful structural rules: symmetry, one-tile paths, avoid dead ends, avoid intersections/turns too close together, deliberate tunnel placement.

5. **Movement-pattern research / translated ROM behavior**
   - https://pacmanc.blogspot.com/
   - Useful reference for bit-pattern movement rates and event/state-machine behavior. Treat it as secondary evidence and cross-check important behavior with the Dossier.

## Original arcade coordinate model

The arcade screen is logically 28 x 36 tiles at 8 x 8 pixels per tile. The actual maze occupies 28 x 31 gameplay rows, with additional vertical space used by score/HUD presentation.

Important consequences:

- actors move with pixel precision but reason about tiles;
- the actor center determines the occupied tile;
- pellets are centered one tile apart;
- ghost decisions can be tile-based even though rendering/motion are pixel-based.

PAC48 should preserve this separation rather than treating rendering cells, actor position and gameplay decisions as the same concept.

## PAC48 4:3 landscape adaptation

ZX Spectrum bitmap: 256 x 192. PAC48 keeps 8 x 8 logical cells because they align naturally with Spectrum attributes and the existing renderer.

Current target:

- logical maze: **28 x 20**;
- screen-cell offset: `(2,2)`;
- maze display: 224 x 160 pixels;
- top band remains available for build/HUD information;
- Pac begins below the centre at `(13,15)`, facing left.

The 0.3.8 maze is deliberately **not a byte-for-byte copy** of arcade ROM data. It compresses the vertical topology while retaining recognizable structural ideas from the original:

- horizontally symmetric overall form;
- classic upper paired blocks and central divider;
- central reserved/non-pellet structure suitable for a future ghost house;
- paired left/right vertical routes around the central area;
- lower maze routes derived from the characteristic arcade lower half;
- Pac start below the central structure;
- no unreachable player pellets;
- no accidental player dead ends.

Approximate design correspondence used for the landscape reduction (PAC48 row -> conceptual arcade maze row/region):

```text
00 -> top boundary
01 -> upper pellet corridor
02 -> first block row
03 -> upper full corridor
04 -> second block row
05 -> cross/side corridor
06 -> upper approach to centre
07 -> central open approach
08 -> central-house band
09 -> central-house/tunnel-height band, compressed
10 -> central-house band
11 -> central open exit
12 -> lower central boundary
13 -> lower full corridor
14 -> lower block row
15 -> Pac start corridor
16 -> lower split block row
17 -> lower cross corridor
18 -> bottom full corridor
19 -> bottom boundary
```

Side-tunnel wrap is intentionally deferred until maze metadata/warp behavior exists. Do not create apparent tunnel exits that are actually dead ends merely to imitate the arcade silhouette.

## Automated maze invariants

`tools/check_maze_topology.py` is authoritative for current player topology. A production maze must:

- be exactly 28 x 20;
- remain horizontally symmetric for the current classic layout;
- keep Pac start in walkable space;
- have every normal pellet reachable from Pac start;
- contain no accidental player dead ends.

The first 0.3.8 landscape map passes with:

- 234 player-reachable cells;
- 198 normal pellets;
- 0 unreachable pellets;
- 0 player dead ends.

When functional side tunnels, ghost-house-only cells or one-way ghost restrictions are introduced, extend the validator with explicit metadata rather than weakening these invariants globally.

## Cornering model to adopt

PAC48's exact-8-pixel turn gate is an interim model. The arcade behavior is more forgiving: requested perpendicular turns can begin around the junction before exact centre alignment and finish by centering the actor onto the new corridor.

Target architecture:

- current movement vector and requested/next vector are distinct;
- store a turn request before the junction;
- define a bounded pre-turn window;
- once a requested turn becomes geometrically legal, start cornering immediately;
- auto-centre the orthogonal coordinate onto the destination corridor;
- allow a short post-centre completion phase if needed;
- never permit collision-box wall clipping.

This should replace repeated patches around `pixel % 8 == 0` rather than adding more special cases to that rule.

## Movement-rate engine

The arcade uses discrete movement patterns rather than expensive fractional-speed arithmetic. PAC48 should adopt the same class of solution at 50 Hz:

- a rotating bit pattern determines whether an actor advances one pixel on a given tick;
- separate patterns for Pac normal/energized and ghosts normal/frightened/tunnel/Cruise-Elroy;
- preserve arcade *ratios and feel*, but derive values for Spectrum 50 Hz instead of copying ~60 Hz timing blindly.

This keeps actor motion deterministic and cheap on Z80.

## Deterministic 50 Hz gameplay state machine

`HALT` remains the canonical frame clock. Gameplay event order must be explicit and testable. Target ordering should be documented before enemies/fruit introduce same-frame ambiguities, for example:

```text
HALT / render commit
input sample
player/actor movement decisions
pellet / energizer consumption
ghost-house and global-mode transitions
fruit / timed events
actor collisions
score / level-complete consequences
render preparation
```

Exact ordering may change after arcade cross-checking, but there must be one authoritative order and regression tests for simultaneous events.

## Maze data should become layered

The current single `Maze_Map` is sufficient for walls/pellets/empty cells only. Before ghost gameplay, separate persistent concepts:

- geometry / player walkability;
- collectible map;
- special flags/metadata.

Metadata candidates:

- tunnel / warp endpoints;
- tunnel ghost slow zones;
- ghost house interior;
- ghost-house door;
- ghost-only / player-only restrictions where required;
- intersections where ghosts cannot choose UP (arcade-specific rule);
- Pac/ghost spawn points;
- energizer positions;
- fruit position.

Do not overload a growing integer cell enum with unrelated responsibilities if bit flags or parallel compact maps are clearer.

## Ghost AI architecture

Do not implement general A*, BFS or full-path search at runtime for normal ghost pursuit.

Target common core:

1. decide at/approaching an intersection;
2. enumerate legal candidate directions;
3. normally exclude immediate reversal;
4. calculate the next tile for each candidate;
5. choose the candidate nearest the current target tile;
6. use deterministic arcade tie priority (UP, LEFT, DOWN, RIGHT).

Most personality differences belong in target-tile functions, not separate pathfinders:

- Blinky: target Pac's current tile;
- Pinky: target ahead of Pac;
- Inky: target derived from Pac and Blinky;
- Clyde: chase when far, scatter-corner target when near.

Global modes (scatter/chase/frightened) should be state-machine driven and may request reversals at mode boundaries.

## Data-driven level progression

Avoid level-number conditionals scattered across actor code. Introduce compact level/config tables for:

- movement patterns;
- frightened duration;
- tunnel speed;
- ghost release thresholds/timers;
- scatter/chase schedule;
- Cruise Elroy thresholds and speeds;
- fruit type/value/timing.

This is especially important if PAC48 eventually aims at Marco-Leal-like arcade progression fidelity.

## Regression cases to add before full gameplay

Same-frame event tests should cover at least:

- pellet/energizer pickup on a collision frame;
- frightened expiration on a collision frame;
- final pellet and player death in the same tick;
- fruit expiry and fruit pickup in the same tick;
- global ghost-mode transition while a ghost leaves/enters the house;
- tunnel/warp transition exactly on a movement-pattern skip tick.

These tests are part of engineering memory: once ordering is chosen, future agents must not silently reorder the frame pipeline.

## Licensing / attribution note

Researching a third-party GPL recreation does not determine PAC48's project license. `P48-006` remains blocked until the owner explicitly chooses the exact GPL variant or another permitted license. Agents must not guess or silently copy third-party source code wholesale.
