p = 'editor.asm'
t = open(p, encoding='latin-1', newline='').read().replace('\r\n', '\n')
a = t.index("kw_row:                         ; ROWBUF")
b = t.index("; ---------------------------------------------------------------- mouse\nmouse_init:")
new = """kw_row:                         ; ROWBUF -> flag di colore (parole chiave) -> tabella di blink della riga (RROW+1)
        ld hl,kwf
        ld de,kwf+1
        ld (hl),0
        ld bc,9
        ldir
        ld a,' '
        ld (rowbuf+VCOLS),a     ; sentinella: la scansione delle parole non esce dalla riga
        ld hl,rowbuf
        ld b,0
        xor a
        ld (kwq),a
        ld d,high kwcls
.nx:    ld a,b
        cp VCOLS
        jp nc,.out
        ld e,(hl)
        ld a,(de)
        or a
        jr z,.adv
        cp 1
        jr z,.word
        cp 2
        jr z,.quote
        jp .out                 ; apostrofo: commento fino a fine riga
.adv:   inc hl
        inc b
        jr .nx
.quote: ld a,(kwq)
        xor 1
        ld (kwq),a
        jr .adv
.word:  ld a,b
        ld (kwcol),a
        ld (kwptr),hl
        ld c,0
.wl:    inc hl
        inc b
        inc c
        ld e,(hl)
        ld a,(de)
        cp 1
        jr z,.wl
        ld a,(kwq)              ; dentro una stringa: nessuna parola chiave
        or a
        jr nz,.nx
        ld a,c
        cp 2
        jr c,.nx                ; una sola lettera
        cp 11
        jr nc,.nx               ; troppo lunga
        ld (kwlen),a
        push hl
        push bc
        ld hl,(kwptr)
        ld a,(hl)
        and 7Fh
        cp '9'+1
        jr c,.nokw              ; comincia con una cifra (o e' un simbolo)
        ld de,kwword
        ld b,c
.cp:    ld a,(hl)
        and 7Fh
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 20h
.u:     ld (de),a
        inc hl
        inc de
        djnz .cp
        call kw_find
        jr nz,.nokw
        call kw_mark
        ld a,(kwlen)
        cp 3
        jr nz,.nokw
        ld hl,kwword            ; REM: il resto della riga e' commento
        ld a,(hl)
        cp 'R'
        jr nz,.nokw
        inc hl
        ld a,(hl)
        cp 'E'
        jr nz,.nokw
        inc hl
        ld a,(hl)
        cp 'M'
        jr nz,.nokw
        pop bc
        pop hl
        jr .out
.nokw:  pop bc
        pop hl
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
# tabella di classi (allineata a 256 byte) dopo kw_isw non serve piu': la si include coi dati
t = t.replace('        INCLUDE "kwtab.inc"\n', '        INCLUDE "kwtab.inc"\n')
open(p, 'w', encoding='latin-1', newline='').write(t)

g = open('gen_kw.py').read()
if 'kwcls' not in g:
    g = g.replace("open(os.path.join(HERE, 'kwtab.inc'), 'w', newline='\\n').write('\\n'.join(out) + '\\n')", """out.append('        ALIGN 256')
out.append('kwcls:')
for r in range(16):
    row = []
    for c in range(16):
        ch = (r * 16 + c) & 127
        ci = chr(ch)
        if ci == '"':
            v = 2
        elif ci == "'":
            v = 3
        elif ci.isalnum() and ch < 128 or ci in '_$':
            v = 1
        else:
            v = 0
        row.append(str(v))
    out.append('        db ' + ','.join(row))
open(os.path.join(HERE, 'kwtab.inc'), 'w', newline='\\n').write('\\n'.join(out) + '\\n')""")
    open('gen_kw.py', 'w').write(g)
print('ok')
