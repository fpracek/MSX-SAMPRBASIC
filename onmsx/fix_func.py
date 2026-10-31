p='rtfunc.asm'
t=open(p).read()
def cut(a_marker, b_marker, new):
    global t
    i=t.index(a_marker); j=t.index(b_marker, i)
    t=t[:i]+new+t[j:]
# fp_int
cut("fp_int:", "fp_horner:", """fp_int:                         ; FA = floor(FA)
        ld hl,SX
        call fp_st
        call fp_fix
        ld a,(FA+FSG)
        or a
        jr nz,.n1
        ld a,(SX+2)             ; parte intera positiva o nulla: se x e' negativo il risultato e' -1
        and 80h
        ret z
        jr .neg
.n1:    ld hl,SX                ; x negativo: floor = fix - 1 se c'e' una parte frazionaria
        call fp_loadb
        call fp_magcmp
        ret z
.neg:   ld hl,k_one
        call fp_loadb
        ld a,(FB+FSG)
        xor 80h
        ld (FB+FSG),a           ; FB = -1
        jp fp_add

""")
# tan
cut("rt_ftan:", "rt_flog:", """rt_ftan:                        ; TAN = SIN / COS
        ld hl,SW
        call fp_st
        call rt_fsin
        ld hl,SZ
        call fp_st
        ld hl,SW
        call fp_load
        call rt_fcos
        ld hl,SZ
        jp fp_divm              ; FA = sin / cos

""")
# fp_scale
cut("fp_scale:", "fp_r24:", """fp_scale:                       ; FA = SZ * 10^HL (HL con segno)
        ld (FSP),hl
        ld hl,SZ
        call fp_load
        ld hl,SX
        call fp_st
.l:     ld hl,(FSP)
        ld a,h
        or l
        jr nz,.n
        ld hl,SX
        jp fp_load
.n:     bit 7,h
        jr nz,.neg
        ld a,l                  ; esponente positivo: moltiplica per 10^min(s, 32)
        cp 33
        jr c,.p1
        ld a,32
.p1:    ld b,a
        ld a,l
        sub b
        ld l,a
        ld (FSP),hl
        ld a,b
        call fp_p10
        ld hl,SX
        call fp_loadb
        call fp_mul
        ld hl,SX
        call fp_st
        jr .l
.neg:   ex de,hl
        ld hl,0
        or a
        sbc hl,de               ; |s|
        ld a,l
        cp 33
        jr c,.p2
        ld a,32
.p2:    ld b,a
        ld a,l
        sub b
        ld l,a                  ; |s| residuo
        ld h,0
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (FSP),hl             ; s residuo (negativo)
        ld a,b
        call fp_p10             ; 10^step
        ld hl,SX
        call fp_loadb
        call fp_div             ; x / 10^step
        ld hl,SX
        call fp_st
        jr .l

""")
# fstr: fallback e formato dell'esponente
t=t.replace("""        ld a,(FSF)
        dec a
        ld (FSF),a
        jr nz,.sc
        ld a,0                  ; (non dovrebbe succedere)
        ld hl,100000-65536*1-34464
.dg:""","""        ld a,(FSF)
        dec a
        ld (FSF),a
        jr nz,.sc
        ld a,1                  ; (non dovrebbe succedere)
        ld hl,86A0h
.dg:""")
i=t.index(".ee:    ld a,'E'")
j=t.index(".end:   ld hl,inbuf+1")
t=t[:i]+""".ee:    ld a,'E'
        call fstr_put
        ld hl,(FSE)
        bit 7,h
        jr z,.es
        push de
        ex de,hl
        ld hl,0
        or a
        sbc hl,de               ; |k|
        pop de
        ld a,'-'
        jr .ew
.es:    ld a,'+'
.ew:    call fstr_put
        ld a,l
        ld b,0
.t:     cp 10
        jr c,.tw
        sub 10
        inc b
        jr .t
.tw:    ld c,a
        ld a,b
        add a,'0'
        call fstr_put
        ld a,c
        add a,'0'
        call fstr_put
"""+t[j:]
# FIN
t+='''
; --- da testo a numero: HL = stringa (lunghezza, testo) -> FA
mul10add:                       ; (FT) = N a 24 bit (LE) -> N * 10 + C
        ld hl,(FT)
        ld a,(FT+2)
        ld d,a
        add hl,hl
        rl d                    ; 2N
        ld b,d
        ld e,h
        push hl
        pop af                  ; (non usato)
        ld c,l
        add hl,hl
        rl d
        add hl,hl
        rl d                    ; 8N
        ld a,l
        add a,c
        ld l,a
        ld a,h
        adc a,e
        ld h,a
        ld a,d
        adc a,b
        ld d,a                  ; 10N
        ld a,(FT+7)
        add a,l
        ld l,a
        jr nc,.n1
        inc h
        jr nz,.n1
        inc d
.n1:    ld (FT),hl
        ld a,d
        ld (FT+2),a
        ret

rt_fval:                        ; VAL! / INPUT: HL = stringa -> FA
        ld b,(hl)
        inc hl
        ld de,0
        ld (FT),de              ; N = 0
        xor a
        ld (FT+2),a
        ld (FT+4),a             ; vista la '.'
        ld (FT+5),a             ; cifre viste
        ld (FSS),a
        ld (FSE),de             ; esponente decimale
.sk:    ld a,b
        or a
        jr z,.fin
        ld a,(hl)
        cp ' '
        jr nz,.sg
        inc hl
        dec b
        jr .sk
.sg:    cp '-'
        jr nz,.pl
        ld a,80h
        ld (FSS),a
        inc hl
        dec b
        jr .ch
.pl:    cp '+'
        jr nz,.ch
        inc hl
        dec b
.ch:    ld a,b
        or a
        jr z,.fin
        ld a,(hl)
        inc hl
        dec b
        cp '.'
        jr nz,.nd
        ld a,(FT+4)
        or a
        jr nz,.fin
        inc a
        ld (FT+4),a
        jr .ch
.nd:    cp 'E'
        jr z,.ex
        cp 'e'
        jr z,.ex
        sub '0'
        cp 10
        jr nc,.fin
        ld c,a
        ld (FT+7),a
        ld a,1
        ld (FT+5),a
        ld a,(FT+2)             ; N <= 1677721 ?
        cp 19h
        jr c,.ok
        jr nz,.big
        ld a,(FT+1)
        cp 99h
        jr c,.ok
        jr nz,.big
        ld a,(FT)
        cp 99h
        jr nc,.big
.ok:    push hl
        push bc
        call mul10add
        pop bc
        pop hl
        ld a,(FT+4)
        or a
        jr z,.ch
        push hl
        ld hl,(FSE)
        dec hl
        ld (FSE),hl
        pop hl
        jr .ch
.big:   ld a,(FT+4)             ; cifra scartata: se prima del punto l'esponente cresce
        or a
        jr nz,.ch
        push hl
        ld hl,(FSE)
        inc hl
        ld (FSE),hl
        pop hl
        jr .ch
.ex:    ld a,b                  ; esponente: [segno] cifre
        or a
        jr z,.fin
        ld c,0                  ; C = segno
        ld a,(hl)
        cp '-'
        jr nz,.ep
        inc c
        inc hl
        dec b
        jr .ed
.ep:    cp '+'
        jr nz,.ed
        inc hl
        dec b
.ed:    ld e,0                  ; E = valore (max 255)
.el:    ld a,b
        or a
        jr z,.ef
        ld a,(hl)
        sub '0'
        cp 10
        jr nc,.ef
        ld d,a
        ld a,e
        cp 26
        jr nc,.sk2
        add a,a
        ld l,a                  ; (l = 2e) ... valore * 10 + cifra
        add a,a
        add a,a
        add a,l
        add a,d
        ld e,a
.sk2:   inc hl
        dec b
        jr .el
.ef:    ld d,0
        ld a,c
        or a
        jr z,.e2
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
.e2:    ld hl,(FSE)
        add hl,de
        ld (FSE),hl
.fin:   ld a,(FT+5)
        or a
        jp z,fp_zero_a
        ld a,(FT)
        ld hl,(FT)
        ld a,h
        or l
        ld a,(FT+2)
        or h
        or l
        jp z,fp_zero_a          ; N = 0
        ld a,(FT)               ; FA = N
        ld (FA+FM0),a
        ld a,(FT+1)
        ld (FA+FM1),a
        ld a,(FT+2)
        ld (FA+FM2),a
        xor a
        ld (FA+FGD),a
        ld (FA+FSG),a
        ld a,152
        ld (FA+FEX),a
        call fp_norm
        ld hl,SZ
        call fp_st
        ld hl,(FSE)
        call fp_scale
        ld a,(FSS)
        ld (FA+FSG),a
        ret
'''
open(p,'w').write(t)
