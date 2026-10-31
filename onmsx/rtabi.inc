; Punti d'ingresso del runtime (tabella di JP a indirizzi fissi, immagine a 0100h)
RT_PSTR   equ 0103h
RT_PINT   equ 0106h
RT_PNL    equ 0109h
RT_ZONE   equ 010Ch
RT_CLS    equ 010Fh
RT_LOCATE equ 0112h
RT_MUL    equ 0115h
RT_DIV    equ 0118h
RT_MOD    equ 011Bh
RT_CMP    equ 011Eh
RT_BEQ    equ 0121h
RT_BNE    equ 0124h
RT_BLT    equ 0127h
RT_BGT    equ 012Ah
RT_BLE    equ 012Dh
RT_BGE    equ 0130h
RT_END    equ 0133h
RT_NEG    equ 0136h
RT_CHK    equ 0139h
RT_RND    equ 013Ch
RT_SCOPY  equ 013Fh
RT_SCAT   equ 0142h
RT_SCMP   equ 0145h
RT_LEFT   equ 0148h
RT_RIGHT  equ 014Bh
RT_MID    equ 014Eh
RT_LEN    equ 0151h
RT_ASC    equ 0154h
RT_CHR    equ 0157h
RT_STR    equ 015Ah
RT_VAL    equ 015Dh
RT_INKEY  equ 0160h
RT_INPUT  equ 0163h
RT_SDUP   equ 0166h
RT_COLOR  equ 0169h
RT_WAIT   equ 016Ch
RT_VPEEK  equ 016Fh
RT_VPOKE  equ 0172h
RT_SCREEN equ 0175h
RT_GPSET  equ 0178h
RT_GPRESET equ 017Bh
RT_GPOINT equ 017Eh
RT_GLINE  equ 0181h
RT_GCIRCLE equ 0184h
RT_PALETTE equ 0187h
RT_PALINIT equ 018Ah
RT_PAINT  equ 018Dh
RT_SPRDEF equ 0190h
RT_SPRPUT equ 0193h
RT_SPRSIZE equ 0196h
RT_GGET   equ 0199h
RT_GPUT   equ 019Ch
RT_DRAW   equ 019Fh
RT_COLL   equ 01A2h
RT_VIEW   equ 01A5h
RT_VIEWR  equ 01A8h
RT_WX     equ 01ABh
RT_WY     equ 01AEh
RT_WR     equ 01B1h
RT_WINDOW equ 01B4h
RT_WINRES equ 01B7h
RT_VBANK  equ 01BAh
RT_VFILL  equ 01BDh
RT_VWRITE equ 01C0h
RT_VREAD  equ 01C3h
RT_BASE   equ 01C6h
RT_VDP    equ 01C9h
RT_VDPSET equ 01CCh
RT_STICK  equ 01CFh
RT_STRIG  equ 01D2h
RT_SPRCOL equ 01D5h
RT_SPRCOLS equ 01D8h
RT_COPY   equ 01DBh
RT_SETPAGE equ 01DEh
RT_SCROLL equ 01E1h
RT_READ   equ 01E4h
RT_RESTORE equ 01E7h
RT_LOGOP  equ 01EAh
RT_EMPTY  equ 01EDh             ; byte 0 (stringa vuota)
RT_NAME   equ 01EEh             ; 16 byte: nome del sorgente (0-terminato)
RT_DSIZE  equ 01FEh             ; word: byte di dati del programma (scritta dal compilatore)
RT_DATA0  equ 0200h             ; word: primo elemento DATA (0 = nessun DATA)
RTRAM     equ 0C100h            ; RAM del runtime (C000h-C086h: caricatore)
HEAPP     equ RTRAM+0
HEAP0     equ RTRAM+10
GX1       equ RTRAM+118h        ; parametri grafici (word)
GY1       equ RTRAM+11Ah
GX2       equ RTRAM+11Ch
GY2       equ RTRAM+11Eh
GCOL      equ RTRAM+120h        ; colore (< 0 = colore corrente)
GFLG      equ RTRAM+122h        ; byte: 0 linea, 1 riquadro, 2 riquadro pieno
SCRMODE   equ RTRAM+123h        ; byte: modo SCREEN corrente
LASTX     equ RTRAM+124h        ; ultimo punto grafico
LASTY     equ RTRAM+126h
FONTPTR   equ RTRAM+150h        ; puntatore al font 8x8 (768 byte in cima allo heap, riservato da SCREEN 5-8)
ROWPTR    equ RTRAM+152h        ; puntatore alla riga di pixel di PAINT (256 byte in cima allo heap)
TCX       equ RTRAM+154h        ; cursore di testo in grafica (colonna, riga)
TCY       equ RTRAM+155h
GBPP      equ RTRAM+156h        ; bit per pixel, pixel per byte, maschera del colore
GPPB      equ RTRAM+157h
GONES     equ RTRAM+158h
GFGP      equ RTRAM+159h        ; colori replicati in un byte di VRAM
GBGP      equ RTRAM+15Ah
PCOL      equ RTRAM+15Bh        ; PAINT: colore, bordo, tratto in corso
PBRD      equ RTRAM+15Ch
PRUN      equ RTRAM+15Dh
PSTK      equ RTRAM+15Eh        ; PAINT: pila dei semi e variabili
PLIM      equ RTRAM+160h
PXS       equ RTRAM+162h
PY        equ RTRAM+164h
PXL       equ RTRAM+166h
PXR       equ RTRAM+168h
PX        equ RTRAM+16Ah
PSY       equ RTRAM+16Ch
PTX       equ RTRAM+16Eh
PTY       equ RTRAM+170h
ARRB      equ RTRAM+172h        ; array di GET/PUT: base e numero di elementi
ARRC      equ RTRAM+174h
CCX       equ RTRAM+176h        ; CIRCLE ad arco/ellisse: centro, ultimo punto
CCY       equ RTRAM+178h
CPX       equ RTRAM+17Ah
CPY       equ RTRAM+17Ch
DCOL      equ RTRAM+17Eh        ; DRAW: colore, scala, prefissi B e N, lunghezza e puntatore
DSC       equ RTRAM+17Fh
DB        equ RTRAM+180h
DN        equ RTRAM+181h
DLEN      equ RTRAM+182h
DPOS      equ RTRAM+183h
CRX       equ RTRAM+185h        ; CIRCLE: raggi, angolo corrente, gradi rimasti, primo punto
CRY       equ RTRAM+187h
CANG      equ RTRAM+189h
CK        equ RTRAM+18Bh
CFIRST    equ RTRAM+18Dh
CEND      equ ARRB              ; CIRCLE: angolo finale (gradi) e aspetto (percentuale) riusano ARRB/ARRC
CASP      equ ARRC
GRPCOL    equ 0F3C9h            ; tabelle del BIOS (colori e pattern dello schermo 2, sprite degli schermi 1-3)
GRPCGP    equ 0F3CBh
GRPATR    equ 0F3CDh
GRPPAT    equ 0F3CFh
T32ATR    equ 0F3C3h
T32PAT    equ 0F3C5h
MLTATR    equ 0F3D7h
MLTPAT    equ 0F3D9h
P2OFF     equ RTRAM+18Eh        ; SCREEN 2: scostamento e maschera del pixel (non usare S1..S8: servono ai chiamanti)
P2MSK     equ RTRAM+190h
VX1       equ RTRAM+192h        ; VIEW: finestra di ritaglio (limiti inclusi) e sue dimensioni
VY1       equ RTRAM+194h
VX2       equ RTRAM+196h
VY2       equ RTRAM+198h
VXW       equ RTRAM+19Ah
VYH       equ RTRAM+19Ch
SCRREAL   equ RTRAM+19Eh        ; numero dello SCREEN richiesto (SCRMODE vale 2 anche per lo SCREEN 4: stesso layout)
WACT      equ RTRAM+19Fh        ; WINDOW: attivo, asse y verso l'alto, origine logica, estensioni, fattori
WYUP      equ RTRAM+1A0h
WWX1      equ RTRAM+1A1h
WWY1      equ RTRAM+1A3h
WDX       equ RTRAM+1A5h
WDY       equ RTRAM+1A7h
WMX       equ RTRAM+1A9h
WMY       equ RTRAM+1ABh
W4        equ RTRAM+1ADh        ; accumulatore a 32 bit
WMU       equ RTRAM+1B1h
WDV       equ RTRAM+1B3h
WREM      equ RTRAM+1B5h
WCNT      equ RTRAM+1B7h
WSG       equ RTRAM+1B8h
UBANK     equ RTRAM+1B9h        ; VBANK: 64 KB della VRAM usati da VPOKE/VPEEK/VFILL/VWRITE/VREAD
VA16      equ RTRAM+1BAh        ; A16 usato da vram_set
APAGE     equ RTRAM+1BBh        ; pagina attiva (SET PAGE)
GOP       equ RTRAM+1BCh        ; operatore logico dei comandi VDP
DPTR      equ RTRAM+1BDh        ; puntatore DATA/READ
APY       equ RTRAM+1BFh        ; pagina attiva: scostamento Y (pagina*256) per i comandi VDP
APLO      equ RTRAM+1C1h        ; ... scostamento dell'indirizzo VRAM (16 bit bassi)
APHI      equ RTRAM+1C3h        ; ... A16 dell'indirizzo VRAM
CSP       equ RTRAM+1C4h        ; COPY: pagina sorgente, destinazione (x,y), pagina destinazione (-1 = attiva)
CDX       equ RTRAM+1C6h
CDY       equ RTRAM+1C8h
CDP       equ RTRAM+1CAh
DATA_BASE equ 0C2E0h
