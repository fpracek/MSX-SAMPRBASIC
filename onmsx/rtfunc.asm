; =====================================================================
; Funzioni in virgola mobile e conversioni testo (usa rtfloat.asm). Temporanei: SX SY SZ SW (4 byte), FSP (word),
; FSN FSF FSS (byte), FSE (word), FDG (6 byte)
; =====================================================================
SX      equ FS
SY      equ FS+4
SZ      equ FS+8
SW      equ FS+12
SV      equ FS+16
FSP     equ FS+20
FSN     equ FS+22
FSF     equ FS+23
FSS     equ FS+24
FSE     equ FS+25
FDG     equ FS+27

fp_addm:                        ; FA = (HL) + FA
        call fp_loadb
        jp fp_add
fp_subm:                        ; FA = (HL) - FA
        call fp_loadb
        jp fp_sub
fp_mulm:                        ; FA = (HL) * FA
        call fp_loadb
        jp fp_mul
fp_divm:                        ; FA = (HL) / FA
        call fp_loadb
        jp fp_div

fp_ldexp:                       ; FA = FA * 2^HL (HL con segno)
        ld a,(FA+FEX)
        or a
        ret z
        ld e,a
        ld d,0
        add hl,de
        ld (FT+9),hl
        jp fp_setexp

fp_fix:                         ; FA = parte intera (verso lo zero)
        ld a,(FA+FEX)
        or a
        ret z
        cp 152
        ret nc                  ; gia' intero
        cp 129
        jp c,fp_zero_a          ; |x| < 1
        ld b,a
        ld a,152
        sub b                   ; bit frazionari (1..23)
        ld b,a
        ld c,a
