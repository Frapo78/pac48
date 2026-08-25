; ==========================================
; PAC48 - video.asm
; Low-level ZX Spectrum screen primitives
; ==========================================

Video_Clear:
    ; azzera bitmap (6144 byte)
    LD HL, SCREEN_ADDR
    LD DE, SCREEN_ADDR + 1
    LD BC, 6144 - 1
    XOR A
    LD (HL), A
    LDIR

    ; azzera attributi (768 byte)
    LD HL, ATTR_ADDR
    LD DE, ATTR_ADDR + 1
    LD BC, 768 - 1
    LD (HL), A
    LDIR

    ; imposta bordo nero
    OUT (PORT_ULA), A
    RET

Video_BeginFrame:
    LD HL, FrameCounter
    INC (HL)
    RET

Video_EndFrame:
    RET

; ------------------------------------------
; Build a 192-entry lookup table of Spectrum bitmap scanline addresses.
; Call once during startup before Render_Commit is used.
Video_InitLineTable:
    LD DE, Video_LineAddrTable
    LD C, 0
.loop:
    LD A, C
    PUSH BC
    PUSH DE
    CALL Video_CalcLineAddress
    POP DE

    LD A, L
    LD (DE), A
    INC DE
    LD A, H
    LD (DE), A
    INC DE

    POP BC
    INC C
    LD A, C
    CP 192
    JR NZ, .loop
    RET

; In: A=y pixel 0..191
; Out: HL=address of byte 0 for that Spectrum bitmap scanline
; Clobbers: AF, B, HL
Video_CalcLineAddress:
    LD B, A

    ; $4000 + ((y & $C0) << 5) + ((y & 7) << 8) + ((y & $38) << 2)
    AND $C0
    RRCA
    RRCA
    RRCA
    ADD A, SCREEN_ADDR / 256
    LD H, A

    LD A, B
    AND 7
    ADD A, H
    LD H, A

    LD A, B
    AND $38
    ADD A, A
    ADD A, A
    LD L, A
    RET

; In: A=y pixel 0..191
; Out: HL=address of byte 0 for the scanline
; Preserves: DE (important for masked sprite source pointer)
; Clobbers: AF, HL
Video_GetLineAddress:
    PUSH DE
    LD L, A
    LD H, 0
    ADD HL, HL
    LD DE, Video_LineAddrTable
    ADD HL, DE
    LD E, (HL)
    INC HL
    LD D, (HL)
    EX DE, HL
    POP DE
    RET

; ------------------------------------------
; Draw an 8x8 cell-aligned bitmap and its attribute.
; Used for persistent maze/background rendering, not moving actors.
;
; In: D=x cell, E=y cell, HL=sprite pointer, A=attribute
; Preserves caller DE.
Video_DrawSprite:
    PUSH AF
    PUSH DE
    PUSH HL
    LD C, D
    LD B, E

    ; base bitmap for aligned 8x8 tile:
    ; $4000 + (y&24)*256 + (y&7)*32 + x
    LD A, B
    AND 7
    LD H, 0
    LD L, A
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL

    LD A, B
    AND 24
    LD H, A
    LD A, H
    ADD A, SCREEN_ADDR / 256
    LD H, A

    LD A, L
    ADD A, C
    LD L, A

    POP DE                  ; DE -> sprite source
    LD B, 8
.line_loop:
    LD A, (DE)
    LD (HL), A
    INC DE
    INC H
    DJNZ .line_loop

    POP DE                  ; original cell coordinates
    POP AF                  ; attribute
    CALL Video_DrawTile
    RET

; ------------------------------------------
; Write one Spectrum attribute cell.
;
; In: D=x cell, E=y cell, A=attribute
; Preserves: DE
; Clobbers: AF, B, HL
Video_DrawTile:
    PUSH DE
    LD B, A

    ; offset = y*32 + x
    LD A, E
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL

    LD A, D
    LD E, A
    LD D, 0
    ADD HL, DE

    LD DE, ATTR_ADDR
    ADD HL, DE
    LD (HL), B

    POP DE
    RET
