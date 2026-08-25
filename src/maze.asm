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
; I corridoi mantengono INK giallo anche quando vuoti: gli attori mobili non
; riscrivono gli attributi e restano visibili durante il movimento sub-tile.
Maze_AttrPellet EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW
Maze_AttrWall   EQU 64 | (COLOR_BLUE << 3) | COLOR_BLUE
Maze_AttrEmpty  EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW

; ------------------------------------------
; Disegna l'intero labirinto.
; Va usato all'inizio del livello, non nel normale loop per-frame.
Maze_Draw:
    LD HL, Maze_Map
    LD B, Maze_Height
    LD E, 0

.row_loop:
    LD C, Maze_Width
    LD D, 0

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
    CALL Maze_DrawAtOffset
    POP DE
    POP BC
    POP HL
    JR .after_draw

.draw_wall:
    PUSH HL
    PUSH BC
    PUSH DE
    LD A, Maze_AttrWall
    CALL Maze_DrawTileAtOffset
    LD HL, Sprite_Empty
    LD A, Maze_AttrWall
    CALL Maze_DrawAtOffset
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

; Disegna bitmap + attributo applicando offset mappa.
; In: HL=sprite, A=attr, D=x mappa, E=y mappa
; Preserves: DE
Maze_DrawAtOffset:
    PUSH DE
    LD A, D
    ADD A, Maze_OffsetX
    LD D, A
    LD A, E
    ADD A, Maze_OffsetY
    LD E, A
    CALL Video_DrawSprite
    POP DE
    RET

; Disegna solo l'attributo applicando offset mappa.
; In: A=attr, D=x mappa, E=y mappa
; Preserves: DE
Maze_DrawTileAtOffset:
    PUSH DE
    PUSH AF
    LD A, D
    ADD A, Maze_OffsetX
    LD D, A
    LD A, E
    ADD A, Maze_OffsetY
    LD E, A
    POP AF
    CALL Video_DrawTile
    POP DE
    RET

; Ripristina una singola cella dalla sorgente persistente Maze_Map.
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
    ADD HL, HL
    ADD HL, HL
    PUSH HL
    ADD HL, HL
    POP DE
    ADD HL, DE
    ADD HL, HL
    ADD HL, DE

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
; Controlla se la cella (D=x, E=y) è attraversabile.
; Out: A=1 walkable, A=0 wall/outside.
Maze_CanMove:
    LD A, D
    CP Maze_Width
    JR NC, .blocked
    LD A, E
    CP Maze_Height
    JR NC, .blocked

    ; offset = y*28 + x
    LD A, D
    PUSH AF

    LD A, E
    LD H, 0
    LD L, A
    ADD HL, HL
    ADD HL, HL
    PUSH HL
    ADD HL, HL
    POP DE
    ADD HL, DE
    ADD HL, HL
    ADD HL, DE

    POP AF
    LD D, 0
    LD E, A
    ADD HL, DE

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
; Dati del labirinto (28x20 = 560 byte)
Maze_Map:
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1
    DEFB 1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1
    DEFB 1,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1
    DEFB 1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,1,0,1,0,1,1,1,0,1,1
    DEFB 1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1
    DEFB 1,0,1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,0,1,1,1,0,1,0,1,1,1,1
    DEFB 1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1
    DEFB 1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,0,1,0,1,1,1,1,0,1,1,1,1,1
    DEFB 1,0,0,1,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,1,0,0,1
    DEFB 1,0,0,1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,1,0,1,1,1,1,1,0,0,1
    DEFB 1,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,1
    DEFB 1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,1,1,1,1,0,1,0,1,1,1,1,1,1
    DEFB 1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1
    DEFB 1,0,1,1,1,1,0,1,0,1,1,1,0,1,1,1,1,0,1,1,1,0,1,0,1,1,1,1
    DEFB 1,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1
    DEFB 1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,1,1
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1
    DEFB 1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
