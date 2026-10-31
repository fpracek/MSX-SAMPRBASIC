; =====================================================================
; Virgola mobile a 32 bit (formato binario MBF: esponente con bias 128, mantissa 24 bit con bit nascosto, segno nel bit 7 del
; terzo byte): in memoria 4 byte [m0, m1, m2|segno, esponente], 0 = esponente 0.
; Gli operandi vivono in due accumulatori scompattati FA (destro/risultato) e FB (sinistro):
;   +0 segno (0 / 80h), +1 esponente, +2 byte di guardia, +3 m0, +4 m1, +5 m2 (bit 7 = 1 se normalizzato)
; =====================================================================
FSG     equ 0
FEX     equ 1
FGD     equ 2
FM0     equ 3
FM1     equ 4
FM2     equ 5

msg_ovf: db msg_ovf_e-msg_ovf-1,"Error: Overflow"
msg_ovf_e:
fp_ovf: ld hl,msg_ovf
        jp rt_fatal

fp_zero_a:
        ld hl,FA
        ld b,6
        xor a
.l:     ld (hl),a
        inc hl
        djnz .l
        ret

fp_ld:                          ; HL = 4 byte compatti, DE = accumulatore scompattato
        push de
        xor a
        inc de
        inc de
        ld (de),a               ; guardia
        inc de
        ldi                     ; m0
        ldi                     ; m1
        ld a,(hl)
        inc hl
        ld c,a
        or 80h
        ld (de),a               ; m2 con il bit nascosto
        ld a,(hl)               ; esponente
        pop de
        inc de
        ld (de),a
        dec de
        ld b,a
        ld a,c
        and 80h
        ld (de),a               ; segno
        ld a,b
        or a
        ret nz
        ld h,d                  ; zero: tutto a zero
        ld l,e
        ld b,6
.z:     ld (hl),a
        inc hl
        djnz .z
        ret

fp_load:                        ; HL -> FA
        ld de,FA
        jr fp_ld
fp_loadb:                       ; HL -> FB
        ld de,FB
        jr fp_ld

fp_st:                          ; FA -> 4 byte compatti in (HL)
        ld a,(FA+FEX)
        or a
        jr z,.z
        ld a,(FA+FM0)
        ld (hl),a
        inc hl
        ld a,(FA+FM1)
        ld (hl),a
        inc hl
        ld a,(FA+FM2)
        and 7Fh
        ld c,a
        ld a,(FA+FSG)
        or c
        ld (hl),a
        inc hl
        ld a,(FA+FEX)
        ld (hl),a
        ret
.z:     xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ret

fp_swap:                        ; scambia FA e FB
        ld hl,FA
        ld de,FB
        ld b,6
.l:     ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .l
        ret

