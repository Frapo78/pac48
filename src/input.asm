; ==========================================
; PAC48 - input.asm
; Physical input -> queued logical direction
; ==========================================
;
; Input_Read returns one logical requested direction in A:
; 0=keep current queued request, 1=up, 2=down, 3=left, 4=right.
;
; Simultaneous cardinal inputs are preserved as a mask first. When Pac is
; already travelling, a perpendicular component wins over the current axis.
; This makes down+right mean "take DOWN at the first opening" while travelling
; horizontally, then "take RIGHT at the first opening" once travelling down.
; Holding only the current travel direction returns 0 so it cannot erase an
; already buffered turn.

INPUT_MASK_RIGHT EQU %00000001
INPUT_MASK_LEFT  EQU %00000010
INPUT_MASK_DOWN  EQU %00000100
INPUT_MASK_UP    EQU %00001000

Input_Read:
    LD A, (Input_Mode)
    OR A
    JR Z, .read_keyboard
    CP 1
    JR Z, .read_kempston
    CP 2
    JR Z, .read_sinclair1
    JR .read_sinclair2

.read_keyboard:
    LD B, 0

    LD BC, $FBFE            ; Q row
    IN A, (C)
    BIT 0, A
    JR NZ, .kbd_no_up
    SET 3, B
.kbd_no_up:

    LD BC, $FDFE            ; A row
    IN A, (C)
    BIT 0, A
    JR NZ, .kbd_no_down
    SET 2, B
.kbd_no_down:

    LD BC, $DFFE            ; P/O row
    IN A, (C)
    BIT 1, A                ; O = left
    JR NZ, .kbd_no_left
    SET 1, B
.kbd_no_left:
    BIT 0, A                ; P = right
    JR NZ, .kbd_no_right
    SET 0, B
.kbd_no_right:

    LD BC, $F7FE            ; cursor 5 = left
    IN A, (C)
    BIT 4, A
    JR NZ, .cursor_no_left
    SET 1, B
.cursor_no_left:

    LD BC, $EFFE            ; cursor 6=down, 7=up, 8=right
    IN A, (C)
    BIT 4, A
    JR NZ, .cursor_no_down
    SET 2, B
.cursor_no_down:
    BIT 3, A
    JR NZ, .cursor_no_up
    SET 3, B
.cursor_no_up:
    BIT 2, A
    JR NZ, .cursor_no_right
    SET 0, B
.cursor_no_right:

    LD A, B
    JP Input_SelectFromMask

.read_kempston:
    LD BC, PORT_KEMPSTON
    IN A, (C)
    LD B, 0
    BIT 0, A                ; right, active high
    JR Z, .kemp_no_right
    SET 0, B
.kemp_no_right:
    BIT 1, A                ; left
    JR Z, .kemp_no_left
    SET 1, B
.kemp_no_left:
    BIT 2, A                ; down
    JR Z, .kemp_no_down
    SET 2, B
.kemp_no_down:
    BIT 3, A                ; up
    JR Z, .kemp_no_up
    SET 3, B
.kemp_no_up:
    LD A, B
    JP Input_SelectFromMask

.read_sinclair1:
    ; Interface 2 joystick 1: 6=left, 7=right, 8=down, 9=up, 0=fire.
    LD BC, $EFFE
    IN A, (C)
    LD B, 0
    BIT 4, A
    JR NZ, .s1_no_left
    SET 1, B
.s1_no_left:
    BIT 3, A
    JR NZ, .s1_no_right
    SET 0, B
.s1_no_right:
    BIT 2, A
    JR NZ, .s1_no_down
    SET 2, B
.s1_no_down:
    BIT 1, A
    JR NZ, .s1_no_up
    SET 3, B
.s1_no_up:
    LD A, B
    JP Input_SelectFromMask

.read_sinclair2:
    ; Interface 2 joystick 2: 1=left, 2=right, 3=down, 4=up, 5=fire.
    LD BC, $F7FE
    IN A, (C)
    LD B, 0
    BIT 0, A
    JR NZ, .s2_no_left
    SET 1, B
.s2_no_left:
    BIT 1, A
    JR NZ, .s2_no_right
    SET 0, B
.s2_no_right:
    BIT 2, A
    JR NZ, .s2_no_down
    SET 2, B
.s2_no_down:
    BIT 3, A
    JR NZ, .s2_no_up
    SET 3, B
.s2_no_up:
    LD A, B
    JP Input_SelectFromMask

; In:  A = INPUT_MASK_* bitmask.
; Out: A = logical requested direction, or 0 to keep the existing queue.
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
    ; A vertical component is the desired queued turn while travelling across.
    BIT 3, B
    JR Z, .horizontal_check_down
    BIT 2, B
    JR Z, .select_up         ; up only
    JR .horizontal_opposite  ; contradictory up+down: ignore perpendicular axis
.horizontal_check_down:
    BIT 2, B
    JR NZ, .select_down

.horizontal_opposite:
    LD A, (Pac_Dir)
    CP 3
    JR Z, .from_left
    BIT 1, B                 ; moving right: left is a reversal request
    JR NZ, .select_left
    XOR A                    ; current direction alone must not clear queue
    RET
.from_left:
    BIT 0, B                 ; moving left: right is a reversal request
    JR NZ, .select_right
    XOR A
    RET

.moving_vertical:
    ; A horizontal component is the desired queued turn while travelling up/down.
    BIT 1, B
    JR Z, .vertical_check_right
    BIT 0, B
    JR Z, .select_left       ; left only
    JR .vertical_opposite    ; contradictory left+right: ignore perpendicular axis
.vertical_check_right:
    BIT 0, B
    JR NZ, .select_right

.vertical_opposite:
    LD A, (Pac_Dir)
    CP 1
    JR Z, .from_up
    BIT 3, B                 ; moving down: up reverses
    JR NZ, .select_up
    XOR A
    RET
.from_up:
    BIT 2, B                 ; moving up: down reverses
    JR NZ, .select_down
    XOR A
    RET

.stopped:
    ; With no current travel axis, accept one held direction using a stable
    ; priority. Once motion begins, the relative-axis rules above take over.
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
