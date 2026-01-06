; ==========================================
; PAC48 - Pac-like 48K (v0: tile/attr engine)
; Menu controlli: Q/A/O/P, Kempston, Sinclair
; Assemble: z80asm -o pac48.bin pac48.asm
; TAP:      bin2tap.py -o 32768 -s 32768 -c 32767 pac48.bin pac48.tap
; ==========================================

INCLUDE "config.asm"
INCLUDE "memory.asm"
CALL Menu_Run

        ORG 32768

; ---- Costanti
ATTR_BASE       EQU 22528
PORT_ULA        EQU 254
PORT_KEMPSTON   EQU 31

MODE_KEYS       EQU 0
MODE_KEMPSTON   EQU 1
MODE_SIN1       EQU 2
MODE_SIN2       EQU 3

; attributi (paper<<3 | ink) + bright facoltativo
ATTR_PATH       EQU (0<<3) | 0          ; nero
ATTR_WALL       EQU (1<<3) | 7 | 64     ; blu paper, ink bianco, bright
ATTR_PAC        EQU (6<<3) | 0 | 64     ; giallo paper, ink nero, bright
ATTR_UI         EQU (0<<3) | 7 | 64     ; testo bianco su nero, bright

; griglia di gioco: 28x20 dentro schermo attr 32x24
GRID_W          EQU 28
GRID_H          EQU 20
OFF_X           EQU 2        ; offset in celle attr
OFF_Y           EQU 2

START:
        DI
        LD SP, 65535

        ; bordo nero iniziale
        XOR A
        OUT (PORT_ULA), A

        CALL RomCLS
        CALL Menu

        ; disegna labirinto e pac
        CALL ClearAttrs
        CALL DrawMaze
        CALL DrawPac

        EI

MainLoop:
        HALT

        ; bordo che cicla (debug/energia)
        LD A,(Frame)
        INC A
        LD (Frame),A
        AND 7
        OUT (PORT_ULA),A

        ; input -> Dir (0 none,1 up,2 down,3 left,4 right)
        CALL ReadInput

        ; muovi pac se possibile
        CALL MovePac

        JP MainLoop


; ==========================================
; MENU
; ==========================================
Menu:
        CALL RomCLS

        LD HL, StrTitle
        CALL PrintString

        LD HL, StrOpt1
        CALL PrintString
        LD HL, StrOpt2
        CALL PrintString
        LD HL, StrOpt3
        CALL PrintString
        LD HL, StrOpt4
        CALL PrintString

WaitKey:
        CALL ReadKeyMenu
        CP 1
        JR Z, Sel1
        CP 2
        JR Z, Sel2
        CP 3
        JR Z, Sel3
        CP 4
        JR Z, Sel4
        JR WaitKey

Sel1:   LD A,MODE_KEYS:    LD (CtrlMode),A: RET
Sel2:   LD A,MODE_KEMPSTON:LD (CtrlMode),A: RET
Sel3:   LD A,MODE_SIN1:    LD (CtrlMode),A: RET
Sel4:   LD A,MODE_SIN2:    LD (CtrlMode),A: RET


; Ritorna in A: 1..4 se premuto 1..4, altrimenti 0
ReadKeyMenu:
        XOR A
        ; Legge riga che contiene 1-5: port FEFE (tasti 1..5)
        ; Bit 0=1, 1=2, 2=3, 3=4, 4=5 (0 = premuto)
        LD BC, $FEFE
        IN A,(C)
        CPL
        AND %00001111
        ; Trova il primo tra 1..4
        BIT 0,A
        JR Z,Chk2
        LD A,1
        RET
Chk2:   BIT 1,A
        JR Z,Chk3
        LD A,2
        RET
Chk3:   BIT 2,A
        JR Z,Chk4
        LD A,3
        RET
Chk4:   BIT 3,A
        JR Z,NoM
        LD A,4
        RET
NoM:    XOR A
        RET


; ==========================================
; RENDER ATTR: pulizia, labirinto, pac
; ==========================================
ClearAttrs:
        LD HL, ATTR_BASE
        LD DE, ATTR_BASE+1
        LD BC, 32*24-1
        LD A, ATTR_PATH
        LD (HL),A
        LDIR
        RET

; Map: 28x20, 1=wall, 0=path
; Disegno dentro area con offset OFF_X/OFF_Y
DrawMaze:
        LD IX, MazeMap
        LD B, GRID_H
        LD D, 0              ; y=0

RowMaze:
        PUSH BC
        LD C, GRID_W
        LD E, 0              ; x=0

ColMaze:
        ; Leggi cella
        LD A,(IX+0)
        INC IX
        OR A
        JR Z, IsPath
        LD A, ATTR_WALL
        JR WriteCell
IsPath:
        LD A, ATTR_PATH

