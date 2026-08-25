; =========================
; SPRITES E DATI GRAFICI CANONICI
; =========================
;
; I frame Pac_* sono la sorgente editabile. tools/gen_shifted_sprites.py
; genera le tabelle masked/pre-shifted usate dal renderer; non aggiungere qui
; una seconda tabella runtime per gli attori mobili.

; Sprite vuoto: cancella un tile 8x8
Sprite_Empty:
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000

; ---------------------------------------------------------------------
; Wall boundary tiles.
;
; Wall cells use BLACK paper + bright BLUE ink. Instead of filling the whole
; attribute cell with blue, Maze_SelectWallSprite chooses one of these 16
; bitmap variants from the neighboring wall topology.
;
; Boundary-mask bits:
;   bit 0 = top edge
;   bit 1 = right edge
;   bit 2 = bottom edge
;   bit 3 = left edge
;
; This produces continuous thin maze outlines rather than solid 8x8 blocks.

Sprite_Wall_0:                 ; none
    DEFB $00,$00,$00,$00,$00,$00,$00,$00
Sprite_Wall_1:                 ; top
    DEFB $FF,$00,$00,$00,$00,$00,$00,$00
Sprite_Wall_2:                 ; right
    DEFB $01,$01,$01,$01,$01,$01,$01,$01
Sprite_Wall_3:                 ; top + right
    DEFB $FF,$01,$01,$01,$01,$01,$01,$01
Sprite_Wall_4:                 ; bottom
    DEFB $00,$00,$00,$00,$00,$00,$00,$FF
Sprite_Wall_5:                 ; top + bottom
    DEFB $FF,$00,$00,$00,$00,$00,$00,$FF
Sprite_Wall_6:                 ; right + bottom
    DEFB $01,$01,$01,$01,$01,$01,$01,$FF
Sprite_Wall_7:                 ; top + right + bottom
    DEFB $FF,$01,$01,$01,$01,$01,$01,$FF
Sprite_Wall_8:                 ; left
    DEFB $80,$80,$80,$80,$80,$80,$80,$80
Sprite_Wall_9:                 ; top + left
    DEFB $FF,$80,$80,$80,$80,$80,$80,$80
Sprite_Wall_10:                ; left + right
    DEFB $81,$81,$81,$81,$81,$81,$81,$81
Sprite_Wall_11:                ; top + left + right
    DEFB $FF,$81,$81,$81,$81,$81,$81,$81
Sprite_Wall_12:                ; left + bottom
    DEFB $80,$80,$80,$80,$80,$80,$80,$FF
Sprite_Wall_13:                ; top + left + bottom
    DEFB $FF,$80,$80,$80,$80,$80,$80,$FF
Sprite_Wall_14:                ; left + right + bottom
    DEFB $81,$81,$81,$81,$81,$81,$81,$FF
Sprite_Wall_15:                ; all four
    DEFB $FF,$81,$81,$81,$81,$81,$81,$FF

; Sprite pallino: piccolo dot 2x2, deliberatamente molto più piccolo di Pac.
Sprite_Pellet:
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00011000
    DEFB %00011000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000

; ---- Pac-Man destra -------------------------------------------------
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

; ---- Pac-Man sinistra -----------------------------------------------
Pac_FrameLeft0:
    DEFB %00111100
    DEFB %01111111
    DEFB %01111111
    DEFB %01111111
    DEFB %01111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameLeft1:
    DEFB %00111100
    DEFB %00111110
    DEFB %00111111
    DEFB %00011111
    DEFB %00111111
    DEFB %00111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameLeft2:
    DEFB %00111100
    DEFB %00111110
    DEFB %00011111
    DEFB %00001111
    DEFB %00011111
    DEFB %00111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameLeft3:
    DEFB %00011100
    DEFB %00011110
    DEFB %00001111
    DEFB %00000111
    DEFB %00001111
    DEFB %00011110
    DEFB %00011100
    DEFB %00000000

Pac_FrameLeft4:
    DEFB %00001100
    DEFB %00001110
    DEFB %00000111
    DEFB %00000111
    DEFB %00000111
    DEFB %00001110
    DEFB %00001100
    DEFB %00000000

; ---- Pac-Man su -----------------------------------------------------
Pac_FrameUp0:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameUp1:
    DEFB %00011000
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameUp2:
    DEFB %00000000
    DEFB %00100100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameUp3:
    DEFB %00000000
    DEFB %00000000
    DEFB %01000010
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameUp4:
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %10000001
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

; ---- Pac-Man giu ----------------------------------------------------
Pac_FrameDown0:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00000000

Pac_FrameDown1:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00111100
    DEFB %00011000
    DEFB %00000000

Pac_FrameDown2:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %01111110
    DEFB %00100100
    DEFB %00000000
    DEFB %00000000

Pac_FrameDown3:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %11111111
    DEFB %01000010
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000

Pac_FrameDown4:
    DEFB %00111100
    DEFB %01111110
    DEFB %11111111
    DEFB %10000001
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
    DEFB %00000000
