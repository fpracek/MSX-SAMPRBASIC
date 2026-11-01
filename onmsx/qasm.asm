; =====================================================================
; QASM.OVL - assembler Z80 in linea (overlay del compilatore, caricato a 8000h)
; Il compilatore lo carica quando il sorgente contiene "__ASM" e lo chiama con
;   HL = SRC (inizio sorgente), BC = SRCMAX (byte disponibili)
; Ogni blocco  __ASM ... __ENDASM  si riscrive sul posto in righe "# elementi": una riga per
; ogni riga del blocco (la numerazione delle righe non cambia). Elementi (separati da virgole):
;   n          byte
;   n:NOME     byte (codice di JP/CALL) + indirizzo dell'etichetta BASIC NOME
;   NOME[+k]   indirizzo (word) della variabile BASIC NOME
;   +k         indirizzo (word) = inizio del blocco + k  (etichette locali)
; La prima riga porta "# *" (inizio blocco).
; Ritorno: CF = 0 ok; CF = 1: A = errore (17 sintassi, 18 valore, 19 simbolo/blocco, 10 sorgente
; troppo grande), DE = riga.
; =====================================================================
ER_SYN  equ 17
ER_RNG  equ 18
ER_SYM  equ 19
ER_BIG  equ 10

TMP     equ 0A000h              ; uscita del blocco
TMPEND  equ 0BF00h
VARS    equ 9800h
LBUF    equ VARS                ; riga corrente (256)
OP1BUF  equ VARS+101h           ; operando 1 (255) preceduto da una sentinella
OP2BUF  equ VARS+201h
OP1     equ VARS+300h           ; struttura operando (19 byte)
OP2     equ VARS+320h
SYMTAB  equ VARS+340h           ; 64 simboli x 15 byte
SYMMAX  equ 64
SV      equ VARS+0700h          ; variabili scalari

O_T     equ 0                   ; tipo
O_C     equ 1                   ; codice registro / condizione
O_P     equ 2                   ; prefisso DD/FD
O_D     equ 3                   ; spostamento
O_V     equ 4                   ; valore (word)
O_K     equ 6                   ; 0 assoluto, 1 relativo al blocco, 2 esterno
O_N     equ 7                   ; nome esterno (12)

T_NONE  equ 0
T_R8    equ 1
T_R16   equ 2
T_AF    equ 3
T_AFP   equ 4
T_IBC   equ 5
T_IDE   equ 6
T_ISP   equ 7
T_IC    equ 8
T_COND  equ 9
T_IMM   equ 10
T_MEM   equ 11
T_I     equ 12
T_R     equ 13

sp0     equ SV+0
srcs    equ SV+2
srcl    equ SV+4
srce    equ SV+6
lno     equ SV+8
curl    equ SV+10
blno    equ SV+12
lnoaft  equ SV+14
bstart  equ SV+16
bend    equ SV+18
pass    equ SV+20
pc_off  equ SV+22
outp    equ SV+24
itfirst equ SV+26
inq     equ SV+27
depth   equ SV+28
cclass  equ SV+29
cparam  equ SV+30
nsym    equ SV+31
textp   equ SV+32
afterT1 equ SV+34
haslab  equ SV+36
ex_v    equ SV+37
ex_k    equ SV+39
ex_op   equ SV+40
ex_dst  equ SV+41
tv      equ SV+43
tk      equ SV+45
newlen  equ SV+46
oldlen  equ SV+48
delta   equ SV+50
nbase   equ SV+52
tmpw    equ SV+53
embv    equ SV+55
tokbuf  equ SV+64               ; 16
labbuf  equ SV+80               ; 16
symkey  equ SV+96               ; 16
ntok    equ SV+112              ; 32

        ORG 8000h
entry:
        ld (sp0),sp
        ld (srcs),hl
        add hl,bc
        ld (srcl),hl
        ld a,' '
        ld (OP1BUF-1),a
        ld (OP2BUF-1),a
        ld hl,(srcs)
.fe:    ld a,(hl)
        or a
        jr z,.fd
        inc hl
        jr .fe
.fd:    ld (srce),hl
        ld hl,1
        ld (lno),hl
        ld hl,(srcs)
.scan:  ld de,(srce)
        or a
        push hl
        sbc hl,de
        pop hl
        jr nc,.done
        push hl
        call is_asm
        pop hl
        jr z,.blk
        call nextline
        jr .scan
.blk:   call doblock
        jr .scan
.done:  or a
        ret

fail:   ld sp,(sp0)
        ld de,(curl)
        scf
        ret
err_syn:
        ld a,ER_SYN
        jr fail
err_rng:
        ld a,ER_RNG
        jr fail
err_sym:
        ld a,ER_SYM
        jr fail
err_big:
        ld a,ER_BIG
        jr fail

skipsp:
        ld a,(hl)
        cp ' '
        jr z,.s
        cp 9
        ret nz
.s:     inc hl
        jr skipsp

matchk:                         ; HL = testo, DE = modello maiuscolo 0-terminato: Z se coincide (HL avanza)
        ld a,(de)
        or a
        ret z
        ld b,a
        ld a,(hl)
        and 0DFh
        cp b
        ret nz
        inc hl
        inc de
        jr matchk

isid:                           ; A = carattere: CF = 1 se e' un carattere di identificatore
        cp '0'
        jr c,.sp
        cp '9'+1
        jr c,.y
        and 0DFh
        cp 'A'
        jr c,.n
        cp 'Z'+1
        jr c,.y
        cp '_'
        jr z,.y
.n:     or a
        ret
.sp:    cp '.'
        jr z,.y
        cp '$'
        jr z,.y
        or a
        ret
.y:     scf
        ret

nextline:                       ; HL = inizio della riga successiva; lno++
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        cp 0Ah
        jr nz,.l
        ld de,(lno)
        inc de
        ld (lno),de
        ret

is_asm:                         ; HL = inizio riga: Z se la riga e' "__ASM" o "OPTION ASM"
        call skipsp
        push hl
        ld de,k_asm
        call matchk
        jr z,.k
        pop hl
        ld de,k_opt
        call matchk
        ret nz
        call skipsp
        ld de,k_asm2
        call matchk
        ret nz
        push hl
.k:     pop de
        ld a,(hl)
        call isid
        jr c,.no
        xor a
        ret
.no:    or 1
        ret
k_opt:  db "OPTION",0
k_asm2: db "ASM",0
k_asm:  db "__ASM",0
k_end:  db "__ENDASM",0
k_equ:  db "EQU",0

doblock:                        ; HL = inizio della riga __ASM -> HL = punto dopo il testo riscritto
        ld (bstart),hl
        ld de,(lno)
        ld (blno),de
        ld (curl),de
        call nextline
