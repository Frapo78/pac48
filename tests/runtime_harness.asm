; ============================================================
; PAC48 headless runtime verification harness
; ============================================================
; This is a standalone test binary. It includes the real engine modules but
; bypasses ROM menu/input and drives state directly. SkoolKit trace.py runs it
; until TEST_STOP and snapinfo.py reads TEST_RESULT.

        ORG 32768
        JP Test_Start

        INCLUDE "../src/config.asm"
        INCLUDE "../src/memory.asm"
        INCLUDE "../src/video.asm"
        INCLUDE "../src/sprites.asm"
        INCLUDE "../src/generated/pac_shifted.asm"
        INCLUDE "../src/maze.asm"
        INCLUDE "../src/player.asm"
        INCLUDE "../src/render.asm"

TEST_STOP       EQU 50000
TEST_RESULT     EQU 65000
TEST_DETAIL     EQU 65001

Test_Y:         DB 0

; A = stable failure code.
Test_Fail:
        LD (TEST_RESULT), A
        JP TEST_STOP

Test_Start:
        DI
        LD SP, 64000
        LD A, 255
        LD (TEST_RESULT), A
        XOR A
        LD (TEST_DETAIL), A

; ------------------------------------------------------------
; Video scanline LUT: execute the real initializer and verify several
; discontinuity/boundary addresses in the Spectrum bitmap layout.
; ------------------------------------------------------------
        CALL Video_InitLineTable

        LD HL, (Video_LineAddrTable)
        LD DE, $4000
        OR A
        SBC HL, DE
        LD A, 1
        JP NZ, Test_Fail

        LD HL, (Video_LineAddrTable + 2)
        LD DE, $4100
        OR A
        SBC HL, DE
        LD A, 2
        JP NZ, Test_Fail

        LD HL, (Video_LineAddrTable + 14)
        LD DE, $4700
        OR A
        SBC HL, DE
        LD A, 3
        JP NZ, Test_Fail

        LD HL, (Video_LineAddrTable + 16)
        LD DE, $4020
        OR A
        SBC HL, DE
        LD A, 4
        JP NZ, Test_Fail

        LD HL, (Video_LineAddrTable + 382)
        LD DE, $57E0
        OR A
        SBC HL, DE
        LD A, 5
        JP NZ, Test_Fail

; ------------------------------------------------------------
; Register contract and attribute address check for Video_DrawTile.
; ------------------------------------------------------------
        LD D, 5
        LD E, 6
        LD A, $47
        CALL Video_DrawTile

        LD A, D
        CP 5
        LD A, 10
        JP NZ, Test_Fail
        LD A, E
        CP 6
        LD A, 11
        JP NZ, Test_Fail

        LD HL, ATTR_ADDR + 6*32 + 5
        LD A, (HL)
        CP $47
        LD A, 12
        JP NZ, Test_Fail

; ------------------------------------------------------------
; Maze collision sanity using the real Maze_Map.
; ------------------------------------------------------------
        LD D, 1
        LD E, 1
        CALL Maze_CanMove
        CP 1
        LD A, 20
        JP NZ, Test_Fail

        LD D, 0
        LD E, 0
        CALL Maze_CanMove
        OR A
        LD A, 21
        JP NZ, Test_Fail

; ------------------------------------------------------------
; Player: blocked turn must not move or change persistent facing.
; ------------------------------------------------------------
        LD A, 24
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        LD A, 1
        LD (Pac_X), A
        LD (Pac_Y), A
        XOR A
        LD (Pac_Dir), A
        LD A, 1                         ; request up into row-0 wall
        LD (Pac_ReqDir), A
        LD A, 3                         ; preserve left-facing visual state
        LD (Pac_FacingDir), A
        CALL Player_Update

        LD A, (Pac_PixelX)
        CP 24
        LD A, 30
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 24
        LD A, 31
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        OR A
        LD A, 32
        JP NZ, Test_Fail
        LD A, (Pac_FacingDir)
        CP 3
        LD A, 33
        JP NZ, Test_Fail

; Legal right request must start movement by one pixel and update facing.
        LD A, 4
        LD (Pac_ReqDir), A
        CALL Player_Update
        LD A, (Pac_PixelX)
        CP 25
        LD A, 34
        JP NZ, Test_Fail
        LD A, (Pac_PixelY)
        CP 24
        LD A, 35
        JP NZ, Test_Fail
        LD A, (Pac_Dir)
        CP 4
        LD A, 36
        JP NZ, Test_Fail
        LD A, (Pac_FacingDir)
        CP 4
        LD A, 37
        JP NZ, Test_Fail

