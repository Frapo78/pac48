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

; Functional centre tunnel. The maze stays 28 cells wide and the actor wraps
; between the two edge cells on this row. Keep endpoint coordinates numeric so
; build-time topology tools can parse the same constants used by Z80 code.
Maze_TunnelRow         EQU 9
Maze_TunnelLeftX       EQU 0
Maze_TunnelRightX      EQU 27
Maze_TunnelPixelY      EQU (Maze_OffsetY + Maze_TunnelRow) * 8
Maze_TunnelLeftPixelX  EQU (Maze_OffsetX + Maze_TunnelLeftX) * 8
Maze_TunnelRightPixelX EQU (Maze_OffsetX + Maze_TunnelRightX) * 8

; Arcade-style cornering window around a logical 8-pixel node. A perpendicular
; request can snap to the nearest legal node when it is at most three pixels
; before/after it, avoiding the old exact-%8 turn gate.
Pac_TurnWindow EQU 3

; Player starts below the central maze structure, echoing the arcade spawn
; rather than the old prototype start in the upper-left corridor.
Pac_StartX      EQU 13
Pac_StartY      EQU 15
Pac_StartPixelX EQU (Maze_OffsetX + Pac_StartX) * 8
Pac_StartPixelY EQU (Maze_OffsetY + Pac_StartY) * 8
