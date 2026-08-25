; ============================================================
; PAC48 headless control-feel verification harness
; ============================================================
; Tests pure joystick-direction selection and immediate safe reversal using
; the real Z80 input/player routines without depending on physical ports.

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

; Holding only the current direction must not overwrite an already queued turn.
        LD A, 4
        LD (Pac_Dir), A
        LD A, 2
        LD (Pac_ReqDir), A
        LD A, INPUT_MASK_RIGHT
        CALL Input_SelectFromMask
        OR A
        LD A, 3
        JP NZ, Test_Fail
        LD A, (Pac_ReqDir)
        CP 2
        LD A, 4
        JP NZ, Test_Fail

; Symmetric vertical case: up+left while moving up requests LEFT.
        LD A, 1
        LD (Pac_Dir), A
        LD A, INPUT_MASK_UP + INPUT_MASK_LEFT
        CALL Input_SelectFromMask
        CP 3
        LD A, 5
        JP NZ, Test_Fail

; Opposite cardinal direction remains a valid request.
        LD A, 4
        LD (Pac_Dir), A
        LD A, INPUT_MASK_LEFT
        CALL Input_SelectFromMask
        CP 3
        LD A, 6
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
        LD A, 7
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 24
        LD A, 8
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        CP 3
        LD A, 9
        JP NZ, Test_Fail
        LD A, (Pac_FacingDir)
        CP 3
        LD A, 10
        JP NZ, Test_Fail

        XOR A
        LD (TEST_RESULT), A
        JP TEST_STOP

        END
