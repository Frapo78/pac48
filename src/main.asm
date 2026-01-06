; ==========================================
; PAC48 - main.asm
; Entry point e game loop
; ==========================================

        ORG 32768

; ---- include ordine LOGICO
        INCLUDE "config.asm"
        INCLUDE "memory.asm"
        INCLUDE "menu.asm"
        INCLUDE "input.asm"
        INCLUDE "video.asm"
        INCLUDE "maze.asm"
        INCLUDE "player.asm"

; ==========================================
; ENTRY POINT
; ==========================================
START:
        DI
        LD SP, 65535

        CALL Video_Clear
        CALL Menu_Run          ; sceglie CtrlMode

        EI

; ==========================================
; MAIN GAME LOOP
; ==========================================
MainLoop:
        HALT

        CALL Input_Read        ; aggiorna Dir
        CALL Player_Update     ; aggiorna PacX/PacY
        CALL Video_BeginFrame
        CALL Maze_Draw
        CALL Player_Draw
        CALL Video_EndFrame

        JP MainLoop

        END START