.fe:    ld de,(srce)
        or a
        push hl
        sbc hl,de
        pop hl
        jr c,.more
        ld hl,(bstart)
        call skipsp
        ld a,(hl)
        and 0DFh
        cp 'O'
        jr z,.eof               ; OPTION ASM: il blocco arriva fino alla fine del file
        ld de,(blno)
        ld (curl),de
        jp err_sym              ; __ENDASM mancante
.more:  push hl
        call skipsp
        ld de,k_end
        call matchk
        pop hl
        jr z,.found
        call nextline
        jr .fe
.found: call nextline
        jr .fnd
.eof:   ld hl,(srce)
.fnd:   ld (bend),hl
        ld de,(lno)
        ld (lnoaft),de
        xor a
        ld (nsym),a
        ld a,1
        ld (pass),a
        call runpass
        ld a,2
        ld (pass),a
        call runpass
        ld hl,(outp)
        ld de,TMP
        or a
        sbc hl,de
        ld (newlen),hl
        ld hl,(bend)
        ld de,(bstart)
        or a
        sbc hl,de
        ld (oldlen),hl
        ld hl,(newlen)
        ld de,(oldlen)
        or a
        sbc hl,de
        ld (delta),hl
        jr z,.cpy
        jr c,.shr
        ld de,(srce)
        add hl,de
        ld de,(srcl)
        or a
        sbc hl,de
        jp nc,err_big
        ld hl,(srce)
        ld de,(bend)
        or a
        sbc hl,de
        inc hl
        ld b,h
        ld c,l
        ld hl,(srce)
        ld de,(delta)
        add hl,de
        ex de,hl
        ld hl,(srce)
        lddr
        jr .adj
.shr:   ld hl,(srce)
        ld de,(bend)
        or a
        sbc hl,de
        inc hl
        ld b,h
        ld c,l
        ld hl,(bend)
        ld de,(delta)
        add hl,de
        ex de,hl
        ld hl,(bend)
        ldir
.adj:   ld hl,(srce)
        ld de,(delta)
        add hl,de
        ld (srce),hl
.cpy:   ld hl,TMP
        ld de,(bstart)
        ld bc,(newlen)
        ldir
        ex de,hl
        ld de,(lnoaft)
        ld (lno),de
        ret

runpass:
        ld hl,0
        ld (pc_off),hl
        ld hl,TMP
        ld (outp),hl
        ld de,(blno)
        ld (lno),de
        ld hl,(bstart)
        call getline            ; riga __ASM
        ld a,(pass)
        cp 2
        jr nz,.l
        ld a,'#'
        call wchar
        ld a,' '
        call wchar
        ld a,'*'
        call wchar
        call weol
.l:     ld de,(bend)
        or a
        push hl
        sbc hl,de
        pop hl
        ret nc
        call getline
        push hl
        call asmline
        pop hl
        jr .l

; ---------------------------------------------------------------- uscita
wchar:                          ; A -> uscita (solo seconda passata)
        push hl
        push af
        ld a,(pass)
        cp 2
        jr nz,.x
        ld hl,(outp)
        ld a,h
        cp high TMPEND
        jp nc,err_rng
        pop af
        push af
        ld (hl),a
        inc hl
        ld (outp),hl
.x:     pop af
        pop hl
        ret

weol:
        ld a,13
        call wchar
        ld a,10
        jp wchar

sepchar:                        ; ' ' prima del primo elemento, ',' dopo
        ld a,(itfirst)
        or a
        ld a,','
        jr z,.c
        xor a
        ld (itfirst),a
        ld a,' '
.c:     jp wchar

wdec:                           ; HL senza segno -> testo decimale
        push bc
        push de
        push hl
        ld c,0
.l:     push bc
        call div10
        pop bc
        push af
        inc c
        ld a,h
        or l
        jr nz,.l
.o:     pop af
        add a,'0'
        call wchar
        dec c
        jr nz,.o
        pop hl
        pop de
        pop bc
        ret

div10:                          ; HL / 10 -> HL, A = resto
        xor a
        ld b,16
.d:     add hl,hl
        rla
        cp 10
        jr c,.n
        sub 10
        inc l
.n:     djnz .d
        ret

emb:                            ; A = byte
        push af
        push hl
        ld (embv),a
        ld hl,(pc_off)
        inc hl
        ld (pc_off),hl
        ld a,(pass)
        cp 2
        jr nz,.x
        call sepchar
        ld a,(embv)
        ld l,a
        ld h,0
        call wdec
.x:     pop hl
        pop af
        ret

pcadd:                          ; pc += A
        push hl
        ld hl,(pc_off)
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld (pc_off),hl
        pop hl
        ret

emitv:                          ; IX = operando: word secondo il tipo di valore
        ld a,(ix+O_K)
        or a
        jr z,.abs
        cp 1
        jr z,.rel
        ld a,2
        call pcadd
        ld a,(pass)
        cp 2
        ret nz
        call sepchar
        push ix
        pop hl
        ld de,O_N
        add hl,de
.nl:    ld a,(hl)
        or a
        jr z,.nd
        call wchar
        inc hl
        jr .nl
.nd:    ld l,(ix+O_V)
        ld h,(ix+O_V+1)
        ld a,h
        or l
        ret z
        ld a,'+'
        call wchar
        jp wdec
.rel:   ld a,2
        call pcadd
        ld a,(pass)
        cp 2
        ret nz
        call sepchar
        ld a,'+'
        call wchar
        ld l,(ix+O_V)
        ld h,(ix+O_V+1)
        jp wdec
.abs:   ld a,(ix+O_V)
        call emb
        ld a,(ix+O_V+1)
        jp emb

emjump:                         ; A = codice operativo, IX = indirizzo: JP/CALL (anche verso etichette BASIC)
        ld c,a
        ld a,(ix+O_K)
        cp 2
        jr z,.ext
        ld a,c
        call emb
        jp emitv
.ext:   ld a,3
        call pcadd
        ld a,(pass)
        cp 2
        ret nz
        call sepchar
        ld l,c
        ld h,0
        call wdec
        ld a,':'
        call wchar
        push ix
        pop hl
        ld de,O_N
        add hl,de
.nl:    ld a,(hl)
        or a
        ret z
        call wchar
        inc hl
        jr .nl

emp:                            ; prefisso DD/FD se c'e'
        ld a,(ix+O_P)
        or a
        ret z
        jp emb
emdisp:
        ld a,(ix+O_P)
        or a
        ret z
        ld a,(ix+O_D)
        jp emb
emb8:                           ; byte immediato (-128..255)
        ld a,(ix+O_K)
        or a
        jp nz,err_syn
        ld a,(ix+O_V+1)
        or a
        jr z,.ok
        cp 0FFh
        jp nz,err_rng
        ld a,(ix+O_V)
        or a
        jp p,err_rng
