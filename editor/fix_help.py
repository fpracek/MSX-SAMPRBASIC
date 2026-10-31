def rw(p, f):
    t = open(p, encoding='latin-1', newline='').read()
    nl = '\r\n' if '\r\n' in t else '\n'
    t = f(t.replace('\r\n', '\n'))
    open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))


def rep(t, a, b):
    assert t.count(a) == 1, (a[:70], t.count(a))
    return t.replace(a, b)


def ed(t):
    t = rep(t, "kutmp   equ RAMB+0445h ", """helpstr equ RAMB+0448h              ; 16 byte: argomento di help (maiuscolo, 12 caratteri con riempimento a zero)
hlptop  equ RAMB+0458h              ; w  prima riga visibile del testo di help
hlpbeg  equ RAMB+045Ah              ; w  inizio del testo di help
hscr    equ RAMB+045Ch              ; w  area di lavoro (nel gap) con il testo di help
kutmp   equ RAMB+0445h """)
    # stringhe dei tasti: F6 = Help sulla parola, F7 = Indice (aprono il menu Help: 0Ah, poi la lettera rapida)
    t = rep(t, "        BIOS KILBUF             ; scarta i tasti in attesa (ripetizioni, F5 del lancio precedente)\n",
            """        ld hl,0F8CFh            ; F6 (Shift+F1): menu Help + "W" = aiuto sulla parola sotto il cursore
        ld (hl),0Ah
        inc hl
        ld (hl),'W'
        inc hl
        ld (hl),0
        ld hl,0F8DFh            ; F7 (Shift+F2): menu Help + "I" = indice
        ld (hl),0Ah
        inc hl
        ld (hl),'I'
        inc hl
        ld (hl),0
        BIOS KILBUF             ; scarta i tasti in attesa (ripetizioni, F5 del lancio precedente)
""")
    # menu Help
    t = rep(t, "        db 20,2\n        dw it_help\n", "        db 20,5\n        dw it_help\n")
    t = rep(t, "it_help: dw l_help,s_none,k_help\n        db 'S'\n        dw l_about,s_none,k_about\n        db 'A'\n",
            "it_help: dw l_hindex,s_f7,k_hindex\n        db 'I'\n        dw l_htopic,s_none,k_htopic\n        db 'T'\n        dw l_hword,s_f6,k_hword\n        db 'W'\n        dw l_help,s_none,k_help\n        db 'S'\n        dw l_about,s_none,k_about\n        db 'A'\n")
    t = rep(t, "l_help:   db \"Shortcuts\",0\n", "l_help:   db \"Shortcuts\",0\nl_hindex: db \"Index\",0\nl_htopic: db \"Topic...\",0\nl_hword:  db \"On word\",0\ns_f6:     db \"F6\",0\ns_f7:     db \"F7\",0\ns_topicp: db \"Help topic: \",0\nm_nohelp: db \"HELP.IDX / HELP.TXT not found\",0\nm_helpmem: db \"Not enough free memory for help\",0\nm_nohlp1: db \"No help for \",0\nabout_txt: db 0,\"SamPr Basic 1.0\",0,\"2026 Fausto Pracek\",0,0\n")
    t = rep(t, 'm_keys:   db "Esc,F1-F4=menu F5=run Ctrl+S/W/O/Q file Ctrl+C/X/V clip Ctrl+Z/Y undo Ctrl+F/G/T find",0',
            'm_keys:   db "Esc,F1-F4=menu F5=run F6=help on word F7=help index Ctrl+S/W/O/Q file Ctrl+C/X/V clip Ctrl+Z/Y undo Ctrl+F/G/T find",0')
    # About: finestra con due righe e attesa di un tasto
    t = rep(t, "k_about:\n        ld hl,m_about\n        ld (msgptr),hl\n        ret\n", """k_about:                        ; finestra: "SamPr Basic 1.0" / "2026 Fausto Pracek"; un tasto la chiude
        call ptr_hide
        ld hl,about_txt
        ld d,9
.l:     push de
        push hl
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,27
        ld (hl),' '
        ldir
        pop hl
        ld de,rowbuf+4
        call strcpy
        inc hl                  ; stringa successiva
        push hl
        ld hl,rowbuf
        ld b,28
.o:     set 7,(hl)
        inc hl
        djnz .o
        ld a,(sw)
        sub 28
        srl a
        ld e,a
        pop hl
        pop de                  ; D = riga
        push hl
        push de
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld b,28
        ld c,VDPD
        otir
        pop de
        pop hl
        inc d
        ld a,d
        cp 13
        jr nz,.l
        BIOS CHGET
        jp mark_text
""")
    # ROM: nessun disco
    t = rep(t, "k_run:\nk_quit: ld hl,m_nodisk\n", "k_run:\nk_hindex:\nk_htopic:\nk_hword:\nk_quit: ld hl,m_nodisk\n")
    return t