; ------------------------------------------------------------
; Render_Prepare dirty-cell coverage using the real Z80 routines.
; ------------------------------------------------------------
        CALL Render_Init
        XOR A
        LD (FrameCounter), A
        LD A, 4
        LD (Pac_FacingDir), A

        LD A, 24
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        CALL Render_Prepare
        LD A, (Render_PlayerPhase)
        OR A
        LD A, 40
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCount)
        CP 1
        LD A, 41
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells)
        CP 1
        LD A, 42
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 1)
        CP 1
        LD A, 43
        JP NZ, Test_Fail

        LD A, 25
        LD (Pac_PixelX), A
        LD A, 24
        LD (Pac_PixelY), A
        CALL Render_Prepare
        LD A, (Render_PlayerPhase)
        CP 1
        LD A, 44
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCount)
        CP 2
        LD A, 45
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 2)
        CP 2
        LD A, 46
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 3)
        CP 1
        LD A, 47
        JP NZ, Test_Fail

        LD A, 25
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        CALL Render_Prepare
        LD A, (Render_NextDirtyCount)
        CP 4
        LD A, 48
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 4)
        CP 1
        LD A, 49
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 5)
        CP 2
        LD A, 50
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 6)
        CP 2
        LD A, 51
        JP NZ, Test_Fail
        LD A, (Render_NextDirtyCells + 7)
        CP 2
        LD A, 52
        JP NZ, Test_Fail

; ------------------------------------------------------------
; Actual masked Z80 renderer: test phase 3 against known background bytes.
; Pac_Frame0 first row is $3C. At phase 3 the generated image is $07,$80,
; mask $F8,$7F. Background $AA,$55 must become $AF,$D5.
; ------------------------------------------------------------
        LD A, 24
        CALL Video_GetLineAddress
        LD BC, 3
        ADD HL, BC
        LD (HL), $AA
        INC HL
        LD (HL), $55

        LD HL, ATTR_ADDR + 3*32 + 3
        LD (HL), $46

        LD D, 27                       ; x=24+3 => phase 3, byte column 3
        LD E, 24
        LD HL, Pac_Shifted_Right_F0_P3
        CALL Render_DrawMasked8x8

        LD A, 24
        CALL Video_GetLineAddress
        LD BC, 3
        ADD HL, BC
        LD A, (HL)
        CP $AF
        LD A, 60
        JP NZ, Test_Fail
        INC HL
        LD A, (HL)
        CP $D5
        LD A, 61
        JP NZ, Test_Fail

        LD HL, ATTR_ADDR + 3*32 + 3
        LD A, (HL)
        CP $46
        LD A, 62
        JP NZ, Test_Fail

; ------------------------------------------------------------
; Dirty restoration end-to-end: draw Pac on maze cell (1,1), jump it away,
; commit again, then verify the old cell bitmap is restored to Sprite_Pellet.
; ------------------------------------------------------------
        CALL Video_Clear
        CALL Video_InitLineTable
        CALL Maze_Draw
        CALL Render_Init
        XOR A
        LD (FrameCounter), A
        LD A, 4
        LD (Pac_FacingDir), A
        LD A, 24
        LD (Pac_PixelX), A
        LD (Pac_PixelY), A
        CALL Render_Prepare
        CALL Render_Commit

        LD A, 40                       ; screen cell 5 => maze x=3
        LD (Pac_PixelX), A
        LD A, 24
        LD (Pac_PixelY), A
        CALL Render_Prepare
        CALL Render_Commit

        LD DE, Sprite_Pellet
        LD A, 24
        LD (Test_Y), A
        LD B, 8
.check_pellet_row:
        LD A, (Test_Y)
        CALL Video_GetLineAddress
        LD A, L
        ADD A, 3                       ; old player cell screen byte x=3
        LD L, A
        JR NC, .pellet_addr_ok
        INC H
.pellet_addr_ok:
        LD A, (DE)
        LD C, A
        LD A, (HL)
        CP C
        LD A, 70
        JP NZ, Test_Fail
        INC DE
        LD A, (Test_Y)
        INC A
        LD (Test_Y), A
        DJNZ .check_pellet_row

; All headless runtime checks passed.
        XOR A
        LD (TEST_RESULT), A
        JP TEST_STOP

        END
