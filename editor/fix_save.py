def rw(p, f):
    t = open(p, encoding='latin-1', newline='').read()
    nl = '\r\n' if '\r\n' in t else '\n'
    t = f(t.replace('\r\n', '\n'))
    open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))


def rep(t, a, b):
    assert t.count(a) == 1, (a[:70], t.count(a))
    return t.replace(a, b)


rw('editor.asm', lambda t: rep(t, "cmdok   equ RAMB+0426h ",
    "oldsz   equ RAMB+0427h              ; w  dimensione del file prima di una sovrascrittura in posto\ninplace equ RAMB+0429h              ; b  il salvataggio sovrascrive il file esistente\ncmdok   equ RAMB+0426h "))


def f(t):
    old = """.ncl:   call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS               ; l'errore (file inesistente) e' ignorato
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr z,.ok
        ld hl,m_cantcreate
        ld (msgptr),hl
        scf
        ret
.ok:    call fcb_rec1
        xor a
        ld (ioerr),a
"""
    new = """.ncl:   call mk_fcb
        xor a
        ld (inplace),a
        ld de,fcb               ; sovrascrittura in posto: niente cancellazione e creazione (risparmia ~2 s di disco)
        ld c,F_OPEN
        call BDOS
        or a
        jr nz,.create           ; il file non esiste
        ld hl,(fcb+18)          ; dimensione vecchia (FCB+16, 4 byte): oltre 64 KB si ricrea
        ld a,h
        or l
        jr nz,.recreate
        ld hl,(fcb+16)
        ld (oldsz),hl
        ex de,hl
        ld hl,(len)             ; stima della nuova dimensione: testo + CR + ^Z + 1 KB di tolleranza
        ld bc,(nlines)
        add hl,bc
        ld bc,1025
        add hl,bc
        or a
        sbc hl,de
        jr c,.recreate          ; il file e' molto piu' lungo del testo: meglio ricrearlo
        ld a,1
        ld (inplace),a
        jr .ok
.recreate:
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
.create: call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS               ; l'errore (file inesistente) e' ignorato
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr z,.ok
        ld hl,m_cantcreate
        ld (msgptr),hl
        scf
        ret
.ok:    call fcb_rec1
        xor a
        ld (ioerr),a
"""
    t = rep(t, old, new)
    t = rep(t, "        call flush_io\n        ld de,fcb\n        ld c,F_CLOSE\n        call BDOS\n        ld a,(ioerr)\n        or a\n        jr nz,.err\n        xor a\n        ld (modified),a\n        inc a\n        ld (onfile),a\n        ld hl,(nbytes)\n",
            """        call flush_io
        ld a,(inplace)
        or a
        jr z,.cl
        ld hl,(nbytes)          ; sovrascrittura piu' corta del file di prima: ^Z dopo il testo (il resto si ignora)
        ld de,(oldsz)
        ex de,hl
        or a
        sbc hl,de
        jr nc,.cl               ; vecchia dimensione <= nuova
        ld a,1Ah
        call put_io
        call flush_io
        ld hl,(nbytes)
        dec hl
        ld (nbytes),hl
.cl:    ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld a,(ioerr)
        or a
        jr nz,.err
        xor a
        ld (modified),a
        inc a
        ld (onfile),a
        ld hl,(nbytes)
""")
    return t


rw('fileio.asm', f)


def q(t):
    old = ".ok:    ld de,SRC\n        add hl,de\n        ld (hl),0\n        ret\n"
    new = """.ok:    ld de,SRC
        add hl,de
        ld (hl),0
        ld hl,SRC
.z:     ld a,(hl)               ; ^Z: il resto del file (residuo di un salvataggio in posto piu' corto) si ignora
        or a
        ret z
        cp 1Ah
        jr z,.cut
        inc hl
        jr .z
.cut:   ld (hl),0
        ret
"""
    return rep(t, old, new)


import os
os.chdir('../onmsx')
rw('qbc.asm', q)
print('ok')
