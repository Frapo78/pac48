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

    RET

Video_BeginFrame:
    RET

Video_EndFrame:
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