WriteCell:
        ; addr = ATTR_BASE + (OFF_Y+y)*32 + (OFF_X+x)
        PUSH AF
        LD A, D
        ADD A, OFF_Y
        LD H, 0
        LD L, A
        ; HL = (OFF_Y+y)
        ADD HL, HL           ; *2
        ADD HL, HL           ; *4
        ADD HL, HL           ; *8
        ADD HL, HL           ; *16
        ADD HL, HL           ; *32
        LD A, E
        ADD A, OFF_X
        LD C, A
        LD B, 0
        ADD HL, BC
        LD BC, ATTR_BASE
        ADD HL, BC
        POP AF
        LD (HL), A

        INC E
        DEC C
        JR NZ, ColMaze

        INC D
        POP BC
        DJNZ RowMaze
        RET

; Pacman come singola cella attr (versione v0)
DrawPac:
        ; Scrive pac su cella corrente
        LD A,(PacY)
        LD D,A
        LD A,(PacX)
        LD E,A
        LD A, ATTR_PAC
        CALL PutAttrAtDE
        RET

ErasePac:
        ; ripristina path sulla cella precedente
        LD A,(PacYPrev)
        LD D,A
        LD A,(PacXPrev)
        LD E,A
        LD A, ATTR_PATH
        CALL PutAttrAtDE
        RET

; PutAttrAtDE: D=y(0..19), E=x(0..27), A=attr
PutAttrAtDE:
        PUSH AF
        LD A, D
        ADD A, OFF_Y
        LD H, 0
        LD L, A
        ADD HL, HL
        ADD HL, HL
        ADD HL, HL
        ADD HL, HL
        ADD HL, HL           ; *32
        LD A, E
        ADD A, OFF_X
        LD C, A
        LD B, 0
        ADD HL, BC
        LD BC, ATTR_BASE
        ADD HL, BC
        POP AF
        LD (HL), A
        RET


; ==========================================
; INPUT
; Dir: 0 none, 1 up, 2 down, 3 left, 4 right
; ==========================================
ReadInput:
        XOR A
        LD (Dir),A

        LD A,(CtrlMode)
        CP MODE_KEMPSTON
        JP Z, ReadKempston
        CP MODE_SIN1
        JP Z, ReadSin1
        CP MODE_SIN2
        JP Z, ReadSin2
        JP ReadKeysQAOP

; ---- Tastiera Q/A/O/P
; Q su riga QWERT (FB) bit 0, A su (FD) bit 0, O su (DF) bit 1, P su (DF) bit 0
ReadKeysQAOP:
        ; UP = Q
        LD BC, $FBFE
        IN A,(C)
        BIT 0,A
        JR NZ, NoQ
        LD A,1
        LD (Dir),A
        RET
NoQ:
        ; DOWN = A
        LD BC, $FDFE
        IN A,(C)
        BIT 0,A
        JR NZ, NoA
        LD A,2
        LD (Dir),A
        RET
NoA:
        ; LEFT = O (bit 1 su riga OP... -> $DFFE)
        LD BC, $DFFE
        IN A,(C)
        BIT 1,A
        JR NZ, NoO
        LD A,3
        LD (Dir),A
        RET
NoO:
        ; RIGHT = P (bit 0 su riga OP... -> $DFFE)
        LD BC, $DFFE
        IN A,(C)
        BIT 0,A
        JR NZ, NoP
        LD A,4
        LD (Dir),A
NoP:
        RET

; ---- Kempston: bit0=right, bit1=left, bit2=down, bit3=up (1=attivo)
ReadKempston:
        IN A,(PORT_KEMPSTON)
        BIT 3,A
        JR Z, KNoU
        LD A,1: LD (Dir),A: RET
KNoU:   IN A,(PORT_KEMPSTON)
        BIT 2,A
        JR Z, KNoD
        LD A,2: LD (Dir),A: RET
KNoD:   IN A,(PORT_KEMPSTON)
        BIT 1,A
        JR Z, KNoL
        LD A,3: LD (Dir),A: RET
KNoL:   IN A,(PORT_KEMPSTON)
        BIT 0,A
        JR Z, KNoR
        LD A,4: LD (Dir),A: RET
KNoR:   RET

; ---- Sinclair 1 (comune): 6 7 8 9 0 = left down up right fire
ReadSin1:
        ; riga 6-0: port EFFE (tasti 6..0), bit0=6,1=7,2=8,3=9,4=0
        LD BC, $EFFE
        IN A,(C)
        ; 0=premuto
        BIT 2,A
        JR NZ, S1NoU
        LD A,1: LD (Dir),A: RET
S1NoU:  BIT 1,A
        JR NZ, S1NoD
        LD A,2: LD (Dir),A: RET
S1NoD:  BIT 0,A
        JR NZ, S1NoL
        LD A,3: LD (Dir),A: RET
S1NoL:  BIT 3,A
        JR NZ, S1NoR
        LD A,4: LD (Dir),A: RET
S1NoR:  RET

; ---- Sinclair 2 (comune): 1 2 3 4 5 = left down up right fire
ReadSin2:
        ; riga 1-5: port FEFE (tasti 1..5), bit0=1,1=2,2=3,3=4,4=5
        LD BC, $FEFE
        IN A,(C)
        BIT 2,A
        JR NZ, S2NoU
        LD A,1: LD (Dir),A: RET
S2NoU:  BIT 1,A
        JR NZ, S2NoD
        LD A,2: LD (Dir),A: RET