.ok:    ld a,(ix+O_V)
        jp emb

; ---------------------------------------------------------------- riga
getline:                        ; HL = riga di ingresso -> LBUF (maiuscole, senza commento); HL = riga successiva
        ld de,(lno)
        ld (curl),de
        inc de
        ld (lno),de
        ld de,LBUF
        xor a
        ld (inq),a
.l:     ld a,(hl)
        or a
        jr z,.end
        inc hl
        cp 0Ah
        jr z,.end
        cp 0Dh
        jr z,.l
        ld b,a
        ld a,(inq)
        or a
        jr nz,.q
        ld a,b
        cp ';'
        jr z,.cmt
        cp '"'
        jr z,.dq
        cp 27h
        jr nz,.up
        ld a,e                  ; apostrofo: carattere letterale se non segue un carattere alfanumerico (AF')
        or a
        jr z,.lit
        dec de
        ld a,(de)
        inc de
        call isid
        jr c,.up
.lit:   ld a,b
        ld (de),a
        inc de
        ld a,(hl)
        or a
        jr z,.l
        cp 0Ah
        jr z,.l
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        cp 27h
        jr nz,.l
        ld (de),a
        inc de
        inc hl
        jr .l
.up:    ld a,b
        cp 'a'
        jr c,.st
        cp 'z'+1
        jr nc,.st
        sub 20h
.st:    ld (de),a
        inc de
        ld a,e
        or a
        jr nz,.l
        jp err_syn
.dq:    ld a,'"'
        ld (inq),a
        ld a,b
        jr .st
.q:     ld a,b
        cp '"'
        jr nz,.st2
        xor a
        ld (inq),a
        ld a,b
.st2:   jr .st
.cmt:   ld a,(hl)
        or a
        jr z,.end
        inc hl
        cp 0Ah
        jr nz,.cmt
.end:   xor a
        ld (de),a
        ret

rdtok:                          ; HL -> TOKBUF (carattere di identificatore, max 11); B = lunghezza
        ld de,tokbuf
        ld b,0
.l:     ld a,(hl)
        call isid
        jr nc,.e
        ld a,b
        cp 11
        jr nc,.skip
        ld a,(hl)
        ld (de),a
        inc de
        inc b
.skip:  inc hl
        jr .l
.e:     xor a
        ld (de),a
        ret

asmline:
        ld a,1
        ld (itfirst),a
        ld a,'#'
        call wchar
        ld hl,LBUF
        call skipsp
        or a
        jp z,.eol
        push hl
        ld de,k_end
        call matchk
        pop hl
        jp z,.eol
        call rdtok
        ld a,b
        or a
        jp z,err_syn
        ld hl,tokbuf            ; T1 -> LABBUF
        ld de,labbuf
        ld bc,16
        ldir
        ld hl,LBUF
        call skipsp
        call skiptok            ; HL dopo T1
        ld (afterT1),hl
        call skipsp
        cp ':'
        jr nz,.nocolon
        inc hl
        call skipsp
        or a
        jr z,.labonly
        call rdtok
        ld a,b
        or a
        jp z,err_syn
        ld de,k_equ
        call tokeq
        jr z,.doequ
        push hl
        call deflabel
        pop hl
        jr .mnem
.nocolon:
        call rdtok
        ld a,b
        or a
        jr z,.mn1
        push hl
        ld de,k_equ
        call tokeq
        pop hl
        jr z,.doequ
.mn1:   ld hl,labbuf
        ld de,tokbuf
        ld bc,16
        ldir
        ld hl,(afterT1)
.mnem:  ld (textp),hl
        ld de,mnemtab
.ml:    ld a,(de)
        or a
        jp z,err_syn
        call tokeq
        jr z,.hit
        inc de
        inc de
        inc de
        jr .ml
.hit:   inc de
        ld a,(de)
        ld (cclass),a
        inc de
        ld a,(de)
        ld (cparam),a
        ld hl,(textp)
        call skipsp
        ld a,(cclass)
        cp 18
        jr nc,.dir
        call doops
        ld a,(cclass)
        add a,a
        ld e,a
        ld d,0
        ld hl,hjump
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)
.dir:   jp dirs
.labonly:
        call deflabel
        jr .eol
.doequ: call skipsp
        ld de,OP1BUF
        call getitem
        ld hl,OP1BUF
        ld a,(hl)
        or a
        jp z,err_syn
        ld ix,OP1
        ld de,OP1+O_N
        ld (ex_dst),de
        call expr
        ld a,(hl)
        or a
        jp nz,err_syn
        ld a,(ex_k)
        cp 2
        jp z,err_syn
        call defsym
.eol:   jp weol

skiptok:                        ; HL oltre un token di identificatore
.l:     ld a,(hl)
        call isid
        ret nc
        inc hl
        jr .l

tokeq:                          ; TOKBUF = stringa DE: Z se uguali; DE sul terminatore
        push hl
        ld hl,tokbuf
.l:     ld a,(de)
        cp (hl)
        jr nz,.n
        or a
        jr z,.y
        inc hl
        inc de
        jr .l
.n:     ld a,(de)
        or a
        jr z,.e
        inc de
        jr .n
.e:     or 1
.y:     pop hl
        ret

; ---------------------------------------------------------------- simboli
symfind:                        ; SYMKEY -> HL = record, NC se trovato; C altrimenti
        ld a,(nsym)
        or a
        scf
        ret z
        ld b,a
        ld hl,SYMTAB
.l:     push hl
        ld de,symkey
        ld c,12
.c:     ld a,(de)
        cp (hl)
        jr nz,.n
        inc hl
        inc de
        dec c
        jr nz,.c
        pop hl
        or a
        ret
.n:     pop hl
        ld de,15
        add hl,de
        djnz .l
        scf
        ret

mkkey:                          ; TOKBUF/LABBUF (HL) -> SYMKEY (12 byte, riempito con zeri)
        ld de,symkey
        ld b,12
.l:     ld a,(hl)
        ld (de),a
        or a
        jr z,.z
        inc hl
        inc de
        djnz .l
        ret
.z:     inc de
        dec b
        ret z
.zl:    xor a
        ld (de),a
        inc de
        djnz .zl
        ret

deflabel:                       ; LABBUF = etichetta relativa al blocco (solo prima passata)
        ld a,(pass)
        cp 1
        ret nz
        ld de,(pc_off)
        ld a,1
defsym2:
        push af
        push de
        ld hl,labbuf
        call mkkey
        call symfind
        jp nc,err_sym           ; duplicato
        ld a,(nsym)
        cp SYMMAX
        jp nc,err_sym
        ld e,a
        ld d,0
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; x15
        ld de,SYMTAB
        add hl,de
        ex de,hl                ; DE = record
        ld a,(nsym)
        inc a
        ld (nsym),a
        ld hl,symkey
        ld bc,12
        ldir
        pop hl                  ; valore
        pop af                  ; tipo
        ld (de),a
        inc de
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        ret

defsym:                         ; EQU: valore (ex_v), tipo (ex_k)
        ld a,(pass)
        cp 1
        ret nz
        ld de,(ex_v)
        ld a,(ex_k)
        jr defsym2

; ---------------------------------------------------------------- operandi
getitem:                        ; HL = testo, DE = destinazione: copia fino alla virgola (livello 0) senza spazi
        xor a
        ld (depth),a
.l:     ld a,(hl)
        or a
        jr z,.end
        ld b,a
        cp ','
        jr nz,.n1
        ld a,(depth)
        or a
        jr z,.endc
        jr .store
.n1:    cp ' '
        jr z,.skip
        cp 9
        jr z,.skip
        cp '('
        jr nz,.n2
        ld a,(depth)
        inc a
        ld (depth),a
        jr .store
.n2:    cp ')'
        jr nz,.n3
        ld a,(depth)
        dec a
        ld (depth),a
        jr .store
.n3:    cp '"'
        jr z,.q
        cp 27h
        jr nz,.store
        dec de
        ld a,(de)
        inc de
        call isid
        jr c,.store             ; AF'
        ld a,b
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        or a
        jp z,err_syn
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        cp 27h
        jp nz,err_syn
        ld (de),a
        inc de
        inc hl
        jr .l
.q:     ld (de),a
        inc de
        inc hl
.ql:    ld a,(hl)
        or a
        jp z,err_syn
        ld (de),a
        inc de
        inc hl
        cp '"'
        jr nz,.ql
        jr .l
.store: ld a,b
        ld (de),a
        inc de
.skip:  inc hl
        jr .l
.endc:  xor a
        ld (de),a
        ld a,','
        ret
.end:   xor a
        ld (de),a
        ret

doops:                          ; HL = testo: OP1, OP2
        ld de,OP1BUF
        call getitem
        or a
        jr z,.one
        inc hl
        ld de,OP2BUF
        call getitem
        or a
        jp nz,err_syn
        ld hl,OP2BUF
        ld ix,OP2
        call classify
        jr .c1
.one:   xor a
        ld (OP2+O_T),a
.c1:    ld hl,OP1BUF
        ld ix,OP1
        jp classify

classify:                       ; HL = testo operando, IX = struttura
        xor a
        ld (ix+O_T),a
        ld (ix+O_C),a
        ld (ix+O_P),a
        ld (ix+O_D),a
        ld (ix+O_K),a
        ld (ix+O_V),a
        ld (ix+O_V+1),a
        ld a,(hl)
        or a
        ret z
        ld de,regtab
.rl:    ld a,(de)
        or a
        jr z,.nf
        call streq
        jr z,.hit
        inc de
        inc de
        inc de
        inc de
        jr .rl
.hit:   inc de
        ld a,(de)
        ld (ix+O_T),a
        inc de
        ld a,(de)
        ld (ix+O_C),a
        inc de
        ld a,(de)
        ld (ix+O_P),a
        ret
.nf:    push ix
        pop de
        push hl
        ld hl,O_N
        add hl,de
        ld (ex_dst),hl
        pop hl
        ld a,(hl)
        cp '('
        jr nz,.imm
        push hl                 ; "(IX+", "(IX-", "(IY+", "(IY-"
        inc hl
        ld a,(hl)
        cp 'I'
        jr nz,.nidx
        inc hl
        ld a,(hl)
        ld b,0DDh
        cp 'X'
        jr z,.i2
        ld b,0FDh
        cp 'Y'
        jr nz,.nidx
.i2:    inc hl
        ld a,(hl)
        cp '+'
        jr z,.i3
        cp '-'
        jr nz,.nidx
.i3:    pop af                  ; scarta il vecchio HL
        ld (ix+O_P),b
        ld (ix+O_T),T_R8
        ld (ix+O_C),6
        call expr
        ld a,(hl)
        cp ')'
        jp nz,err_syn
        inc hl
        ld a,(hl)
        or a
        jp nz,err_syn
        ld a,(ex_k)
        or a
        jp nz,err_syn
        ld de,(ex_v)
        ld a,d
        or a
        jr z,.dok
        cp 0FFh
        jp nz,err_rng
        bit 7,e
        jp z,err_rng
.dok:   ld (ix+O_D),e
        ret
.nidx:  pop hl
        inc hl                  ; "(" espressione ")"
        call expr
        ld a,(hl)
        cp ')'
        jp nz,err_syn
        inc hl
        ld a,(hl)
        or a
        jp nz,err_syn
        ld (ix+O_T),T_MEM
        jr .val
.imm:   call expr
        ld a,(hl)
        or a
        jp nz,err_syn
        ld (ix+O_T),T_IMM
.val:   ld a,(ex_k)
        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        ret

streq:                          ; HL = testo, DE = nome: Z se coincide; DE sul terminatore; HL conservato
        push hl
.l:     ld a,(de)
        cp (hl)
        jr nz,.n
        or a
        jr z,.y
        inc hl
        inc de
        jr .l
.n:     ld a,(de)
        or a
        jr z,.e
        inc de
        jr .n
.e:     or 1
.y:     pop hl
        ret

; ---------------------------------------------------------------- espressioni
expr:                           ; HL = testo -> HL dopo l'espressione; DE = valore, A = tipo (0 ass., 1 rel., 2 esterno)
        ld de,0
        ld (ex_v),de
        xor a
        ld (ex_k),a
        ld a,'+'
        ld (ex_op),a
        ld a,(hl)
        cp '+'
        jr z,.sg
        cp '-'
        jr nz,.t
.sg:    ld (ex_op),a
        inc hl
.t:     call term
        call combine
        ld a,(hl)
        cp '+'
        jr z,.sg
        cp '-'
        jr z,.sg
        ld de,(ex_v)
        ld a,(ex_k)
        ret

combine:
        push hl
        ld a,(ex_op)
        cp '-'
        jr z,.sub
        ld a,(ex_k)
        or a
        jr z,.ad1
        ld a,(tk)
        or a
        jp nz,err_syn
        jr .addv
.ad1:   ld a,(tk)
        ld (ex_k),a
.addv:  ld hl,(ex_v)
        ld de,(tv)
        add hl,de
        ld (ex_v),hl
        pop hl
        ret
.sub:   ld a,(tk)
        or a
        jr z,.sv
        cp 1
        jp nz,err_syn
        ld a,(ex_k)
        cp 1
        jp nz,err_syn
        xor a
        ld (ex_k),a
.sv:    ld hl,(ex_v)
        ld de,(tv)
        or a
        sbc hl,de
        ld (ex_v),hl
        pop hl
        ret

term:                           ; HL = testo -> tv, tk; HL oltre il termine
        ld a,(hl)
        cp '$'
        jr z,.dollar
        cp 27h
        jr z,.char
        cp '%'
        jr z,.bin
        cp '0'
        jr c,.id
        cp '9'+1
        jr c,.num
.id:    and 0DFh
        cp 'A'
        jp c,err_syn
        cp 'Z'+1
        jp c,ident
        cp '_'
        jp z,ident
        jp err_syn
.char:  inc hl
        ld a,(hl)
        ld e,a
        ld d,0
        ld (tv),de
        inc hl
        ld a,(hl)
        cp 27h
        jp nz,err_syn
        inc hl
        xor a
        ld (tk),a
        ret
.dollar:
        inc hl
        ld a,(hl)
        call ishex
        jr c,.dhex
        ld de,(pc_off)
        ld (tv),de
        ld a,1
        ld (tk),a
        ret
.dhex:  ld c,16
        jr .pre
.bin:   inc hl
        ld c,2
.pre:   call rdnum
        push hl
        ld hl,ntok
        call pnum
        pop hl
        ret
.num:   call rdnum
        push hl
        call numbase
        call pnum
        pop hl
        ret

rdnum:                          ; HL = cifre -> NTOK (0-terminato); HL dopo le cifre
        ld de,ntok
.l:     ld a,(hl)
        call isalnum
        jr nc,.e
        ld (de),a
        inc de
        inc hl
        jr .l
.e:     xor a
        ld (de),a
        ret

numbase:                        ; NTOK -> HL = cifre, C = base (toglie il suffisso H/B)
        ld hl,ntok
        call strend
        dec hl
        ld a,(hl)
        cp 'H'
        jr nz,.nh
        ld (hl),0
        ld c,16
        ld hl,ntok
        ret
.nh:    ld a,(ntok)
        cp '0'
        jr nz,.nb
        ld a,(ntok+1)
        cp 'X'
        jr nz,.nb
        ld c,16
        ld hl,ntok+2
        ret
.nb:    ld a,(hl)
        cp 'B'
        jr nz,.dec
        ld de,ntok
.bl:    ld a,(de)
        cp 'B'
        jr z,.isb
        cp '0'
        jr z,.bn
        cp '1'
        jr nz,.dec
.bn:    inc de
        jr .bl
.isb:   ld (hl),0
        ld c,2
        ld hl,ntok
        ret
.dec:   ld c,10
        ld hl,ntok
        ret

strend:                         ; HL -> terminatore
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        jr .l

isalnum:                        ; CF = 1 se 0-9 A-Z
        cp '0'
        jr c,.n
        cp '9'+1
        jr c,.y
        cp 'A'
        jr c,.n
        cp 'Z'+1
        jr c,.y
.n:     or a
        ret
.y:     scf
        ret

ishex:                          ; CF = 1 se cifra esadecimale
        cp '0'
        jr c,.n
        cp '9'+1
        jr c,.y
        cp 'A'
        jr c,.n
        cp 'F'+1
        jr c,.y
.n:     or a
        ret
.y:     scf
        ret

pnum:                           ; HL = cifre (0-terminate), C = base -> tv, tk = 0
        ld a,c
        ld (nbase),a
        ld de,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc hl
        sub '0'
        cp 10
        jr c,.dg
        sub 'A'-'0'-10
.dg:    ld b,a
        ld a,(nbase)
        dec a
        cp b
        jp c,err_syn            ; cifra >= base
        push bc
        ld a,(nbase)
        call mulacc
        pop bc
        ld a,b
        add a,e
        ld e,a
        jr nc,.l
        inc d
        jr .l
.d:     ld (tv),de
        xor a
        ld (tk),a
        ret

mulacc:                         ; DE = DE * base (base = 2, 10 o 16)
        cp 16
        jr z,.m16
        cp 10
        jr z,.m10
        ex de,hl                ; x2
        add hl,hl
        ex de,hl
        ret
.m16:   ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ret
.m10:   ex de,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ex de,hl
        ret

ident:                          ; HL = inizio dell'identificatore
        push hl
        call rdtok
        push hl                 ; fine
        ld hl,tokbuf
        call mkkey
        call symfind
        jr c,.unk
        ld de,12
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (tv),de
        ld (tk),a
        pop hl
        pop de
        ret
.unk:   ld a,(pass)
        cp 1
        jr nz,.ext
        ld de,0
        ld (tv),de
        xor a
        ld (tk),a
        pop hl
        pop de
        ret
.ext:   pop bc
        pop hl
        ld de,(ex_dst)
.cp:    ld a,(hl)
        call isid
        jr nc,.cd
        ld (de),a
        inc hl
        inc de
        jr .cp
.cd:    xor a
        ld (de),a
        ld de,0
        ld (tv),de
        ld a,2
        ld (tk),a
        ret

; ---------------------------------------------------------------- gestori
hjump:  dw h_imp1,h_imp2,h_alu,h_incdec,h_ld,h_jp,h_call,h_jr,h_djnz,h_ret,h_rst,h_pushpop,h_ex,h_rot,h_bit,h_im,h_in,h_out

h_imp1: ld a,(cparam)
        call emb
        jp asmline.eol
h_imp2: ld a,0EDh
        call emb
        ld a,(cparam)
        call emb
        jp asmline.eol

cond_of:                        ; IX = operando -> A = codice (0-7), CF = 1 se non e' una condizione
        ld a,(ix+O_T)
        cp T_COND
        jr nz,.r8
        ld a,(ix+O_C)
        or a
        ret
.r8:    cp T_R8
        jr nz,.no
        ld a,(ix+O_P)
        or a
        jr nz,.no
        ld a,(ix+O_C)
        cp 1
        jr nz,.no
        ld a,3
        or a
        ret
.no:    scf
        ret

h_alu:  ld a,(OP2+O_T)
        or a
        jr nz,.two
        ld ix,OP1
        jr .tgt
.two:   ld a,(OP1+O_T)
        cp T_R16
        jr z,.w16
        cp T_R8
        jp nz,err_syn
        ld a,(OP1+O_C)
        cp 7
        jp nz,err_syn
        ld a,(OP1+O_P)
        or a
        jp nz,err_syn
        ld ix,OP2
.tgt:   ld a,(ix+O_T)
        cp T_R8
        jr z,.reg
        cp T_IMM
        jp nz,err_syn
        ld a,(cparam)
        add a,a
        add a,a
        add a,a
        add a,0C6h
        call emb
        call emb8
        jp asmline.eol
