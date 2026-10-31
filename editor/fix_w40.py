def rw(p, f):
    t = open(p, encoding='latin-1', newline='').read()
    nl = '\r\n' if '\r\n' in t else '\n'
    t = f(t.replace('\r\n', '\n'))
    open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))


def rep(t, a, b, n=1):
    assert t.count(a) == n, (a[:70], t.count(a))
    return t.replace(a, b)


def ed(t):
    # ---- memoria: nuove variabili prima di UNDO / BUF
    t = rep(t, "UNDO    equ RAMB+0440h          ; registro di annullamento: C440h-CFFFh\nUNDOSZ  equ 0BC0h",
            "UNDO    equ RAMB+0460h          ; registro di annullamento: C460h-CFFFh\nUNDOSZ  equ 0BA0h")
    t = rep(t, "BUF     equ RAMB+0440h          ; gap buffer (fino a bufend)", "BUF     equ RAMB+0460h          ; gap buffer (fino a bufend)")
    t = rep(t, "kwnext  equ RAMB+0423h ", """sw      equ RAMB+0430h              ; b  larghezza dello schermo: 80 (MSX2) o 40 (MSX1)
swm1    equ RAMB+0431h              ; b  sw-1 (colonna della barra verticale = VCOLS)
swm2    equ RAMB+0432h              ; b  sw-2 (colonna della freccia destra)
thv     equ RAMB+0433h              ; b  sw-3 (celle del binario orizzontale)
m2flag  equ RAMB+0434h              ; b  0 = MSX1 (TMS9918: niente tabella di blink, R#12/13/14), altrimenti MSX2 o superiore
vcolsw  equ RAMB+0435h              ; w  VCOLS = sw-1
vcw1    equ RAMB+0437h              ; w  VCOLS-1
nvcw1   equ RAMB+0439h              ; w  -(VCOLS-1)
hmaxw   equ RAMB+043Bh              ; w  HMAX (massimo scroll orizzontale)
hmax1w  equ RAMB+043Dh              ; w  HMAX+1
pattb   equ RAMB+043Fh              ; w  tabella dei pattern: 1000h (80 colonne) o 0800h (40)
mxmax   equ RAMB+0441h              ; w  limite x del mouse = sw*8
rbm2    equ RAMB+0443h              ; w  indirizzo di rowbuf+sw-2
kwnext  equ RAMB+0423h """)
    # ---- avvio: larghezza
    t = rep(t, "        xor a\n        ld (CSRSW),a\n        ld a,80\n        ld (LINL40),a\n        ld (LINLEN),a\n        BIOS INITXT",
            "        xor a\n        ld (CSRSW),a\n        call width_init\n        ld a,(sw)\n        ld (LINL40),a\n        ld (LINLEN),a\n        BIOS INITXT")
    t = rep(t, "vdp_init:\n        xor a                   ; R#14 = 0\n        out (VDPC),a\n        ld a,8Eh\n        out (VDPC),a\n        ld a,0F4h               ; R#7: testo 15 su blu\n        out (VDPC),a\n        ld a,87h\n        out (VDPC),a\n",
            """width_init:                      ; versione MSX (byte 002Dh): 80 colonne su MSX2, 40 su MSX1; parametri di layout
        IFDEF COM
        ld hl,002Dh
        ld a,(EXPTBL)
        call 000Ch              ; RDSLT
        ei
        ELSE
        ld a,(002Dh)
        ENDIF
        ld (m2flag),a
        ld b,80
        ld hl,1000h
        or a
        jr nz,.w
        ld b,40
        ld hl,0800h
.w:     ld (pattb),hl
        ld a,b
        ld (sw),a
        dec a
        ld (swm1),a
        ld l,a
        ld h,0
        ld (vcolsw),hl
        dec hl
        ld (vcw1),hl
        ld a,l
        ld (swm2),a
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (nvcw1),hl
        ld a,(swm2)
        dec a
        ld (thv),a
        ld a,(sw)
        ld l,a
        ld h,0
        ex de,hl
        ld hl,256
        or a
        sbc hl,de               ; 256 - sw = HMAX (MAXCOL - VCOLS + 1)
        ld (hmaxw),hl
        inc hl
        ld (hmax1w),hl
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (mxmax),hl
        ld a,(sw)
        ld l,a
        ld h,0
        ld de,rowbuf-2
        add hl,de
        ld (rbm2),hl
        ret

vdp_init:
        ld a,0F4h               ; R#7: testo 15 su blu
        out (VDPC),a
        ld a,87h
        out (VDPC),a
        ld a,(m2flag)
        or a
        ret z                   ; MSX1: niente R#12/R#13/R#14 (i numeri sopra il 7 si sovrapporrebbero ai registri 0-7)
        xor a                   ; R#14 = 0
        out (VDPC),a
        ld a,8Eh
        out (VDPC),a
""")
    # ---- font: tabella dei pattern variabile
    t = rep(t, "font_load:                      ; 128-255 = copie negate di 0-127 (font gia' in VRAM da INITXT), glifi 1-5 propri\n        ld hl,PATT\n        ld de,PATT+1024\n",
            "font_load:                      ; 128-255 = copie negate di 0-127 (font gia' in VRAM da INITXT), glifi 1-5 propri\n        ld hl,(pattb)\n        ld de,1024\n        add hl,de\n        ex de,hl\n        ld hl,(pattb)\n")
    t = rep(t, "        ld de,PATT\n        add hl,de\n        ex de,hl                ; DE = indirizzo normale", "        ld de,(pattb)\n        add hl,de\n        ex de,hl                ; DE = indirizzo normale")
    # ---- blink
    t = rep(t, "blink_clear:\n        ld hl,BLKT\n        call vsetw\n        ld b,240\n        xor a\n.l:     out (VDPD),a\n        djnz .l\n        ld a,0FFh\n",
            "blink_clear:\n        ld a,(m2flag)\n        or a\n        jr z,.nb                ; MSX1: a 0800h c'e' la tabella dei pattern\n        ld hl,BLKT\n        call vsetw\n        ld b,240\n        xor a\n.l:     out (VDPD),a\n        djnz .l\n.nb:    ld a,0FFh\n")
    t = rep(t, "kw_reset:                       ; testo ridisegnato: i colori si azzerano e si ricalcolano nei tempi morti\n        ld hl,BLKT+10\n",
            "kw_reset:                       ; testo ridisegnato: i colori si azzerano e si ricalcolano nei tempi morti\n        ld a,(m2flag)\n        or a\n        ret z                   ; MSX1: nessun colore\n        ld hl,BLKT+10\n")
    # ---- cell_addr: riga * sw
    t = rep(t, "        add hl,bc               ; *5\n        add hl,hl\n        add hl,hl\n        add hl,hl\n        add hl,hl               ; *80\n        ld d,0\n        add hl,de\n        ret\n",
            "        add hl,bc               ; *5\n        add hl,hl\n        add hl,hl\n        add hl,hl               ; *40\n        ld a,(sw)\n        cp 80\n        jr nz,.w\n        add hl,hl               ; *80\n.w:     ld d,0\n        add hl,de\n        ret\n")
    # ---- scroll orizzontale e ensure_visible
    t = rep(t, ".p:     ld de,HMAX+1\n        push hl", ".p:     ld de,(hmax1w)\n        push hl")
    t = rep(t, "        jr c,.ok\n        ld hl,HMAX\n.ok:", "        jr c,.ok\n        ld hl,(hmaxw)\n.ok:")
    t = rep(t, "        sbc hl,de\n        ld de,VCOLS\n        or a\n        sbc hl,de\n        pop hl\n        ret c\n        ld de,VCOLS-1\n",
            "        sbc hl,de\n        ld de,(vcolsw)\n        or a\n        sbc hl,de\n        pop hl\n        ret c\n        ld de,(vcw1)\n")
    # ---- righe intere: 80 / 79
    t = rep(t, "        ld de,rowbuf+1\n        ld bc,79\n        ld (hl),' '\n        ldir\n        ld hl,(pprm)", "        ld de,rowbuf+1\n        ld bc,(vcolsw)\n        ld (hl),' '\n        ldir\n        ld hl,(pprm)")
    t = rep(t, "        ld hl,rowbuf\n        ld b,80\n.o:     set 7,(hl)\n        inc hl\n        djnz .o\n        ld d,0\n        ld e,0\n        call cell_addr\n        call vsetw\n        ld hl,rowbuf\n        ld b,80\n        ld c,VDPD\n        otir\n",
            "        ld hl,rowbuf\n        ld a,(sw)\n        ld b,a\n.o:     set 7,(hl)\n        inc hl\n        djnz .o\n        ld d,0\n        ld e,0\n        call cell_addr\n        call vsetw\n        ld hl,rowbuf\n        ld a,(sw)\n        ld b,a\n        ld c,VDPD\n        otir\n", 2)
    t = rep(t, "        ld de,rowbuf+1\n        ld bc,79\n        ld (hl),' '\n        ldir\n        pop hl", "        ld de,rowbuf+1\n        ld bc,(vcolsw)\n        ld (hl),' '\n        ldir\n        pop hl")
    # ---- build_row / redraw / kw
    t = rep(t, "        ld de,rowbuf+1\n        ld bc,VCOLS-1\n        ld (hl),' '\n        ldir\n        ld a,(reof)", "        ld de,rowbuf+1\n        ld bc,(vcw1)\n        ld (hl),' '\n        ldir\n        ld a,(reof)")
    t = rep(t, ".copy:  ld de,rowbuf\n        ld b,VCOLS\n        ld a,(selact)", ".copy:  ld de,rowbuf\n        ld a,(swm1)\n        ld b,a\n        ld a,(selact)")
    t = rep(t, "        ld hl,rowbuf\n        ld b,VCOLS\n        ld c,VDPD\n        otir\n        ld a,(rrow)", "        ld hl,rowbuf\n        ld a,(swm1)\n        ld b,a\n        ld c,VDPD\n        otir\n        ld a,(rrow)")
    t = rep(t, "        ld hl,rowbuf\n        ld b,VCOLS\n        ld c,VDPD\n        inir\n        call kw_scan", "        ld hl,rowbuf\n        ld a,(swm1)\n        ld b,a\n        ld c,VDPD\n        inir\n        call kw_scan")
    t = rep(t, "        xor a\n        ld (rowbuf+VCOLS),a     ; sentinella (classe 4): la scansione non esce dalla riga\n        ld (kwq),a\n",
            "        ld hl,(vcolsw)\n        ld de,rowbuf\n        add hl,de\n        ld (hl),0               ; sentinella (classe 4): la scansione non esce dalla riga\n        xor a\n        ld (kwq),a\n")
    t = rep(t, "kw_idle:                        ; nessun tasto in attesa: colora fino a 2 righe leggendole dalla VRAM\n        ld a,(menuopen)\n",
            "kw_idle:                        ; nessun tasto in attesa: colora fino a 2 righe leggendole dalla VRAM\n        ld a,(m2flag)\n        or a\n        ret z\n        ld a,(menuopen)\n")
    # ---- cursor_show
    t = rep(t, "        ld a,l\n        cp VCOLS\n        ret nc\n        ld (tmpd),a             ; x", "        ld a,l\n        ld hl,swm1\n        cp (hl)\n        ret nc\n        ld (tmpd),a             ; x")
    # ---- barre
    t = rep(t, "        add a,2\n        ld (tmpb),a\n        ld e,79\n        ld d,1\n", "        add a,2\n        ld (tmpb),a\n        ld a,(swm1)\n        ld e,a\n        ld d,1\n")
    t = rep(t, ".p:     ld e,79\n        call put_cell", ".p:     ld hl,swm1\n        ld e,(hl)\n        call put_cell")
    t = rep(t, "        ld hl,rowbuf\n        ld de,rowbuf+1\n        ld bc,79\n        ld (hl),05h\n        ldir\n        ld a,03h\n        ld (rowbuf),a\n        ld a,04h\n        ld (rowbuf+78),a\n",
            "        ld hl,rowbuf\n        ld de,rowbuf+1\n        ld bc,(vcolsw)\n        ld (hl),05h\n        ldir\n        ld a,03h\n        ld (rowbuf),a\n        ld a,04h\n        ld hl,(rbm2)\n        ld (hl),a\n")
    t = rep(t, "        ld hl,rowbuf\n        ld b,80\n        ld c,VDPD\n        otir\n        ret\n\ndraw_title:", "        ld hl,rowbuf\n        ld a,(sw)\n        ld b,a\n        ld c,VDPD\n        otir\n        ret\n\ndraw_title:")
    t = rep(t, "        ld c,TV-1\n        call scale\n        ld a,l\n        ret\n.z:", "        ld c,TV-1\n        call scale\n        ld a,l\n        ret\n.z:")
    t = rep(t, "        ld hl,(hscroll)\n        ld de,HMAX\n        ld c,TH-1\n        call scale", "        ld hl,(hscroll)\n        ld de,(hmaxw)\n        ld a,(thv)\n        dec a\n        ld c,a\n        call scale")
    # ---- titolo: 80 colonne come prima, 40 colonne con stato compatto
    t = rep(t, "draw_title:\n        ld hl,rowbuf\n        ld de,rowbuf+1\n        ld bc,79\n        ld (hl),' '\n        ldir\n        ld hl,s_menubar\n        ld de,rowbuf\n        call strcpy\n        ld hl,(msgptr)\n        ld a,h\n        or l\n        jr z,.nomsg\n",
            """draw_title:
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        ld a,(sw)
        cp 80
        jp nz,draw_title40
        ld hl,s_menubar
        ld de,rowbuf
        call strcpy
        ld hl,(msgptr)
        ld a,h
        or l
        jr z,.nomsg
""")
    t = rep(t, ".inv:   ld hl,rowbuf\n        ld b,80\n.o:     set 7,(hl)\n        inc hl\n        djnz .o\n        ld a,(menuopen)         ; il titolo del menu aperto va in video normale",
            ".inv:   ld hl,rowbuf\n        ld a,(sw)\n        ld b,a\n.o:     set 7,(hl)\n        inc hl\n        djnz .o\n        ld a,(menuopen)         ; il titolo del menu aperto va in video normale")
    t = rep(t, ".wr:    ld d,0\n        ld e,0\n        call cell_addr\n        call vsetw\n        ld hl,rowbuf\n        ld b,80\n        ld c,VDPD\n        otir\n        ret\n\ns_menubar:",
            """.wr:    ld d,0
        ld e,0
        call cell_addr
        call vsetw
        ld hl,rowbuf
        ld a,(sw)
        ld b,a
        ld c,VDPD
        otir
        ret

draw_title40:                   ; 40 colonne: barra dei menu (30 colonne) e stato "riga:colonna" a destra;
        ld hl,(msgptr)          ; un messaggio occupa tutta la barra
        ld a,h
        or l
        jr z,.nomsg
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        ld hl,(msgptr)
        ld de,rowbuf
        call strcpy
        jp draw_title.inv
.nomsg: ld hl,s_menubar
        ld de,rowbuf
        call strcpy
        ld a,(modified)
        or a
        jr z,.st
        ld a,'*'
        ld (rowbuf+30),a
.st:    ld de,rowbuf+31
        ld hl,(curline)
        call dec16
        ld a,':'
        ld (de),a
        inc de
        push de
        call cur_col            ; (clobbera DE)
        inc hl
        pop de
        call dec16
        jp draw_title.inv

s_menubar:""")
    # ---- mouse
    t = rep(t, "        ld hl,(mpx)\n        add hl,de\n        ld de,640\n        call clamp", "        ld hl,(mpx)\n        add hl,de\n        ld de,(mxmax)\n        call clamp")
    t = rep(t, "        ld hl,VCOLS-1\n        jr .h\n", "        ld hl,(vcw1)\n        jr .h\n")
    t = rep(t, ".hl:    ld hl,-(VCOLS-1)\n", ".hl:    ld hl,(nvcw1)\n")
    t = rep(t, "        ret nc\n        ld a,e\n        cp 79\n        jp nz,click_text", "        ret nc\n        ld a,e\n        ld hl,swm1\n        cp (hl)\n        jp nz,click_text")
    t = rep(t, ".hbar:  ld a,e\n        or a\n        ld a,5\n        jp z,start_repeat\n        ld a,e\n        cp 78\n        ld a,6\n        jp z,start_repeat\n        ld a,e\n        cp 79\n        ret nc\n",
            ".hbar:  ld a,e\n        or a\n        ld a,5\n        jp z,start_repeat\n        ld a,e\n        ld hl,swm2\n        cp (hl)\n        ld a,6\n        jp z,start_repeat\n        ld a,e\n        ld hl,swm1\n        cp (hl)\n        ret nc\n")
    t = rep(t, "        ld a,(mact)\n        cp 5\n        jr nc,.hor\n        ld a,(mcx)\n        cp 79\n        jr nz,.stop", "        ld a,(mact)\n        cp 5\n        jr nc,.hor\n        ld a,(mcx)\n        ld hl,swm1\n        cp (hl)\n        jr nz,.stop")
    t = rep(t, ".a:     cp TH\n        jr c,.b\n        ld a,TH-1\n.b:     ld (tmpd),a\n        ld c,a\n        ld hl,HMAX\n        ld de,TH-1\n        call scale",
            ".a:     ld hl,thv\n        cp (hl)\n        jr c,.b\n        ld a,(hl)\n        dec a\n.b:     ld (tmpd),a\n        ld c,a\n        ld hl,(hmaxw)\n        ld a,(thv)\n        dec a\n        ld e,a\n        ld d,0\n        call scale")
    t = rep(t, "        ld a,(mcx)\n        cp 79\n        jr c,.c1\n        ld a,78\n.c1:    ld (tgtcol),a", "        ld a,(mcx)\n        ld hl,swm1\n        cp (hl)\n        jr c,.c1\n        ld a,(swm2)\n.c1:    ld (tgtcol),a")
    return t


rw('editor.asm', ed)


def fi(t):
    t = rep(t, "leave_screen:\n        ld a,(csrsave)\n        ld (CSRSW),a\n        xor a                   ; R#13 = 0: niente blink\n",
            "leave_screen:\n        ld a,(csrsave)\n        ld (CSRSW),a\n        ld a,(m2flag)\n        or a\n        ret z                   ; MSX1: niente R#13\n        xor a                   ; R#13 = 0: niente blink\n")
    return t


rw('fileio.asm', fi)
print('ok')
