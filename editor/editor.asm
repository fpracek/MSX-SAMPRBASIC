; =====================================================================
; MSXQB editor di testo - prototipo (ROM 16K a 4000h, MSX2, SCREEN 0 W80)
;
; Schermo (80x24):  riga 0      barra del titolo (video inverso)
;                   righe 1-22  testo (colonne 0-78) + barra verticale (col 79)
;                   riga 23     barra orizzontale
; Buffer: gap buffer in RAM, offset logici; LF = fine riga, max 254 colonne.
; Mouse: movimento+pulsanti via BIOS (GTPAD/GTTRIG) oppure, con mmode=1,
;        dai byte tm_dx/tm_dy/tm_btn (per i test automatici).
; =====================================================================
CHGET   equ 009Fh
CHSNS   equ 009Ch
KILBUF  equ 0156h
INITXT  equ 006Ch
ERAFNK  equ 00CCh
GTPAD   equ 00DBh
GTTRIG  equ 00D8h
SNSMAT  equ 0141h
CGTABL  equ 0004h
CSRSW   equ 0FCA9h
LINL40  equ 0F3AEh
LINLEN  equ 0F3B0h
VDPD    equ 98h
VDPC    equ 99h
EXPTBL  equ 0FCC1h
CALSLT  equ 001Ch

RAMB    equ 0C000h              ; variabili in pagina 3 (sempre RAM, visibile al debugger)

        MACRO BIOS addr         ; chiama una routine del BIOS (da DOS via CALSLT)
        IFDEF COM
        ld ix,addr
        call bioscall
        ELSE
        call addr
        ENDIF
        ENDM

LF      equ 0Ah
NAMT    equ 0000h               ; name table
BLKT    equ 0800h               ; blink table (10 byte per riga)
PATT    equ 1000h               ; pattern table
VCOLS   equ 79
VROWS   equ 22
TV      equ 20                  ; celle di binario verticale (righe 2..21)
TH      equ 77                  ; celle di binario orizzontale (colonne 1..77)
MAXCOL  equ 254
HMAX    equ MAXCOL-VCOLS+1      ; massimo scroll orizzontale (176)
KWCOL   equ 0B4h               ; parole chiave: giallo chiaro su blu
KWBLINK equ 010h               ; R#13
MPAD    equ 12                  ; GTPAD: 12 = mouse porta 1 (16 = porta 2)

        IFDEF COM
BUF     equ 3E00h               ; gap buffer: 3A00h-BFFFh (TPA, pagine 0-2)
UNDO    equ RAMB+0460h          ; registro di annullamento: C460h-CFFFh
UNDOSZ  equ 0BA0h
CLIP    equ UNDO+UNDOSZ         ; clipboard: D000h fino a (0006h)-0300h
        ELSE
BUF     equ RAMB+0460h          ; gap buffer (fino a bufend)
UNDO    equ 0DE00h              ; registro di annullamento di 2 KB (solo build ROM)
UNDOSZ  equ 0800h
CLIP    equ 0E600h              ; clipboard di 2.5 KB (solo build ROM)
        ENDIF

; ---- RAM
kwf     equ RAMB+0400h              ; 10 byte: flag di colore della riga (un bit per colonna)
kwword  equ RAMB+040Ah              ; 16 byte: parola in esame (maiuscola)
kwptr   equ RAMB+041Ah              ; w
kwq     equ RAMB+041Ch              ; b  dentro una stringa tra virgolette
kwlen   equ RAMB+041Dh              ; b
kwcol   equ RAMB+041Eh              ; b
curch   equ RAMB+041Fh              ; b  carattere sotto il cursore
cph     equ RAMB+0420h              ; b  fase del cursore (1 = visibile)
blcnt   equ RAMB+0421h              ; b  contatore di quadri
curdr   equ RAMB+0422h              ; b  il glifo del cursore e' disegnato
compiled equ RAMB+0424h             ; b  NOME.COM e' la compilazione del testo attuale (marcatore " +" dal programma)
onfile  equ RAMB+0425h              ; b  il testo corrisponde a un file su disco (caricato o salvato)
oldsz   equ RAMB+0427h              ; w  dimensione del file prima di una sovrascrittura in posto
inplace equ RAMB+0429h              ; b  il salvataggio sovrascrive il file esistente
cmdok   equ RAMB+0426h              ; b  la riga di comando aveva il marcatore " +"
sw      equ RAMB+0430h              ; b  larghezza dello schermo: 80 (MSX2) o 40 (MSX1)
swm1    equ RAMB+0431h              ; b  sw-1 (colonna della barra verticale = VCOLS)
swm2    equ RAMB+0432h              ; b  sw-2 (colonna della freccia destra)
thv     equ RAMB+0433h              ; b  sw-3 (celle del binario orizzontale)
m2flag  equ RAMB+0434h              ; b  0 = MSX1 (TMS9918: niente tabella di blink, R#12/13/14), altrimenti MSX2 o superiore
vcolsw  equ RAMB+0435h              ; w  VCOLS = sw-1
vcw1    equ RAMB+0437h              ; w  VCOLS-1
nvcw1   equ RAMB+0439h              ; w  -(VCOLS-1)
hmaxw   equ RAMB+043Bh              ; w  HMAX (massimo scroll orizzontale)
hmax1w  equ RAMB+043Dh              ; w  HMAX+1
pattb   equ RAMB+043Fh              ; w  tabella dei pattern: 1000h (80 colonne) o 0800h (40)
mxmax   equ RAMB+0441h              ; w  limite x del mouse = sw*8
rbm2    equ RAMB+0443h              ; w  indirizzo di rowbuf+sw-2
helpstr equ RAMB+0448h              ; 16 byte: argomento di help (maiuscolo, 12 caratteri con riempimento a zero)
hlptop  equ RAMB+0458h              ; w  prima riga visibile del testo di help
hlpbeg  equ RAMB+045Ah              ; w  inizio del testo di help
hscr    equ RAMB+045Ch              ; w  area di lavoro (nel gap) con il testo di help
kutmp   equ RAMB+0445h              ; w  JIFFY d'inizio dell'attesa dei tasti
kwnext  equ RAMB+0423h              ; b  prossima riga schermo (0..) da colorare nei tempi morti (VROWS = fatto)
cur     equ RAMB+0000h              ; w  offset logico del cursore
len     equ RAMB+0002h              ; w  lunghezza del testo
gs      equ RAMB+0004h              ; w  inizio gap (offset logico)
gsz     equ RAMB+0006h              ; w  dimensione gap
top     equ RAMB+0008h              ; w  offset della prima riga visibile
topline equ RAMB+000Ah              ; w  numero (1..) della prima riga visibile
curline equ RAMB+000Ch              ; w  riga del cursore
nlines  equ RAMB+000Eh              ; w  righe totali
hscroll equ RAMB+0010h              ; w  colonna di sinistra visibile
wantcol equ RAMB+0012h              ; w  colonna "desiderata" per su/giu
mpx     equ RAMB+0014h              ; w  mouse x (pixel 0..639)
mpy     equ RAMB+0016h              ; w  mouse y (pixel 0..191)
mprev   equ RAMB+0018h
mdrag   equ RAMB+0019h              ; 0 niente, 1 trascina pollice V, 2 pollice H, 3 ripetizione
mact    equ RAMB+001Ah
mtimer  equ RAMB+001Bh
mcx     equ RAMB+001Ch              ; cella del puntatore
mcy     equ RAMB+001Dh
mshown  equ RAMB+001Eh
mactive equ RAMB+001Fh
blx     equ RAMB+0020h              ; cella del cursore lampeggiante (FF = nessuna)
bly     equ RAMB+0021h
dirty   equ RAMB+0022h              ; bit0 = testo da ridisegnare
mmode   equ RAMB+0023h              ; 0 = BIOS, 1 = test
tm_dx   equ RAMB+0024h
tm_dy   equ RAMB+0025h
tm_btn  equ RAMB+0026h
rdx     equ RAMB+0027h
rdy     equ RAMB+0028h
rbtn    equ RAMB+0029h
tmpb    equ RAMB+002Ah
tmpc    equ RAMB+002Bh
tmpd    equ RAMB+002Ch
rp      equ RAMB+002Eh              ; w
rrow    equ RAMB+0030h
reof    equ RAMB+0031h
tgtline equ RAMB+0032h              ; w
tmp1    equ RAMB+0034h              ; w
tmp2    equ RAMB+0036h              ; w
tmp3    equ RAMB+0038h              ; w
sc_z    equ RAMB+003Ah              ; w
sc_x    equ RAMB+003Ch
sc_r    equ RAMB+003Dh              ; w
sc_acc  equ RAMB+003Fh              ; w
sc_rem  equ RAMB+0041h              ; w
sc_res  equ RAMB+0043h              ; w
numtmp  equ RAMB+0045h              ; 6 byte
gpa     equ RAMB+004Ch              ; w  indirizzo fisico dell'inizio gap (FFFF = nessun gap)
gpb     equ RAMB+004Eh              ; w  indirizzo fisico della fine gap
rowbuf  equ RAMB+0050h              ; 96 byte
bufend  equ RAMB+00B0h              ; w  ultimo byte del buffer (sentinella 0)
bufsz   equ RAMB+00B2h              ; w  dimensione del buffer
modified equ RAMB+00B4h             ; b  testo modificato dall'ultimo salvataggio
pendkey equ RAMB+00B5h              ; b  tasto in attesa di conferma
csrsave equ RAMB+00B6h              ; b  CSRSW originale (ripristinato all'uscita)
ioerr   equ RAMB+00B7h              ; b
msgptr  equ RAMB+00B8h              ; w  messaggio da mostrare nel titolo (0 = nessuno)
iop     equ RAMB+00BAh              ; w  puntatore di scrittura in iobuf
lcol    equ RAMB+00BCh              ; b  colonna corrente durante il caricamento
nbytes  equ RAMB+00BDh              ; w  byte letti/scritti
fname   equ RAMB+00C0h              ; 16 byte, nome file 0-terminato
fcb     equ RAMB+00D0h              ; 37 byte
msgbuf  equ RAMB+00F8h              ; 64 byte (messaggi composti)
iobuf   equ RAMB+0140h              ; 512 byte per i trasferimenti file
IOSZ    equ 512
selanc  equ RAMB+0340h              ; w  ancora della selezione (FFFF = nessuna)
cliplen equ RAMB+0342h              ; w  byte nella clipboard
clipsz  equ RAMB+0344h              ; w  capacita' della clipboard
selps   equ RAMB+0346h              ; w  selezione: indirizzi fisici (per il disegno)
selpe   equ RAMB+0348h              ; w
selact  equ RAMB+034Ah              ; b  selezione presente durante il disegno
gtgt    equ RAMB+034Ch              ; w  destinazione del gap
tgtrow  equ RAMB+034Eh              ; b  cella bersaglio (riga 1..22)
tgtcol  equ RAMB+034Fh              ; b  cella bersaglio (colonna 0..78)
menuopen equ RAMB+0350h             ; b  menu aperto (0 = nessuno, 1..NMENU)
menusel equ RAMB+0351h              ; b  voce evidenziata
mw      equ RAMB+0352h              ; b  larghezza del riquadro
mn      equ RAMB+0353h              ; b  numero di voci
mx0     equ RAMB+0354h              ; b  colonna del riquadro
mi      equ RAMB+0355h              ; b  voce in corso di disegno
mrec    equ RAMB+0356h              ; w  puntatore alle voci
MENUW   equ 6                       ; larghezza di ogni titolo nella barra
NMENU   equ 5
srchstr equ RAMB+0360h              ; 33 byte: testo cercato (0-terminato)
replstr equ RAMB+0380h              ; 33 byte: testo sostitutivo
casestr equ RAMB+03A0h              ; 16 byte: etichetta "Match case: off/on"
srchlow equ RAMB+03B0h              ; 33 byte: copia del testo cercato (minuscolo se si ignora la differenza)
mcase   equ RAMB+03D2h              ; b  1 = maiuscole/minuscole distinte
slen    equ RAMB+03D3h              ; b  lunghezza del testo cercato
rlen    equ RAMB+03D4h              ; b  lunghezza del testo sostitutivo
smask   equ RAMB+03D5h              ; b  20h = ignora il caso, 0 = lo distingue
swrap   equ RAMB+03D6h              ; b  la ricerca ha girato intorno
rall    equ RAMB+03D7h              ; b  sostituisci tutto senza chiedere
spos    equ RAMB+03D8h              ; w  inizio dell'intervallo di ricerca
slim    equ RAMB+03DAh              ; w  fine (esclusa) dell'intervallo
sdelta  equ RAMB+03DCh              ; w  scarto fisico dell'intervallo
rcount  equ RAMB+03DEh              ; w  sostituzioni fatte
insn    equ RAMB+03E0h              ; w  byte da inserire
pdst    equ RAMB+03E2h              ; w  prompt di riga: destinazione
pprm    equ RAMB+03E4h              ; w  prompt di riga: testo del prompt
pmax    equ RAMB+03E6h              ; b
pflag   equ RAMB+03E7h              ; b  bit0 spazi, bit1 parte dal testo attuale, bit2 invio vuoto accettato
plen    equ RAMB+00BEh              ; b  lunghezza del testo digitato nel prompt
ucur    equ RAMB+03E8h              ; w  fine dei record applicati (prossimo undo = quello prima)
uend    equ RAMB+03EAh              ; w  fine dei record validi (oltre ucur: redo)
uglue   equ RAMB+03ECh              ; b  il prossimo record si unisce al gruppo precedente
ukind   equ RAMB+03EDh              ; b  tipo della serie di battute in corso (0 = nessuna)
unolog  equ RAMB+03EEh              ; b  durante undo/redo non si registra
utype   equ RAMB+03EFh              ; b  tipo del record da scrivere (1 inserimento, 2 cancellazione)
uoff    equ RAMB+03F0h              ; w
ulen    equ RAMB+03F2h              ; w
usrc    equ RAMB+03F4h              ; w
urec    equ RAMB+03F6h              ; w  record in lavorazione
errline equ RAMB+03F8h              ; w  riga dell'errore di compilazione (0 = nessuno)
errcode equ RAMB+03FAh              ; b  codice dell'errore

        DEVICE NOSLOT64K
        IFDEF COM
        ORG 0100h
        ELSE
        ORG 4000h
        db "AB"
        dw start
        dw 0,0,0
        ds 6
        ENDIF

start:
        IFDEF COM
        ld hl,(0006h)           ; base del BDOS = fine della TPA (stack sotto di essa)
        ld sp,hl
        ld hl,0BFFFh
        ld (bufend),hl
        ld hl,(0006h)           ; clipboard: dal fondo dei dati fino a 768 byte sotto il BDOS
        ld de,-(CLIP+0300h)
        add hl,de
        bit 7,h
        jr z,.cs
        ld hl,0
.cs:    ld (clipsz),hl
        ld a,(CSRSW)
        ld (csrsave),a
        call getcmd             ; nome file dalla riga di comando
        ELSE
        di
        ld sp,0F380h
        ei
        ld hl,UNDO-1
        ld (bufend),hl
        ld hl,0A00h
        ld (clipsz),hl
        xor a
        ld (fname),a            ; (la RAM all'avvio non e' a zero)
        ENDIF
        xor a
        ld (CSRSW),a
        call width_init
        ld a,(sw)
        ld (LINL40),a
        ld (LINLEN),a
        BIOS INITXT
        BIOS ERAFNK
        ld hl,0F87Fh            ; F1-F4: un solo carattere ciascuno (aprono i menu File, Edit, Find, Help)
        ld de,fkcodes
        ld b,4
.fk:    ld a,(de)
        ld (hl),a
        inc hl
        ld (hl),0
        ld a,l
        add a,15
        ld l,a
        jr nc,.fn
        inc h
.fn:    inc de
        djnz .fk
        ld hl,0F8BFh            ; stringa del tasto F5 = 15h (un solo carattere gestito dall'editor)
        ld (hl),15h
        inc hl
        ld (hl),0
        call keys_up            ; il tasto premuto per uscire dal programma puo' essere ancora giu': non deve ripetersi nel testo
        ld hl,0F8CFh            ; F6 (Shift+F1): menu Help + "W" = aiuto sulla parola sotto il cursore
        ld (hl),0Ah
        inc hl
        ld (hl),'W'
        inc hl
        ld (hl),0
        ld hl,0F8DFh            ; F7 (Shift+F2): menu Help + "I" = indice
        ld (hl),0Ah
        inc hl
        ld (hl),'I'
        inc hl
        ld (hl),0
        BIOS KILBUF             ; scarta i tasti in attesa (ripetizioni, F5 del lancio precedente)
        call vdp_init
        call font_load
        call blink_clear
        call ed_init
        ld hl,0
        ld (cliplen),hl
        call mouse_init
        IFDEF COM
        call startup_load
        ENDIF
        ld a,1
        ld (dirty),a
        call refresh
main:   halt
        ld hl,blcnt
        inc (hl)
        ld a,(hl)
        and 1Fh
        call z,cur_blink
        call mouse_poll
        BIOS CHSNS
        jr nz,.key
        call kw_idle
        jr main
.key:   BIOS CHGET
        call handle_key
        jr main

        IFDEF COM
bioscall:                       ; chiamata BIOS (IX = indirizzo) dalla RAM di MSX-DOS
        ld iy,(EXPTBL-1)
        call CALSLT
        ei
        ret
        ENDIF

; ---------------------------------------------------------------- VDP
vsetw:                          ; HL = indirizzo VRAM (scrittura); clobbera A
        di
        ld a,l
        out (VDPC),a
        ld a,h
        and 3Fh
        or 40h
        out (VDPC),a
        ei
        ret

vsetr:                          ; HL = indirizzo VRAM (lettura); clobbera A
        di
        ld a,l
        out (VDPC),a
        ld a,h
        and 3Fh
        out (VDPC),a
        ei
        nop
        nop
        ret

width_init:                      ; versione MSX (byte 002Dh): 80 colonne su MSX2, 40 su MSX1; parametri di layout
        IFDEF COM
        ld hl,002Dh
        ld a,(EXPTBL)
        call 000Ch              ; RDSLT
        ei
        ELSE
        ld a,(002Dh)
        ENDIF
        ld (m2flag),a
        ld b,80
        ld hl,1000h
        or a
        jr nz,.w
        ld b,40
        ld hl,0800h
.w:     ld (pattb),hl
        ld a,b
        ld (sw),a
        dec a
        ld (swm1),a
        ld l,a
        ld h,0
        ld (vcolsw),hl
        dec hl
        ld (vcw1),hl
        ld a,l
        ld (swm2),a
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (nvcw1),hl
        ld a,(swm2)
        dec a
        ld (thv),a
        ld a,(sw)
        ld l,a
        ld h,0
        ex de,hl
        ld hl,256
        or a
        sbc hl,de               ; 256 - sw = HMAX (MAXCOL - VCOLS + 1)
        ld (hmaxw),hl
        inc hl
        ld (hmax1w),hl
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (mxmax),hl
        ld a,(sw)
        ld l,a
        ld h,0
        ld de,rowbuf-2
        add hl,de
        ld (rbm2),hl
        ret

vdp_init:
        ld a,0F4h               ; R#7: testo 15 su blu
        out (VDPC),a
        ld a,87h
        out (VDPC),a
        ld a,(m2flag)
        or a
        ret z                   ; MSX1: niente R#12/R#13/R#14 (i numeri sopra il 7 si sovrapporrebbero ai registri 0-7)
        xor a                   ; R#14 = 0
        out (VDPC),a
        ld a,8Eh
        out (VDPC),a
        ld a,KWCOL              ; R#12: colori alternativi (parole chiave)
        out (VDPC),a
        ld a,8Ch
        out (VDPC),a
        ld a,KWBLINK            ; R#13: nessuna alternanza, i caratteri flaggati restano nel colore alternativo
        out (VDPC),a
        ld a,8Dh
        out (VDPC),a
        ret

font_load:                      ; 128-255 = copie negate di 0-127 (font gia' in VRAM da INITXT), glifi 1-5 propri
        ld hl,(pattb)
        ld de,1024
        add hl,de
        ex de,hl
        ld hl,(pattb)
        ld a,128
.cp:    push af
        push hl
        push de
        call vsetr              ; legge il glifo sorgente
        ld hl,rowbuf
        ld b,8
        ld c,VDPD
        inir
        pop hl                  ; HL = destinazione
        push hl
        call vsetw
        ld hl,rowbuf
        ld b,8
.i:     ld a,(hl)
        cpl
        out (VDPD),a
        inc hl
        djnz .i
        pop de
        pop hl
        ld bc,8
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop af
        dec a
        jr nz,.cp
        ld hl,glyphs
        ld b,12
        ld c,1
.g:     push bc
        push hl
        ld a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(pattb)
        add hl,de
        ex de,hl                ; DE = indirizzo normale
        pop hl                  ; HL = glifo
        push hl
        push de
        xor a
        call gl_write
        pop de
        pop hl
        ld a,d
        add a,4                 ; +1024
        ld d,a
        ld a,0FFh
        push hl
        call gl_write
        pop hl
        ld de,8
        add hl,de
        pop bc
        inc c
        djnz .g
        ret

gl_write:                       ; HL = 8 byte, DE = indirizzo VRAM, A = maschera xor
        ld c,a
        push hl
        ex de,hl
        call vsetw
        pop hl
        ld b,8
.l:     ld a,(hl)
        xor c
        out (VDPD),a
        inc hl
        djnz .l
        ret

        INCLUDE "kwtab.inc"
glyphs: db 000h,000h,030h,078h,0FCh,000h,000h,000h     ; 1 freccia su
        db 000h,000h,0FCh,078h,030h,000h,000h,000h     ; 2 freccia giu
        db 000h,00Ch,01Ch,03Ch,07Ch,03Ch,01Ch,00Ch     ; 3 freccia sinistra
        db 000h,060h,070h,078h,07Ch,078h,070h,060h     ; 4 freccia destra
        db 0A8h,054h,0A8h,054h,0A8h,054h,0A8h,054h     ; 5 binario
        db 000h,000h,000h,0FCh,0FCh,000h,000h,000h     ; 6 linea orizzontale
        db 030h,030h,030h,030h,030h,030h,030h,030h     ; 7 linea verticale
        db 000h,000h,000h,03Ch,03Ch,030h,030h,030h     ; 8 angolo alto-sinistra
        db 000h,000h,000h,0F0h,0F0h,030h,030h,030h     ; 9 angolo alto-destra
        db 000h,000h,000h,000h,000h,000h,000h,000h     ; 10 (vuoto, e' LF)
        db 030h,030h,030h,03Ch,03Ch,000h,000h,000h     ; 11 angolo basso-sinistra
        db 030h,030h,030h,0F0h,0F0h,000h,000h,000h     ; 12 angolo basso-destra

blink_clear:
        ld a,(m2flag)
        or a
        jr z,.nb                ; MSX1: a 0800h c'e' la tabella dei pattern
        ld hl,BLKT
        call vsetw
        ld b,240
        xor a
.l:     out (VDPD),a
        djnz .l
.nb:    ld a,0FFh
        ld (blx),a
        xor a
        ld (curdr),a
        ld (blcnt),a
        inc a
        ld (cph),a
        ld a,VROWS
        ld (kwnext),a
        ret

cell_addr:                      ; D = riga, E = colonna -> HL; clobbera D, BC
        ld l,d
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; *5
        add hl,hl
        add hl,hl
        add hl,hl               ; *40
        ld a,(sw)
        cp 80
        jr nz,.w
        add hl,hl               ; *80
.w:     ld d,0
        add hl,de
        ret

put_cell:                       ; A = carattere, D = riga, E = colonna (preserva DE)
        ld (tmpc),a
        push de
        call cell_addr
        call vsetw
        pop de
        ld a,(tmpc)
        out (VDPD),a
        ret

get_cell:                       ; D = riga, E = colonna -> A (preserva DE)
        push de
        call cell_addr
        call vsetr
        in a,(VDPD)
        pop de
        ret

blink_op:                       ; D = riga, E = colonna, C = 0 spegne / 1 accende
        ld a,c
        ld (tmpc),a
        ld l,d
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl               ; riga*10
        ld a,e
        rrca
        rrca
        rrca
        and 1Fh
        ld c,a
        ld b,0
        add hl,bc
        ld bc,BLKT
        add hl,bc
        push hl
        ld a,e
        and 7
        ld b,a
        ld a,80h
        jr z,.nb
.sh:    srl a
        djnz .sh
.nb:    ld (tmpd),a
        pop hl
        push hl
        call vsetr
        in a,(VDPD)
        ld c,a
        ld a,(tmpd)
        ld b,a
        ld a,(tmpc)
        or a
        ld a,c
        jr z,.clr
        or b
        jr .w
.clr:   ld a,b
        cpl
        and c
.w:     ld c,a
        pop hl
        call vsetw
        ld a,c
        out (VDPD),a
        ret

; ---------------------------------------------------------------- aritmetica
udiv:                           ; HL / DE (senza segno) -> HL quoziente, DE resto
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     sla c
        rl b
        adc hl,hl
        or a
        sbc hl,de
        jr nc,.s
        add hl,de
        jr .n
.s:     inc c
.n:     dec a
        jr nz,.l
        ld d,h
        ld e,l
        ld h,b
        ld l,c
        ret

scale:                          ; C = x, HL = y, DE = z -> HL = x*y/z  (y,z < 32768)
        ld a,d
        or e
        jr z,.zero
        ld (sc_z),de
        ld a,c
        ld (sc_x),a
        call udiv               ; HL = y/z, DE = y mod z
        ld (sc_r),de
        ex de,hl                ; DE = q
        ld hl,0
        ld a,(sc_x)
        or a
        jr z,.nm
        ld b,a
.mq:    add hl,de
        djnz .mq
.nm:    ld (sc_acc),hl
        ld hl,0
        ld (sc_rem),hl
        ld (sc_res),hl
        ld a,(sc_x)
        ld c,a
        ld b,8
.f:     ld hl,(sc_res)
        add hl,hl
        ld (sc_res),hl
        ld hl,(sc_rem)
        add hl,hl
        call .red
        sla c
        jr nc,.nb
        ld de,(sc_r)
        add hl,de
        call .red
.nb:    ld (sc_rem),hl
        djnz .f
        ld hl,(sc_res)
        ld de,(sc_acc)
        add hl,de
        ret
.red:   ld de,(sc_z)
        or a
        sbc hl,de
        jr nc,.rd
        add hl,de
        ret
.rd:    push hl
        ld hl,(sc_res)
        inc hl
        ld (sc_res),hl
        pop hl
        ret
.zero:  ld hl,0
        ret

clamp:                          ; HL = valore, DE = max+1 -> HL limitato a 0..max
        bit 7,h
        jr z,.p
        ld hl,0
        ret
.p:     push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        dec hl
        ret

dec16:                          ; HL = valore -> cifre decimali in (DE), DE avanza
        push de
        ld de,numtmp
        ld bc,-10000
        call .d
        ld bc,-1000
        call .d
        ld bc,-100
        call .d
        ld bc,-10
        call .d
        ld a,l
        add a,'0'
        ld (de),a
        pop de
        ld hl,numtmp
        ld b,4
.s:     ld a,(hl)
        cp '0'
        jr nz,.c
        inc hl
        djnz .s
.c:     ld c,b
        inc c
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        dec c
        jr nz,.cp
        ret
.d:     ld a,'0'-1
.l:     inc a
        add hl,bc
        jr c,.l
        sbc hl,bc
        ld (de),a
        inc de
        ret

strcpy:                         ; HL = sorgente (0-terminata), DE = destinazione
.l:     ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr .l

; ---------------------------------------------------------------- buffer
phys:                           ; HL = offset logico -> HL = indirizzo fisico; clobbera DE
        ld de,(gs)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.lo
        ld de,(gsz)
        add hl,de
.lo:    ld de,BUF
        add hl,de
        ret

getb:                           ; HL = offset -> A; preserva HL; clobbera DE
        push hl
        call phys
        ld a,(hl)
        pop hl
        ret

set_sentinel:                   ; scrive 0 sul primo byte del gap (se il gap non e' vuoto)
        ld hl,(gsz)
        ld a,h
        or l
        ret z
        ld hl,(gs)
        ld de,BUF
        add hl,de
        ld (hl),0
        ret

line_start:                     ; HL = offset -> HL = inizio della riga
.l:     ld a,h
        or l
        ret z
        dec hl
        call getb
        cp LF
        jr nz,.l
        inc hl
        ret

line_end:                       ; HL = offset -> HL = posizione del LF (o len)
.l:     ld de,(len)
        push hl
        or a
        sbc hl,de
        pop hl
        ret nc
        call getb
        cp LF
        ret z
        inc hl
        jr .l

next_line_start:                ; HL = offset -> HL = inizio riga successiva; C se non c'e'
        call line_end
        ld de,(len)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.none
        inc hl
        or a
        ret
.none:  scf
        ret

prev_line_start:                ; HL = inizio di una riga (>0) -> inizio della precedente
        dec hl
        jp line_start

cur_col:                        ; -> HL = colonna del cursore (0..)
        ld hl,(cur)
        push hl
        call line_start
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ret

upd_wantcol:
        call cur_col
        ld (wantcol),hl
        ret

gap_to_cur:                     ; porta il gap sul cursore
        ld hl,(cur)
gap_to_ofs:                     ; porta il gap sull'offset HL
        ld (gtgt),hl
        ld de,(gs)
        or a
        sbc hl,de
        ret z
        jr c,.back
        push hl
        pop bc                  ; BC = cur-gs
        ld hl,(gs)
        ld de,BUF
        add hl,de
        ex de,hl                ; DE = BUF+gs
        ld hl,(gsz)
        add hl,de               ; HL = BUF+gs+gsz
        ldir
        jr .done
.back:  ld hl,(gs)
        ld bc,(gtgt)
        or a
        sbc hl,bc
        push hl
        pop bc                  ; BC = gs-cur
        ld hl,(gs)
        ld de,BUF
        add hl,de
        dec hl                  ; sorgente (ultimo byte)
        ld de,(gsz)
        push hl
        add hl,de
        ex de,hl                ; DE = destinazione
        pop hl
        lddr
.done:  ld hl,(gtgt)
        ld (gs),hl
        jp set_sentinel

; ---------------------------------------------------------------- init
ed_reset:                       ; testo vuoto (usa bufend)
        call u_clear
        ld hl,(bufend)
        ld de,BUF
        or a
        sbc hl,de
        ld (bufsz),hl
        ld (gsz),hl
        ld hl,0
        ld (cur),hl
        ld (len),hl
        ld (gs),hl
        ld (top),hl
        ld (hscroll),hl
        ld (wantcol),hl
        ld hl,1
        ld (topline),hl
        ld (curline),hl
        ld (nlines),hl
        ld hl,(bufend)
        ld (hl),0               ; sentinella di fine testo
        ld hl,0FFFFh
        ld (selanc),hl
        xor a
        ld (dirty),a
        ld (modified),a
        jp set_sentinel

ed_init:
        call ed_reset
        ld hl,0
        ld (msgptr),hl
        xor a
        ld (pendkey),a
        ld (menuopen),a
        ld (menusel),a
        ld (srchstr),a
        ld (replstr),a
        ld (slen),a
        ld (rlen),a
        ld (mcase),a
        ld hl,s_caseoff
        ld de,casestr
        ld bc,16
        ldir
        ld (mmode),a
        ld (tm_dx),a
        ld (tm_dy),a
        ld (tm_btn),a
        IFDEF DEMO
        ld hl,demo_text
        ld de,BUF
        ld bc,demo_end-demo_text
        ldir
        ld hl,demo_end-demo_text
        ld (len),hl
        ld (gs),hl
        ld hl,(bufsz)
        ld de,(len)
        or a
        sbc hl,de               ; bufsz - len
        ld (gsz),hl
        ld hl,BUF               ; nlines = 1 + numero di LF
        ld bc,(len)
        ld de,1
.cnt:   ld a,b
        or c
        jr z,.cd
        ld a,(hl)
        cp LF
        jr nz,.nx
        inc de
.nx:    inc hl
        dec bc
        jr .cnt
.cd:    ld (nlines),de
        ENDIF
        jp set_sentinel

; ---------------------------------------------------------------- vista
mark_text:
        ld a,(dirty)
        or 1
        ld (dirty),a
        ret

set_topline:                    ; HL = riga voluta (limitata a 1..nlines)
        ld a,h
        or l
        jr nz,.nz
        ld hl,1
.nz:    ld de,(nlines)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.cl
        jr z,.cl
        ld hl,(nlines)
.cl:    ld (tmp3),hl
.f:     ld hl,(topline)
        ld de,(tmp3)
        or a
        sbc hl,de
        ret z
        jr nc,.back
        ld hl,(top)
        call next_line_start
        ret c
        ld (top),hl
        ld hl,(topline)
        inc hl
        ld (topline),hl
        call mark_text
        jr .f
.back:  ld hl,(top)
        call prev_line_start
        ld (top),hl
        ld hl,(topline)
        dec hl
        ld (topline),hl
        call mark_text
        jr .f

scroll_v:                       ; HL = delta (con segno) righe
        ld de,(topline)
        add hl,de
        bit 7,h
        jr z,.p
        ld hl,1
.p:     jp set_topline

scroll_h:                       ; HL = delta (con segno) colonne
        ld de,(hscroll)
        add hl,de
        bit 7,h
        jr z,.p
        ld hl,0
.p:     ld de,(hmax1w)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ld hl,(hmaxw)
.ok:    ld de,(hscroll)
        push hl
        or a
        sbc hl,de
        pop hl
        ret z
        ld (hscroll),hl
        jp mark_text

ensure_visible:                 ; scorre la vista in modo che il cursore sia visibile
        ld hl,(curline)
        ld de,(topline)
        or a
        sbc hl,de
        jr c,.above
        ld de,VROWS
        or a
        sbc hl,de
        jr c,.vok
        ld hl,(curline)
        ld de,VROWS-1
        or a
        sbc hl,de
        call set_topline
        jr .vok
.above: ld hl,(curline)
        call set_topline
.vok:   call cur_col
        ld de,(hscroll)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.r1
        ld (hscroll),hl
        jp mark_text
.r1:    push hl
        or a
        sbc hl,de
        ld de,(vcolsw)
        or a
        sbc hl,de
        pop hl
        ret c
        ld de,(vcw1)
        or a
        sbc hl,de
        ld (hscroll),hl
        jp mark_text

; ---------------------------------------------------------------- movimento
key_left:
        ld hl,(cur)
        ld a,h
        or l
        ret z
        dec hl
        ld (cur),hl
        call getb
        cp LF
        jr nz,.c
        ld hl,(curline)
        dec hl
        ld (curline),hl
.c:     jp upd_wantcol

key_right:
        ld hl,(cur)
        ld de,(len)
        or a
        sbc hl,de
        ret nc
        ld hl,(cur)
        call getb
        inc hl
        ld (cur),hl
        cp LF
        jr nz,.c
        ld hl,(curline)
        inc hl
        ld (curline),hl
.c:     jp upd_wantcol

key_home:
        ld hl,(cur)
        call line_start
        ld (cur),hl
        ld hl,0
        ld (wantcol),hl
        ret

key_end:
        ld hl,(cur)
        call line_end
        ld (cur),hl
        jp upd_wantcol

key_up:
        ld hl,(curline)
        dec hl
        ld a,h
        or l
        ret z
        ld hl,(cur)
        call line_start         ; HL = ls
        push hl
        call prev_line_start    ; HL = ps
        pop de                  ; DE = ls
        push hl                 ; ps
        ex de,hl
        or a
        sbc hl,de               ; ls - ps
        dec hl                  ; lunghezza riga precedente
        ld de,(wantcol)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.u
        ex de,hl
.u:     pop de
        add hl,de
        ld (cur),hl
        ld hl,(curline)
        dec hl
        ld (curline),hl
        ret

key_down:
        ld hl,(cur)
        call next_line_start
        ret c
        push hl
        call line_end
        pop de                  ; DE = ns, HL = ne
        push de
        or a
        sbc hl,de               ; lunghezza
        ld de,(wantcol)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.u
        ex de,hl
.u:     pop de
        add hl,de
        ld (cur),hl
        ld hl,(curline)
        inc hl
        ld (curline),hl
        ret

set_col:                        ; HL = colonna voluta (limitata alla riga)
        ld (tmp1),hl
        ld hl,(cur)
        call line_start
        ld (tmp2),hl
        ld hl,(cur)
        call line_end
        ld de,(tmp2)
        or a
        sbc hl,de               ; lunghezza riga
        ld de,(tmp1)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.u
        ex de,hl
.u:     ld de,(tmp2)
        add hl,de
        ld (cur),hl
        ret

key_pgup:
        ld hl,-(VROWS-1)
        call scroll_v
        ld b,VROWS-1
.l:     push bc
        call key_up
        pop bc
        djnz .l
        ret

key_pgdn:
        ld hl,VROWS-1
        call scroll_v
        ld b,VROWS-1
.l:     push bc
        call key_down
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------- modifica
ed_insert:                      ; A = carattere -> C se non inserito
        ld (tmpb),a
        cp LF
        jr z,.go
        call cur_col
        ld de,MAXCOL
        or a
        sbc hl,de
        jr c,.go
        scf
        ret
.go:    call gap_to_cur
        ld hl,(gsz)
        ld a,h
        or l
        jr nz,.has
        scf
        ret
.has:   ld hl,(gs)
        ld de,BUF
        add hl,de
        ld a,(tmpb)
        ld (hl),a
        ld hl,(gs)
        inc hl
        ld (gs),hl
        ld hl,(gsz)
        dec hl
        ld (gsz),hl
        ld hl,(len)
        inc hl
        ld (len),hl
        ld hl,(cur)
        inc hl
        ld (cur),hl
        ld a,(tmpb)
        cp LF
        jr nz,.nl
        ld hl,(curline)
        inc hl
        ld (curline),hl
        ld hl,(nlines)
        inc hl
        ld (nlines),hl
.nl:    ld hl,(cur)             ; registra l'inserimento (1 byte in tmpb)
        dec hl
        ld (uoff),hl
        ld hl,1
        ld (ulen),hl
        ld hl,tmpb
        ld (usrc),hl
        ld a,1
        call ulog
        ld a,1
        ld (modified),a
        ld hl,0FFFFh
        ld (selanc),hl
        call set_sentinel
        call upd_wantcol
        call mark_text
        or a
        ret

ed_backspace:
        ld hl,(cur)
        ld a,h
        or l
        ret z
        call gap_to_cur
        ld hl,(gs)
        dec hl
        ld (gs),hl
        ld de,BUF
        add hl,de
        ld a,(hl)
        push af                 ; registra la cancellazione del carattere (a cur-1)
        ld (usrc),hl
        ld hl,(cur)
        dec hl
        ld (uoff),hl
        ld hl,1
        ld (ulen),hl
        ld a,2
        call ulog
        pop af
        ld hl,(gsz)
        inc hl
        ld (gsz),hl
        ld hl,(len)
        dec hl
        ld (len),hl
        ld hl,(cur)
        dec hl
        ld (cur),hl
        cp LF
        jr nz,.nl
        ld hl,(curline)
        dec hl
        ld (curline),hl
        ld hl,(nlines)
        dec hl
        ld (nlines),hl
.nl:    ld hl,(top)
        ld de,(cur)
        or a
        sbc hl,de
        jr z,.ok
        jr c,.ok
        ld hl,(cur)             ; il cursore ha superato l'inizio della vista
        call line_start
        ld (top),hl
        ld hl,(curline)
        ld (topline),hl
.ok:    ld a,1
        ld (modified),a
        ld hl,0FFFFh
        ld (selanc),hl
        call set_sentinel
        call upd_wantcol
        jp mark_text

ed_delete:
        ld hl,(cur)
        ld de,(len)
        or a
        sbc hl,de
        ret nc
        call gap_to_cur
        ld hl,(gs)
        ld de,(gsz)
        add hl,de
        ld de,BUF
        add hl,de
        ld a,(hl)
        push af                 ; registra la cancellazione del carattere (a cur)
        ld (usrc),hl
        ld hl,(cur)
        ld (uoff),hl
        ld hl,1
        ld (ulen),hl
        ld a,2
        call ulog
        pop af
        ld hl,(gsz)
        inc hl
        ld (gsz),hl
        ld hl,(len)
        dec hl
        ld (len),hl
        cp LF
        jr nz,.d
        ld hl,(nlines)
        dec hl
        ld (nlines),hl
.d:     ld a,1
        ld (modified),a
        ld hl,0FFFFh
        ld (selanc),hl
        call set_sentinel
        jp mark_text

; ---------------------------------------------------------------- tastiera
handle_key:
        ld b,a
        ld a,(menuopen)
        or a
        jr z,.nm
        ld a,b
        jp menu_key             ; menu aperto: i tasti vanno al menu
.nm:    ld a,b
        cp 1Bh
        jr z,.pk                ; ESC (apre il menu) non annulla una conferma
        ld a,(pendkey)          ; la conferma vale solo se si ripete lo stesso tasto
        cp b
        jr z,.pk
        xor a
        ld (pendkey),a
.pk:    ld hl,0
        ld (msgptr),hl          ; ogni tasto cancella il messaggio
        call ukind_key          ; una serie di battute dello stesso tipo e' un solo passo di undo
        push bc
        call ensure_visible
        pop bc
        ld a,b
        cp 32
        jr c,.tab
        cp 127
        jr z,.del
        jr nc,.fin
        push af
        call sel_delete         ; la digitazione sostituisce la selezione
        pop af
        call ed_insert
        jr .fin
.del:   call key_mods
        and 1
        jr z,.dl
        call k_cut              ; Shift+Canc = taglia
        jr .fin
.dl:    call sel_range
        jr c,.d2
        call sel_delete
        jr .fin
.d2:    call ed_delete
        jr .fin
.tab:   ld hl,keytab
        ld b,KEYS
.l:     cp (hl)
        jr z,.hit
        inc hl
        inc hl
        inc hl
        djnz .l
        ret
.hit:   inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,.fin
        push de
        jp (hl)
.fin:   call ensure_visible
        call sel_range
        call nc,mark_text       ; selezione attiva: ridisegna
        jp refresh

fkcodes: db 02h,04h,05h,0Ah     ; codici di F1-F4

keys_up:                        ; attende che nessun tasto sia premuto (al massimo ~10 s)
        ld hl,(0FC9Eh)          ; JIFFY
        ld (kutmp),hl
.t:     ld b,0
.r:     push bc
        ld a,b
        BIOS SNSMAT
        pop bc
        cp 0FFh
        jr nz,.p
        inc b
        ld a,b
        cp 9
        jr nz,.r
        ret
.p:     ld hl,(0FC9Eh)
        ld de,(kutmp)
        or a
        sbc hl,de
        ld de,500
        or a
        sbc hl,de
        ret nc                  ; tasto bloccato: si prosegue comunque
        halt
        jr .t

keytab: db 0Dh
        dw k_enter
        db 08h
        dw k_bs
        db 09h
        dw k_tab
        db 1Dh
        dw k_left
        db 1Ch
        dw k_right
        db 1Eh
        dw k_up
        db 1Fh
        dw k_down
        db 0Bh
        dw k_home
        db 0Ch                  ; Shift+Home
        dw k_home
        db 18h
        dw k_x                  ; SELECT = Fine, Ctrl+X = taglia
        db 10h
        dw k_pgup
        db 0Eh
        dw k_pgdn
        db 01h
        dw k_selall
        db 03h
        dw k_copy
        db 16h
        dw k_paste
        db 12h
        dw k_ins
        db 1Bh
        dw k_menu
        db 1Ah
        dw k_undo
        db 19h
        dw k_redo
        db 06h
        dw k_find
        db 07h
        dw k_findnext
        db 14h
        dw k_replace
        db 15h                  ; F5 (la stringa del tasto funzione e' un solo byte 15h)
        dw k_run
        db 02h                  ; F1-F4: menu File, Edit, Find, Help
        dw k_f1
        db 04h
        dw k_f2
        db 05h
        dw k_f3
        db 0Ah
        dw k_f4
        IFDEF COM
        db 13h
        dw k_save
        db 17h
        dw k_saveas
        db 0Fh
        dw k_open
        db 11h
        dw k_quit
        ENDIF
keytab_end:
KEYS    equ (keytab_end-keytab)/3

k_enter:
        call sel_delete
        ld a,LF
        jp ed_insert

k_tab:  call sel_delete
.l:     ld a,' '
        call ed_insert
        ret c
        call cur_col
        ld a,l
        and 3
        jr nz,.l
        ret


; ---------------------------------------------------------------- selezione / clipboard
key_mods:                       ; -> A: bit0 = Shift premuto, bit1 = Ctrl premuto
        ld a,6
        BIOS SNSMAT
        cpl
        and 3
        ret

k_left:  call sel_prep
        jp key_left
k_right: call sel_prep
        jp key_right
k_up:   call sel_prep
        jp key_up
k_down: call sel_prep
        jp key_down
k_home: call sel_prep
        jp key_home
k_pgup: call sel_prep
        jp key_pgup
k_pgdn: call sel_prep
        jp key_pgdn
k_x:    ld a,7                  ; stesso codice 18h: SELECT (Fine) oppure Ctrl+X (taglia)
        BIOS SNSMAT
        bit 6,a
        jp nz,k_cut
        call sel_prep
        jp key_end

k_bs:   call sel_range
        jp c,ed_backspace
        jp sel_delete

k_ins:  call key_mods           ; Ctrl+Ins = copia, Shift+Ins = incolla
        bit 1,a
        jp nz,k_copy
        bit 0,a
        jp nz,k_paste
        ret

k_selall:
        ld hl,0
        ld (selanc),hl
        ld hl,(len)
        ld (cur),hl
        ld hl,(nlines)
        ld (curline),hl
        jp upd_wantcol

sel_prep:                       ; prima di un movimento: Shift estende, altrimenti annulla
        call sel_range
        jr c,.q
        call mark_text
.q:     call key_mods
        and 1
        jr nz,.sh
        ld hl,0FFFFh
        ld (selanc),hl
        ret
.sh:    ld hl,(selanc)
        ld a,h
        and l
        inc a
        ret nz
        ld hl,(cur)
        ld (selanc),hl
        ret

sel_range:                      ; -> NC con HL = inizio, DE = fine se c'e' una selezione; C se vuota
        ld hl,(selanc)
        ld a,h
        and l
        inc a
        jr z,.none
        ld de,(cur)
        or a
        sbc hl,de
        jr z,.none
        jr c,.fw
        add hl,de               ; ancora dopo il cursore: inizio = cursore
        ex de,hl
        or a
        ret
.fw:    add hl,de
        or a
        ret
.none:  scf
        ret

sel_delete:                     ; elimina la selezione attiva (NC) oppure non fa nulla (C)
        call sel_range
        ret c
        ld (tmp1),hl
        ld (tmp2),de
        ex de,hl
        call gap_to_ofs         ; ora [inizio,fine) e' contiguo prima del gap
        ld hl,(tmp2)
        ld de,(tmp1)
        or a
        sbc hl,de
        ld b,h
        ld c,l                  ; BC = byte da togliere
        ld (ulen),bc            ; registra la cancellazione [inizio, fine)
        ld hl,(tmp1)
        ld (uoff),hl
        ld de,BUF
        add hl,de
        ld (usrc),hl
        push bc
        ld a,2
        call ulog
        pop bc
        ld hl,(tmp1)
        ld de,BUF
        add hl,de
        ld de,0                 ; DE = a-capo eliminati
.c:     ld a,b
        or c
        jr z,.cd
        ld a,(hl)
        cp LF
        jr nz,.n
        inc de
.n:     inc hl
        dec bc
        jr .c
.cd:    ld (tmp3),de
        ld hl,(tmp2)
        ld de,(tmp1)
        or a
        sbc hl,de
        ex de,hl                ; DE = n
        ld hl,(gs)
        or a
        sbc hl,de
        ld (gs),hl
        ld hl,(gsz)
        add hl,de
        ld (gsz),hl
        ld hl,(len)
        or a
        sbc hl,de
        ld (len),hl
        ld hl,(cur)             ; se il cursore era in fondo, la riga corrente scende
        ld de,(tmp2)
        or a
        sbc hl,de
        jr nz,.cc
        ld hl,(curline)
        ld de,(tmp3)
        or a
        sbc hl,de
        ld (curline),hl
.cc:    ld hl,(tmp1)
        ld (cur),hl
        ld hl,(nlines)
        ld de,(tmp3)
        or a
        sbc hl,de
        ld (nlines),hl
        ld hl,(top)
        ld de,(cur)
        or a
        sbc hl,de
        jr z,.tk
        jr c,.tk
        ld hl,(cur)             ; l'inizio della vista era dentro la parte tolta
        call line_start
        ld (top),hl
        ld hl,(curline)
        ld (topline),hl
.tk:    ld hl,0FFFFh
        ld (selanc),hl
        ld a,1
        ld (modified),a
        call set_sentinel
        call upd_wantcol
        call mark_text
        or a
        ret

k_copy: call key_mods           ; 03h: Ctrl+C = copia (STOP da solo = niente)
        bit 1,a
        ret z
sel_copy:                       ; copia la selezione nella clipboard; C se impossibile
        call sel_range
        ret c
        ld (tmp1),hl
        ld (tmp2),de
        ex de,hl
        call gap_to_ofs
        ld hl,(tmp2)
        ld de,(tmp1)
        or a
        sbc hl,de
        ld b,h
        ld c,l                  ; BC = n
        ld de,(clipsz)
        ld h,b
        ld l,c
        or a
        sbc hl,de               ; n - capacita'
        jr z,.fit
        jr c,.fit
        ld hl,m_clipfull
        ld (msgptr),hl
        scf
        ret
.fit:   ld (cliplen),bc
        ld hl,(tmp1)
        ld de,BUF
        add hl,de
        ld de,CLIP
        ldir
        ld hl,(cliplen)
        ld (tmp1),hl
        ld hl,m_copied
        call mk_msg
        or a
        ret

k_cut:  call sel_copy
        ret c
        jp sel_delete

k_paste:
        call sel_delete
        ld bc,(cliplen)
        ld a,b
        or c
        ret z
        ld hl,CLIP
        call ins_block
        ret nc
        ld hl,m_noroom
        ld (msgptr),hl
        ret

ins_block:                      ; HL = sorgente, BC = n byte: li inserisce al cursore; C se manca spazio
        ld (tmp2),hl
        ld (insn),bc
        call gap_to_cur         ; (clobbera tutto)
        ld bc,(insn)
        ld hl,(gsz)
        or a
        sbc hl,bc
        jr nc,.room
        scf
        ret
.room:  ld hl,(cur)             ; registra l'inserimento
        ld (uoff),hl
        ld hl,(insn)
        ld (ulen),hl
        ld hl,(tmp2)
        ld (usrc),hl
        ld a,1
        call ulog
        ld bc,(insn)
        ld hl,(gs)
        ld de,BUF
        add hl,de
        ex de,hl                ; DE = destinazione
        ld hl,(tmp2)
        ldir
        ld hl,(tmp2)
        ld bc,(insn)
        call count_lf           ; DE = a-capo inseriti
        ld (tmp3),de
        ld de,(insn)
        ld hl,(gs)
        add hl,de
        ld (gs),hl
        ld hl,(gsz)
        or a
        sbc hl,de
        ld (gsz),hl
        ld hl,(len)
        add hl,de
        ld (len),hl
        ld hl,(cur)
        add hl,de
        ld (cur),hl
        ld de,(tmp3)
        ld hl,(curline)
        add hl,de
        ld (curline),hl
        ld hl,(nlines)
        add hl,de
        ld (nlines),hl
        ld hl,0FFFFh
        ld (selanc),hl
        ld a,1
        ld (modified),a
        call set_sentinel
        call upd_wantcol
        call mark_text
        or a
        ret

count_lf:                       ; HL = puntatore, BC = byte -> DE = numero di LF
        ld de,0
.l:     ld a,b
        or c
        ret z
        ld a,(hl)
        cp LF
        jr nz,.n
        inc de
.n:     inc hl
        dec bc
        jr .l

m_copied:   db "Copied ",0
m_clipfull: db "Selection too big for the clipboard",0
m_noroom:   db "No room to paste",0

key_shift:                      ; -> A = 1 se Shift premuto
        call key_mods
        and 1
        ret

mk_msg:                         ; HL = prefisso, numero in (tmp1) -> msgptr = "prefisso N bytes"
        ld de,s_bytes
mk_msgs:                        ; HL = prefisso, DE = suffisso, numero in (tmp1)
        push de
        ld de,msgbuf
        call strcpy
        ld hl,(tmp1)
        call dec16
        pop hl
        call strcpy
        xor a
        ld (de),a
        ld hl,msgbuf
        ld (msgptr),hl
        ret

s_bytes: db " bytes",0


; ---------------------------------------------------------------- barra dei menu
; menutab: per menu larghezza del riquadro, numero di voci, puntatore alle voci.
; voce (7 byte): etichetta, scorciatoia, gestore, tasto rapido.
menutab:
        db 24,5
        dw it_file
        db 26,7
        dw it_edit
        db 24,4
        dw it_find
        db 20,5
        dw it_help
        db 20,1
        dw it_run
it_file: dw l_new,s_none,k_new
        db 'N'
        dw l_open,s_cto,k_open
        db 'O'
        dw l_save,s_cts,k_save
        db 'S'
        dw l_saveas,s_ctw,k_saveas
        db 'A'
        dw l_exit,s_ctq,k_quit
        db 'X'
it_edit: dw l_undo,s_ctz,k_undo
        db 'U'
        dw l_redo,s_cty,k_redo
        db 'R'
        dw l_cut,s_ctx,k_cut
        db 'T'
        dw l_copy,s_ctc,sel_copy
        db 'C'
        dw l_paste,s_ctv,k_paste
        db 'P'
        dw l_del,s_del,k_mdel
        db 'D'
        dw l_selall,s_cta,k_selall
        db 'A'
it_find: dw l_find,s_ctf,k_find
        db 'F'
        dw l_fnext,s_ctg,k_findnext
        db 'N'
        dw l_repl,s_ctt,k_replace
        db 'R'
        dw casestr,s_none,k_case
        db 'M'
it_help: dw l_hindex,s_f7,k_hindex
        db 'I'
        dw l_htopic,s_none,k_htopic
        db 'T'
        dw l_hword,s_f6,k_hword
        db 'W'
        dw l_help,s_none,k_help
        db 'S'
        dw l_about,s_none,k_about
        db 'A'
it_run: dw l_run,s_f5,k_run
        db 'R'
l_run:    db "Run program",0
s_f5:     db "F5",0
l_new:    db "New",0
l_open:   db "Open...",0
l_save:   db "Save",0
l_saveas: db "Save As...",0
l_exit:   db "Exit",0
l_undo:   db "Undo",0
l_redo:   db "Redo",0
l_cut:    db "Cut",0
l_copy:   db "Copy",0
l_paste:  db "Paste",0
l_del:    db "Delete",0
l_selall: db "Select all",0
l_find:   db "Find...",0
l_fnext:  db "Find next",0
l_repl:   db "Replace...",0
l_help:   db "Shortcuts",0
l_hindex: db "Index",0
l_htopic: db "Topic...",0
l_hword:  db "On word",0
s_f6:     db "F6",0
s_f7:     db "F7",0
s_topicp: db "Help topic: ",0
m_nohelp: db "HELP.IDX / HELP.TXT not found",0
m_helpmem: db "Not enough free memory for help",0
m_nohlp1: db "No help for ",0
about_txt: db 0,"SamPr Basic 1.0",0,"2026 Fausto Pracek",0,0
l_about:  db "About",0
s_none:   db 0
s_cto:    db "Ctrl+O",0
s_cts:    db "Ctrl+S",0
s_ctw:    db "Ctrl+W",0
s_ctq:    db "Ctrl+Q",0
s_ctx:    db "Ctrl+X",0
s_ctz:    db "Ctrl+Z",0
s_cty:    db "Ctrl+Y",0
s_ctc:    db "Ctrl+C",0
s_ctv:    db "Ctrl+V",0
s_cta:    db "Ctrl+A",0
s_del:    db "Del",0
s_ctf:    db "Ctrl+F",0
s_ctg:    db "Ctrl+G",0
s_ctt:    db "Ctrl+T",0
m_about:  db "SamPr Basic 0.2 - BASIC IDE and compiler for MSX2",0
m_keys:   db "Esc,F1-F4=menu F5=run F6=help on word F7=help index Ctrl+S/W/O/Q file Ctrl+C/X/V clip Ctrl+Z/Y undo Ctrl+F/G/T find",0
m_nodisk: db "No disk access in this build",0

k_menu: ld a,1                  ; ESC: apre il menu File
open_menu:
        ld (menuopen),a
        xor a
        ld (menusel),a
        ret
k_f1:   ld a,1
        jr open_menu
k_f2:   ld a,2
        jr open_menu
k_f3:   ld a,3
        jr open_menu
k_f4:   ld a,4
        jr open_menu

k_mdel: call sel_range
        jp c,ed_delete
        jp sel_delete

k_about:                        ; finestra: "SamPr Basic 1.0" / "2026 Fausto Pracek"; un tasto la chiude
        call refresh            ; toglie il menu a tendina
        call ptr_hide
        ld hl,about_txt
        ld d,9
.l:     push de
        push hl
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,27
        ld (hl),' '
        ldir
        pop hl
        ld de,rowbuf+4
        call strcpy
        inc hl                  ; stringa successiva
        push hl
        ld hl,rowbuf
        ld b,28
.o:     set 7,(hl)
        inc hl
        djnz .o
        ld a,(sw)
        sub 28
        srl a
        ld e,a
        pop hl
        pop de                  ; D = riga
        push hl
        push de
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld b,28
        ld c,VDPD
        otir
        pop de
        pop hl
        inc d
        ld a,d
        cp 13
        jr nz,.l
        BIOS CHGET
        jp mark_text

k_help: ld hl,m_keys
        ld (msgptr),hl
        ret

        IFNDEF COM
k_new:
k_open:
k_save:
k_saveas:
k_run:
k_hindex:
k_htopic:
k_hword:
k_quit: ld hl,m_nodisk
        ld (msgptr),hl
        ret
        ENDIF

menu_info:                      ; menu aperto -> B = larghezza, C = voci, HL = elenco voci, D = colonna
        ld a,(menuopen)
        dec a
        ld e,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld bc,menutab
        add hl,bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,e
        add a,a
        ld d,a
        add a,a
        add a,d
        ld d,a                  ; 6*k
        ld a,(sw)               ; il riquadro non esce dallo schermo (40 colonne: i menu a destra si spostano a sinistra)
        sub b
        cp d
        jr nc,.o
        ld d,a
.o:     ret

menu_close:
        xor a
        ld (menuopen),a
        call mark_text          ; il testo sotto il riquadro va ridisegnato
        jp refresh

menu_exec:                      ; esegue la voce evidenziata
        call menu_info
        ld a,(menusel)
        push hl
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; 7*voce
        pop de
        add hl,de
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; gestore
        push de
        xor a
        ld (menuopen),a
        ld (uglue),a            ; ogni comando di menu e' un gruppo a se'
        ld (ukind),a
        call mark_text
        pop hl
        ld de,.back
        push de
        jp (hl)
.back:  call ensure_visible
        jp refresh

menu_key:                       ; A = tasto, menu aperto
        cp 1Bh
        jp z,menu_close
        ld b,1                  ; F1-F4: passa direttamente a quel menu
        cp 02h
        jr z,.fk
        inc b
        cp 04h
        jr z,.fk
        inc b
        cp 05h
        jr z,.fk
        inc b
        cp 0Ah
        jr nz,.nfk
.fk:    ld a,b
        jp .st
.nfk:   cp 15h                  ; F5: chiude il menu ed esegue
        jr nz,.nf5
        call menu_close
        jp k_run
.nf5:
        cp 0Dh
        jp z,menu_exec
        cp 1Dh
        jr z,.left
        cp 1Ch
        jr z,.right
        cp 1Eh
        jr z,.up
        cp 1Fh
        jr z,.down
        cp 'a'                  ; tasto rapido (maiuscole/minuscole)
        jr c,.hk0
        cp 'z'+1
        jr nc,.hk0
        sub 20h
.hk0:   ld (tmpb),a
        call menu_info
        ld b,c
        ld c,0
.hk:    push hl
        ld de,6
        add hl,de
        ld a,(hl)
        pop hl
        ld e,a
        ld a,(tmpb)
        cp e
        jr z,.found
        ld de,7
        add hl,de
        inc c
        djnz .hk
        ret
.found: ld a,c
        ld (menusel),a
        jp menu_exec
.left:  ld a,(menuopen)
        dec a
        jr nz,.st
        ld a,NMENU
        jr .st
.right: ld a,(menuopen)
        inc a
        cp NMENU+1
        jr c,.st
        ld a,1
.st:    ld (menuopen),a
        xor a
        ld (menusel),a
        call mark_text          ; il riquadro precedente va cancellato
        jp refresh
.up:    ld a,(menusel)
        or a
        jr nz,.u1
        call menu_info
        ld a,c
.u1:    dec a
        ld (menusel),a
        jp refresh
.down:  call menu_info          ; (clobbera B)
        ld a,(menusel)
        inc a
        cp c
        jr c,.d1
        xor a
.d1:    ld (menusel),a
        jp refresh

menu_hit:                       ; puntatore sopra una voce? -> A = indice oppure FF
        call menu_info
        ld a,(mcy)
        sub 2
        jr c,.no
        cp c
        jr nc,.no
        ld e,a                  ; indice voce
        ld a,(mcx)
        sub d
        jr c,.no
        jr z,.no                ; bordo sinistro
        dec a
        ld d,a                  ; colonna interna
        ld a,b
        sub 2
        cp d
        jr z,.no
        jr c,.no
        ld a,e
        ret
.no:    ld a,0FFh
        ret

menu_hover:                     ; il puntatore si e' mosso con il menu aperto
        call menu_hit
        cp 0FFh
        ret z
        ld hl,menusel
        cp (hl)
        ret z
        ld (hl),a
        jp refresh

menu_click:                     ; pulsante premuto con il menu aperto
        ld a,(mcy)
        or a
        jr z,.title
        call menu_hit
        cp 0FFh
        jp z,menu_close
        ld (menusel),a
        jp menu_exec
.title: ld a,(mcx)
        cp MENUW*NMENU
        jp nc,menu_close
        ld b,0
.k:     cp MENUW
        jr c,.kd
        sub MENUW
        inc b
        jr .k
.kd:    ld a,b
        inc a
        ld hl,menuopen
        cp (hl)
        jp z,menu_close         ; stesso titolo: chiude
        ld (hl),a
        xor a
        ld (menusel),a
        call mark_text
        jp refresh

mrow_border:                    ; A = glifo sinistro, E = glifo destro (video inverso)
        ld hl,rowbuf
        ld (hl),a
        inc hl
        ld a,(mw)
        sub 2
        ld b,a
.b:     ld (hl),86h
        inc hl
        djnz .b
        ld (hl),e
        ret

mrow_blank:                     ; riga interna: bordi 87h e spazi inversi
        ld hl,rowbuf
        ld (hl),87h
        inc hl
        ld a,(mw)
        sub 2
        ld b,a
.b:     ld (hl),0A0h
        inc hl
        djnz .b
        ld (hl),87h
        ret

mrow_str:                       ; HL = stringa, DE = destinazione in rowbuf (copia con bit 7)
.l:     ld a,(hl)
        or a
        ret z
        or 80h
        ld (de),a
        inc hl
        inc de
        jr .l

mrow_put:                       ; A = riga schermo: scrive mw celle di rowbuf a (riga, mx0)
        ld d,a
        ld a,(mx0)
        ld e,a
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(mw)
        ld b,a
        ld c,VDPD
        otir
        ret

menu_draw:                      ; riquadro a discesa del menu aperto
        call menu_info
        ld a,b
        ld (mw),a
        ld a,c
        ld (mn),a
        ld (mrec),hl
        ld a,d
        ld (mx0),a
        ld a,88h
        ld e,89h
        call mrow_border
        ld a,1
        call mrow_put
        xor a
        ld (mi),a
.row:   call mrow_blank
        ld a,(mi)               ; record della voce = elenco + 7*i
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,(mrec)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tmp1),de            ; etichetta
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (tmp2),de            ; scorciatoia
        ld hl,(tmp1)
        ld de,rowbuf+2
        call mrow_str
        ld hl,(tmp2)            ; scorciatoia allineata a destra
        ld b,0
.ln:    ld a,(hl)
        or a
        jr z,.lnd
        inc hl
        inc b
        jr .ln
.lnd:   ld a,(mw)
        sub b
        sub 2
        ld e,a
        ld d,0
        ld hl,rowbuf
        add hl,de
        ex de,hl
        ld hl,(tmp2)
        call mrow_str
        ld a,(mi)
        ld b,a
        ld a,(menusel)
        cp b
        jr nz,.ns
        ld hl,rowbuf+1          ; voce evidenziata: interno in video normale
        ld a,(mw)
        sub 2
        ld b,a
.rs:    res 7,(hl)
        inc hl
        djnz .rs
.ns:    ld a,(mi)
        add a,2
        call mrow_put
        ld a,(mi)
        inc a
        ld (mi),a
        ld hl,mn
        cp (hl)
        jr nz,.row
        ld a,8Bh
        ld e,8Ch
        call mrow_border
        ld a,(mn)
        add a,2
        jp mrow_put


; ---------------------------------------------------------------- prompt di riga, cerca, sostituisci
; prompt_line: HL = prompt, DE = destinazione (0-term), B = lunghezza massima,
;              C = bit0 spazi ammessi, bit1 parte dal testo attuale, bit2 Invio vuoto accettato
prompt_line:
        ld (pdst),de
        ld (pprm),hl
        ld a,b
        ld (pmax),a
        ld a,c
        ld (pflag),a
        xor a
        ld (plen),a
        ld (iobuf),a
        bit 1,c
        jr z,.draw
        ld hl,(pdst)
        ld de,iobuf
        ld b,0
.ci:    ld a,(hl)
        ld (de),a
        or a
        jr z,.cd
        inc hl
        inc de
        inc b
        jr .ci
.cd:    ld a,b
        ld (plen),a
.draw:  ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        ld hl,(pprm)
        ld de,rowbuf+1
        call strcpy
        ld hl,iobuf
        call strcpy
        ld a,'_'
        ld (de),a
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
.o:     set 7,(hl)
        inc hl
        djnz .o
        ld d,0
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
        ld c,VDPD
        otir
.key:   BIOS CHGET
        cp 0Dh
        jr z,.enter
        cp 1Bh
        jr z,.cancel
        cp 08h
        jr z,.bs
        cp 7Fh
        jr z,.bs
        cp 32
        jr c,.key
        jr nz,.nsp
        ld a,(pflag)
        and 1
        jr z,.key
        ld a,' '
.nsp:   cp 127
        jr nc,.key
        ld c,a
        ld a,(plen)
        ld hl,pmax
        cp (hl)
        jr nc,.key
        ld e,a
        ld d,0
        ld hl,iobuf
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),0
        ld a,(plen)
        inc a
        ld (plen),a
        jp .draw
.bs:    ld a,(plen)
        or a
        jr z,.key
        dec a
        ld (plen),a
        ld e,a
        ld d,0
        ld hl,iobuf
        add hl,de
        ld (hl),0
        jp .draw
.enter: ld a,(plen)
        or a
        jr nz,.acc
        ld a,(pflag)
        and 4
        jr z,.cancel
.acc:   ld hl,iobuf
        ld de,(pdst)
        ld a,(plen)
        inc a
        ld c,a
        ld b,0
        ldir
        or a
        ret
.cancel: scf
        ret

show_row0:                      ; HL = testo: lo mostra in video inverso sulla riga 0
        push hl
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        pop hl
        ld de,rowbuf+1
        call strcpy
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
.o:     set 7,(hl)
        inc hl
        djnz .o
        ld d,0
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
        ld c,VDPD
        otir
        ret

strlen_a:                       ; HL = stringa 0-terminata -> A = lunghezza
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc hl
        inc b
        jr .l
.d:     ld a,b
        ret

find_prep:                      ; gap sul cursore, maschera del caso, copia del testo cercato
        call gap_to_cur
        ld a,(mcase)
        or a
        ld a,20h
        jr z,.m
        xor a
.m:     ld (smask),a
        ld c,a
        ld hl,srchstr
        ld de,srchlow
.l:     ld a,(hl)
        or a
        jr z,.d
        cp 'A'
        jr c,.s
        cp 'Z'+1
        jr nc,.s
        or c
.s:     ld (de),a
        inc hl
        inc de
        jr .l
.d:     ld (de),a
        ret

match_here:                     ; HL = testo (fisico) -> Z se coincide con srchlow; preserva HL, DE, BC
        push hl
        push de
        push bc
        ld a,(smask)
        ld c,a
        ld a,(slen)
        ld b,a
        ld de,srchlow
.l:     ld a,(hl)
        cp 'A'
        jr c,.n
        cp 'Z'+1
        jr nc,.n
        or c
.n:     ex de,hl
        cp (hl)
        ex de,hl
        jr nz,.no
        inc hl
        inc de
        djnz .l
        xor a
        jr .out
.no:    or 1
.out:   pop bc
        pop de
        pop hl
        ret

scan:                           ; cerca in [spos, min(slim, len-m+1)) con scarto fisico sdelta -> NC e HL = inizio, C se non trovato
        ld a,(slen)
        ld e,a
        ld d,0
        ld hl,(len)
        or a
        sbc hl,de               ; len - m
        ret c
        inc hl                  ; ultima posizione + 1
        ld de,(slim)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.t1                ; len-m+1 < slim: vale len-m+1
        ex de,hl                ; altrimenti vale slim
.t1:    ld de,(spos)
        or a
        sbc hl,de               ; numero di posizioni
        jr c,.none
        jr z,.none
        ld d,h
        ld e,l                  ; DE = contatore
        ld hl,(spos)
        ld bc,BUF
        add hl,bc
        ld bc,(sdelta)
        add hl,bc               ; HL = indirizzo fisico di partenza
        ld a,(smask)
        ld c,a
        ld a,(srchlow)
        or c
        ld b,a                  ; B = primo carattere (filtro rapido), C = maschera
.l:     ld a,(hl)
        or c
        cp b
        jr z,.cand
.nx:    inc hl
        dec de
        ld a,d
        or e
        jr nz,.l
.none:  scf
        ret
.cand:  call match_here
        jr z,.found
        jr .nx
.found: ld bc,BUF
        or a
        sbc hl,bc
        ld bc,(sdelta)
        or a
        sbc hl,bc               ; HL = offset logico dell'inizio
        or a
        ret

do_find_fw:                     ; dal cursore alla fine (senza girare) -> NC, HL = inizio
        ld a,(slen)
        or a
        jr nz,.go
        scf
        ret
.go:    call find_prep
        ld hl,(cur)
        ld (spos),hl
        ld hl,(gsz)
        ld (sdelta),hl
        ld hl,0FFFFh
        ld (slim),hl
        jp scan

do_find:                        ; dal cursore alla fine, poi dall'inizio fino al cursore
        xor a
        ld (swrap),a
        call do_find_fw
        ret nc
        ld a,(slen)
        or a
        scf
        ret z
        ld hl,0
        ld (spos),hl
        ld (sdelta),hl
        ld a,(slen)
        ld e,a
        ld d,0
        ld hl,(cur)
        or a
        sbc hl,de               ; cur - m: le corrispondenze devono finire prima del cursore
        jr c,.none
        inc hl
        ld (slim),hl
        call scan
        ret c
        ld a,1
        ld (swrap),a
        or a
        ret
.none:  scf
        ret

goto_ofs:                       ; DE = nuovo offset del cursore (gap sul vecchio cursore): aggiorna curline
        ld (tmp1),de
        ld hl,(cur)
        or a
        sbc hl,de
        jr z,.set
        jr c,.fw
        ld b,h
        ld c,l                  ; BC = cur - destinazione
        ld hl,BUF
        add hl,de
        call count_lf
        ld hl,(curline)
        or a
        sbc hl,de
        ld (curline),hl
        jr .set
.fw:    ld hl,(tmp1)
        ld de,(cur)
        or a
        sbc hl,de
        ld b,h
        ld c,l                  ; BC = destinazione - cur
        ld hl,(cur)
        ld de,BUF
        add hl,de
        ld de,(gsz)
        add hl,de               ; dopo il gap
        call count_lf
        ld hl,(curline)
        add hl,de
        ld (curline),hl
.set:   ld hl,(tmp1)
        ld (cur),hl
        ret

find_show:                      ; HL = inizio della corrispondenza: la seleziona, cursore in fondo
        ld (selanc),hl
        ld a,(slen)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        call goto_ofs
        call upd_wantcol
        ld hl,(curline)         ; centra la riga se non e' visibile
        ld de,(topline)
        or a
        sbc hl,de
        jr c,.cen
        ld de,VROWS
        or a
        sbc hl,de
        jr c,.vis
.cen:   ld hl,(curline)
        ld de,VROWS/2
        or a
        sbc hl,de
        jr nc,.ok
        ld hl,1
.ok:    call set_topline
.vis:   jp mark_text

set_slen:
        ld hl,srchstr
        call strlen_a
        ld (slen),a
        ret

k_find:                         ; Ctrl+F
        ld hl,s_findp
        ld de,srchstr
        ld b,30
        ld c,3
        call prompt_line
        ret c
        call set_slen
find_again:
        call do_find
        jr c,.nf
        call find_show
        ld a,(swrap)
        or a
        ret z
        ld hl,m_wrapped
        ld (msgptr),hl
        ret
.nf:    ld hl,m_nfound
        ld (msgptr),hl
        ret

k_findnext:                     ; Ctrl+G
        ld a,(srchstr)
        or a
        jr z,k_find
        jr find_again

k_case:
        ld a,(mcase)
        xor 1
        ld (mcase),a
        ld hl,s_caseoff
        jr z,.s
        ld hl,s_caseon
.s:     ld de,casestr
        ld bc,16
        ldir
        ret

ask_replace:                    ; -> A = 'y', 'n', 'a' oppure 0 (Esc)
        ld hl,s_askrep
        call show_row0
.k:     BIOS CHGET
        cp 1Bh
        jr z,.esc
        or 20h
        cp 'y'
        ret z
        cp 'n'
        ret z
        cp 'a'
        ret z
        jr .k
.esc:   xor a
        ret

k_replace:                      ; Ctrl+T: sostituisce con conferma (Y/N/A/Esc)
        ld hl,s_findp
        ld de,srchstr
        ld b,30
        ld c,3
        call prompt_line
        ret c
        call set_slen
        ld hl,s_replp
        ld de,replstr
        ld b,30
        ld c,7
        call prompt_line
        ret c
        ld hl,replstr
        call strlen_a
        ld (rlen),a
        xor a
        ld (rall),a
        ld hl,0
        ld (rcount),hl
.loop:  call do_find_fw
        jr c,.done
        call find_show
        ld a,(rall)
        or a
        jr nz,.rep
        call ensure_visible
        call refresh
        call ask_replace
        or a
        jr z,.done
        cp 'n'
        jr z,.loop
        cp 'a'
        jr nz,.rep
        ld a,1
        ld (rall),a
.rep:   call sel_delete
        ld a,(rlen)
        or a
        jr z,.cnt
        ld c,a
        ld b,0
        ld hl,replstr
        call ins_block
        jr c,.noroom
.cnt:   ld hl,(rcount)
        inc hl
        ld (rcount),hl
        jr .loop
.noroom: ld hl,m_norep
        ld (msgptr),hl
        ret
.done:  ld hl,0FFFFh
        ld (selanc),hl
        call mark_text
        ld hl,(rcount)
        ld (tmp1),hl
        ld a,h
        or l
        jr nz,.some
        ld hl,m_nfound
        ld (msgptr),hl
        ret
.some:  ld hl,m_replaced
        ld de,s_occ
        jp mk_msgs

s_findp:   db "Find: ",0
s_replp:   db "Replace with: ",0
s_askrep:  db "Replace?   Y = yes   N = no   A = all   Esc = stop",0
s_occ:     db " occurrence(s)",0
s_caseoff: db "Match case: off",0
s_caseon:  db "Match case: on ",0
m_nfound:  db "Text not found",0
m_wrapped: db "Search wrapped around",0
m_norep:   db "No room for the replacement",0
m_replaced: db "Replaced ",0


; ---------------------------------------------------------------- annulla / ripeti
; Registro in UNDO..UNDO+UNDOSZ: record = tipo (1 inserimento, 2 cancellazione; bit 7 = si unisce al
; gruppo precedente), offset (w), lunghezza (w), dati, dimensione del record (w, per leggere all'indietro).
; ucur separa i record applicati da quelli ripetibili (redo); una nuova modifica scarta questi ultimi.
u_clear:
        ld hl,UNDO
        ld (ucur),hl
        ld (uend),hl
        xor a
        ld (uglue),a
        ld (ukind),a
        ld (unolog),a
        ret

ukind_key:                      ; B = tasto (preservato): decide se il gruppo continua
        push bc
        ld a,b
        ld c,0                  ; 0 = comando qualsiasi
        cp 32
        jr c,.ctl
        cp 127
        jr z,.del
        jr nc,.set
        ld c,1                  ; carattere stampabile
        jr .set
.del:   call key_mods           ; Shift+Canc e' "taglia": non e' una serie di cancellazioni
        and 1
        jr nz,.set
        ld c,3
        jr .set
.ctl:   cp 0Dh
        jr z,.t1
        cp 09h
        jr z,.t1
        cp 08h
        jr nz,.set
        ld c,2
        jr .set
.t1:    ld c,1
.set:   ld a,(ukind)
        cp c
        jr nz,.brk
        ld a,c
        or a
        jr nz,.keep             ; stessa serie: il gruppo continua
.brk:   xor a
        ld (uglue),a
        ld a,c
        ld (ukind),a
.keep:  pop bc
        ret

ulog:                           ; A = tipo; uoff, ulen, usrc descrivono la modifica gia' decisa
        ld (utype),a
        ld a,(unolog)
        or a
        ret nz
        ld hl,(ulen)
        ld de,7
        add hl,de
        ld de,UNDOSZ+1
        or a
        sbc hl,de
        jr c,.fits
        call u_clear            ; non entra nemmeno da solo: si rinuncia all'annullamento
        ld hl,m_nundo2
        ld (msgptr),hl
        ret
.fits:  ld hl,(ucur)
        ld (uend),hl            ; una nuova modifica scarta la coda di redo
        ld a,(uglue)            ; fusione con l'inserimento precedente (battute contigue)
        or a
        jp z,.new
        ld a,(utype)
        cp 1
        jp nz,.new
        ld hl,(ulen)
        ld de,1
        or a
        sbc hl,de
        jp nz,.new
        ld hl,(ucur)
        ld de,UNDO
        or a
        sbc hl,de
        jp z,.new
        ld hl,(ucur)
        ld de,UNDO+UNDOSZ
        or a
        sbc hl,de
        jp nc,.new              ; manca il posto per un byte in piu'
        ld hl,(ucur)
        dec hl
        dec hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = dimensione dell'ultimo record
        ld hl,(ucur)
        or a
        sbc hl,de
        ld (urec),hl
        ld a,(hl)
        and 7Fh
        cp 1
        jp nz,.new
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = offset
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = lunghezza
        ld a,b
        or a
        jp nz,.new
        ld a,c
        cp 200
        jp nc,.new
        ex de,hl                ; HL = offset
        ld de,(uoff)
        ex de,hl                ; DE = offset del record, HL = nuovo offset
        push hl
        ld h,d
        ld l,e
        add hl,bc               ; fine dell'ultimo record
        pop de                  ; DE = nuovo offset
        or a
        sbc hl,de
        jp nz,.new              ; non contiguo
        ld hl,(usrc)            ; contiguo: il byte va al posto del vecchio trailer
        ld a,(hl)
        ld hl,(ucur)
        dec hl
        dec hl
        ld (hl),a
        ld hl,(urec)
        inc hl
        inc hl
        inc hl
        inc (hl)                ; lunghezza + 1
        ld a,(hl)
        add a,7                 ; nuova dimensione del record
        ld hl,(ucur)
        inc hl
        ld (ucur),hl
        ld (uend),hl
        dec hl
        dec hl
        ld (hl),a
        inc hl
        ld (hl),0
        ret
.new:   ld hl,(ulen)            ; libera i gruppi piu' vecchi finche' il record entra
        ld de,7
        add hl,de
        ex de,hl
        ld hl,(uend)
        add hl,de
        ld de,UNDO+UNDOSZ+1
        or a
        sbc hl,de
        jr c,.room
        call u_drop
        jr .new
.room:  ld hl,(uend)
        ld a,(utype)
        ld c,a
        ld a,(uglue)
        or a
        ld a,c
        jr z,.nj
        or 80h
.nj:    ld (hl),a
        inc hl
        ld bc,(uoff)
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld bc,(ulen)
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ex de,hl                ; DE = destinazione dei dati
        ld a,b
        or c
        jr z,.nd
        ld hl,(usrc)
        ldir
.nd:    ex de,hl                ; HL = posto del trailer
        ld de,(ulen)
        push hl
        ld hl,7
        add hl,de
        ex de,hl                ; DE = dimensione del record
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (ucur),hl
        ld (uend),hl
        ld a,1
        ld (uglue),a
        ret

u_drop:                         ; elimina il gruppo piu' vecchio (il registro viene compattato)
        ld hl,UNDO
        ld de,(uend)
        or a
        push hl
        sbc hl,de
        pop hl
        jp nc,u_clear           ; gia' vuoto
.l:     push hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,7
        add hl,de
        ex de,hl                ; DE = dimensione del record
        pop hl
        add hl,de               ; HL = record successivo
        ld de,(uend)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.done             ; fine del registro
        ld a,(hl)
        and 80h
        jr nz,.l                ; unito al precedente: stesso gruppo
.done:  push hl                 ; HL = primo byte da conservare
        ld de,UNDO
        or a
        sbc hl,de
        ex de,hl                ; DE = byte eliminati
        ld hl,(uend)
        or a
        sbc hl,de
        ld (uend),hl
        ld hl,(ucur)
        or a
        sbc hl,de
        ld (ucur),hl
        ld hl,(uend)
        ld de,UNDO
        or a
        sbc hl,de
        ld b,h
        ld c,l                  ; BC = byte da spostare
        pop hl
        ld de,UNDO
        ld a,b
        or c
        ret z
        ldir
        ret

u_hdr:                          ; record in urec -> DE = offset, BC = lunghezza
        ld hl,(urec)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ret

u_remove:                       ; elimina [offset, offset+lunghezza); il cursore resta all'inizio
        call gap_to_cur
        call u_hdr
        push de
        ld h,d
        ld l,e
        add hl,bc
        ex de,hl                ; DE = fine dell'intervallo
        call goto_ofs
        pop hl
        ld (selanc),hl
        jp sel_delete

u_restore:                      ; reinserisce i dati del record; il cursore va in fondo
        call gap_to_cur
        call u_hdr
        push bc
        call goto_ofs           ; DE = offset
        pop bc
        ld hl,(urec)
        ld de,5
        add hl,de               ; HL = dati
        jp ins_block

u_apply_inv:                    ; annulla il record in urec
        ld hl,(urec)
        ld a,(hl)
        and 7Fh
        cp 1
        jr z,u_remove
        jr u_restore

u_apply_fwd:                    ; ripete il record in urec
        ld hl,(urec)
        ld a,(hl)
        and 7Fh
        cp 1
        jr z,u_restore
        jr u_remove

u_finish:
        xor a
        ld (unolog),a
        ld (uglue),a
        ld (ukind),a
        ld a,1
        ld (modified),a
        ret

k_undo:                         ; Ctrl+Z
        ld hl,(ucur)
        ld de,UNDO
        or a
        sbc hl,de
        jr nz,.go
        ld hl,m_nundo
        ld (msgptr),hl
        ret
.go:    ld a,1
        ld (unolog),a
.loop:  ld hl,(ucur)
        dec hl
        dec hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = dimensione dell'ultimo record applicato
        ld hl,(ucur)
        or a
        sbc hl,de
        ld (urec),hl
        ld (ucur),hl
        call u_apply_inv
        ld hl,(urec)
        ld a,(hl)
        and 80h
        jp z,u_finish           ; inizio del gruppo
        ld hl,(ucur)
        ld de,UNDO
        or a
        sbc hl,de
        jr nz,.loop
        jp u_finish

k_redo:                         ; Ctrl+Y
        ld hl,(ucur)
        ld de,(uend)
        or a
        sbc hl,de
        jr c,.go
        ld hl,m_nredo
        ld (msgptr),hl
        ret
.go:    ld a,1
        ld (unolog),a
.loop:  ld hl,(ucur)
        ld (urec),hl
        call u_apply_fwd
        ld hl,(urec)
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,7
        add hl,de
        ex de,hl                ; DE = dimensione del record
        ld hl,(urec)
        add hl,de
        ld (ucur),hl
        ld de,(uend)
        or a
        sbc hl,de
        jp nc,u_finish          ; fine del registro
        ld hl,(ucur)
        ld a,(hl)
        and 80h
        jr nz,.loop             ; il prossimo e' dello stesso gruppo
        jp u_finish

m_nundo:  db "Nothing to undo",0
m_nredo:  db "Nothing to redo",0
m_nundo2: db "Edit too large to undo - history cleared",0

; ---------------------------------------------------------------- disegno
refresh:
        call ptr_hide
        ld a,(dirty)
        and 1
        jr z,.nr
        xor a                   ; il ridisegno del testo cancella il cursore disegnato
        ld (curdr),a
        call redraw_text
.nr:    ld a,1
        ld (cph),a
        xor a
        ld (blcnt),a
        ld (dirty),a
        call draw_vbar
        call draw_hbar
        call draw_title
        call cursor_show
        ld a,(menuopen)
        or a
        call nz,menu_draw
        jp ptr_show

build_row:                      ; costruisce rowbuf per la riga che inizia in (rp)
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcw1)
        ld (hl),' '
        ldir
        ld a,(reof)
        or a
        ret nz
        ld hl,(rp)              ; indirizzo fisico
        ld bc,(hscroll)
.skip:  ld a,b
        or c
        jr z,.copy
        ld a,(hl)
        or a
        jr z,.gs
        cp LF
        jr z,.nl
        inc hl
        dec bc
        jr .skip
.gs:    call gapchk
        jr nz,.skip
        jr .eof
.copy:  ld de,rowbuf
        ld a,(swm1)
        ld b,a
        ld a,(selact)
        or a
        jr nz,.cps
.cp:    ld a,(hl)
        or a
        jr z,.gc
        cp LF
        jr z,.nl
        ld (de),a
        inc de
        inc hl
        djnz .cp
.adv:   ld a,(hl)               ; scarta il resto della riga
        or a
        jr z,.ga
        cp LF
        jr z,.nl
        inc hl
        jr .adv
.gc:    call gapchk
        jr nz,.cp
        jr .eof
.cps:   ld a,(hl)               ; copia con selezione
        or a
        jr z,.gcs
        cp LF
        jr z,.lfs
        call selmark
        ld (de),a
        inc de
        inc hl
        djnz .cps
        jr .adv
.lfs:   ld a,' '                ; a-capo selezionato = spazio inverso a fine riga
        call selmark
        ld (de),a
        jr .nl
.gcs:   call gapchk
        jr nz,.cps
        jr .eof
.ga:    call gapchk
        jr nz,.adv
.eof:   ld a,1
        ld (reof),a
        ret
.nl:    inc hl
        ld (rp),hl
        ret

selmark:                        ; A = carattere, HL = puntatore fisico -> A |= 80h se selezionato
        push de
        push af
        ld de,(selps)
        ld a,h
        cp d
        jr c,.out
        jr nz,.in1
        ld a,l
        cp e
        jr c,.out
.in1:   ld de,(selpe)
        ld a,h
        cp d
        jr c,.in
        jr nz,.out
        ld a,l
        cp e
        jr nc,.out
.in:    pop af
        or 80h
        pop de
        ret
.out:   pop af
        pop de
        ret

gapchk:                         ; HL punta a un byte 0: gap (salta, NZ) oppure fine testo (Z)
        push de
        ld de,(gpa)
        ld a,l
        cp e
        jr nz,.eof
        ld a,h
        cp d
        jr nz,.eof
        ld hl,(gpb)
        pop de
        or 1
        ret
.eof:   pop de
        xor a
        ret

redraw_text:
        call sel_range
        jr c,.nosel
        push de
        call phys
        ld (selps),hl
        pop hl
        call phys
        ld (selpe),hl
        ld a,1
        jr .sdone
.nosel: xor a
.sdone: ld (selact),a
        ld hl,(gs)
        ld de,BUF
        add hl,de
        ld (gpa),hl
        ld de,(gsz)
        add hl,de
        ld (gpb),hl
        ld a,d
        or e
        jr nz,.hg
        ld hl,0FFFFh
        ld (gpa),hl
.hg:    ld hl,(top)
        call phys
        ld (rp),hl
        xor a
        ld (rrow),a
        ld (reof),a
.row:   call build_row
        ld a,(rrow)
        inc a
        ld d,a
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(swm1)
        ld b,a
        ld c,VDPD
        otir
        ld a,(rrow)
        inc a
        ld (rrow),a
        cp VROWS
        jr nz,.row
        jp kw_reset

vthumb_idx:                     ; -> A = posizione del pollice (0..TV-1)
        ld hl,(nlines)
        dec hl
        ld a,h
        or l
        jr z,.z
        ex de,hl                ; DE = nlines-1
        ld hl,(topline)
        dec hl
        ld c,TV-1
        call scale
        ld a,l
        ret
.z:     xor a
        ret

hthumb_idx:                     ; -> A = posizione del pollice (0..TH-1)
        ld hl,(hscroll)
        ld de,(hmaxw)
        ld a,(thv)
        dec a
        ld c,a
        call scale
        ld a,l
        ret

draw_vbar:
        call vthumb_idx
        add a,2
        ld (tmpb),a
        ld a,(swm1)
        ld e,a
        ld d,1
        ld a,01h
        call put_cell
        ld d,22
        ld a,02h
        call put_cell
        ld d,2
.l:     ld a,(tmpb)
        cp d
        ld a,0A0h
        jr z,.p
        ld a,05h
.p:     ld hl,swm1
        ld e,(hl)
        call put_cell
        inc d
        ld a,d
        cp 22
        jr nz,.l
        ret

draw_hbar:
        call hthumb_idx
        inc a
        ld (tmpb),a
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),05h
        ldir
        ld a,03h
        ld (rowbuf),a
        ld a,04h
        ld hl,(rbm2)
        ld (hl),a
        ld a,(tmpb)
        ld e,a
        ld d,0
        ld hl,rowbuf
        add hl,de
        ld (hl),0A0h
        ld d,23
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
        ld c,VDPD
        otir
        ret

draw_title:
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        ld a,(sw)
        cp 80
        jp nz,draw_title40
        ld hl,s_menubar
        ld de,rowbuf
        call strcpy
        ld hl,(msgptr)
        ld a,h
        or l
        jr z,.nomsg
        ld de,rowbuf+25         ; messaggio al posto di nome e stato
        call strcpy
        jr .inv
.nomsg: ld de,rowbuf+25
        ld a,(fname)
        or a
        jr nz,.hasn
        ld hl,s_untitled
        jr .nm
.hasn:  ld hl,fname
.nm:    call strcpy
        ld a,(modified)
        or a
        jr z,.stat
        ld a,'*'
        ld (de),a
.stat:  ld hl,s_ln
        ld de,rowbuf+48
        call strcpy
        ld hl,(curline)
        call dec16
        ld a,'/'
        ld (de),a
        inc de
        ld hl,(nlines)
        call dec16
        ld hl,s_col
        call strcpy
        push de
        call cur_col            ; (clobbera DE)
        inc hl
        pop de
        call dec16
.inv:   ld hl,rowbuf
        ld a,(sw)
        ld b,a
.o:     set 7,(hl)
        inc hl
        djnz .o
        ld a,(menuopen)         ; il titolo del menu aperto va in video normale
        or a
        jr z,.wr
        dec a
        add a,a
        ld d,a
        add a,a
        add a,d                 ; 6*k
        ld e,a
        ld d,0
        ld hl,rowbuf
        add hl,de
        ld b,MENUW
.na:    res 7,(hl)
        inc hl
        djnz .na
.wr:    ld d,0
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
        ld c,VDPD
        otir
        ret

draw_title40:                   ; 40 colonne: barra dei menu (30 colonne) e stato "riga:colonna" a destra;
        ld hl,(msgptr)          ; un messaggio occupa tutta la barra
        ld a,h
        or l
        jr z,.nomsg
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        ld hl,(msgptr)
        ld de,rowbuf
        call strcpy
        jp draw_title.inv
.nomsg: ld hl,s_menubar
        ld de,rowbuf
        call strcpy
        ld a,(modified)
        or a
        jr z,.st
        ld a,'*'
        ld (rowbuf+30),a
.st:    ld de,rowbuf+31
        ld hl,(curline)
        call dec16
        ld a,':'
        ld (de),a
        inc de
        push de
        call cur_col            ; (clobbera DE)
        inc hl
        pop de
        call dec16
        jp draw_title.inv

s_menubar: db " File  Edit  Find  Help  Run  ",0
s_untitled: db "(untitled)",0
s_title: db "SamPr Basic",0
s_ln:   db "Ln ",0
s_col:  db "  Col ",0

cur_blink:                      ; ogni 32 quadri: il cursore appare/scompare
        ld a,(cph)
        xor 1
        ld (cph),a
        call ptr_hide
        call cursor_show
        jp ptr_show

cursor_show:                    ; il cursore e' il glifo inverso (bit 7) della cella; (blx, bly) = cella del cursore
        ld a,(curdr)
        or a
        jr z,.nc
        ld a,(blx)
        ld e,a
        ld a,(bly)
        ld d,a
        ld a,(curch)
        call put_cell
        xor a
        ld (curdr),a
.nc:    ld a,0FFh
        ld (blx),a
        ld a,(menuopen)
        or a
        ret nz                  ; con il menu aperto il cursore non si mostra
        call cur_col
        ld de,(hscroll)
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        ld hl,swm1
        cp (hl)
        ret nc
        ld (tmpd),a             ; x
        ld hl,(curline)
        ld de,(topline)
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        cp VROWS
        ret nc
        inc a
        ld d,a
        ld a,(tmpd)
        ld e,a
        ld (blx),a
        ld a,d
        ld (bly),a
        ld a,(cph)
        or a
        ret z
        call get_cell
        ld (curch),a
        or 80h
        call put_cell
        ld a,1
        ld (curdr),a
        ret

kw_isw:                         ; A -> CF = 1 se e' 0-9 A-Z a-z _ $
        cp '$'
        jr z,.y
        cp '_'
        jr z,.y
        cp '0'
        jr c,.n
        cp '9'+1
        jr c,.y
        and 0DFh
        cp 'A'
        jr c,.n
        cp 'Z'+1
        jr c,.y
.n:     or a
        ret
.y:     scf
        ret

kw_up:                          ; A -> maiuscola (senza bit 7)
        and 7Fh
        cp 'a'
        ret c
        cp '{'
        ret nc
        sub 20h
        ret

kw_find:                        ; HL = parola, C = lunghezza (2..10) -> Z se e' una parola chiave (HL conservato)
        ld a,(hl)
        call kw_up
        cp '_'
        jr nz,.l
        ld a,26
        jr .ix
.l:     sub 'A'
        jr c,.no
        cp 26
        jr nc,.no
.ix:    ld e,a                  ; indice = iniziale * 9 + (lunghezza - 2)
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld a,c
        sub 2
        ld e,a
        add hl,de
        add hl,hl
        ld de,kwidx
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        pop ix                  ; IX = parole di quella lunghezza che iniziano con la lettera
        pop hl
.e:     ld a,(ix+0)
        or a
        jr z,.no
        push hl
        ld b,c
.c:     ld a,(hl)
        call kw_up
        cp (ix+0)
        jr nz,.mm
        inc hl
        inc ix
        djnz .c
        pop hl
        xor a
        ret
.mm:    pop hl                  ; IX dentro la voce: B caratteri (compreso questo) restano da saltare
        push bc
        ld c,b
        ld b,0
        add ix,bc
        pop bc
        jr .e
.no:    or 1
        ret

kw_mark:                        ; flag per le colonne KWCOL .. KWCOL+KWLEN-1
        ld a,(kwcol)
        ld b,a
        ld a,(kwlen)
        ld c,a
.m:     ld a,b
        rrca
        rrca
        rrca
        and 1Fh
        ld e,a
        ld d,0
        ld hl,kwf
        add hl,de
        ld a,b
        and 7
        ld e,a
        ld a,80h
        inc e
        dec e
        jr z,.nm
.sh:    srl a
        dec e
        jr nz,.sh
.nm:    or (hl)
        ld (hl),a
        inc b
        dec c
        jr nz,.m
        ret

kw_scan:                        ; ROWBUF (VCOLS caratteri) -> flag di colore delle parole chiave in KWF
        ld hl,kwf
        ld de,kwf+1
        ld (hl),0
        ld bc,9
        ldir
        ld hl,(vcolsw)
        ld de,rowbuf
        add hl,de
        ld (hl),0               ; sentinella (classe 4): la scansione non esce dalla riga
        xor a
        ld (kwq),a
        ld hl,rowbuf-1
        ld d,high kwcls
.nx:    inc hl
        ld e,(hl)
        ld a,(de)
        or a
        jr z,.nx
        cp 1
        jr z,.word
        cp 2
        jr z,.quote
        cp 3
        jr nz,.out              ; sentinella
        jr .out                 ; apostrofo: commento fino a fine riga
.quote: ld a,(kwq)
        xor 1
        ld (kwq),a
        jr .nx
.word:  ld (kwptr),hl
        ld c,0
.wl:    inc hl
        inc c
        ld e,(hl)
        ld a,(de)
        cp 1
        jr z,.wl
        dec hl                  ; HL = ultimo carattere della parola
        ld a,(kwq)
        or a
        jr nz,.nx               ; dentro una stringa: nessuna parola chiave
        ld a,c
        cp 2
        jr c,.nx                ; una sola lettera
        cp 11
        jr nc,.nx               ; troppo lunga
        push hl
        ld hl,(kwptr)
        ld a,(hl)
        and 7Fh
        cp 40h
        jr c,.nokw              ; comincia con una cifra
        call kw_find
        jr nz,.nokw
        ld a,l                  ; colonna = KWPTR - ROWBUF
        sub low rowbuf
        ld (kwcol),a
        ld a,c
        ld (kwlen),a
        call kw_mark
        ld a,(kwlen)
        cp 3
        jr nz,.nokw
        ld hl,(kwptr)           ; REM: il resto della riga e' commento
        ld a,(hl)
        call kw_up
        cp 'R'
        jr nz,.nokw
        inc hl
        ld a,(hl)
        call kw_up
        cp 'E'
        jr nz,.nokw
        inc hl
        ld a,(hl)
        call kw_up
        cp 'M'
        jr nz,.nokw
        pop hl
        jr .out
.nokw:  pop hl
        ld d,high kwcls
        jp .nx
.out:   ret

kw_put:                         ; A = riga schermo (1..22): KWF -> tabella di blink
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; riga * 10
        ld de,BLKT
        add hl,de
        call vsetw
        ld hl,kwf
        ld b,10
        ld c,VDPD
        otir
        ret

kw_reset:                       ; testo ridisegnato: i colori si azzerano e si ricalcolano nei tempi morti
        ld a,(m2flag)
        or a
        ret z                   ; MSX1: nessun colore
        ld hl,BLKT+10
        call vsetw
        ld b,220
        xor a
.z:     out (VDPD),a
        djnz .z
        ld (kwnext),a
        ret

kw_idle:                        ; nessun tasto in attesa: colora fino a 2 righe leggendole dalla VRAM
        ld a,(m2flag)
        or a
        ret z
        ld a,(menuopen)
        or a
        ret nz
        ld a,(kwnext)
        cp VROWS
        ret nc
        call kw_do1
        ld a,(kwnext)
        cp VROWS
        ret nc
kw_do1:
        ld a,(kwnext)
        inc a
        ld d,a                  ; riga schermo 1..22
        ld e,0
        push de
        call cell_addr
        call vsetr
        ld hl,rowbuf
        ld a,(swm1)
        ld b,a
        ld c,VDPD
        inir
        call kw_scan
        pop de
        ld a,d
        call kw_put
        ld hl,kwnext
        inc (hl)
        ret

; ---------------------------------------------------------------- mouse
mouse_init:
        ld hl,320
        ld (mpx),hl
        ld hl,96
        ld (mpy),hl
        xor a
        ld (mprev),a
        ld (mdrag),a
        ld (mshown),a
        ld (mactive),a
        ld a,40
        ld (mcx),a
        ld a,12
        ld (mcy),a
        ret

mouse_read:                     ; riempie rdx, rdy (con segno), rbtn (bit0 sinistro, bit1 destro)
        ld a,(mmode)
        or a
        jr nz,.test
        ld a,1
        BIOS GTTRIG
        and 1
        ld (tmpb),a
        ld a,3
        BIOS GTTRIG
        and 2
        ld hl,tmpb
        or (hl)
        ld (rbtn),a
        ld a,MPAD
        BIOS GTPAD
        ld a,MPAD+1
        BIOS GTPAD
        ld (rdx),a
        ld a,MPAD+2
        BIOS GTPAD
        ld (rdy),a
        ret
.test:  ld a,(tm_dx)
        ld (rdx),a
        ld a,(tm_dy)
        ld (rdy),a
        xor a
        ld (tm_dx),a
        ld (tm_dy),a
        ld a,(tm_btn)
        ld (rbtn),a
        ret

ptr_toggle:
        ld a,(mcy)
        ld d,a
        ld a,(mcx)
        ld e,a
        call get_cell
        xor 80h
        jp put_cell

ptr_hide:
        ld a,(mshown)
        or a
        ret z
        xor a
        ld (mshown),a
        jr ptr_toggle

ptr_show:
        ld a,(mactive)
        or a
        ret z
        ld a,(mshown)
        or a
        ret nz
        inc a
        ld (mshown),a
        jr ptr_toggle

mouse_poll:
        call mouse_read
        ld a,(rdx)
        ld b,a
        ld a,(rdy)
        or b
        ld b,a
        ld a,(rbtn)
        or b
        jr z,.noact
        ld a,1
        ld (mactive),a
.noact: ld a,(rdx)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld hl,(mpx)
        add hl,de
        ld de,(mxmax)
        call clamp
        ld (mpx),hl
        ld a,(rdy)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld hl,(mpy)
        add hl,de
        ld de,192
        call clamp
        ld (mpy),hl
        ld hl,(mpx)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld c,l                  ; cx
        ld hl,(mpy)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld b,l                  ; cy
        ld a,(mcx)
        cp c
        jr nz,.mv
        ld a,(mcy)
        cp b
        jr z,.same
.mv:    push bc
        call ptr_hide
        pop bc
        ld a,c
        ld (mcx),a
        ld a,b
        ld (mcy),a
        call ptr_show
        ld a,(menuopen)
        or a
        call nz,menu_hover
.same:  ld a,(rbtn)
        and 1
        ld b,a
        ld a,(mprev)
        ld c,a
        ld a,b
        ld (mprev),a
        ld a,c
        cpl
        and b
        jr nz,mouse_press
        ld a,b
        or a
        jp nz,mouse_hold
        xor a
        ld (mdrag),a
        ret

start_repeat:                   ; A = azione
        ld (mact),a
        ld a,3
        ld (mdrag),a
        ld a,18
        ld (mtimer),a
        ld a,(mact)
        ; prosegue in do_action

do_action:                      ; A = 1 su, 2 giu, 3 pag su, 4 pag giu, 5 sx, 6 dx, 7 pag sx, 8 pag dx
        cp 1
        jr z,.up
        cp 2
        jr z,.dn
        cp 3
        jr z,.pu
        cp 4
        jr z,.pd
        cp 5
        jr z,.lf
        cp 6
        jr z,.rt
        cp 7
        jr z,.hl
        ld hl,(vcw1)
        jr .h
.up:    ld hl,-1
        jr .v
.dn:    ld hl,1
        jr .v
.pu:    ld hl,-(VROWS-1)
        jr .v
.pd:    ld hl,VROWS-1
.v:     call scroll_v
        jp refresh
.lf:    ld hl,-1
        jr .h
.rt:    ld hl,1
        jr .h
.hl:    ld hl,(nvcw1)
.h:     call scroll_h
        jp refresh

mouse_press:
        xor a                   ; un clic chiude il gruppo di annullamento
        ld (uglue),a
        ld (ukind),a
        ld a,(menuopen)
        or a
        jp nz,menu_click
        ld a,(mcy)
        ld d,a
        ld a,(mcx)
        ld e,a
        ld a,d
        or a
        jr z,.row0
        cp 23
        jr z,.hbar
        ret nc
        ld a,e
        ld hl,swm1
        cp (hl)
        jp nz,click_text
        ld a,d
        cp 1
        ld a,1
        jp z,start_repeat
        ld a,d
        cp 22
        ld a,2
        jp z,start_repeat
        call vthumb_idx         ; (clobbera D/E: ricarico la riga del puntatore)
        add a,2
        ld b,a
        ld a,(mcy)
        ld d,a
        ld a,b
        cp d
        jr z,.vthumb
        ld a,3
        jr nc,.go
        ld a,4
.go:    jp start_repeat
.vthumb:
        ld a,1
        ld (mdrag),a
        ret
.hbar:  ld a,e
        or a
        ld a,5
        jp z,start_repeat
        ld a,e
        ld hl,swm2
        cp (hl)
        ld a,6
        jp z,start_repeat
        ld a,e
        ld hl,swm1
        cp (hl)
        ret nc
        call hthumb_idx
        inc a
        ld b,a
        ld a,(mcx)
        ld e,a
        ld a,b
        cp e
        jr z,.hthumb
        ld a,7
        jr nc,.go
        ld a,8
        jr .go
.hthumb:
        ld a,2
        ld (mdrag),a
        ret
.row0:  ld a,e                  ; clic sulla barra dei menu
        cp MENUW*NMENU
        ret nc
        ld b,0
.k0:    cp MENUW
        jr c,.k1
        sub MENUW
        inc b
        jr .k0
.k1:    ld a,b
        inc a
        ld (menuopen),a
        xor a
        ld (menusel),a
        jp refresh

mouse_hold:
        ld a,(mdrag)
        or a
        ret z
        cp 1
        jp z,drag_v
        cp 2
        jp z,drag_h
        cp 4
        jp z,drag_text
        ld hl,mtimer
        dec (hl)
        ret nz
        ld (hl),3
        ld a,(mact)
        cp 5
        jr nc,.hor
        ld a,(mcx)
        ld hl,swm1
        cp (hl)
        jr nz,.stop
        ld a,(mact)
        cp 3
        jr c,.run
        call vthumb_idx
        add a,2
        ld b,a                  ; riga del pollice
        ld a,(mcy)
        ld c,a
        ld a,(mact)
        cp 3
        jr z,.pu
        ld a,c
        cp b
        jr z,.stop
        jr c,.stop
        jr .run
.pu:    ld a,c
        cp b
        jr nc,.stop
        jr .run
.hor:   ld a,(mcy)
        cp 23
        jr nz,.stop
        ld a,(mact)
        cp 7
        jr c,.run
        call hthumb_idx
        inc a
        ld b,a                  ; colonna del pollice
        ld a,(mcx)
        ld c,a
        ld a,(mact)
        cp 7
        jr z,.hl
        ld a,c
        cp b
        jr z,.stop
        jr c,.stop
        jr .run
.hl:    ld a,c
        cp b
        jr nc,.stop
.run:   ld a,(mact)
        jp do_action
.stop:  xor a
        ld (mdrag),a
        ret

drag_v:
        ld a,(mcy)
        sub 2
        jr nc,.a
        xor a
.a:     cp TV
        jr c,.b
        ld a,TV-1
.b:     ld (tmpd),a
        ld c,a
        ld hl,(nlines)
        dec hl
        ld a,h
        or l
        ret z
        ld de,TV-1
        call scale
        inc hl
        ld de,(topline)
        push de
        call set_topline
        call vthumb_idx         ; l'arrotondamento puo' lasciare il pollice una cella indietro
        ld b,a
        ld a,(tmpd)
        cp b
        jr z,.ok
        jr c,.ok
        ld hl,(topline)
        inc hl
        call set_topline
.ok:    pop de
        ld hl,(topline)
        or a
        sbc hl,de
        ret z
        jp refresh

drag_h:
        ld a,(mcx)
        sub 1
        jr nc,.a
        xor a
.a:     ld hl,thv
        cp (hl)
        jr c,.b
        ld a,(hl)
        dec a
.b:     ld (tmpd),a
        ld c,a
        ld hl,(hmaxw)
        ld a,(thv)
        dec a
        ld e,a
        ld d,0
        call scale              ; HL = scroll candidato (arrotondato per difetto)
        ld de,(hscroll)
        ld (tmp1),de            ; valore precedente
        ld (hscroll),hl         ; provvisorio: il pollice deve cadere nella cella del puntatore
        call hthumb_idx
        ld b,a
        ld a,(tmpd)
        cp b
        jr z,.ok
        jr c,.ok
        ld hl,(hscroll)
        inc hl
        ld (hscroll),hl
.ok:    ld hl,(hscroll)
        ld de,(tmp1)
        or a
        sbc hl,de
        ret z
        call mark_text
        jp refresh

cell_to_cursor:                 ; sposta il cursore sulla cella (tgtrow, tgtcol)
        ld a,(tgtrow)
        dec a
        ld l,a
        ld h,0
        ld de,(topline)
        add hl,de
        ld de,(nlines)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        jr z,.ok
        ld hl,(nlines)
.ok:    ld (tgtline),hl
        ld a,(tgtcol)
        ld l,a
        ld h,0
        ld de,(hscroll)
        add hl,de
        ld (wantcol),hl
.dn:    ld hl,(curline)
        ld de,(tgtline)
        or a
        sbc hl,de
        jr nc,.up
        call key_down
        jr .dn
.up:    ld hl,(curline)
        ld de,(tgtline)
        or a
        sbc hl,de
        jr z,.col
        call key_up
        jr .up
.col:   ld hl,(wantcol)
        call set_col
        jp upd_wantcol


click_text:                     ; pulsante premuto nell'area di testo: sposta il cursore e inizia la selezione
        ld a,(mcy)
        ld (tgtrow),a
        ld a,(mcx)
        ld (tgtcol),a
        call key_shift
        or a
        jr z,.ns
        ld hl,(selanc)          ; Shift+clic: estende la selezione
        ld a,h
        and l
        inc a
        jr nz,.sh
        ld hl,(cur)
        ld (selanc),hl
.sh:    call cell_to_cursor
        jr .fin
.ns:    call cell_to_cursor
        ld hl,(cur)
        ld (selanc),hl          ; ancora = punto del clic (selezione vuota finche' non si trascina)
.fin:   ld a,4
        ld (mdrag),a
        ld a,3
        ld (mtimer),a
        call mark_text
        jp refresh

drag_text:                      ; pulsante tenuto premuto: la selezione segue il puntatore
        ld hl,mtimer
        dec (hl)
        jr nz,.nosc
        ld (hl),3
        ld a,(mcy)
        cp 2
        jr nc,.chk2
        ld hl,-1                ; puntatore in alto: scorre su
        call scroll_v
        jr .nosc
.chk2:  cp 22
        jr c,.nosc
        ld hl,1                 ; puntatore in basso: scorre giu'
        call scroll_v
.nosc:  ld a,(mcy)
        or a
        jr nz,.r1
        ld a,1
.r1:    cp 23
        jr c,.r2
        ld a,22
.r2:    ld (tgtrow),a
        ld a,(mcx)
        ld hl,swm1
        cp (hl)
        jr c,.c1
        ld a,(swm2)
.c1:    ld (tgtcol),a
        ld hl,(cur)
        push hl
        call cell_to_cursor
        pop de
        ld hl,(cur)
        or a
        sbc hl,de
        jr nz,.ch
        ld a,(dirty)
        or a
        ret z
.ch:    call mark_text
        jp refresh

        IFDEF COM
        INCLUDE "fileio.asm"
        ENDIF

        IFDEF DEMO
demo_text:
        INCBIN "demo.txt"
demo_end:
        ENDIF

        IFDEF COM
comend:
        ASSERT comend < BUF
        SAVEBIN "ed.com",0100h,comend-0100h
        ELSE
        ds 8000h-$,0FFh
        SAVEBIN "editor.rom",4000h,4000h
        ENDIF
