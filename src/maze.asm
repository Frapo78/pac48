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
; Walls use black PAPER + bright blue INK and bitmap outline tiles.
Maze_AttrPellet EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW
Maze_AttrWall   EQU 64 | (COLOR_BLACK << 3) | COLOR_BLUE
Maze_AttrEmpty  EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW

Maze_WallSpriteTable:
    DW Sprite_Wall_0, Sprite_Wall_1, Sprite_Wall_2, Sprite_Wall_3
    DW Sprite_Wall_4, Sprite_Wall_5, Sprite_Wall_6, Sprite_Wall_7
    DW Sprite_Wall_8, Sprite_Wall_9, Sprite_Wall_10, Sprite_Wall_11
    DW Sprite_Wall_12, Sprite_Wall_13, Sprite_Wall_14, Sprite_Wall_15

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
    CALL Maze_SelectWallSprite
    LD A, Maze_AttrWall
    JR .draw
.empty:
    LD HL, Sprite_Empty
    LD A, Maze_AttrEmpty
.draw:
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
; Preserves: AF, DE
; Clobbers: BC, HL (through Video_DrawSprite)
Maze_DrawAtOffset:
    PUSH AF
    PUSH DE
    LD A, D
    ADD A, Maze_OffsetX
    LD D, A
    LD A, E
    ADD A, Maze_OffsetY
    LD E, A
    POP AF
    CALL Video_DrawSprite
    POP DE
    RET

; Attribute-only helper for future/HUD/background cases.
; In: A=attr, D=x maze, E=y maze
; Preserves: AF, DE
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

; ------------------------------------------
; Return the cell value at maze coordinate D,E.
; Out-of-range returns $FF so wall-outline selection treats the outside of the
; level as a boundary rather than as another wall.
; In: D=x, E=y
; Out: A=cell value or $FF outside
; Preserves: BC, DE
; Clobbers: AF, HL
Maze_GetCellValue:
    LD A, D
    CP Maze_Width
    JR NC, .outside
    LD A, E
    CP Maze_Height
    JR NC, .outside

    PUSH BC
    PUSH DE
    LD B, D

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

    LD D, 0
    LD E, B
    ADD HL, DE
    LD DE, Maze_Map
    ADD HL, DE
    LD A, (HL)

    POP DE
    POP BC
    RET
.outside:
    LD A, $FF
    RET

; Select one of 16 thin wall-boundary bitmap tiles from neighboring topology.
; Boundary-mask bits: 0 top, 1 right, 2 bottom, 3 left.
; A boundary is drawn whenever the neighboring coordinate is outside the map
; or is not a wall. This outlines walkable corridors and the outer maze edge.
;
; In: D=x wall cell, E=y wall cell
; Out: HL=wall sprite pointer
; Preserves: DE
; Clobbers: AF, BC, HL
Maze_SelectWallSprite:
    LD C, 0

    ; top
    LD A, E
    OR A
    JR Z, .top_boundary
    DEC E
    CALL Maze_GetCellValue
    INC E
    CP Maze_CellWall
    JR Z, .top_done
.top_boundary:
    SET 0, C
.top_done:

    ; right
    INC D
    CALL Maze_GetCellValue
    DEC D
    CP Maze_CellWall
    JR Z, .right_done
    SET 1, C
.right_done:

    ; bottom
    INC E
    CALL Maze_GetCellValue
    DEC E
    CP Maze_CellWall
    JR Z, .bottom_done
    SET 2, C
.bottom_done:

    ; left
    LD A, D
    OR A
    JR Z, .left_boundary
    DEC D
    CALL Maze_GetCellValue
    INC D
    CP Maze_CellWall
    JR Z, .left_done
.left_boundary:
    SET 3, C
.left_done:

    LD A, C
    ADD A, A
    LD L, A
    LD H, 0
    LD BC, Maze_WallSpriteTable
    ADD HL, BC

    PUSH DE
    LD E, (HL)
    INC HL
    LD D, (HL)
    EX DE, HL
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
    CALL Maze_SelectWallSprite
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
    CALL Maze_GetCellValue
    CP Maze_CellWall
    JR Z, .blocked
    CP $FF
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
