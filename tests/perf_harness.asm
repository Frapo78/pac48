; ============================================================
; PAC48 Render_Commit performance harness
; ============================================================
; This harness is deliberately continuous in raw-file memory.
;
; Performance state is injected directly into the raw binary by
; tools/run_perf_tests.sh using SkoolKit trace.py --poke/--reg/--state.
; No intermediate snapshot is written or reloaded. This guarantees that the
; bytes executed at Perf_MeasureStart are exactly the bytes assembled here.
;
; INC-2026-006 documents why snapshot round-tripping is forbidden for exact
; instruction-range timing evidence.

        ORG 32768
        JP Perf_MeasureStart

        INCLUDE "../src/config.asm"
        INCLUDE "../src/memory.asm"
        INCLUDE "../src/video.asm"
        INCLUDE "../src/sprites.asm"
        INCLUDE "../src/generated/pac_shifted.asm"
        INCLUDE "../src/maze.asm"
        INCLUDE "../src/player.asm"
        INCLUDE "../src/render.asm"

; ------------------------------------------------------------
; Exact measured range. tools/run_perf_tests.sh prepares all state directly:
; - Video_LineAddrTable
; - Render_DirtyCount / Render_DirtyCells
; - Render_NextDirtyCount / Render_NextDirtyCells
; - Render_PlayerX / Render_PlayerY / Render_PlayerSprite
; - SP and tstates
; ------------------------------------------------------------
Perf_MeasureStart:
        CALL Render_Commit
        JP Perf_MeasureStop
Perf_MeasureStop:
        NOP

; Measurement wrapper.
        EXPORT Perf_MeasureStart
        EXPORT Perf_MeasureStop

; Mutable renderer state injected by the profiler.
        EXPORT Render_PlayerX
        EXPORT Render_PlayerY
        EXPORT Render_PlayerSprite
        EXPORT Render_DirtyCount
        EXPORT Render_NextDirtyCount
        EXPORT Render_DirtyCells
        EXPORT Render_NextDirtyCells
        EXPORT Video_LineAddrTable

; Representative generated player phases used by timing cases.
        EXPORT Pac_Shifted_Right_F0_P1
        EXPORT Pac_Shifted_Right_F0_P2

        END
