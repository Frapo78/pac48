; ==========================================
; PAC48 - render.asm
; Frame composition and masked actor drawing
; ==========================================
;
; Architecture:
;   Render_Prepare runs outside the time-critical screen commit.
;   Render_Commit restores previous dirty maze cells, draws the prepared
;   player descriptor, then promotes the new dirty list for the next frame.
;
; Moving actors never write attributes here. Maze attributes remain owned by
; maze/video code.

RENDER_DIRTY_MAX EQU 24

Render_AnimMap:
    DB 0,1,2,3,4,3,2,1

; ------------------------------------------
; Reset renderer state. Call once after the initial maze draw.
Render_Init:
    XOR A
    LD (Render_DirtyCount), A
    LD (Render_NextDirtyCount), A
    RET

; ------------------------------------------
; Prepare one frame without touching screen RAM.
; Currently prepares the player; enemies can later use the same descriptor
; and dirty-cell model.
Render_Prepare:
    XOR A
    LD (Render_NextDirtyCount), A

    LD A, (Pac_PixelX)
    LD (Render_PlayerX), A
    AND 7
    LD (Render_PlayerPhase), A

    LD A, (Pac_PixelY)
    LD (Render_PlayerY), A

    CALL Render_SelectPlayerSprite
    CALL Render_CollectPlayerDirty
    RET

; Select generated sprite pointer from direction, animation frame, and x phase.
Render_SelectPlayerSprite:
    CALL Render_SelectDirectionTable       ; DE = table base
    PUSH DE

    LD A, (FrameCounter)
    SRL A
    SRL A
    SRL A
    AND 7
    LD L, A
    LD H, 0
    LD DE, Render_AnimMap
    ADD HL, DE
    LD A, (HL)                             ; 0..4 canonical frame

    ADD A, A                               ; frame * 8
    ADD A, A
    ADD A, A
    LD B, A
    LD A, (Render_PlayerPhase)
    ADD A, B                               ; frame*8 + phase = 0..39
    ADD A, A                               ; word offset
    LD L, A
    LD H, 0

    POP DE
    ADD HL, DE
    LD E, (HL)
    INC HL
    LD D, (HL)
    EX DE, HL
    LD (Render_PlayerSprite), HL
    RET

; Out: DE = base of 5-frame x 8-phase pointer table.
Render_SelectDirectionTable:
    LD A, (Pac_Dir)
    CP 1
    JR Z, .up
    CP 2
    JR Z, .down
    CP 3
    JR Z, .left
    LD DE, Pac_ShiftedTableRight
    RET
.up:
    LD DE, Pac_ShiftedTableUp
    RET
.down:
    LD DE, Pac_ShiftedTableDown
    RET
.left:
    LD DE, Pac_ShiftedTableLeft
    RET

; ------------------------------------------
; Record the maze cells touched by the prepared 8x8 player sprite.
; An arbitrary 8x8 pixel sprite touches at most four 8x8 maze cells.
Render_CollectPlayerDirty:
    LD A, (Render_PlayerX)
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetX
    LD (Render_TileX), A

    LD A, (Render_PlayerY)
    SRL A
    SRL A
    SRL A
    SUB Maze_OffsetY
    LD (Render_TileY), A

    LD A, (Render_PlayerX)
    AND 7
    LD (Render_CrossX), A

    LD A, (Render_PlayerY)
    AND 7
    LD (Render_CrossY), A

    ; top-left
    LD A, (Render_TileX)
    LD D, A
    LD A, (Render_TileY)
    LD E, A
    CALL Render_AddNextDirtyCell

    ; top-right when horizontally crossing a cell boundary
    LD A, (Render_CrossX)
    OR A
    JR Z, .no_top_right
    LD A, (Render_TileX)
    INC A
    LD D, A
    LD A, (Render_TileY)
    LD E, A
    CALL Render_AddNextDirtyCell
.no_top_right:

    ; no bottom row unless vertically crossing a cell boundary
    LD A, (Render_CrossY)
    OR A
    RET Z

    LD A, (Render_TileX)
    LD D, A
    LD A, (Render_TileY)
    INC A
    LD E, A
    CALL Render_AddNextDirtyCell

    LD A, (Render_CrossX)
    OR A
    RET Z
    LD A, (Render_TileX)
    INC A
    LD D, A
    LD A, (Render_TileY)
    INC A
    LD E, A
    JP Render_AddNextDirtyCell

; In: D=x, E=y maze coordinates.
; Adds a unique valid cell to the next-frame dirty list.
Render_AddNextDirtyCell:
    LD A, D
    CP Maze_Width
    RET NC
    LD A, E
    CP Maze_Height
    RET NC

    LD A, (Render_NextDirtyCount)
    LD B, A
    LD HL, Render_NextDirtyCells
.scan:
    LD A, B
    OR A
    JR Z, .add

    LD A, (HL)
    CP D
    JR NZ, .next_pair
    INC HL
    LD A, (HL)
    CP E
    JR Z, .exists
    DEC HL
.next_pair:
    INC HL
    INC HL
    DJNZ .scan

.add:
    LD A, (Render_NextDirtyCount)
    CP RENDER_DIRTY_MAX
    RET NC
    LD L, A
    LD H, 0
    ADD HL, HL
    LD BC, Render_NextDirtyCells
    ADD HL, BC
    LD (HL), D
    INC HL
    LD (HL), E
    LD HL, Render_NextDirtyCount
    INC (HL)
.exists:
    RET

; ------------------------------------------
; Time-critical display phase.
; Restores background touched by the previously displayed actors, draws the
; already prepared player, and records this frame's dirty cells for next time.
Render_Commit:
    CALL Render_RestoreDirty
    CALL Render_DrawPlayer
    CALL Render_PromoteDirty
    RET

Render_RestoreDirty:
    LD A, (Render_DirtyCount)
    OR A
    RET Z
    LD B, A
    LD HL, Render_DirtyCells
.loop:
    LD D, (HL)
    INC HL
    LD E, (HL)
    INC HL
    PUSH HL
    PUSH BC
    CALL Maze_DrawCell
    POP BC
    POP HL
    DJNZ .loop
    RET

Render_PromoteDirty:
    LD A, (Render_NextDirtyCount)
    LD (Render_DirtyCount), A
    OR A
    JR Z, .clear_next

    ADD A, A
    LD C, A
    LD B, 0
    LD HL, Render_NextDirtyCells
    LD DE, Render_DirtyCells
    LDIR

.clear_next:
    XOR A
    LD (Render_NextDirtyCount), A
    RET

Render_DrawPlayer:
    LD HL, (Render_PlayerSprite)
    LD A, (Render_PlayerX)
    LD D, A
    LD A, (Render_PlayerY)
    LD E, A
    JP Render_DrawMasked8x8

; ------------------------------------------
; Draw one generated masked 8x8 sprite at arbitrary pixel coordinates.
;
; In:
;   D = x pixel (must keep x/8 <= 30; maze invariants guarantee this)
;   E = y pixel (must keep y <= 184; maze invariants guarantee this)
;   HL = generated sprite data, 8 rows x 4 bytes:
;        maskL,imageL,maskR,imageR
;
; Formula per screen byte:
;   new = (old AND mask) OR image
;
; Clobbers: AF, BC, DE, HL.
Render_DrawMasked8x8:
    LD A, D
    SRL A
    SRL A
    SRL A
    LD (Render_DrawXByte), A

    LD A, E
    LD (Render_DrawY), A

    EX DE, HL                              ; DE = generated sprite pointer
    LD B, 8
.row:
    PUSH BC

    LD A, (Render_DrawY)
    CALL Video_GetLineAddress              ; HL = start of scanline, DE preserved
    LD A, (Render_DrawXByte)
    ADD A, L
    LD L, A
    JR NC, .address_ready
    INC H
.address_ready:

    ; left screen byte
    LD A, (DE)
    LD C, A                                ; maskL
    INC DE
    LD A, (HL)
    AND C
    LD C, A
    LD A, (DE)                             ; imageL
    OR C
    LD (HL), A
    INC DE
    INC HL

    ; right spill byte (phase 0 is a harmless mask=$FF/image=$00 no-op)
    LD A, (DE)
    LD C, A                                ; maskR
    INC DE
    LD A, (HL)
    AND C
    LD C, A
    LD A, (DE)                             ; imageR
    OR C
    LD (HL), A
    INC DE

    LD A, (Render_DrawY)
    INC A
    LD (Render_DrawY), A

    POP BC
    DJNZ .row
    RET
