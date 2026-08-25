; ==========================================
; PAC48 - pellets.asm
; Persistent pellet state built on Maze_Map
; ==========================================
;
; Pellet gameplay state lives in the maze cell map. Consuming a pellet changes
; Maze_CellPellet -> Maze_CellEmpty; dirty restoration then redraws the updated
; cell automatically on the next relevant render commit.

; In: D=x maze tile, E=y maze tile
; Out: A=1 if a pellet was consumed, A=0 otherwise
; Preserves: DE
; Clobbers: AF, BC, HL
Pellet_ConsumeAt:
    LD A, D
    CP Maze_Width
    JR NC, .none
    LD A, E
    CP Maze_Height
    JR NC, .none

    PUSH DE
    LD B, D

    ; HL = y*28 + x
    LD A, E
    LD H, 0
    LD L, A
    ADD HL, HL           ; y*2
    ADD HL, HL           ; y*4
    PUSH HL
    ADD HL, HL           ; y*8
    POP DE               ; DE=y*4
    ADD HL, DE           ; y*12
    ADD HL, HL           ; y*24
    ADD HL, DE           ; y*28

    LD D, 0
    LD E, B
    ADD HL, DE
    LD DE, Maze_Map
    ADD HL, DE

    LD A, (HL)
    CP Maze_CellPellet
    JR NZ, .restore_none

    LD (HL), Maze_CellEmpty
    POP DE
    LD A, 1
    RET

.restore_none:
    POP DE
.none:
    XOR A
    RET
