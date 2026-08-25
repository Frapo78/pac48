; ==========================================
; PAC48 - player.asm
; Player simulation only; no direct screen writes
; ==========================================

Player_Update:
    CALL Player_TryRequestedDir

    LD A, (Pac_Dir)
    OR A
    RET Z

    ; Functional centre tunnel: wrapping is a movement event of its own frame.
    ; It happens before normal edge collision because leaving x=0/27 is legal
    ; only on Maze_TunnelRow.
    CALL Player_TryTunnelWarp
    OR A
    RET NZ

    ; Validate the leading edge of the full 8x8 actor for every pixel step.
    CALL Player_CanContinue
    OR A
    JR NZ, .move

    ; If the preferred queued turn is blocked at a dead end, do not freeze Pac
    ; while another physically-held direction is legal. The common case is a
    ; diagonal joystick state where the perpendicular turn is blocked but the
    ; opposite direction is held and should reverse immediately.
    CALL Player_TryHeldReversal
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

; ------------------------------------------------------------
; Requested-turn model.
;
; 180-degree reversals remain immediate. Perpendicular requests no longer wait
; for exact x%8==0/y%8==0: when Pac is within Pac_TurnWindow pixels of the
; nearest logical node, a legal branch can snap the travel axis to that node
; and turn in the same frame. This implements a compact Spectrum-friendly
; approximation of arcade pre-turn/post-turn cornering and guarantees the new
; corridor starts perfectly centred.
Player_TryRequestedDir:
    LD A, (Pac_ReqDir)
    OR A
    RET Z
    LD B, A

    LD A, (Pac_Dir)
    OR A
    JR Z, .stopped
    CP B
    RET Z

    ADD A, B
    CP 3                           ; up + down
    JR Z, .reverse_now
    CP 7                           ; left + right
    JR Z, .reverse_now

    ; Remaining combinations are perpendicular turns.
    CALL Player_TryCornerTurn
    RET

.stopped:
    ; A stationary actor should normally be exactly on a node. Keep this path
    ; strict so a corrupted/off-grid stopped state cannot teleport diagonally.
    CALL Player_IsAligned
    OR A
    RET Z
    LD A, B
    CALL Player_LoadNextTileForDir
    CALL Maze_CanMove
    OR A
    RET Z
    LD A, B
    LD (Pac_Dir), A
    LD (Pac_FacingDir), A
    RET

.reverse_now:
    LD A, B
    LD (Pac_Dir), A
    LD (Pac_FacingDir), A
    RET

; Try a perpendicular turn near the closest 8-pixel node.
; In: B=requested direction.
; Out: A=1 when applied, A=0 otherwise.
Player_TryCornerTurn:
    LD A, (Pac_Dir)
    CP 3
    JR Z, .from_horizontal
    CP 4
    JR Z, .from_horizontal
    CP 1
    JR Z, .from_vertical
    CP 2
    JR Z, .from_vertical
    XOR A
    RET

.from_horizontal:
    LD A, B
    CP 1
    JR Z, .snap_x
    CP 2
    JR Z, .snap_x
    XOR A
    RET

.snap_x:
    LD A, (Pac_PixelX)
    LD C, A                        ; original x for rollback
    CALL Player_FindNearestNode
    JR NC, .no_turn
    LD (Pac_PixelX), A

    LD A, B
    CALL Player_LoadNextTileForDir
    CALL Maze_CanMove
    OR A
    JR Z, .restore_x

    CALL Player_ApplyCornerDir
    LD A, 1
    RET

.restore_x:
    LD A, C
    LD (Pac_PixelX), A
.no_turn:
    XOR A
    RET

.from_vertical:
    LD A, B
    CP 3
    JR Z, .snap_y
    CP 4
    JR Z, .snap_y
    XOR A
    RET

.snap_y:
    LD A, (Pac_PixelY)
    LD C, A                        ; original y for rollback
    CALL Player_FindNearestNode
    JR NC, .no_turn
    LD (Pac_PixelY), A

    LD A, B
    CALL Player_LoadNextTileForDir
    CALL Maze_CanMove
    OR A
    JR Z, .restore_y

    CALL Player_ApplyCornerDir
    LD A, 1
    RET

.restore_y:
    LD A, C
    LD (Pac_PixelY), A
    XOR A
    RET

; Apply a successful corner after its travel axis has been snapped to a node.
; In: B=requested direction.
Player_ApplyCornerDir:
    LD A, B
    LD (Pac_Dir), A
    LD (Pac_ReqDir), A
    LD (Pac_FacingDir), A
    CALL Player_SyncTile
    CALL Player_ConsumeCurrentPellet
    RET

; In: A=pixel coordinate on the current travel axis.
; Out: carry set and A=nearest 8-pixel node when distance <= Pac_TurnWindow;
;      carry clear when exactly midway/outside the permitted turn window.
; Preserves: BC.
Player_FindNearestNode:
    LD D, A
    AND 7
    JR Z, .aligned

    CP Pac_TurnWindow + 1          ; remainders 1..3 -> previous node
    JR C, .lower
    CP 8 - Pac_TurnWindow          ; remainders 5..7 -> next node
    JR NC, .upper

    OR A                           ; clear carry (remainder 4 with window=3)
    RET

.lower:
    LD A, D
    AND $F8
    SCF
    RET
.upper:
    LD A, D
    AND $F8
    ADD A, 8
    SCF
    RET
.aligned:
    LD A, D
    SCF
    RET

; ------------------------------------------------------------
; Functional centre tunnel wrap.
; Out: A=1 when a wrap occurred, A=0 otherwise.
Player_TryTunnelWarp:
    LD A, (Pac_PixelY)
    CP Maze_TunnelPixelY
    JR NZ, .none

    LD A, (Pac_Dir)
    CP 3
    JR Z, .left
    CP 4
    JR Z, .right
    JR .none

.left:
    LD A, (Pac_PixelX)
    CP Maze_TunnelLeftPixelX
    JR NZ, .none
    LD A, Maze_TunnelRightPixelX
    LD (Pac_PixelX), A
    JR .wrapped

.right:
    LD A, (Pac_PixelX)
    CP Maze_TunnelRightPixelX
    JR NZ, .none
    LD A, Maze_TunnelLeftPixelX
    LD (Pac_PixelX), A

.wrapped:
    CALL Player_SyncTile
    CALL Player_ConsumeCurrentPellet
    LD A, 1
    RET
.none:
    XOR A
    RET

; Out: A=1 when a held opposite direction was legal and selected, else 0.
; Called only after the current direction is known to be blocked.
Player_TryHeldReversal:
    LD A, (Pac_Dir)
    CP 1
    JR Z, .from_up
    CP 2
    JR Z, .from_down
    CP 3
    JR Z, .from_left
    CP 4
    JR Z, .from_right
    XOR A
    RET

.from_up:
    LD A, (Input_HeldMask)
    BIT 2, A                       ; DOWN
    JR Z, .none
    LD A, 2
    JR .apply
.from_down:
    LD A, (Input_HeldMask)
    BIT 3, A                       ; UP
    JR Z, .none
    LD A, 1
    JR .apply
.from_left:
    LD A, (Input_HeldMask)
    BIT 0, A                       ; RIGHT
    JR Z, .none
    LD A, 4
    JR .apply
.from_right:
    LD A, (Input_HeldMask)
    BIT 1, A                       ; LEFT
    JR Z, .none
    LD A, 3

.apply:
    LD (Pac_Dir), A
    LD (Pac_ReqDir), A
    LD (Pac_FacingDir), A
    CALL Player_CanContinue
    RET
.none:
    XOR A
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
