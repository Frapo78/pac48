; =========================
; MAZE DATA & ROUTINES
; =========================

; costanti celle
Maze_CellPath   EQU 0
Maze_CellWall   EQU 1

Maze_Width      EQU 28
Maze_Height     EQU 20

; attributi per rendering
Maze_AttrPath   EQU COLOR_YELLOW
Maze_AttrWall   EQU (COLOR_BLUE << 3) | COLOR_YELLOW

; ------------------------------------------
; Disegna l'intero labirinto
; usa Video_DrawTile: D=x, E=y, A=attr
Maze_Draw:
    LD HL, Maze_Map
    LD B, Maze_Height        ; contatore righe
    LD E, 0                  ; y corrente

.row_loop:
    LD C, Maze_Width
    LD D, 0                  ; x corrente

.col_loop:
    LD A, (HL)
    CP Maze_CellWall
    JR Z, .draw_wall
    LD A, Maze_AttrPath
    JR .draw_tile
.draw_wall:
    LD A, Maze_AttrWall
.draw_tile:
    PUSH HL
    PUSH BC
    PUSH DE
    CALL Video_DrawTile
    POP DE
    POP BC
    POP HL

    INC HL
    INC D
    DEC C
    JR NZ, .col_loop

    INC E
    DEC B
    JR NZ, .row_loop

    RET

; ------------------------------------------
; Controlla se la cella (D=x, E=y) è attraversabile
; Ritorna A=1 se ok, A=0 se muro o fuori mappa
Maze_CanMove:
    ; limiti X
    LD A, D
    CP Maze_Width
    JR NC, .blocked
    ; limiti Y
    LD A, E
    CP Maze_Height
    JR NC, .blocked

    ; calcola offset = y*28 + x
    LD A, D
    PUSH AF              ; salva x

    LD A, E
    LD H, 0
    LD L, A              ; HL = y
    ADD HL, HL           ; y*2
    ADD HL, HL           ; y*4
    PUSH HL              ; salva y*4
    ADD HL, HL           ; y*8
    POP DE               ; DE = y*4
    ADD HL, DE           ; y*12
    ADD HL, HL           ; y*24
    ADD HL, DE           ; y*28

    POP AF               ; ripristina x
    LD D, 0
    LD E, A
    ADD HL, DE           ; HL = offset

    LD DE, Maze_Map
    ADD HL, DE
    LD A, (HL)
    CP Maze_CellWall
    JR Z, .blocked

    LD A, 1
    RET

.blocked:
    XOR A
    RET

; ------------------------------------------
; Dati del labirinto (28x20)
Maze_Map:
    ; riga 0
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    ; riga 1
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; riga 2
    DEFB 1,0,1,1,1,0,1,0,1,1,0,1,0,1,1,0,1,0,1,1,0,1,0,1,1,1,0,1
    ; riga 3
    DEFB 1,0,1,0,0,0,1,0,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,1
    ; riga 4
    DEFB 1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,1
    ; riga 5
    DEFB 1,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,1
    ; riga 6
    DEFB 1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,0,1
    ; riga 7
    DEFB 1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1
    ; riga 8
    DEFB 1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,0,1,1,0,1
    ; riga 9
    DEFB 1,0,1,0,0,0,1,0,1,0,0,0,1,0,1,0,1,0,0,0,1,0,1,0,0,1,0,1
    ; riga 10
    DEFB 1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,1
    ; riga 11
    DEFB 1,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,1
    ; riga 12
    DEFB 1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1
    ; riga 13
    DEFB 1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1
    ; riga 14
    DEFB 1,0,1,1,1,1,0,1,1,1,0,1,1,0,1,1,0,1,1,1,0,1,1,1,1,0,1,1
    ; riga 15
    DEFB 1,0,1,0,0,0,0,0,1,0,1,0,0,0,0,0,1,0,1,0,0,0,0,0,1,0,0,1
    ; riga 16
    DEFB 1,0,1,0,1,1,1,0,1,0,1,1,1,0,1,0,1,0,1,1,1,0,1,0,1,1,0,1
    ; riga 17
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; riga 18
    DEFB 1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1
    ; riga 19
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
