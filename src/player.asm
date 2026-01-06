Player_Update:
    LD A, (Pac_Dir)
    OR A
    RET Z                  ; nessuna direzione

    ; coord correnti
    LD A, (Pac_X)
    LD D, A
    LD A, (Pac_Y)
    LD E, A

    LD A, (Pac_Dir)

    CP 1
    JR NZ, .check_down
    DEC E                  ; up
    JR .try_move
.check_down:
    CP 2
    JR NZ, .check_left
    INC E                  ; down
    JR .try_move
.check_left:
    CP 3
    JR NZ, .check_right
    DEC D                  ; left
    JR .try_move
.check_right:
    CP 4
    JR NZ, .done
    INC D                  ; right

.try_move:
    CALL Maze_CanMove      ; D=x, E=y
    OR A
    JR Z, .done

    LD A, D
    LD (Pac_X), A
    LD A, E
    LD (Pac_Y), A

.done:
    RET

Player_Draw:
    LD A, (Pac_X)
    LD D, A
    LD A, (Pac_Y)
    LD E, A

    LD A, (COLOR_BLACK << 3) | COLOR_YELLOW
    CALL Video_DrawTile

    RET
