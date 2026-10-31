; =====================================================================
; Debugger a strumentazione (OPTION DEBUG)
; Il compilatore mette prima di ogni istruzione:  ld hl,<riga> ; call RT_DBG
; Passo-passo, breakpoint per riga, CTRL-STOP interrompe l'esecuzione, variabili globali scalari
; (solo .COM). Lo schermo del programma si salva cosi': registri VDP (copie del BIOS), 960 byte di
; VRAM per la tabella dei nomi e 512 per i glifi ASCII 32-95; poi si passa a TEXT 1 (40x24),
; attivando il VDP in modo testo prima di leggere la VRAM (negli schermi 6 e 7 gli indirizzi sono
; interlacciati: si salva e si ripristina sempre con la stessa mappatura).
; Lo stato (circa 1.6 KB) si prende dall'alto dell'heap alla prima chiamata.
; =====================================================================
INTFLG  equ 0FC9Bh
RG25SA  equ 0FFFAh
D_MODE  equ 0                   ; 1 = passo-passo, 0 = esegui fino a un breakpoint
D_NBP   equ 1
D_BP    equ 2                   ; 8 word
D_LINE  equ 18
D_VPG   equ 20                  ; pagina delle variabili
D_VPTR  equ 22
D_VN    equ 24
D_VS    equ 25
D_VR    equ 26
D_IN    equ 27                  ; word
D_ND    equ 29
D_REGS  equ 32                  ; R#0-R#27 (28 byte)
D_LBUF  equ 64                  ; 40 byte: riga di testo
D_BUF   equ 128                 ; 960 byte tabella nomi + 512 byte glifi
DBGSIZE equ 0640h

rt_dbg:                         ; HL = riga sorgente; conserva tutti i registri
        push af
        push bc
        push de
        push hl
        push ix
        push iy
        ld de,(DBGP)
        ld a,d
        or e
        jr nz,.have
        push hl
        call dbg_init
        pop hl
.have:  ld ix,(DBGP)
        ld (ix+D_LINE),l
        ld (ix+D_LINE+1),h
        ld a,(ix+D_MODE)
        or a
        jr nz,.stop
        ld a,(INTFLG)           ; CTRL-STOP
        or a
        jr z,.nobrk
        xor a
        ld (INTFLG),a
        jr .stop
.nobrk: ld b,(ix+D_NBP)
        ld a,b
        or a
        jr z,.go
        push ix
        pop de
        inc de
        inc de
.cmp:   ld a,(de)
        cp l
        jr nz,.nx
        inc de
        ld a,(de)
        dec de
        cp h
        jr z,.stop
.nx:    inc de
        inc de
        djnz .cmp
.go:    pop iy
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ret
.stop:  call dbg_ui
        jr .go

dbg_init:
        ld hl,(heapend)
        ld de,-DBGSIZE
        add hl,de
        ld (heapend),hl
        ld (DBGP),hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,127
        ldir
        ld hl,(DBGP)
        ld (hl),1               ; si parte in passo-passo
        ret

; ---------------------------------------------------------------- VDP
dbg_wreg:                       ; A = valore, C = registro (conserva BC, DE, HL)
        di
        out (VDPC),a
        ld a,c
        or 80h
        out (VDPC),a
        ei
        ret

dbg_vset:                       ; HL = indirizzo (< 16 KB), A = 0 lettura / 40h scrittura
        ld c,a
        di
        xor a
        out (VDPC),a
        ld a,8Eh
        out (VDPC),a
        ld a,l
        out (VDPC),a
        ld a,h
        and 3Fh
        or c
        out (VDPC),a
        ei
        ret

dbg_rd:                         ; BC byte dalla VRAM a (HL)
        in a,(VDPD)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,dbg_rd
        ret

dbg_wr:                         ; BC byte da (HL) alla VRAM
        ld a,(hl)
        out (VDPD),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,dbg_wr
        ret

dbg_bufp:                       ; -> HL = buffer VRAM salvata
        ld hl,(DBGP)
        ld de,D_BUF
        add hl,de
        ret

