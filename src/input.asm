; ritorna direzione in A
; 0 = none, 1=up, 2=down, 3=left, 4=right
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
    LD BC, $FBFE            ; Q row
    IN A, (C)
    BIT 0, A
    JR Z, .dir_up

    LD BC, $FDFE            ; A row
    IN A, (C)
    BIT 0, A
    JR Z, .dir_down

    LD BC, $DFFE            ; P/O row
    IN A, (C)
    BIT 1, A
    JR Z, .dir_left
    BIT 0, A
    JR Z, .dir_right

    LD BC, $F7FE            ; cursor 5 = left
    IN A, (C)
    BIT 4, A
    JR Z, .dir_left

    LD BC, $EFFE            ; cursor 6=down, 7=up, 8=right
    IN A, (C)
    BIT 4, A
    JR Z, .dir_down
    BIT 3, A
    JR Z, .dir_up
    BIT 2, A
    JR Z, .dir_right

    XOR A
    RET

.read_kempston:
    LD BC, PORT_KEMPSTON
    IN A, (C)
    BIT 3, A                ; up, active high
    JR NZ, .dir_up
    BIT 2, A                ; down
    JR NZ, .dir_down
    BIT 1, A                ; left
    JR NZ, .dir_left
    BIT 0, A                ; right
    JR NZ, .dir_right
    XOR A
    RET

.read_sinclair1:
    ; Interface 2 joystick 1 maps to keyboard row 6-0, active low:
    ; 6=left, 7=right, 8=down, 9=up, 0=fire.
    LD BC, $EFFE
    IN A, (C)
    BIT 4, A                ; 6 = left
    JR Z, .dir_left
    BIT 3, A                ; 7 = right
    JR Z, .dir_right
    BIT 2, A                ; 8 = down
    JR Z, .dir_down
    BIT 1, A                ; 9 = up
    JR Z, .dir_up
    XOR A
    RET

.read_sinclair2:
    ; Interface 2 joystick 2 maps to keyboard row 1-5, active low:
    ; 1=left, 2=right, 3=down, 4=up, 5=fire.
    LD BC, $F7FE
    IN A, (C)
    BIT 0, A                ; 1 = left
    JR Z, .dir_left
    BIT 1, A                ; 2 = right
    JR Z, .dir_right
    BIT 2, A                ; 3 = down
    JR Z, .dir_down
    BIT 3, A                ; 4 = up
    JR Z, .dir_up

    XOR A
    RET

.dir_up:
    LD A, 1
    RET
.dir_down:
    LD A, 2
    RET
.dir_left:
    LD A, 3
    RET
.dir_right:
    LD A, 4
    RET
