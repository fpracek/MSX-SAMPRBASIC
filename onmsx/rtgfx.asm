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

rt_screen:                      ; HL = modo 0..8 (CHGMOD del BIOS)
        ld a,h
        or a
        jr nz,rt_eifc
        ld a,l
        cp 9
        jr nc,rt_eifc
        or a
        jr nz,.go
        ld a,80                 ; SCREEN 0: testo a 80 colonne
        ld (LINL40),a
        ld (LINLEN),a
        xor a
.go:    ld (SCRMODE),a
        push ix
        ld ix,CHGMOD
        call rt_bios
        pop ix
        ld a,(SCRMODE)
        cp 5
        ret c
        ld a,(RG9SAV)           ; 212 righe
        or 80h
        ld (RG9SAV),a
        di
        out (VDPC),a
        ld a,89h
        out (VDPC),a
        ei
        ld hl,0
        ld (LASTX),hl
        ld (LASTY),hl
        call gmode_init
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

chk_gfx:                        ; solo SCREEN 5-8
        ld a,(SCRMODE)
        cp 5
        jp c,rt_egfx
        cp 9
        jp nc,rt_egfx
        ret

gwidth:                         ; -> BC = larghezza dello schermo
        ld a,(SCRMODE)
        ld bc,256
        cp 6
        jr c,.r
        cp 8
        ret z
        ld bc,512
.r:     ret

in_range:                       ; HL = x, DE = y: C se dentro lo schermo (confronto senza segno: i negativi sono fuori)
        push hl
        push de
        call gwidth
        or a
        sbc hl,bc
        jr nc,.out
        ex de,hl
        ld bc,GHEIGHT
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
        ld hl,GCMD
        ld bc,0B00h+VDPR        ; B = 11 byte, C = porta dei registri indiretti
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
.in:    push hl
        push de
        call vdp_wait
        pop de
        pop hl
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
        ld hl,(S1)              ; x1 < 0 -> 0
        bit 7,h
        jr z,.a
        ld hl,0
        ld (S1),hl
.a:     ld hl,(S2)
        bit 7,h
        jr z,.b
        ld hl,0
        ld (S2),hl
.b:     call gwidth
        dec bc                  ; massimo x
        ld de,(S3)              ; x2 > max -> max (con segno)
        ld h,b
        ld l,c
        push bc
        call rt_cmp             ; DE = x2, HL = max: C se x2 < max
        pop bc
        jr c,.c
        ld (S3),bc
.c:     ld bc,GHEIGHT-1
        ld de,(S4)
        ld h,b
        ld l,c
        push bc
        call rt_cmp
        pop bc
        jr c,.d
        ld (S4),bc
.d:     ld de,(S3)              ; vuoto se x2 < x1 oppure y2 < y1
        ld hl,(S1)
        call rt_cmp
        ret c
        ld de,(S4)
        ld hl,(S2)
        call rt_cmp
        ret c
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
.line:  ld hl,(GX1)
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

rt_gcircle:                     ; centro (GX1,GY1), raggio GX2
        call chk_gfx
        call gprep
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
