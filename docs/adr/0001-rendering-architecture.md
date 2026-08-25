# ADR 0001 - Rendering architecture for PAC48

- **Status:** Accepted
- **Date:** 2026-08-25
- **Scope:** ZX Spectrum 48K rendering, frame pipeline, sprite assets, dirty restoration
- **Decision owner:** project architecture review

## Context

PAC48 is a single-screen maze-chase engine for the ZX Spectrum 48K. The current implementation already has useful gameplay foundations: tile-owned maze collision, buffered direction changes, pixel/sub-tile player movement, directional animation, and direct screen rendering.

The current rendering path is not suitable as the long-term engine architecture:

- `MainLoop` redraws the full 28x20 maze every frame.
- `Video_DrawSpritePx` shifts sprite data at runtime.
- The current pixel renderer writes sprite bytes destructively rather than compositing them with the background.
- Sprite drawing and maze restoration are coupled indirectly by the full-maze redraw.
- Attribute handling is not designed for shifted moving sprites.
- Game logic and time-critical video writes occur in the same frame phase.

A 48K Spectrum has no hardware sprites. Screen bitmap RAM at `$4000-$57ff` and attributes at `$5800-$5aff` are in contended RAM. The Z80 code and game data loaded at `$8000+` are in uncontended upper RAM on a 48K machine, so the architecture should minimize work touching screen RAM and do as much preparation as possible in upper RAM.

## Research basis

The decision is based on established Spectrum development techniques and measured implementations:

1. **Single-screen maze backgrounds are naturally tile-based.** Jonathan Cauldwell's game-programming material recommends a table of blocks for single-screen maze games, with cells transferred to screen as needed.
2. **Runtime sprite shifting is expensive.** Cauldwell recommends pre-shifted sprite copies when many moving sprites are required, explicitly describing the speed/memory trade-off.
3. **Screen-line lookup tables are a good speed/memory trade.** A 192-entry table costs 384 bytes and avoids repeated Spectrum bitmap-address arithmetic. Rafe Becket's measured sprite work reports materially lower T-state cost using a line-address table.
4. **Prepare first, draw quickly.** Measured Spectrum renderers benefit from doing compositing/bookkeeping outside the time-critical display update and committing prepared cell data quickly after frame synchronization.
5. **Contended video RAM is the scarce execution resource.** `$4000-$7fff` accesses can be delayed while the ULA is reading the display. Code/data in upper 32K can execute without that RAM contention.
6. **A full 48K software back buffer is not the default answer.** It consumes significant RAM and still requires an expensive copy/update path. PAC48 has a mostly static single-screen maze, so restoring only touched background cells is a better fit.

### References

- Jonathan Cauldwell, *How To Write ZX Spectrum Games*, sprite chapter: https://chuntey.wordpress.com/2013/09/08/how-to-write-zx-spectrum-games-chapter-8/
- Jonathan Cauldwell, background/maze blocks: https://chuntey.wordpress.com/2013/09/08/how-to-write-zx-spectrum-games-chapter-9/
- Jonathan Cauldwell, timing: https://chuntey.wordpress.com/2013/10/02/how-to-write-zx-spectrum-games-chapter-12/
- Sinclair Wiki, Spectrum video modes: https://sinclair.wiki.zxnet.co.uk/wiki/Spectrum_Video_Modes
- Sinclair Wiki, contended memory: https://sinclair.wiki.zxnet.co.uk/wiki/Contended_memory
- Rafe Becket, *Faster Sprites on the ZX Spectrum*: https://ralphbecket.blogspot.com/2015/09/faster-sprites-on-zx-spectrum.html
- Rafe Becket, *More on drawing sprites on the ZX Spectrum*: https://ralphbecket.blogspot.com/2019/04/more-on-drawing-sprites-on-zx-spectrum.html

## Decision

PAC48 will use a **direct-to-screen, tile-backed, dirty-restored masked-sprite renderer**.

The current pixel/sub-tile movement model is retained. The rendering implementation around it will be replaced incrementally.

### 1. Static maze tilemap remains the source of truth

`Maze_Map` remains authoritative for persistent background state.

Walls, pellets, empty paths, energizers, doors, and later maze-owned states are represented in maze data. Rendering a background cell always derives from maze state rather than from a saved full-screen bitmap.

The initial maze is drawn once when gameplay begins. It is not redrawn in full each frame.

### 2. Moving actors use masked software sprites

The long-term actor renderer must use transparent masked compositing:

```text
screen = (screen AND mask) OR image
```

This preserves maze pixels around the actor silhouette and avoids the destructive black rectangle produced by simply writing shifted sprite bytes.

The baseline actor size remains 8x8 because it matches the current 8x8 maze grid and one-cell corridors. Larger actor art must not be introduced without checking corridor geometry and dirty-cell cost.

### 3. Horizontal sprite phases are pre-shifted

PAC48 keeps one-pixel movement and therefore supports eight horizontal phases (`x & 7`).

The hot render path must not shift every sprite row at runtime. Pre-shifted image/mask pairs should be produced ahead of gameplay, preferably at build time from canonical source frames.

This intentionally spends a few KB of upper RAM to save per-frame Z80 work. If measured memory pressure later becomes significant, reducing to four phases with two-pixel movement is an allowed optimization, but not the baseline.

### 4. Sprite asset generation becomes a build concern

Canonical human-editable sprite frames should remain compact and understandable. A build tool may generate:

- eight horizontal phases per frame;
- left/right output bytes for each shifted row;
- corresponding masks;
- frame/phase pointer tables.

Generated data must be reproducible from a clean checkout and should not require third-party runtime libraries on the Spectrum.

### 5. Use a screen-line address lookup table

A 192-entry word table (384 bytes) is accepted as the default way to obtain the Spectrum bitmap address for a pixel Y coordinate.

The renderer combines the line base with `x >> 3`. This removes repeated nonlinear bitmap-address calculation from the hot sprite loop.

A separate aligned fast path is encouraged for `x & 7 == 0`, where an 8x8 sprite occupies one byte per scanline instead of two.

### 6. Restore dirty maze cells, not the whole maze

Before drawing the next actor frame, restore only maze cells touched by actors in the previously displayed frame, plus persistent cells whose maze state changed.

An arbitrary-position 8x8 actor touches at most four 8x8 maze cells. Five actors therefore produce a small bounded dirty set before de-duplication.

The first implementation should favor a short dirty-cell list with simple de-duplication over a large generalized framebuffer system. Optimize the data structure only if profiling shows it matters.

### 7. Split preparation from time-critical screen commit

The target frame pipeline is:

```text
Game_Init
Render_PrepareInitial

loop:
    HALT
    Render_Commit        ; short, bounded writes to screen RAM
    Input_Read
    Game_Update          ; gameplay logic in upper RAM
    Render_Prepare       ; choose frames/phases, dirty list, descriptors
    jump loop
```

The important rule is not the exact routine names; it is the separation:

- **Commit phase:** screen restoration and actor drawing only, using already prepared descriptors.
- **Preparation/update phase:** collision, requested direction, animation selection, enemy AI, pellet state, dirty-list construction and address/frame selection.

A one-frame presentation latency is acceptable if it keeps the video commit deterministic and short.

### 8. 50 Hz remains the target

PAC48 should target one presented actor frame per Spectrum interrupt (about 50 Hz) while the actor count is small.

Do not redesign around 25 Hz pre-emptively. If measured commit/update cost cannot meet a stable 50 Hz budget after the dirty/preshift architecture is implemented, a fixed 25 Hz mode is acceptable and preferable to irregular 50/25 Hz oscillation.

### 9. Render timing is a measurable budget

The renderer should have an explicit T-state budget.

Initial engineering targets:

- aim for `Render_Commit` to remain around or below 12,000 T-states in the common case;
- treat roughly 14,000 T-states as a warning threshold because the active display begins shortly after the frame interrupt on a 48K Spectrum;
- record worst-case actor count and dirty-cell count when profiling.

Exact timing must be measured in a cycle-aware emulator/profiler before declaring the renderer finalized.

### 10. Keep screen attributes mostly static

The baseline actor renderer does **not** rewrite attributes for every sprite.

Walkable maze cells should use an attribute combination that keeps actor bitmap pixels visible throughout movement. This avoids per-sprite attribute churn and reduces color-clash side effects.

Distinct per-ghost colors may be introduced later as an explicit extension with documented clash/restore rules. They are not allowed to complicate the baseline renderer before the core game is stable.

### 11. Keep code and renderer data in uncontended upper RAM

The program already starts at `$8000`. Keep code, maze state, lookup tables, dirty lists, sprite descriptors, generated sprite data, score/life state, and AI state at `$8000+` unless there is a measured reason to do otherwise.

Screen RAM writes are necessarily contended; avoid placing hot executable code or frequently read sprite data in `$4000-$7fff`.

## Rejected baseline approaches

### Full-maze redraw every frame

Rejected. It scales with 560 maze cells even when only a few actors moved.

### Runtime bit shifting for every sprite row

Rejected as the long-term hot path. It saves RAM but spends too many cycles repeatedly.

### XOR-only sprites

Rejected as the baseline because maze pellets/background pixels would show through/invert inside moving actors and actor overlap becomes visually poor.

### Full software double buffer

Rejected as the baseline for this single-screen 48K game. It consumes too much memory/bandwidth compared with dirty restoration from the tilemap.

### Beam-racing/floating-bus dependency

Rejected as a core requirement. Such techniques can be very fast but are timing-sensitive and less portable across Spectrum-compatible hardware/emulators.

### Stack-as-screen, heavy self-modifying or generated runtime drawing code

Not forbidden forever, but deferred. Introduce only after profiling proves the simpler masked/preshifted pipeline cannot meet the budget. Any such optimization requires a new ADR because it affects interrupts, stack safety and maintainability.

## Module boundary after migration

The target ownership is:

- `main.asm` - orchestration only.
- `input.asm` - physical controls to logical input.
- `maze.asm` - persistent maze state, collision and cell rendering data.
- `player.asm` - player logic/state; no direct screen ownership after migration.
- future `enemy.asm` - enemy logic/state.
- `video.asm` - low-level Spectrum screen primitives and screen-address tables.
- new `render.asm` - dirty lists, sprite descriptors, frame prepare/commit and masked actor composition.
- `sprites.asm` or generated include - sprite frame/phase data only.

This extra render module is justified because frame composition is now a substantial responsibility separate from raw video addressing and gameplay logic.

## Migration rule

Do not rewrite all engine code in one unverified commit.

Migrate in independently buildable steps tracked in `docs/TODO.md`. During migration, legacy routines may remain temporarily, but new gameplay features must not increase dependence on full-maze redraw or destructive runtime-shift sprite drawing.
