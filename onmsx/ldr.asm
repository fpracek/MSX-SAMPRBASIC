; =====================================================================
; Caricatore a catena (MSX-DOS 1/2): vive a 0C000h, fuori dalla TPA bassa che sovrascrive.
;   ldr_load : carica il programma ldr_fn (nome FCB 8+3) a 0100h e lo avvia
;   ldr_copy : HL = sorgente, BC = lunghezza -> copia a 0100h e avvia
; La riga di comando (0080h) e' preparata dal chiamante.
; =====================================================================
LDR     equ 0C000h
        ORG LDR
ldr_load:
        jp ldr_main
ldr_fn: db "QB      COM"
ldr_copy:
        ld de,0100h
        ldir
        jp 0100h
ldr_main: ld hl,ldr_fn
        ld de,ldr_fcb+1
        ld bc,11
        ldir
        xor a
        ld (ldr_fcb),a
        ld hl,ldr_fcb+12
        ld de,ldr_fcb+13
        ld bc,24
        ld (hl),a
        ldir
        ld de,ldr_fcb
        ld c,0Fh                ; open
        call 5
        or a
        jp nz,0                 ; file mancante: riavvio del DOS
        ld hl,1
        ld (ldr_fcb+14),hl      ; record da 1 byte
        ld hl,0
        ld (ldr_fcb+33),hl
        ld (ldr_fcb+35),hl
        ld de,0100h
        ld c,1Ah                ; DMA
        call 5
        ld de,ldr_fcb
        ld hl,0B000h
        ld c,27h                ; lettura a blocchi
        call 5
        jp 0100h
ldr_fcb: ds 37
ldr_end:
