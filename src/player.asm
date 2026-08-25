; ==========================================
; PAC48 - player.asm
; Player simulation only; no direct screen writes
; ==========================================

Player_Update:
    CALL Player_TryRequestedDir

    LD A, (Pac_Dir)
    OR A
    RET Z

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

; Prova a cambiare direzione solo quando il player e' allineato alla griglia.
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

; Out: A=1 se la direzione corrente puo' continuare, A=0 se bloccata.
; Fra due celle la mossa e' gia' stata validata; ai nodi ricontrolla il tile.
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

; Out: A=1 se Pac_PixelX e Pac_PixelY sono multipli di 8, altrimenti A=0.
Player_IsAligned:
    LD A, (Pac_PixelX)
    AND 7
    RET NZ
    LD A, (Pac_PixelY)
    AND 7
    RET NZ
    LD A, 1
    RET

; Out: D=x tile mappa, E=y tile mappa.
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
