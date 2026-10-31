p = 'qasm.asm'
t = open(p, encoding='latin-1', newline='').read().replace('\r\n', '\n')


def rep(a, b):
    global t
    assert t.count(a) == 1, (a[:60], t.count(a))
    t = t.replace(a, b)


def cut(start, end, new):
    global t
    a = t.index(start)
    b = t.index(end)
    assert a < b, (start[:40], end[:40])
    t = t[:a] + new + t[b:]


cut("wchar:                          ; A -> uscita", "weol:", """wchar:                          ; A -> uscita (solo seconda passata)
        push hl
        push af
        ld a,(pass)
        cp 2
        jr nz,.x
        ld hl,(outp)
        ld a,h
        cp high TMPEND
        jp nc,err_rng
        pop af
        push af
        ld (hl),a
        inc hl
        ld (outp),hl
.x:     pop af
        pop hl
        ret

""")
cut("emb:                            ; A = byte", "pcadd:", """emb:                            ; A = byte
        push af
        push hl
        ld (embv),a
        ld hl,(pc_off)
        inc hl
        ld (pc_off),hl
        ld a,(pass)
        cp 2
        jr nz,.x
        call sepchar
        ld a,(embv)
        ld l,a
        ld h,0
        call wdec
.x:     pop hl
        pop af
        ret

""")
rep("tmpw    equ SV+53\n", "tmpw    equ SV+53\nembv    equ SV+55\n")
cut(".dollar:\n        inc hl\n        ld a,(hl)\n        call ishex", "strend:                         ; HL -> terminatore", """.dollar:
        inc hl
        ld a,(hl)
        call ishex
        jr c,.dhex
        ld de,(pc_off)
        ld (tv),de
        ld a,1
        ld (tk),a
        ret
.dhex:  ld c,16
        jr .pre
.bin:   inc hl
        ld c,2
.pre:   call rdnum
        push hl
        ld hl,ntok
        call pnum
        pop hl
        ret
.num:   call rdnum
        push hl
        call numbase
        call pnum
        pop hl
        ret

rdnum:                          ; HL = cifre -> NTOK (0-terminato); HL dopo le cifre
        ld de,ntok
.l:     ld a,(hl)
        call isalnum
        jr nc,.e
        ld (de),a
        inc de
        inc hl
        jr .l
.e:     xor a
        ld (de),a
        ret

numbase:                        ; NTOK -> HL = cifre, C = base (toglie il suffisso H/B)
        ld hl,ntok
        call strend
        dec hl
        ld a,(hl)
        cp 'H'
        jr nz,.nh
        ld (hl),0
        ld c,16
        ld hl,ntok
        ret
.nh:    ld a,(ntok)
        cp '0'
        jr nz,.nb
        ld a,(ntok+1)
        cp 'X'
        jr nz,.nb
        ld c,16
        ld hl,ntok+2
        ret
.nb:    ld a,(hl)
        cp 'B'
        jr nz,.dec
        ld de,ntok
.bl:    ld a,(de)
        cp 'B'
        jr z,.isb
        cp '0'
        jr z,.bn
        cp '1'
        jr nz,.dec
.bn:    inc de
        jr .bl
.isb:   ld (hl),0
        ld c,2
        ld hl,ntok
        ret
.dec:   ld c,10
        ld hl,ntok
        ret

""")
cut("pnum:                           ; HL = cifre", "mulacc:", """pnum:                           ; HL = cifre (0-terminate), C = base -> tv, tk = 0
        ld a,c
        ld (nbase),a
        ld de,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc hl
        sub '0'
        cp 10
        jr c,.dg
        sub 'A'-'0'-10
.dg:    ld b,a
        ld a,(nbase)
        dec a
        cp b
        jp c,err_syn            ; cifra >= base
        push bc
        ld a,(nbase)
        call mulacc
        pop bc
        ld a,b
        add a,e
        ld e,a
        jr nc,.l
        inc d
        jr .l
.d:     ld (tv),de
        xor a
        ld (tk),a
        ret

""")
cut("ident:                          ; HL = inizio dell'identificatore", "; ---------------------------------------------------------------- gestori", """ident:                          ; HL = inizio dell'identificatore
        push hl
        call rdtok
        push hl                 ; fine
        ld hl,tokbuf
        call mkkey
        call symfind
        jr c,.unk
        ld de,12
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (tv),de
        ld (tk),a
        pop hl
        pop de
        ret
.unk:   ld a,(pass)
        cp 1
        jr nz,.ext
        ld de,0
        ld (tv),de
        xor a
        ld (tk),a
        pop hl
        pop de
        ret
.ext:   pop bc
        pop hl
        ld de,(ex_dst)
.cp:    ld a,(hl)
        call isid
        jr nc,.cd
        ld (de),a
        inc hl
        inc de
        jr .cp
.cd:    xor a
        ld (de),a
        ld de,0
        ld (tv),de
        ld a,2
        ld (tk),a
        ret

""")
rep(".val:   ld (ix+O_V),e\n        ld (ix+O_V+1),d\n        ld (ix+O_K),a\n        ret",
    ".val:   ld a,(ex_k)\n        ld (ix+O_V),e\n        ld (ix+O_V+1),d\n        ld (ix+O_K),a\n        ret")
