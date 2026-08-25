; ============================================================
; PAC48 Render_Commit performance harness
; ============================================================
; Setup entry points prepare snapshots for measured commits with different
; previous dirty-cell counts. tools/run_perf_tests.sh executes setup first,
; then starts a second cycle-aware trace exactly at PERF_MEASURE_START.

        ORG 32768
        JP Perf_CommonSetup

        INCLUDE "../src/config.asm"
        INCLUDE "../src/memory.asm"
        INCLUDE "../src/video.asm"
        INCLUDE "../src/sprites.asm"
        INCLUDE "../src/generated/pac_shifted.asm"
        INCLUDE "../src/maze.asm"
        INCLUDE "../src/player.asm"
        INCLUDE "../src/render.asm"

PERF_COMMON_SETUP   EQU 45000
PERF_DIRTY2_SETUP   EQU 46000
PERF_DIRTY4_SETUP   EQU 47000
PERF_MEASURE_START  EQU 49000
PERF_MEASURE_STOP   EQU 49900

; Shared deterministic environment.
Perf_Init:
        DI
        LD SP, 64000
        CALL Video_Clear
        CALL Video_InitLineTable
        CALL Maze_Draw
        CALL Render_Init
        XOR A
        LD (FrameCounter), A
        LD A, 4
        LD (Pac_FacingDir), A
        RET

; ------------------------------------------------------------
; Common case: previous frame was byte/cell aligned (1 dirty cell).
; Prepared frame is phase 1. Measured commit restores 1 cell and draws 1 actor.
; ------------------------------------------------------------
        ORG PERF_COMMON_SETUP
Perf_CommonSetup:
        CALL Perf_Init
        LD A, 24
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        CALL Render_Prepare
        CALL Render_Commit

        LD A, 25
        LD (Pac_PixelX), A
        LD A, 24
        LD (Pac_PixelY), A
        CALL Render_Prepare
        JP PERF_MEASURE_START

; ------------------------------------------------------------
; Current cardinal-player worst case: previous frame crosses one byte boundary
; while Y remains aligned, so 2 maze cells must be restored.
; ------------------------------------------------------------
        ORG PERF_DIRTY2_SETUP
Perf_Dirty2Setup:
        CALL Perf_Init
        LD A, 25
        LD (Pac_PixelX), A
        LD A, 24
        LD (Pac_PixelY), A
        CALL Render_Prepare
        CALL Render_Commit

        LD A, 26
        LD (Pac_PixelX), A
        LD A, 24
        LD (Pac_PixelY), A
        CALL Render_Prepare
        JP PERF_MEASURE_START

; ------------------------------------------------------------
; General 8x8 arbitrary-position case: previous actor overlaps four cells.
; Player gameplay does not currently move diagonally; this measures renderer
; headroom for future actors/animation paths using both sub-cell axes.
; ------------------------------------------------------------
        ORG PERF_DIRTY4_SETUP
Perf_Dirty4Setup:
        CALL Perf_Init
        LD A, 25
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        CALL Render_Prepare
        CALL Render_Commit

        LD A, 26
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        CALL Render_Prepare
        JP PERF_MEASURE_START

; ------------------------------------------------------------
; This exact range is the measurement target.
; ------------------------------------------------------------
        ORG PERF_MEASURE_START
Perf_MeasureStart:
        CALL Render_Commit
        JP PERF_MEASURE_STOP

        END
