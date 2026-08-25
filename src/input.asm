; ==========================================
; PAC48 - input.asm
; Physical input -> queued logical direction
; ==========================================
;
; Input_Read returns one logical requested direction in A:
; 0=no cardinal held, 1=up, 2=down, 3=left, 4=right.
;
; The complete held-direction mask is retained in Input_HeldMask. This matters
; at dead ends: a preferred perpendicular turn may be blocked while another
; held direction (usually the reversal) is legal. Player_Update can then fall
; back without an artificial stop.
;
; While travelling, a perpendicular component wins over the current axis.
; Holding only the current direction returns that direction, so a stale queued
; turn is cancelled instead of surviving after the player releases the turn.

INPUT_MASK_RIGHT EQU %00000001
INPUT_MASK_LEFT  EQU %00000010
INPUT_MASK_DOWN  EQU %00000100
INPUT_MASK_UP    EQU %00001000

Input_Read:
    LD A, (Input_Mode)
    OR A
    JP Z, .read_keyboard
    CP 1
    JP Z, .read_kempston
    CP 2
    JP Z, .read_sinclair1
    JP .read_sinclair2

.read_keyboard:
    ; D holds the logical mask because BC is repeatedly reused for row ports.
    LD D, 0

    LD BC, $FBFE            ; Q row
    IN A, (C)
    BIT 0, A
    JR NZ, .kbd_no_up
    SET 3, D
.kbd_no_up:

    LD BC, $FDFE            ; A row
    IN A, (C)
    BIT 0, A
    JR NZ, .kbd_no_down
    SET 2, D
.kbd_no_down:

    LD BC, $DFFE            ; P/O row
    IN A, (C)
    BIT 1, A                ; O = left
    JR NZ, .kbd_no_left
    SET 1, D
.kbd_no_left:
    BIT 0, A                ; P = right
    JR NZ, .kbd_no_right
    SET 0, D
.kbd_no_right:

    LD BC, $F7FE            ; cursor 5 = left
    IN A, (C)
    BIT 4, A
    JR NZ, .cursor_no_left
    SET 1, D
.cursor_no_left:

    LD BC, $EFFE            ; cursor 6=down, 7=up, 8=right
    IN A, (C)
    BIT 4, A
    JR NZ, .cursor_no_down
    SET 2, D
.cursor_no_down:
    BIT 3, A
    JR NZ, .cursor_no_up
    SET 3, D
.cursor_no_up:
    BIT 2, A
    JR NZ, .cursor_no_right
    SET 0, D
.cursor_no_right:

    LD A, D
    JP .remember_and_select

.read_kempston:
    LD BC, PORT_KEMPSTON
    IN A, (C)
    LD D, 0
    BIT 0, A                ; right, active high
    JR Z, .kemp_no_right
    SET 0, D
.kemp_no_right:
    BIT 1, A                ; left
    JR Z, .kemp_no_left
    SET 1, D
.kemp_no_left:
    BIT 2, A                ; down
    JR Z, .kemp_no_down
    SET 2, D
.kemp_no_down:
    BIT 3, A                ; up
    JR Z, .kemp_no_up
    SET 3, D
.kemp_no_up:
    LD A, D
    JP .remember_and_select

.read_sinclair1:
    ; Interface 2 joystick 1: 6=left, 7=right, 8=down, 9=up, 0=fire.
    LD BC, $EFFE
    IN A, (C)
    LD D, 0
    BIT 4, A
    JR NZ, .s1_no_left
    SET 1, D
.s1_no_left:
    BIT 3, A
    JR NZ, .s1_no_right
    SET 0, D
.s1_no_right:
    BIT 2, A
    JR NZ, .s1_no_down
    SET 2, D
.s1_no_down:
    BIT 1, A
    JR NZ, .s1_no_up
    SET 3, D
.s1_no_up:
    LD A, D
    JP .remember_and_select

.read_sinclair2:
    ; Interface 2 joystick 2: 1=left, 2=right, 3=down, 4=up, 5=fire.
    LD BC, $F7FE
    IN A, (C)
    LD D, 0
    BIT 0, A
    JR NZ, .s2_no_left
    SET 1, D
.s2_no_left:
    BIT 1, A
    JR NZ, .s2_no_right
    SET 0, D
.s2_no_right:
    BIT 2, A
    JR NZ, .s2_no_down
    SET 2, D
.s2_no_down:
    BIT 3, A
    JR NZ, .s2_no_up
    SET 3, D
.s2_no_up:
    LD A, D

.remember_and_select:
    LD (Input_HeldMask), A
    JP Input_SelectFromMask

; In:  A = INPUT_MASK_* bitmask.
; Out: A = logical requested direction, or 0 when nothing is held.
Input_SelectFromMask:
    LD B, A
    OR A
    RET Z

    LD A, (Pac_Dir)
    CP 1
    JR Z, .moving_vertical
    CP 2
    JR Z, .moving_vertical
    CP 3
    JR Z, .moving_horizontal
    CP 4
    JR Z, .moving_horizontal
    JR .stopped

.moving_horizontal:
    ; A vertical component is the preferred queued turn while travelling across.
    BIT 3, B
    JR Z, .horizontal_check_down
    BIT 2, B
    JR Z, .select_up         ; up only
    JR .horizontal_axis      ; contradictory up+down: use horizontal axis
.horizontal_check_down:
    BIT 2, B
    JR NZ, .select_down

.horizontal_axis:
    LD A, (Pac_Dir)
    CP 3
    JR Z, .from_left
    ; Moving right: opposite LEFT first, then current RIGHT.
    BIT 1, B
    JR NZ, .select_left
    BIT 0, B
    JR NZ, .select_right
    XOR A
    RET
.from_left:
    ; Moving left: opposite RIGHT first, then current LEFT.
    BIT 0, B
    JR NZ, .select_right
    BIT 1, B
    JR NZ, .select_left
    XOR A
    RET

.moving_vertical:
    ; A horizontal component is the preferred queued turn while travelling up/down.
    BIT 1, B
    JR Z, .vertical_check_right
    BIT 0, B
    JR Z, .select_left       ; left only
    JR .vertical_axis        ; contradictory left+right: use vertical axis
.vertical_check_right:
    BIT 0, B
    JR NZ, .select_right

.vertical_axis:
    LD A, (Pac_Dir)
    CP 1
    JR Z, .from_up
    ; Moving down: opposite UP first, then current DOWN.
    BIT 3, B
    JR NZ, .select_up
    BIT 2, B
    JR NZ, .select_down
    XOR A
    RET
.from_up:
    ; Moving up: opposite DOWN first, then current UP.
    BIT 2, B
    JR NZ, .select_down
    BIT 3, B
    JR NZ, .select_up
    XOR A
    RET

.stopped:
    ; With no current travel axis, accept one held direction using stable priority.
    BIT 3, B
    JR NZ, .select_up
    BIT 2, B
    JR NZ, .select_down
    BIT 1, B
    JR NZ, .select_left
    BIT 0, B
    JR NZ, .select_right
    XOR A
    RET

.select_up:
    LD A, 1
    RET
.select_down:
    LD A, 2
    RET
.select_left:
    LD A, 3
    RET
.select_right:
    LD A, 4
    RET