dbg_enter:
        ld a,(M2FLAG)
        or a
        call nz,vdp_wait        ; MSX1: niente motore comandi (e R#15 non esiste)
        ld hl,(DBGP)
        ld de,D_REGS
        add hl,de
        ex de,hl
        ld hl,RG0SAV
        ld bc,8
        ldir
        ld hl,RG8SAV
        ld bc,16
        ldir
        inc de                  ; R#24 non esiste
        ld hl,RG25SA
        ld bc,3
        ldir
        ld c,1                  ; TEXT 1, schermo spento
        ld a,0B0h
        call dbg_wreg
        xor a
        ld c,0
        call dbg_wreg
        xor a
        ld c,2
        call dbg_wreg
        xor a
        ld c,3
        call dbg_wreg
        ld a,1
        ld c,4
        call dbg_wreg
        ld a,0F4h
        ld c,7
        call dbg_wreg
        ld a,(M2FLAG)
        or a
        jp z,.nv                ; MSX1: solo R#0-R#7 (i numeri maggiori si sovrapporrebbero ai primi)
        ld a,(RG8SAV+1)
        and 7Fh
        ld c,9
        call dbg_wreg
        xor a
        ld c,23
        call dbg_wreg
        ld hl,2Dh
        call rdrom
        cp 2
        jr c,.nv
        xor a
        ld c,25
        call dbg_wreg
        xor a
        ld c,26
        call dbg_wreg
        xor a
        ld c,27
        call dbg_wreg
.nv:    ld hl,0                 ; salva la VRAM
        xor a
        call dbg_vset
        call dbg_bufp
        ld bc,960
        call dbg_rd
        push hl
        ld hl,0900h
        xor a
        call dbg_vset
        pop hl
        ld bc,512
        call dbg_rd
        ld hl,0900h             ; font del BIOS: ASCII 32-95
        ld a,40h
        call dbg_vset
        ld hl,4
        call rdrom
        ld c,a
        ld hl,5
        call rdrom
        ld h,a
        ld l,c
        ld de,32*8
        add hl,de
        ld bc,512
.f:     call rdrom
        out (VDPD),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.f
        ld hl,0                 ; tabella dei nomi vuota
        ld a,40h
        call dbg_vset
        ld bc,960
.s:     ld a,' '
        out (VDPD),a
        dec bc
        ld a,b
        or c
        jr nz,.s
        ret

dbg_leave:
        ld c,1
        ld a,0B0h
        call dbg_wreg
        ld hl,0
        ld a,40h
        call dbg_vset
        call dbg_bufp
        ld bc,960
        call dbg_wr
        push hl
        ld hl,0900h
        ld a,40h
        call dbg_vset
        pop hl
        ld bc,512
        call dbg_wr
        ld hl,(DBGP)
        ld de,D_REGS
        add hl,de
        ld c,0
        ld b,24
        ld a,(M2FLAG)
        or a
        jr nz,.r
        ld b,8                  ; MSX1: si ripristinano solo R#0-R#7
.r:     ld a,c
        cp 1
        jr z,.s
        cp 14
        jr c,.w
        cp 18
        jr c,.s                 ; R#14-17 (banco, stato, palette, puntatore) non si toccano
.w:     ld a,(hl)
        call dbg_wreg
.s:     inc hl
        inc c
        ld a,c
        cp b
        jr nz,.r
        ld a,(M2FLAG)
        or a
        jr z,.d
        inc hl
        push hl
        ld hl,2Dh
        call rdrom
        pop hl
        cp 2
        jr c,.d
        ld c,25
        ld a,(hl)
        call dbg_wreg
        inc hl
        inc c
        ld a,(hl)
        call dbg_wreg
        inc hl
        inc c
        ld a,(hl)
        call dbg_wreg
.d:     ld ix,(DBGP)
        ld a,(ix+D_REGS+1)
        ld c,1
        jp dbg_wreg

; ---------------------------------------------------------------- testo
dbg_lclr:                       ; riga di testo = 40 spazi, DE = inizio
        ld hl,(DBGP)
        ld de,D_LBUF
        add hl,de
        push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),' '
        ld bc,39
        ldir
        pop de
        ret

dbg_cat:                        ; HL = testo 0-terminato -> (DE), DE avanza
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr dbg_cat

dbg_row:                        ; A = riga: la riga di testo va nella tabella dei nomi
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,40h
        call dbg_vset
        ld hl,(DBGP)
        ld de,D_LBUF
        add hl,de
        ld b,40
.c:     ld a,(hl)
        inc hl
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 32
.u:     cp 32
        jr c,.sp
        cp 96
        jr c,.o
.sp:    ld a,32
.o:     out (VDPD),a
        djnz .c
        ret

dbg_div10:                      ; HL / 10 -> HL, A = resto
        xor a
        ld b,16
.d:     add hl,hl
        rla
        cp 10
        jr c,.n
        sub 10
        inc l
.n:     djnz .d
        ret

dbg_udec:                       ; HL senza segno -> testo in (DE), DE avanza
        ld c,0
.l:     push bc
        call dbg_div10
        pop bc
        push af
        inc c
        ld a,h
        or l
        jr nz,.l
