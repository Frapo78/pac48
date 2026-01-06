Menu_Run:
    LD HL, Menu_Text
.print_loop:
    LD A, (HL)
    OR A
    JR Z, .wait_input
    RST 16                  ; stampa carattere
    INC HL
    JR .print_loop

.wait_input:
    LD BC, $F7FE            ; riga tasti 1-5
.wait_key:
    IN A, (C)
    BIT 0, A                ; '1' -> Q/A/O/P
    JR Z, .choose_keyboard
    BIT 1, A                ; '2' -> Kempston
    JR Z, .choose_kempston
    BIT 2, A                ; '3' -> Sinclair
    JR Z, .choose_sinclair
    JR .wait_key

.choose_keyboard:
    XOR A                   ; Input_Mode = 0
    JR .store_mode
.choose_kempston:
    LD A, 1
    JR .store_mode
.choose_sinclair:
    LD A, 2

.store_mode:
    LD (Input_Mode), A
    RET

Menu_Text:
    DB "PAC48 - Seleziona controllo", 13
    DB "1) Q/A/O/P", 13
    DB "2) Kempston", 13
    DB "3) Sinclair", 13
    DB 0
