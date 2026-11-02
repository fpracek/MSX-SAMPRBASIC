; =====================================================================
; MSX2 bitmap graphics: SCREEN 5-8 using the VDP command engine (V9938/V9958)
; Parameters in runtime RAM (see rtabi.inc): GX1 GY1 GX2 GY2 GCOL GFLG, last point LASTX/LASTY.
; Color GCOL < 0 = current color (FORCLR; PRESET uses BAKCLR). Off-screen coordinates: clipped.
; =====================================================================
CHGMOD  equ 005Fh
RG9SAV  equ 0FFE8h
VDPC    equ 99h
VDPR    equ 9Bh
GCMD    equ RTRAM+128h          ; DX DY NX NY CLR ARG CMD (11 bytes, registers R#36..R#46)
S1      equ RTRAM+134h
S2      equ RTRAM+136h
S3      equ RTRAM+138h
S4      equ RTRAM+13Ah
S5      equ RTRAM+13Ch
S6      equ RTRAM+13Eh
S7      equ RTRAM+140h
S8      equ RTRAM+142h
GHEIGHT equ 212

msg_ifc: db msg_ifc_e-msg_ifc-1,"Error: Illegal function call"
msg_ifc_e:
msg_gfx: db msg_gfx_e-msg_gfx-1,"Error: Graphics needs SCREEN 5-8"
msg_gfx_e:

rt_eifc:
        ld hl,msg_ifc
        jp rt_fatal
rt_egfx:
        ld hl,msg_gfx
        jp rt_fatal

rt_screen:                      ; HL = mode 0..8 (BIOS CHGMOD), 10..12 only on MSX2+ (V9958)
        ld a,h
        or a
        jr nz,rt_eifc
        ld a,l
        cp 13
        jr nc,rt_eifc
        ld b,a
        ld a,(M2FLAG)
        or a
        ld a,b
        jr nz,.mm               ; MSX1 (TMS9918): SCREEN 0-3 only
        cp 4
        jr nc,rt_eifc
.mm:
        cp 9
        jr c,.ok
        cp 10
        jr c,rt_eifc
        push af
        ld hl,002Dh             ; MSXVER: 2 = MSX2+, 3 = turbo R
        call rdrom
        cp 2
        jp c,rt_eifc
        pop af
.ok:    or a
        jr nz,.go
        ld b,80                 ; SCREEN 0: 80-column text (40 on MSX1)
        ld a,(M2FLAG)
        or a
        jr nz,.w0
        ld b,40
.w0:    ld a,b
        ld (LINL40),a
        ld (LINLEN),a
        xor a
.go:    ld (SCRMODE),a
        ld (SCRREAL),a
        ld hl,0                 ; pagina attiva = 0
        ld (APY),hl
        ld (APLO),hl
        ld (APHI),hl
        ld (VA16),hl
        cp 10
        jr c,.n1
        ld a,8                  ; SCREEN 10-12: like SCREEN 8, then R#25 enables YJK (V9958)
.n1:    push ix
        ld ix,CHGMOD
        call rt_bios
        pop ix
        ld a,(SCRREAL)
        cp 4
        jr nc,.nsp              ; SCREEN 4+: the BIOS CLRSPR does not return (mode 2 sprite tables)
        push ix
        ld ix,0069h             ; CLRSPR: like BASIC's SCREEN, removes the sprites left in VRAM (e.g. by the editor)
        call rt_bios
        pop ix
.nsp:
        ld a,(SCRREAL)
        cp 10
        jr c,.cm
        cp 12
        ld a,08h                ; SCREEN 12: YJK
        jr z,.y
        ld a,18h                ; SCREEN 10-11: YJK + YAE
.y:     ld (0FFFAh),a           ; RG25SAV
        di
        out (VDPC),a
        ld a,80h+25
        out (VDPC),a
        ei
.cm:    ld a,(SCRREAL)
        cp 4
        jr z,.m2
        cp 3
        jr z,.m2
        cp 10
        jr c,.nm
        ld a,8                  ; SCREEN 10-12: one byte per pixel like SCREEN 8
        ld (SCRMODE),a
        jr .nm
.m2:    ld a,2                  ; SCREEN 4 has the same layout (pattern + colors) as SCREEN 2; SCREEN 3 (multicolor) goes through plot3
        ld (SCRMODE),a
.nm:    ld a,(SCRMODE)
        cp 2
        jr z,.g
        cp 5
        jr nc,.g
        call rt_trpon           ; screens 1, 3, 4: sprites only
        ret
.g:     cp 5
        jr c,.nr9               ; SCREEN 2: 192 lines
        ld a,(RG9SAV)           ; 212 lines
        or 80h
        ld (RG9SAV),a
        di
        out (VDPC),a
        ld a,89h
        out (VDPC),a
        ei
.nr9:   ld hl,0
        ld (LASTX),hl
        ld (LASTY),hl
        call gmode_init
        call view_reset
        ld hl,(FONTPTR)         ; the font (768 bytes) is reserved only once at the top of the heap
        ld a,h
        or l
        jr nz,.hf
        ld hl,(heapend)
        ld de,-768
        add hl,de
        push hl
        ld de,(heapp)
        inc d
        inc d
        inc d
        inc d                   ; at least 1 KB of heap stays free
        or a
        sbc hl,de
        pop hl
        jr nc,.fok
        xor a                   ; without room for the font the error must be printed in text mode (in graphics the font itself would be needed)
        ld (SCRMODE),a
        push ix
        ld ix,INITXT
        call rt_bios
        pop ix
        jp rt_oom
.fok:   ld (FONTPTR),hl
        ld (heapend),hl
.hf:    call load_font
        call rt_trpon
        xor a
        ld (TCX),a
        ld (TCY),a
        inc a
        ld (CSRX),a
        ret

chk_spr:                        ; sprite: SCREEN 1-8
        ld a,(SCRMODE)
        or a
        jp z,rt_egfx
        cp 9
        jp nc,rt_egfx
        ret

gheight:                        ; -> BC = screen lines (192 in SCREEN 2, 212 in SCREEN 5-8)
        ld a,(SCRMODE)
        ld bc,212
        cp 2
        ret nz
        ld bc,192
        ret

grows:                          ; -> A = text rows in graphics (24 in SCREEN 2, 26 in SCREEN 5-8)
        ld a,(SCRMODE)
        cp 2
        ld a,26
        ret nz
        ld a,24
        ret

chk_gfx:                        ; SCREEN 2 e 5-8
        ld a,(SCRMODE)
        cp 2
        ret z
        cp 5
        jp c,rt_egfx
        cp 9
        jp nc,rt_egfx
        ret

chk_gfx_nm:                     ; like chk_gfx, but not for SCREEN 3 (PAINT, GET, PUT do not support it)
        call chk_gfx
        ld a,(SCRREAL)
        cp 3
        ret nz
        jp rt_egfx

gwidth:                         ; -> BC = screen width
        ld a,(SCRMODE)
        ld bc,256
        cp 6
        jr c,.r
        cp 8
        ret z
        ld bc,512
.r:     ret

in_range:                       ; HL = x, DE = y: C if inside the clipping window (VIEW); unsigned after subtracting the minimum
        push hl
        push de
        ld bc,(VX1)
        or a
        sbc hl,bc
        ld bc,(VXW)
        or a
        sbc hl,bc
        jr nc,.out
        ex de,hl
        ld bc,(VY1)
        or a
        sbc hl,bc
        ld bc,(VYH)
        or a
        sbc hl,bc
        jr nc,.out
        pop de
        pop hl
        scf
        ret
.out:   pop de
        pop hl
        or a
        ret

vdp_wait:                       ; waits for the command to finish (S#2 bit 0)
        di
        ld a,2
        out (VDPC),a
        ld a,8Fh
        out (VDPC),a
.l:     in a,(VDPC)
        rra
        jr c,.l
        xor a
        out (VDPC),a
        ld a,8Fh
        out (VDPC),a
        ei
        ret

vdp_cmd:                        ; executes the command described in GCMD
        call vdp_wait
        di
        ld a,36
        out (VDPC),a
        ld a,80h+17
        out (VDPC),a
        ld a,(GOP)              ; logical operator (only for the LINE/PSET/LMMV/LMMM commands)
        ld hl,GCMD+10
        or (hl)
        ld (hl),a
        ld hl,GCMD
        ld bc,0200h+VDPR        ; DX
        otir
        ld e,(hl)               ; DY + offset of the active page
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(APY)
        add hl,de
        ld a,l
        out (c),a
        ld a,h
        out (c),a
        pop hl
        ld b,7                  ; NX NY CLR ARG CMD
        otir
        ei
        ret

gcolor:                         ; A = colore effettivo
        ld hl,(GCOL)
        bit 7,h
        jr z,.c
        ld a,(FORCLR)
        ret
.c:     ld a,l
        ret

gprep:                          ; color and command argument in GCMD
        call gcolor
        ld (GCMD+8),a
        xor a
        ld (GCMD+9),a
        ret

gplot:                          ; HL = x, DE = y: clipped PSET with the color from GCMD
        call in_range
        ret nc
        ld a,(SCRMODE)
        cp 2
        jp z,plot2
        ld (GCMD),hl
        ld (GCMD+2),de
        ld a,50h
        ld (GCMD+10),a
        jp vdp_cmd

rt_gpreset:
        ld hl,(GCOL)
        bit 7,h
        jr z,rt_gpset
        ld a,(BAKCLR)
        ld l,a
        ld h,0
        ld (GCOL),hl
rt_gpset:
        call chk_gfx
        ld hl,(GX1)
        ld (LASTX),hl
        ld de,(GY1)
        ld (LASTY),de
        call gprep
        ld hl,(GX1)
        ld de,(GY1)
        jp gplot

rt_gpoint:                      ; (GX1,GY1) -> HL = color, -1 if off-screen
        call chk_gfx
        ld hl,(GX1)
        ld de,(GY1)
        call in_range
        jr c,.in
        ld hl,-1
        ret
.in:    ld a,(SCRMODE)
        cp 2
        jr nz,.v
        call getpix2
        ld l,a
        ld h,0
        ret
.v:     push hl
        push de
        call vdp_wait
        pop de
        pop hl
        di
        ld a,32
        out (VDPC),a
        ld a,80h+17
        out (VDPC),a
        push hl
        ld hl,(APY)
        add hl,de
        ex de,hl
        pop hl
        ld a,l
        out (VDPR),a
        ld a,h
        out (VDPR),a
        ld a,e
        out (VDPR),a
        ld a,d
        out (VDPR),a
        ld a,40h                ; POINT
        out (VDPC),a
        ld a,80h+46
        out (VDPC),a
        ei
        call vdp_wait
        di
        ld a,7
        out (VDPC),a
        ld a,8Fh
        out (VDPC),a
        in a,(VDPC)
        ld l,a
        ld h,0
        xor a
        out (VDPC),a
        ld a,8Fh
        out (VDPC),a
        ei
        ret

;   (sortp) HL = &a, DE = &b (words): swaps if b < a (signed)
sortp:
        push hl
        push de
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = a
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = b
        ld h,b
        ld l,c                  ; HL = a
        push bc
        push de
        call rt_cmp             ; DE = b, HL = a: C if b < a
        pop de
        pop bc
        jr nc,.n
        pop hl                  ; &b = a
        ld (hl),c
        inc hl
        ld (hl),b
        pop hl                  ; &a = b
        ld (hl),e
        inc hl
        ld (hl),d
        ret
.n:     pop hl
        pop hl
        ret

rect_draw:                      ; S1,S2,S3,S4 = x1,y1,x2,y2: fills the clipped rectangle (color in GCMD+8)
        ld hl,S1
        ld de,S3
        call sortp
        ld hl,S2
        ld de,S4
        call sortp
        ld de,(S1)              ; x1 < VX1 -> VX1
        ld hl,(VX1)
        call rt_cmp             ; C if x1 < VX1
        jr nc,.a
        ld hl,(VX1)
        ld (S1),hl
.a:     ld de,(S2)
        ld hl,(VY1)
        call rt_cmp
        jr nc,.b
        ld hl,(VY1)
        ld (S2),hl
.b:     ld de,(VX2)             ; x2 > VX2 -> VX2
        ld hl,(S3)
        call rt_cmp             ; C if VX2 < x2
        jr nc,.c
        ld hl,(VX2)
        ld (S3),hl
.c:     ld de,(VY2)
        ld hl,(S4)
        call rt_cmp
        jr nc,.d
        ld hl,(VY2)
        ld (S4),hl
.d:     ld de,(S3)              ; empty if x2 < x1 or y2 < y1
        ld hl,(S1)
        call rt_cmp
        ret c
        ld de,(S4)
        ld hl,(S2)
        call rt_cmp
        ret c
        ld a,(SCRMODE)
        cp 2
        jp z,rect_fill2
        ld hl,(S1)
        ld (GCMD),hl
        ld hl,(S2)
        ld (GCMD+2),hl
        ld hl,(S3)              ; NX = x2 - x1 + 1
        ld de,(S1)
        or a
        sbc hl,de
        inc hl
        ld (GCMD+4),hl
        ld hl,(S4)
        ld de,(S2)
        or a
        sbc hl,de
        inc hl
        ld (GCMD+6),hl
        xor a
        ld (GCMD+9),a
        ld a,80h                ; LMMV
        ld (GCMD+10),a
        jp vdp_cmd

rt_gline:                       ; (GX1,GY1)-(GX2,GY2), GFLG: 0 linea, 1 riquadro, 2 riquadro pieno
        call chk_gfx
        call gprep
        ld hl,(GX2)
        ld (LASTX),hl
        ld hl,(GY2)
        ld (LASTY),hl
        ld a,(GFLG)
        or a
        jp z,.line
        dec a
        jr z,.box
        ld hl,(GX1)             ; BF
        ld (S1),hl
        ld hl,(GY1)
        ld (S2),hl
        ld hl,(GX2)
        ld (S3),hl
        ld hl,(GY2)
        ld (S4),hl
        jp rect_draw
.box:   ld hl,(GX1)             ; box: four thin sides (rect_draw modifies S1..S4: they are reloaded)
        ld (S1),hl
        ld hl,(GX2)
        ld (S3),hl
        ld hl,(GY1)             ; alto
        ld (S2),hl
        ld (S4),hl
        call rect_draw
        ld hl,(GX1)
        ld (S1),hl
        ld hl,(GX2)
        ld (S3),hl
        ld hl,(GY2)             ; basso
        ld (S2),hl
        ld (S4),hl
        call rect_draw
        ld hl,(GX1)             ; sinistra
        ld (S1),hl
        ld (S3),hl
        ld hl,(GY1)
        ld (S2),hl
        ld hl,(GY2)
        ld (S4),hl
        call rect_draw
        ld hl,(GX2)             ; destra
        ld (S1),hl
        ld (S3),hl
        ld hl,(GY1)
        ld (S2),hl
        ld hl,(GY2)
        ld (S4),hl
        jp rect_draw
.line:  ld a,(SCRMODE)
        cp 2
        jp z,.soft              ; SCREEN 2: no command engine
        ld hl,(GX1)
        ld de,(GY1)
        call in_range
        jr nc,.soft
        ld hl,(GX2)
        ld de,(GY2)
        call in_range
        jr nc,.soft
        ld c,0                  ; hardware LINE command
        ld hl,(GX2)
        ld de,(GX1)
        or a
        sbc hl,de
        bit 7,h
        jr z,.dxp
        ld c,4                  ; DIX: verso sinistra
        call rt_neghl
.dxp:   ld (S1),hl              ; |dx|
        ld hl,(GY2)
        ld de,(GY1)
        or a
        sbc hl,de
        bit 7,h
        jr z,.dyp
        set 3,c                 ; DIY: verso l'alto
        call rt_neghl
.dyp:   ld (S2),hl              ; |dy|
        ld de,(S1)
        or a
        sbc hl,de               ; |dy| - |dx|
        jr c,.xmaj
        jr z,.xmaj
        set 0,c                 ; asse lungo = Y
        ld hl,(S2)
        ld (GCMD+4),hl          ; NX = lato lungo (|dy|)
        ld hl,(S1)
        ld (GCMD+6),hl
        jr .go
.xmaj:  ld hl,(S1)
        ld (GCMD+4),hl
        ld hl,(S2)
        ld (GCMD+6),hl
.go:    ld hl,(GX1)
        ld (GCMD),hl
        ld hl,(GY1)
        ld (GCMD+2),hl
        ld a,c
        ld (GCMD+9),a
        ld a,70h                ; LINE
        ld (GCMD+10),a
        jp vdp_cmd
.soft:  ld hl,(GX1)             ; Bresenham with point-by-point clipping
        ld (S1),hl
        ld hl,(GY1)
        ld (S2),hl
        ld hl,(GX2)
        ld de,(GX1)
        or a
        sbc hl,de
        ld bc,1
        bit 7,h
        jr z,.a1
        ld bc,-1
        call rt_neghl
.a1:    ld (S3),hl              ; dx = |x2-x1|
        ld (S5),bc              ; sx
        ld hl,(GY2)
        ld de,(GY1)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.neg
        ld bc,1
        call rt_neghl
        jr .a2
.neg:   ld bc,-1
.a2:    ld (S4),hl              ; dy = -|y2-y1|
        ld (S6),bc              ; sy
        ld hl,(S3)
        ld de,(S4)
        add hl,de
        ld (S7),hl              ; err = dx + dy
.l:     ld hl,(S1)
        ld de,(S2)
        call gplot
        ld hl,(S1)
        ld de,(GX2)
        or a
        sbc hl,de
        jr nz,.cont
        ld hl,(S2)
        ld de,(GY2)
        or a
        sbc hl,de
        ret z
.cont:  ld hl,(S7)
        add hl,hl
        ld (S8),hl              ; e2 = 2*err
        ld de,(S8)
        ld hl,(S4)
        call rt_cmp             ; C if e2 < dy
        jr c,.skx
        ld hl,(S7)
        ld de,(S4)
        add hl,de
        ld (S7),hl
        ld hl,(S1)
        ld de,(S5)
        add hl,de
        ld (S1),hl
.skx:   ld de,(S3)
        ld hl,(S8)
        call rt_cmp             ; C if dx < e2
        jr c,.sky
        ld hl,(S7)
        ld de,(S3)
        add hl,de
        ld (S7),hl
        ld hl,(S2)
        ld de,(S6)
        add hl,de
        ld (S2),hl
.sky:   jr .l

pl:                             ; BC = x offset, DE = y offset from the center (GX1,GY1)
        ld hl,(GX1)
        add hl,bc
        push hl
        ld hl,(GY1)
        add hl,de
        ex de,hl
        pop hl
        jp gplot

rt_gcircle:                     ; centro (GX1,GY1), raggio GX2 (GFLG = 1: arco/ellisse)
        call chk_gfx
        call gprep
        ld a,(GFLG)
        or a
        jp nz,circ_arc
        ld hl,(GX1)
        ld (LASTX),hl
        ld hl,(GY1)
        ld (LASTY),hl
        ld hl,(GX2)
        bit 7,h
        ret nz
        ld (S1),hl              ; x = r
        ld hl,0
        ld (S2),hl              ; y = 0
        ld hl,(S1)
        ex de,hl
        ld hl,1
        or a
        sbc hl,de
        ld (S3),hl              ; d = 1 - r
.l:     ld de,(S1)
        ld hl,(S2)
        call rt_cmp             ; C if x < y: done
        ret c
        ld hl,(S1)
        call rt_neghl
        ld (S4),hl              ; -x
        ld hl,(S2)
        call rt_neghl
        ld (S5),hl              ; -y
        ld bc,(S1)
        ld de,(S2)
        call pl
        ld bc,(S2)
        ld de,(S1)
        call pl
        ld bc,(S4)
        ld de,(S2)
        call pl
        ld bc,(S5)
        ld de,(S1)
        call pl
        ld bc,(S1)
        ld de,(S5)
        call pl
        ld bc,(S2)
        ld de,(S4)
        call pl
        ld bc,(S4)
        ld de,(S5)
        call pl
        ld bc,(S5)
        ld de,(S4)
        call pl
        ld hl,(S2)              ; y++
        inc hl
        ld (S2),hl
        ld hl,(S3)
        bit 7,h
        jr z,.dec
        ld de,(S2)              ; d < 0: d += 2y + 1
        add hl,de
        add hl,de
        inc hl
        ld (S3),hl
        jp .l
.dec:   ld hl,(S1)              ; otherwise x--, d += 2(y - x) + 1
        dec hl
        ld (S1),hl
        ex de,hl
        ld hl,(S2)
        or a
        sbc hl,de
        add hl,hl
        inc hl
        ld de,(S3)
        add hl,de
        ld (S3),hl
        jp .l

; ---------------------------------------------------------------- SCREEN 2 (MSX1 graphics: 8x1 patterns with color per group)
pix_addr2:                      ; HL = x, DE = y -> (P2OFF) = offset into the tables, (P2MSK) = bit mask
        ld a,e
        rrca
        rrca
        rrca
        and 1Fh
        ld b,a                  ; y >> 3 (high byte)
        ld a,e
        and 7
        ld c,a
        ld a,l
        and 0F8h
        or c
        ld c,a                  ; (x & F8) | (y & 7)
        ld a,l
        and 7
        ld e,a
        ld (P2OFF),bc
        ld a,80h
        inc e
.m:     dec e
        jr z,.d
        srl a
        jr .m
.d:     ld (P2MSK),a
        ret

plot2:                          ; HL = x, DE = y (inside the screen): point with the color from GCMD+8
        ld a,(SCRREAL)
        cp 3
        jp z,plot3
        call pix_addr2
        ld hl,(P2OFF)
        ld bc,(GRPCOL)
        add hl,bc
        push hl
        xor a
        call vram_set
        in a,(VDPD)
        ld b,a                  ; B = color byte (foreground | background)
        pop hl
        ld a,(GCMD+8)
        and 0Fh
        ld c,a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        cp c
        jr z,.setb              ; color = foreground: sets the bit
        ld a,b
        and 0Fh
        cp c
        jr z,.clrb              ; color = background: clears the bit
        ld a,c                  ; new color: becomes the foreground of the group
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        ld d,a
        ld a,b
        and 0Fh
        or d
        ld b,a
        ld a,40h
        call vram_set
        ld a,b
        out (VDPD),a
.setb:  ld hl,(P2OFF)
        ld bc,(GRPCGP)
        add hl,bc
        push hl
        xor a
        call vram_set
        in a,(VDPD)
        ld b,a
        pop hl
        ld a,(P2MSK)
        or b
        ld b,a
        ld a,40h
        call vram_set
        ld a,b
        out (VDPD),a
        ret
.clrb:  ld hl,(P2OFF)
        ld bc,(GRPCGP)
        add hl,bc
        push hl
        xor a
        call vram_set
        in a,(VDPD)
        ld b,a
        pop hl
        ld a,(P2MSK)
        cpl
        and b
        ld b,a
        ld a,40h
        call vram_set
        ld a,b
        out (VDPD),a
        ret

getpix2:                        ; HL = x, DE = y -> A = pixel color
        ld a,(SCRREAL)
        cp 3
        jp z,getpix3
        call pix_addr2
        ld hl,(P2OFF)
        ld bc,(GRPCGP)
        add hl,bc
        xor a
        call vram_set
        in a,(VDPD)
        ld b,a
        ld a,(P2MSK)
        and b
        ld d,a                  ; D != 0 if the bit is set
        ld hl,(P2OFF)
        ld bc,(GRPCOL)
        add hl,bc
        xor a
        call vram_set
        in a,(VDPD)
        ld b,a
        ld a,d
        or a
        ld a,b
        jr z,.bg
        rrca
        rrca
        rrca
        rrca
.bg:    and 0Fh
        ret

pix_addr3:                      ; SCREEN 3: HL = x, DE = y -> HL = generator byte, C bit 2 = 0 if high nibble (left pixel)
        ld a,l
        and 4
        ld c,a
        ld a,e
        rrca
        rrca
        rrca
        rrca
        rrca
        and 7
        ld h,a
        ld a,e
        rrca
        rrca
        and 7
        ld b,a
        ld a,l
        and 0F8h
        or b
        ld l,a
        ld de,(0F3D5h)          ; MLTCGP: multicolor pattern generator
        add hl,de
        ret

plot3:                          ; SCREEN 3: 4x4 block with the color from GCMD+8
        call pix_addr3
        push bc
        push hl
        xor a
        call vram_set
        in a,(VDPD)
        ld b,a
        pop hl
        pop de                  ; E = C (bit 2 = nibble)
        ld a,(GCMD+8)
        and 0Fh
        ld c,a
        bit 2,e
        jr z,.hi
        ld a,b
        and 0F0h
        or c
        jr .w
.hi:    ld a,c
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,b
        and 0Fh
        or c
.w:     ld b,a
        ld a,40h
        call vram_set
        ld a,b
        out (VDPD),a
        ret

getpix3:                        ; SCREEN 3: HL = x, DE = y -> A = colore
        call pix_addr3
        push bc
        xor a
        call vram_set
        in a,(VDPD)
        pop bc
        bit 2,c
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo:    and 0Fh
        ret

rect_fill2:                     ; S1..S4 = rectangle (sorted, clipped): point by point
        ld hl,(S2)
        ld (S8),hl
.row:   ld hl,(S1)
        ld (PX),hl
.px:    ld hl,(PX)
        ld de,(S8)
        call plot2
        ld hl,(PX)
        ld de,(S3)
        or a
        sbc hl,de
        jr z,.nr
        ld hl,(PX)
        inc hl
        ld (PX),hl
        jr .px
.nr:    ld hl,(S8)
        ld de,(S4)
        or a
        sbc hl,de
        ret z
        ld hl,(S8)
        inc hl
        ld (S8),hl
        jr .row

; ---------------------------------------------------------------- VIEW
view_reset:                     ; clipping window = full screen
        ld hl,0
        ld (VX1),hl
        ld (VY1),hl
        call gwidth
        ld (VXW),bc
        dec bc
        ld (VX2),bc
        call gheight
        ld (VYH),bc
        dec bc
        ld (VY2),bc
        ret

rt_viewr:
        call chk_gfx
        jr view_reset

rt_view:                        ; VIEW (GX1,GY1)-(GX2,GY2): sets the window (clipped to the screen)
        call chk_gfx
        call view_reset         ; (sorting and clipping are done against the whole screen)
        ld hl,(GX1)
        ld (S1),hl
        ld hl,(GY1)
        ld (S2),hl
        ld hl,(GX2)
        ld (S3),hl
        ld hl,(GY2)
        ld (S4),hl
        ld hl,S1
        ld de,S3
        call sortp
        ld hl,S2
        ld de,S4
        call sortp
        ld hl,(S1)
        ld de,(S2)
        call in_range
        jp nc,rt_eifc
        ld hl,(S3)
        ld de,(S4)
        call in_range
        jp nc,rt_eifc
        ld hl,(S1)
        ld (VX1),hl
        ld hl,(S2)
        ld (VY1),hl
        ld hl,(S3)
        ld (VX2),hl
        ld hl,(S4)
        ld (VY2),hl
        ld hl,(S3)
        ld de,(S1)
        or a
        sbc hl,de
        inc hl
        ld (VXW),hl
        ld hl,(S4)
        ld de,(S2)
        or a
        sbc hl,de
        inc hl
        ld (VYH),hl
        ret
