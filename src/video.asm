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
; Disegna sprite 8x8 allineato a cella
; In: D=x, E=y, HL=sprite ptr, A=attr
Video_DrawSprite:
    PUSH AF                 ; salva attr
    PUSH DE                 ; salva coordinate mappa
    LD C, D                 ; conserva x per offset
    LD IX, HL               ; IX -> sprite

    ; calcola indirizzo base (riga 0 della cella)
    LD A, E
    AND 7
    LD H, 0
    LD L, A
    ADD HL, HL              ; *2
    ADD HL, HL              ; *4
    ADD HL, HL              ; *8
    ADD HL, HL              ; *16
    ADD HL, HL              ; *32
    ADD HL, HL              ; *64

    LD A, E
    AND 24
    LD D, A
    LD E, 0
    ADD HL, DE              ; + (y&24)*256

    LD DE, SCREEN_ADDR
    ADD HL, DE              ; HL = base bitmap

    ; aggiunge x
    LD A, C
    LD E, A
    LD D, 0
    ADD HL, DE

    LD B, 8                 ; 8 righe
.line_loop:
    LD A, (IX+0)
    LD (HL), A
    INC IX
    LD DE, 32
    ADD HL, DE
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
