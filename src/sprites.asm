; =========================
; SPRITES E DATI GRAFICI
; =========================

; Sprite muro: blocco pieno con bordo morbido
Sprite_Wall:
    DEFB %11111111
    DEFB %11111111
    DEFB %11100111
    DEFB %11000011
    DEFB %11000011
    DEFB %11100111
    DEFB %11111111
    DEFB %11111111

; Sprite pallino: dot centrale minimale
Sprite_Pellet:
    DEFB %00000000
    DEFB %00011000
    DEFB %00111100
    DEFB %00111100
    DEFB %00111100
    DEFB %00011000
    DEFB %00000000
    DEFB %00000000

; Fotogrammi Pac-Man: animazione apertura bocca (destra)
Pac_Frame0:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111110
    DEFB %11111110
    DEFB %11111110
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_Frame1:
    DEFB %00111100
    DEFB %01111100
    DEFB %11111100
    DEFB %11111000
    DEFB %11111100
    DEFB %01111100
    DEFB %00111100
    DEFB %00000000

Pac_Frame2:
    DEFB %00111100
    DEFB %01111100
    DEFB %11111000
    DEFB %11110000
    DEFB %11111000
    DEFB %01111100
    DEFB %00111100
    DEFB %00000000

Pac_Frame3:
    DEFB %00111000
    DEFB %01111000
    DEFB %11110000
    DEFB %11100000
    DEFB %11110000
    DEFB %01111000
    DEFB %00111000
    DEFB %00000000

Pac_Frame4:
    DEFB %00110000
    DEFB %01110000
    DEFB %11100000
    DEFB %11100000
    DEFB %11100000
    DEFB %01110000
    DEFB %00110000
    DEFB %00000000

Pac_FrameTable:
    DW Pac_Frame0, Pac_Frame1, Pac_Frame2, Pac_Frame3, Pac_Frame4, Pac_Frame3, Pac_Frame2, Pac_Frame1