cut("defsym2:\n", "defsym:                         ; EQU", """defsym2:
        push af
        push de
        ld hl,labbuf
        call mkkey
        call symfind
        jp nc,err_sym           ; duplicato
        ld a,(nsym)
        cp SYMMAX
        jp nc,err_sym
        ld e,a
        ld d,0
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; x15
        ld de,SYMTAB
        add hl,de
        ex de,hl                ; DE = record
        ld a,(nsym)
        inc a
        ld (nsym),a
        ld hl,symkey
        ld bc,12
        ldir
        pop hl                  ; valore
        pop af                  ; tipo
        ld (de),a
        inc de
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        ret

""")
cut(".w16:   ld a,(OP1+O_C)\n        cp 2\n        jp nz,err_syn\n        ld a,(OP2+O_T)", "h_incdec:", """.w16:   ld a,(OP1+O_C)
        cp 2
        jp nz,err_syn
        ld a,(OP2+O_T)
        cp T_R16
        jp nz,err_syn
        ld ix,OP1
        ld a,(cparam)
        or a
        jr z,.add
        ld b,4Ah
        cp 1
        jr z,.ed
        ld b,42h
        cp 3
        jp nz,err_syn
.ed:    ld a,(OP1+O_P)
        or a
        jp nz,err_syn           ; ADC/SBC solo HL
        ld a,0EDh
        call emb
        ld a,(OP2+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        call emb
        jp asmline.eol
.add:   call emp
        ld a,(OP2+O_C)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,9
        call emb
        jp asmline.eol

""")
cut(".rr:    ld a,(OP1+O_P)\n        ld b,a\n        ld a,(OP2+O_P)\n        or b", "h_jp:", """.rr:    ld a,(OP1+O_P)
        ld b,a
        ld a,(OP2+O_P)
        ld c,a
        ld a,b
        or a
        jr z,.o1
        ld a,c
        or a
        jp nz,err_syn           ; entrambi indicizzati
        ld ix,OP1
        jr .chk
.o1:    ld ix,OP2
.chk:   ld a,(OP1+O_C)
        cp 6
        jr nz,.ok
        ld a,(OP2+O_C)
        cp 6
        jp z,err_syn            ; LD (HL),(HL)
.ok:    call emp
        ld a,(OP1+O_C)
        add a,a
        add a,a
        add a,a
        add a,40h
        ld hl,OP2+O_C
        add a,(hl)
        call emb
        call emdisp
        jp asmline.eol

""")
cut("jr_target:", "h_jr:", """jr_target:                      ; IX = operando: A = spostamento (pc_off e' gia' oltre l'opcode)
        ld a,(pass)
        cp 2
        jr z,.p2
        xor a
        ret
.p2:    ld a,(ix+O_K)
        cp 1
        jp nz,err_syn
        ld l,(ix+O_V)
        ld h,(ix+O_V+1)
        ld de,(pc_off)
        inc de
        or a
        sbc hl,de
        ld e,l
        ld a,h
        or a
        jr z,.pos
        cp 0FFh
        jp nz,err_rng
        bit 7,e
        jp z,err_rng
        jr .o
.pos:   bit 7,e
        jp nz,err_rng
.o:     ld a,e
        ret

""")
t = t.replace("""        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        call emb8""", """        ld a,(ex_k)
        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        call emb8""")
t = t.replace("""        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        call emitv""", """        ld a,(ex_k)
        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        call emitv""")
rep("""        call expr
        ld (ix+O_V),e
        ld (ix+O_V+1),d
        ld (ix+O_K),a
        or a
        jp nz,err_syn
        ld a,e
        ld c,a""", """        call expr
        ld a,(ex_k)
        or a
        jp nz,err_syn
        ld a,e
        ld c,a""")
open(p, 'w', encoding='latin-1', newline='').write(t)
print('ok')
