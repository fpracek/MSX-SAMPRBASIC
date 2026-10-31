; ---------------------------------------------------------------- Open: finestra dei file .SPB (e cartelle su DOS 2)
; Area di lavoro nel gap: [0] numero voci, [1] selezione, [2] prima voce visibile, [3] colonne, [4] DOS 2,
; [5] temporaneo, [6..] percorso corrente (ASCIIZ, 74 byte), poi le voci da 14 byte: flag (1 = cartella) + nome 8.3 ASCIIZ.
BW_ENT  equ 80
BW_MAX  equ 120
bw_cnt  equ 0
bw_sel  equ 1
bw_top  equ 2
bw_ncol equ 3
bw_dos2 equ 4
bw_tmp  equ 5
bw_path equ 6

k_open:
        ld a,0Fh
        call confirm_discard
        ret c
        ld hl,(len)             ; il gap in fondo al testo e' l'area di lavoro
        call gap_to_ofs
        ld hl,(gsz)
        ld de,2048
        or a
        sbc hl,de
        jr c,.nomem
        ld hl,(gs)
        ld de,BUF
        add hl,de
        ld (hscr),hl
        call bw_run
        push af
        call set_sentinel
        call mark_text
        pop af
        ret c
        jp load_file
.nomem: ld hl,m_helpmem
        ld (msgptr),hl
        ret

bw_run:                         ; C = annullato; altrimenti fname = file scelto
        call kw_reset           ; niente colori delle parole chiave sotto la finestra
        ld ix,(hscr)
        ld a,(sw)
        ld b,0
.nc:    sub 20
        jr c,.nd
        inc b
        jr .nc
.nd:    ld (ix+bw_ncol),b
        ld (ix+bw_dos2),0
        ld b,0
        ld c,6Fh                ; _DOSVER: solo il DOS 2 risponde con A=0 e B>=2
        call BDOS
        or a
        jr nz,.d1
        ld a,b
        cp 2
        jr c,.d1
        ld ix,(hscr)
        ld (ix+bw_dos2),1
.d1:    ld ix,(hscr)
        ld (ix+bw_sel),0
        call bw_scan
.redraw: call bw_draw
.key:   BIOS CHGET
        ld ix,(hscr)
        cp 1Bh
        jp z,.cancel
        cp 0Dh
        jp z,.enter
        cp 1Eh
        jr z,.up
        cp 1Fh
        jr z,.dn
        cp 1Dh
        jr z,.lf
        cp 1Ch
        jr z,.rt
        cp 0Bh
        jr z,.hm
        cp 0Eh
        jr z,.pd
        cp 10h
        jr z,.pu
        cp '0'
        jr c,.key
        cp 'a'
        jr c,.ju
        cp 'z'+1
        jr nc,.key
        sub 20h
.ju:    ld b,a                  ; lettera iniziale: salta alla prima voce che comincia cosi'
        ld c,0
.jl:    ld a,(ix+bw_cnt)
        cp c
        jp z,.key
        ld a,c
        push bc
        call bw_entry
        pop bc
        inc hl
        ld a,(hl)
        cp b
        jr z,.jf
        inc c
        jr .jl
.jf:    ld a,c
        jr .set
.up:    ld a,(ix+bw_sel)
        sub (ix+bw_ncol)
        jr c,.key
        jr .set
.dn:    ld a,(ix+bw_sel)
        add a,(ix+bw_ncol)
        jr .set
.lf:    ld a,(ix+bw_sel)
        or a
        jr z,.key
        dec a
        jr .set
.rt:    ld a,(ix+bw_sel)
        inc a
        jr .set
.hm:    xor a
        jr .set
.pd:    call bw_cap
        add a,(ix+bw_sel)
        jr .set
.pu:    call bw_cap
        ld b,a
        ld a,(ix+bw_sel)
        sub b
        jr nc,.set
        xor a
.set:   ld b,a
        ld a,(ix+bw_cnt)
        or a
        jp z,.key
        dec a
        cp b
        jr c,.sm
        ld a,b
