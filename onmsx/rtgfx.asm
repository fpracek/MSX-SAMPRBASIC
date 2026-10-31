; =====================================================================
; Grafica bitmap MSX2: SCREEN 5-8 con il motore comandi del VDP (V9938/V9958)
; Parametri nella RAM del runtime (vedi rtabi.inc): GX1 GY1 GX2 GY2 GCOL GFLG, ultimo punto LASTX/LASTY.
; Colore GCOL < 0 = colore corrente (FORCLR; PRESET usa BAKCLR). Coordinate fuori schermo: ritagliate.
; =====================================================================
CHGMOD  equ 005Fh
RG9SAV  equ 0FFE8h
VDPC    equ 99h
VDPR    equ 9Bh
GCMD    equ RTRAM+128h          ; DX DY NX NY CLR ARG CMD (11 byte, registri R#36..R#46)
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

rt_screen:                      ; HL = modo 0..8 (CHGMOD del BIOS), 10..12 solo su MSX2+ (V9958)
        ld a,h
        or a
        jr nz,rt_eifc
        ld a,l
        cp 13
        jr nc,rt_eifc
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
        ld a,80                 ; SCREEN 0: testo a 80 colonne
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
        push ix
        ld ix,CHGMOD
        call rt_bios
        pop ix
        ld a,(SCRREAL)
        cp 4
        jr z,.m2
        cp 3
        jr z,.m2
        cp 10
        jr c,.nm
        ld a,8                  ; SCREEN 10-12: un byte per pixel come lo SCREEN 8
        ld (SCRMODE),a
        jr .nm
.m2:    ld a,2                  ; SCREEN 4 ha lo stesso layout (pattern + colori) dello SCREEN 2; SCREEN 3 (multicolore) passa da plot3
        ld (SCRMODE),a
.nm:    ld a,(SCRMODE)
        cp 2
        jr z,.g
        cp 5
        jr nc,.g
        call rt_trpon           ; schermi 1, 3, 4: solo gli sprite
        ret
.g:     cp 5
        jr c,.nr9               ; SCREEN 2: 192 righe
        ld a,(RG9SAV)           ; 212 righe
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
        ld hl,(FONTPTR)         ; il font (768 byte) si riserva una volta sola in cima allo heap
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
        inc d                   ; almeno 1 KB di heap resta libero
        or a
        sbc hl,de
        pop hl
        jp c,rt_oom
        ld (FONTPTR),hl
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

gheight:                        ; -> BC = righe dello schermo (192 in SCREEN 2, 212 in SCREEN 5-8)
        ld a,(SCRMODE)
        ld bc,212
        cp 2
        ret nz
        ld bc,192
        ret

grows:                          ; -> A = righe di testo in grafica (24 in SCREEN 2, 26 in SCREEN 5-8)
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

chk_gfx_nm:                     ; come chk_gfx, ma non per lo SCREEN 3 (PAINT, GET, PUT non lo supportano)
        call chk_gfx
        ld a,(SCRREAL)
        cp 3
        ret nz
        jp rt_egfx

gwidth:                         ; -> BC = larghezza dello schermo
        ld a,(SCRMODE)
        ld bc,256
        cp 6
        jr c,.r
        cp 8
        ret z
        ld bc,512
.r:     ret

in_range:                       ; HL = x, DE = y: C se dentro la finestra di ritaglio (VIEW); senza segno dopo la sottrazione del minimo
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

vdp_wait:                       ; attende la fine del comando (S#2 bit 0)
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

vdp_cmd:                        ; esegue il comando descritto in GCMD
        call vdp_wait
        di
        ld a,36
        out (VDPC),a
        ld a,80h+17
        out (VDPC),a
        ld a,(GOP)              ; operatore logico (solo per i comandi LINE/PSET/LMMV/LMMM)
        ld hl,GCMD+10
        or (hl)
        ld (hl),a
        ld hl,GCMD
        ld bc,0200h+VDPR        ; DX
        otir
        ld e,(hl)               ; DY + scostamento della pagina attiva
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

gprep:                          ; colore e argomento del comando in GCMD
        call gcolor
        ld (GCMD+8),a
        xor a
        ld (GCMD+9),a
        ret

gplot:                          ; HL = x, DE = y: PSET ritagliato con il colore di GCMD
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

rt_gpoint:                      ; (GX1,GY1) -> HL = colore, -1 fuori dallo schermo
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

;   (sortp) HL = &a, DE = &b (parole): scambia se b < a (con segno)
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
        call rt_cmp             ; DE = b, HL = a: C se b < a
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

rect_draw:                      ; S1,S2,S3,S4 = x1,y1,x2,y2: riempie il rettangolo ritagliato (colore in GCMD+8)
        ld hl,S1
        ld de,S3
        call sortp
        ld hl,S2
        ld de,S4
        call sortp
        ld de,(S1)              ; x1 < VX1 -> VX1
        ld hl,(VX1)
        call rt_cmp             ; C se x1 < VX1
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
        call rt_cmp             ; C se VX2 < x2
        jr nc,.c
        ld hl,(VX2)
        ld (S3),hl
.c:     ld de,(VY2)
        ld hl,(S4)
        call rt_cmp
        jr nc,.d
        ld hl,(VY2)
        ld (S4),hl
.d:     ld de,(S3)              ; vuoto se x2 < x1 oppure y2 < y1
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
.box:   ld hl,(GX1)             ; riquadro: quattro lati sottili (rect_draw modifica S1..S4: si ricaricano)
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
        jp z,.soft              ; SCREEN 2: niente motore dei comandi
        ld hl,(GX1)
        ld de,(GY1)
        call in_range
        jr nc,.soft
        ld hl,(GX2)
        ld de,(GY2)
        call in_range
        jr nc,.soft
        ld c,0                  ; comando LINE hardware
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
.soft:  ld hl,(GX1)             ; Bresenham con ritaglio punto per punto
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
        call rt_cmp             ; C se e2 < dy
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
        call rt_cmp             ; C se dx < e2
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

pl:                             ; BC = scostamento x, DE = scostamento y dal centro (GX1,GY1)
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
        call rt_cmp             ; C se x < y: fine
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
.dec:   ld hl,(S1)              ; altrimenti x--, d += 2(y - x) + 1
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

; ---------------------------------------------------------------- SCREEN 2 (grafica MSX1: pattern 8x1 con colore per gruppo)
pix_addr2:                      ; HL = x, DE = y -> (P2OFF) = scostamento nelle tabelle, (P2MSK) = maschera del bit
        ld a,e
        rrca
        rrca
        rrca
        and 1Fh
        ld b,a                  ; y >> 3 (byte alto)
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

plot2:                          ; HL = x, DE = y (dentro lo schermo): punto con il colore di GCMD+8
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
        ld b,a                  ; B = byte dei colori (primo piano | sfondo)
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
        jr z,.setb              ; colore = primo piano: accende il bit
        ld a,b
        and 0Fh
        cp c
        jr z,.clrb              ; colore = sfondo: spegne il bit
        ld a,c                  ; colore nuovo: diventa il primo piano del gruppo
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

getpix2:                        ; HL = x, DE = y -> A = colore del pixel
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
        ld d,a                  ; D != 0 se il bit e' acceso
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

pix_addr3:                      ; SCREEN 3: HL = x, DE = y -> HL = byte del generatore, C bit 2 = 0 se nibble alto (pixel a sinistra)
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
        ld de,(0F3D5h)          ; MLTCGP: generatore dei pattern del multicolore
        add hl,de
        ret

plot3:                          ; SCREEN 3: blocco 4x4 con il colore di GCMD+8
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

rect_fill2:                     ; S1..S4 = rettangolo (ordinato, ritagliato): punto per punto
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
view_reset:                     ; finestra di ritaglio = schermo intero
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

rt_view:                        ; VIEW (GX1,GY1)-(GX2,GY2): imposta la finestra (ritagliata allo schermo)
        call chk_gfx
        call view_reset         ; (l'ordinamento e il ritaglio si fanno sull'intero schermo)
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
