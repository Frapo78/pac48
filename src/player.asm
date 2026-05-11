Pac_Attr        EQU 64 | (COLOR_BLACK << 3) | COLOR_YELLOW

Player_Update:
    CALL Player_TryRequestedDir

    LD A, (Pac_Dir)
    OR A
    RET Z                  ; nessuna direzione

    CALL Player_CanContinue
    OR A
    JR NZ, .move
    XOR A
    LD (Pac_Dir), A
    RET

.move:
    LD A, (Pac_Dir)
    CP 1
    JR NZ, .check_down
    LD HL, Pac_PixelY
    DEC (HL)
    JR .sync_tile
.check_down:
    CP 2
    JR NZ, .check_left
    LD HL, Pac_PixelY
    INC (HL)
    JR .sync_tile
.check_left:
    CP 3
    JR NZ, .check_right
    LD HL, Pac_PixelX
    DEC (HL)
    JR .sync_tile
.check_right:
    CP 4
    JR NZ, .done
    LD HL, Pac_PixelX
    INC (HL)

.sync_tile:
    CALL Player_SyncTile

.done:
    RET

; Prova a cambiare direzione solo quando Pac-Man e' allineato alla griglia.
Player_TryRequestedDir:
    LD A, (Pac_ReqDir)
    OR A
    RET Z
    CALL Player_IsAligned
    OR A
    RET Z
    LD A, (Pac_ReqDir)
    CALL Player_LoadNextTileForDir
    CALL Maze_CanMove
    OR A
    RET Z
    LD A, (Pac_ReqDir)
    LD (Pac_Dir), A
    RET

; Ritorna A=1 se la direzione corrente puo' continuare.
; Fra due celle la mossa e' gia' stata validata; ai nodi ricontrolla il tile successivo.
Player_CanContinue:
    CALL Player_IsAligned
    OR A
    JR Z, .ok
    LD A, (Pac_Dir)
    CALL Player_LoadNextTileForDir
    CALL Maze_CanMove
    OR A
    JR NZ, .ok
    XOR A
    RET
.ok:
    LD A, 1
    RET

; In: A=dir. Out: D/E=tile candidato dalla cella corrente.
Player_LoadNextTileForDir:
    PUSH AF
    CALL Player_LoadTile
    POP AF
    CP 1
    JR NZ, .down
    DEC E
    RET
.down:
    CP 2
    JR NZ, .left
    INC E
    RET
.left:
    CP 3
    JR NZ, .right
    DEC D
    RET
.right:
    CP 4
    RET NZ
    INC D
    RET

; Ritorna A=1 se Pac_PixelX e Pac_PixelY sono multipli di 8.
Player_IsAligned:
    LD A, (Pac_PixelX)
    AND 7
    RET NZ
    LD A, (Pac_PixelY)
    AND 7
    RET NZ
    LD A, 1
    RET

; Out: D=x tile mappa, E=y tile mappa
Player_LoadTile:
    LD A, (Pac_PixelX)
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetX
    LD D, A
    LD A, (Pac_PixelY)
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetY
    LD E, A
    RET

Player_SyncTile:
    CALL Player_LoadTile
    LD A, D
    LD (Pac_X), A
    LD A, E
    LD (Pac_Y), A
    RET

Player_Erase:
    LD A, (Pac_PixelX)
    SUB 8
    LD D, A
    LD A, (Pac_PixelY)
    SUB 8
    LD E, A
    CALL Player_RestoreBlock3x3
    RET

; In: D/E = top-left pixel of 3x3 tile restore area
Player_RestoreBlock3x3:
    CALL Player_RestoreRow3
    LD A, E
    ADD A, 8
    LD E, A
    CALL Player_RestoreRow3
    LD A, E
    ADD A, 8
    LD E, A
    CALL Player_RestoreRow3
    RET

; In: D/E = first pixel in row. Restores 3 adjacent tiles.
Player_RestoreRow3:
    PUSH DE
    CALL Player_RestoreCellAtPixel
    POP DE
    LD A, D
    ADD A, 8
    LD D, A
    PUSH DE
    CALL Player_RestoreCellAtPixel
    POP DE
    LD A, D
    ADD A, 8
    LD D, A
    CALL Player_RestoreCellAtPixel
    RET

; In: D=x pixel schermo, E=y pixel schermo
Player_RestoreCellAtPixel:
    LD A, D
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetX
    LD D, A
    LD A, E
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetY
    LD E, A
    CALL Maze_DrawCell
    RET

Player_Draw:
    LD A, (Pac_PixelX)
    LD D, A
    LD A, (Pac_PixelY)
    LD E, A

    PUSH DE                     ; conserva coordinate schermo

    LD A, (FrameCounter)
    SRL A
    SRL A
    SRL A
    AND 7
    LD C, A

    LD A, (Pac_Dir)
    CP 1
    JR Z, .table_up
    CP 2
    JR Z, .table_down
    CP 3
    JR Z, .table_left
    LD DE, Pac_FrameTableRight
    JR .table_selected
.table_up:
    LD DE, Pac_FrameTableUp
    JR .table_selected
.table_down:
    LD DE, Pac_FrameTableDown
    JR .table_selected
.table_left:
    LD DE, Pac_FrameTableLeft
.table_selected:
    LD A, C
    LD L, A
    LD H, 0
    ADD HL, HL                 ; word offset
    ADD HL, DE
    LD E, (HL)
    INC HL
    LD D, (HL)
    EX DE, HL                  ; HL -> sprite

    POP DE                     ; D=x, E=y
    LD A, Pac_Attr
    CALL Video_DrawSpritePx

    RET