.l:     ld hl,FA+FM2            ; si cancellano i bit bassi: scorrimento a destra e poi a sinistra
        srl (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        djnz .l
        ld b,c
.r:     ld hl,FA+FM0
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        djnz .r
        ret

fp_int:                         ; FA = floor(FA)
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

fp_horner:                      ; (FSP) = tabella (primo coefficiente il piu' alto), (FSN) = quanti dopo il primo, DE = indirizzo del moltiplicatore
        push de
        ld hl,(FSP)
        call fp_load
        call fsp_next
        pop de
.l:     push de
        ex de,hl
        call fp_loadb
        call fp_mul
        ld hl,(FSP)
        call fp_addm
        call fsp_next
        pop de
        ld hl,FSN
        dec (hl)
        jr nz,.l
        ret
fsp_next:
        ld hl,(FSP)
        inc hl
        inc hl
        inc hl
        inc hl
        ld (FSP),hl
        ret

rt_fsqr:                        ; SQR
        ld a,(FA+FEX)
        or a
        ret z
        ld a,(FA+FSG)
        or a
        jp nz,rt_eifc
        ld hl,SX
        call fp_st
        ld a,(FA+FEX)
        ld l,a
        ld h,0
        ld de,128
        add hl,de
        srl h
        rr l
        ld a,l
        ld (FA+FEX),a           ; ipotesi iniziale: esponente dimezzato
        ld b,6
.it:    push bc
        ld hl,SY
        call fp_st              ; y
        ld hl,SX
        call fp_loadb
        call fp_div             ; x / y
        ld hl,SY
        call fp_addm            ; y + x / y
        ld hl,FA+FEX
        dec (hl)                ; / 2
        pop bc
        djnz .it
        ret

rt_fsin:                        ; SIN
        ld hl,SX
        call fp_st
        ld hl,k_inv2pi
        call fp_mulm
        ld a,1
        call fp_ftoi
        call fp_itof
        ld hl,k_2pi
        call fp_mulm
        ld hl,SX
        call fp_loadb
        call fp_sub             ; r = x - n * 2pi in [-pi, pi]
        ld hl,SX
        call fp_st
        call fp_abs
        ld hl,k_halfpi
        call fp_loadb
        call fp_cmp
        jr nc,.nr               ; |r| <= pi/2
        ld hl,k_pi              ; r = (+-pi) - r
        call fp_load
        ld a,(SX+2)
        and 80h
        call nz,fp_neg
        ld hl,SX
        call fp_loadb
        call fp_sub             ; r - (+-pi)
        call fp_neg
        ld hl,SX
        call fp_st
.nr:    ld hl,SX
        call fp_load
        ld hl,SX
        call fp_loadb
        call fp_mul             ; r^2
        ld hl,SY
        call fp_st
        ld hl,k_sin
        ld (FSP),hl
        ld a,6
        ld (FSN),a
        ld de,SY
        call fp_horner
        ld hl,SX
        jp fp_mulm              ; * r

rt_fcos:                        ; COS(x) = SIN(x + pi/2)
        ld hl,k_halfpi
        call fp_addm
        jp rt_fsin

rt_ftan:                        ; TAN = SIN / COS
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

rt_flog:                        ; LOG (logaritmo naturale)
        ld a,(FA+FEX)
        or a
        jp z,rt_eifc
        ld a,(FA+FSG)
        or a
        jp nz,rt_eifc
        ld a,(FA+FEX)
        ld l,a
        ld h,0
        ld de,-128
        add hl,de
        ld (FSE),hl             ; e
        ld a,128
        ld (FA+FEX),a           ; m in [0.5, 1)
        ld hl,k_sqrhalf
        call fp_loadb
        call fp_cmp
        jr c,.ok                ; m > 0.7071
        ld hl,FA+FEX
        inc (hl)                ; m * 2
        ld hl,(FSE)
        dec hl
        ld (FSE),hl
.ok:    ld hl,SX
        call fp_st              ; m
        ld hl,k_one
        call fp_addm
        ld hl,SY
        call fp_st              ; m + 1
        ld hl,k_one
        call fp_load
        ld hl,SX
        call fp_loadb
        call fp_sub             ; m - 1
        ld hl,SZ
        call fp_st
        ld hl,SY
        call fp_load
        ld hl,SZ
        call fp_divm            ; z = (m - 1) / (m + 1)
        ld hl,SX
        call fp_st
        ld hl,SX
        call fp_loadb
        call fp_mul
        ld hl,SY
        call fp_st              ; z^2
        ld hl,k_log
        ld (FSP),hl
        ld a,6
        ld (FSN),a
        ld de,SY
        call fp_horner
        ld hl,SX
        call fp_mulm            ; * z
        ld a,(FA+FEX)
        or a
        jr z,.nz
        ld hl,FA+FEX
        inc (hl)                ; * 2
.nz:    ld hl,SZ
        call fp_st
        ld hl,(FSE)
        call fp_itof
        ld hl,k_ln2
        call fp_mulm
        ld hl,SZ
        jp fp_addm

rt_fexp:                        ; EXP
        ld hl,k_log2e
        call fp_mulm
        ld hl,SX
        call fp_st              ; t = x * log2(e)
        ld a,1
        call fp_ftoi
        ld (FSE),hl             ; n
        call fp_itof
        ld hl,SX
        call fp_loadb
        call fp_sub             ; f = t - n
        ld hl,k_ln2
        call fp_mulm            ; u = f * ln2
        ld hl,SX
        call fp_st
        ld hl,k_exp
        ld (FSP),hl
        ld a,8
        ld (FSN),a
        ld de,SX
        call fp_horner
        ld hl,(FSE)
        jp fp_ldexp             ; * 2^n

rt_fatn:                        ; ATN
        ld a,(FA+FEX)
        or a
        ret z
        ld a,(FA+FSG)
        ld (FSS),a
        call fp_abs
        xor a
        ld (FSF),a              ; 1 se si e' usato 1/x
        ld hl,k_one
        call fp_loadb
        call fp_cmp             ; C se 1 < |x|
        jr nc,.sm
        ld hl,k_one
        call fp_divm            ; 1 / |x|
        ld a,1
        ld (FSF),a
.sm:    ld hl,SW
        call fp_st              ; x in [0, 1]
        ld hl,SW
        call fp_loadb
        call fp_mul             ; x^2
        ld hl,k_one
        call fp_addm            ; 1 + x^2
        call rt_fsqr
        ld hl,k_one
        call fp_addm            ; 1 + sqrt(1 + x^2)
        ld hl,SW
        call fp_divm            ; x / (1 + sqrt(...)): argomento dimezzato
        ld hl,SW
        call fp_st
        ld hl,SW
        call fp_loadb
        call fp_mul
        ld hl,SY
        call fp_st              ; x'^2
        ld hl,k_atn
        ld (FSP),hl
        ld a,7
        ld (FSN),a
        ld de,SY
        call fp_horner
        ld hl,SW
        call fp_mulm            ; * x'
        ld a,(FA+FEX)
        or a
        jr z,.z2
        ld hl,FA+FEX
        inc (hl)                ; * 2
.z2:    ld a,(FSF)
        or a
        jr z,.nf
        ld hl,k_halfpi
        call fp_subm            ; pi/2 - risultato
.nf:    ld a,(FSS)
        or a
        ret z
        jp fp_neg

; --- potenza FB ^ FA
rt_fpow:
        ld hl,SV
        call fp_st              ; esponente y
        call fp_swap            ; FA = base x
        ld hl,SW
        call fp_st
        ld a,(FA+FEX)
        or a
        jr nz,.nz
        ld a,(SV+3)             ; base nulla: 0^y = 0 se y > 0
        or a
        jp z,.one               ; 0^0 = 1
        ld a,(SV+2)
        and 80h
        jp nz,rt_ediv           ; 0^(negativo)
        jp fp_zero_a
.nz:    ld hl,SV
        call fp_load            ; y
        ld a,(FA+FEX)
        or a
        jp z,.one
        cp 136                  ; |y| < 256: possibile potenza intera
        jp nc,.gen
        xor a
        call fp_ftoi            ; n = tronca(y)
        ld (FSE),hl
        call fp_itof
        ld hl,SV
        call fp_loadb
        call fp_cmp             ; n == y ?
        jr nz,.gen
        ld hl,SW                ; potenza intera: x^|n| per quadrati ripetuti
        call fp_load
        ld hl,SY
        call fp_st              ; b = x
        ld hl,k_one
        call fp_load
        ld hl,SX
        call fp_st              ; r = 1
        ld hl,(FSE)
        bit 7,h
        jr z,.pp
        ex de,hl
        ld hl,0
        or a
        sbc hl,de               ; |n|
.pp:    ld a,l
        ld (FSN),a
.lp:    ld a,(FSN)
        or a
        jr z,.dn
        srl a
        ld (FSN),a
        jr nc,.sq
        ld hl,SX                ; r = r * b
        call fp_load
        ld hl,SY
        call fp_mulm
        ld hl,SX
        call fp_st
.sq:    ld a,(FSN)
        or a
        jr z,.dn
        ld hl,SY
        call fp_load
        ld hl,SY
        call fp_mulm
        ld hl,SY
        call fp_st
        jr .lp
.dn:    ld hl,SX
        call fp_load
        ld a,(FSE+1)
        bit 7,a
        ret z
        ld hl,k_one
        jp fp_divm              ; n negativo: 1 / r
.one:   ld hl,k_one
        jp fp_load
.gen:   ld hl,SW                ; generale: exp(y * ln x), x > 0
        call fp_load
        call rt_flog
        ld hl,SV
        call fp_mulm
        jp rt_fexp

; --- segno, valore assoluto, intero
rt_fsgn:                        ; SGN -> HL = -1, 0, 1
        ld a,(FA+FEX)
        or a
        jr z,.z
        ld a,(FA+FSG)
        or a
        ld hl,1
        ret z
        ld hl,-1
        ret
.z:     ld hl,0
        ret

; ---------------------------------------------------------------- conversioni testo
fp_p10:                         ; A = n (0..38) -> FA = 10^n
        ld (SV),a
        ld hl,k_one
        call fp_load
        ld hl,k_p10
        ld b,6
.l:     ld a,(SV)
        bit 0,a
        jr z,.s
        push hl
        push bc
        call fp_loadb
        call fp_mul
        pop bc
        pop hl
.s:     ld a,(SV)
        srl a
        ld (SV),a
        ld de,4
        add hl,de
        djnz .l
        ret

fp_scale:                       ; FA = SZ * 10^HL (HL con segno)
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

fp_r24:                         ; FA (>= 0) -> A:HL intero a 24 bit arrotondato
        ld a,(FA+FEX)
        or a
        jr z,.z
        cp 128
        jr c,.z
        jr nz,.go
        ld hl,1                 ; 0.5 <= y < 1
        xor a
        ret
.go:    ld b,a
        ld a,152
        sub b
        jr nc,.sh
        xor a
.sh:    ld b,a
        ld a,(FA+FM2)
        ld d,a
        ld a,(FA+FM1)
        ld h,a
        ld a,(FA+FM0)
        ld l,a
        ld a,b
        or a
        jr z,.d
.l:     srl d
        rr h
        rr l
        djnz .l
        jr nc,.d
        inc l
        jr nz,.d
        inc h
        jr nz,.d
        inc d
.d:     ld a,d
        ret
.z:     ld hl,0
        xor a
        ret

div10:                          ; A:HL / 10 -> A:HL, resto in C
        ld d,a
        ld c,0
        ld b,24
.l:     sla l
        rl h
        rl d
        rl c
        ld a,c
        cp 10
        jr c,.n
        sub 10
        ld c,a
        inc l
.n:     djnz .l
        ld a,d
        ret

fstr_put:                       ; A = carattere -> (DE++)
        ld (de),a
        inc de
        ret

rt_fstr:                        ; FA -> HL = stringa temporanea (formato MSX: spazio o '-' davanti)
        ld a,(FA+FEX)
        or a
        jr nz,.nz
        ld hl,inbuf+1
        ld (hl),' '
        inc hl
        ld (hl),'0'
        ld a,2
        ld (inbuf),a
        ld hl,inbuf
        jp rt_sdup
.nz:    ld a,(FA+FSG)
        or a
        ld a,' '
        jr z,.p
        ld a,'-'
.p:     ld (inbuf+1),a
        call fp_abs
        ld hl,SZ
        call fp_st              ; |x|
        ld a,(FA+FEX)           ; stima k = floor((e - 1) * 77 / 256)
        ld l,a
        ld h,0
        ld de,-129
        add hl,de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,de
        ld b,h
        ld c,l                  ; 13x
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; 64x
        add hl,bc               ; 77x
        ld a,h
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (FSE),hl             ; k
        ld a,3
        ld (FSF),a              ; tentativi
.sc:    ld hl,5
        ld de,(FSE)
        or a
        sbc hl,de               ; s = 5 - k
        call fp_scale
        call fp_r24             ; A:HL = n
        cp 0Fh
        jr c,.lo
        jr nz,.hi
        ld de,4240h
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.lo
.hi:    ld hl,(FSE)             ; n >= 10^6: la stima era bassa
        inc hl
        ld (FSE),hl
        ld a,(FSF)
        dec a
        ld (FSF),a
        jp nz,.sc
        ld a,1
        ld hl,86A0h
        jr .dg
.lo:    cp 1
        jr c,.sm
        jr nz,.dg
        ld de,86A0h
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.dg
.sm:    ld hl,(FSE)             ; n < 10^5: la stima era alta
        dec hl
        ld (FSE),hl
        ld a,(FSF)
        dec a
        ld (FSF),a
        jr nz,.sc
        ld a,1                  ; (non dovrebbe succedere)
        ld hl,86A0h
.dg:    ld b,6                  ; sei cifre, dalla meno significativa
        ld de,FDG
.dl:    push bc
        push de
        call div10
        pop de
        ld b,a
        ld a,c
        ld (de),a
        inc de
        ld a,b
        pop bc
        djnz .dl
        ld c,6                  ; nd = cifre significative (tolti gli zeri in coda)
        ld hl,FDG
.zc:    ld a,(hl)
        or a
        jr nz,.zd
        inc hl
        dec c
        jr .zc
.zd:    ld a,c
        ld (FSN),a              ; nd
        ld de,inbuf+2
        ld hl,(FSE)             ; k
        bit 7,h
        jr nz,.neg
        ld a,l
        cp 6
        jr nc,.exp
        ; formato fisso: k = 0..5, cifre intere = k + 1
        ld b,a
        inc b                   ; B = cifre intere
        ld hl,FDG+5             ; cifra piu' significativa
        ld c,b                  ; C = cifre intere da scrivere
.fi:    ld a,(FSN)
        or a
        jr z,.fz
        dec a
        ld (FSN),a
        ld a,(hl)
        add a,'0'
        jr .fw
.fz:    ld a,'0'
.fw:    call fstr_put
        dec hl
        dec c
        jr nz,.fi
        ld a,(FSN)
        or a
        jp z,.end
        ld a,'.'
        call fstr_put
.fr:    ld a,(hl)
        add a,'0'
        call fstr_put
        dec hl
        ld a,(FSN)
        dec a
        ld (FSN),a
        jr nz,.fr
        jp .end
.neg:   ld a,l                  ; k < 0
        cp 0FFh
        jr z,.sm1
        cp 0FEh
        jr nz,.exp
.sm1:   ld a,'.'                ; 0.01 <= x < 1: .ddd con zeri iniziali
        call fstr_put
        ld a,l
        cpl                     ; -k - 1 zeri
        ld b,a
        or a
        jr z,.nz0
.z0:    ld a,'0'
        call fstr_put
        djnz .z0
.nz0:   ld hl,FDG+5
.d0:    ld a,(hl)
        add a,'0'
        call fstr_put
        dec hl
        ld a,(FSN)
        dec a
        ld (FSN),a
        jr nz,.d0
        jr .end
.exp:   ld hl,FDG+5             ; d[.ddd]E+xx
        ld a,(hl)
        add a,'0'
        call fstr_put
        dec hl
        ld a,(FSN)
        dec a
        ld (FSN),a
        jr z,.ee
        ld a,'.'
        call fstr_put
.e1:    ld a,(hl)
        add a,'0'
        call fstr_put
        dec hl
        ld a,(FSN)
        dec a
        ld (FSN),a
        jr nz,.e1
.ee:    ld a,'E'
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
.end:   ld hl,inbuf+1
        ex de,hl
        or a
        sbc hl,de
        ld a,l
        ld (inbuf),a
        ld hl,inbuf
        jp rt_sdup

; --- da testo a numero: HL = stringa (lunghezza, testo) -> FA
mul10add:                       ; (FT) = N a 24 bit (LE) -> N * 10 + C
        ld hl,(FT)
        ld a,(FT+2)
        ld d,a
        add hl,hl
        rl d                    ; 2N
        ld b,d
        ld e,h
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
        jp z,.fin
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
        jp z,.fin
        ld a,(hl)
        inc hl
        dec b
        cp '.'
        jr nz,.nd
        ld a,(FT+4)
        or a
        jp nz,.fin
        inc a
        ld (FT+4),a
        jr .ch
.nd:    cp 'E'
        jr z,.ex
        cp 'e'
        jr z,.ex
        sub '0'
        cp 10
        jp nc,.fin
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
        xor a
        ld (FSF),a              ; segno
        ld a,(hl)
        cp '-'
        jr nz,.ep
        ld a,1
        ld (FSF),a
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
        ld c,a                  ; 2e
        add a,a
        add a,a
        add a,c                 ; 10e
        add a,d
        ld e,a
.sk2:   inc hl
        dec b
        jr .el
.ef:    ld d,0
        ld a,(FSF)
        or a
        jr z,.e2
        ld hl,0
        or a
        sbc hl,de
        ex de,hl                ; DE = -valore
.e2:    ld hl,(FSE)
        add hl,de
        ld (FSE),hl
.fin:   ld a,(FT+5)
        or a
        jp z,fp_zero_a          ; nessuna cifra
        ld hl,(FT)
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