.sm:    ld (ix+bw_sel),a
        jp .redraw
.enter: ld a,(ix+bw_cnt)
        or a
        jp z,.key
        ld a,(ix+bw_sel)
        call bw_entry
        ld a,(hl)
        inc hl
        or a
        jr nz,.dir
        ld de,fname
        ld bc,13
        ldir
        or a
        ret
.dir:   ex de,hl
        ld c,5Ah                ; _CHDIR
        call BDOS
        ld ix,(hscr)
        ld (ix+bw_sel),0
        call bw_scan
        jp .redraw
.cancel: scf
        ret

bw_cap:                         ; A = voci per pagina (22 righe x colonne)
        ld b,(ix+bw_ncol)
        xor a
.l:     add a,22
        djnz .l
        ret

bw_entry:                       ; A = indice -> HL = voce
        ld hl,0
        or a
        jr z,.p
        ld b,a
        ld de,14
.m:     add hl,de
        djnz .m
.p:     ld de,BW_ENT
        add hl,de
        push ix
        pop de
        add hl,de
        ret

bw_add:                         ; HL = nome ASCIIZ, A = flag (1 = cartella)
        push hl
        ld ix,(hscr)
        ld (ix+bw_tmp),a
        ld a,(ix+bw_cnt)
        cp BW_MAX
        jr nc,.full
        call bw_entry
        ld a,(ix+bw_tmp)
        ld (hl),a
        inc hl
        ex de,hl
        pop hl
        ld b,12
.c:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        djnz .c
.e:     xor a
        ld (de),a
        inc (ix+bw_cnt)
        ret
.full:  pop hl
        ret

bw_scan:
        call bw_scan0
        ; fall through
bw_sort:                        ; cartelle prima, poi file; ordine alfabetico (bubble sort sulle voci da 14 byte)
        ld ix,(hscr)
        ld a,(ix+bw_cnt)
        cp 2
        ret c
        dec a
        ld b,a
.pass:  push bc
        ld hl,(hscr)
        ld de,BW_ENT
        add hl,de
.cmp:   push bc
        ld d,h
        ld e,l
        ld a,e
        add a,14
        ld e,a
        jr nc,.nc
        inc d
.nc:    ld a,(de)
        cp (hl)
        jr c,.ok
        jr nz,.swap
        push hl
        push de
        inc hl
        inc de
.nm:    ld a,(de)
        cp (hl)
        jr c,.sw2
        jr nz,.ok2
        or a
        jr z,.ok2
        inc hl
        inc de
        jr .nm
.sw2:   pop de
        pop hl
        jr .swap
.ok2:   pop de
        pop hl
        jr .ok
.swap:  push hl
        push de
        ld b,14
.x:     ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .x
        pop de
        pop hl
.ok:    ld de,14
        add hl,de
        pop bc
        djnz .cmp
        pop bc
        djnz .pass
        ret

bw_scan0:                       ; elenca cartelle e file .SPB della directory corrente
        ld ix,(hscr)
        ld (ix+bw_cnt),0
        ld (ix+bw_path),0
        ld a,(ix+bw_dos2)
        or a
        jp z,.dos1
        push ix
        pop hl
        ld de,bw_path
        add hl,de
        ex de,hl
        ld b,0
        ld c,59h                ; _GETCD: percorso corrente
        call BDOS
        ld ix,(hscr)
        ld a,(ix+bw_path)
        or a
        jr z,.noup
        ld hl,s_dotdot
        ld a,1
        call bw_add
.noup:  ld de,s_star
        ld b,10h
        ld c,40h                ; _FFIRST
.d1x:   ld ix,iobuf
        call BDOS
        or a
        jr nz,.dend
        ld a,(iobuf+14)
        and 10h
        jr z,.dnext
        ld a,(iobuf+1)
        cp '.'
        jr z,.dnext
        ld hl,iobuf+1
        ld a,1
        call bw_add
.dnext: ld c,41h                ; _FNEXT
        jr .d1x
.dend:  ld de,s_spbm
        ld b,0
        ld c,40h