.o:     pop af
        add a,'0'
        ld (de),a
        inc de
        dec c
        jr nz,.o
        ret

dbg_dec:                        ; HL con segno
        bit 7,h
        jr z,dbg_udec
        ld a,'-'
        ld (de),a
        inc de
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        jr dbg_udec

dbg_key:                        ; -> A = tasto (maiuscolo), senza cursore del BIOS
.w:     ld ix,CHSNS
        call rt_bios
        jr z,.w
        ld ix,CHGET
        call rt_bios
        cp 'a'
        ret c
        cp 'z'+1
        ret nc
        sub 32
        ret

; ---------------------------------------------------------------- schermata
t_title: db "SAMPR BASIC DEBUGGER   LINE ",0
t_bp:    db "BREAKPOINTS:",0
t_ask:   db "BREAKPOINT LINE (0=CLEAR)? ",0
t_nov:   db "NO VARIABLE TABLE",0
t_h1:    db "SPACE=STEP  R=RUN  B=BREAKPOINT  C=CLEAR",0
t_h2:    db "V=NEXT VARS  Q=QUIT  CTRL-STOP=BREAK",0

dbg_draw:
        call dbg_lclr
        ld hl,t_title
        call dbg_cat
        ld ix,(DBGP)
        ld l,(ix+D_LINE)
        ld h,(ix+D_LINE+1)
        call dbg_udec
        xor a
        call dbg_row
        ld hl,(DBGP)
        ld de,D_LBUF
        add hl,de
        ld b,40
        ld a,'-'
.sp:    ld (hl),a
        inc hl
        djnz .sp
        ld a,1
        call dbg_row
        ld c,2                  ; righe 2-17 vuote
.bl:    push bc
        call dbg_lclr
        pop bc
        ld a,c
        push bc
        call dbg_row
        pop bc
        inc c
        ld a,c
        cp 18
        jr nz,.bl
        call dbg_vars
        call dbg_lclr
        ld hl,t_bp
        call dbg_cat
        ld ix,(DBGP)
        ld b,(ix+D_NBP)
        ld a,b
        or a
        jr z,.nb
        push ix
        pop hl
        inc hl
        inc hl                  ; HL = &bp[0]
.bq:    inc de
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        call dbg_udec
        pop hl
        pop bc
        djnz .bq
.nb:    ld a,19
        call dbg_row
        call dbg_lclr
        ld a,20
        call dbg_row
        call dbg_lclr
        ld hl,t_h1
        call dbg_cat
        ld a,22
        call dbg_row
        call dbg_lclr
        ld hl,t_h2
        call dbg_cat
        ld a,23
        jp dbg_row

dbg_vars:
        ld ix,(DBGP)
        ld hl,(DBGT)
        ld a,h
        or l
        jr nz,.have
        call dbg_lclr
        ld hl,t_nov
        call dbg_cat
        ld a,2
        jp dbg_row
.have:  ld a,(hl)
        inc hl
        ld (ix+D_VN),a
        ld (ix+D_VPTR),l
        ld (ix+D_VPTR+1),h
        ld a,(ix+D_VPG)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (ix+D_VS),a
        ld (ix+D_VR),2
.loop:  ld ix,(DBGP)
        ld a,(ix+D_VN)
        or a
        ret z
        dec (ix+D_VN)
        ld l,(ix+D_VPTR)
        ld h,(ix+D_VPTR+1)
        ld de,16
        push hl
        add hl,de
        ld (ix+D_VPTR),l
        ld (ix+D_VPTR+1),h
        pop hl
        push hl
        pop iy                  ; IY = record
        ld a,(iy+14)
        or (iy+15)
        jr nz,.loop             ; gli array non si mostrano
        ld a,(ix+D_VS)
        or a
        jr z,.show
        dec (ix+D_VS)
        jr .loop
.show:  ld a,(ix+D_VR)
        cp 18
        ret nc
        call dbg_lclr
        push iy
        pop hl
        ld b,11
.nm:    ld a,(hl)
        or a
        jr z,.ne
        ld (de),a
        inc hl
        inc de
        djnz .nm
.ne:    ld a,(iy+11)
        cp '$'
        jr nz,.nsx
        ld (de),a
        inc de
.nsx:   ld a,'='
        ld (de),a
        inc de
        ld l,(iy+12)
        ld h,(iy+13)
        ld a,(iy+11)
        cp '$'
        jr z,.str
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call dbg_dec
        jr .put
.str:   ld a,'"'                 ; la variabile stringa e' il buffer [len][dati]
        ld (de),a
        inc de
        call dbg_cats
.sq:    ld a,'"'
        ld (de),a
        inc de
        jr .put
