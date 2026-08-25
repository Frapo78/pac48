; ==========================================
; PAC48 - main.asm
; Entry point and frame orchestration
; ==========================================

        ORG 32768

        JP START

; ---- include order: low-level/state -> generated metadata -> gameplay/render
        INCLUDE "config.asm"
        INCLUDE "memory.asm"
        INCLUDE "generated/build_info.asm"
        INCLUDE "menu.asm"
        INCLUDE "input.asm"
        INCLUDE "video.asm"
        INCLUDE "hud.asm"
        INCLUDE "sprites.asm"
        INCLUDE "generated/pac_shifted.asm"
        INCLUDE "maze.asm"
        INCLUDE "pellets.asm"
        INCLUDE "player.asm"
        INCLUDE "render.asm"

; ==========================================
; ENTRY POINT
; ==========================================
START:
        DI
        LD SP, 65535

        CALL Menu_Run
        CALL Video_Clear
        CALL Video_InitLineTable
        CALL HUD_DrawBuildStamp

        ; The spawn tile is considered occupied by Pac at level start, so its
        ; normal pellet is consumed before the initial maze is drawn.
        CALL Player_ConsumeCurrentPellet
        CALL Maze_Draw
        CALL Render_Init
        CALL Render_Prepare

        EI

; ==========================================
; MAIN GAME LOOP
;
; Commit is intentionally first after HALT: all expensive simulation and
; descriptor preparation happen after the short screen update phase.
; ==========================================
MainLoop:
        HALT
        CALL Render_Commit

        CALL Input_Read
        OR A
        JR Z, .keep_dir
        LD (Pac_ReqDir), A
.keep_dir:
        CALL Player_Update
        CALL Video_BeginFrame
        CALL Render_Prepare
        CALL Video_EndFrame

        JP MainLoop

        END START
