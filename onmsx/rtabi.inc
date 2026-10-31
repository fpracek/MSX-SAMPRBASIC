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
RT_EMPTY  equ 0169h             ; byte 0 (stringa vuota)
RT_NAME   equ 016Ah             ; 16 byte: nome del sorgente (0-terminato)
RT_DSIZE  equ 017Ah             ; word: byte di dati del programma (scritta dal compilatore)
RTRAM     equ 0C100h            ; RAM del runtime (C000h-C086h: caricatore)
HEAPP     equ RTRAM+0
HEAP0     equ RTRAM+10
DATA_BASE equ 0C220h            ; variabili e array del programma
