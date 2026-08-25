; ============================================================
; PAC48 Render_Commit performance harness
; ============================================================
; Setup entry points prepare snapshots for measured commits with different
; previous dirty-cell counts. tools/run_perf_tests.sh executes setup first,
; then starts a second cycle-aware trace exactly at PERF_MEASURE_START.
;
; IMPORTANT: this harness is emitted as a raw binary. ORG alone changes the
; logical address in sjasmplus but does not insert bytes into a raw file. Fixed
; measurement entry points therefore use DS padding so raw-file offset and Z80
; address stay identical. See INC-2026-006.

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
        ASSERT $ < PERF_COMMON_SETUP
        DS PERF_COMMON_SETUP - $, 0
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
        ASSERT $ < PERF_DIRTY2_SETUP
        DS PERF_DIRTY2_SETUP - $, 0
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
        ASSERT $ < PERF_DIRTY4_SETUP
        DS PERF_DIRTY4_SETUP - $, 0
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
        ASSERT $ < PERF_MEASURE_START
        DS PERF_MEASURE_START - $, 0
Perf_MeasureStart:
        CALL Render_Commit
        JP PERF_MEASURE_STOP

; Ensure the raw file actually contains the measured stop address so trace.py
; cannot accidentally run into implicit zero-filled memory beyond EOF.
        ASSERT $ < PERF_MEASURE_STOP
        DS PERF_MEASURE_STOP - $, 0
Perf_MeasureStop:
        NOP

        END
