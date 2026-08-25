Menu_Run:
    ; pulisci schermo e resetta cursore ROM
    CALL $0DAF               ; ROM CLS
    CALL Video_Clear         ; azzera bitmap/attributi

    ; Version comes from generated/build_info.asm, which itself comes from
    ; the canonical VERSION file. Do not hardcode a semantic version here.
    LD HL, Build_MenuTitle
    CALL Menu_PrintZ
    LD HL, Menu_Text
    CALL Menu_PrintZ

.wait_input:
.wait_key:
    LD BC, $F7FE            ; riga tasti 1-5
    IN A, (C)
    BIT 0, A                ; '1' -> Q/A/O/P
    JR Z, .choose_keyboard
    BIT 1, A                ; '2' -> Kempston
    JR Z, .choose_kempston
    BIT 2, A                ; '3' -> Sinclair 1
    JR Z, .choose_sinclair1
    BIT 3, A                ; '4' -> Sinclair 2
    JR Z, .choose_sinclair2

    ; Kempston fire (bit 4, active high) is also a direct menu shortcut.
    ; This lets a joystick-only player start without touching the keyboard.
    LD BC, PORT_KEMPSTON
    IN A, (C)
    BIT 4, A
    JR NZ, .choose_kempston
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
    LD (Pac_Dir), A
    LD (Pac_ReqDir), A
    LD A, 4                 ; default visual facing = right
    LD (Pac_FacingDir), A

.wait_release:
    LD BC, $F7FE
    IN A, (C)
    AND %00001111
    CP %00001111
    JR NZ, .wait_release
    RET

; In: HL=zero-terminated ROM-printable text.
Menu_PrintZ:
.print_loop:
    LD A, (HL)
    OR A
    RET Z
    RST 16
    INC HL
    JR .print_loop

Menu_Text:
    DB "Seleziona controllo", 13
    DB "1) Q/A/O/P", 13
    DB "2) Kempston", 13
    DB "3) Sinclair 1", 13
    DB "4) Sinclair 2", 13
    DB 0
