        IFNDEF RTB
        IFDEF ROMMODE
RTB       equ 4100h
        ELSE
RTB       equ 0100h
        ENDIF
        ENDIF
; Punti d'ingresso del runtime (tabella di JP a indirizzi fissi, immagine a 0100h)
RT_PSTR   equ RTB+(0103h-0100h)
RT_PINT   equ RTB+(0106h-0100h)
RT_PNL    equ RTB+(0109h-0100h)
RT_ZONE   equ RTB+(010Ch-0100h)
RT_CLS    equ RTB+(010Fh-0100h)
RT_LOCATE equ RTB+(0112h-0100h)
RT_MUL    equ RTB+(0115h-0100h)
RT_DIV    equ RTB+(0118h-0100h)
RT_MOD    equ RTB+(011Bh-0100h)
RT_CMP    equ RTB+(011Eh-0100h)
RT_BEQ    equ RTB+(0121h-0100h)
RT_BNE    equ RTB+(0124h-0100h)
RT_BLT    equ RTB+(0127h-0100h)
RT_BGT    equ RTB+(012Ah-0100h)
RT_BLE    equ RTB+(012Dh-0100h)
RT_BGE    equ RTB+(0130h-0100h)
RT_END    equ RTB+(0133h-0100h)
RT_NEG    equ RTB+(0136h-0100h)
RT_CHK    equ RTB+(0139h-0100h)
RT_RND    equ RTB+(013Ch-0100h)
RT_SCOPY  equ RTB+(013Fh-0100h)
RT_SCAT   equ RTB+(0142h-0100h)
RT_SCMP   equ RTB+(0145h-0100h)
RT_LEFT   equ RTB+(0148h-0100h)
RT_RIGHT  equ RTB+(014Bh-0100h)
RT_MID    equ RTB+(014Eh-0100h)
RT_LEN    equ RTB+(0151h-0100h)
RT_ASC    equ RTB+(0154h-0100h)
RT_CHR    equ RTB+(0157h-0100h)
RT_STR    equ RTB+(015Ah-0100h)
RT_VAL    equ RTB+(015Dh-0100h)
RT_INKEY  equ RTB+(0160h-0100h)
RT_INPUT  equ RTB+(0163h-0100h)
RT_SDUP   equ RTB+(0166h-0100h)
RT_COLOR  equ RTB+(0169h-0100h)
RT_WAIT   equ RTB+(016Ch-0100h)
RT_VPEEK  equ RTB+(016Fh-0100h)
RT_VPOKE  equ RTB+(0172h-0100h)
RT_SCREEN equ RTB+(0175h-0100h)
RT_GPSET  equ RTB+(0178h-0100h)
RT_GPRESET equ RTB+(017Bh-0100h)
RT_GPOINT equ RTB+(017Eh-0100h)
RT_GLINE  equ RTB+(0181h-0100h)
RT_GCIRCLE equ RTB+(0184h-0100h)
RT_PALETTE equ RTB+(0187h-0100h)
RT_PALINIT equ RTB+(018Ah-0100h)
RT_PAINT  equ RTB+(018Dh-0100h)
RT_SPRDEF equ RTB+(0190h-0100h)
RT_SPRPUT equ RTB+(0193h-0100h)
RT_SPRSIZE equ RTB+(0196h-0100h)
RT_GGET   equ RTB+(0199h-0100h)
RT_GPUT   equ RTB+(019Ch-0100h)
RT_DRAW   equ RTB+(019Fh-0100h)
RT_COLL   equ RTB+(01A2h-0100h)
RT_VIEW   equ RTB+(01A5h-0100h)
RT_VIEWR  equ RTB+(01A8h-0100h)
RT_WX     equ RTB+(01ABh-0100h)
RT_WY     equ RTB+(01AEh-0100h)
RT_WR     equ RTB+(01B1h-0100h)
RT_WINDOW equ RTB+(01B4h-0100h)
RT_WINRES equ RTB+(01B7h-0100h)
RT_VBANK  equ RTB+(01BAh-0100h)
RT_VFILL  equ RTB+(01BDh-0100h)
RT_VWRITE equ RTB+(01C0h-0100h)
RT_VREAD  equ RTB+(01C3h-0100h)
RT_BASE   equ RTB+(01C6h-0100h)
RT_VDP    equ RTB+(01C9h-0100h)
RT_VDPSET equ RTB+(01CCh-0100h)
RT_STICK  equ RTB+(01CFh-0100h)
RT_STRIG  equ RTB+(01D2h-0100h)
RT_SPRCOL equ RTB+(01D5h-0100h)
RT_SPRCOLS equ RTB+(01D8h-0100h)
RT_COPY   equ RTB+(01DBh-0100h)
RT_SETPAGE equ RTB+(01DEh-0100h)
RT_SCROLL equ RTB+(01E1h-0100h)
RT_READ   equ RTB+(01E4h-0100h)
RT_RESTORE equ RTB+(01E7h-0100h)
RT_BEEP   equ RTB+(01EAh-0100h)
RT_SOUND  equ RTB+(01EDh-0100h)
RT_PLAY   equ RTB+(01F0h-0100h)
RT_OPEN   equ RTB+(01F3h-0100h)
RT_CLOSE  equ RTB+(01F6h-0100h)
RT_OUTSEL equ RTB+(01F9h-0100h)
RT_FINPUT equ RTB+(01FCh-0100h)
RT_FLINE  equ RTB+(01FFh-0100h)
RT_FEOF   equ RTB+(0202h-0100h)
RT_KILL   equ RTB+(0205h-0100h)
RT_WINT   equ RTB+(0208h-0100h)
RT_WSTR   equ RTB+(020Bh-0100h)
RT_FARCALL equ RTB+(020Eh-0100h)
RT_SETBANK equ RTB+(0211h-0100h)
RT_DATAWIN equ RTB+(0214h-0100h)
RT_VCOPY  equ RTB+(0217h-0100h)
RT_MAPSEGS equ RTB+(021Ah-0100h)
RT_MGET   equ RTB+(021Dh-0100h)
RT_MPUT   equ RTB+(0220h-0100h)
RT_MREAD  equ RTB+(0223h-0100h)
RT_MWRITE equ RTB+(0226h-0100h)
RT_MALLOC equ RTB+(0229h-0100h)
RT_MFREE  equ RTB+(022Ch-0100h)
RT_MDIM   equ RTB+(022Fh-0100h)
RT_MAGET  equ RTB+(0232h-0100h)
RT_MAPUT  equ RTB+(0235h-0100h)
RT_BLOAD  equ RTB+(0238h-0100h)
RT_BSAVE  equ RTB+(023Bh-0100h)
RT_FIELD  equ RTB+(023Eh-0100h)
RT_FGET   equ RTB+(0241h-0100h)
RT_FPUT   equ RTB+(0244h-0100h)
RT_FLOF   equ RTB+(0247h-0100h)
RT_MKI    equ RTB+(024Ah-0100h)
RT_CVI    equ RTB+(024Dh-0100h)
RT_RSET   equ RTB+(0250h-0100h)
RT_EMPTY  equ RTB+(0253h-0100h)             ; byte 0 (stringa vuota)
RT_NAME   equ RTB+(0254h-0100h)             ; 16 byte: nome del sorgente (0-terminato)
RT_DSIZE  equ RTB+(0264h-0100h)             ; word: byte di dati del programma (scritta dal compilatore)
RT_DATA0  equ RTB+(0266h-0100h)             ; word: primo elemento DATA (0 = nessun DATA)
RT_TARGET equ RTB+(0268h-0100h)             ; byte: tipo di cartuccia (1 ROM16, 2 ROM32, 3 ASCII8, 4 ASCII16, 5 KONAMI, 6 SCC)
RT_DBG    equ RT_TARGET+1       ; jp rt_dbg: gancio del debugger (OPTION DEBUG)
RT_STAMP  equ RT_DBG+5          ; 20 byte: data, ora e variante della costruzione (il compilatore .COM li confronta)
RT_STAMPLEN equ 20
RT_SIZE   equ RT_DBG+3          ; word: dimensione dell'immagine del runtime (letta dal compilatore .COM senza leggere tutto il file)
RTRAM     equ 0C090h            ; RAM del runtime (C000h-C086h: caricatore)
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
PLV       equ RTRAM+1CCh        ; PLAY: stringhe delle 3 voci
PVOICE    equ RTRAM+1D2h        ; PLAY: stato delle voci (3 x 12 byte)
PHZ       equ RTRAM+1F6h        ; PLAY: frequenza di quadro * 240
PTEMPO    equ RTRAM+1F8h
PANY      equ RTRAM+1FAh
FILEP     equ RTRAM+1FBh        ; descrittori dei file (0 = non ancora riservati)
OUTSEL    equ RTRAM+1FDh        ; file di PRINT# (0 = schermo)
FARSP     equ RTRAM+1FEh        ; ROM: pila software delle chiamate fra segmenti
CURBANK   equ RTRAM+200h        ; ROM: banco nella finestra di codice
CWREG     equ RTRAM+201h        ; ROM: registro di banco della finestra di codice
DWREG     equ RTRAM+203h        ; ROM: registro di banco della finestra dati (A000h per i banchi da 8 KB)
MSAVE     equ RTRAM+205h        ; mapper: segmento della pagina 2 da ripristinare
MAPN      equ RTRAM+206h        ; numero di segmenti (word), valido se MAPK <> 0
MAPK      equ RTRAM+208h
MT0       equ RTRAM+209h        ; scratch del rilevamento
MTN       equ RTRAM+20Ah
MTB       equ RTRAM+20Bh
MJT       equ RTRAM+20Ch        ; tabella delle routine del mapper (DOS 2)
MALN      equ RTRAM+20Eh        ; segmenti presi dall'alto (senza DOS 2)
RAMSL     equ RTRAM+20Fh        ; ROM: slot della RAM (pagina 3 = mapper)
DBGP      equ RTRAM+210h        ; debugger: blocco di stato (in cima all'heap), 0 = non ancora creato
M2FLAG    equ RTRAM+214h        ; 0 = MSX1 (TMS9918: niente R#14, niente 80 colonne), altrimenti MSX2 o superiore
DBGT      equ RTRAM+212h        ; debugger: tabella delle variabili (scritta dal programma)
DATA_BASE equ 0C2B0h
