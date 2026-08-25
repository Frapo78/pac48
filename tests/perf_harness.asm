; ============================================================
; PAC48 Render_Commit performance harness
; ============================================================
; The harness is deliberately continuous in raw-file memory. No fixed ORG gaps
; are used. sjasmplus exports the real addresses of setup/measure labels and
; tools/run_perf_tests.sh drives trace.py using those exported addresses.
; This prevents logical-PC/raw-offset mismatches (INC-2026-006).

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
        JP Perf_MeasureStart

; ------------------------------------------------------------
; Current cardinal-player worst case: previous frame crosses one byte boundary
; while Y remains aligned, so 2 maze cells must be restored.
; ------------------------------------------------------------
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
        JP Perf_MeasureStart

; ------------------------------------------------------------
; General 8x8 arbitrary-position case: previous actor overlaps four cells.
; Player gameplay does not currently move diagonally; this measures renderer
; headroom for future actors/animation paths using both sub-cell axes.
; ------------------------------------------------------------
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
        JP Perf_MeasureStart

; ------------------------------------------------------------
; This exact range is the measurement target.
; ------------------------------------------------------------
Perf_MeasureStart:
        CALL Render_Commit
        JP Perf_MeasureStop
Perf_MeasureStop:
        NOP

        EXPORT Perf_CommonSetup
        EXPORT Perf_Dirty2Setup
        EXPORT Perf_Dirty4Setup
        EXPORT Perf_MeasureStart
        EXPORT Perf_MeasureStop

        END
