; ============================================================
; PAC48 headless control-feel verification harness
; ============================================================
; Tests joystick-direction selection, immediate reversals, stale-turn cancel,
; dead-end diagonal fallback, arcade turn-window centering and centre tunnel
; wrap using the real Z80 input/player routines.

        ORG 32768
        JP Test_Start

        INCLUDE "../src/config.asm"
        INCLUDE "../src/memory.asm"
        INCLUDE "../src/input.asm"
        INCLUDE "../src/video.asm"
        INCLUDE "../src/sprites.asm"
        INCLUDE "../src/maze.asm"
        INCLUDE "../src/pellets.asm"
        INCLUDE "../src/player.asm"

TEST_STOP       EQU 50000
TEST_RESULT     EQU 65000

Test_Fail:
        LD (TEST_RESULT), A
        JP TEST_STOP

Test_Start:
        DI
        LD SP, 64000
        LD A, 255
        LD (TEST_RESULT), A

; Horizontal travel + down/right must request the perpendicular DOWN turn.
        LD A, 4
        LD (Pac_Dir), A
        LD A, INPUT_MASK_DOWN + INPUT_MASK_RIGHT
        CALL Input_SelectFromMask
        CP 2
        LD A, 1
        JP NZ, Test_Fail

; Vertical travel + down/right must request the perpendicular RIGHT turn.
        LD A, 2
        LD (Pac_Dir), A
        LD A, INPUT_MASK_DOWN + INPUT_MASK_RIGHT
        CALL Input_SelectFromMask
        CP 4
        LD A, 2
        JP NZ, Test_Fail

; Holding only the current direction must explicitly return that direction so
; the main loop replaces any stale queued turn.
        LD A, 4
        LD (Pac_Dir), A
        LD A, 2
        LD (Pac_ReqDir), A
        LD A, INPUT_MASK_RIGHT
        CALL Input_SelectFromMask
        CP 4
        LD A, 3
        JP NZ, Test_Fail

; Symmetric vertical case: up+left while moving up requests LEFT.
        LD A, 1
        LD (Pac_Dir), A
        LD A, INPUT_MASK_UP + INPUT_MASK_LEFT
        CALL Input_SelectFromMask
        CP 3
        LD A, 4
        JP NZ, Test_Fail

; Opposite cardinal direction remains a valid request.
        LD A, 4
        LD (Pac_Dir), A
        LD A, INPUT_MASK_LEFT
        CALL Input_SelectFromMask
        CP 3
        LD A, 5
        JP NZ, Test_Fail

; A 180-degree reversal is safe inside the current corridor and must happen
; immediately rather than waiting for the next 8-pixel node.
        LD A, 25
        LD (Pac_PixelX), A
        LD A, 24
        LD (Pac_PixelY), A
        LD A, 4
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD A, 3
        LD (Pac_ReqDir), A
        CALL Player_Update

        LD A, (Pac_PixelX)
        CP 24
        LD A, 6
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 24
        LD A, 7
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        CP 3
        LD A, 8
        JP NZ, Test_Fail
        LD A, (Pac_FacingDir)
        CP 3
        LD A, 9
        JP NZ, Test_Fail

; Regression from owner video, relocated to the equivalent topology in the
; landscape maze: at map cell (1,5), LEFT is a wall, DOWN is a wall, RIGHT is
; open. DOWN+RIGHT held while moving left must fall back to RIGHT immediately.
        LD A, 24                    ; screen pixel x for maze cell x=1
        LD (Pac_PixelX), A
        LD A, 56                    ; screen pixel y for maze cell y=5
        LD (Pac_PixelY), A
        CALL Player_SyncTile
        LD A, 3
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD A, 2
        LD (Pac_ReqDir), A
        LD A, INPUT_MASK_DOWN + INPUT_MASK_RIGHT
        LD (Input_HeldMask), A
        CALL Player_Update

        LD A, (Pac_Dir)
        CP 4
        LD A, 10
        JP NZ, Test_Fail
        LD A, (Pac_PixelX)
        CP 25
        LD A, 11
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 56
        LD A, 12
        JP NZ, Test_Fail
        LD A, (Pac_ReqDir)
        CP 4
        LD A, 13
        JP NZ, Test_Fail

; P48-031 pre-turn: node (6,3) is at screen x=64,y=40 and has a legal DOWN
; branch. Starting three pixels before it while moving RIGHT must snap x to 64,
; turn DOWN and advance vertically in the same frame.
        LD A, 61
        LD (Pac_PixelX), A
        LD A, 40
        LD (Pac_PixelY), A
        CALL Player_SyncTile
        LD A, 4
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD A, 2
        LD (Pac_ReqDir), A
        XOR A
        LD (Input_HeldMask), A
        CALL Player_Update

        LD A, (Pac_PixelX)
        CP 64
        LD A, 20
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 41
        LD A, 21
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        CP 2
        LD A, 22
        JP NZ, Test_Fail
        LD A, (Pac_FacingDir)
        CP 2
        LD A, 23
        JP NZ, Test_Fail

; P48-031 post-turn tolerance: two pixels beyond the same node must still be
; recoverable. The travel axis is recentered to x=64 before moving DOWN.
        LD A, 66
        LD (Pac_PixelX), A
        LD A, 40
        LD (Pac_PixelY), A
        CALL Player_SyncTile
        LD A, 4
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD A, 2
        LD (Pac_ReqDir), A
        CALL Player_Update

        LD A, (Pac_PixelX)
        CP 64
        LD A, 24
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 41
        LD A, 25
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        CP 2
        LD A, 26
        JP NZ, Test_Fail

; Midpoint four pixels away is intentionally outside the +/-3 turn window and
; must not snap prematurely.
        LD A, 60
        LD (Pac_PixelX), A
        LD A, 40
        LD (Pac_PixelY), A
        CALL Player_SyncTile
        LD A, 4
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD A, 2
        LD (Pac_ReqDir), A
        CALL Player_Update
        LD A, (Pac_PixelX)
        CP 61
        LD A, 27
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 40
        LD A, 28
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        CP 4
        LD A, 29
        JP NZ, Test_Fail

; P48-034 centre tunnel: leaving the left endpoint while travelling LEFT wraps
; to maze x=27 in one frame without entering an out-of-range map coordinate.
        LD A, Maze_TunnelLeftPixelX
        LD (Pac_PixelX), A
        LD A, Maze_TunnelPixelY
        LD (Pac_PixelY), A
        CALL Player_SyncTile
        LD A, 3
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD (Pac_ReqDir), A
        CALL Player_Update

        LD A, (Pac_PixelX)
        CP Maze_TunnelRightPixelX
        LD A, 30
        JP NZ, Test_Fail
        LD A, (Pac_X)
        CP Maze_TunnelRightX
        LD A, 31
        JP NZ, Test_Fail
        LD A, (Pac_Y)
        CP Maze_TunnelRow
        LD A, 32
        JP NZ, Test_Fail

; Symmetric right-to-left wrap.
        LD A, 4
        LD (Pac_Dir), A
        LD (Pac_FacingDir), A
        LD (Pac_ReqDir), A
        CALL Player_Update
        LD A, (Pac_PixelX)
        CP Maze_TunnelLeftPixelX
        LD A, 33
        JP NZ, Test_Fail
        LD A, (Pac_X)
        CP Maze_TunnelLeftX
        LD A, 34
        JP NZ, Test_Fail
        LD A, (Pac_Y)
        CP Maze_TunnelRow
        LD A, 35
        JP NZ, Test_Fail

        XOR A
        LD (TEST_RESULT), A
        JP TEST_STOP

        END
