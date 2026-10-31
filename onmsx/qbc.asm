; =====================================================================
; MSXQB compilatore su MSX (QBC.COM) - stadio 1
; BASIC -> codice macchina Z80 (programma .COM con il runtime rtcom.asm).
; Una passata, emissione diretta; HL = accumulatore, operando sinistro sullo stack.
; Input: riga di comando " NOME.BAS"  ->  scrive NOME.COM e lo avvia.
; Errore: ricarica l'editor con " NOME.BAS E<riga> <codice>".
; Memoria: codice 0100h-39FFh, tabelle 3A00h-49FFh, sorgente 4A00h-7FFFh,
;          output 8000h-BEFFh (indirizzi virtuali da 0100h: virt = fisico - 7F00h).
; =====================================================================
        INCLUDE "rtabi.inc"
BDOS    equ 0005h
F_OPEN  equ 0Fh
F_CLOSE equ 10h
F_DEL   equ 13h
F_MAKE  equ 16h
F_DMA   equ 1Ah
F_BWR   equ 26h
F_BRD   equ 27h

        IFDEF ROMMODE
SRC     equ 4400h               ; il compilatore per cartucce non ha OPTION NUMBERED: le tabelle stanno nella RAM alta
SRCMAX  equ 3BFEh
        ELSE
SRC     equ 4A00h
SRCMAX  equ 35FEh
        ENDIF
OUT0    equ 8000h
        IFDEF ROMMODE
