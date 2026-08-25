; ==========================================
; PAC48 - hud.asm
; Startup-only version/build stamp
; ==========================================
;
; Uses the ZX Spectrum ROM 8x8 system font. Printable glyph data starts at
; $3D00 for ASCII 32; $3C00 is the CHARS-style base only when the full ASCII
; code is used as the offset. We subtract 32 below, so $3D00 is authoritative.
; The maze begins at character row 2, so row 0 is reserved for build identity.

ROM_FONT_ADDR   EQU $3D00
HUD_Attr        EQU 64 | COLOR_WHITE      ; BRIGHT white INK on black PAPER
HUD_LabelRow    EQU 0

HUD_CursorCell: DB 0

; Draw generated label, e.g. "V0.3.7 B1A2B3C", centered in character cells.
HUD_DrawBuildStamp:
    LD A, Build_ScreenLabelColumn
    LD (HUD_CursorCell), A
    LD HL, Build_ScreenLabel
.next_char:
    LD A, (HL)
    OR A
    RET Z

    PUSH HL
    CALL HUD_GetRomGlyph

    LD A, (HUD_CursorCell)
    LD D, A
    LD E, HUD_LabelRow
    LD A, HUD_Attr
    CALL Video_DrawSprite

    POP HL
    INC HL
    LD A, (HUD_CursorCell)
    INC A
    LD (HUD_CursorCell), A
    JR .next_char

; In: A = printable ASCII 32..127
; Out: HL = 8-byte ROM glyph pointer.
HUD_GetRomGlyph:
    SUB 32
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD DE, ROM_FONT_ADDR
    ADD HL, DE
    RET
