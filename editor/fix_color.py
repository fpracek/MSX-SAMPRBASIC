p = 'editor.asm'
t = open(p, encoding='latin-1', newline='').read()
nl = '\r\n' if '\r\n' in t else '\n'
t = t.replace('\r\n', '\n')


def rep(a, b):
    global t
    assert t.count(a) == 1, (a[:70], t.count(a))
    t = t.replace(a, b)


# memoria: 64 byte nuovi prima di UNDO / BUF
rep("UNDO    equ RAMB+0400h          ; registro di annullamento: C400h-CFFFh\nUNDOSZ  equ 0C00h",
    "UNDO    equ RAMB+0440h          ; registro di annullamento: C440h-CFFFh\nUNDOSZ  equ 0BC0h")
rep("BUF     equ RAMB+0400h          ; gap buffer (fino a bufend)", "BUF     equ RAMB+0440h          ; gap buffer (fino a bufend)")
rep("; ---- RAM\n", """; ---- RAM
kwf     equ RAMB+0400h              ; 10 byte: flag di colore della riga (un bit per colonna)
kwword  equ RAMB+040Ah              ; 16 byte: parola in esame (maiuscola)
kwptr   equ RAMB+041Ah              ; w
kwq     equ RAMB+041Ch              ; b  dentro una stringa tra virgolette
kwlen   equ RAMB+041Dh              ; b
kwcol   equ RAMB+041Eh              ; b
curch   equ RAMB+041Fh              ; b  carattere sotto il cursore
cph     equ RAMB+0420h              ; b  fase del cursore (1 = visibile)
blcnt   equ RAMB+0421h              ; b  contatore di quadri
""")

# colori: R#12 = colore alternativo (parole chiave); R#13 = i caratteri col bit acceso restano sempre nel colore alternativo
rep("""        ld a,04Fh               ; R#12: colori di blink (blu su bianco)
        out (VDPC),a
        ld a,8Ch
        out (VDPC),a
        ld a,055h               ; R#13: periodi di blink
        out (VDPC),a""", """        ld a,KWCOL              ; R#12: colori alternativi (parole chiave)
        out (VDPC),a
        ld a,8Ch
        out (VDPC),a
        ld a,KWBLINK            ; R#13: nessuna alternanza, i caratteri flaggati restano nel colore alternativo
        out (VDPC),a""")
rep("MPAD    equ 12 ", "KWCOL   equ 0B4h               ; parole chiave: giallo chiaro su blu\nKWBLINK equ 0F0h               ; R#13\nMPAD    equ 12 ")

# main: cursore lampeggiante con il contatore di quadri
rep("""main:   halt
        call mouse_poll""", """main:   halt
        ld hl,blcnt
        inc (hl)
        ld a,(hl)
        and 1Fh
        call z,cur_blink
        call mouse_poll""")

# refresh: ridisegno cancella il cursore, il cursore riparte visibile
rep("""refresh:
        call ptr_hide
        ld a,(dirty)
        and 1
        call nz,redraw_text
        xor a
        ld (dirty),a""", """refresh:
        call ptr_hide
        ld a,(dirty)
        and 1
        jr z,.nr
        ld a,0FFh               ; il ridisegno del testo cancella il cursore disegnato
        ld (blx),a
        call redraw_text
.nr:    ld a,1
        ld (cph),a
        xor a
        ld (blcnt),a
        ld (dirty),a""")

# redraw_text: flag di colore per riga
rep("""        ld (reof),a
.row:   call build_row
        ld a,(rrow)""", """        ld (reof),a
.row:   call build_row
        call kw_row
        ld a,(rrow)""")

# cursor_show: glifo inverso al posto del lampeggio hardware
a = t.index("cursor_show:\n")
b = t.index("; ---------------------------------------------------------------- mouse\nmouse_init:")
t = t[:a] + """cur_blink:                      ; ogni 32 quadri: il cursore appare/scompare
        ld a,(cph)
        xor 1
        ld (cph),a
        call ptr_hide
        call cursor_show
        jp ptr_show

cursor_show:                    ; il cursore e' il glifo inverso (bit 7) della cella; (blx, bly) = cella disegnata
        ld a,(blx)
        cp 0FFh
        jr z,.nc
        ld e,a
        ld a,(bly)
        ld d,a
        ld a,(curch)
        call put_cell
        ld a,0FFh
        ld (blx),a
.nc:    ld a,(menuopen)
        or a
        ret nz                  ; con il menu aperto il cursore non si mostra
        ld a,(cph)
        or a
        ret z
        call cur_col
        ld de,(hscroll)
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        cp VCOLS
        ret nc
        ld (tmpd),a             ; x
        ld hl,(curline)
        ld de,(topline)
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        cp VROWS
        ret nc
        inc a
        ld d,a
        ld a,(tmpd)
        ld e,a
        ld (blx),a
        ld a,d
        ld (bly),a
        call get_cell
        ld (curch),a
        or 80h
        jp put_cell

kw_isw:                         ; A -> CF = 1 se e' 0-9 A-Z a-z _ $
        cp '$'
        jr z,.y
        cp '_'
        jr z,.y
        cp '0'
        jr c,.n
        cp '9'+1
        jr c,.y
        and 0DFh
        cp 'A'
        jr c,.n
        cp 'Z'+1
        jr c,.y
.n:     or a
        ret
.y:     scf
        ret

kw_find:                        ; KWWORD (lunghezza KWLEN) in tabella -> Z se e' una parola chiave
        ld a,(kwword)
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
        ld hl,kwidx
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
.e:     ld a,(hl)
        or a
        jr z,.no
        ld b,a
        ld a,(kwlen)
        cp b
        jr nz,.skip
        push hl
        inc hl
        ld de,kwword
.c:     ld a,(de)
        cp (hl)
        jr nz,.mm
        inc hl
        inc de
        djnz .c
        pop hl
        xor a
        ret
.mm:    pop hl
.skip:  ld c,(hl)
        ld b,0
        add hl,bc
        inc hl
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
        ld hl,rowbuf
        ld b,0
        xor a
        ld (kwq),a
.nx:    ld a,b
        cp VCOLS
        jp nc,.out
        ld a,(hl)
        and 7Fh
        cp '"'
        jr nz,.nq
        ld a,(kwq)
        xor 1
        ld (kwq),a
        jr .adv
.nq:    cp 27h                  ; apostrofo: commento fino a fine riga
        jp z,.out
        ld c,a
        ld a,(kwq)
        or a
        ld a,c
        jr nz,.adv
        call kw_isw
        jr c,.word
.adv:   inc hl
        inc b
        jr .nx
.word:  ld a,b
        ld (kwcol),a
        ld (kwptr),hl
        ld c,0
.wl:    ld a,b
        cp VCOLS
        jr nc,.we
        ld a,(hl)
        and 7Fh
        call kw_isw
        jr nc,.we
        inc hl
        inc b
        inc c
        jr .wl
.we:    ld a,c
        ld (kwlen),a
        cp 17
        jr nc,.nx
        push hl
        push bc
        ld hl,(kwptr)
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
        ld a,(kwword)
        cp '0'
        jr c,.look
        cp '9'+1
        jr c,.nokw              ; comincia con una cifra
.look:  call kw_find
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

""" + t[b:]
# glifi: la tabella delle parole chiave
rep("glyphs: db 000h,000h,030h,078h,0FCh,000h,000h,000h     ; 1 freccia su", "        INCLUDE \"kwtab.inc\"\nglyphs: db 000h,000h,030h,078h,0FCh,000h,000h,000h     ; 1 freccia su")
open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))
print('ok')
