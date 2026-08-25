; =========================
; CONFIG / COSTANTI GLOBALI
; =========================

PORT_ULA       EQU 254
PORT_KEMPSTON  EQU 31

SCREEN_ADDR    EQU 16384
ATTR_ADDR      EQU 22528

COLOR_BLACK    EQU 0
COLOR_BLUE     EQU 1
COLOR_RED      EQU 2
COLOR_MAGENTA  EQU 3
COLOR_GREEN    EQU 4
COLOR_CYAN     EQU 5
COLOR_YELLOW   EQU 6
COLOR_WHITE    EQU 7

; ------------------------------------------------------------
; Landscape maze geometry.
; Keep these global because startup state, renderer and validation all depend
; on the same coordinate system.
; ------------------------------------------------------------
Maze_Width      EQU 28
Maze_Height     EQU 20
Maze_OffsetX    EQU 2
Maze_OffsetY    EQU 2

; Player starts below the central maze structure, echoing the arcade spawn
; rather than the old prototype start in the upper-left corridor.
Pac_StartX      EQU 13
Pac_StartY      EQU 15
Pac_StartPixelX EQU (Maze_OffsetX + Pac_StartX) * 8
Pac_StartPixelY EQU (Maze_OffsetY + Pac_StartY) * 8