rw('editor.asm', ed)


def fi(t):
    t += """
; ---------------------------------------------------------------- Help (solo .COM): HELP.TXT + HELP.IDX
; HELP.IDX: record da 17 byte = nome (12, maiuscolo, riempito con zeri), posizione in HELP.TXT (3 byte), lunghezza (2 byte);
; un record con il primo byte 0 chiude l'indice. L'argomento si legge con un accesso casuale e si mostra a pagine.
hnorm:                          ; HELPSTR -> maiuscolo, riempito con zeri fino a 12; Z se vuoto
        ld hl,helpstr
        ld b,12
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.pad
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 20h
.u:     ld (hl),a
        inc hl
        inc c
        djnz .l
        jr .d
.pad:   ld (hl),0
        inc hl
        djnz .pad
.d:     ld a,c
        or a
        ret

hword_get:                      ; parola sotto il cursore -> HELPSTR (vuota se non c'e')
        ld hl,helpstr
        ld (hl),0
        ld hl,(cur)
.l:     ld a,h
        or l
        jr z,.r
        dec hl
        call getb
        call kw_isw
        jr c,.l
        inc hl
.r:     ld b,0
.c:     ld a,b
        cp 12
        ret nc
        push hl
        ld de,(len)
        or a
        sbc hl,de
        pop hl
        ret nc
        call getb
        ld c,a
        call kw_isw
        ret nc
        push hl
        ld hl,helpstr
        ld e,b
        ld d,0
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),0
        pop hl
        inc hl
        inc b
        jr .c

k_hindex:
        ld hl,helpstr
        ld de,s_hindexn
        ex de,hl
        ld bc,6
        ldir
        jr help_lookup

k_hword:
        call hword_get
        ld a,(helpstr)
        or a
        jr nz,help_lookup
k_htopic:
        call hword_get
        ld hl,s_topicp
        ld de,helpstr
        ld b,12
        ld c,2
        call prompt_line
        ret c
help_lookup:                    ; HELPSTR = argomento
        call hnorm
        ret z
        ld hl,(len)             ; il gap in fondo al testo e' l'area di lavoro
        call gap_to_ofs
        ld hl,(gsz)
        ld de,4200
        or a
        sbc hl,de
        jp c,.nomem
        ld hl,(gs)
        ld de,BUF
        add hl,de
        ld (hscr),hl
        ld hl,s_hidx
        call hopen
        jp nz,.nofile
        ld de,(hscr)
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,3700
        ld c,F_BRD
        call BDOS
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld ix,(hscr)
.scan:  ld a,(ix+0)
        or a
        jr z,.nf
        ld b,12
        ld hl,helpstr
        push ix
        pop de
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.no
        inc hl
        inc de
        djnz .cmp
        jr .found
.no:    ld de,17
        add ix,de
        jr .scan
.found: ld l,(ix+12)
        ld h,(ix+13)
        ld (tmp1),hl
        ld a,(ix+14)
        ld (tmp2),a
        ld l,(ix+15)
        ld h,(ix+16)
        ld de,4000
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.lok
        ld hl,4000
.lok:   ld (tmp3),hl
        ld hl,s_htxt
        call hopen
        jp nz,.nofile
        ld hl,(tmp1)
        ld (fcb+33),hl
        ld a,(tmp2)
        ld (fcb+35),a
        ld de,(hscr)
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,(tmp3)
        ld c,F_BRD
        call BDOS
        ld (tmp3),hl
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,(hscr)
        ld de,(tmp3)
        add hl,de
        ld (hl),0
        call help_pager
        jr .done
.nf:    ld hl,msgbuf
        ex de,hl
        ld hl,m_nohlp1
        call strcpy
        ld hl,helpstr
        ld b,12
.nc:    ld a,(hl)
        or a
        jr z,.ne
        ld (de),a
        inc hl
        inc de
        djnz .nc
.ne:    xor a
        ld (de),a
        ld hl,msgbuf
        ld (msgptr),hl
        jr .done
.nofile:
        ld hl,m_nohelp
        ld (msgptr),hl
        jr .done
.nomem: ld hl,m_helpmem
        ld (msgptr),hl
        ret
.done:  call set_sentinel
        jp mark_text

s_hindexn: db "INDEX",0
s_hidx:    db "HELP    IDX"
s_htxt:    db "HELP    TXT"

hopen:                          ; HL = nome FCB (11 byte): apre il file; NZ se manca
        push hl
        ld hl,fcb
        ld de,fcb+1
        ld bc,36
        ld (hl),0
        ldir
        pop hl
        ld de,fcb+1
        ld bc,11
        ldir
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        ret nz
        call fcb_rec1
        xor a
        ret

hnext:                          ; HL = riga -> HL = riga successiva (invariata se e' l'ultima)
        push hl
.l:     ld a,(hl)
        or a
        jr z,.end
        inc hl
        cp 0Ah
        jr nz,.l
        ld a,(hl)
        or a
        jr z,.end
        pop af
        ret
.end:   pop hl
        ret

hprev:                          ; HL = riga -> HL = riga precedente
        ld de,(hlpbeg)
        push hl
        or a
        sbc hl,de
        pop hl
        ret z
        dec hl
.l:     push hl
        or a
        sbc hl,de
        pop hl
        ret z
        dec hl
        ld a,(hl)
        cp 0Ah
        jr nz,.l
        inc hl
        ret

help_pager:                     ; testo a (HSCR), terminato da 0: Su/Giu, PgSu/PgGiu o Spazio, Home, Esc chiude
        call ptr_hide
        ld hl,(hscr)
        ld (hlpbeg),hl
        ld (hlptop),hl
.draw:  ld hl,msgbuf
        ex de,hl
        ld hl,s_hlp1
        call strcpy
        ld hl,helpstr
        ld b,12
.nm:    ld a,(hl)
        or a
        jr z,.nme
        ld (de),a
        inc hl
        inc de
        djnz .nm
.nme:   ld hl,s_hlp2
        call strcpy
        xor a
        ld (de),a
        ld hl,msgbuf
        call show_row0
        ld hl,(hlptop)
        ld d,1
.row:   push de
        push hl
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        pop hl
        ld de,rowbuf
        ld a,(swm1)
        ld b,a
.cp:    ld a,(hl)
        or a
        jr z,.wr
        inc hl
        cp 0Ah
        jr z,.wr
        cp 0Dh
        jr z,.cp
        ld c,a
        ld a,b
        or a
        jr z,.cp
        ld a,c
        ld (de),a
        inc de
        dec b
        jr .cp
.wr:    pop de
        push hl
        push de
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
        ld c,VDPD
        otir
        pop de
        pop hl
        inc d
        ld a,d
        cp 23
        jr nz,.row
.key:   BIOS CHGET
        cp 1Bh
        ret z
        cp 'q'
        ret z
        cp 'Q'
        ret z
        cp 1Fh
        jr z,.dn
        cp 1Eh
        jr z,.up
        cp 0Eh
        jr z,.pd
        cp ' '
        jr z,.pd
        cp 10h
        jr z,.pu
        cp 0Bh
        jr z,.hm
        jr .key
.dn:    ld hl,(hlptop)
        call hnext
        jr .set
.up:    ld hl,(hlptop)
        call hprev
        jr .set
.pd:    ld b,22
.p1:    push bc
        ld hl,(hlptop)
        call hnext
        ld (hlptop),hl
        pop bc
        djnz .p1
        jp .draw
.pu:    ld b,22
.p2:    push bc
        ld hl,(hlptop)
        call hprev
        ld (hlptop),hl
        pop bc
        djnz .p2
        jp .draw
.hm:    ld hl,(hlpbeg)
.set:   ld (hlptop),hl
        jp .draw

s_hlp1: db "Help: ",0
s_hlp2: db "  Esc=close Up/Dn PgUp/PgDn",0
"""
    return t


rw('fileio.asm', fi)
print('ok')
