; =====================================================================
; Text in graphics (SCREEN 5-8), PALETTE and PAINT
; The font is copied from the BIOS ROM (RDSLT) into RAM: 96 8x8 glyphs (ASCII 32-127). Cells are 8x8 pixels
; (32 columns x 26 rows in screens 5 and 8, 64 x 26 in 6 and 7); glyphs are written directly to VRAM
; with opaque background (BAKCLR) and foreground FORCLR.
; =====================================================================
RDSLT   equ 000Ch
VDPD    equ 98h

rdrom:                          ; HL = address in the main ROM -> A (preserves HL, DE, BC)
        push hl
        push de
        push bc
        ld a,(EXPTBL)
        call RDSLT
        ei
        pop bc
        pop de
        pop hl
        ret

load_font:                      ; ASCII 32-127 from the BIOS table (pointer at 0004h)
        ld hl,4
        call rdrom
        ld c,a
        ld hl,5
        call rdrom
        ld h,a
        ld l,c
        ld de,32*8
        add hl,de
        ld de,(FONTPTR)
        ld bc,768
.l:     call rdrom
        ld (de),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

gmode_init:                     ; bits per pixel, pixels per byte, color mask, based on SCRMODE
        ld a,(SCRMODE)
        cp 2
        jr z,.m2
        cp 6
        jr z,.m6
        cp 8
        jr z,.m8
        ld a,4
        ld (GBPP),a
        ld a,2
        ld (GPPB),a
        ld a,0Fh
        ld (GONES),a
        ret
.m2:    ld a,8                  ; SCREEN 2: lines read as one byte per pixel (color)
        ld (GBPP),a
        ld a,1
        ld (GPPB),a
        ld a,0Fh
        ld (GONES),a
        ret
.m6:    ld a,2
        ld (GBPP),a
        ld a,4
        ld (GPPB),a
        ld a,3
        ld (GONES),a
        ret
.m8:    ld a,8
        ld (GBPP),a
        ld a,1
        ld (GPPB),a
        ld a,0FFh
        ld (GONES),a
        ret

gcols:                          ; -> A = text columns
        ld a,(SCRMODE)
        cp 6
        jr z,.w
        cp 7
        jr z,.w
        ld a,32
        ret
.w:     ld a,64
        ret

gstride:                        ; -> A = bytes per pixel line: 128, or 0 = 256
        ld a,(SCRMODE)
        cp 5
        jr z,.s
        cp 6
        jr z,.s
        xor a
        ret
.s:     ld a,128
        ret

gputc:                          ; A = carattere (modo grafico): disegna o interpreta i controlli
        cp 13
        jr z,.cr
        cp 10
        jr z,.lf
        cp 8
        jr z,.left
        cp 1Dh
        jr z,.left
        cp 32
        ret c
        call gdraw
        ld a,(TCX)
        inc a
        ld (TCX),a
        ld b,a
        call gcols
        cp b
        jr z,.nl
        jr c,.nl
        jr .csr
.nl:    xor a
        ld (TCX),a
.lf:    ld a,(TCY)
        inc a
        ld (TCY),a
        ld b,a
        call grows
        cp b
        jr z,.sc
        jr c,.sc
        jr .csr
.sc:    call grows
        dec a
        ld (TCY),a
        call gscroll
        jr .csr
.cr:    xor a
        ld (TCX),a
        jr .csr
.left:  ld a,(TCX)
        or a
        jr z,.csr
        dec a
        ld (TCX),a
.csr:   ld a,(TCX)
        inc a
        ld (CSRX),a
        ret

gpack:                          ; A = color -> A = color replicated across a VRAM byte
        ld b,a
        ld a,(GBPP)
        cp 8
        jr nz,.n
        ld a,b
        ret
.n:     cp 4
        jr z,.four
        ld a,b                  ; 2 bits per pixel
        and 3
        ld b,a
        add a,a
        add a,a
        or b
        ld b,a
