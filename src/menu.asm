Menu_Run:
    ; pulisci schermo e resetta cursore ROM
    CALL $0DAF               ; ROM CLS
    CALL Video_Clear         ; azzera bitmap/attributi

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
    JR Z, .choose_sinclair1
    BIT 3, A                ; '4' -> Sinclair 2
    JR Z, .choose_sinclair2
    JR .wait_key

.choose_keyboard:
    XOR A                   ; Input_Mode = 0
    JR .store_mode
.choose_kempston:
    LD A, 1
    JR .store_mode
.choose_sinclair1:
    LD A, 2
    JR .store_mode
.choose_sinclair2:
    LD A, 3

.store_mode:
    LD (Input_Mode), A
    XOR A
    LD (Pac_Dir), A          ; reset direzione giocatore
    LD (Pac_ReqDir), A

.wait_release:
    LD BC, $F7FE             ; riga tasti 1-5
    IN A, (C)
    AND %00001111
    CP %00001111
    JR NZ, .wait_release
    RET

Menu_Text:
    DB "PAC48 0.3.4-beta", 13
    DB "Seleziona controllo", 13
    DB "1) Q/A/O/P", 13
    DB "2) Kempston", 13
    DB "3) Sinclair 1", 13
    DB "4) Sinclair 2", 13
    DB 0
