; ==========================================
; PAC48 - player.asm
; Player simulation only; no direct screen writes
; ==========================================

Player_Update:
    CALL Player_TryRequestedDir

    LD A, (Pac_Dir)
    OR A
    RET Z

    ; Validate the leading edge of the full 8x8 actor for every pixel step.
    ; This is deliberately stronger than the old "aligned node only" check:
    ; even if orthogonal alignment is ever disturbed, Pac cannot drift through
    ; a wall while travelling between tile centres.
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
    CALL Player_ConsumeCurrentPellet
.done:
    RET

; Requested perpendicular turns remain buffered until an aligned legal node.
; A 180-degree reversal is safe within the same corridor, so apply it
; immediately instead of waiting up to seven pixels for the next node.
Player_TryRequestedDir:
    LD A, (Pac_ReqDir)
    OR A
    RET Z
    LD B, A

    LD A, (Pac_Dir)
    OR A
    JR Z, .aligned_turn
    ADD A, B
    CP 3                           ; up + down
    JR Z, .reverse_now
    CP 7                           ; left + right
    JR Z, .reverse_now

.aligned_turn:
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
    LD (Pac_FacingDir), A
    RET

.reverse_now:
    LD A, B
    LD (Pac_Dir), A
    LD (Pac_FacingDir), A
    RET

; Out: A=1 when the next one-pixel step keeps the complete 8x8 player box in
; walkable maze cells, A=0 when the leading edge would enter a wall/outside.
;
; The two leading-edge corners are checked every frame. Normal cardinal
; movement keeps the orthogonal axis aligned, so both points usually hit the
; same tile; checking both makes collision robust against transient drift.
Player_CanContinue:
    LD A, (Pac_Dir)
    CP 1
    JR Z, .up
    CP 2
    JR Z, .down
    CP 3
    JR Z, .left
    CP 4
    JR Z, .right
    XOR A
    RET

.up:
    ; Candidate top edge after y-1: (x,y-1) and (x+7,y-1).
    LD A, (Pac_PixelX)
    LD D, A
    LD A, (Pac_PixelY)
    DEC A
    LD E, A
    CALL Player_PointCanMove
    OR A
    RET Z

    LD A, (Pac_PixelX)
    ADD A, 7
    LD D, A
    LD A, (Pac_PixelY)
    DEC A
    LD E, A
    JP Player_PointCanMove

.down:
    ; Candidate bottom edge after y+1 is current y+8.
    LD A, (Pac_PixelX)
    LD D, A
    LD A, (Pac_PixelY)
    ADD A, 8
    LD E, A
    CALL Player_PointCanMove
    OR A
    RET Z

    LD A, (Pac_PixelX)
    ADD A, 7
    LD D, A
    LD A, (Pac_PixelY)
    ADD A, 8
    LD E, A
    JP Player_PointCanMove

.left:
    ; Candidate left edge after x-1: (x-1,y) and (x-1,y+7).
    LD A, (Pac_PixelX)
    DEC A
    LD D, A
    LD A, (Pac_PixelY)
    LD E, A
    CALL Player_PointCanMove
    OR A
    RET Z

    LD A, (Pac_PixelX)
    DEC A
    LD D, A
    LD A, (Pac_PixelY)
    ADD A, 7
    LD E, A
    JP Player_PointCanMove

.right:
    ; Candidate right edge after x+1 is current x+8.
    LD A, (Pac_PixelX)
    ADD A, 8
    LD D, A
    LD A, (Pac_PixelY)
    LD E, A
    CALL Player_PointCanMove
    OR A
    RET Z

    LD A, (Pac_PixelX)
    ADD A, 8
    LD D, A
    LD A, (Pac_PixelY)
    ADD A, 7
    LD E, A
    JP Player_PointCanMove

; In: D/E = screen pixel coordinate.
; Out: A=1 walkable, A=0 wall/outside.
; Converts the sampled pixel to maze tile coordinates then delegates to the
; canonical maze collision source of truth.
Player_PointCanMove:
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
    JP Maze_CanMove

; In: A=dir. Out: D/E=tile candidate from the current anchor tile.
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

; Out: A=1 when Pac_PixelX and Pac_PixelY are both multiples of 8.
Player_IsAligned:
    LD A, (Pac_PixelX)
    AND 7
    RET NZ
    LD A, (Pac_PixelY)
    AND 7
    RET NZ
    LD A, 1
    RET

; Out: D=x tile map, E=y tile map using the actor anchor/top-left pixel.
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

; Out: D/E = maze tile containing the centre of the 8x8 player.
; Pellet pickup is centre-based so entering from left/right/up/down behaves
; symmetrically instead of depending on the top-left sprite anchor.
Player_LoadCenterTile:
    LD A, (Pac_PixelX)
    ADD A, 4
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetX
    LD D, A

    LD A, (Pac_PixelY)
    ADD A, 4
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetY
    LD E, A
    RET

; Consume the pellet under the player centre, if present.
; Out: A=1 when a pellet changed to empty, A=0 otherwise.
Player_ConsumeCurrentPellet:
    CALL Player_LoadCenterTile
    JP Pellet_ConsumeAt

Player_SyncTile:
    CALL Player_LoadTile
    LD A, D
    LD (Pac_X), A
    LD A, E
    LD (Pac_Y), A
    RET