.f1x:   ld ix,iobuf
        call BDOS
        or a
        ret nz
        ld hl,iobuf+1
        xor a
        call bw_add
        ld c,41h
        jr .f1x
.dos1:  ld hl,fcb
        ld de,fcb+1
        ld bc,36
        ld (hl),0
        ldir
        ld hl,fcb+1
        ld de,fcb+2
        ld bc,7
        ld (hl),'?'
        ldir
        ld hl,s_spb3
        ld de,fcb+9
        ld bc,3
        ldir
        ld de,iobuf
        ld c,F_DMA
        call BDOS
        ld c,11h                ; ricerca del primo
.s1:    ld de,fcb
        call BDOS
        cp 0FFh
        ret z
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,iobuf
        add hl,de
        call bw_fmt
        ld hl,msgbuf
        xor a
        call bw_add
        ld c,12h                ; ricerca del successivo
        jr .s1

bw_fmt:                         ; HL = voce di directory (nome 8+3 in forma FCB) -> "NOME.SPB" in msgbuf
        push hl
        inc hl
        ld de,msgbuf
        ld b,8
.n:     ld a,(hl)
        cp ' '
        jr z,.dot
        ld (de),a
        inc hl
        inc de
        djnz .n
.dot:   pop hl
        ld bc,9
        add hl,bc
        ld a,'.'
        ld (de),a
        inc de
        ld bc,3
        ldir
        xor a
        ld (de),a
        ret

bw_draw:
        call ptr_hide
        ld ix,(hscr)
        ld hl,msgbuf
        ex de,hl
        ld hl,s_bw1
        call strcpy
        push ix
        pop hl
        ld bc,bw_path
        add hl,bc
        ld b,20
.pc:    ld a,(hl)
        or a
        jr z,.pe
        ld (de),a
        inc hl
        inc de
        djnz .pc
.pe:    ld hl,s_bw2
        call strcpy
        xor a
        ld (de),a
        ld hl,msgbuf
        call show_row0
        ld ix,(hscr)
        call bw_cap             ; pagina che contiene la selezione
        ld c,a
        ld a,(ix+bw_sel)
        ld b,0
.t:     cp c
        jr c,.td
        sub c
        ld d,a
        ld a,b
        add a,c
        ld b,a
        ld a,d
        jr .t
.td:    ld (ix+bw_top),b
        ld (ix+bw_tmp),b        ; indice della voce che si sta disegnando
        ld d,1
.row:   push de
        ld hl,rowbuf
        ld de,rowbuf+1
        ld bc,(vcolsw)
        ld (hl),' '
        ldir
        ld c,(ix+bw_ncol)
        ld de,rowbuf+1
.col:   push bc
        push de
        ld a,(ix+bw_tmp)
        cp (ix+bw_cnt)
        jr nc,.after
        call bw_entry
        pop de
        push de
        ld b,(hl)
        inc hl
        ld a,b
        or a
        jr z,.nm
        ld a,'['
        ld (de),a
        inc de
.nm:    ld a,(hl)
        or a
        jr z,.cd
        ld (de),a
        inc hl
        inc de
        jr .nm
.cd:    ld a,b
        or a
        jr z,.after
        ld a,']'
        ld (de),a
.after: pop hl
        push hl
        ld a,(ix+bw_tmp)
        cp (ix+bw_sel)
        jr nz,.ns
        ld a,(ix+bw_cnt)
        or a
        jr z,.ns
        ld b,19
.iv:    set 7,(hl)
        inc hl
        djnz .iv
.ns:    pop hl
        ld de,20
        add hl,de
        ex de,hl
        pop bc
        inc (ix+bw_tmp)
        dec c
        jr nz,.col
        pop de
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
        inc d
        ld a,d
        cp 23
        jp nz,.row
        ret

s_bw1:   db "Open: ",5Ch,0
s_bw2:   db "  Enter=open Esc=quit",0
s_dotdot: db "..",0
s_star:  db "*.*",0
s_spbm:  db "*.SPB",0
s_spb3:  db "SPB"
