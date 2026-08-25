; =========================
; MAZE DATA & ROUTINES
; =========================

Maze_CellPellet EQU 0
Maze_CellWall   EQU 1
Maze_CellEmpty  EQU 2

Maze_Width      EQU 28
Maze_Height     EQU 20

Maze_OffsetX    EQU 2
Maze_OffsetY    EQU 2

; Walkable cells keep yellow INK on black PAPER so masked moving actors remain
; visible without changing attributes in the render hot path.
Maze_AttrPellet EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW
Maze_AttrWall   EQU 64 | (COLOR_BLUE << 3) | COLOR_BLUE
Maze_AttrEmpty  EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW

; ------------------------------------------
; Draw the complete persistent maze.
; Initialization/level operation only: normal frames use Maze_DrawCell.
Maze_Draw:
    LD HL, Maze_Map
    LD B, Maze_Height
    LD E, 0

.row_loop:
    LD C, Maze_Width
    LD D, 0

.col_loop:
    LD A, (HL)
    PUSH HL
    PUSH BC
    PUSH DE

    CP Maze_CellWall
    JR Z, .wall
    CP Maze_CellEmpty
    JR Z, .empty

    LD HL, Sprite_Pellet
    LD A, Maze_AttrPellet
    JR .draw
.wall:
    LD HL, Sprite_Empty
    LD A, Maze_AttrWall
    JR .draw
.empty:
    LD HL, Sprite_Empty
    LD A, Maze_AttrEmpty
.draw:
    ; Video_DrawSprite writes both bitmap and attribute, so there is no
    ; separate attribute write here.
    CALL Maze_DrawAtOffset

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

; Draw bitmap + attribute applying maze -> screen-cell offset.
; In: HL=sprite, A=attr, D=x maze, E=y maze
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

; Attribute-only helper for future/HUD/background cases.
; In: A=attr, D=x maze, E=y maze
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

; Restore one persistent maze cell.
; In: D=x maze, E=y maze
; Out: none. Out-of-range coordinates are ignored.
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

    ; HL = y*28
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

    POP AF               ; x
    LD D, 0
    LD E, A
    ADD HL, DE
    LD DE, Maze_Map
    ADD HL, DE
    LD A, (HL)
    POP DE               ; restore requested maze coordinate

    CP Maze_CellWall
    JR Z, .wall
    CP Maze_CellEmpty
    JR Z, .empty

    LD HL, Sprite_Pellet
    LD A, Maze_AttrPellet
    JP Maze_DrawAtOffset
.wall:
    LD HL, Sprite_Empty
    LD A, Maze_AttrWall
    JP Maze_DrawAtOffset
.empty:
    LD HL, Sprite_Empty
    LD A, Maze_AttrEmpty
    JP Maze_DrawAtOffset

; ------------------------------------------
; In: D=x, E=y maze coordinate
; Out: A=1 walkable, A=0 wall/outside
Maze_CanMove:
    LD A, D
    CP Maze_Width
    JR NC, .blocked
    LD A, E
    CP Maze_Height
    JR NC, .blocked

    ; HL = y*28 + x
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
; Maze data: 28x20 = 560 bytes
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