S2NoD:  BIT 0,A
        JR NZ, S2NoL
        LD A,3: LD (Dir),A: RET
S2NoL:  BIT 3,A
        JR NZ, S2NoR
        LD A,4: LD (Dir),A: RET
S2NoR:  RET


; ==========================================
; MOVIMENTO + COLLISIONE
; ==========================================
MovePac:
        LD A,(Dir)
        OR A
        RET Z

        ; salva prev
        LD A,(PacX)
        LD (PacXPrev),A
        LD A,(PacY)
        LD (PacYPrev),A

        ; calcola next
        LD A,(PacX)
        LD E,A
        LD A,(PacY)
        LD D,A

        LD A,(Dir)
        CP 1
        JR NZ,ChkDown
        DEC D
        JR DoTry
ChkDown:
        CP 2
        JR NZ,ChkLeft
        INC D
        JR DoTry
ChkLeft:
        CP 3
        JR NZ,ChkRight
        DEC E
        JR DoTry
ChkRight:
        CP 4
        JR NZ,EndMove
        INC E

DoTry:
        ; bounds
        LD A,D
        CP GRID_H
        JR NC,EndMove
        LD A,E
        CP GRID_W
        JR NC,EndMove

        ; wall?
        CALL IsWallDE
        OR A
        JR NZ,EndMove

        ; ok: redraw
        CALL ErasePac
        LD A,E
        LD (PacX),A
        LD A,D
        LD (PacY),A
        CALL DrawPac
EndMove:
        RET

; IsWallDE: D=y, E=x, ritorna A=1 se wall, A=0 se path
IsWallDE:
        ; index = y*28 + x
        PUSH DE
        LD A,D
        LD H,0
        LD L,A
        ; HL = y
        ADD HL,HL           ; *2
        ADD HL,HL           ; *4
        ADD HL,HL           ; *8
        LD DE, HL           ; DE = y*8
        ADD HL,HL           ; *16
        ADD HL,DE           ; *24
        LD DE, HL           ; DE = y*24
        ADD HL,HL           ; *48
        SBC HL,DE           ; *24 (ripristino veloce?)  -> troppo contorto

        ; versione semplice e sicura: y*28 = y*32 - y*4
        POP DE
        PUSH DE
        LD A,D
        LD H,0
        LD L,A
        ADD HL,HL           ;*2
        ADD HL,HL           ;*4
        LD BC, HL           ;BC=y*4
        LD A,D
        LD H,0
        LD L,A
        ADD HL,HL           ;*2
        ADD HL,HL           ;*4
        ADD HL,HL           ;*8
        ADD HL,HL           ;*16
        ADD HL,HL           ;*32
        OR A
        SBC HL,BC           ;*28

        LD A,E
        LD C,A
        LD B,0
        ADD HL,BC

        LD DE, MazeMap
        ADD HL,DE
        LD A,(HL)
        POP DE
        RET

; ==========================================
; ROM helper: CLS + stampa stringhe (menu)
; ==========================================
RomCLS:
        CALL $0DAF
        RET

PrintString:
        ; HL -> stringa terminata da 0
PS_Loop:
        LD A,(HL)
        OR A
        RET Z
        RST 16
        INC HL
        JR PS_Loop


; ==========================================
; DATA: maze e stringhe
; ==========================================

; Labirinto semplice: bordo + blocchi interni
; 20 righe * 28 colonne = 560 byte
; 1=wall, 0=path
MazeMap:
        ; riga 0
        DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        ; riga 1
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 2
        DB 1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,0,1
        ; riga 3
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 4
        DB 1,0,1,1,0,1,1,1,0,1,1,0,1,1,0,1,1,0,1,1,0,1,1,1,0,1,0,1
        ; riga 5
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 6
        DB 1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,0,1
        ; riga 7
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 8
        DB 1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,1
        ; riga 9
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 10
        DB 1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,0,1
        ; riga 11
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 12
        DB 1,0,1,0,0,0,1,1,0,0,0,1,1,0,0,0,1,1,0,0,0,1,1,0,0,0,0,1
        ; riga 13
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 14
        DB 1,0,1,1,0,1,1,1,0,1,1,0,1,1,0,1,1,0,1,1,0,1,1,1,0,1,0,1
        ; riga 15
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 16
        DB 1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,0,1
        ; riga 17
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 18
        DB 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        ; riga 19
        DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1


StrTitle: DB 13,13,"PAC48 - SCEGLI CONTROLLI",13,13,0
StrOpt1:  DB "1) TASTIERA Q/A/O/P",13,0
StrOpt2:  DB "2) JOYSTICK KEMPSTON",13,0
StrOpt3:  DB "3) JOYSTICK SINCLAIR 1 (6-0)",13,0
StrOpt4:  DB "4) JOYSTICK SINCLAIR 2 (1-5)",13,13,0

; ==========================================
; VAR
; ==========================================
Frame:      DB 0
CtrlMode:   DB 0
Dir:        DB 0

; Pac start
PacX:       DB 1
PacY:       DB 1
PacXPrev:   DB 1
PacYPrev:   DB 1

        END START
