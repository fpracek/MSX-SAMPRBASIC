p = 'editor.asm'
t = open(p, encoding='latin-1', newline='').read().replace('\r\n', '\n')
a = t.index("kw_find:                        ; KWWORD")
b = t.index("; ---------------------------------------------------------------- mouse\nmouse_init:")
new = """kw_find:                        ; HL = parola, C = lunghezza (2..10) -> Z se e' una parola chiave (HL conservato)
        ld d,high kwupt
        ld e,(hl)
        ld a,(de)
        cp '_'
        jr nz,.l
        ld a,26
        jr .ix
.l:     sub 'A'
        jr c,.no
        cp 26
        jr nc,.no
.ix:    add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,kwidx
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        pop ix                  ; IX = elenco delle parole che iniziano con quella lettera
        pop hl
        ld d,high kwupt
.e:     ld a,(ix+0)
        or a
        jr z,.no
        cp c
        jr nz,.skip
        push hl
        ld b,c
        inc ix
.c:     ld e,(hl)
        ld a,(de)
        cp (ix+0)
        jr nz,.mm
        inc hl
        inc ix
        djnz .c
        pop hl
        xor a
        ret
.mm:    pop hl                  ; IX e' dentro la voce: B caratteri restano da saltare
        push bc
        ld c,b
        ld b,0
        add ix,bc
        pop bc
        jr .e
.skip:  push bc
        ld c,a
        ld b,0
        add ix,bc
        inc ix
        pop bc
        jr .e
.no:    or 1
        ret

kw_mark:                        ; flag per le colonne KWCOL .. KWCOL+KWLEN-1
        ld a,(kwcol)
        ld b,a
        ld a,(kwlen)
        ld c,a
.m:     ld a,b
        rrca
        rrca
        rrca
        and 1Fh
        ld e,a
        ld d,0
        ld hl,kwf
        add hl,de
        ld a,b
        and 7
        ld e,a
        ld a,80h
        inc e
        dec e
        jr z,.nm
.sh:    srl a
        dec e
        jr nz,.sh
.nm:    or (hl)
        ld (hl),a
        inc b
        dec c
        jr nz,.m
        ret

kw_row:                         ; ROWBUF -> flag di colore (parole chiave) -> tabella di blink della riga (RROW+1)
        ld hl,kwf
        ld de,kwf+1
        ld (hl),0
        ld bc,9
        ldir
        xor a
        ld (rowbuf+VCOLS),a     ; sentinella (classe 4): la scansione non esce dalla riga
        ld (kwq),a
        ld hl,rowbuf-1
        ld d,high kwcls
.nx:    inc hl
        ld e,(hl)
        ld a,(de)
        or a
        jr z,.nx
        cp 1
        jr z,.word
        cp 2
        jr z,.quote
        cp 3
        jr nz,.out              ; sentinella
        jr .out                 ; apostrofo: commento fino a fine riga
.quote: ld a,(kwq)
        xor 1
        ld (kwq),a
        jr .nx
.word:  ld (kwptr),hl
        ld c,0
.wl:    inc hl
        inc c
        ld e,(hl)
        ld a,(de)
        cp 1
        jr z,.wl
        dec hl                  ; HL = ultimo carattere della parola
        ld a,(kwq)
        or a
        jr nz,.nx               ; dentro una stringa: nessuna parola chiave
        ld a,c
        cp 2
        jr c,.nx                ; una sola lettera
        cp 11
        jr nc,.nx               ; troppo lunga
        push hl
        ld hl,(kwptr)
        ld a,(hl)
        and 7Fh
        cp 40h
        jr c,.nokw              ; comincia con una cifra
        call kw_find
        jr nz,.nokw
        ld a,l                  ; colonna = KWPTR - ROWBUF
        sub low rowbuf
        ld (kwcol),a
        ld a,c
        ld (kwlen),a
        call kw_mark
        ld a,c
        cp 3
        jr nz,.nokw
        ld hl,(kwptr)           ; REM: il resto della riga e' commento
        ld d,high kwupt
        ld e,(hl)
        ld a,(de)
        cp 'R'
        jr nz,.nokw
        inc hl
        ld e,(hl)
        ld a,(de)
        cp 'E'
        jr nz,.nokw
        inc hl
        ld e,(hl)
        ld a,(de)
        cp 'M'
        jr nz,.nokw
        pop hl
        jr .out
.nokw:  pop hl
        ld d,high kwcls
        jp .nx
.out:   ld a,(rrow)
        inc a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; riga * 10
        ld de,BLKT
        add hl,de
        call vsetw
        ld hl,kwf
        ld b,10
        ld c,VDPD
        otir
        ret

"""
t = t[:a] + new + t[b:]
open(p, 'w', encoding='latin-1', newline='').write(t)

g = open('gen_kw.py').read()
g = g.replace("""        elif ci == "'":
            v = 3""", """        elif ci == "'":
            v = 3
        elif ch == 0 and (r * 16 + c) < 128:
            v = 4""")
g = g.replace("open(os.path.join(HERE, 'kwtab.inc'), 'w', newline='\\n')", """out.append('kwupt:')
for r in range(16):
    out.append('        db ' + ','.join(str((lambda x: x - 32 if 97 <= x <= 122 else x)((r * 16 + c) & 127)) for c in range(16)))
open(os.path.join(HERE, 'kwtab.inc'), 'w', newline='\\n')""")
open('gen_kw.py', 'w').write(g)
print('ok')