.four:  ld a,b
        and 0Fh
        ld b,a
        rlca
        rlca
        rlca
        rlca
        or b
        ret

gdraw:                          ; A = character 32..: draws the glyph in cell (TCX,TCY)
        sub 32
        ret c
        cp 96
        jr c,.ok
        xor a
.ok:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(FONTPTR)
        add hl,de
        push hl                 ; pointer to the glyph
        ld a,(SCRMODE)
        cp 2
        jp z,gdraw2
        ld a,(FORCLR)
        call gpack
        ld (GFGP),a
        ld a,(BAKCLR)
        call gpack
        ld (GBGP),a
        ld a,(TCY)              ; address = TCY*8*stride + TCX*bytes-per-cell
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; pixel line
        call gstride
        or a
        ld h,l                  ; * 256
        ld l,0
        jr z,.col
        srl h                   ; * 128
        rr l
.col:   ld a,(TCX)
        ld e,a
        ld d,0
        ld a,(GPPB)
        ld b,2                  ; bytes per cell 4 (log2 = 2)
        cp 2
        jr z,.sh
        ld b,1                  ; 2 bytes
        cp 4
        jr z,.sh
        ld b,3                  ; 8 bytes
.sh:    sla e
        rl d
        djnz .sh
        add hl,de
        ld de,(APLO)            ; pagina attiva
        add hl,de
        pop de                  ; DE = glifo
        ld b,8                  ; 8 lines
.row:   push bc
        push de
        push hl
        ld a,40h
        call vram_set
        pop hl
        pop de
        ld a,(de)
        inc de
        push de
        push hl
        call gline
        pop hl
        call gstride
        ld e,a
        ld d,0
        or a
        jr nz,.st
        ld d,1
.st:    add hl,de
        pop de
        pop bc
        djnz .row
        ret

vram_set:                       ; HL = VRAM address (16 bit + VA16 = A16), A = 0 read / 40h write
        ld c,a
        ld a,(M2FLAG)
        or a
        jr nz,.m2
        di                      ; MSX1: 16 KB VRAM, the TMS9918 has no R#14 (number 14 would overwrite R#6)
        ld a,l
        out (VDPC),a
        ld a,h
        and 3Fh
        or c
        out (VDPC),a
        ei
        ret
.m2:
        push de
        ld a,(VA16)
        add a,a
        add a,a
        ld d,a
        ld a,h
        rlca
        rlca
        and 3
        or d
        pop de
        di
        out (VDPC),a
        ld a,8Eh                ; R#14
        out (VDPC),a
        ld a,l
        out (VDPC),a
        ld a,h
        and 3Fh
        or c
        out (VDPC),a
        ei
        ret

gline:                          ; A = glyph line (bit 7 = left pixel): writes 8 pixels to the data port
        ld b,a
        ld a,(GPPB)
        ld e,a                  ; E = pixels per VRAM byte
        ld d,8                  ; D = pixel rimasti
.byte:  ld l,0                  ; L = VRAM byte mask
        ld h,e                  ; H = pixels still to put in the byte
.px:    ld a,(GBPP)
        ld c,a
.sh:    sla l                   ; mask <<= bits per pixel
        dec c
        jr nz,.sh
        ld a,b
        add a,a
        ld b,a
        jr nc,.nb
        ld a,(GONES)
        or l
        ld l,a
.nb:    dec d
        dec h
        jr nz,.px
        ld a,(GFGP)             ; byte = (fg & m) | (bg & ~m)
        and l
        ld c,a
        ld a,l
        cpl
        ld l,a
        ld a,(GBGP)
        and l
        or c
        out (VDPD),a
        ld a,d
        or a
        jr nz,.byte
        ret