HDRB    equ OUT0+(RT_EMPTY-IMGBASE)     ; intestazione del runtime dentro il buffer (il runtime e' nel buffer)
        ELSE
HDRB    equ ST+232              ; .COM: il runtime non sta nel buffer (si copia dal file RT.BIN): i campi si tengono qui
        ENDIF
HDRNAME equ HDRB+(RT_NAME-RT_EMPTY)
HDRDSZ  equ HDRB+(RT_DSIZE-RT_EMPTY)
HDRDAT  equ HDRB+(RT_DATA0-RT_EMPTY)
HDRTGT  equ HDRB+(RT_TARGET-RT_EMPTY)
HDRLEN  equ RT_TARGET+1-RT_EMPTY
rtsz    equ ST+254              ; w  dimensione di RT.BIN (.COM)
        IFDEF ROMMODE
IMGBASE equ 4000h               ; indirizzo virtuale dell'inizio dell'immagine (cartuccia in pagina 1)
        ELSE
IMGBASE equ 0100h
        ENDIF
OUTLIM  equ 0BFh                ; alto byte: oltre BF00h il programma e' troppo grande
LDR     equ 0C000h

        IFDEF ROMMODE
LABT    equ 0CA00h
        ELSE
LABT    equ 3A00h               ; etichette: 96 x 20 byte
        ENDIF
LABREC  equ 20
MAXLAB  equ 96
        IFDEF ROMMODE
VART    equ 0D180h
        ELSE
VART    equ 4180h               ; variabili/array: 100 x 16 byte
        ENDIF
VARREC  equ 16
MAXVAR  equ 100
        IFDEF ROMMODE
BLKS    equ 0D7C0h
        ELSE
BLKS    equ 47C0h               ; stack dei blocchi: 24 x 10 byte
        ENDIF
BLKREC  equ 10
MAXBLK  equ 24

ST      equ 0C100h
lp      equ ST+0                ; w  puntatore nel sorgente
lineno  equ ST+2                ; w  riga corrente
tline   equ ST+4                ; w  riga del token corrente
ttype   equ ST+6                ; b
tval    equ ST+7                ; w
tlen    equ ST+9                ; b  lunghezza stringa
tsuf    equ ST+10               ; b  suffisso '$' presente
iseof   equ ST+11               ; b
tbuf    equ ST+12               ; 16 byte: identificatore maiuscolo (0-terminato)
LEXSZ   equ 28
lexsv   equ ST+32
outp    equ ST+64               ; w  puntatore fisico di emissione
nlab    equ ST+66
nvar    equ ST+67
nblk    equ ST+68
errcode equ ST+69
tmpv    equ ST+70               ; w
tmps    equ ST+72               ; w
namep   equ ST+74               ; w
fname   equ ST+80               ; 16 byte
oname   equ ST+96               ; 16 byte
fcb     equ ST+112              ; 37 byte
mode    equ ST+150              ; b  0 mista, 1 NUMBERED, 2 LABELS
onel    equ ST+151              ; b  line_loop si ferma a fine riga
entp    equ ST+152              ; w
entend  equ ST+154              ; w
en_num  equ ST+156              ; w
en_ptr  equ ST+158              ; w
en_ln   equ ST+160              ; w
en_pos  equ ST+162              ; w
etype   equ ST+164              ; b  tipo dell'ultima espressione (0 intero, 1 stringa)
tmpf    equ ST+165              ; b  l'istruzione ha creato stringhe temporanee
dptr    equ ST+166              ; w  prossimo byte libero nell'area dati del programma
dlim    equ ST+168              ; w  limite dell'area dati
nbuf    equ ST+170              ; 16 byte: nome normalizzato (per le funzioni predefinite)
vtyp    equ ST+186              ; b  tipo dell'ultima variabile cercata
fi_s    equ ST+188              ; w
voff    equ ST+220              ; w  fisico - virtuale (cambia con il segmento)
outlim  equ ST+222              ; b  alto byte oltre il quale l'output e' troppo grande
target  equ ST+223              ; b  tipo di cartuccia (0 COM)
curseg  equ ST+224              ; b  segmento in compilazione (0 = fisso)
pseg    equ ST+225              ; b  segmento corrente durante la pre-scansione
nfar    equ ST+226              ; b  voci usate in FARTAB
romopen equ ST+227              ; b  il file ROM e' gia' stato creato
        IFDEF ROMMODE
FARTABC equ 3C00h
SEGT    equ 3C80h
FCBSV   equ 3CA8h
FARX    equ 3C94h
        ELSE
FARTABC equ 48C0h               ; FARTAB in costruzione: 32 x 4 byte (banco, 0, indirizzo)
SEGT    equ 4940h               ; segmento di ogni SUB/FUNCTION (indice nel record)
FCBSV   equ 4968h               ; copia dell'FCB di uscita durante INCBIN
FARX    equ 4954h               ; indice FARTAB di ogni SUB/FUNCTION (FFh = nessuno)
        ENDIF
usewin  equ ST+216              ; b  il sorgente usa WINDOW: le coordinate grafiche vengono convertite
nfunc   equ ST+192              ; b
npart   equ ST+193              ; b
nloc    equ ST+194              ; b
nint    equ ST+195              ; b  variabili intere locali create
nstr    equ ST+196              ; b  stringhe locali create
tmpk    equ ST+197              ; b  tipo di riferimento a variabile (vedi emit_ldv)
ca_i    equ ST+198              ; b  chiamata in corso: indice dell'argomento
ca_paren equ ST+199             ; b  chiamata in corso: parentesi presente
mapf    equ ST+228              ; b  DIM ... MAPPER in corso
mapcnt  equ ST+229              ; w  numero di elementi dell'array nel mapper
fcur    equ ST+200              ; w  record della funzione in compilazione (0 = livello principale)
fexit   equ ST+202              ; w  catena degli EXIT SUB/FUNCTION
fskiph  equ ST+204              ; w  catena del salto che scavalca il corpo
framep  equ ST+206              ; w  indirizzo fisico dell'operando del frame
ca_rec  equ ST+208              ; w  chiamata in corso: record
chfail  equ ST+210              ; w  catena per CASE a TO b
rf_rec  equ ST+212              ; w
ENT     equ 0CA00h              ; indice righe NUMBERED: 6 byte (numero, puntatore, riga) in RAM alta
ENTMAX  equ 0D7F0h
FUNT    equ 0C220h              ; SUB/FUNCTION: 20 x 24 byte (RAM alta, solo durante la compilazione)
FUNREC  equ 24
MAXFUN  equ 20
PART    equ 0C600h               ; parametri: 64 x 16 byte (nome 12, tipo)
MAXPAR  equ 64
LOCT    equ 0C400h               ; locali/parametri della funzione in compilazione: 24 x 16 byte
MAXLOC  equ 32

T_EOL   equ 0
T_NUM   equ 1
T_ID    equ 2
T_STR   equ 3
T_KW    equ 4
T_P     equ 5

K_PRINT equ 0
K_IF    equ 1
K_THEN  equ 2
K_ELSE  equ 3
K_ELSEIF equ 4
K_END   equ 5
K_FOR   equ 6
K_TO    equ 7
K_STEP  equ 8
K_NEXT  equ 9
K_WHILE equ 10
K_WEND  equ 11
K_GOTO  equ 12
K_GOSUB equ 13
K_RETURN equ 14
K_CLS   equ 15
K_LOCATE equ 16
K_AND   equ 17
K_OR    equ 18
K_XOR   equ 19
K_NOT   equ 20
K_MOD   equ 21
K_LET   equ 22
K_OPTION equ 23
K_INPUT equ 24
K_DIM   equ 25
K_POKE  equ 26
K_SUB   equ 27
K_FUNCTION equ 28
K_CALL  equ 29
K_DECLARE equ 30
K_SHARED equ 31
K_EXIT  equ 32
K_DO    equ 33
K_LOOP  equ 34
K_UNTIL equ 35
K_SELECT equ 36
K_CASE  equ 37
K_IS    equ 38
K_CONST equ 39
K_COLOR equ 40
K_RANDOMIZE equ 41
K_VPOKE equ 42
K_OUT   equ 43
K_SLEEP equ 44
K_STOP  equ 45
K_SCREEN equ 46
K_PSET  equ 47
K_PRESET equ 48
K_LINE  equ 49
K_CIRCLE equ 50
K_PALETTE equ 51
K_PAINT equ 52
K_PUT   equ 53
K_SPRITE equ 54
K_GET   equ 55
K_DRAW  equ 56
K_VIEW  equ 57
K_WINDOW equ 58
K_VBANK equ 59
K_VFILL equ 60
K_VWRITE equ 61
K_SET equ 62
K_COPY equ 63
K_DATA equ 64
K_READ equ 65
K_RESTORE equ 66
K_BEEP equ 67
K_SOUND equ 68
K_PLAY equ 69
K_OPEN equ 70
K_CLOSE equ 71
K_KILL equ 72
K_WRITE equ 73
K_SEGMENT equ 74
K_INCBIN equ 75
K_SETBANK equ 76
K_VCOPY equ 77
K_MPUT equ 78
K_MREAD equ 79
K_MWRITE equ 80
K_MFREE equ 81
K_BLOAD equ 82
K_BSAVE equ 83
K_FIELD equ 84
K_LSET equ 85
K_RSET equ 86

B_IF    equ 1
B_FOR   equ 2
B_WHILE equ 3
B_DO    equ 4
B_SEL   equ 5

E_SYNTAX equ 1
E_LABEL equ 2
E_UNSUP equ 3
E_CHAR  equ 4
E_OPEN  equ 5
E_MISM  equ 6
E_DUP   equ 7
E_MANY  equ 8
E_BIG   equ 9
E_SRCBIG equ 10
E_READ  equ 11
E_WRITE equ 12
E_MODE  equ 13
E_TYPE  equ 14
E_MEM   equ 15
E_RT    equ 16

        MACRO EM1 a
        call emit_i
        db 1,a
        ENDM
        MACRO EM2 a,b
        call emit_i
        db 2,a,b
        ENDM
        MACRO EM3 a,b,c
        call emit_i
        db 3,a,b,c
        ENDM
        MACRO EM4 a,b,c,d
        call emit_i
        db 4,a,b,c,d
        ENDM
        MACRO EM6 a,b,c,d,e,f
        call emit_i
        db 6,a,b,c,d,e,f
        ENDM
        MACRO EM7 a,b,c,d,e,f,g
        call emit_i
        db 7,a,b,c,d,e,f,g
        ENDM
        MACRO ERR n
        ld a,n
        jp error
        ENDM

        DEVICE NOSLOT64K
        ORG 0100h
start:
        ld hl,(0006h)
        ld sp,hl
        call getname
        call read_source
        IFNDEF ROMMODE
        call chk_rom
        ENDIF
        call compile
        IFDEF ROMMODE
        call rom_finish
        jp rom_done
        ELSE
        call write_output
        ENDIF
        ; avvia il programma dal disco: il caricatore (a C000h) legge NOME.COM
        ld hl,oname
        ld (namep),hl
        call mk_fcb
        ld hl,ldr_img
        ld de,LDR
        ld bc,ldr_size
        ldir
        ld hl,fcb+1
        ld de,LDR+3
        ld bc,11
        ldir
        jp LDR

; ---------------------------------------------------------------- errori
error:                          ; A = codice, (tline) = riga
        ld (errcode),a
fail:   ld de,0081h
        ld a,' '
        ld (de),a
        inc de
        ld hl,fname
.n:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        jr .n
.e:     ld a,' '
        ld (de),a
        inc de
        ld a,'E'
        ld (de),a
        inc de
        ld hl,(tline)
        call dec_str
        ld a,' '
        ld (de),a
        inc de
        ld a,(errcode)
        ld l,a
        ld h,0
        call dec_str
        ld a,0Dh
        ld (de),a
        inc de
        ld hl,0081h
        ex de,hl
        or a
        sbc hl,de
        ld a,l
        ld (0080h),a
        ld hl,ldr_img           ; ricarica l'editor (ldr_fn = QB.COM di default)
        ld de,LDR
        ld bc,ldr_size
        ldir
        jp LDR

div10:                          ; HL / 10 (senza segno) -> HL, A = resto
        xor a
        ld b,16
.l:     add hl,hl
        rla
        cp 10
        jr c,.n
        sub 10
        inc l
.n:     djnz .l
        ret

dec_str:                        ; HL = valore -> cifre ASCII a (DE), DE avanza
        ld c,0
.d:     call div10
        add a,'0'
        push af
        inc c
        ld a,h
        or l
        jr nz,.d
.o:     pop af
        ld (de),a
        inc de
        dec c
        jr nz,.o
        ret

; ---------------------------------------------------------------- file
getname:                        ; riga di comando -> fname (maiuscolo, ".BAS" se manca l'estensione)
        ld hl,0081h
        ld a,(0080h)
        or a
        jr z,.none
        ld b,a
.sk:    ld a,(hl)
        cp ' '
        jr nz,.go
        inc hl
        djnz .sk
.none:  jp 0
.go:    ld de,fname
        ld c,0                  ; C = c'e' un punto
        ld b,12
.cp:    ld a,(hl)
        cp ' '
        jr z,.end
        cp 0Dh
        jr z,.end
        or a
        jr z,.end
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 20h
.u:     cp '.'
        jr nz,.st
        inc c
.st:    ld (de),a
        inc hl
        inc de
        djnz .cp
.end:   ld a,c
        or a
        jr nz,.z
        ld hl,s_bas
        ld bc,4
        ldir
.z:     xor a
        ld (de),a
        ret
s_bas:  db ".BAS"

mk_fcb:                         ; (namep) -> fcb (8.3 maiuscolo, unita' opzionale "A:")
        ld hl,fcb
        ld de,fcb+1
        ld bc,36
        ld (hl),0
        ldir
        ld hl,fcb+1
        ld de,fcb+2
        ld bc,10
        ld (hl),' '
        ldir
        ld hl,(namep)
        ld a,(hl)
        or a
        ret z
        inc hl
        ld a,(hl)
        dec hl
        cp ':'
        jr nz,.nm
        ld a,(hl)
        and 1Fh
        ld (fcb),a
        inc hl
        inc hl
.nm:    ld de,fcb+1
        ld b,8
        call .field
        ld a,(hl)
        cp '.'
        ret nz
        inc hl
        ld de,fcb+9
        ld b,3
.field: ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        ld (de),a
        inc hl
        inc de
        djnz .field
.rest:  ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        inc hl
        jr .rest

fcb_rec1:
        ld hl,1
        ld (fcb+14),hl
        ld hl,0
        ld (fcb+33),hl
        ld (fcb+35),hl
        ret

read_source:
        ld hl,fname
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_READ
.o:     call fcb_rec1
        ld de,SRC
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,SRCMAX
        ld c,F_BRD
        call BDOS
        push af
        push hl
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        pop hl
        pop af
        ld de,0
        ld (tline),de
        or a
        jr nz,.ok
        ERR E_SRCBIG
.ok:    ld de,SRC
        add hl,de
        ld (hl),0
        ret

        IFDEF ROMMODE
load_rt:                        ; RT.BIN -> OUT0 (immagine del runtime); outp = fine
        ld hl,s_rtbin
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_RT
.o:     call fcb_rec1
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,3000h
        ld c,F_BRD
        call BDOS
        push hl
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        pop hl
        ld de,OUT0
        add hl,de
        ld (outp),hl
        ret
        ELSE
load_rt:                        ; .COM: dimensione di RT.BIN (il file si copia per intero davanti al codice); il buffer parte vuoto
        ld hl,s_rtbin
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_RT
.o:     call fcb_rec1
        ld de,PART              ; la dimensione si ottiene leggendo il file a blocchi (F_SIZE dipende dalla versione del DOS)
        ld c,F_DMA
        call BDOS
        ld hl,0
        ld (rtsz),hl
.sz:    ld de,fcb
        ld hl,1024
        ld c,F_BRD
        call BDOS
        ld a,h
        or l
        jr z,.sd
        ld de,(rtsz)
        add hl,de
        ld (rtsz),hl
        jr .sz
.sd:
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,OUT0
        ld (outp),hl
        ld hl,OUT0-IMGBASE      ; il codice parte subito dopo il runtime: virtuale = fisico - voff
        ld de,(rtsz)
        or a
        sbc hl,de
        ld (voff),hl
        ld hl,HDRB              ; intestazione azzerata
        ld de,HDRB+1
        ld bc,HDRLEN-1
        ld (hl),0
        ldir
        ret
        ENDIF
        IFDEF ROMMODE
s_rtbin: db "RTROM.BIN",0
        ELSE
s_rtbin: db "RT.BIN",0
        ENDIF

        IFNDEF ROMMODE
write_output:                   ; NOME.COM <- RT.BIN + codice, con l'intestazione del runtime corretta
        ld hl,fname
        ld de,oname
.c:     ld a,(hl)
        or a
        jr z,.x
        cp '.'
        jr z,.x
        ld (de),a
        inc hl
        inc de
        jr .c
.x:     ld hl,s_com
        ld bc,5
        ldir
        ld hl,oname
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr z,.m
.err:   ld hl,0
        ld (tline),hl
        ERR E_WRITE
.m:     call fcb_rec1
        ld hl,fcb               ; FCB del file di uscita -> FCBSV
        ld de,FCBSV
        ld bc,37
        ldir
        ld hl,s_rtbin           ; si apre RT.BIN nell'FCB principale
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr nz,.err
        call fcb_rec1
        ld de,PART              ; buffer di copia da 1 KB (la tabella dei parametri non serve piu')
        ld c,F_DMA
        call BDOS
.cp:    ld de,fcb
        ld hl,1024
        ld c,F_BRD
        call BDOS
        ld a,h
        or l
        jr z,.cd                ; niente piu' dati
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        jr .cp
.cd:    ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld de,OUT0              ; il codice generato
        ld c,F_DMA
        call BDOS
        ld hl,(outp)
        ld de,-OUT0
        add hl,de
        ld a,h
        or l
        jr z,.hd
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        or a
        jr nz,.err
.hd:    ld de,HDRB              ; intestazione: nome, dimensione dati, DATA, target
        ld c,F_DMA
        call BDOS
        ld hl,RT_EMPTY-IMGBASE
        ld (FCBSV+33),hl
        xor a
        ld (FCBSV+35),a
        ld hl,HDRLEN
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        or a
        jp nz,.err
        ld de,FCBSV
        ld c,F_CLOSE
        call BDOS
        ret
        ENDIF
        IFDEF ROMMODE
rom_werr:
        ld hl,0
        ld (tline),hl
        ERR E_WRITE

rom_create:                     ; NOME.ROM: crea il file (una volta sola)
        ld hl,fname
        ld de,oname
.c:     ld a,(hl)
        or a
        jr z,.x
        cp '.'
        jr z,.x
        ld (de),a
        inc hl
        inc de
        jr .c
.x:     ld hl,s_rom
        ld bc,5
        ldir
        ld hl,oname
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr nz,rom_werr
        call fcb_rec1
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        ld a,1
        ld (romopen),a
        ret

segsz:                          ; -> DE = dimensione di un segmento commutabile
        ld de,8192
        ld a,(target)
        cp 4
        ret nz
        ld de,16384
        ret

rom_flush:                      ; DE = dimensione del segmento: scrive il buffer e riempie con zeri
        push de
        ld a,(romopen)
        or a
        call z,rom_create
        ld hl,(outp)
        ld de,-OUT0
        add hl,de
        push hl
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
        pop hl                  ; scritti
        pop de                  ; dimensione
        ex de,hl
        or a
        sbc hl,de               ; riempimento
        jp c,err_big
        ld a,h
        or l
        ret z
        ld (tmpv),hl
        ld hl,OUT0
        ld de,OUT0+1
        ld bc,16383
        ld (hl),0
        ldir
.z:     ld hl,(tmpv)
        ld a,h
        or l
        ret z
        ld de,16384
        or a
        sbc hl,de
        jr c,.last
        ld (tmpv),hl
        ld hl,16384
        jr .w
.last:  ld hl,(tmpv)
        ld de,0
        ld (tmpv),de
.w:     ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jr z,.z
        jp rom_werr

rom_finish:                     ; ultimo segmento, FARTAB e dimensione dei dati nell'intestazione, chiusura
        ld a,(curseg)
        or a
        jr nz,.seg
        ld de,16384
        ld a,(target)
        cp 1
        jr z,.go
        ld de,32768
        jr .go
.seg:   call segsz
.go:    call rom_flush
        ld a,(curseg)
        or a
        jr z,.close             ; un solo segmento: l'intestazione e' gia' completa
        ld hl,7F00h-4000h       ; FARTAB sta a 7F00h, cioe' a 3F00h nel file
        ld (fcb+33),hl
        xor a
        ld (fcb+35),a
        ld de,FARTABC
        ld c,F_DMA
        call BDOS
        ld hl,128
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
        ld hl,(dptr)
        ld de,-DATA_BASE
        add hl,de
        ld (tmpv),hl
        ld hl,RT_DSIZE-IMGBASE
        ld (fcb+33),hl
        xor a
        ld (fcb+35),a
        ld de,tmpv
        ld c,F_DMA
        call BDOS
        ld hl,2
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
.close: ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ret

rec_index:                      ; HL = record SUB/FUNCTION -> A = indice
        ld de,FUNT
        or a
        sbc hl,de
        ld de,FUNREC
        ld b,0
.l:     ld a,h
        or l
        jr z,.d
        or a
        sbc hl,de
        inc b
        jr .l
.d:     ld a,b
        ret

rec_far:                        ; HL = record -> A = indice FARTAB se la routine sta in un altro segmento, altrimenti FFh
        call rec_index
        ld e,a
        ld d,0
        ld hl,SEGT
        add hl,de
        ld a,(hl)
        or a
        jr z,.no
        ld b,a
        ld a,(curseg)
        cp b
        jr z,.no
        ld hl,FARX
        add hl,de
        ld a,(hl)
        ret
.no:    ld a,0FFh
        ret

rom_regfunc:                    ; nuova routine (indice nfunc-1): segmento della pre-scansione e voce FARTAB
        push hl
        push de
        ld a,(nfunc)
        dec a
        ld e,a
        ld d,0
        ld hl,SEGT
        add hl,de
        ld a,(pseg)
        ld (hl),a
        ld hl,FARX
        add hl,de
        ld (hl),0FFh
        ld a,(pseg)
        or a
        jr z,.d
        ld a,(nfar)
        cp 32
        jp nc,err_many
        ld (hl),a
        inc a
        ld (nfar),a
.d:     pop de
        pop hl
        ret

segbank:                        ; -> A = numero di banco del segmento corrente
        ld a,(curseg)
        ld b,a
        ld a,(target)
        cp 4
        ld a,b
        ret z
        inc a
        ret

rom_defsub:                     ; la routine (fcur) comincia qui: voce FARTAB (banco, indirizzo)
        ld a,(curseg)
        or a
        ret z
        ld hl,(fcur)
        call rec_index
        ld e,a
        ld d,0
        ld hl,FARX
        add hl,de
        ld a,(hl)
        cp 0FFh
        ret z
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,FARTABC
        add hl,de
        push hl
        call segbank
        pop hl
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        push hl
        call get_pc
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

err_many:
        ERR E_MANY

st_segment:                     ; SEGMENT n: da qui il codice va nel segmento n (n = segmento precedente + 1)
        ld a,(target)
        cp 3
        jp c,err_syntax         ; solo ASCII8, ASCII16, KONAMI, SCC
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld a,(curseg)
        inc a
        cp l
        jp nz,err_syntax
        ld a,h
        or a
        jp nz,err_syntax
        ld a,(fcur)
        ld hl,(fcur)
        ld a,h
        or l
        jp nz,err_syntax        ; non dentro una SUB/FUNCTION
        ld a,(nblk)
        or a
        jp nz,err_syntax
        ld a,(nlab)             ; salti in avanti non risolti non possono attraversare i segmenti
        or a
        jr z,.nl
        ld b,a
        ld hl,LABT
.pl:    push hl
        ld de,14
        add hl,de
        ld a,(hl)
        or a
        jr nz,.ok
        inc hl
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.ok
        pop hl
        jp err_label
.ok:    pop hl
        ld de,LABREC
        add hl,de
        djnz .pl
.nl:    ld a,(curseg)
        or a
        ld de,16384
        jr z,.fl
        call segsz
.fl:    call rom_flush
        ld hl,OUT0
        ld (outp),hl
        ld hl,0
        ld (voff),hl            ; il segmento commutabile sta a 8000h: fisico = virtuale
        ld a,(target)
        cp 4
        ld a,0BFh
        jr z,.l
        ld a,0A0h
.l:     ld (outlim),a
        ld a,(curseg)
        inc a
        ld (curseg),a
        jp next_tok
        ENDIF

        IFNDEF ROMMODE
st_segment:
        jp err_syntax
        ENDIF

st_setbank:                     ; SETBANK n: il segmento n compare nella finestra dati (DATAWIN)
        call expr
        call want_int
        EM3 0CDh,low RT_SETBANK,high RT_SETBANK
        ret

st_vcopy:                       ; VCOPY memoria, vram, quanti
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        EM3 0CDh,low RT_VCOPY,high RT_VCOPY
        ret

bi_mapsegs:                     ; MAPPERSEGS: segmenti da 16 KB del mapper RAM (0 = nessuno)
        call next_tok
        EM3 0CDh,low RT_MAPSEGS,high RT_MAPSEGS
        xor a
        ld (etype),a
        ret

bi_malloc:                      ; MALLOC: segmento libero del mapper
        call next_tok
        EM3 0CDh,low RT_MALLOC,high RT_MALLOC
        xor a
        ld (etype),a
        ret

st_mfree:                       ; MFREE segmento
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        EM3 0CDh,low RT_MFREE,high RT_MFREE
        ret

bi_mget:                        ; MGET(segmento, offset)
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        call close_paren
        EM3 0CDh,low RT_MGET,high RT_MGET
        xor a
        ld (etype),a
        ret

st_mput:                        ; MPUT segmento, offset, valore
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        EM3 0CDh,low RT_MPUT,high RT_MPUT
        ret

st_mread:                       ; MREAD segmento, offset, indirizzo, quanti  (mapper -> memoria)
        ld hl,RT_MREAD
        jr mblock
st_mwrite:                      ; MWRITE segmento, offset, indirizzo, quanti (memoria -> mapper)
        ld hl,RT_MWRITE
mblock: push hl
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY2
        call emit_st
        pop hl
        ld a,0CDh
        jp emit_jabs

bi_varptr:                      ; VARPTR(variabile) o VARPTR(array(i)): indirizzo in memoria
        call next_tok
        call open_paren
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call resolve_var
        cp 2
        jr nc,.loc
        push hl
        ld a,21h                ; globale: ld hl,indirizzo
        call emit_a
        pop hl
        call emit_w
        jr .nx
.loc:   push hl                 ; locale: push ix ; pop hl ; ld de,scostamento ; add hl,de
        EM3 0DDh,0E5h,0E1h
        ld a,11h
        call emit_a
        pop hl
        call emit_w
        EM1 19h
.nx:    call next_tok
        jr .end
.arr:   call restore_lex
        call arr_elem
.end:   call close_paren
        xor a
        ld (etype),a
        ret

arr_is_mapper:                  ; tbuf = array: NZ se sta nel mapper RAM
        call find_arrparam
        jr nc,.no
        call find_rec
        jr c,.no
        ld de,15
        add hl,de
        ld a,(hl)
        and 80h
        ret
.no:    xor a
        ret

mapper_desc:                    ; tbuf = array in mapper -> DE = indirizzo del descrittore
        call find_rec
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

mapper_read:                    ; x(i): ld de,descrittore ; call RT_MAGET (HL = indice -> valore)
        call mapper_desc
        push de
        call next_tok
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        pop hl
        ld a,11h
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_MAGET,high RT_MAGET
        xor a
        ld (etype),a
        ret

mapper_assign:                  ; x(i) = v: push indice ; v ; pop de ; ld bc,descrittore ; call RT_MAPUT
        call mapper_desc
        push de
        call next_tok
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        EM1 0E5h
        ld a,'='
        call expect_p
        call expr
        call want_int
        EM1 0D1h
        pop hl
        ld a,1
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_MAPUT,high RT_MAPUT
        ret

st_bload:                       ; BLOAD nome$ [, S] [, scostamento]
        call expr
        call want_str
        EM1 0E5h
        call emit_i             ; GX1 = 0, GY1 = 0
        db 9,21h,0,0,22h,low GX1,high GX1,22h,low GY1,high GY1
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld hl,tbuf
        ld de,s_sw
        ld a,(ttype)
        cp T_ID
        jr nz,.off
        call str_eq
        jr nz,.off
        call emit_i             ; GY1 = 1
        db 6,21h,1,0,22h,low GY1,high GY1
        call next_tok
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
.off:   call expr
        call want_int
        ld hl,GX1
        call emit_st
.go:    EM1 0E1h
        EM3 0CDh,low RT_BLOAD,high RT_BLOAD
        ret

st_bsave:                       ; BSAVE nome$, inizio, lunghezza [, S]
        call expr
        call want_str
        EM1 0E5h
        call emit_i             ; GX2 = 0
        db 6,21h,0,0,22h,low GX2,high GX2
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_sw
        call str_eq
        jp nz,err_syntax
        call emit_i
        db 6,21h,1,0,22h,low GX2,high GX2
        call next_tok
.go:    EM1 0E1h
        EM3 0CDh,low RT_BSAVE,high RT_BSAVE
        ret

st_fget:
        ld hl,RT_FGET
        jr fio
st_fput:
        ld hl,RT_FPUT
fio:    push hl
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call emit_i             ; record = 0 (il successivo)
        db 6,21h,0,0,22h,low GY1,high GY1
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        call expr
        call want_int
        ld hl,GY1
        call emit_st
.go:    pop hl
        ld a,0CDh
        jp emit_jabs

st_field:                       ; FIELD [#]n, larghezza AS variabile$ [, larghezza AS variabile$ ...]
        ld a,'#'
        call is_p
        jr nz,.n
        call next_tok
.n:     call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,1
        ld (mapf),a             ; primo campo: azzera la tabella
.l:     ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_as
        call str_eq
        jp nz,err_syntax
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        cp 1
        jp nz,err_type          ; solo variabili stringa globali
        push hl
        ld a,21h                ; ld hl,primo ; ld (GX2),hl
        call emit_a
        ld a,(mapf)
        ld l,a
        ld h,0
        call emit_w
        ld hl,GX2
        call emit_st
        xor a
        ld (mapf),a
        pop hl
        push hl
        ld a,21h                ; ld hl,variabile ; call RT_FIELD
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_FIELD,high RT_FIELD
        call next_tok
        ld a,','
        call is_p
        jr z,.l
        ret

st_lset:                        ; LSET v$ = espressione: come un assegnamento (PUT completa con spazi)
        jp st_let

st_rset:                        ; RSET v$ = espressione: allineata a destra nella larghezza del campo
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        cp 1
        jp nz,err_type
        push hl
        call next_tok
        ld a,'='
        call expect_p
        call expr
        call want_str
        pop hl
        ld a,11h                ; ld de,variabile ; call RT_RSET
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_RSET,high RT_RSET
        ret

bi_lof:                         ; LOF(n)
        call bi_arg_int
        EM3 0CDh,low RT_FLOF,high RT_FLOF
        ret

bi_mki:                         ; MKI$(n): intero in 2 byte
        ld hl,RT_MKI
        ld c,1
        jp bi1i

bi_cvi:                         ; CVI(s$)
        ld hl,RT_CVI
        jp bi1s

bi_datawin:                     ; DATAWIN: indirizzo della finestra dati
        call next_tok
        EM3 0CDh,low RT_DATAWIN,high RT_DATAWIN
        xor a
        ld (etype),a
        ret

        IFDEF ROMMODE
st_incbin:                      ; INCBIN "file": i byte del file entrano nel segmento corrente
        ld a,(ttype)
        cp T_STR
        jp nz,err_syntax
        ld a,(tlen)
        cp 13
        jp nc,err_syntax
        ld c,a
        ld b,0
        ld hl,(tval)
        ld de,nbuf
        or a
        jr z,.e
        ldir
.e:     xor a
        ld (de),a
        ld hl,nbuf
        ld (namep),hl
        ld hl,fcb               ; l'FCB del file di uscita si salva
        ld de,FCBSV
        ld bc,37
        ldir
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ERR E_READ
.o:     call fcb_rec1
        ld de,(outp)
        ld c,F_DMA
        call BDOS
        ld a,(outlim)
        ld h,a
        ld l,0
        ld de,(outp)
        or a
        sbc hl,de
        push hl
        ld de,fcb
        ld c,F_BRD
        call BDOS
        ld (tmpv),hl
        pop de
        or a
        sbc hl,de
        push af
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,FCBSV
        ld de,fcb
        ld bc,37
        ldir
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        pop af
        jp z,err_big            ; riempie tutto lo spazio: troppo grande
        ld hl,(outp)
        ld de,(tmpv)
        add hl,de
        ld (outp),hl
        jp next_tok
        ENDIF
        IFNDEF ROMMODE
st_incbin:
        jp err_syntax
        ENDIF

s_com:  db ".COM",0

; ---------------------------------------------------------------- emissione
emit_a:                         ; A -> output (clobbera solo A)
        push hl
        ld hl,(outp)
        ld (hl),a
        inc hl
        ld (outp),hl
        ld a,h
        ld hl,outlim
        cp (hl)
        jp nc,err_big
        pop hl
        ret
err_big:
        ERR E_BIG

emit_w:                         ; HL -> output (little endian)
        push af
        ld a,l
        call emit_a
        ld a,h
        call emit_a
        pop af
        ret

emit_i:                         ; byte inline: db n, b1..bn  (dopo la call)
        ex (sp),hl
        push bc
        ld b,(hl)
        inc hl
.l:     ld a,(hl)
        inc hl
        call emit_a
        djnz .l
        pop bc
        ex (sp),hl
        ret

get_pc:                         ; HL = indirizzo virtuale corrente (clobbera DE)
        ld hl,(outp)
        ld de,(voff)
        or a
        sbc hl,de
        ret

emit_jchain:                    ; A = opcode, HL = &testa: jp con operando = catena di fixup
        push hl
        call emit_a
        pop hl
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call get_pc
        ex de,hl
        pop hl
        call emit_w
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

emit_jabs:                      ; A = opcode, HL = indirizzo
        push hl
        call emit_a
        pop hl
        jp emit_w

patch_chain:                    ; HL = &testa: tutti i salti della catena puntano al pc corrente
        ld e,(hl)
        inc hl
        ld d,(hl)
        xor a
        ld (hl),a
        dec hl
        ld (hl),a
        push de
        call get_pc
        ex de,hl
        pop hl
.l:     ld a,h
        or l
        ret z
        ld bc,(voff)
        add hl,bc
        ld c,(hl)
        ld (hl),e
        inc hl
        ld b,(hl)
        ld (hl),d
        ld h,b
        ld l,c
        jr .l

; ---------------------------------------------------------------- lexer
save_lex:
        ld hl,lp
        ld de,lexsv
        ld bc,LEXSZ
        ldir
        ret
restore_lex:
        ld hl,lexsv
        ld de,lp
        ld bc,LEXSZ
        ldir
        ret

next_tok:
        ld hl,(lp)
.ws:    ld a,(hl)
        cp ' '
        jr z,.sk
        cp 9
        jr z,.sk
        cp 0Dh
        jr nz,.go
.sk:    inc hl
        jr .ws
.go:    ld de,(lineno)
        ld (tline),de
        xor a
        ld (tsuf),a
        ld a,(hl)
        or a
        jr z,.eof
        cp 1Ah
        jr z,.eof
        cp 0Ah
        jr z,.eol
        cp 27h                  ; '
        jr z,.cmt
        cp '"'
        jp z,.str
        cp '&'
        jp z,.amp
        cp '0'
        jr c,.nd
        cp '9'+1
        jp c,.num
.nd:    cp '_'
        jp z,.id
        or 20h
        cp 'a'
        jr c,.pu
        cp 'z'+1
        jp c,.id
.pu:    ld a,(hl)
        jp .punct
.eof:   ld (lp),hl
        ld a,1
        ld (iseof),a
        xor a
        ld (ttype),a
        ret
.eol:   inc hl
        ld (lp),hl
        ld hl,(lineno)
        inc hl
        ld (lineno),hl
        xor a
        ld (ttype),a
        ret
.cmt:   inc hl
        ld a,(hl)
        cp 0Ah
        jr z,.go
        or a
        jr z,.go
        cp 1Ah
        jr nz,.cmt
        jr .go

.num:   ld de,0
.nl:    ld a,(hl)
        sub '0'
        cp 10
        jr nc,.ne
        push hl
        ld h,d
        ld l,e
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        pop hl
        inc hl
        jr .nl
.ne:    ld (tval),de
        ld (lp),hl
        ld a,T_NUM
        ld (ttype),a
        ret

.amp:   inc hl
        ld a,(hl)
        or 20h
        cp 'h'
        jr z,.hex
        cp 'b'
        jr z,.bin
        ERR E_CHAR
.hex:   inc hl
        ld de,0
        ld c,0                  ; cifre lette
.hl:    ld a,(hl)
        sub '0'
        cp 10
        jr c,.hd
        ld a,(hl)
        or 20h
        sub 'a'-10
        cp 10
        jr c,.he
        cp 16
        jr nc,.he
.hd:    ld b,a
        push hl
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        inc c
        jr .hl
.he:    ld a,c
        or a
        jr nz,.ne
        ERR E_CHAR
.bin:   inc hl
        ld de,0
        ld c,0
.bl:    ld a,(hl)
        sub '0'
        cp 2
        jr nc,.he
        ld b,a
        push hl
        ex de,hl
        add hl,hl
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        inc c
        jr .bl

.str:   inc hl
        ld (tval),hl
        ld c,0
.sl:    ld a,(hl)
        cp '"'
        jr z,.se
        or a
        jr z,.su
        cp 0Ah
        jr z,.su
        inc hl
        inc c
        jr nz,.sl
.su:    ERR E_CHAR
.se:    inc hl
        ld a,c
        ld (tlen),a
        ld (lp),hl
        ld a,T_STR
        ld (ttype),a
        ret

.id:    ld de,tbuf
        push hl
        ld hl,tbuf
        ld b,16
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        pop hl
        ld b,14
.il:    ld a,(hl)
        cp '_'
        jr z,.ic
        cp '0'
        jr c,.ie
        cp '9'+1
        jr c,.ic
        or 20h
        cp 'a'
        jr c,.ie
        cp 'z'+1
        jr nc,.ie
.ic:    ld a,(hl)
        cp 'a'
        jr c,.up
        cp 'z'+1
        jr nc,.up
        sub 20h
.up:    inc hl
        ld c,a
        ld a,b
        or a
        jr z,.il
        dec b
        ld a,c
        ld (de),a
        inc de
        jr .il
.ie:    ld a,(hl)
        cp '$'
        jr z,.sf
        cp '%'
        jr nz,.fin
        inc hl                  ; A% = A: il suffisso intero si ignora
        jr .fin
.sf:    inc hl
        ld a,1
        ld (tsuf),a
        ld a,'$'
        ld (tbuf+11),a          ; A$ e A restano nomi distinti anche per nomi lunghi
.fin:   ld (lp),hl
        ld a,(tsuf)
        or a
        jr nz,.var
        ld hl,tbuf              ; REM = commento
        ld de,s_rem
        ld b,4
.rc:    ld a,(de)
        cp (hl)
        jr nz,.nrem
        inc hl
        inc de
        djnz .rc
        ld hl,(lp)
        jp .cmt
.nrem:  ld hl,kwtab
        ld de,tbuf
        call find_in
        jr c,.var
        ld (tval),a
        ld a,T_KW
        ld (ttype),a
        ret
.var:   ld a,T_ID
        ld (ttype),a
        ret

.punct: ld c,a
        inc hl
        cp '<'
        jr nz,.q1
        ld a,(hl)
        cp '>'
        jr z,.t1
        cp '='
        jr z,.t2
        jr .single
.q1:    cp '>'
        jr nz,.q2
        ld a,(hl)
        cp '='
        jr z,.t3
        jr .single
.q2:    cp '='
        jr nz,.single
        ld a,(hl)
        cp '<'
        jr z,.t2
        cp '>'
        jr z,.t3
.single:
        ld a,c
        push hl
        ld hl,puncts
        ld b,15
.pl:    cp (hl)
        jr z,.pv
        inc hl
        djnz .pl
        ERR E_CHAR
.pv:    pop hl
        jr .pfin
.t1:    ld c,1
        jr .t
.t2:    ld c,2
        jr .t
.t3:    ld c,3
.t:     inc hl
.pfin:  ld (lp),hl
        ld a,c
        ld (tval),a
        ld a,T_P
        ld (ttype),a
        ret
puncts: db "()+-*/",5Ch,"=<>,;:?#"
s_rem:  db "REM",0

find_in:                        ; HL = tabella di stringhe 0-terminate (fine: byte 0), DE = nome -> A = indice, C se manca
        ld (fi_s),de
        ld c,0
.next:  ld a,(hl)
        or a
        jr z,.nf
        ld de,(fi_s)
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.skip
        or a
        jr z,.hit
        inc hl
        inc de
        jr .cmp
.skip:  ld a,(hl)
        inc hl
        or a
        jr nz,.skip
        inc c
        jr .next
.hit:   ld a,c
        or a
        ret
.nf:    scf
        ret

kwtab:  db "PRINT",0,"IF",0,"THEN",0,"ELSE",0,"ELSEIF",0,"END",0,"FOR",0,"TO",0
        db "STEP",0,"NEXT",0,"WHILE",0,"WEND",0,"GOTO",0,"GOSUB",0,"RETURN",0
        db "CLS",0,"LOCATE",0,"AND",0,"OR",0,"XOR",0,"NOT",0,"MOD",0,"LET",0
        db "OPTION",0,"INPUT",0,"DIM",0,"POKE",0,"SUB",0,"FUNCTION",0,"CALL",0,"DECLARE",0,"SHARED",0
        db "EXIT",0,"DO",0,"LOOP",0,"UNTIL",0,"SELECT",0,"CASE",0,"IS",0,"CONST",0,"COLOR",0,"RANDOMIZE",0,"VPOKE",0,"OUT",0,"SLEEP",0,"STOP",0,"SCREEN",0,"PSET",0,"PRESET",0,"LINE",0,"CIRCLE",0
        db "PALETTE",0,"PAINT",0,"PUT",0,"SPRITE",0,"GET",0,"DRAW",0,"VIEW",0,"WINDOW",0,"VBANK",0,"VFILL",0,"VWRITE",0,"SET",0,"COPY",0,"DATA",0,"READ",0,"RESTORE",0,"BEEP",0,"SOUND",0,"PLAY",0
        db "OPEN",0,"CLOSE",0,"KILL",0,"WRITE",0,"SEGMENT",0,"INCBIN",0
        db "SETBANK",0,"VCOPY",0,"MPUT",0,"MREAD",0,"MWRITE",0,"MFREE",0,"BLOAD",0,"BSAVE",0,"FIELD",0,"LSET",0,"RSET",0,0

; ---------------------------------------------------------------- helper del parser
is_p:                           ; A = carattere: Z se il token e' quella punteggiatura
        ld b,a
        ld a,(ttype)
        cp T_P
        ret nz
        ld a,(tval)
        cp b
        ret
is_kw:                          ; A = indice: Z se il token e' quella parola chiave
        ld b,a
        ld a,(ttype)
        cp T_KW
        ret nz
        ld a,(tval)
        cp b
        ret
expect_p:
        call is_p
        jp nz,err_syntax
        jp next_tok
expect_kw:
        call is_kw
        jp nz,err_syntax
        jp next_tok
err_syntax:
        ERR E_SYNTAX
err_unsup:
        ERR E_UNSUP

at_send:                        ; Z se il token chiude l'istruzione (fine riga, ':' o ELSE)
        ld a,(ttype)
        cp T_EOL
        ret z
        cp T_P
        jr z,.p
        cp T_KW
        jr z,.k
        or 1
        ret
.p:     ld a,(tval)
        cp ':'
        ret
.k:     ld a,(tval)
        cp K_ELSE
        ret

; ---------------------------------------------------------------- tabelle
name_eq:                        ; HL = record: Z se i primi 12 byte coincidono con tbuf
        push hl
        push bc
        ld de,tbuf
        ld b,12
.l:     ld a,(de)
        cp (hl)
        jr nz,.x
        inc hl
        inc de
        djnz .l
.x:     pop bc
        pop hl
        ret

find_label:                     ; tbuf -> HL = record (lo crea)
        ld a,(nlab)
        ld b,a
        ld hl,LABT
        or a
        jr z,.new
.l:     call name_eq
        ret z
        ld de,LABREC
        add hl,de
        djnz .l
.new:   ld a,(nlab)
        cp MAXLAB
        jr c,.ok
        ERR E_MANY
.ok:    inc a
        ld (nlab),a
        push hl
        ex de,hl
        ld hl,tbuf
        ld bc,12
        ldir
        ex de,hl
        ld b,LABREC-12
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        pop hl
        ld de,(tline)
        push hl
        ld bc,17
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ret

define_label:                   ; tbuf = nome: definisce l'etichetta al pc corrente
        call find_label
        push hl
        ld de,14
        add hl,de
        ld a,(hl)
        or a
        jr z,.ok
        ERR E_DUP
.ok:    ld (hl),1
        push hl
        ld de,5                 ; +19: segmento dell'etichetta
        add hl,de
        ld a,(curseg)
        ld (hl),a
        pop hl
        pop hl
        push hl
        call get_pc
        ex de,hl
        pop hl
        push hl
        ld bc,12
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ld de,15
        add hl,de
        jp patch_chain

label_jump:                     ; A = opcode (C3 jp / CD call), tbuf = nome
        push af
        call find_label
        ld de,14
        add hl,de
        ld a,(hl)
        or a
        jr nz,.def
        inc hl                  ; non definita: catena di fixup nella testa (rec+15)
        pop af
        jp emit_jchain
.def:   push hl
        ld de,5
        add hl,de
        ld a,(curseg)
        cp (hl)
        pop hl
        jp nz,err_label         ; etichetta in un altro segmento
        dec hl
        dec hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop af
        jp emit_jabs

num_to_name:                    ; tval = numero di riga -> tbuf = cifre decimali
        ld hl,tbuf
        ld b,16
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        ld hl,(tval)
        ld de,tbuf
        jp dec_str

find_rec:                       ; tbuf -> HL = record, NC se trovato; C se manca (HL = posto libero)
        ld a,(tsuf)
        ld (vtyp),a
        ld a,(nvar)
        ld b,a
        ld hl,VART
        or a
        jr z,.nf
.l:     call name_eq
        jr z,.f
        ld de,VARREC
        add hl,de
        djnz .l
.nf:    scf
        ret
.f:     or a
        ret

alloc_data:                     ; BC = byte -> HL = indirizzo (area dati del programma)
        ld hl,(dptr)
        push hl
        add hl,bc
        jp c,err_mem
        ld de,(dlim)
        push hl
        or a
        sbc hl,de
        pop hl
        jp nc,err_mem
        ld (dptr),hl
        pop hl
        ret
err_mem:
        ERR E_MEM

new_rec:                        ; HL = posto, BC = byte, DE = numero elementi (0 = scalare) -> HL = indirizzo dati
        ld (tmps),de
        ld a,(nvar)
        cp MAXVAR
        jr c,.ok
        ERR E_MANY
.ok:    inc a
        ld (nvar),a
        push hl
        ex de,hl
        ld hl,tbuf
        push bc
        ld bc,12
        ldir
        pop bc
        push de
        call alloc_data
        pop de
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld bc,(tmps)
        ld (hl),c
        inc hl
        ld (hl),b
        pop hl
        ex de,hl
        ret

kind_type:                      ; A = tipo di riferimento (emit_ldv) -> A = 0 intero, 1 stringa
        cp 1
        jr z,.s
        cp 3
        jr z,.s
        cp 4
        jr z,.s
        xor a
        ret
.s:     ld a,1
        ret

resolve_var:                    ; tbuf -> A = tipo di riferimento, HL = indirizzo o scostamento da IX
        ld a,(tsuf)
        ld (vtyp),a
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.glob
        ld a,(nloc)
        ld hl,LOCT
        or a
        jr z,.new
        ld b,a
.l:     call name_eq
        jr z,.f
        ld de,16
        add hl,de
        djnz .l
        jr .new
.f:     ld de,12
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        cp 2
        jr z,.glob              ; SHARED
        or a
        jr z,.m2
        cp 1
        jr z,.m3
        cp 3
        jr z,.m2
        cp 4
        jp nz,err_type          ; parametro array usato come scalare
        ld a,4                  ; parametro stringa
        ret
.m2:    ld a,2
        ret
.m3:    ld a,3
        ret
.glob:  call find_var
        ld a,(vtyp)
        ret
.new:   ld a,(vtyp)             ; nuova variabile locale
        or a
        jr nz,.ns
        ld a,(nint)
        inc a
        cp 30
        jr c,.ni
        ERR E_MANY
.ni:    ld (nint),a
        inc a
        add a,a
        ld e,a
        ld d,0
        ld hl,0
        or a
        sbc hl,de               ; scostamento = -2*(n+1)
        ex de,hl
        xor a                   ; tipo locale: intero
        push af
        jr .add
.ns:    ld a,(nstr)
        inc a
        ld (nstr),a
        ld h,a                  ; scostamento = -(64 + 256*n)
        ld l,0
        ld de,64
        add hl,de
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
        ld a,1
        push af
.add:   pop af
        push af
        push de
        call loct_add
        pop hl
        pop af
        or a
        ld a,2
        ret z
        ld a,3
        ret

loct_add:                       ; tbuf = nome, A = tipo (0 int, 1 str, 2 shared, 3 par.int, 4 par.str), DE = scostamento
        push af
        push de
        ld a,(nloc)
        cp MAXLOC
        jr c,.ok
        ERR E_MANY
.ok:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,LOCT
        add hl,de
        ld a,(nloc)
        inc a
        ld (nloc),a
        ex de,hl
        ld hl,tbuf
        ld bc,12
        ldir
        pop bc
        pop af
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        ret

emit_ldv:                       ; A = tipo di riferimento, HL = indirizzo/scostamento: HL (programma) = valore o puntatore
        or a
        jr nz,.k1
        ld a,2Ah                ; globale intero: ld hl,(nn)
        jr .abs
.k1:    dec a
        jr nz,.k2
        ld a,21h                ; globale stringa: ld hl,nn
.abs:   push hl
        call emit_a
        pop hl
        jp emit_w
.k2:    dec a
        jr z,.ix
        dec a
        jr z,.lstr
.ix:    ld c,l                  ; intero locale o parametro (anche stringa): ld l,(ix+d) ; ld h,(ix+d+1)
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        inc a
        jp emit_a
.lstr:  push hl                 ; buffer di stringa locale: push ix ; pop hl ; ld de,d ; add hl,de
        EM3 0DDh,0E5h,0E1h
        ld a,11h
        call emit_a
        pop hl
        call emit_w
        EM1 19h
        ret

emit_stv:                       ; A = tipo di riferimento, HL = indirizzo/scostamento: memorizza il valore in HL (programma)
        or a
        jr nz,.n1
        ld a,22h                ; globale intero: ld (nn),hl
        push hl
        call emit_a
        pop hl
        jp emit_w
.n1:    dec a
        jr nz,.n2
        ld a,11h                ; globale stringa: ld de,buffer ; call rt_scopy
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_SCOPY,high RT_SCOPY
        ret
.n2:    dec a
        jr nz,.n3
        ld c,l                  ; intero locale: ld (ix+d),l ; ld (ix+d+1),h
        ld a,0DDh
        call emit_a
        ld a,75h
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,74h
        call emit_a
        ld a,c
        inc a
        jp emit_a
.n3:    dec a
        jp nz,err_type          ; parametro stringa: non assegnabile
        push hl                 ; stringa locale: push hl ; (ix+d) -> HL ; ex de,hl ; pop hl ; call rt_scopy
        EM1 0E5h
        EM3 0DDh,0E5h,0E1h
        ld a,11h
        call emit_a
        pop hl
        call emit_w
        EM1 19h
        EM2 0EBh,0E1h
        EM3 0CDh,low RT_SCOPY,high RT_SCOPY
        ret

find_var:                       ; variabile scalare (tbuf) -> HL = indirizzo; vtyp = tipo
        call find_rec
        jr c,.new
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,b
        or c
        jp nz,err_type          ; e' un array usato senza indice
        ex de,hl
        ret
.new:   ld a,(vtyp)
        ld bc,2
        or a
        jr z,.s
        ld bc,256
.s:     ld de,0
        jp new_rec

arr_elem:                       ; tbuf = array, token = nome: emette il calcolo dell'indirizzo dell'elemento in HL
        call find_arrparam
        jr c,.glob
        ld a,(tsuf)             ; parametro array: numero elementi a (ix+d), base a (ix+d+2)
        push hl
        push af
        call next_tok
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        pop af
        ld (etype),a
        pop hl
        ld c,l
        ld a,0DDh               ; ld e,(ix+d) ; ld d,(ix+d+1) ; call rt_chk
        call emit_a
        ld a,5Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,56h
        call emit_a
        ld a,c
        inc a
        call emit_a
        EM3 0CDh,low RT_CHK,high RT_CHK
        ld a,(etype)
        or a
        jr nz,.pstr
        EM1 29h
        jr .pbase
.pstr:  EM3 65h,2Eh,0
.pbase: ld a,0DDh               ; ld e,(ix+d+2) ; ld d,(ix+d+3) ; add hl,de
        call emit_a
        ld a,5Eh
        call emit_a
        ld a,c
        add a,2
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,56h
        call emit_a
        ld a,c
        add a,3
        call emit_a
        EM1 19h
        ret
.glob:  call find_rec
        jp c,err_type           ; array non dichiarato
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        bit 7,b
        jp nz,err_type          ; array nel mapper: solo x(i) in lettura/assegnamento
        ld a,b
        or c
        jp z,err_type
        push de                 ; base
        push bc                 ; numero elementi
        ld a,(vtyp)
        push af
        call next_tok           ; nome
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        pop af
        ld (etype),a            ; tipo dell'elemento
        pop bc
        pop de
        push de                 ; base
        ld a,11h                ; ld de,numero
        call emit_a
        ld h,b
        ld l,c
        call emit_w
        EM3 0CDh,low RT_CHK,high RT_CHK
        ld a,(etype)
        or a
        jr nz,.str
        EM1 29h                 ; add hl,hl
        jr .base
.str:   EM3 65h,2Eh,0           ; ld h,l ; ld l,0   (indice * 256)
.base:  ld a,11h                ; ld de,base
        call emit_a
        pop hl
        call emit_w
        EM1 19h                 ; add hl,de
        ret

push_blk:                       ; A = tipo -> HL = record (campi azzerati)
        ld c,a
        ld a,(nblk)
        cp MAXBLK
        jr c,.ok
        ERR E_MANY
.ok:    inc a
        ld (nblk),a
        call blk_top
        ld (hl),c
        push hl
        inc hl
        ld b,BLKREC-1
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        pop hl
        ret

blk_top:                        ; HL = record in cima (nblk >= 1)
        ld a,(nblk)
        dec a
blk_addr:                       ; A = indice -> HL = record
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl               ; *8
        add hl,de
        add hl,de               ; *10
        ld de,BLKS
        add hl,de
        ret

find_blk:                       ; C = tipo -> HL = record del blocco piu' interno di quel tipo
        ld a,(nblk)
.l:     or a
        jr z,.bad
        dec a
        push af
        call blk_addr
        ld a,(hl)
        cp c
        jr z,.f
        pop af
        jr .l
.f:     pop af
        ret
.bad:   ERR E_MISM

need_blk:                       ; A = tipo richiesto -> HL = record in cima, altrimenti errore
        ld c,a
        ld a,(nblk)
        or a
        jr z,.bad
        call blk_top
        ld a,(hl)
        cp c
        ret z
.bad:   ERR E_MISM

; ---------------------------------------------------------------- compilazione
compile:
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        ld (tline),hl
        xor a
        ld (iseof),a
        ld (nlab),a
        ld (nvar),a
        ld (nblk),a
        ld (onel),a
        ld (mode),a
        ld (tmpf),a
        ld (etype),a
        ld (usewin),a
        ld (target),a
        ld (curseg),a
        ld (pseg),a
        ld (nfar),a
        ld (romopen),a
        IFDEF ROMMODE
        ld hl,FARTABC
        ld de,FARTABC+1
        ld bc,127
        ld (hl),0
        ldir
        ENDIF
        ld hl,OUT0-IMGBASE
        ld (voff),hl
        ld a,OUTLIM
        ld (outlim),a
        xor a
        ld h,a
        ld l,a
        ld (dlast),hl
        ld hl,DATA_BASE
        ld (dptr),hl
        IFDEF ROMMODE
        ld hl,0DC00h
        ELSE
        ld hl,(0006h)
        ld de,-0C00h
        add hl,de
        ENDIF
        ld (dlim),hl
        ld (nfunc),a
        ld (npart),a
        ld (nloc),a
        ld h,a
        ld l,a
        ld (fcur),hl
        ld (fexit),hl
        ld (fskiph),hl
        call load_rt            ; il runtime (RT.BIN) e' l'inizio dell'output
        call prescan            ; firme di SUB/FUNCTION (riferimenti in avanti)
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        ld (tline),hl
        xor a
        ld (iseof),a
        ld hl,fname             ; nome del sorgente nell'immagine (per il ritorno all'editor)
        ld de,HDRNAME
        ld bc,16
        ldir
        call next_tok
        ld a,K_OPTION           ; OPTION NUMBERED | LABELS | MIXED come prima istruzione
        call is_kw
        jr nz,.nopt
        call save_lex
        call next_tok
        ld a,(ttype)
        cp T_ID
        jr nz,.ropt
        ld hl,tbuf
        ld de,s_numbered
        call str_eq
        ld a,1
        jr z,.setm
        ld hl,tbuf
        ld de,s_labels
        call str_eq
        ld a,2
        jr z,.setm
        IFDEF ROMMODE
        ld hl,tbuf
        ld de,s_target
        call str_eq
        jr nz,.ropt
        call next_tok
        call parse_target
        ENDIF
.ropt:  xor a
.setm:  ld (mode),a
        call restore_lex
.nopt:
        IFDEF ROMMODE
        ld a,(target)
        or a
        jr nz,.tok
        ld a,2                  ; senza OPTION TARGET: ROM32
        ld (target),a
        ld (HDRTGT),a
.tok:
        ENDIF
        ld a,(mode)
        cp 1
        jr nz,.plain
        IFDEF ROMMODE
        jp err_syntax           ; OPTION NUMBERED non c'e' nel compilatore per cartucce
        ELSE
        call sort_lines         ; NUMBERED: le righe si compilano in ordine di numero
        ld a,1
        ld (onel),a
        ld hl,ENT
        ld (entp),hl
.sl:    ld hl,(entp)
        ld de,(entend)
        or a
        sbc hl,de
        jr nc,.finish
        ld hl,(entp)
        ld e,(hl)
        inc hl
        ld d,(hl)               ; numero (non serve)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lp),de              ; puntatore alla riga
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lineno),de
        ld (entp),hl
        xor a
        ld (iseof),a
        call next_tok
        call line_loop
        jr .sl
        ENDIF
.plain: call line_loop
.finish:
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.nf
        ld hl,(lineno)
        ld (tline),hl
        ERR E_OPEN
.nf:    ld a,(nfunc)            ; funzioni dichiarate ma mai definite
        or a
        jr z,.nf2
        ld b,a
        ld hl,FUNT
.fl:    ld de,16
        add hl,de
        ld a,(hl)
        ld de,FUNREC-16
        add hl,de
        or a
        jr nz,.fn
        ld hl,0
        ld (tline),hl
        ERR E_LABEL
.fn:    djnz .fl
.nf2:   ld a,(nblk)
        or a
        jr z,.nb
        ld hl,(lineno)
        ld (tline),hl
        ERR E_OPEN
.nb:    ld a,(nlab)             ; etichette senza definizione
        or a
        jr z,.fin
        ld b,a
        ld hl,LABT
.ul:    ld de,14
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.nx
        push hl
        ld de,17
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (tline),de
        pop hl
        ERR E_LABEL
.nx:    ld de,LABREC
        add hl,de
        djnz .ul
.fin:   ld hl,(dptr)             ; dimensione dei dati nell'immagine del runtime
        ld de,-DATA_BASE
        add hl,de
        IFDEF ROMMODE
        ld a,(curseg)
        or a
        jr nz,.nods
        ENDIF
        ld (HDRDSZ),hl
.nods:  ld hl,RT_END
        ld a,0C3h
        jp emit_jabs


        IFDEF ROMMODE
s_target: db "TARGET",0
tgtnames: db "ROM16",0,1,"ROM32",0,2,"ASCII8",0,3,"ASCII16",0,4,"KONAMI",0,5,"SCC",0,6,0

parse_target:                   ; token = nome del tipo di cartuccia
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld de,tgtnames
.nx:    ld a,(de)
        or a
        jp z,err_syntax
        push de
        ld hl,tbuf
        call str_eq
        jr z,.hit
        pop de
.sk:    ld a,(de)
        inc de
        or a
        jr nz,.sk
        inc de
        jr .nx
.hit:   pop hl
        inc de
        ld a,(de)
        ld (target),a
        ld (HDRTGT),a
        ret

s_rom:  db ".ROM",0
msg_romw: db 13,10,"ROM written: $"
msg_romk: db 13,10,"Press any key...$"

rom_done:                       ; messaggio, attesa di un tasto e ritorno all'editor
        ld de,msg_romw
        ld c,9
        call BDOS
        ld hl,oname
.p:     ld a,(hl)
        or a
        jr z,.pd
        push hl
        ld e,a
        ld c,2
        call BDOS
        pop hl
        inc hl
        jr .p
.pd:    ld de,msg_romk
        ld c,9
        call BDOS
        ld c,1
        call BDOS
        ld de,0081h
        ld a,' '
        ld (de),a
        inc de
        ld hl,fname
.n:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        jr .n
.e:     ld a,0Dh
        ld (de),a
        inc de
        ld hl,0081h
        ex de,hl
        or a
        sbc hl,de
        ld a,l
        ld (0080h),a
        ld hl,ldr_img
        ld de,LDR
        ld bc,ldr_size
        ldir
        jp LDR
        ENDIF

        IFNDEF ROMMODE
chk_rom:                        ; il sorgente ha "OPTION TARGET <cartuccia>": si passa al compilatore per cartucce
        ld hl,SRC
.l:     ld a,(hl)
        or a
        ret z
        or 20h
        cp 'o'
        jr nz,.n
        push hl
        ld de,s_optionl
        call match_ci
        jr nz,.f
        call skip_sp
        ld de,s_targetl
        call match_ci
        jr nz,.f
        call skip_sp
        ld a,(hl)
        or 20h
        cp 'c'
        jr z,.f                 ; TARGET COM: compilazione normale
        pop hl
        ld hl,ldr_img           ; carica QBCR.COM con la stessa riga di comando
        ld de,LDR
        ld bc,ldr_size
        ldir
        ld hl,s_qbcr
        ld de,LDR+3
        ld bc,11
        ldir
        jp LDR
.f:     pop hl
.n:     inc hl
        jr .l
match_ci:                       ; HL = testo, DE = modello minuscolo 0-terminato: Z se coincide (HL avanza)
.m:     ld a,(de)
        or a
        ret z
        ld b,a
        ld a,(hl)
        or 20h
        cp b
        ret nz
        inc hl
        inc de
        jr .m
skip_sp:
.s:     ld a,(hl)
        cp ' '
        jr z,.a
        cp 9
        ret nz
.a:     inc hl
        jr .s
s_optionl: db "option",0
s_targetl: db "target",0
s_qbcr: db "QBCR    COM"
        ENDIF

str_eq:                         ; HL = tbuf, DE = stringa 0-terminata: Z se uguali
.l:     ld a,(de)
        cp (hl)
        ret nz
        or a
        ret z
        inc hl
        inc de
        jr .l
s_numbered: db "NUMBERED",0
s_labels:   db "LABELS",0

line_loop:
.line:  ld a,(ttype)
        or a                    ; T_EOL
        jr nz,.st
        ld a,(onel)
        or a
        ret nz                  ; modalita' a riga singola: fine riga = ritorno
        ld a,(iseof)
        or a
        ret nz
        call next_tok
        jr .line
.st:    cp T_NUM
        jr nz,.nonum
        ld a,(mode)
        cp 2
        jp z,err_mode
        call num_to_name        ; numero di riga = etichetta
        call define_label
        call next_tok
        jr .line
.nonum: cp T_ID
        jr nz,.stmt
        call save_lex
        call next_tok
        ld a,':'
        call is_p
        jr nz,.notlab
        ld a,(mode)
        cp 1
        jp z,err_mode
        call define_label       ; etichetta "nome:" (tbuf ancora quello dell'identificatore)
        call next_tok
        jr .line
.notlab:
        call restore_lex
.stmt:  call statement
        ld a,(ttype)
        or a
        jr z,.line
        ld a,':'
        call is_p
        jp nz,err_syntax
        call next_tok
        jr .line

err_mode:
        ERR E_MODE

        IFNDEF ROMMODE
; NUMBERED: indice (numero, puntatore, riga) delle righe, ordinato per numero
sort_lines:
        ld hl,ENT
        ld (entend),hl
        ld hl,SRC
        ld de,1                 ; DE = numero di riga del sorgente
.ln:    ld a,(hl)
        cp ' '
        jr z,.sp
        cp 9
        jr z,.sp
        cp 0Dh
        jr nz,.go
.sp:    inc hl
        jr .ln
.go:    or a
        ret z                   ; fine sorgente
        cp 1Ah
        ret z
        cp 0Ah
        jr z,.eol
        cp 27h
        jr z,.skip              ; commento
        cp '0'
        jr c,.nonum
        cp '9'+1
        jr nc,.nonum
        push de
        push hl
        ld bc,0                 ; BC = numero
.nl:    ld a,(hl)
        sub '0'
        cp 10
        jr nc,.nd
        push hl
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ld c,a
        ld b,0
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        inc hl
        jr .nl
.nd:    pop hl                  ; HL = inizio riga
        pop de
        push hl
        push de
        push bc
        call ins_ent            ; inserisce (BC, HL, DE) in ordine
        pop bc
        pop de
        pop hl
        jr .skip
.nonum: ld (tline),de           ; riga senza numero: ammessa solo OPTION
        push hl
        ld de,s_optionw
        ld b,6
.oc:    ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc de
        djnz .oc
        pop hl
        ld de,(tline)
        jr .skip
.bad:   pop hl
        ERR E_MODE
.skip:  ld a,(hl)
        or a
        ret z
        cp 1Ah
        ret z
        inc hl
        cp 0Ah
        jr z,.nxt
        jr .skip
.eol:   inc hl
.nxt:   inc de
        jr .ln
s_optionw: db "OPTION"

ins_ent:                        ; BC = numero, HL = puntatore riga, DE = riga sorgente
        ld (en_num),bc
        ld (en_ptr),hl
        ld (en_ln),de
        ld (tline),de
        ld hl,(entend)
        ld de,ENTMAX
        or a
        sbc hl,de
        jp nc,err_big
        ld hl,(entend)
.up:    push hl
        ld de,ENT
        or a
        sbc hl,de
        pop hl
        jr z,.ins
        ld de,-6
        add hl,de               ; HL = record precedente
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = numero precedente
        ld hl,(en_num)
        or a
        sbc hl,de               ; nuovo - precedente
        pop hl
        jr z,.dup
        jr c,.up                ; nuovo < precedente: continua a risalire
        ld de,6
        add hl,de               ; dopo il precedente
        jr .ins
.dup:   ERR E_DUP
.ins:   ld (en_pos),hl
        ld de,(entend)
        ex de,hl
        or a
        sbc hl,de               ; HL = byte da spostare
        ld a,h
        or l
        jr z,.wr
        ld b,h
        ld c,l
        ld hl,(entend)
        dec hl                  ; ultimo byte sorgente
        ld de,(entend)
        push hl
        ld hl,5
        add hl,de
        ex de,hl                ; DE = entend + 5
        pop hl
        lddr
.wr:    ld hl,(en_pos)
        ld de,(en_num)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(en_ptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(en_ln)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(entend)
        ld de,6
        add hl,de
        ld (entend),hl
        ret
        ENDIF

statement:
        call statement0
        ld a,(tmpf)
        or a
        ret z
        xor a
        ld (tmpf),a
        jp emit_reset

emit_reset:                     ; libera le stringhe temporanee (clobbera DE nel programma)
        ld hl,(fcur)
        ld a,h
        or l
        jr nz,.f
        call emit_i
        db 8,0EDh,5Bh,low HEAP0,high HEAP0,0EDh,53h,low HEAPP,high HEAPP
        ret
.f:     call emit_i             ; dentro una funzione: heapp = valore salvato all'ingresso (ix-2)
        db 8,0DDh,5Eh,0FEh,0DDh,56h,0FFh,0EDh,53h
        ld hl,HEAPP
        jp emit_w

statement0:
        ld a,(ttype)
        cp T_KW
        jr z,.kw
        cp T_ID
        jp z,st_idstmt
        cp T_P
        jp nz,err_syntax
        ld a,(tval)
        cp '?'
        jp nz,err_syntax
        call next_tok
        jp st_print
.kw:    ld a,(tval)
        add a,a
        ld e,a
        ld d,0
        ld hl,kwjump
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call next_tok
        pop hl
        jp (hl)

kwjump: dw st_print, st_if, err_syntax, st_else, st_elseif, st_end, st_for, err_syntax
        dw err_syntax, st_next, st_while, st_wend, st_goto, st_gosub, st_return, st_cls
        dw st_locate, err_syntax, err_syntax, err_syntax, err_syntax, err_syntax, st_let, st_option
        dw st_input, st_dim, st_poke, st_sub, st_function, st_call, st_skip, st_shared
        dw st_exit, st_do, st_loop, err_syntax, st_select, st_case, err_syntax
        dw st_const, st_color, st_randomize, st_vpoke, st_out, st_sleep, st_stop
        dw st_screen, st_pset, st_preset, st_line, st_circle, st_palette, st_paint, st_put, err_syntax, st_get, st_draw, st_view, st_window
        dw st_vbank, st_vfill, st_vwrite, st_set, st_copy, st_data, st_read, st_restore, st_beep, st_sound, st_play, st_open, st_close, st_kill, st_write, st_segment, st_incbin, st_setbank, st_vcopy, st_mput, st_mread, st_mwrite, st_mfree, st_bload, st_bsave, st_field, st_lset, st_rset

; ---------------------------------------------------------------- espressioni
want_int:
        ld a,(etype)
        or a
        ret z
err_type:
        ERR E_TYPE
want_str:
        ld a,(etype)
        cp 1
        ret z
        jr err_type

expr:   jp e_or

e_or:   call e_and
.l:     ld a,K_OR
        call is_kw
        ld bc,0B3B2h
        jr z,.go
        ld a,K_XOR
        call is_kw
        ret nz
        ld bc,0ABAAh
.go:    push bc
        call want_int
        call next_tok
        EM1 0E5h
        call e_and
        call want_int
        pop bc
        call emit_logic
        jr .l

e_and:  call e_not
.l:     ld a,K_AND
        call is_kw
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_not
        call want_int
        ld bc,0A3A2h
        call emit_logic
        jr .l

emit_logic:                     ; C = op con D, B = op con E
        EM2 0D1h,7Ch            ; pop de ; ld a,h
        ld a,c
        call emit_a
        EM2 67h,7Dh             ; ld h,a ; ld a,l
        ld a,b
        call emit_a
        EM1 6Fh                 ; ld l,a
        ret

e_not:  ld a,K_NOT
        call is_kw
        jp nz,e_cmp
        call next_tok
        call e_not
        call want_int
        EM6 7Ch,2Fh,67h,7Dh,2Fh,6Fh
        ret

e_cmp:  call e_add
.l:     ld a,(ttype)
        cp T_P
        ret nz
        ld a,(tval)
        ld b,6
        ld hl,cmptab
.f:     cp (hl)
        jr z,.hit
        inc hl
        inc hl
        inc hl
        djnz .f
        ret
.hit:   inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de                 ; routine per interi
        ld a,(etype)
        push af                 ; tipo dell'operando sinistro
        call next_tok
        EM1 0E5h
        call e_add
        pop bc                  ; B = tipo sinistro
        ld a,(etype)
        cp b
        jp nz,err_type
        ld c,a                  ; tipo comune (emit_i clobbera A)
        EM1 0D1h
        ld a,c
        or a
        ld hl,RT_CMP
        jr z,.cp
        ld hl,RT_SCMP           ; stringhe
.cp:    ld a,0CDh
        call emit_jabs          ; call rt_cmp / rt_scmp
        pop hl                  ; routine booleana (b_eq ecc.)
        ld a,0CDh
        call emit_jabs
.res:   xor a
        ld (etype),a
        jr .l

cmptab: db '=':dw RT_BEQ
        db 1:dw RT_BNE
        db '<':dw RT_BLT
        db '>':dw RT_BGT
        db 2:dw RT_BLE
        db 3:dw RT_BGE

e_add:  call e_mod
.l:     ld a,'+'
        call is_p
        ld c,0
        jr z,.go
        ld a,'-'
        call is_p
        ret nz
        ld c,1
.go:    ld a,(etype)
        ld b,a                  ; tipo sinistro
        push bc
        call next_tok
        EM1 0E5h
        call e_mod
        pop bc
        ld a,(etype)
        cp b
        jp nz,err_type
        ld a,b
        or a
        jr nz,.str
        EM1 0D1h
        ld a,c
        or a
        jr nz,.sub
        EM1 19h                 ; add hl,de
        jr .l
.sub:   EM4 0EBh,0B7h,0EDh,52h  ; ex de,hl ; or a ; sbc hl,de
        jr .l
.str:   ld a,c
        or a
        jp nz,err_type          ; '-' sulle stringhe
        EM1 0D1h
        EM3 0CDh,low RT_SCAT,high RT_SCAT
        ld a,1
        ld (tmpf),a
        jr .l

e_mod:  call e_idiv
.l:     ld a,K_MOD
        call is_kw
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_idiv
        call want_int
        EM2 0D1h,0EBh
        EM3 0CDh,low RT_MOD,high RT_MOD
        jr .l

e_idiv: call e_mul
.l:     ld a,5Ch
        call is_p
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_mul
        call want_int
        EM2 0D1h,0EBh
        EM3 0CDh,low RT_DIV,high RT_DIV
        jr .l

e_mul:  call e_unary
.l:     ld a,'*'
        call is_p
        jr z,.mul
        ld a,'/'
        call is_p
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_unary
        call want_int
        EM2 0D1h,0EBh           ; '/' = divisione intera (niente float)
        EM3 0CDh,low RT_DIV,high RT_DIV
        jr .l
.mul:   call want_int
        call next_tok
        EM1 0E5h
        call e_unary
        call want_int
        EM1 0D1h
        EM3 0CDh,low RT_MUL,high RT_MUL
        jr .l

e_unary:
        ld a,'-'
        call is_p
        jr nz,.nm
        call next_tok
        call e_unary
        call want_int
        EM7 0EBh,21h,0,0,0B7h,0EDh,52h   ; ex de,hl ; ld hl,0 ; or a ; sbc hl,de
        ret
.nm:    ld a,'+'
        call is_p
        jr nz,primary
        call next_tok
        jr e_unary

primary:
        ld a,(ttype)
        cp T_NUM
        jr nz,.nn
        ld a,21h                ; ld hl,nn
        call emit_a
        ld hl,(tval)
        call emit_w
        xor a
        ld (etype),a
        jp next_tok
.nn:    cp T_STR
        jr nz,.ns
        call emit_strlit
        ld a,1
        ld (etype),a
        jp next_tok
.ns:    cp T_ID
        jp nz,.ni
        call make_nbuf
        ld hl,bitab
        ld de,nbuf
        call find_in
        jr c,.var
        add a,a                 ; funzione predefinita
        ld e,a
        ld d,0
        ld hl,bijump
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)
.var:   call find_func
        jr c,.nofn
        ld a,(hl)               ; (primo byte nome) - non usato; il tipo e' a +12
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        pop hl
        cp 2
        jp nz,err_syntax        ; una SUB non e' un'espressione
        ld de,(fcur)
        or a
        push hl
        sbc hl,de               ; funzione corrente?
        pop hl
        jr nz,.docall
        call save_lex           ; dentro la propria FUNCTION: senza '(' e' la variabile risultato
        call next_tok
        ld a,'('
        call is_p
        jr z,.cl2
        call restore_lex
        jr .nofn
.cl2:   call restore_lex
        call find_func
.docall:
        push hl
        call next_tok           ; nome
        pop hl
        call emit_args
        push hl
        call emit_callrec
        pop hl
        call emit_cleanup
        ld a,1
        ld (tmpf),a             ; (il risultato stringa e' sullo heap)
        ld de,15
        add hl,de
        ld a,(hl)
        ld (etype),a
        or a
        ret nz
        xor a
        ld (tmpf),a
        ret
.nofn: call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call find_rec           ; CONST?
        jr c,.nc
        push hl
        ld de,14
        add hl,de
        ld a,(hl)
        inc hl
        and (hl)
        cp 0FFh
        pop hl
        jr nz,.nc
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,21h                ; ld hl,valore
        push hl
        call emit_a
        pop hl
        call emit_w
        xor a
        ld (etype),a
        jp next_tok
.nc:    call resolve_var
        push hl
        push af
        call kind_type
        ld (etype),a
        pop af
        pop hl
        call emit_ldv
        jp next_tok
.arr:   call restore_lex
        call arr_is_mapper
        jp nz,mapper_read
        call arr_elem           ; HL = indirizzo dell'elemento
        ld a,(etype)
        or a
        ret nz                  ; stringa: HL e' gia' il puntatore
        EM4 5Eh,23h,56h,0EBh    ; ld e,(hl) ; inc hl ; ld d,(hl) ; ex de,hl
        ret
.ni:    cp T_P
        jp nz,err_syntax
        ld a,'('
        call is_p
        jp nz,err_syntax
        call next_tok
        call expr
        ld a,')'
        jp expect_p

make_nbuf:                      ; tbuf -> nbuf (testo normale, "CHR$" ecc.)
        ld hl,tbuf
        ld de,nbuf
        ld b,11
.l:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        djnz .l
.e:     ld a,(tbuf+11)
        cp '$'
        jr nz,.z
        ld (de),a
        inc de
.z:     xor a
        ld (de),a
        ret

; --- funzioni predefinite (il token corrente e' il nome)
bitab:  db "LEN",0,"ASC",0,"VAL",0,"ABS",0,"SGN",0,"RND",0,"PEEK",0,"CHR$",0,"STR$",0
        db "LEFT$",0,"RIGHT$",0,"MID$",0,"INKEY$",0,"TIMER",0,"VPEEK",0,"INP",0,"UBOUND",0,"POINT",0,"COLLISION",0,"BASE",0,"VDP",0,"STICK",0,"STRIG",0,"VREAD$",0,"EOF",0,"DATAWIN",0,"MAPPERSEGS",0,"MGET",0,"VARPTR",0
        db "MALLOC",0,"LOF",0
        db "MKI$",0,"CVI",0,0
bijump: dw bi_len, bi_asc, bi_val, bi_abs, bi_sgn, bi_rnd, bi_peek, bi_chr, bi_str
        dw bi_left, bi_right, bi_mid, bi_inkey, bi_timer, bi_vpeek, bi_inp, bi_ubound, bi_point, bi_coll
        dw bi_base, bi_vdp, bi_stick, bi_strig, bi_vread, bi_eof, bi_datawin, bi_mapsegs, bi_mget, bi_varptr, bi_malloc, bi_lof, bi_mki, bi_cvi

open_paren:
        ld a,'('
        jp expect_p
close_paren:
        ld a,')'
        jp expect_p

bi_len: ld hl,RT_LEN
        jr bi1s
bi_asc: ld hl,RT_ASC
        jr bi1s
bi_val: ld hl,RT_VAL
bi1s:   push hl                 ; un argomento stringa -> intero
        call next_tok
        call open_paren
        call expr
        call want_str
        call close_paren
        pop hl
        ld a,0CDh
        call emit_jabs
        xor a
        ld (etype),a
        ret

bi_chr: ld hl,RT_CHR
        ld c,1
        jr bi1i
bi_str: ld hl,RT_STR
        ld c,1
        jr bi1i
bi_rnd: ld hl,RT_RND
        ld c,0
bi1i:   push bc                 ; un argomento intero; C = tipo del risultato
        push hl
        call next_tok
        call open_paren
        call expr
        call want_int
        call close_paren
        pop hl
        ld a,0CDh
        call emit_jabs
        pop bc
        ld a,c
        ld (etype),a
        or a
        ret z
        ld (tmpf),a
        ret

bi_abs: call bi_arg_int
        call emit_i
        db 7,0CBh,7Ch,28h,03h,0CDh,low RT_NEG,high RT_NEG   ; bit 7,h ; jr z,+3 ; call rt_neg
        ret
bi_sgn: call bi_arg_int
        call emit_i
        db 16,0CBh,7Ch,20h,09h,7Ch,0B5h,28h,08h,21h,1,0,18h,03h,21h,0FFh,0FFh
        ret
bi_peek:
        call bi_arg_int
        EM4 7Eh,6Fh,26h,0       ; ld a,(hl) ; ld l,a ; ld h,0
        ret
bi_arg_int:
        call next_tok
        call open_paren
        call expr
        call want_int
        jp close_paren

bi_timer:
        call next_tok
        ld a,'('
        call is_p
        jr nz,.nop
        call next_tok
        ld a,')'
        call expect_p
.nop:   EM3 2Ah,low 0FC9Eh,high 0FC9Eh     ; ld hl,(JIFFY)
        xor a
        ld (etype),a
        ret

bi_inkey:
        call next_tok
        ld a,'('
        call is_p
        jr nz,.nop
        call next_tok
        ld a,')'
        call expect_p
.nop:   EM3 0CDh,low RT_INKEY,high RT_INKEY
        ld a,1
        ld (etype),a
        ld (tmpf),a
        ret

bi_left:
        ld hl,RT_LEFT
        jr bi2
bi_right:
        ld hl,RT_RIGHT
bi2:    push hl                 ; (stringa, intero) -> stringa
        call next_tok
        call open_paren
        call expr
        call want_str
        ld a,','
        call expect_p
        EM1 0E5h
        call expr
        call want_int
        call close_paren
        EM1 0D1h
        pop hl
        ld a,0CDh
        call emit_jabs
        ld a,1
        ld (etype),a
        ld (tmpf),a
        ret

bi_mid: call next_tok
        call open_paren
        call expr
        call want_str
        ld a,','
        call expect_p
        EM1 0E5h
        call expr
        call want_int
        ld a,','
        call is_p
        jr nz,.two
        call next_tok
        EM1 0E5h
        call expr
        call want_int
        EM2 0D1h,0C1h           ; pop de (inizio) ; pop bc (stringa)
        jr .go
.two:   call emit_i
        db 5,0EBh,0C1h,21h,0FFh,0   ; ex de,hl ; pop bc ; ld hl,255
.go:    call close_paren
        EM3 0CDh,low RT_MID,high RT_MID
        ld a,1
        ld (etype),a
        ld (tmpf),a
        ret

; ---------------------------------------------------------------- istruzioni
st_option:
st_skip:                        ; DECLARE e OPTION: resto della riga ignorato
.l:     ld a,(ttype)
        or a
        ret z
        call next_tok
        jr .l

st_let: ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
st_idstmt:                      ; identificatore all'inizio dell'istruzione: SUB senza CALL oppure assegnamento
        call make_nbuf
        ld hl,nbuf
        ld de,s_spritedol
        call str_eq
        jp z,st_sprdef
        ld hl,nbuf
        ld de,s_vdp
        call str_eq
        jp z,st_vdpset
        call find_func
        jr c,st_assign
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        pop hl
        cp 1
        jr nz,st_assign         ; FUNCTION: assegnamento al risultato
        push hl
        call next_tok
        pop hl
        jp call_sub
st_assign:
        call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call resolve_var
        push hl
        push af
        call next_tok
        ld a,'='
        call expect_p
        call expr
        pop af
        pop hl                  ; A = tipo di riferimento, HL = indirizzo/scostamento
        push af
        push hl
        call kind_type
        ld b,a
        ld a,(etype)
        cp b
        jp nz,err_type
        pop hl
        pop af
        jp emit_stv
.arr:   call restore_lex
        call arr_is_mapper
        jp nz,mapper_assign
        call arr_elem           ; HL = indirizzo dell'elemento
        ld a,(etype)
        push af
        EM1 0E5h
        ld a,'='
        call expect_p
        call expr
        pop af
        ld b,a
        ld a,(etype)
        cp b
        jp nz,err_type
        EM1 0D1h                ; pop de = indirizzo
        ld a,(etype)
        or a
        jr nz,.astr
        call emit_i
        db 5,7Dh,12h,13h,7Ch,12h        ; ld a,l ; ld (de),a ; inc de ; ld a,h ; ld (de),a
        ret
.astr:  EM3 0CDh,low RT_SCOPY,high RT_SCOPY
        ret

st_print0:
        ld c,1                  ; C = a capo finale
.l:     push bc
        call at_send
        pop bc
        jr z,.end
        ld a,';'
        call is_p
        jr nz,.nsc
        ld c,0
        push bc
        call next_tok
        pop bc
        jr .l
.nsc:   ld a,','
        call is_p
        jr nz,.item
        ld c,0
        push bc
        EM3 0CDh,low RT_ZONE,high RT_ZONE
        call next_tok
        pop bc
        jr .l
.item:  ld c,1
.num:   push bc
        call expr
        ld a,(etype)
        or a
        jr nz,.ps
        EM3 0CDh,low RT_PINT,high RT_PINT
        jr .pd
.ps:    EM3 0CDh,low RT_PSTR,high RT_PSTR
.pd:    pop bc
        ld c,1
        jr .l
.end:   ld a,c
        or a
        ret z
        EM3 0CDh,low RT_PNL,high RT_PNL
        ret

emit_strlit:                    ; token stringa -> ld hl,<len> ; jp oltre ; db len,testo
        ld a,(tlen)
        ld b,a
        ld hl,(tval)
emit_lit:                       ; HL = testo, B = lunghezza
        push hl
        push bc
        call get_pc
        ld de,6
        add hl,de               ; indirizzo del byte lunghezza = pc + 6
        ld a,21h
        call emit_a
        call emit_w
        pop bc
        push bc
        ld c,b
        ld b,0
        call get_pc
        ld de,4
        add hl,de
        add hl,bc               ; fine dei dati = pc + 4 + len (pc dopo il ld hl)
        ld a,0C3h
        call emit_jabs
        pop bc
        ld a,b
        call emit_a
        pop hl
        ld a,b
        or a
        ret z
.c:     ld a,(hl)
        inc hl
        call emit_a
        djnz .c
        ret

st_goto:
        ld a,0C3h
        jr jump_target
st_gosub:
        ld a,0CDh
jump_target:                    ; A = opcode; token = numero di riga o etichetta
        ld b,a
        ld a,(ttype)
        cp T_NUM
        jr nz,.id
        ld a,(mode)
        cp 2
        jp z,err_mode
        push bc
        call num_to_name
        pop bc
        jr .go
.id:    cp T_ID
        jp nz,err_syntax
        ld a,(mode)
        cp 1
        jp z,err_mode
.go:    ld a,b
        call label_jump
        jp next_tok

st_return:
        EM1 0C9h
        ret

st_cls: EM3 0CDh,low RT_CLS,high RT_CLS
        ret

st_locate:
        call expr
        call want_int
        EM1 0E5h
        ld a,','
        call expect_p
        call expr
        call want_int
        EM1 0D1h
        EM3 0CDh,low RT_LOCATE,high RT_LOCATE
        ret

; --- IF
cond_expr:                      ; espressione intera di condizione; rilascia i temporanei; HL (programma) != 0 se vera
        call expr
        call want_int
        ld a,(tmpf)
        or a
        jr z,.nt
        xor a
        ld (tmpf),a
        call emit_reset
.nt:    EM2 7Ch,0B5h            ; ld a,h ; or l
        ret

cond_jz:                        ; condizione -> salta se falsa alla catena (HL)
        push hl
        call cond_expr
        pop hl
        ld a,0CAh               ; jp z
        jp emit_jchain

st_if:  ld a,B_IF
        call push_blk
        inc hl                  ; campo a = catena dell'else
        call cond_jz
        ld a,K_THEN
        call is_kw
        jp nz,err_syntax
        call next_tok
        ld a,(ttype)
        or a
        ret z                   ; forma a blocchi: il blocco resta aperto
        call one_line           ; forma su riga singola
        ld a,K_ELSE
        call is_kw
        jr nz,.noelse
        call next_tok
        ld a,B_IF
        call need_blk
        inc hl
        inc hl
        inc hl                  ; campo b = catena della fine
        ld a,0C3h
        call emit_jchain
        ld a,B_IF
        call need_blk
        inc hl
        call patch_chain
        call one_line
        jr .fin
.noelse:
        ld a,B_IF
        call need_blk
        inc hl
        call patch_chain
.fin:   ld a,B_IF
        call need_blk
        inc hl
        inc hl
        inc hl
        call patch_chain
        ld hl,nblk
        dec (hl)
        ret

one_line:                       ; dopo THEN/ELSE: salto a riga/etichetta oppure istruzioni
        ld a,(ttype)
        cp T_NUM
        jr z,.goto
        cp T_ID
        jr nz,.stm
        call save_lex
        call next_tok
        ld a,(ttype)
        or a
        jr z,.lab
        ld a,(ttype)
        cp T_KW
        jr nz,.ntk
        ld a,(tval)
        cp K_ELSE
        jr z,.lab
.ntk:   ld a,':'
        call is_p
        jr z,.lab
        call restore_lex
        jr .stm
.lab:   call restore_lex
.goto:  ld a,0C3h
        jp jump_target
.stm:
.sl:    call statement
        ld a,':'
        call is_p
        ret nz
        call next_tok
        jr .sl

st_elseif:
        ld a,B_IF
        call need_blk
        push hl
        inc hl
        inc hl
        inc hl
        ld a,0C3h
        call emit_jchain
        pop hl
        inc hl
        push hl
        call patch_chain
        pop hl
        call cond_jz
        ld a,K_THEN
        jp expect_kw

st_else:
        ld a,B_IF
        call need_blk
        push hl
        inc hl
        inc hl
        inc hl
        ld a,0C3h
        call emit_jchain
        pop hl
        inc hl
        jp patch_chain

st_end: ld a,K_IF
        call is_kw
        jr z,.endif
        ld a,K_SUB
        call is_kw
        jr z,.esub
        ld a,K_FUNCTION
        call is_kw
        jr z,.efun
        ld a,K_SELECT
        call is_kw
        jr z,.esel
        ld a,0C3h
        ld hl,RT_END
        jp emit_jabs
.esub:  ld c,1
        jr .endf
.efun:  ld c,2
.endf:  push bc
        call next_tok
        pop bc
        jp end_func
.esel:  call next_tok
        ld a,B_SEL
        call need_blk
        push hl
        inc hl
        call patch_chain        ; CASE senza corrispondenze -> qui
        pop hl
        inc hl
        inc hl
        inc hl
        call patch_chain        ; fine dei CASE
        ld a,B_SEL
        call need_blk
        ld de,9
        add hl,de
        ld a,(hl)
        or a
        jr nz,.sstr
        EM1 0D1h                ; pop de (scarta il valore del SELECT)
        jr .sdone
.sstr:  call emit_i             ; libera la copia da 256 byte: ld hl,256 ; add hl,sp ; ld sp,hl
        db 5,21h,0,1,39h,0F9h
.sdone:
        ld hl,nblk
        dec (hl)
        ret
.endif: call next_tok
        ld a,B_IF
        call need_blk
        push hl
        inc hl
        call patch_chain
        pop hl
        inc hl
        inc hl
        inc hl
        call patch_chain
        ld hl,nblk
        dec (hl)
        ret

; --- FOR / NEXT
st_for: ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call kind_type
        or a
        jp nz,err_type
        call next_tok
        ld a,'='
        call expect_p
        call expr
        call want_int
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv           ; var = valore iniziale
        ld a,K_TO
        call expect_kw
        call expr
        call want_int
        EM1 0E5h                ; push hl (limite)
        ld hl,1
        ld (tmps),hl
        ld a,K_STEP
        call is_kw
        jr nz,.nstep
        call next_tok
        ld a,'-'
        call is_p
        jr nz,.pos
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld de,0
        ex de,hl
        or a
        sbc hl,de
        ld (tmps),hl
        jr .stp
.pos:   ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld (tmps),hl
.stp:   call next_tok
.nstep: ld a,B_FOR
        call push_blk
        ld a,(tmpk)
        ld de,9
        add hl,de
        ld (hl),a               ; +9 = tipo di riferimento
        ld de,-8
        add hl,de               ; +1
        ld de,(tmpv)
        ld (hl),e
        inc hl
        ld (hl),d               ; a = variabile
        inc hl
        ld de,(tmps)
        ld (hl),e
        inc hl
        ld (hl),d               ; b = passo
        inc hl
        push hl
        call get_pc
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d               ; c = inizio del ciclo
        EM2 0D1h,0D5h           ; pop de ; push de
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_ldv           ; ld hl,var
        EM1 0EBh
        EM3 0CDh,low RT_CMP,high RT_CMP
        ld a,(tmps+1)
        bit 7,a
        push af
        ld a,B_FOR
        call need_blk
        ld de,7
        add hl,de               ; HL = &catena d'uscita
        pop af
        jr nz,.neg
        EM2 38h,03h             ; jr c,+3
        ld a,0C2h               ; jp nz,uscita
        jp emit_jchain
.neg:   ld a,0DAh               ; jp c,uscita
        jp emit_jchain

st_next:
        ld a,B_FOR
        call need_blk
        ld a,(ttype)
        cp T_ID
        jr nz,.nn
        push hl
        call next_tok
        pop hl
.nn:    push hl
        ld de,9
        add hl,de
        ld a,(hl)
        ld (tmpk),a
        pop hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tmpv),de            ; variabile
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (tmps),bc            ; passo
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = inizio del ciclo
        push de
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_ldv           ; ld hl,var
        ld a,11h
        call emit_a
        ld hl,(tmps)
        call emit_w             ; ld de,passo
        EM1 19h                 ; add hl,de
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv           ; var = hl
        pop hl
        ld a,0C3h
        call emit_jabs          ; jp inizio
        ld a,B_FOR
        call need_blk
        ld de,7
        add hl,de
        call patch_chain        ; uscita
        EM1 0D1h                ; pop de (scarta il limite)
        ld hl,nblk
        dec (hl)
        ret

; --- WHILE / WEND
st_while:
        ld a,B_WHILE
        call push_blk
        push hl
        call get_pc
        ex de,hl
        pop hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d               ; a = inizio
        inc hl                  ; b = catena d'uscita
        call cond_jz
        ret

st_poke:
        call expr
        call want_int
        EM1 0E5h
        ld a,','
        call expect_p
        call expr
        call want_int
        EM3 0D1h,7Dh,12h        ; pop de ; ld a,l ; ld (de),a
        ret

st_input:
        ld a,'#'
        call is_p
        jp z,st_finput
        ld c,1                  ; C = stampa "? "
        ld a,(ttype)
        cp T_STR
        jr nz,.q
        call emit_strlit
        EM3 0CDh,low RT_PSTR,high RT_PSTR
        call next_tok
        ld a,','
        call is_p
        jr nz,.semi
        ld c,0
        call next_tok
        jr .q
.semi:  ld a,';'
        call expect_p
.q:     ld a,c
        or a
        jr z,.var
        ld b,2
        ld hl,s_qm
        call emit_lit
        EM3 0CDh,low RT_PSTR,high RT_PSTR
.var:   ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 0CDh,low RT_INPUT,high RT_INPUT
        ld a,(tmpk)
        call kind_type
        or a
        jr nz,.istr
        EM3 0CDh,low RT_VAL,high RT_VAL
.istr:  ld a,(tmpk)
        ld hl,(tmpv)
        jp emit_stv
s_qm:   db "? "

st_dim:
        ld hl,(fcur)
        ld a,h
        or l
        jp nz,err_syntax        ; DIM solo a livello principale
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_rec
        jp nc,.dup
        ld a,(vtyp)
        push af
        push hl                 ; posto del nuovo record
        ld hl,tbuf              ; il nome dell'array va salvato: leggere una CONST sovrascrive tbuf
        ld de,nbuf
        ld bc,16
        ldir
        call next_tok
        ld a,'('
        call expect_p
        call num_or_const
        inc de                  ; elementi = massimo indice + 1
        push de
        call next_tok
        ld a,')'
        call expect_p
        xor a
        ld (mapf),a
        ld a,(ttype)
        cp T_ID
        jr nz,.nmp
        ld hl,tbuf
        ld de,s_mapper
        call str_eq
        jr nz,.nmp
        ld a,1                  ; DIM x(n) MAPPER: l'array sta nei segmenti del mapper RAM
        ld (mapf),a
        call next_tok
.nmp:   pop de
        pop hl
        pop af
        push hl
        ld h,d
        ld l,e
        or a
        jr z,.int
        ld a,(mapf)
        or a
        jp nz,err_type          ; solo array di interi
        ld a,d                  ; stringhe: massimo 255 elementi da 256 byte
        or a
        jp nz,err_mem
        ld b,e
        ld c,0
        jr .go
.int:   add hl,hl
        ld b,h
        ld c,l
.go:    push de                 ; numero di elementi
        ld hl,nbuf              ; ripristina il nome
        ld de,tbuf
        push bc
        ld bc,16
        ldir
        pop bc
        pop de
        pop hl
        ld a,(mapf)
        or a
        jr nz,.map
        call new_rec
.cm:    ld a,','
        call is_p
        ret nz
        call next_tok
        jp .l
.map:   ld (mapcnt),de          ; descrittore (6 byte) nei dati; il record ricorda il numero di elementi con il bit 15 acceso
        set 7,d
        ld bc,6
        call new_rec
        push hl
        ld a,21h                ; ld hl,descrittore ; ld de,numero ; call RT_MDIM
        call emit_a
        pop hl
        call emit_w
        ld a,11h
        call emit_a
        ld hl,(mapcnt)
        call emit_w
        EM3 0CDh,low RT_MDIM,high RT_MDIM
        xor a
        ld (mapf),a
        jr .cm
.dup:   ERR E_DUP

; --- tabella delle funzioni
find_func:                      ; tbuf -> HL = record, NC se trovato; C se manca
        ld a,(nfunc)
        or a
        jr z,.nf
        ld b,a
        ld hl,FUNT
.l:     call name_eq
        jr z,.f
        ld de,FUNREC
        add hl,de
        djnz .l
.nf:    scf
        ret
.f:     or a
        ret

prescan:                        ; registra le firme di SUB/FUNCTION di tutto il sorgente
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        xor a
        ld (iseof),a
        call next_tok
.t:     ld a,(ttype)
        or a
        jr nz,.nz
        ld a,(iseof)
        or a
        ret nz
        call next_tok
        jr .t
.nz:    cp T_NUM
        jr nz,.k
        call next_tok
        jr .t
.k:     cp T_KW
        jr nz,.skip
        ld a,(tval)
        cp K_SUB
        jr z,.reg
        cp K_FUNCTION
        jr nz,.skip
.reg:   call reg_func
.skip:  ld a,(ttype)
        or a
        jr z,.t
        cp T_KW
        jr nz,.adv
        ld a,(tval)
        cp K_WINDOW
        jr nz,.nw
        ld a,1
        ld (usewin),a           ; il programma usa WINDOW
        jr .adv
.nw:    IFDEF ROMMODE
        cp K_SEGMENT
        jr nz,.adv
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jr nz,.skip
        ld a,(tval)
        ld (pseg),a
        ENDIF
.adv:   call next_tok
        jr .skip

reg_func:                       ; token = SUB/FUNCTION: crea il record con nome e parametri
        ld a,(tval)
        sub K_SUB
        inc a                   ; 1 = SUB, 2 = FUNCTION
        push af
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_func
        jp nc,err_dup2
        ld a,(nfunc)
        cp MAXFUN
        jr c,.ok
        ERR E_MANY
.ok:    ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl
        add hl,hl               ; *24
        ld de,FUNT
        add hl,de
        ld (rf_rec),hl
        ld a,(nfunc)
        inc a
        ld (nfunc),a
        IFDEF ROMMODE
        call rom_regfunc
        ENDIF
        ex de,hl
        ld hl,tbuf
        ld bc,12
        ldir                    ; nome
        pop af
        ld (de),a               ; +12 tipo
        inc de
        xor a
        ld (de),a               ; +13 numero di parametri
        inc de
        ld a,(npart)
        ld (de),a               ; +14 primo parametro
        inc de
        ld a,(tsuf)
        ld (de),a               ; +15 tipo del risultato
        inc de
        xor a
        ld b,8
.z:     ld (de),a               ; +16 definita, +17 +18 indirizzo, +19 +20 catena, +21 maschera, +22 +23
        inc de
        djnz .z
        call next_tok
        ld a,'('
        call is_p
        jp nz,.done
        call next_tok
.pl:    ld a,')'
        call is_p
        jp z,.close
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(npart)
        cp MAXPAR
        jr c,.pok
        ERR E_MANY
.pok:   call save_lex           ; parametro array: nome seguito da "()"
        call next_tok
        ld a,'('
        call is_p
        ld a,0
        jr nz,.na
        inc a
.na:    ld (tmpk),a
        call restore_lex
        ld hl,(rf_rec)
        ld de,13
        add hl,de
        ld a,(hl)
        cp 8
        jr c,.p8
        ERR E_MANY
.p8:    inc a
        ld (hl),a               ; numero di parametri
        dec a
        ld c,a                  ; indice del parametro
        ld a,(npart)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PART
        add hl,de
        ex de,hl
        ld hl,tbuf
        push bc
        ld bc,12
        ldir
        pop bc
        ld a,(tsuf)
        ld (de),a               ; tipo del parametro
        inc de
        ld a,(tmpk)
        ld (de),a               ; +13 = 1 se array
        ld a,(npart)
        inc a
        ld (npart),a
        ld a,(tsuf)
        or a
        jr z,.nms
        ld e,21                 ; maschera dei tipi stringa
        push bc
        call rf_bit
        pop bc
.nms:   ld a,(tmpk)
        or a
        jr z,.nma
        ld e,22                 ; maschera dei parametri array
        push bc
        call rf_bit
        pop bc
.nma:   ld hl,(rf_rec)          ; parole sullo stack: 1 (scalare) o 2 (array: base e numero elementi)
        ld de,23
        add hl,de
        ld a,(tmpk)
        inc a
        add a,(hl)
        ld (hl),a
.nm:    call next_tok
        ld a,(tmpk)
        or a
        jr z,.nn
        ld a,'('
        call is_p
        jp nz,err_syntax
        call next_tok
        ld a,')'
        call is_p
        jp nz,err_syntax
        call next_tok
.nn:    ld a,','
        call is_p
        jp nz,.pl
        call next_tok
        jp .pl
.close: call next_tok
.done:  ret
err_dup2:
        ERR E_DUP

rf_bit:                         ; C = indice, E = scostamento nel record: imposta il bit
        ld b,c
        ld a,1
        inc b
.sh:    dec b
        jr z,.sd
        add a,a
        jr .sh
.sd:    ld c,a
        ld hl,(rf_rec)
        ld d,0
        add hl,de
        ld a,(hl)
        or c
        ld (hl),a
        ret

ca_bit:                         ; DE = scostamento di una maschera nel record -> A = bit dell'argomento corrente
        ld hl,(ca_rec)
        add hl,de
        ld b,(hl)
        ld a,(ca_i)
        ld c,a
        ld a,b
        inc c
.s:     dec c
        jr z,.d
        rrca
        jr .s
.d:     and 1
        ret

emit_args:                      ; HL = record; legge gli argomenti (anche fra parentesi) ed emette i push; ritorna HL = record
        ld de,(ca_rec)
        push de
        ld a,(ca_i)
        ld d,a
        ld a,(ca_paren)
        ld e,a
        push de
        ld (ca_rec),hl
        xor a
        ld (ca_i),a
        ld (ca_paren),a
        ld a,'('
        call is_p
        jr nz,.l
        ld a,1
        ld (ca_paren),a
        call next_tok
.l:     ld hl,(ca_rec)
        ld de,13
        add hl,de
        ld a,(ca_i)
        cp (hl)
        jp nc,.done
        or a
        jr z,.first
        ld a,','
        call expect_p
.first: ld de,22
        call ca_bit
        or a
        jr z,.sc
        call emit_arrarg        ; parametro array: nome (con o senza "()")
        jr .nx
.sc:    call expr
        ld de,21
        call ca_bit
        ld b,a
        ld a,(etype)
        cp b
        jp nz,err_type
        IFDEF ROMMODE
        ld a,(etype)
        or a
        jr z,.pp
        ld hl,(ca_rec)          ; stringa verso un altro segmento: copia nello heap (i letterali stanno nel segmento di chi chiama)
        call rec_far
        cp 0FFh
        jr z,.pp
        EM3 0CDh,low RT_SDUP,high RT_SDUP
.pp:
        ENDIF
        EM1 0E5h                ; push hl
.nx:    ld a,(ca_i)
        inc a
        ld (ca_i),a
        jp .l
.done:  ld a,(ca_paren)
        or a
        jr z,.np
        ld a,')'
        call expect_p
.np:    ld hl,(ca_rec)
        pop de
        ld a,e
        ld (ca_paren),a
        ld a,d
        ld (ca_i),a
        pop de
        ld (ca_rec),de
        ret

emit_arrarg:                    ; argomento array: emette push base ; push numero elementi
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld de,21
        call ca_bit
        ld b,a
        ld a,(tsuf)
        cp b
        jp nz,err_type          ; tipo degli elementi diverso da quello del parametro
emit_arrref:                    ; token = nome: emette push base ; push numero elementi (array globale o parametro)
        call find_arrparam
        jr c,.glob
        ld c,l                  ; array parametro di questa funzione: copia la coppia dal frame
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        add a,2
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        add a,3
        call emit_a
        EM1 0E5h                ; push base
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        inc a
        call emit_a
        EM1 0E5h                ; push numero elementi
        jr .end
.glob:  call find_rec
        jp c,err_type
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        bit 7,b
        jp nz,err_type
        ld a,b
        or c
        jp z,err_type           ; non e' un array
        ld a,b
        and c
        inc a
        jp z,err_type           ; e' una CONST
        push bc
        ex de,hl
        ld a,21h                ; ld hl,base ; push hl
        push hl
        call emit_a
        pop hl
        call emit_w
        EM1 0E5h
        pop hl
        ld a,21h                ; ld hl,numero ; push hl
        push hl
        call emit_a
        pop hl
        call emit_w
        EM1 0E5h
.end:   call next_tok           ; nome
        ld a,'('
        call is_p
        ret nz
        call next_tok
        ld a,')'
        jp expect_p

find_arrparam:                  ; tbuf = nome: NC se e' un parametro array della funzione corrente (A = tipo, HL = scostamento)
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.no
        ld a,(nloc)
        or a
        jr z,.no
        ld b,a
        ld hl,LOCT
.l:     call name_eq
        jr z,.f
        ld de,16
        add hl,de
        djnz .l
.no:    scf
        ret
.f:     ld de,12
        add hl,de
        ld a,(hl)
        cp 5
        jr c,.no
        cp 7
        jr nc,.no
        push af
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop af
        or a
        ret

emit_callrec:                   ; HL = record: call della routine (o catena di fixup se non ancora definita)
        IFDEF ROMMODE
        push hl
        call rec_far
        pop hl
        cp 0FFh
        jr z,.direct
        push af                 ; routine in un altro segmento: ld a,indice ; call RT_FARCALL
        ld a,3Eh
        call emit_a
        pop af
        call emit_a
        ld hl,RT_FARCALL
        ld a,0CDh
        jp emit_jabs
.direct:
        ENDIF
        ld de,16
        add hl,de
        ld a,(hl)
        or a
        jr z,.fwd
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,0CDh
        jp emit_jabs
.fwd:   ld de,3
        add hl,de               ; +19 = testa della catena
        ld a,0CDh
        jp emit_jchain

emit_cleanup:                   ; HL = record: toglie gli argomenti dallo stack (preserva HL del programma)
        push hl
        ld de,23
        add hl,de
        ld a,(hl)               ; parole sullo stack
        pop hl
        or a
        ret z
        push hl
        add a,a
        ld c,a                  ; byte da rilasciare
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        jr nz,.sub
        EM1 0EBh                ; ex de,hl (conserva il risultato)
.sub:   ld a,21h
        call emit_a
        ld l,c
        ld h,0
        call emit_w             ; ld hl,2n
        EM2 39h,0F9h            ; add hl,sp ; ld sp,hl
        pop hl
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        jr nz,.end
        EM1 0EBh
.end:   pop hl
        ret

st_call:
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf              ; CALL FAR nome: FAR e' facoltativo (la chiamata fra segmenti e' automatica)
        ld de,s_far
        call str_eq
        jr nz,.nf
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
.nf:
        call find_func
        jp c,err_label
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        pop hl
        cp 1
        jp nz,err_syntax
        push hl
        call next_tok
        pop hl
call_sub:                       ; HL = record SUB
        call emit_args
        push hl
        call emit_callrec
        pop hl
        jp emit_cleanup
err_label:
        ERR E_LABEL

st_sub: ld c,1
        call begin_func
        jp st_skip              ; parametri gia' registrati dal prescan
st_function:
        ld c,2
        call begin_func
        jp st_skip
begin_func:                     ; token = nome; C = 1 SUB / 2 FUNCTION
        ld hl,(fcur)
        ld a,h
        or l
        jp nz,err_syntax        ; non annidabili
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_func
        jp c,err_label
        ld (fcur),hl
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        cp c
        jp nz,err_syntax
        pop hl
        ld hl,0
        ld (fexit),hl
        xor a
        ld (nloc),a
        ld (nint),a
        ld (nstr),a
        ld hl,fskiph            ; il flusso normale scavalca il corpo
        ld a,0C3h
        call emit_jchain
        ld hl,(fcur)            ; definisce l'ingresso
        push hl
        call get_pc
        ex de,hl
        pop hl
        push hl
        ld bc,16
        add hl,bc
        ld (hl),1
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl                  ; +19 catena delle chiamate precedenti
        call patch_chain
        pop hl
        IFDEF ROMMODE
        call rom_defsub
        ENDIF
        call emit_i             ; push ix ; ld ix,0 ; add ix,sp ; ld hl,-FRAME ; add hl,sp ; ld sp,hl
        db 8,0DDh,0E5h,0DDh,21h,0,0,0DDh,39h
        ld a,21h
        call emit_a
        ld hl,(outp)
        ld (framep),hl          ; operando da correggere a fine funzione
        ld hl,0
        call emit_w
        EM2 39h,0F9h
        call emit_i             ; salva heapp: ld hl,(heapp) ; ld (ix-2),l ; ld (ix-1),h
        db 9,2Ah,low HEAPP,high HEAPP,0DDh,75h,0FEh,0DDh,74h,0FFh
        ; parametri come variabili: tipo 3 (intero) / 4 (stringa) / 5, 6 (array di interi / stringhe)
        ld hl,(fcur)
        ld de,13
        add hl,de
        ld a,(hl)
        or a
        jr z,.np
        ld c,a                  ; C = indice (si scende dall'ultimo: il primo argomento e' il piu' profondo)
        ld hl,4
        ld (tmps),hl            ; scostamento corrente
.pl:    dec c
        push bc
        ld hl,(fcur)
        ld de,14
        add hl,de
        ld a,(hl)
        add a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PART
        add hl,de
        push hl
        ld de,tbuf              ; nome del parametro -> tbuf
        ld bc,12
        ldir
        pop hl
        ld de,12
        add hl,de
        ld b,(hl)               ; tipo (0 int / 1 str)
        inc hl
        ld a,(hl)               ; 1 = array
        or a
        ld a,3
        jr z,.k
        ld a,5
.k:     add a,b
        ld (tmpk),a
        ld de,(tmps)
        call loct_add
        ld a,(tmpk)
        ld de,2
        cp 5
        jr c,.s1
        ld de,4
.s1:    ld hl,(tmps)
        add hl,de
        ld (tmps),hl
        pop bc
        ld a,c
        or a
        jr nz,.pl
.np:    ld hl,(fcur)            ; variabile risultato delle FUNCTION
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        ret nz
        ld hl,(fcur)
        ld de,tbuf
        ld bc,12
        ldir                    ; il nome della funzione e' il nome del risultato
        ld a,(tbuf+11)
        cp '$'
        ld a,0
        jr nz,.r
        inc a
.r:     ld (tsuf),a
        call resolve_var        ; crea la variabile locale risultato
        ld (tmpk),a
        ld (tmpv),hl
        cp 3
        jr z,.rs
        ld a,(tmpk)             ; intero: ld hl,0 ; salva
        EM3 21h,0,0
        ld a,(tmpk)
        ld hl,(tmpv)
        jp emit_stv
.rs:    ld a,(tmpk)             ; stringa: parte vuota
        ld hl,(tmpv)
        call emit_ldv
        EM2 36h,0               ; ld (hl),0
        ret

end_func:                       ; C = 1 SUB / 2 FUNCTION
        ld hl,(fcur)
        ld a,h
        or l
        jp z,err_syntax
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        cp c
        jp nz,err_syntax
        pop hl
        ld a,(nblk)
        or a
        jp nz,err_open2
        ld hl,fexit
        call patch_chain
        ld hl,(fcur)
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        jr nz,.ret
        ld hl,(fcur)            ; risultato: richiama la variabile locale
        ld de,tbuf
        ld bc,12
        ldir
        ld a,(tbuf+11)
        cp '$'
        ld a,0
        jr nz,.r
        inc a
.r:     ld (tsuf),a
        push af
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        pop af
        or a
        jr nz,.str
        ld a,(tmpk)             ; intero
        ld hl,(tmpv)
        call emit_ldv
        call emit_i             ; ripristina heapp (usa DE)
        db 8,0DDh,5Eh,0FEh,0DDh,56h,0FFh,0EDh,53h
        ld hl,HEAPP
        call emit_w
        jr .ret
.str:   call emit_i             ; heapp ripristinato, poi copia del risultato sullo heap
        db 8,0DDh,5Eh,0FEh,0DDh,56h,0FFh,0EDh,53h
        ld hl,HEAPP
        call emit_w
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_ldv
        EM3 0CDh,low RT_SDUP,high RT_SDUP
.ret:   call emit_i             ; ld sp,ix ; pop ix ; ret
        db 5,0DDh,0F9h,0DDh,0E1h,0C9h
        ld a,(nstr)             ; dimensione del frame: 64 + 256 * stringhe locali (operando = -frame)
        ld h,a
        ld l,64
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
        ld hl,(framep)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,fskiph
        call patch_chain
        ld hl,0
        ld (fcur),hl
        ret
err_open2:
        ERR E_OPEN

st_shared:                      ; SHARED a, b$: i nomi restano globali dentro la SUB/FUNCTION
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.nx
        ld a,2
        ld de,0
        call loct_add
.nx:    call next_tok
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_exit:
        ld a,(ttype)
        cp T_KW
        jp nz,err_syntax
        ld a,(tval)
        cp K_SUB
        jr z,.fn
        cp K_FUNCTION
        jr z,.fn
        ld c,B_FOR
        cp K_FOR
        jr z,.blk
        ld c,B_DO
        cp K_DO
        jr z,.blk
        ld c,B_WHILE
        cp K_WHILE
        jr z,.blk
        jp err_syntax
.fn:    ld hl,(fcur)
        ld a,h
        or l
        jp z,err_syntax
        call next_tok
        ld hl,fexit
        ld a,0C3h
        jp emit_jchain
.blk:   push bc
        call next_tok
        pop bc
        call find_blk
        ld a,c
        cp B_FOR
        ld de,7
        jr z,.o
        ld de,3
.o:     add hl,de
        ld a,0C3h
        jp emit_jchain

; --- DO / LOOP
st_do:  ld a,B_DO
        call push_blk
        push hl
        call get_pc
        ex de,hl
        pop hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d               ; a = inizio
        ld a,K_WHILE
        call is_kw
        jr z,.w
        ld a,K_UNTIL
        call is_kw
        ret nz
        call next_tok           ; DO UNTIL cond: esce se vera
        call cond_expr
        ld a,B_DO
        call need_blk
        ld de,3
        add hl,de
        ld a,0C2h               ; jp nz,uscita
        jp emit_jchain
.w:     call next_tok           ; DO WHILE cond: esce se falsa
        ld a,B_DO
        call need_blk
        ld de,3
        add hl,de
        jp cond_jz

st_loop:
        ld a,B_DO
        call need_blk
        push hl
        ld a,K_WHILE
        call is_kw
        ld c,0C2h               ; LOOP WHILE: torna all'inizio se vera
        jr z,.c
        ld a,K_UNTIL
        call is_kw
        ld c,0CAh               ; LOOP UNTIL: torna all'inizio se falsa
        jr z,.c
        pop hl
        jr .plain
.c:     push bc
        call next_tok
        call cond_expr
        pop bc
        pop hl
        push hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,c
        call emit_jabs
        pop hl
        jr .fin
.plain: push hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,0C3h
        call emit_jabs
        pop hl
.fin:   inc hl
        inc hl
        inc hl
        call patch_chain        ; uscita
        ld hl,nblk
        dec (hl)
        ret

; --- SELECT CASE (interi)
st_select:
        ld a,K_CASE
        call expect_kw
        call expr
        ld a,(etype)
        ld (tmpk),a             ; 0 = selettore intero, 1 = stringa
        or a
        jr z,.tmp
        call emit_i             ; stringa: copia di 256 byte sullo stack (resta valida per tutto il blocco)
        db 7,0EBh,21h,0,0FFh,39h,0F9h,0EBh
        EM3 0CDh,low RT_SCOPY,high RT_SCOPY
.tmp:   ld a,(tmpf)
        or a
        jr z,.nt
        xor a
        ld (tmpf),a
        call emit_reset
.nt:    ld a,(tmpk)
        or a
        jr nz,.blk
        EM1 0E5h                ; intero: push hl (il valore resta sullo stack per tutto il blocco)
.blk:   ld a,B_SEL
        call push_blk
        ld de,9
        add hl,de
        ld a,(tmpk)
        ld (hl),a               ; +9 = tipo del selettore
        ret

want_sel:                       ; il valore del CASE deve avere il tipo del selettore
        ld a,B_SEL
        call need_blk
        ld de,9
        add hl,de
        ld b,(hl)
        ld a,(etype)
        cp b
        ret z
        jp err_type

emit_seltest:                   ; confronta selettore (sullo stack) con HL (valore del CASE): flag come rt_cmp/rt_scmp
        ld a,B_SEL
        call need_blk
        ld de,9
        add hl,de
        ld a,(hl)
        or a
        jr nz,.s
        EM2 0D1h,0D5h           ; pop de ; push de
        EM3 0CDh,low RT_CMP,high RT_CMP
        ret
.s:     call emit_i             ; DE = copia del selettore (SP), HL = valore del CASE
        db 6,0EBh,21h,0,0,39h,0EBh
        EM3 0CDh,low RT_SCMP,high RT_SCMP
        ret

st_case:
        ld a,B_SEL
        call need_blk
        push hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,.first
        pop hl                  ; CASE precedente: il suo corpo salta alla fine
        push hl
        inc hl
        inc hl
        inc hl
        ld a,0C3h
        call emit_jchain
        pop hl
        push hl
        inc hl
        call patch_chain        ; i test falliti arrivano qui
.first: pop hl
        ld a,K_ELSE
        call is_kw
        jr nz,.tests
        jp next_tok             ; CASE ELSE
.tests: ld hl,0
        ld (chfail),hl
.tl:    ld a,K_IS
        call is_kw
        jr nz,.val
        call next_tok           ; IS op expr
        ld a,(ttype)
        cp T_P
        jp nz,err_syntax
        ld a,(tval)
        ld b,6
        ld hl,cmptab
.f:     cp (hl)
        jr z,.hit
        inc hl
        inc hl
        inc hl
        djnz .f
        jp err_syntax
.hit:   inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call next_tok
        call expr
        call want_sel
        call emit_seltest
        pop hl
        ld a,0CDh
        call emit_jabs          ; call b_xx
        EM2 7Ch,0B5h
        ld a,B_SEL
        call need_blk
        ld de,5
        add hl,de               ; c = catena del corpo
        ld a,0C2h               ; jp nz,corpo
        call emit_jchain
        jr .more
.val:   call expr
        call want_sel
        ld a,K_TO
        call is_kw
        jr z,.range
        call emit_seltest
        ld a,B_SEL
        call need_blk
        ld de,5
        add hl,de
        ld a,0CAh               ; jp z,corpo
        call emit_jchain
        jr .more
.range: call next_tok
        call emit_seltest
        ld hl,chfail
        ld a,0DAh               ; jp c,fallito (valore < inizio)
        call emit_jchain
        call expr
        call want_sel
        call emit_seltest
        ld a,B_SEL
        call need_blk
        ld de,5
        add hl,de
        push hl
        ld a,0CAh               ; jp z,corpo
        call emit_jchain
        pop hl
        ld a,0DAh               ; jp c,corpo
        call emit_jchain
        ld hl,chfail
        call patch_chain
.more:  ld a,','
        call is_p
        jr nz,.end
        call next_tok
        jp .tl
.end:   ld a,B_SEL
        call need_blk
        push hl
        inc hl
        ld a,0C3h
        call emit_jchain        ; nessuna corrispondenza: al prossimo CASE
        pop hl
        ld de,5
        add hl,de
        jp patch_chain          ; il corpo comincia qui

num_or_const:                    ; numero o CONST -> DE = valore (il token non e' consumato)
        ld a,(ttype)
        cp T_NUM
        jr nz,.id
        ld de,(tval)
        ret
.id:    cp T_ID
        jp nz,err_syntax
        call find_rec
        jp c,err_syntax
        push hl
        ld de,14
        add hl,de
        ld a,(hl)
        inc hl
        and (hl)
        cp 0FFh
        pop hl
        jp nz,err_syntax
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

; --- CONST nome = [-]numero {, ...}: record con conteggio FFFFh e valore al posto dell'indirizzo
st_const:
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(tsuf)
        or a
        jp nz,err_type
        call find_rec
        jp nc,err_dup2
        ld (tmpv),hl            ; posto del record
        call next_tok
        ld a,'='
        call expect_p
        ld hl,0
        ld a,'-'
        call is_p
        jr nz,.pos
        ld hl,1
        call next_tok
.pos:   ld (chfail),hl          ; segno (1 = negativo)
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld de,(tval)
        ld hl,(chfail)
        ld a,l
        or a
        jr z,.val
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
.val:   ld (chfail),de          ; valore
        ld hl,(tmpv)
        ld bc,0
        ld de,0FFFFh
        call new_rec
        ld hl,(tmpv)
        ld de,12
        add hl,de
        ld de,(chfail)
        ld (hl),e
        inc hl
        ld (hl),d
        call next_tok
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_stop:
        ld a,0C3h
        ld hl,RT_END
        jp emit_jabs

st_randomize:
        call expr
        call want_int
        call emit_i             ; ld a,h ; or l ; jr nz,+1 ; inc hl ; ld (rndseed),hl
        db 8,7Ch,0B5h,20h,01h,23h,22h,low (RTRAM+2),high (RTRAM+2)
        ret

st_sleep:
        call expr
        call want_int
        EM3 0CDh,low RT_WAIT,high RT_WAIT
        ret

two_ints:                       ; a, b -> DE = a, HL = b
        call expr
        call want_int
        EM1 0E5h
        ld a,','
        call expect_p
        call expr
        call want_int
        EM1 0D1h
        ret

st_vpoke:
        call two_ints
        EM3 0CDh,low RT_VPOKE,high RT_VPOKE
        ret

st_out: call two_ints
        EM4 4Bh,7Dh,0EDh,79h    ; ld c,e ; ld a,l ; out (c),a
        ret

st_color:
        ld a,'='
        call is_p
        jp z,st_colpal
        ld a,K_SPRITE
        call is_kw
        jp z,st_colspr
        ld a,(ttype)
        cp T_ID
        jr nz,.n
        call make_nbuf
        ld hl,nbuf
        ld de,s_spritedol
        call str_eq
        jp z,st_colsprs
.n:     call expr
        call want_int
        EM1 0E5h
        ld a,','
        call is_p
        jr nz,.nobg
        call next_tok
        call expr
        call want_int
        jr .go
.nobg:  call emit_i             ; sfondo invariato: ld a,(BAKCLR) ; ld l,a ; ld h,0
        db 6,3Ah,low 0F3EAh,high 0F3EAh,6Fh,26h,0
.go:    EM1 0D1h
        EM3 0CDh,low RT_COLOR,high RT_COLOR
        ret

st_colpal:                      ; COLOR = (n, r, g, b)  oppure  COLOR = RESTORE
        call next_tok
        ld a,'('
        call is_p
        jr nz,.rs
        call next_tok
        call st_palette
        jp close_paren
.rs:    call next_tok
        EM3 0CDh,low RT_PALINIT,high RT_PALINIT
        ret

colspr_head:                    ; (n) = : piano in GX1
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call close_paren
        ld a,'='
        jp expect_p

st_colspr:                      ; COLOR SPRITE(n) = colore
        call colspr_head
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        EM3 0CDh,low RT_SPRCOL,high RT_SPRCOL
        ret

st_colsprs:                     ; COLOR SPRITE$(n) = colori per riga
        call colspr_head
        call expr
        call want_str
        EM3 0CDh,low RT_SPRCOLS,high RT_SPRCOLS
        ret

st_vbank:
        call expr
        call want_int
        EM3 0CDh,low RT_VBANK,high RT_VBANK
        ret

st_vfill:                       ; VFILL indirizzo, quanti, valore
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        EM3 0CDh,low RT_VFILL,high RT_VFILL
        ret

st_vwrite:                      ; VWRITE indirizzo, stringa
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_str
        EM3 0CDh,low RT_VWRITE,high RT_VWRITE
        ret

st_vdpset:                      ; VDP(n) = valore
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call close_paren
        ld a,'='
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        EM3 0CDh,low RT_VDPSET,high RT_VDPSET
        ret

bi_base: ld hl,RT_BASE
        jr bi_one
bi_vdp: ld hl,RT_VDP
        jr bi_one
bi_stick: ld hl,RT_STICK
        jr bi_one
bi_strig: ld hl,RT_STRIG
bi_one: push hl
        call bi_arg_int
        pop hl
        ld a,0CDh
        call emit_jabs
        xor a
        ld (etype),a
        ret

bi_vread:                       ; VREAD$(indirizzo, quanti)
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        call close_paren
        EM3 0CDh,low RT_VREAD,high RT_VREAD
        ld a,1
        ld (etype),a
        ret

bi_ubound:                      ; UBOUND(array): massimo indice (anche per un parametro array)
        call next_tok
        call open_paren
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_arrparam
        jr c,.glob
        ld c,l                  ; ld l,(ix+d) ; ld h,(ix+d+1) ; dec hl
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        inc a
        call emit_a
        EM1 2Bh
        jr .done
.glob:  call find_rec
        jp c,err_type
        ld de,14
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        res 7,d                 ; (array nel mapper: bit 15 = flag)
        ld a,d
        or e
        jp z,err_type
        ld a,d
        and e
        inc a
        jp z,err_type
        dec de
        ld a,21h
        call emit_a
        ex de,hl
        call emit_w
.done:  call next_tok
        call close_paren
        xor a
        ld (etype),a
        ret

bi_vpeek:
        call bi_arg_int
        EM3 0CDh,low RT_VPEEK,high RT_VPEEK
        ret
bi_inp: call bi_arg_int
        call emit_i             ; ld c,l ; in a,(c) ; ld l,a ; ld h,0
        db 6,4Dh,0EDh,78h,6Fh,26h,0
        ret

; --- grafica
emit_st:                        ; HL = indirizzo: emette ld (nn),hl
        ld a,22h
        push hl
        call emit_a
        pop hl
        jp emit_w

emit_xy:                        ; "(x, y)" con conversione WINDOW (se il sorgente la usa): in (DE) e (BC)
        push de
        push bc
        call emit_xy_raw
        pop bc
        pop de
        ld a,(usewin)
        or a
        ret z
        push bc
        ld h,d
        ld l,e
        ld de,RT_WX
        call emit_map
        pop hl
        ld de,RT_WY
        jp emit_map

emit_map:                       ; HL = &variabile, DE = routine: emette ld hl,(var) ; call routine ; ld (var),hl
        ld (tmpv),hl
        ld (tmps),de
        ld a,2Ah
        call emit_a
        ld hl,(tmpv)
        call emit_w
        ld a,0CDh
        call emit_a
        ld hl,(tmps)
        call emit_w
        ld a,22h
        call emit_a
        ld hl,(tmpv)
        jp emit_w

emit_xy_raw:                    ; "(x, y)" senza conversione: valuta e memorizza in (DE) e (BC)
        push bc
        push de
        ld a,'('
        call expect_p
        call expr
        call want_int
        pop hl
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        pop hl
        call emit_st
        ld a,')'
        jp expect_p

emit_defcol:                    ; GCOL = -1 (colore corrente)
        call emit_i
        db 6,21h,0FFh,0FFh,22h,low GCOL,high GCOL
        ret

emit_optcol:                    ; ", colore" facoltativo -> GCOL
        ld a,','
        call is_p
        ret nz
        call next_tok
        call expr
        call want_int
        ld hl,GCOL
        jp emit_st

emit_gopclr:                    ; xor a ; ld (GOP),a
        call emit_i
        db 4,0AFh,32h,low GOP,high GOP
        ret

parse_op:                       ; operatore logico -> ld a,n ; ld (GOP),a  (PSET PRESET AND OR XOR e le versioni T...)
        ld a,(ttype)
        cp T_KW
        jr nz,.id
        ld a,(tval)
        ld c,0
        cp K_PSET
        jr z,.ok
        ld c,4
        cp K_PRESET
        jr z,.ok
        ld c,1
        cp K_AND
        jr z,.ok
        ld c,2
        cp K_OR
        jr z,.ok
        ld c,3
        cp K_XOR
        jp nz,err_syntax
        jr .ok
.id:    cp T_ID
        jp nz,err_syntax
        ld de,opnames
.nx:    ld a,(de)
        or a
        jp z,err_syntax
        push de
        ld hl,tbuf
        call str_eq
        jr z,.hit
        pop de
.sk:    ld a,(de)
        inc de
        or a
        jr nz,.sk
        inc de                  ; salta il codice
        jr .nx
.hit:   pop hl
        inc de
        ld a,(de)
        ld c,a
.ok:    ld a,3Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GOP
        call emit_w
        jp next_tok

opnames: db "TPSET",0,8,"TPRESET",0,12,"TAND",0,9,"TOR",0,10,"TXOR",0,11,0

st_data:                        ; DATA elementi: blocco nel codice (jp oltre, elementi, 2, collegamento)
        ld a,(curseg)
        or a
        jp nz,err_syntax        ; DATA solo nel segmento fisso
        call get_pc
        push hl                 ; indirizzo del blocco
        ld a,0C3h
        call emit_a
        ld hl,0
        call emit_w
        ld hl,(dlast)           ; collega il blocco precedente (o l'inizio dei dati per il primo)
        ld a,h
        or l
        jr nz,.lk
        pop hl
        push hl
        inc hl
        inc hl
        inc hl
        ld (HDRDAT),hl
        jr .it
.lk:    pop de
        push de
        inc de
        inc de
        inc de
        ld bc,(voff)
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
.it:    ld a,(ttype)
        cp T_STR
        jr z,.str
        ld a,'-'
        call is_p
        jr nz,.num
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        xor a
        call emit_a
        ld hl,(tval)
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        call emit_w
        jr .nx
.num:   ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        xor a
        call emit_a
        ld hl,(tval)
        call emit_w
        jr .nx
.str:   ld a,1
        call emit_a
        ld a,(tlen)
        call emit_a
        ld a,(tlen)
        ld b,a
        ld hl,(tval)
.cp:    ld a,b
        or a
        jr z,.nx
        ld a,(hl)
        push hl
        push bc
        call emit_a
        pop bc
        pop hl
        inc hl
        dec b
        jr .cp
.nx:    call next_tok
        ld a,','
        call is_p
        jr nz,.end
        call next_tok
        jr .it
.end:   ld a,2
        call emit_a
        call get_pc
        ld (dlast),hl
        ld hl,0
        call emit_w
        call get_pc             ; patch del jp: oltre il blocco
        pop de
        inc de
        ex de,hl
        ld bc,(voff)
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ret

st_read:                        ; READ variabile[, variabile...]
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        ld a,(tmpk)
        call kind_type
        call emit_read
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv
        jr .more
.arr:   call restore_lex
        call arr_elem
        ld a,(etype)
        push af
        EM1 0E5h
        pop af
        push af
        call emit_read
        EM1 0D1h
        pop af
        or a
        jr nz,.astr
        call emit_i
        db 5,7Dh,12h,13h,7Ch,12h
        jr .more
.astr:  EM3 0CDh,low RT_SCOPY,high RT_SCOPY
.more:  ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

emit_read:                      ; A = 0/1: ld a,n ; call RT_READ
        push af
        ld a,3Eh
        call emit_a
        pop af
        call emit_a
        EM3 0CDh,low RT_READ,high RT_READ
        ret

st_restore:                     ; RESTORE [etichetta]
        call at_send
        jr nz,.lab
        call emit_i
        db 3,21h,0,0
        jr .go
.lab:   ld a,21h
        call jump_target
        EM3 0CDh,low RT_RESTORE,high RT_RESTORE
        ret
.go:    EM3 0CDh,low RT_RESTORE,high RT_RESTORE
        ret

st_beep:
        EM3 0CDh,low RT_BEEP,high RT_BEEP
        ret

st_sound:                       ; SOUND registro, valore
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        EM3 0CDh,low RT_SOUND,high RT_SOUND
        ret

st_play:                        ; PLAY voce1$[, voce2$[, voce3$]]
        call emit_i
        db 12,21h,0,0,22h,low PLV,high PLV,22h,low PLV+2,high PLV+2,22h,low PLV+4,high PLV+4
        ld hl,PLV
.l:     push hl
        call expr
        call want_str
        pop hl
        push hl
        call emit_st
        pop hl
        inc hl
        inc hl
        ld a,','
        call is_p
        jr nz,.go
        push hl
        call next_tok
        pop hl
        ld de,PLV+6
        or a
        sbc hl,de
        add hl,de
        jp z,err_syntax
        jr .l
.go:    EM3 0CDh,low RT_PLAY,high RT_PLAY
        ret

st_print:                       ; PRINT [#n,] elementi
        ld a,'#'
        call is_p
        jp nz,st_print0
        call sel_file
        call st_print0
        jp emit_outreset

sel_file:                       ; "#n," -> RT_OUTSEL
        call next_tok
        call expr
        call want_int
        EM3 0CDh,low RT_OUTSEL,high RT_OUTSEL
        ld a,','
        jp expect_p

emit_outreset:                  ; ld hl,0 ; call RT_OUTSEL
        call emit_i
        db 6,21h,0,0,0CDh,low RT_OUTSEL,high RT_OUTSEL
        ret

st_write:                       ; WRITE [#n,] elementi
        ld a,'#'
        call is_p
        jr nz,.nf
        call sel_file
.nf:    call at_send
        jr z,.end
.l:     call expr
        ld a,(etype)
        or a
        jr nz,.s
        EM3 0CDh,low RT_WINT,high RT_WINT
        jr .nx
.s:     EM3 0CDh,low RT_WSTR,high RT_WSTR
.nx:    ld a,','
        call is_p
        jr nz,.end
        ld b,1
        ld hl,s_comma
        call emit_lit
        EM3 0CDh,low RT_PSTR,high RT_PSTR
        call next_tok
        jr .l
.end:   EM3 0CDh,low RT_PNL,high RT_PNL
        jp emit_outreset
s_comma: db ","

st_open:                        ; OPEN nome$ FOR INPUT|OUTPUT|APPEND AS [#]n
        call expr
        call want_str
        EM1 0E5h
        call emit_i             ; lunghezza del record = 128
        db 6,21h,80h,0,22h,low GX2,high GX2
        ld a,K_FOR
        call is_kw
        jr z,.for
        ld c,4                  ; senza FOR: accesso casuale
        jp .m2
.for:   call next_tok
        ld c,1
        ld a,K_INPUT
        call is_kw
        jr z,.m
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_output
        call str_eq
        ld c,2
        jr z,.m
        ld hl,tbuf
        ld de,s_random
        call str_eq
        ld c,4
        jr z,.m
        ld hl,tbuf
        ld de,s_append
        call str_eq
        jp nz,err_syntax
        ld c,3
.m:     push bc
        call next_tok
        pop bc
.m2:    ld a,21h                ; ld hl,modo ; ld (GY1),hl
        call emit_a
        ld l,c
        ld h,0
        call emit_w
        ld hl,GY1
        call emit_st
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_as
        call str_eq
        jp nz,err_syntax
        call next_tok
        ld a,'#'
        call is_p
        jr nz,.n
        call next_tok
.n:     call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,(ttype)            ; LEN = lunghezza del record
        cp T_ID
        jr nz,.nl
        ld hl,tbuf
        ld de,s_len
        call str_eq
        jr nz,.nl
        call next_tok
        ld a,'='
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
.nl:    EM1 0E1h
        EM3 0CDh,low RT_OPEN,high RT_OPEN
        ret
s_len:  db "LEN",0
s_random: db "RANDOM",0
s_output: db "OUTPUT",0
s_append: db "APPEND",0
s_as:   db "AS",0

st_close:                       ; CLOSE [[#]n[, [#]m...]]
        call at_send
        jr nz,.l
        call emit_i
        db 6,21h,0,0,0CDh,low RT_CLOSE,high RT_CLOSE
        ret
.l:     ld a,'#'
        call is_p
        jr nz,.e
        call next_tok
.e:     call expr
        call want_int
        EM3 0CDh,low RT_CLOSE,high RT_CLOSE
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_kill:
        call expr
        call want_str
        EM3 0CDh,low RT_KILL,high RT_KILL
        ret

bi_eof:                         ; EOF(n)
        call bi_arg_int
        EM3 0CDh,low RT_FEOF,high RT_FEOF
        ret

st_finput:                      ; INPUT #n, var[, var...]
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 2Ah,low GX1,high GX1
        EM3 0CDh,low RT_FINPUT,high RT_FINPUT
        ld a,(tmpk)
        call kind_type
        or a
        jr nz,.s
        EM3 0CDh,low RT_VAL,high RT_VAL
.s:     ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_lineinput:                   ; LINE INPUT [#n,] var$
        call next_tok
        ld a,'#'
        call is_p
        jr nz,.kb
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 2Ah,low GX1,high GX1
        EM3 0CDh,low RT_FLINE,high RT_FLINE
        jr .st
.kb:    ld a,(ttype)
        cp T_STR
        jr nz,.v
        call emit_strlit        ; prompt facoltativo
        EM3 0CDh,low RT_PSTR,high RT_PSTR
        call next_tok
        ld a,';'
        call expect_p
.v:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 0CDh,low RT_INPUT,high RT_INPUT
.st:    ld a,(tmpk)
        call kind_type
        or a
        jp nz,.ok
        jp err_type
.ok:    ld a,(tmpk)
        ld hl,(tmpv)
        jp emit_stv

st_set:                         ; SET PAGE visibile[, attiva]  |  SET SCROLL x, y
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_page
        call str_eq
        jr z,.page
        ld hl,tbuf
        ld de,s_scroll
        call str_eq
        jp nz,err_syntax
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        EM3 0CDh,low RT_SCROLL,high RT_SCROLL
        ret
.page:  call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call is_p
        jr nz,.same
        call next_tok
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        jr .go
.same:  call emit_i             ; pagina attiva = visibile
        db 6,2Ah,low GX1,high GX1,22h,low GY1,high GY1
.go:    EM3 0CDh,low RT_SETPAGE,high RT_SETPAGE
        ret
s_page: db "PAGE",0
dlast:  dw 0
s_scroll: db "SCROLL",0

st_copy:                        ; COPY (x1,y1)-(x2,y2)[, pagina] TO (x3,y3)[, pagina][, operatore]
        ld de,GX1
        ld bc,GY1
        call emit_xy_raw
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        call emit_i             ; pagine = -1 (attiva)
        db 9,21h,0FFh,0FFh,22h,low CSP,high CSP,22h,low CDP,high CDP
        ld a,','
        call is_p
        jr nz,.to
        call next_tok
        call expr
        call want_int
        ld hl,CSP
        call emit_st
.to:    ld a,K_TO
        call expect_kw
        ld de,CDX
        ld bc,CDY
        call emit_xy_raw
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.op                ; pagina omessa
        call expr
        call want_int
        ld hl,CDP
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.op:    call next_tok
        call parse_op
        EM3 0CDh,low RT_COPY,high RT_COPY
        jp emit_gopclr
.go:    EM3 0CDh,low RT_COPY,high RT_COPY
        ret

st_screen:
        call expr
        call want_int
        EM3 0CDh,low RT_SCREEN,high RT_SCREEN
        ld a,','
        call is_p
        ret nz
        call next_tok           ; SCREEN modo, dimensione sprite (0 8x8, 1 8x8 x2, 2 16x16, 3 16x16 x2)
        call expr
        call want_int
        EM3 0CDh,low RT_SPRSIZE,high RT_SPRSIZE
        ret

st_pset:
        ld hl,RT_GPSET
        jr pset_common
st_preset:
        ld hl,RT_GPRESET
pset_common:
        push hl
        ld de,GX1
        ld bc,GY1
        call emit_xy
        call emit_defcol
        call emit_optcol
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        call parse_op
        pop hl
        ld a,0CDh
        call emit_jabs
        jp emit_gopclr
.go:    pop hl
        ld a,0CDh
        jp emit_jabs

st_circle:                      ; CIRCLE (x,y), r[, colore[, inizio[, fine[, aspetto]]]]  (gradi, aspetto in %)
        ld de,GX1
        ld bc,GY1
        call emit_xy
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        ld a,(usewin)
        or a
        jr z,.nw
        ld hl,GX2
        ld de,RT_WR
        call emit_map
.nw:    call emit_defcol
        call emit_i             ; inizio = 0, fine = 360, aspetto = 100, GFLG = 0
        db 22,21h,0,0,22h,low GY2,high GY2,21h,68h,1,22h,low CEND,high CEND,21h,64h,0,22h,low CASP,high CASP,0AFh,32h,low GFLG,high GFLG
        ld a,','
        call is_p
        jp nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.arc               ; colore omesso
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        ld a,','
        call is_p
        jp nz,.go
.arc:   call emit_i             ; GFLG = 1 (arco/ellisse)
        db 5,3Eh,1,32h,low GFLG,high GFLG
        call next_tok
        ld a,','
        call is_p
        jr z,.end               ; inizio omesso
        call expr
        call want_int
        ld hl,GY2
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.end:   call next_tok
        ld a,','
        call is_p
        jr z,.asp               ; fine omessa
        call expr
        call want_int
        ld hl,CEND
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.asp:   call next_tok
        call expr
        call want_int
        ld hl,CASP
        call emit_st
.go:    EM3 0CDh,low RT_GCIRCLE,high RT_GCIRCLE
        ret

st_line:                        ; LINE [(x1,y1)]-(x2,y2)[, colore[, B|BF]]  |  LINE INPUT [#n,] var$
        ld a,K_INPUT
        call is_kw
        jp z,st_lineinput
        ld a,'('
        call is_p
        jr nz,.cur
        ld de,GX1
        ld bc,GY1
        call emit_xy
        jr .dash
.cur:   call emit_i             ; senza primo punto: dall'ultimo punto grafico
        db 12,2Ah,low LASTX,high LASTX,22h,low GX1,high GX1,2Ah,low LASTY,high LASTY,22h,low GY1,high GY1
.dash:  ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy
        call emit_defcol
        call emit_i             ; GFLG = 0
        db 4,0AFh,32h,low GFLG,high GFLG
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.flag              ; colore omesso: ", , B"
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.flag:  call next_tok
        ld a,','
        call is_p
        jr z,.op                ; ", colore, , operatore"
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(tbuf)
        cp 'B'
        jp nz,err_syntax
        ld c,1                  ; B
        ld a,(tbuf+1)
        or a
        jr z,.setf
        cp 'F'
        jp nz,err_syntax
        ld a,(tbuf+2)
        or a
        jp nz,err_syntax
        ld c,2                  ; BF
.setf:  ld a,3Eh                ; ld a,n ; ld (GFLG),a
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GFLG
        call emit_w
        call next_tok
        ld a,','
        call is_p
        jr nz,.go
.op:    call next_tok
        call parse_op
        EM3 0CDh,low RT_GLINE,high RT_GLINE
        jp emit_gopclr
.go:    EM3 0CDh,low RT_GLINE,high RT_GLINE
        ret

st_paint:                       ; PAINT (x,y)[, colore[, bordo]]
        ld de,GX1
        ld bc,GY1
        call emit_xy
        call emit_defcol
        call emit_i             ; bordo = -1 (come il colore)
        db 6,21h,0FFh,0FFh,22h,low GX2,high GX2
        call emit_optcol
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        call expr
        call want_int
        ld hl,GX2
        call emit_st
.go:    EM3 0CDh,low RT_PAINT,high RT_PAINT
        ret

s_spritedol: db "SPRITE$",0
s_vdp:  db "VDP",0
s_far:  db "FAR",0
s_mapper: db "MAPPER",0
s_sw:   db "S",0

arr_ref_stmt:                   ; array di interi (con o senza "()") -> ARRB, ARRC
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(tsuf)
        or a
        jp nz,err_type
        call emit_arrref
        call emit_i             ; pop hl ; ld (ARRC),hl ; pop hl ; ld (ARRB),hl
        db 8,0E1h,22h,low ARRC,high ARRC,0E1h,22h,low ARRB,high ARRB
        ret

st_get:                         ; GET (x1,y1)-(x2,y2), array   |   GET #n [, record]
        ld a,'#'
        call is_p
        jp z,st_fget
        ld de,GX1
        ld bc,GY1
        call emit_xy
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy
        ld a,','
        call expect_p
        call arr_ref_stmt
        EM3 0CDh,low RT_GGET,high RT_GGET
        ret

st_gput:                        ; PUT (x,y), array[, PSET|PRESET|AND|OR|XOR]
        ld de,GX1
        ld bc,GY1
        call emit_xy
        ld a,','
        call expect_p
        call arr_ref_stmt
        call emit_i             ; azione predefinita XOR
        db 5,3Eh,4,32h,low GFLG,high GFLG
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,(ttype)
        cp T_KW
        jp nz,err_syntax
        ld a,(tval)
        ld c,0
        cp K_PSET
        jr z,.set
        inc c
        cp K_PRESET
        jr z,.set
        inc c
        cp K_AND
        jr z,.set
        inc c
        cp K_OR
        jr z,.set
        inc c
        cp K_XOR
        jp nz,err_syntax
.set:   ld a,3Eh                ; ld a,n ; ld (GFLG),a
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GFLG
        call emit_w
        call next_tok
.go:    EM3 0CDh,low RT_GPUT,high RT_GPUT
        ret

st_view:                        ; VIEW (x1,y1)-(x2,y2)  oppure  VIEW (finestra = schermo intero)
        call at_send
        jr nz,.args
        EM3 0CDh,low RT_VIEWR,high RT_VIEWR
        ret
.args:  ld de,GX1
        ld bc,GY1
        call emit_xy_raw
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        EM3 0CDh,low RT_VIEW,high RT_VIEW
        ret

st_window:                      ; WINDOW [SCREEN] (x1,y1)-(x2,y2)  oppure  WINDOW (coordinate = pixel)
        call at_send
        jr nz,.args
        EM3 0CDh,low RT_WINRES,high RT_WINRES
        ret
.args:  ld c,0                  ; 1 con SCREEN: asse y verso il basso
        ld a,K_SCREEN
        call is_kw
        jr nz,.n1
        ld c,1
        push bc
        call next_tok
        pop bc
.n1:    ld a,3Eh                ; ld a,n ; ld (GFLG),a
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GFLG
        call emit_w
        ld de,GX1
        ld bc,GY1
        call emit_xy_raw
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        EM3 0CDh,low RT_WINDOW,high RT_WINDOW
        ret

st_draw:                        ; DRAW "comandi"
        call expr
        call want_str
        EM3 0CDh,low RT_DRAW,high RT_DRAW
        ret

bi_coll:                        ; COLLISION: -1 se due sprite si sono toccati
        call next_tok
        ld a,'('
        call is_p
        jr nz,.nop
        call next_tok
        ld a,')'
        call expect_p
.nop:   EM3 0CDh,low RT_COLL,high RT_COLL
        xor a
        ld (etype),a
        ret

st_sprdef:                      ; SPRITE$(n) = pattern
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call close_paren
        ld a,'='
        call expect_p
        call expr
        call want_str
        EM3 0CDh,low RT_SPRDEF,high RT_SPRDEF
        ret

st_put:                         ; PUT SPRITE piano, (x,y)[, colore[, pattern]]  oppure  PUT (x,y), array[, azione]  |  PUT #n [, record]
        ld a,'#'
        call is_p
        jp z,st_fput
        ld a,K_SPRITE
        call is_kw
        jp nz,st_gput
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        call emit_defcol
        call emit_i             ; pattern = -1 (come il numero del piano)
        db 6,21h,0FFh,0FFh,22h,low GY1,high GY1
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.pat               ; colore omesso
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.pat:   call next_tok
        call expr
        call want_int
        ld hl,GY1
        call emit_st
.go:    EM3 0CDh,low RT_SPRPUT,high RT_SPRPUT
        ret

st_palette:                     ; PALETTE [n, rosso, verde, blu]
        call at_send
        jr nz,.args
        EM3 0CDh,low RT_PALINIT,high RT_PALINIT
        ret
.args:  call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY2
        call emit_st
        EM3 0CDh,low RT_PALETTE,high RT_PALETTE
        ret

bi_point:                       ; POINT(x, y) -> colore (-1 fuori dallo schermo)
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        call close_paren
        ld a,(usewin)
        or a
        jr z,.nw
        ld hl,GX1
        ld de,RT_WX
        call emit_map
        ld hl,GY1
        ld de,RT_WY
        call emit_map
.nw:    EM3 0CDh,low RT_GPOINT,high RT_GPOINT
        xor a
        ld (etype),a
        ret

st_wend:
        ld a,B_WHILE
        call need_blk
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,0C3h
        call emit_jabs
        ld a,B_WHILE
        call need_blk
        inc hl
        inc hl
        inc hl
        call patch_chain
        ld hl,nblk
        dec (hl)
        ret

; ---------------------------------------------------------------- runtime e caricatore inclusi
ldr_img: INCBIN "build/ldr.bin"
ldr_size equ $-ldr_img
comend:
        IFDEF ROMMODE
        ASSERT comend < FARTABC
        ELSE
        ASSERT comend < LABT
        ENDIF
        IFDEF ROMMODE
        SAVEBIN "build/qbcr.com",0100h,comend-0100h
        ELSE
        SAVEBIN "build/qbc.com",0100h,comend-0100h
        ENDIF
