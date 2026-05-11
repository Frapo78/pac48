; =========================
; MEMORIA / VARIABILI
; =========================

FrameCounter:  DB 0

GameState:     DB 0   ; 0=menu, 1=play, 2=gameover

Pac_X:         DB 1
Pac_Y:         DB 1
Pac_PixelX:    DB 24
Pac_PixelY:    DB 24
Pac_Dir:       DB 0
Pac_ReqDir:    DB 0

Input_Mode:    DB 0   ; 0=Q/A/O/P, 1=Kempston, 2=Sinclair 1, 3=Sinclair 2
