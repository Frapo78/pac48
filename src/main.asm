; ==========================================
; PAC48 - main.asm
; Entry point e game loop
; ==========================================

        ORG 32768

        JP START              ; salta oltre i dati inclusi e raggiunge l'entry point

; ---- include ordine LOGICO
        INCLUDE "config.asm"
        INCLUDE "memory.asm"
        INCLUDE "menu.asm"
        INCLUDE "input.asm"
        INCLUDE "video.asm"
        INCLUDE "sprites.asm"
        INCLUDE "maze.asm"
        INCLUDE "player.asm"

; ==========================================
; ENTRY POINT
; ==========================================
START:
        DI
        LD SP, 65535

        CALL Menu_Run          ; sceglie CtrlMode
        CALL Video_Clear       ; rimuove menu prima del gioco

        EI

; ==========================================
; MAIN GAME LOOP
; ==========================================
MainLoop:
        HALT

        CALL Input_Read        ; aggiorna Dir
        LD (Pac_Dir), A
        CALL Player_Update     ; aggiorna PacX/PacY
        CALL Video_BeginFrame
        CALL Maze_Draw
        CALL Player_Draw
        CALL Video_EndFrame

        JP MainLoop

        END START