.reg:   call emp
        ld a,(cparam)
        add a,a
        add a,a
        add a,a
        add a,80h
        add a,(ix+O_C)
        call emb
        call emdisp
        jp asmline.eol
.w16:   ld a,(OP1+O_C)
        cp 2
        jp nz,err_syn
        ld a,(OP2+O_T)
        cp T_R16
        jp nz,err_syn
        ld ix,OP1
        ld a,(cparam)
        or a
        jr z,.add
        ld b,4Ah
        cp 1
        jr z,.ed
        ld b,42h
        cp 3
        jp nz,err_syn
.ed:    ld a,(OP1+O_P)
        or a
        jp nz,err_syn           ; ADC/SBC solo HL
        ld a,0EDh
        call emb
        ld a,(OP2+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        call emb
        jp asmline.eol
.add:   call emp
        ld a,(OP2+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,9
        call emb
        jp asmline.eol

h_incdec:
        ld ix,OP1
        ld a,(OP1+O_T)
        cp T_R8
        jr z,.r8
        cp T_R16
        jp nz,err_syn
        call emp
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(cparam)
        or a
        ld a,3
        jr z,.w
        ld a,0Bh
.w:     add a,b
        call emb
        jp asmline.eol
.r8:    call emp
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(cparam)
        or a
        ld a,4
        jr z,.b
        ld a,5
.b:     add a,b
        call emb
        call emdisp
        jp asmline.eol

h_ld:   ld a,(OP1+O_T)
        cp T_R8
        jp z,ld_r8
        cp T_R16
        jp z,ld_r16
        cp T_MEM
        jp z,ld_mem
        cp T_IBC
        jr nz,.n1
        ld a,02h
        jr .ia
.n1:    cp T_IDE
        jr nz,.n2
        ld a,12h
.ia:    ld b,a
        ld a,(OP2+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,(OP2+O_C)
        cp 7
        jp nz,err_syn
        ld a,(OP2+O_P)
        or a
        jp nz,err_syn
        ld a,b
        call emb
        jp asmline.eol
.n2:    cp T_I
        ld b,47h
        jr z,.ir
        cp T_R
        jp nz,err_syn
        ld b,4Fh
.ir:    ld a,(OP2+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,(OP2+O_C)
        cp 7
        jp nz,err_syn
        ld a,0EDh
        call emb
        ld a,b
        call emb
        jp asmline.eol

ld_mem:                         ; LD (nn),src
        ld a,(OP2+O_T)
        cp T_R8
        jr z,.a
        cp T_R16
        jp nz,err_syn
        ld ix,OP2
        ld a,(OP2+O_C)
        cp 2
        jr nz,.rr
        call emp
        ld a,22h
        call emb
        jr .addr
.rr:    ld a,0EDh
        call emb
        ld a,(OP2+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,43h
        call emb
.addr:  ld ix,OP1
        call emitv
        jp asmline.eol
.a:     ld a,(OP2+O_C)
        cp 7
        jp nz,err_syn
        ld a,(OP2+O_P)
        or a
        jp nz,err_syn
        ld a,32h
        call emb
        jr .addr

ld_r16:
        ld a,(OP2+O_T)
        cp T_IMM
        jr z,.imm
        cp T_MEM
        jr z,.mem
        cp T_R16
        jp nz,err_syn
        ld a,(OP1+O_C)          ; LD SP,HL/IX/IY
        cp 3
        jp nz,err_syn
        ld a,(OP2+O_C)
        cp 2
        jp nz,err_syn
        ld ix,OP2
        call emp
        ld a,0F9h
        call emb
        jp asmline.eol
.imm:   ld ix,OP1
        call emp
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        inc a
        call emb
        ld ix,OP2
        call emitv
        jp asmline.eol
.mem:   ld a,(OP1+O_C)
        cp 2
        jr nz,.rr
        ld ix,OP1
        call emp
        ld a,2Ah
        call emb
        jr .addr
.rr:    ld a,0EDh
        call emb
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,4Bh
        call emb
.addr:  ld ix,OP2
        call emitv
        jp asmline.eol

ld_r8:  ld a,(OP2+O_T)
        cp T_R8
        jp z,.rr
        cp T_IMM
        jr z,.imm
        cp T_MEM
        jr z,.mem
        cp T_IBC
        ld b,0Ah
        jr z,.ia
        cp T_IDE
        ld b,1Ah
        jr z,.ia
        cp T_I
        ld b,57h
        jr z,.ir
        cp T_R
        ld b,5Fh
        jp nz,err_syn
.ir:    ld a,(OP1+O_C)
        cp 7
        jp nz,err_syn
        ld a,(OP1+O_P)
        or a
        jp nz,err_syn
        ld a,0EDh
        call emb
        ld a,b
        call emb
        jp asmline.eol
.ia:    ld a,(OP1+O_C)
        cp 7
        jp nz,err_syn
        ld a,(OP1+O_P)
        or a
        jp nz,err_syn
        ld a,b
        call emb
        jp asmline.eol
.imm:   ld ix,OP1
        call emp
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,6
        call emb
        call emdisp
        ld ix,OP2
        call emb8
        jp asmline.eol
.mem:   ld a,(OP1+O_C)
        cp 7
        jp nz,err_syn
        ld a,(OP1+O_P)
        or a
        jp nz,err_syn
        ld a,3Ah
        call emb
        ld ix,OP2
        call emitv
        jp asmline.eol
.rr:    ld a,(OP1+O_P)
        ld b,a
        ld a,(OP2+O_P)
        ld c,a
        ld a,b
        or a
        jr z,.o1
        ld a,c
        or a
        jp nz,err_syn           ; entrambi indicizzati
        ld ix,OP1
        jr .chk
.o1:    ld ix,OP2
.chk:   ld a,(OP1+O_C)
        cp 6
        jr nz,.ok
        ld a,(OP2+O_C)
        cp 6
        jp z,err_syn            ; LD (HL),(HL)
.ok:    call emp
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,40h
        ld hl,OP2+O_C
        add a,(hl)
        call emb
        call emdisp
        jp asmline.eol

h_jp:   ld ix,OP1
        ld a,(OP2+O_T)
        or a
        jr nz,.cc
        ld a,(OP1+O_T)
        cp T_R8
        jr nz,.nn
        ld a,(OP1+O_C)
        cp 6
        jp nz,err_syn
        call emp
        ld a,0E9h
        call emb
        jp asmline.eol
.nn:    cp T_IMM
        jp nz,err_syn
        ld a,0C3h
        call emjump
        jp asmline.eol
.cc:    call cond_of
        jp c,err_syn
        add a,a
        add a,a
        add a,a
        add a,0C2h
        ld ix,OP2
        ld b,a
        ld a,(ix+O_T)
        cp T_IMM
        jp nz,err_syn
        ld a,b
        call emjump
        jp asmline.eol

h_call: ld ix,OP1
        ld a,(OP2+O_T)
        or a
        jr nz,.cc
        ld a,(OP1+O_T)
        cp T_IMM
        jp nz,err_syn
        ld a,0CDh
        call emjump
        jp asmline.eol
.cc:    call cond_of
        jp c,err_syn
        add a,a
        add a,a
        add a,a
        add a,0C4h
        ld ix,OP2
        ld b,a
        ld a,(ix+O_T)
        cp T_IMM
        jp nz,err_syn
        ld a,b
        call emjump
        jp asmline.eol

jr_target:                      ; IX = operando: A = spostamento (pc_off e' gia' oltre l'opcode)
        ld a,(pass)
        cp 2
        jr z,.p2
        xor a
        ret
.p2:    ld a,(ix+O_K)
        cp 1
        jp nz,err_syn
        ld l,(ix+O_V)
        ld h,(ix+O_V+1)
        ld de,(pc_off)
        inc de
        or a
        sbc hl,de
        ld e,l
        ld a,h
        or a
        jr z,.pos
        cp 0FFh
        jp nz,err_rng
        bit 7,e
        jp z,err_rng
        jr .o
.pos:   bit 7,e
        jp nz,err_rng
.o:     ld a,e
        ret

h_jr:   ld a,(OP2+O_T)
        or a
        jr nz,.cc
        ld ix,OP1
        ld a,18h
        jr .go
.cc:    ld ix,OP1
        call cond_of
        jp c,err_syn
        cp 4
        jp nc,err_syn
        add a,a
        add a,a
        add a,a
        add a,20h
        ld ix,OP2
.go:    call emb
        ld a,(ix+O_T)
        cp T_IMM
        jp nz,err_syn
        call jr_target
        call emb
        jp asmline.eol

h_djnz: ld ix,OP1
        ld a,10h
        call emb
        ld a,(ix+O_T)
        cp T_IMM
        jp nz,err_syn
        call jr_target
        call emb
        jp asmline.eol

h_ret:  ld a,(OP1+O_T)
        or a
        jr nz,.cc
        ld a,0C9h
        call emb
        jp asmline.eol
.cc:    ld ix,OP1
        call cond_of
        jp c,err_syn
        add a,a
        add a,a
        add a,a
        add a,0C0h
        call emb
        jp asmline.eol

h_rst:  ld ix,OP1
        ld a,(ix+O_T)
        cp T_IMM
        jp nz,err_syn
        ld a,(ix+O_K)
        or a
        jp nz,err_syn
        ld a,(ix+O_V+1)
        or a
        jp nz,err_rng
        ld a,(ix+O_V)
        and 0C7h
        jp nz,err_rng
        ld a,(ix+O_V)
        add a,0C7h
        call emb
        jp asmline.eol

h_pushpop:
        ld a,(OP1+O_T)
        cp T_AF
        ld b,3
        jr z,.go
        cp T_R16
        jp nz,err_syn
        ld a,(OP1+O_C)
        cp 3
        jp z,err_syn
        ld b,a
.go:    ld ix,OP1
        call emp
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld hl,cparam
        add a,(hl)
        call emb
        jp asmline.eol

h_ex:   ld a,(OP1+O_T)
        cp T_R16
        jr z,.de
        cp T_AF
        jr z,.af
        cp T_ISP
        jp nz,err_syn
        ld a,(OP2+O_T)
        cp T_R16
        jp nz,err_syn
        ld a,(OP2+O_C)
        cp 2
        jp nz,err_syn
        ld ix,OP2
        call emp
        ld a,0E3h
        call emb
        jp asmline.eol
.de:    ld a,(OP1+O_C)
        cp 1
        jp nz,err_syn
        ld a,(OP2+O_T)
        cp T_R16
        jp nz,err_syn
        ld a,(OP2+O_C)
        cp 2
        jp nz,err_syn
        ld a,(OP2+O_P)
        or a
        jp nz,err_syn
        ld a,0EBh
        call emb
        jp asmline.eol
.af:    ld a,(OP2+O_T)
        cp T_AFP
        jp nz,err_syn
        ld a,08h
        call emb
        jp asmline.eol

h_rot:  ld a,(cparam)
        ld c,a
        ld ix,OP1
        jp cbop
h_bit:  ld ix,OP2
        ld a,(OP1+O_T)
        cp T_IMM
        jp nz,err_syn
        ld a,(OP1+O_K)
        or a
        jp nz,err_syn
        ld a,(OP1+O_V+1)
        or a
        jp nz,err_rng
        ld a,(OP1+O_V)
        cp 8
        jp nc,err_rng
        add a,a
        add a,a
        add a,a
        ld hl,cparam
        add a,(hl)
        ld c,a
        jp cbop
cbop:                           ; IX = registro/indicizzato, C = base: [prefisso] CB [spostamento] base+r
        ld a,(ix+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,(ix+O_P)
        or a
        jr z,.plain
        call emp
        ld a,0CBh
        call emb
        ld a,(ix+O_D)
        call emb
        ld a,c
        add a,6
        call emb
        jp asmline.eol
.plain: ld a,0CBh
        call emb
        ld a,c
        add a,(ix+O_C)
        call emb
        jp asmline.eol

h_im:   ld ix,OP1
        ld a,(ix+O_T)
        cp T_IMM
        jp nz,err_syn
        ld a,(ix+O_V)
        ld b,46h
        or a
        jr z,.go
        ld b,56h
        cp 1
        jr z,.go
        ld b,5Eh
        cp 2
        jp nz,err_rng
.go:    ld a,0EDh
        call emb
        ld a,b
        call emb
        jp asmline.eol

h_in:   ld a,(OP2+O_T)
        cp T_IC
        jr z,.c
        cp T_MEM
        jp nz,err_syn
        ld a,(OP1+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,(OP1+O_C)
        cp 7
        jp nz,err_syn
        ld a,0DBh
        call emb
        ld ix,OP2
        call emb8
        jp asmline.eol
.c:     ld a,(OP1+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,0EDh
        call emb
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,40h
        call emb
        jp asmline.eol

h_out:  ld a,(OP1+O_T)
        cp T_IC
        jr z,.c
        cp T_MEM
        jp nz,err_syn
        ld a,(OP2+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,(OP2+O_C)
        cp 7
        jp nz,err_syn
        ld a,0D3h
        call emb
        ld ix,OP1
        call emb8
        jp asmline.eol
.c:     ld a,(OP2+O_T)
        cp T_R8
        jp nz,err_syn
        ld a,0EDh
        call emb
        ld a,(OP2+O_C)
        add a,a
        add a,a
        add a,a
        add a,41h
        call emb
        jp asmline.eol

; ---------------------------------------------------------------- DB / DW / DS
dirs:                           ; HL = testo dopo il mnemonico
        ld a,(cclass)
        cp 20
        jp z,.ds
        cp 19
        jp z,.dw
.db:    ld de,OP1BUF
        call getitem
        push af
        push hl
        ld hl,OP1BUF
        ld a,(hl)
        or a
        jp z,err_syn
        cp '"'
        jr z,.str
        ld ix,OP1
        ld de,OP1+O_N
        ld (ex_dst),de
        call expr
        ld a,(hl)
        or a
        jp nz,err_syn
        ld a,(ex_k)
        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        call emb8
        jr .nx
.str:   inc hl
.sl:    ld a,(hl)
        cp '"'
        jr z,.nx
        or a
        jp z,err_syn
        call emb
        inc hl
        jr .sl
.nx:    pop hl
        pop af
        or a
        jp z,asmline.eol
        inc hl
        jr .db
.dw:    ld de,OP1BUF
        call getitem
        push af
        push hl
        ld hl,OP1BUF
        ld a,(hl)
        or a
        jp z,err_syn
        ld ix,OP1
        ld de,OP1+O_N
        ld (ex_dst),de
        call expr
        ld a,(hl)
        or a
        jp nz,err_syn
        ld a,(ex_k)
        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        call emitv
        pop hl
        pop af
        or a
        jp z,asmline.eol
        inc hl
        jr .dw
.ds:    ld de,OP1BUF
        call getitem
        push af
        push hl
        ld ix,OP1
        ld hl,OP1BUF
        ld de,OP1+O_N
        ld (ex_dst),de
        call expr
        ld a,(hl)
        or a
        jp nz,err_syn
        ld a,(ex_k)
        or a
        jp nz,err_syn
        ld (tmpw),de            ; contatore
        pop hl
        pop af
        ld c,0
        or a
        jr z,.dsgo
        inc hl
        ld de,OP2BUF
        call getitem
        ld hl,OP2BUF
        ld ix,OP2
        ld de,OP2+O_N
        ld (ex_dst),de
        call expr
        ld a,(ex_k)
        or a
        jp nz,err_syn
        ld a,e
        ld c,a
.dsgo:  ld hl,(tmpw)
.dl:    ld a,h
        or l
        jp z,asmline.eol
        push hl
        ld a,c
        call emb
        pop hl
        dec hl
        jr .dl

; ---------------------------------------------------------------- tabelle
        MACRO REG n,t,c,p
        db n,0,t,c,p
        ENDM
regtab:
        REG "B",T_R8,0,0
        REG "C",T_R8,1,0
        REG "D",T_R8,2,0
        REG "E",T_R8,3,0
        REG "H",T_R8,4,0
        REG "L",T_R8,5,0
        REG "(HL)",T_R8,6,0
        REG "A",T_R8,7,0
        REG "(IX)",T_R8,6,0DDh
        REG "(IY)",T_R8,6,0FDh
        REG "BC",T_R16,0,0
        REG "DE",T_R16,1,0
        REG "HL",T_R16,2,0
        REG "SP",T_R16,3,0
        REG "IX",T_R16,2,0DDh
        REG "IY",T_R16,2,0FDh
        REG "AF",T_AF,0,0
        db 'A','F',27h,0,T_AFP,0,0
        REG "(BC)",T_IBC,0,0
        REG "(DE)",T_IDE,0,0
        REG "(SP)",T_ISP,0,0
        REG "(C)",T_IC,0,0
        REG "NZ",T_COND,0,0
        REG "Z",T_COND,1,0
        REG "NC",T_COND,2,0
        REG "PO",T_COND,4,0
        REG "PE",T_COND,5,0
        REG "P",T_COND,6,0
        REG "M",T_COND,7,0
        REG "I",T_I,0,0
        REG "R",T_R,0,0
        db 0

        MACRO MN n,c,p
        db n,0,c,p
        ENDM
mnemtab:
        MN "NOP",0,00h
        MN "HALT",0,76h
        MN "EXX",0,0D9h
        MN "DI",0,0F3h
        MN "EI",0,0FBh
        MN "DAA",0,27h
        MN "CPL",0,2Fh
        MN "SCF",0,37h
        MN "CCF",0,3Fh
        MN "RLCA",0,07h
        MN "RRCA",0,0Fh
        MN "RLA",0,17h
        MN "RRA",0,1Fh
        MN "NEG",1,44h
        MN "RETN",1,45h
        MN "RETI",1,4Dh
        MN "RRD",1,67h
        MN "RLD",1,6Fh
        MN "LDI",1,0A0h
        MN "LDIR",1,0B0h
        MN "LDD",1,0A8h
        MN "LDDR",1,0B8h
        MN "CPI",1,0A1h
        MN "CPIR",1,0B1h
        MN "CPD",1,0A9h
        MN "CPDR",1,0B9h
        MN "INI",1,0A2h
        MN "INIR",1,0B2h
        MN "IND",1,0AAh
        MN "INDR",1,0BAh
        MN "OUTI",1,0A3h
        MN "OTIR",1,0B3h
        MN "OUTD",1,0ABh
        MN "OTDR",1,0BBh
        MN "ADD",2,0
        MN "ADC",2,1
        MN "SUB",2,2
        MN "SBC",2,3
        MN "AND",2,4
        MN "XOR",2,5
        MN "OR",2,6
        MN "CP",2,7
        MN "INC",3,0
        MN "DEC",3,1
        MN "LD",4,0
        MN "JP",5,0
        MN "CALL",6,0
        MN "JR",7,0
        MN "DJNZ",8,0
        MN "RET",9,0
        MN "RST",10,0
        MN "PUSH",11,0C5h
        MN "POP",11,0C1h
        MN "EX",12,0
        MN "RLC",13,00h
        MN "RRC",13,08h
        MN "RL",13,10h
        MN "RR",13,18h
        MN "SLA",13,20h
        MN "SRA",13,28h
        MN "SLL",13,30h
        MN "SRL",13,38h
        MN "BIT",14,40h
        MN "RES",14,80h
        MN "SET",14,0C0h
        MN "IM",15,0
        MN "IN",16,0
        MN "OUT",17,0
        MN "DB",18,0
        MN "DEFB",18,0
        MN "DW",19,0
        MN "DEFW",19,0
        MN "DS",20,0
        MN "DEFS",20,0
        db 0

        ASSERT $ < VARS