.put:   ld ix,(DBGP)
        ld a,(ix+D_VR)
        inc (ix+D_VR)
        call dbg_row
        jp .loop

dbg_cats:                       ; HL = stringa [len][dati] -> (DE), al massimo 22 caratteri
        ld b,(hl)
        inc hl
        ld a,b
        or a
        ret z
        cp 23
        jr c,.l
        ld b,22
.l:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .l
        ret

dbg_nextpg:
        ld ix,(DBGP)
        ld hl,(DBGT)
        ld a,h
        or l
        ret z
        ld b,(hl)
        ld a,(ix+D_VPG)
        inc a
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        cp b
        jr c,.ok
        ld c,0
.ok:    ld (ix+D_VPG),c
        ret

; ---------------------------------------------------------------- breakpoint
dbg_bptoggle:                   ; HL = riga: aggiunge o toglie
        ld ix,(DBGP)
        push ix
        pop de
        inc de
        inc de
        ld b,(ix+D_NBP)
        ld a,b
        or a
        jr z,.add
.f:     ld a,(de)
        cp l
        jr nz,.n
        inc de
        ld a,(de)
        dec de
        cp h
        jr z,.rem
.n:     inc de
        inc de
        djnz .f
.add:   ld a,(ix+D_NBP)
        cp 8
        ret nc
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc (ix+D_NBP)
        ret
.rem:   ld a,b
        dec a
        jr z,.last
        add a,a
        ld c,a
        ld b,0
        ld h,d
        ld l,e
        inc hl
        inc hl
        ldir
.last:  dec (ix+D_NBP)
        ret

dbg_prompt:
        ld ix,(DBGP)
        xor a
        ld (ix+D_IN),a
        ld (ix+D_IN+1),a
        ld (ix+D_ND),a
.show:  call dbg_lclr
        ld hl,t_ask
        call dbg_cat
        ld ix,(DBGP)
        ld a,(ix+D_ND)
        or a
        jr z,.nz
        ld l,(ix+D_IN)
        ld h,(ix+D_IN+1)
        call dbg_udec
.nz:    ld a,20
        call dbg_row
.k:     call dbg_key
        cp 13
        jr z,.done
        cp 8
        jr z,.bs
        cp 127
        jr z,.bs
        cp '0'
        jr c,.k
        cp '9'+1
        jr nc,.k
        ld c,a
        ld ix,(DBGP)
        ld a,(ix+D_ND)
        cp 5
        jr nc,.k
        inc (ix+D_ND)
        ld l,(ix+D_IN)
        ld h,(ix+D_IN+1)
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld a,c
        sub '0'
        ld e,a
        ld d,0
        add hl,de
        ld (ix+D_IN),l
        ld (ix+D_IN+1),h
        jp .show
.bs:    ld ix,(DBGP)
        ld a,(ix+D_ND)
        or a
        jr z,.k
        dec (ix+D_ND)
        ld l,(ix+D_IN)
        ld h,(ix+D_IN+1)
        call dbg_div10
        ld ix,(DBGP)
        ld (ix+D_IN),l
        ld (ix+D_IN+1),h
        jp .show
.done:  ld ix,(DBGP)
        ld a,(ix+D_ND)
        or a
        jr nz,.have
        ld l,(ix+D_LINE)        ; senza cifre: la riga corrente
        ld h,(ix+D_LINE+1)
        jr .tog
.have:  ld l,(ix+D_IN)
        ld h,(ix+D_IN+1)
        ld a,h
        or l
        jr nz,.tog
        ld (ix+D_NBP),0         ; 0: toglie tutti
        ret
.tog:   jp dbg_bptoggle

; ---------------------------------------------------------------- interfaccia
dbg_ui:
        call dbg_enter
.draw:  call dbg_draw
        ld c,1                  ; schermo acceso
        ld a,0F0h
        call dbg_wreg
.k:     call dbg_key
        cp ' '
        jr z,.step
        cp 13
        jr z,.step
        cp 'S'
        jr z,.step
        cp 'R'
        jr z,.run
        cp 'B'
        jr nz,.nb
        call dbg_prompt
        jr .draw
.nb:    cp 'C'
        jr nz,.nc
        ld ix,(DBGP)
        ld (ix+D_NBP),0
        jr .draw
.nc:    cp 'V'
        jr nz,.nv
        call dbg_nextpg
        jr .draw
.nv:    cp 'Q'
        jr nz,.k
        call dbg_leave
        jp rt_end
.step:  ld a,1
        jr .go
.run:   xor a
.go:    ld ix,(DBGP)
        ld (ix+D_MODE),a
        jp dbg_leave
