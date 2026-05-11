; =========================
; MAZE DATA & ROUTINES
; =========================

; costanti celle
Maze_CellPellet EQU 0
Maze_CellWall   EQU 1
Maze_CellEmpty  EQU 2

Maze_Width      EQU 28
Maze_Height     EQU 20

Maze_OffsetX    EQU 2
Maze_OffsetY    EQU 2

; attributi per rendering
Maze_AttrPellet EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW
Maze_AttrWall   EQU 64 | (COLOR_BLUE << 3) | COLOR_BLUE
Maze_AttrEmpty  EQU 64 | (COLOR_BLACK << 3) | COLOR_BLACK

; ------------------------------------------
; Disegna l'intero labirinto
; usa attributi per muri/pavimento e bitmap solo per pellet
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
    CP Maze_CellEmpty
    JR Z, .draw_empty
    PUSH HL
    PUSH BC
    PUSH DE
    LD A, Maze_AttrPellet
    CALL Maze_DrawTileAtOffset
    LD HL, Sprite_Pellet
    LD A, Maze_AttrPellet
    CALL Maze_DrawAtOffset
    POP DE
    POP BC
    POP HL
    JR .after_draw
.draw_empty:
    PUSH HL
    PUSH BC
    PUSH DE
    LD A, Maze_AttrEmpty
    CALL Maze_DrawTileAtOffset
    LD HL, Sprite_Empty
    LD A, Maze_AttrEmpty
    CALL Maze_DrawAtOffset          ; pulisce eventuale bitmap precedente
    POP DE
    POP BC
    POP HL
    JR .after_draw
.draw_wall:
    PUSH HL
    PUSH BC
    PUSH DE
    LD A, Maze_AttrWall
    CALL Maze_DrawTileAtOffset      ; muro solido via PAPER blu
    LD HL, Sprite_Empty
    LD A, Maze_AttrWall
    CALL Maze_DrawAtOffset          ; bitmap vuota, attributo resta blu
    POP DE
    POP BC
    POP HL
.after_draw:

    INC HL
    INC D
    DEC C
    JR NZ, .col_loop

    INC E
    DEC B
    JR NZ, .row_loop

    RET

; Disegna un tile con sprite e attributo, applicando offset per centrare la mappa
; In: HL=sprite, A=attr, D=x mappa, E=y mappa
Maze_DrawAtOffset:
    LD A, D
    ADD A, Maze_OffsetX
    LD D, A
    LD A, E
    ADD A, Maze_OffsetY
    LD E, A
    CALL Video_DrawSprite
    RET

; Disegna solo l'attributo di un tile, applicando offset mappa
; In: A=attr, D=x mappa, E=y mappa
Maze_DrawTileAtOffset:
    PUSH AF
    LD A, D
    ADD A, Maze_OffsetX
    LD D, A
    LD A, E
    ADD A, Maze_OffsetY
    LD E, A
    POP AF
    CALL Video_DrawTile
    RET

; Ripristina una singola cella del maze.
; In: D=x mappa, E=y mappa
Maze_DrawCell:
    LD A, D
    CP Maze_Width
    RET NC
    LD A, E
    CP Maze_Height
    RET NC

    PUSH DE
    LD A, D
    PUSH AF

    LD A, E
    LD H, 0
    LD L, A
    ADD HL, HL           ; y*2
    ADD HL, HL           ; y*4
    PUSH HL
    ADD HL, HL           ; y*8
    POP DE               ; y*4
    ADD HL, DE           ; y*12
    ADD HL, HL           ; y*24
    ADD HL, DE           ; y*28

    POP AF
    LD D, 0
    LD E, A
    ADD HL, DE
    LD DE, Maze_Map
    ADD HL, DE
    LD A, (HL)
    POP DE

    CP Maze_CellWall
    JR Z, .wall
    CP Maze_CellEmpty
    JR Z, .empty

    PUSH DE
    LD A, Maze_AttrPellet
    CALL Maze_DrawTileAtOffset
    LD HL, Sprite_Pellet
    LD A, Maze_AttrPellet
    CALL Maze_DrawAtOffset
    POP DE
    RET
.empty:
    PUSH DE
    LD A, Maze_AttrEmpty
    CALL Maze_DrawTileAtOffset
    LD HL, Sprite_Empty
    LD A, Maze_AttrEmpty
    CALL Maze_DrawAtOffset
    POP DE
    RET
.wall:
    PUSH DE
    LD A, Maze_AttrWall
    CALL Maze_DrawTileAtOffset
    LD HL, Sprite_Empty
    LD A, Maze_AttrWall
    CALL Maze_DrawAtOffset
    POP DE
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
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; riga 2
    DEFB 1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1
    ; riga 3
    DEFB 1,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1
    ; riga 4
    DEFB 1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,1,0,1,0,1,1,1,0,1,1
    ; riga 5
    DEFB 1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1
    ; riga 6
    DEFB 1,0,1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,0,1,1,1,0,1,0,1,1,1,1
    ; riga 7
    DEFB 1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1
    ; riga 8
    DEFB 1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,0,1,0,1,1,1,1,0,1,1,1,1,1
    ; riga 9
    DEFB 1,0,0,1,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,1,0,0,1
    ; riga 10
    DEFB 1,0,0,1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,1,0,1,1,1,1,1,0,0,1
    ; riga 11
    DEFB 1,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,1
    ; riga 12
    DEFB 1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,1,0,1,0,1,1,1,1,1,1
    ; riga 13
    DEFB 1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1
    ; riga 14
    DEFB 1,0,1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,0,1,1,1,0,1,0,1,1,1,1
    ; riga 15
    DEFB 1,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1
    ; riga 16
    DEFB 1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,1,1
    ; riga 17
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; riga 18
    DEFB 1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1
    ; riga 19
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
