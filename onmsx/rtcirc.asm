; =====================================================================
; CIRCLE ad arco o ellisse: CIRCLE (x,y), r[, colore[, inizio[, fine[, aspetto]]]]
; Angoli in GRADI (0 = destra, antiorario), aspetto in PERCENTUALE (100 = cerchio, 50 = ellisse bassa).
; Poligonale con un segmento per grado, tracciata con rt_gline (ritagliata).
; =====================================================================
sintab:
        dw 0,4,9,13,18,22,27,31,36,40
        dw 44,49,53,58,62,66,71,75,79,83
        dw 88,92,96,100,104,108,112,116,120,124
        dw 128,132,136,139,143,147,150,154,158,161
        dw 165,168,171,175,178,181,184,187,190,193
        dw 196,199,202,204,207,210,212,215,217,219
        dw 222,224,226,228,230,232,234,236,237,239
        dw 241,242,243,245,246,247,248,249,250,251
        dw 252,253,254,254,255,255,255,256,256,256
        dw 256

sin256:                         ; HL = angolo in gradi -> HL = seno * 256 (con segno)
.neg:   bit 7,h
        jr z,.pos
        ld de,360
        add hl,de
        jr .neg
.pos:   ld de,360
        or a
        sbc hl,de
        jr nc,.pos
        add hl,de               ; 0..359
        ld de,180
        or a
        sbc hl,de
        jr c,.first
        call sinq               ; 180..359: -sin(a - 180)
        jp rt_neghl
.first: add hl,de               ; 0..179
sinq:   ld a,l                  ; 0..179 -> sin (91..179 si specchiano su 89..1)
        cp 91
        jr c,.ok
        ld a,180
        sub l
.ok:    ld l,a
        ld h,0
        add hl,hl
        ld de,sintab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

smul:                           ; HL = valore con segno (seno*256), DE = raggio >= 0 -> HL = valore*raggio/256 (arrotondato)
        ld a,h
        push af
        bit 7,h
        call nz,rt_neghl
        call rt_mul
        ld de,128
        add hl,de
        ld l,h
        ld h,0
        pop af
        bit 7,a
        ret z
        jp rt_neghl

circ_arc:
        ld hl,(GX2)             ; raggio
        bit 7,h
        ret nz
        ld (CRX),hl
        ld de,(CASP)            ; raggio verticale = r * aspetto / 100
        call rt_mul
        ld de,100
        call rt_div
        ld (CRY),hl
        ld hl,(GX1)
        ld (CCX),hl
        ld hl,(GY1)
        ld (CCY),hl
        ld hl,(GY2)             ; angolo iniziale
        ld (CANG),hl
        ld de,(CEND)            ; gradi da percorrere = fine - inizio (+ 360 se <= 0)
        ex de,hl
        or a
        sbc hl,de
        bit 7,h
        jr nz,.add
        ld a,h
        or l
        jr nz,.cnt
.add:   ld de,360
        add hl,de
.cnt:   ld (CK),hl
        ld a,1
        ld (CFIRST),a
.l:     ld hl,(CANG)            ; x = cx + r * cos(a)
        ld de,90
        add hl,de
        call sin256
        ld de,(CRX)
        call smul
        ld de,(CCX)
        add hl,de
        ld (GX2),hl
        ld hl,(CANG)            ; y = cy - ry * sin(a)
        call sin256
        ld de,(CRY)
        call smul
        ex de,hl
        ld hl,(CCY)
        or a
        sbc hl,de
        ld (GY2),hl
        ld a,(CFIRST)
        or a
        jr z,.seg
        xor a
        ld (CFIRST),a
        jr .nx
.seg:   ld hl,(CPX)             ; segmento dal punto precedente
        ld (GX1),hl
        ld hl,(CPY)
        ld (GY1),hl
        xor a
        ld (GFLG),a
        call rt_gline
.nx:    ld hl,(GX2)
        ld (CPX),hl
        ld hl,(GY2)
        ld (CPY),hl
        ld hl,(CK)
        ld a,h
        or l
        ret z
        dec hl
        ld (CK),hl
        ld hl,(CANG)
        inc hl
        ld (CANG),hl
        jp .l
