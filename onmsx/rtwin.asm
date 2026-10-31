; =====================================================================
; WINDOW: coordinate logiche intere -> pixel della finestra (VIEW) o dello schermo
; WINDOW [SCREEN] (x1,y1)-(x2,y2): (x1,y1) e' l'angolo logico in basso a sinistra (asse y verso l'alto);
; con SCREEN l'asse y va verso il basso come nei pixel. Aritmetica a 32 bit con arrotondamento.
; =====================================================================
muldiv:                         ; HL = v (con segno), DE = m (0..32767), BC = d (con segno, != 0) -> HL = v * m / d
        ld a,h
        xor b
        ld (WSG),a              ; segno del risultato (bit 7)
        bit 7,h
        call nz,rt_neghl
        bit 7,b
        jr z,.dp
        push hl
        ld h,b
        ld l,c
        call rt_neghl
        ld b,h
        ld c,l
        pop hl
.dp:    ld (WDV),bc
        ld (WMU),hl
        ld hl,0
        ld (W4),hl
        ld (W4+2),hl
        ld a,16
        ld (WCNT),a
.ml:    ld hl,(W4)              ; acc <<= 1
        add hl,hl
        ld (W4),hl
        ld hl,(W4+2)
        adc hl,hl
        ld (W4+2),hl
        sla e                   ; bit alto del moltiplicatore
        rl d
        jr nc,.nb
        ld hl,(W4)              ; acc += moltiplicando
        ld bc,(WMU)
        add hl,bc
        ld (W4),hl
        ld hl,(W4+2)
        ld bc,0
        adc hl,bc
        ld (W4+2),hl
.nb:    ld hl,WCNT
        dec (hl)
        jr nz,.ml
        ld hl,(WDV)             ; acc += d / 2 (arrotondamento)
        srl h
        rr l
        ld de,(W4)
        add hl,de
        ld (W4),hl
        ld hl,(W4+2)
        ld de,0
        adc hl,de
        ld (W4+2),hl
        ld hl,0
        ld (WREM),hl
        ld a,32
        ld (WCNT),a
.dv:    ld hl,W4                ; dividendo <<= 1, il bit uscente entra nel resto
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld hl,(WREM)
        adc hl,hl
        ld de,(WDV)
        or a
        sbc hl,de
        jr c,.no
        ld (WREM),hl            ; resto >= d: sottrae e mette 1 nel quoziente
        ld hl,W4
        set 0,(hl)
        jr .nx
.no:    add hl,de
        ld (WREM),hl
.nx:    ld hl,WCNT
        dec (hl)
        jr nz,.dv
        ld hl,(W4)              ; quoziente (16 bit bassi)
        ld a,(WSG)
        bit 7,a
        ret z
        jp rt_neghl

rt_winres:                      ; WINDOW senza argomenti: coordinate = pixel
        xor a
        ld (WACT),a
        ret

rt_window:                      ; (GX1,GY1)-(GX2,GY2) logiche, GFLG = 1 con SCREEN (y verso il basso)
        call chk_gfx
        ld hl,GX1
        ld de,GX2
        call sortp
        ld hl,GY1
        ld de,GY2
        call sortp
        ld hl,(GX1)
        ld (WWX1),hl
        ex de,hl
        ld hl,(GX2)
        or a
        sbc hl,de
        ld a,h
        or l
        jp z,rt_eifc
        ld (WDX),hl
        ld hl,(GY1)
        ld (WWY1),hl
        ex de,hl
        ld hl,(GY2)
        or a
        sbc hl,de
        ld a,h
        or l
        jp z,rt_eifc
        ld (WDY),hl
        ld hl,(VXW)
        dec hl
        ld (WMX),hl
        ld hl,(VYH)
        dec hl
        ld (WMY),hl
        ld a,(GFLG)
        xor 1
        ld (WYUP),a
        ld a,1
        ld (WACT),a
        ret

rt_wx:                          ; HL = x logica -> HL = x fisica
        ld a,(WACT)
        or a
        ret z
        ld de,(WWX1)
        or a
        sbc hl,de
        ld de,(WMX)
        ld bc,(WDX)
        call muldiv
        ld de,(VX1)
        add hl,de
        ret

rt_wy:                          ; HL = y logica -> HL = y fisica
        ld a,(WACT)
        or a
        ret z
        ld de,(WWY1)
        or a
        sbc hl,de
        ld de,(WMY)
        ld bc,(WDY)
        call muldiv
        ld a,(WYUP)
        or a
        jr z,.dn
        ex de,hl
        ld hl,(VY2)
        or a
        sbc hl,de
        ret
.dn:    ld de,(VY1)
        add hl,de
        ret

rt_wr:                          ; HL = raggio logico (come l'asse x) -> HL = raggio in pixel
        ld a,(WACT)
        or a
        ret z
        ld de,(WMX)
        ld bc,(WDX)
        jp muldiv
