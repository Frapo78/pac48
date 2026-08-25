; =========================
; MAZE DATA & ROUTINES
; =========================

Maze_CellPellet EQU 0
Maze_CellWall   EQU 1
Maze_CellEmpty  EQU 2

; Maze_Width/Height/Offset live in config.asm so startup state, renderer and
; validators share one coordinate source of truth.

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
; Preserves: DE
; Important: the input attribute in A survives coordinate translation and is
; passed unchanged into Video_DrawSprite. AF may be clobbered by the callee.
Maze_DrawAtOffset:
    PUSH DE
    PUSH AF
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
; Preserves: DE
; Important: A survives coordinate translation into Video_DrawTile.
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
.bottom_boundary:
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
; Landscape adaptation of the original arcade Pac-Man topology.
;
; The arcade maze is 28x31 gameplay tiles. PAC48 deliberately keeps the same
; 28-tile width and 8x8 logical cells, but compresses the vertical structure to
; 20 rows for a 256x192 4:3 display. The retained sections preserve the classic
; upper blocks, central-house silhouette, symmetric lower routes and the
; below-centre Pac start area. Empty cells (2) reserve non-pellet central space.
;
; Row 09 is now the functional side tunnel: its left and right edge cells are
; linked by player wrap logic. The central eight wall cells remain reserved for
; the future ghost-house core.
;
; This is an independently encoded landscape adaptation, not arcade ROM data.
; Source/research rationale is documented in docs/PACMAN_REFERENCE.md.
;
; Legend: 0 pellet/walkable, 1 wall, 2 empty/walkable.
; 28x20 = 560 bytes.
Maze_Map:
    ; 00  ############################
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    ; 01  #............##............#
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; 02  #.####.#####.##.#####.####.#
    DEFB 1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1
    ; 03  #..........................#
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; 04  #.####.##.########.##.####.#
    DEFB 1,0,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,0,1
    ; 05  #......##....##....##......#
    DEFB 1,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0,0,1
    ; 06  ######.##### ## #####.######
    DEFB 1,1,1,1,1,1,0,1,1,1,1,1,2,1,1,2,1,1,1,1,1,0,1,1,1,1,1,1
    ; 07  ######.##          ##.######
    DEFB 1,1,1,1,1,1,0,1,1,2,2,2,2,2,2,2,2,2,2,1,1,0,1,1,1,1,1,1
    ; 08  ######.## ######## ##.######
    DEFB 1,1,1,1,1,1,0,1,1,2,1,1,1,1,1,1,1,1,2,1,1,0,1,1,1,1,1,1
    ; 09  .......   ########   .......   <- functional side tunnel
    DEFB 0,0,0,0,0,0,0,2,2,2,1,1,1,1,1,1,1,1,2,2,2,0,0,0,0,0,0,0
    ; 10  ######.## ######## ##.######
    DEFB 1,1,1,1,1,1,0,1,1,2,1,1,1,1,1,1,1,1,2,1,1,0,1,1,1,1,1,1
    ; 11  ######.##          ##.######
    DEFB 1,1,1,1,1,1,0,1,1,2,2,2,2,2,2,2,2,2,2,1,1,0,1,1,1,1,1,1
    ; 12  ######.## ######## ##.######
    DEFB 1,1,1,1,1,1,0,1,1,2,1,1,1,1,1,1,1,1,2,1,1,0,1,1,1,1,1,1
    ; 13  #............##............#
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; 14  #.####.#####.##.#####.####.#
    DEFB 1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1
    ; 15  #...##.......  .......##...#  <- Pac start x=13,y=15
    DEFB 1,0,0,0,1,1,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,1,1,0,0,0,1
    ; 16  ###.##.##.########.##.##.###
    DEFB 1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1
    ; 17  #......##....##....##......#
    DEFB 1,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0,0,1
    ; 18  #..........................#
    DEFB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    ; 19  ############################
    DEFB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
