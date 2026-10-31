import os


def rw(p, f):
    t = open(p, encoding='latin-1', newline='').read()
    nl = '\r\n' if '\r\n' in t else '\n'
    t = f(t.replace('\r\n', '\n'))
    open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))


def rep(t, a, b):
    assert t.count(a) == 1, (a[:70], t.count(a))
    return t.replace(a, b)


# ---- runtime: timbro della costruzione (data/ora + variante) dopo RT_SIZE
rw('rtabi.inc', lambda t: rep(t, "RT_SIZE   equ RT_DBG+3 ",
    "RT_STAMP  equ RT_DBG+5          ; 21 byte: data, ora e variante della costruzione (il compilatore .COM li confronta)\nRT_STAMPLEN equ 21\nRT_SIZE   equ RT_DBG+3 "))
rw('rtcom.asm', lambda t: rep(t, "        ASSERT $ == RT_SIZE\n        dw rt_prog-RTB\n",
    """        ASSERT $ == RT_SIZE
        dw rt_prog-RTB
        ASSERT $ == RT_STAMP
        db __DATE__," ",__TIME__
        IFDEF DBGRT
        db "D"
        ELSE
        db "N"
        ENDIF
        ASSERT $ == RT_STAMP+RT_STAMPLEN
"""))


def rtend(t):
    return rep(t, ".d:     ld (hl),0Dh\n        ld a,b\n        inc a\n        ld (0080h),a\n        ld hl,ldr_img\n        ld de,0C000h",
               ".d:     ld (hl),' '             ; \" +\": il sorgente non e' cambiato dopo la compilazione (l'editor puo' rilanciare NOME.COM)\n        inc hl\n        ld (hl),'+'\n        inc hl\n        ld (hl),0Dh\n        inc b\n        inc b\n        ld a,b\n        inc a\n        ld (0080h),a\n        ld hl,ldr_img\n        ld de,0C000h")


rw('rtcom.asm', rtend)


def q(t):
    # tabelle +100h
    t = rep(t, "SRC     equ 4C00h\nSRCMAX  equ 33FEh", "SRC     equ 4D00h\nSRCMAX  equ 32FEh")
    t = rep(t, "LABT    equ 3C00h", "LABT    equ 3D00h")
    t = rep(t, "VART    equ 4380h", "VART    equ 4480h")
    t = rep(t, "BLKS    equ 49C0h", "BLKS    equ 4AC0h")
    t = rep(t, "FCBSV   equ 4B68h", "FCBSV   equ 4C68h")
    t = rep(t, "; Memoria: codice 0100h-3BFFh, tabelle 3C00h-4BFFh, sorgente 4C00h-7FFFh,", "; Memoria: codice 0100h-3CFFh, tabelle 3D00h-4CFFh, sorgente 4D00h-7FFFh,")
    # timbro del runtime: copia dopo il primo blocco
    t = rep(t, "        ld hl,(PART+RT_SIZE-IMGBASE)\n        ld (rtsz),hl\n",
            "        ld hl,(PART+RT_SIZE-IMGBASE)\n        ld (rtsz),hl\n        ld hl,PART+RT_STAMP-IMGBASE      ; timbro della costruzione: serve a riconoscere un NOME.COM gia' pronto\n        ld de,RTSTAMP\n        ld bc,RT_STAMPLEN\n        ldir\n")
    t = rep(t, "rtsz    equ ST+254 ", "RTSTAMP equ 0C200h               ; 21 byte: timbro di RT.BIN (COM)\nRTCHK   equ 0CA00h               ; primo blocco del NOME.COM esistente (dopo la compilazione l'indice NUMBERED non serve piu')\nrtsz    equ ST+254 ")
    # write_output: NOME.COM esistente con lo stesso runtime -> si riscrive solo il codice
    old = """        ld hl,oname
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr z,.m
.err:"""
    new = """        ld hl,oname
        ld (namep),hl
        call mk_fcb
        ld de,fcb               ; NOME.COM esiste gia' con lo stesso runtime? allora si riscrive solo il codice
        ld c,F_OPEN
        call BDOS
        or a
        jr nz,.new
        call fcb_rec1
        ld de,RTCHK
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,1024
        ld c,F_BRD
        call BDOS
        ld a,h
        cp 2
        jr c,.nomatch           ; file troppo corto
        ld hl,RTCHK+RT_STAMP-IMGBASE
        ld de,RTSTAMP
        ld b,RT_STAMPLEN
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.nomatch
        inc hl
        inc de
        djnz .cmp
        ld hl,fcb
        ld de,FCBSV
        ld bc,37
        ldir
        ld hl,(rtsz)            ; il codice va scritto dopo il runtime
        ld (FCBSV+33),hl
        xor a
        ld (FCBSV+35),a
        ld (FCBSV+36),a
        jp .cd
.nomatch:
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,oname
        ld (namep),hl
        call mk_fcb
.new:   ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr z,.m
.err:"""
    t = rep(t, old, new)
    return t


rw('qbc.asm', q)
print('ok')