fp_push:                        ; FA -> 4 byte sullo stack (conserva l'indirizzo di ritorno)
        pop de
        ld a,(FA+FEX)
        or a
        jr z,.z
        ld a,(FA+FM2)
        and 7Fh
        ld b,a
        ld a,(FA+FSG)
        or b
        ld l,a
        ld a,(FA+FEX)
        ld h,a
        push hl                 ; (m2|segno, esponente)
        ld hl,(FA+FM0)
        push hl                 ; (m0, m1)
        ex de,hl
        jp (hl)
.z:     ld hl,0
        push hl
        push hl
        ex de,hl
        jp (hl)

fp_pop:                         ; 4 byte dallo stack -> FB
        pop de                  ; ritorno
        pop hl                  ; (m0, m1)
        ld (FT),hl
        pop hl                  ; (m2|segno, esponente)
        ld (FT+2),hl
        push de
        ld hl,FT
        call fp_loadb
        ret

fp_ipop:                        ; intero dallo stack -> FB (conversione); FA resta com'e'
        pop de
        pop hl
        push de
        push hl                 ; si usa FA come lavoro: lo si salva in FT+4
        ld hl,FA
        ld de,FT+4
        ld bc,6
        ldir
        pop hl
        call fp_itof
        ld hl,FA                ; FA (convertito) -> FB
        ld de,FB
        ld bc,6
        ldir
        ld hl,FT+4              ; FA originale
        ld de,FA
        ld bc,6
        ldir
        ret

fp_norm:                        ; normalizza la mantissa di FA
.l:     ld a,(FA+FM2)
        or a
        jp m,.d
        jr nz,.s1
        ld a,(FA+FM1)           ; byte alto nullo: scorrimento di un byte
        ld (FA+FM2),a
        ld a,(FA+FM0)
        ld (FA+FM1),a
        ld a,(FA+FGD)
        ld (FA+FM0),a
        xor a
        ld (FA+FGD),a
        ld a,(FA+FEX)
        sub 8
        jr c,.z
        jr z,.z
        ld (FA+FEX),a
        jr .l
.s1:    ld hl,FA+FGD
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld hl,FA+FEX
        dec (hl)
        jr nz,.l
.z:     jp fp_zero_a
.d:     ret

fp_round:                       ; arrotonda usando il byte di guardia
        ld a,(FA+FGD)
        bit 7,a
        jr z,.z
        ld hl,(FA+FM0)
        inc hl
        ld (FA+FM0),hl
        ld a,h
        or l
        jr nz,.z
        ld hl,FA+FM2
        inc (hl)
        jr nz,.z
        ld (hl),80h
        ld hl,FA+FEX
        inc (hl)
        jp z,fp_ovf
.z:     xor a
        ld (FA+FGD),a
        ret

fp_neg:
        ld a,(FA+FEX)
        or a
        ret z
        ld a,(FA+FSG)
        xor 80h
        ld (FA+FSG),a
        ret

fp_abs:
        xor a
        ld (FA+FSG),a
        ret

fp_add:                         ; FA = FB + FA
        ld a,(FA+FEX)
        or a
        jr nz,.a1
        ld hl,FB                ; FA nullo: FA = FB
        ld de,FA
        ld bc,6
        ldir
        ret
.a1:    ld a,(FB+FEX)
        or a
        ret z
        ld a,(FA+FEX)
        ld b,a
        ld a,(FB+FEX)
        cp b
        jr c,.ok
        jr z,.ok
        call fp_swap            ; FA ha l'esponente maggiore
.ok:    ld a,(FA+FEX)
        ld b,a
        ld a,(FB+FEX)
        ld c,a
        ld a,b
        sub c
        cp 26
        ret nc                  ; FB trascurabile
        or a
        jr z,.al
        ld b,a                  ; allinea FB: scorrimento a destra di b bit
.sl:    ld hl,FB+FM2
        srl (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        djnz .sl
.al:    ld a,(FA+FSG)
        ld b,a
        ld a,(FB+FSG)
        xor b
        jr nz,.sub
        ld hl,(FA+FGD)          ; stesso segno: somma
        ld de,(FB+FGD)
        add hl,de
        ld (FA+FGD),hl
        ld hl,(FA+FM1)
        ld de,(FB+FM1)
        adc hl,de
        ld (FA+FM1),hl
        jr nc,.rn
        ld hl,FA+FM2            ; riporto: scorrimento a destra con il bit uscito in cima
        scf
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        ld hl,FA+FEX
        inc (hl)
        jp z,fp_ovf
.rn:    jp fp_round
.sub:   ld hl,(FA+FM1)          ; segni diversi: differenza dei moduli
        ld de,(FB+FM1)
        or a
        sbc hl,de
        jr nz,.cm
        ld hl,(FA+FGD)
        ld de,(FB+FGD)
        or a
        sbc hl,de
.cm:    jr nc,.fa               ; |FA| >= |FB|
        ld hl,(FB+FGD)          ; FA = FB - FA, segno di FB
        ld de,(FA+FGD)
        or a
        sbc hl,de
        ld (FA+FGD),hl
        ld hl,(FB+FM1)
        ld de,(FA+FM1)
        sbc hl,de
        ld (FA+FM1),hl
        ld a,(FB+FSG)
        ld (FA+FSG),a
        jr .nm
.fa:    ld hl,(FA+FGD)
        ld de,(FB+FGD)
        or a
        sbc hl,de
        ld (FA+FGD),hl
        ld hl,(FA+FM1)
        ld de,(FB+FM1)
        sbc hl,de
        ld (FA+FM1),hl
.nm:    ld hl,(FA+FM1)
        ld a,h
        or l
        jr nz,.nz
        ld hl,(FA+FGD)
        ld a,h
        or l
        jp z,fp_zero_a
.nz:    call fp_norm
        ld a,(FA+FEX)
        or a
        ret z
        jp fp_round

fp_sub:                         ; FA = FB - FA
        ld a,(FA+FSG)
        xor 80h
        ld (FA+FSG),a
        jp fp_add

fp_mul:                         ; FA = FB * FA
        ld a,(FA+FEX)
        or a
        ret z
        ld a,(FB+FEX)
        or a
        jp z,fp_zero_a
        ld a,(FA+FSG)
        ld b,a
        ld a,(FB+FSG)
        xor b
        ld (FA+FSG),a
        ld a,(FA+FEX)
        ld l,a
        ld h,0
        ld a,(FB+FEX)
        ld e,a
        ld d,0
        add hl,de
        ld de,-128
        add hl,de
        ld (FT+9),hl
        ld hl,(FA+FM0)          ; moltiplicatore = mantissa di FA
        ld (FT),hl
        ld a,(FA+FM2)
        ld (FT+2),a
        ld hl,FT+3              ; prodotto = 0
        ld b,6
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        ld b,24
.m:     ld hl,FT+2
        srl (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        jr nc,.na
        ld hl,(FT+6)
        ld de,(FB+FM0)
        add hl,de
        ld (FT+6),hl
        ld a,(FT+8)
        ld hl,FB+FM2
        adc a,(hl)
        ld (FT+8),a
        jr .sr
.na:    or a
.sr:    ld hl,FT+8
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        djnz .m
        ld a,(FT+8)
        or a
        jp m,.nn
        ld hl,FT+5
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld hl,(FT+9)
        dec hl
        ld (FT+9),hl
.nn:    ld hl,(FT+5)
        ld (FA+FGD),hl
        ld hl,(FT+7)
        ld (FA+FM1),hl
        jr fp_setexp

fp_setexp:                      ; (FT+9) = esponente a 16 bit: controlla, scrive e arrotonda
        ld hl,(FT+9)
        bit 7,h
        jp nz,fp_zero_a
        ld a,h
        or a
        jp nz,fp_ovf
        ld a,l
        or a
        jp z,fp_zero_a
        ld (FA+FEX),a
        jp fp_round

fp_div:                         ; FA = FB / FA
        ld a,(FA+FEX)
        or a
        jp z,rt_ediv
        ld a,(FB+FEX)
        or a
        jp z,fp_zero_a
        ld a,(FA+FSG)
        ld b,a
        ld a,(FB+FSG)
        xor b
        ld (FA+FSG),a
        ld a,(FB+FEX)
        ld l,a
        ld h,0
        ld a,(FA+FEX)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,128
        add hl,de
        ld (FT+9),hl
        ld hl,(FB+FM0)          ; resto = mantissa di FB
        ld (FT),hl
        ld a,(FB+FM2)
        ld (FT+2),a
        xor a
        ld (FT+3),a
        ld hl,0
        ld (FT+4),hl
        ld (FT+6),hl
        ld b,32
.l:     ld a,(FT+3)
        or a
        jr nz,.sub
        ld a,(FT+2)
        ld hl,FA+FM2
        cp (hl)
        jr c,.skip
        jr nz,.sub
        ld a,(FT+1)
        ld hl,FA+FM1
        cp (hl)
        jr c,.skip
        jr nz,.sub
        ld a,(FT)
        ld hl,FA+FM0
        cp (hl)
        jr c,.skip
.sub:   ld hl,(FT)
        ld de,(FA+FM0)
        or a
        sbc hl,de
        ld (FT),hl
        ld a,(FT+2)
        ld hl,FA+FM2
        sbc a,(hl)
        ld (FT+2),a
        scf
        jr .q
.skip:  or a
.q:     ld hl,FT+4
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld hl,FT
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld a,0
        rla
        ld (FT+3),a
        djnz .l
        ld a,(FT+7)
        or a
        jp m,.big
        ld hl,FT+4              ; q < 1: Q << 1
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        jr .st
.big:   ld hl,(FT+9)            ; q >= 1: esponente + 1
        inc hl
        ld (FT+9),hl
.st:    ld hl,(FT+4)
        ld (FA+FGD),hl
        ld hl,(FT+6)
        ld (FA+FM1),hl
        jp fp_setexp

fp_itof:                        ; HL = intero con segno -> FA
        ld a,h
        or l
        jp z,fp_zero_a
        ld a,h
        and 80h
        ld (FA+FSG),a
        jr z,.p
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.p:     ld a,h
        ld (FA+FM2),a
        ld a,l
        ld (FA+FM1),a
        xor a
        ld (FA+FM0),a
        ld (FA+FGD),a
        ld a,144
        ld (FA+FEX),a
        jp fp_norm

fp_ftoi:                        ; FA -> HL intero; A = 0 tronca, 1 arrotonda; errore se fuori da -32768..32767
        ld c,a
        ld a,(FA+FEX)
        or a
        jr z,.zero
        cp 145
        jp nc,fp_ovf
        cp 128
        jr c,.zero
        jr nz,.sh
        ld hl,0                 ; 0.5 <= |x| < 1
        bit 0,c
        jr z,.sg
        inc hl
        jr .sg
.sh:    ld b,a
        ld a,152
        sub b
        ld b,a                  ; scorrimenti: 152 - esponente (8..23)
        ld a,(FA+FM2)
        ld h,a
        ld a,(FA+FM1)
        ld l,a
        ld a,(FA+FM0)
        ld d,a
.l:     srl h
        rr l
        rr d
        djnz .l
        ld h,l
        ld l,d
        bit 0,c
        jr z,.sg
        jr nc,.sg
        inc hl
.sg:    ld a,(FA+FSG)
        or a
        jr z,.pos
        ld a,h
        cp 81h
        jp nc,fp_ovf
        cp 80h
        jr nz,.ng
        ld a,l
        or a
        jp nz,fp_ovf
.ng:    ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ret
.pos:   bit 7,h
        jp nz,fp_ovf
        ret
.zero:  ld hl,0
        ret

fp_magcmp:                      ; C se |FB| < |FA|, Z se uguali
        ld a,(FB+FEX)
        ld hl,FA+FEX
        cp (hl)
        ret nz
        ld a,(FB+FM2)
        ld hl,FA+FM2
        cp (hl)
        ret nz
        ld a,(FB+FM1)
        ld hl,FA+FM1
        cp (hl)
        ret nz
        ld a,(FB+FM0)
        ld hl,FA+FM0
        cp (hl)
        ret

fp_cmp:                         ; confronta FB (sinistro) con FA (destro): Z se uguali, C se FB < FA
        ld a,(FB+FEX)
        or a
        jr nz,.b1
        ld a,(FA+FEX)
        or a
        ret z                   ; entrambi nulli
        ld a,(FA+FSG)
        or a
        jr z,.lt
        jr .gt
.b1:    ld a,(FA+FEX)
        or a
        jr nz,.n2
        ld a,(FB+FSG)           ; destro nullo
        or a
        jr nz,.lt
        jr .gt
.n2:    ld a,(FB+FSG)
        ld b,a
        ld a,(FA+FSG)
        xor b
        jr z,.same
        ld a,(FB+FSG)           ; segni diversi
        or a
        jr nz,.lt
        jr .gt
.same:  call fp_magcmp
        ret z
        push af
        ld a,(FB+FSG)
        or a
        jr z,.p
        pop af
        ccf                     ; negativi: ordine invertito
        ret
.p:     pop af
        ret
.lt:    ld a,1
        or a
        scf
        ret
.gt:    ld a,1
        or a
        ret

fp_cmpop:                       ; sinistro dallo stack (4 byte), destro in FA: flag come rt_cmp
        call fp_pop
        jp fp_cmp
