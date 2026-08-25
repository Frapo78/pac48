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
Pac_FacingDir: DB 4   ; ultima direzione valida per l'animazione, default destra

Input_Mode:     DB 0   ; 0=Q/A/O/P, 1=Kempston, 2=Sinclair 1, 3=Sinclair 2
Input_HeldMask: DB 0   ; tutte le direzioni cardinali attualmente premute

; ------------------------------------------
; Renderer persistent/prepared state
; ------------------------------------------
Render_PlayerX:        DB 24
Render_PlayerY:        DB 24
Render_PlayerPhase:    DB 0
Render_PlayerSprite:   DW 0

Render_DirtyCount:     DB 0
Render_NextDirtyCount: DB 0
Render_DirtyCells:     DEFS 48, 0      ; 24 x/y cell pairs
Render_NextDirtyCells: DEFS 48, 0      ; 24 x/y cell pairs

; Renderer scratch used only inside prepare/commit routines.
Render_TileX:          DB 0
Render_TileY:          DB 0
Render_CrossX:         DB 0
Render_CrossY:         DB 0
Render_DrawXByte:      DB 0
Render_DrawY:          DB 0

; 192 Spectrum bitmap scanlines x 16-bit address.
; Initialized once by Video_InitLineTable during startup.
Video_LineAddrTable:   DEFS 384, 0
