; ritorna direzione in A
; 0 = none, 1=up, 2=down, 3=left, 4=right
Input_Read:
    LD A, (Input_Mode)
    OR A
    JR Z, .read_keyboard
    CP 1
    JR Z, .read_kempston
    JR .read_sinclair

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
    XOR A
    RET

.read_kempston:
    LD BC, PORT_KEMPSTON
    IN A, (C)
    BIT 3, A                ; up
    JR Z, .dir_up
    BIT 2, A                ; down
    JR Z, .dir_down
    BIT 1, A                ; left
    JR Z, .dir_left
    BIT 0, A                ; right
    JR Z, .dir_right
    XOR A
    RET

.read_sinclair:
    LD BC, $F7FE            ; Sinclair 2 (1-5)
    IN A, (C)
    BIT 0, A                ; 1 = up
    JR Z, .dir_up
    BIT 1, A                ; 2 = down
    JR Z, .dir_down
    BIT 2, A                ; 3 = left
    JR Z, .dir_left
    BIT 3, A                ; 4 = right
    JR Z, .dir_right

    LD BC, $EFFE            ; Sinclair 1 (6-0)
    IN A, (C)
    BIT 4, A                ; 6 = up
    JR Z, .dir_up
    BIT 3, A                ; 7 = down
    JR Z, .dir_down
    BIT 2, A                ; 8 = left
    JR Z, .dir_left
    BIT 1, A                ; 9 = right
    JR Z, .dir_right

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