vdp_setsrc:                     ; HL = SX, DE = SY (registers R#32-35), SY relative to the active page
        push hl
        ld hl,(APY)
        add hl,de
        ex de,hl
        pop hl
vdp_setsrc_raw:                 ; as above, SY absolute
        di
        ld a,32
        out (VDPC),a
        ld a,80h+17
        out (VDPC),a
        ld a,l
        out (VDPR),a
        ld a,h
        out (VDPR),a
        ld a,e
        out (VDPR),a
        ld a,d
        out (VDPR),a
        ei
        ret

gscroll:                        ; scrolls the screen by one text line (8 pixels)
        ld a,(SCRMODE)
        cp 2
        jp z,gscroll2
        call vdp_wait
        ld hl,0
        ld de,8
        call vdp_setsrc
        ld hl,0
        ld (GCMD),hl
        ld (GCMD+2),hl
        call gwidth
        ld (GCMD+4),bc
        ld hl,200
        ld (GCMD+6),hl
        xor a
        ld (GCMD+8),a
        ld (GCMD+9),a
        ld a,0D0h               ; HMMM
        ld (GCMD+10),a
        call vdp_cmd
        ld a,(BAKCLR)           ; last text line -> background
        ld b,a
        ld a,(GONES)
        and b
        ld (GCMD+8),a
        ld hl,0
        ld (GCMD),hl
        ld hl,200
        ld (GCMD+2),hl
        call gwidth
        ld (GCMD+4),bc
        ld hl,8
        ld (GCMD+6),hl
        xor a
        ld (GCMD+9),a
        ld a,80h                ; LMMV
        ld (GCMD+10),a
        jp vdp_cmd

; ---------------------------------------------------------------- PALETTE
paltab: db 00h,00h,00h,00h,11h,06h,33h,07h,17h,01h,27h,03h,51h,01h,27h,06h
        db 71h,01h,73h,03h,61h,06h,64h,06h,11h,04h,65h,02h,55h,05h,77h,07

rt_palinit:                     ; tavolozza predefinita dell'MSX2
        di
        xor a
        out (VDPC),a
        ld a,90h
        out (VDPC),a
        ld hl,paltab
        ld bc,2000h+9Ah         ; 32 bytes to the palette data port
        otir
        ei
        ret

rt_palette:                     ; GX1 = number (0-15), GY1 = red, GX2 = green, GY2 = blue (0-7)
        ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 16
        jp nc,rt_eifc
        ld c,a
        ld hl,(GY1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 8
        jp nc,rt_eifc
        rlca
        rlca
        rlca
        rlca
        ld d,a
        ld hl,(GY2)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 8
        jp nc,rt_eifc
        or d
        ld d,a
        ld hl,(GX2)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 8
        jp nc,rt_eifc
        ld e,a
        di
        ld a,c
        out (VDPC),a
        ld a,90h
        out (VDPC),a
        ld a,d
        out (9Ah),a
        ld a,e
        out (9Ah),a
        ei
        ret

; ---------------------------------------------------------------- PAINT
ppush:                          ; HL = x, DE = y: seed onto the stack (at the end of the free area); if full, discards it
        ld (PTX),hl
        ld (PTY),de
        ld hl,(PSTK)
        ld bc,-4
        add hl,bc
        ld de,(PLIM)
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ld (PSTK),hl
        ld de,(PTX)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(PTY)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

ppop:                           ; -> HL = x, DE = y
        ld hl,(PSTK)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (PSTK),hl
        pop hl
        ret

rowread:                        ; HL = y: reads the pixel line into ROWBUF
        ld a,(SCRMODE)
        cp 2
        jp z,rowread2
        push hl
        call vdp_wait
        pop hl
        call gstride
        or a
        ld a,l
        ld h,a                  ; y * 256
        ld l,0
        ld b,0                  ; 256 bytes
        jr z,.rd
        srl h                   ; y * 128
        rr l
        ld b,128
.rd:    ld de,(APLO)
        add hl,de
        push bc
        xor a
        call vram_set
        pop bc
        ld hl,(ROWPTR)
        ld c,VDPD
        inir
        ret

rb_pix:                         ; HL = x -> A = pixel from the line in ROWBUF
        ld a,(GBPP)
        cp 8
        jr z,.m8
        cp 2
        jr z,.m2
        ld a,l                  ; 4 bits per pixel
        and 1
        ld c,a
        srl h
        rr l
        ld de,(ROWPTR)
        add hl,de
        ld a,(hl)
        bit 0,c
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo:    and 0Fh
        ret
.m2:    ld a,l
        and 3
        ld c,a
        srl h
        rr l
        srl h
        rr l
        ld de,(ROWPTR)
        add hl,de
        ld a,3
        sub c
        add a,a
        ld b,a
        ld a,(hl)
        inc b
.s2:    dec b
        jr z,.d2
        rrca
        jr .s2
.d2:    and 3
        ret
.m8:    ld de,(ROWPTR)
        add hl,de
        ld a,(hl)
        ret

rb_ok:                          ; HL = x: C if the pixel can be filled (neither border nor already the fill color)
        push hl
        call rb_pix
        pop hl
        ld b,a
        ld a,(PBRD)
        cp b
        jr z,.no
        ld a,(PCOL)
        cp b
        jr z,.no
        scf
        ret
.no:    or a
        ret

scanrow:                        ; HL = y: seeds for each fillable run of that line within [PXL, PXR]
        ld (PSY),hl
        call rowread
        xor a
        ld (PRUN),a
        ld hl,(PXL)
        ld (PX),hl
.l:     ld hl,(PX)
        call rb_ok
        jr nc,.out
        ld a,(PRUN)
        or a
        jr nz,.nx
        ld a,1
        ld (PRUN),a
        ld hl,(PX)
        ld de,(PSY)
        call ppush
        jr .nx
.out:   xor a
        ld (PRUN),a
.nx:    ld hl,(PX)
        ld de,(PXR)
        or a
        sbc hl,de
        ret z
        ld hl,(PX)
        inc hl
        ld (PX),hl
        jr .l

rt_paint:                       ; PAINT (GX1,GY1), color GCOL, border GX2 (< 0 = same as the fill color)
        call chk_gfx_nm
        call gcolor
        ld b,a
        ld a,(GONES)
        and b
        ld (PCOL),a
        ld hl,(GX2)
        ld a,(PCOL)
        bit 7,h
        jr nz,.bs
        ld a,l
        ld b,a
        ld a,(GONES)
        and b
.bs:    ld (PBRD),a
        ld hl,(GX1)
        ld de,(GY1)
        call in_range
        ret nc
        ld a,(PCOL)
        ld (GCMD+8),a
        xor a
        ld (GCMD+9),a
        ld hl,(heapend)         ; pixel line and seed stack at the top of the heap's free area
        ld de,-256
        add hl,de
        ld (ROWPTR),hl
        ld (PSTK),hl
        ld hl,(heapp)
        ld de,32
        add hl,de
        ld (PLIM),hl
        ld hl,(GX1)
        ld de,(GY1)
        call ppush
.loop:  ld hl,(PSTK)
        ld de,(ROWPTR)
        or a
        sbc hl,de
        ret z
        call ppop
        ld (PXS),hl
        ld (PY),de
        ld hl,(PY)
        call rowread
        ld hl,(PXS)
        call rb_ok
        jr nc,.loop
        ld hl,(PXS)             ; estremo sinistro
        ld (PXL),hl
.lf:    ld hl,(PXL)
        ld de,(VX1)
        or a
        sbc hl,de
        jr z,.lr
        ld hl,(PXL)
        dec hl
        call rb_ok
        jr nc,.lr
        ld hl,(PXL)
        dec hl
        ld (PXL),hl
        jr .lf
.lr:    ld hl,(PXS)             ; estremo destro
        ld (PXR),hl
.rf:    ld bc,(VX2)
        ld hl,(PXR)
        or a
        sbc hl,bc
        jr nc,.fill
        ld hl,(PXR)
        inc hl
        call rb_ok
        jr nc,.fill
        ld hl,(PXR)
        inc hl
        ld (PXR),hl
        jr .rf
.fill:  ld hl,(PXL)             ; fills the run
        ld (S1),hl
        ld hl,(PY)
        ld (S2),hl
        ld (S4),hl
        ld hl,(PXR)
        ld (S3),hl
        call rect_draw
        ld hl,(PY)              ; seeds above and below (inside the window)
        ld de,(VY1)
        or a
        sbc hl,de
        jr z,.dn
        ld hl,(PY)
        dec hl
        call scanrow
.dn:    ld hl,(PY)
        inc hl
        push hl
        ld de,(VY2)
        or a
        sbc hl,de
        pop hl
        jr z,.dnok
        jp nc,.loop
.dnok:  call scanrow
        jp .loop

; ---------------------------------------------------------------- SCREEN 2: text, scrolling, reading a line
gdraw2:                         ; (SP) = glyph: writes pattern and colors into cell (TCX,TCY)
        pop de
        ld a,(TCY)
        ld h,a
        ld l,0
        ld a,(TCX)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld b,0
        add hl,bc               ; offset = TCY*256 + TCX*8
        push hl
        ld bc,(GRPCGP)
        add hl,bc
        ld a,40h
        call vram_set
        ld b,8
.p:     ld a,(de)
        out (VDPD),a
        inc de
        djnz .p
        pop hl
        ld bc,(GRPCOL)
        add hl,bc
        ld a,40h
        call vram_set
        ld a,(FORCLR)
        and 0Fh
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld a,(BAKCLR)
        and 0Fh
        or b
        ld b,8
.c:     out (VDPD),a
        djnz .c
        ret

gscroll2:                       ; SCREEN 2: scrolls the pattern and color tables by one line
        call ensure_rowbuf
        ld hl,(GRPCGP)
        ld (S1),hl
        call scr2tbl
        ld hl,(GRPCOL)
        ld (S1),hl
        call scr2tbl
        ld hl,(GRPCGP)          ; last line: empty patterns
        ld de,23*256
        add hl,de
        ld a,40h
        call vram_set
        ld b,0
        xor a
.z:     out (VDPD),a
        djnz .z
        ld hl,(GRPCOL)          ; colors = current foreground / background
        ld de,23*256
        add hl,de
        ld a,40h
        call vram_set
        ld a,(FORCLR)
        and 0Fh
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld a,(BAKCLR)
        and 0Fh
        or b
        ld b,0
.c:     out (VDPD),a
        djnz .c
        ret

scr2tbl:                        ; (S1) = table base: copies 23 lines of 256 bytes upward
        ld a,23
        ld (S2),a
.l:     ld hl,(S1)
        inc h
        xor a
        call vram_set
        ld hl,(ROWPTR)
        ld c,VDPD
        ld b,0
        inir
        ld hl,(S1)
        ld a,40h
        call vram_set
        ld hl,(ROWPTR)
        ld c,VDPD
        ld b,0
        otir
        ld hl,(S1)
        inc h
        ld (S1),hl
        ld hl,S2
        dec (hl)
        jr nz,.l
        ret

rowread2:                       ; SCREEN 2, HL = y: ROWBUF[x] = color of pixel (x, y)
        ld (S1),hl
        ld hl,(ROWPTR)
        ld (S2),hl
        ld hl,0
        ld (S3),hl
.l:     ld hl,(S3)
        ld de,(S1)
        call getpix2
        ld hl,(S2)
        ld (hl),a
        inc hl
        ld (S2),hl
        ld hl,(S3)
        inc hl
        ld (S3),hl
        ld a,h
        or a
        jr z,.l
        ret
