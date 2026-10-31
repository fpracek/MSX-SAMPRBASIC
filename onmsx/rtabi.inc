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
RT_EMPTY  equ 0199h             ; byte 0 (stringa vuota)
RT_NAME   equ 019Ah             ; 16 byte: nome del sorgente (0-terminato)
RT_DSIZE  equ 01AAh             ; word: byte di dati del programma (scritta dal compilatore)
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
DATA_BASE equ 0C280h
