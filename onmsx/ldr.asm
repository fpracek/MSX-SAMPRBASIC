; =====================================================================
; Chain loader (MSX-DOS 1/2): lives at 0C000h, outside the low TPA that it overwrites.
;   ldr_load : loads the program ldr_fn (FCB name 8+3) at 0100h and starts it
;   ldr_copy : HL = source, BC = length -> copies to 0100h and starts
; The command line (0080h) is prepared by the caller.
; =====================================================================
LDR     equ 0C000h
        ORG LDR
ldr_load:
        jp ldr_main
ldr_fn: db "SAMPRBASCOM"
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
        jp nz,0                 ; missing file: DOS restart
        ld hl,1
        ld (ldr_fcb+14),hl      ; 1-byte record
        ld hl,0
        ld (ldr_fcb+33),hl
        ld (ldr_fcb+35),hl
        ld de,0100h
        ld c,1Ah                ; DMA
        call 5
        ld de,ldr_fcb
        ld hl,7000h
        ld c,27h                ; lettura a blocchi
        call 5
        jp 0100h
ldr_fcb: ds 37
ldr_end:
