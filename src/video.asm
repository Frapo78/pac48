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
; Disegna sprite 8x8 a coordinate pixel.
; In: D=x pixel, E=y pixel, HL=sprite ptr, A=attr
Video_DrawSpritePx:
    PUSH AF
    PUSH DE
    PUSH HL
    LD C, D                 ; C = x pixel
    LD B, E                 ; B = y pixel

    ; HL = $4000 + ((y&$C0)<<5) + ((y&7)<<8) + ((y&$38)<<2) + x/8
    LD A, B
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

    LD A, C
    SRL A
    SRL A
    SRL A
    ADD A, L
    LD L, A

    LD A, C
    AND 7
    LD C, A                 ; C = shift 0..7

    POP DE                  ; DE -> sprite
    LD B, 8
.line_loop_px:
    LD A, C
    OR A
    JR Z, .aligned_px

    PUSH BC
    LD B, C
    LD A, (DE)
.shift_right:
    SRL A
    DJNZ .shift_right
    LD (HL), A
    POP BC

    PUSH BC
    LD A, 8
    SUB C
    LD B, A
    LD A, (DE)
.shift_left:
    SLA A
    DJNZ .shift_left
    INC L
    LD (HL), A
    DEC L
    POP BC
    JR .next_px

.aligned_px:
    LD A, (DE)
    LD (HL), A

.next_px:
    INC DE
    CALL Video_NextScanline
    DJNZ .line_loop_px

    POP DE                  ; coordinate pixel originali
    POP AF                  ; attr
    CALL Video_DrawTileForPixel
    RET

; Avanza HL alla scanline ZX Spectrum successiva.
Video_NextScanline:
    INC H
    LD A, H
    AND 7
    RET NZ
    LD A, L
    ADD A, 32
    LD L, A
    RET C
    LD A, H
    SUB 8
    LD H, A
    RET

; In: D=x pixel, E=y pixel, A=attr
Video_DrawTileForPixel:
    PUSH AF
    LD A, D
    SRL A
    SRL A
    SRL A
    LD D, A
    LD A, E
    SRL A
    SRL A
    SRL A
    LD E, A
    POP AF
    CALL Video_DrawTile
    RET

; ------------------------------------------
; Disegna sprite 8x8 allineato a cella
; In: D=x, E=y, HL=sprite ptr, A=attr
Video_DrawSprite:
    PUSH AF                 ; salva attr
    PUSH DE                 ; salva coordinate mappa
    PUSH HL                 ; salva sprite ptr
    LD C, D                 ; C = x cella
    LD B, E                 ; B = y cella

    ; base bitmap per tile 8x8:
    ; $4000 + (y&24)*256 + (y&7)*32 + x
    LD A, B
    AND 7
    LD H, 0
    LD L, A
    ADD HL, HL              ; *2
    ADD HL, HL              ; *4
    ADD HL, HL              ; *8
    ADD HL, HL              ; *16
    ADD HL, HL              ; *32

    LD A, B
    AND 24
    LD H, A
    LD A, H
    ADD A, SCREEN_ADDR / 256
    LD H, A

    ; aggiunge x
    LD A, L
    ADD A, C
    LD L, A

    POP DE                  ; DE -> sprite
    LD B, 8                 ; 8 righe
.line_loop:
    LD A, (DE)
    LD (HL), A
    INC DE
    INC H                   ; prossima scanline dentro la cella: +256
    DJNZ .line_loop

    POP DE                  ; ripristina coordinate
    POP AF                  ; attr
    CALL Video_DrawTile     ; scrive attributo
    RET

Video_DrawTile:
    ; D=x, E=y, A=attr
    LD B, A              ; salva attr

    ; offset = y*32 + x
    LD A, E
    LD L, A
    LD H, 0
    ADD HL, HL           ; *2
    ADD HL, HL           ; *4
    ADD HL, HL           ; *8
    ADD HL, HL           ; *16
    ADD HL, HL           ; *32

    LD A, D
    LD E, A
    LD D, 0
    ADD HL, DE           ; HL = offset

    LD DE, ATTR_ADDR
    ADD HL, DE           ; HL = indirizzo attributo

    LD (HL), B
    RET
