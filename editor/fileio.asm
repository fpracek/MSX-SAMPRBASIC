; =====================================================================
; Caricamento / salvataggio file (solo build .COM) - API a FCB, valida su
; MSX-DOS 1 e Nextor/MSX-DOS 2 (compatibilita').  Fine riga su disco = CR LF,
; in memoria = LF.  Funzioni BDOS: 0Fh open, 10h close, 13h delete, 16h make,
; 1Ah set DMA, 26h/27h blocchi casuali (dimensione record = 1 -> byte esatti).
; =====================================================================
BDOS    equ 0005h
F_OPEN  equ 0Fh
F_CLOSE equ 10h
F_DEL   equ 13h
F_MAKE  equ 16h
F_DMA   equ 1Ah
F_BWR   equ 26h
F_BRD   equ 27h

getcmd:                         ; riga di comando (0080h: lunghezza + testo) -> fname
        call d2_detect
        ld hl,0
        ld (errline),hl
        xor a
        ld (errcode),a
        ld (cmdok),a
        ld (compiled),a
        ld (onfile),a
        ld hl,0080h
        ld a,(hl)
        or a
        jr z,.none
        ld b,a
        inc hl
.sk:    ld a,(hl)
        cp ' '
        jr nz,.go
        inc hl
        djnz .sk
        jr .none
.go:    call d2_path            ; DOS 2: A:\DIR\NOME -> entra in DIR
        ld de,fname
        ld c,14
.cp:    ld a,(hl)
        cp ' '
        jr z,.end
        cp 0Dh
        jr z,.end
        ld (de),a
        inc hl
        inc de
        dec c
        jr z,.end
        djnz .cp
.end:   xor a
        ld (de),a
        call ensure_spb
        jp parse_err
.none:  xor a
        ld (fname),a
        ret

ensure_spb:                     ; fname senza estensione -> aggiunge ".SPB" (conserva HL)
        push hl
        ld hl,fname
        ld a,(hl)
        or a
        jr z,.r
.f:     ld a,(hl)
        or a
        jr z,.add
        cp '.'
        jr z,.r
        inc hl
        jr .f
.add:   ex de,hl
        ld hl,s_spbz
        ld bc,5
        ldir
.r:     pop hl
        ret
s_spbz: db ".SPB",0

spb_force:                      ; fname: toglie l'estensione digitata e mette ".SPB"
        ld hl,fname
        ld a,(hl)
        or a
        ret z
.f:     ld a,(hl)
        or a
        jr z,.go
        cp '.'
        jr z,.cut
        inc hl
        jr .f
.cut:   ld (hl),0
.go:    jp ensure_spb

prompt_spb:                     ; "Save as:" con al massimo 8 caratteri; C se annullato
        ld hl,s_saveas
        ld de,fname
        ld b,8
        ld c,0
        call prompt_line
        ret c
        call spb_force
        or a
        ret

parse_err:                      ; HL dopo il nome: " E<riga> <codice>" (ritorno dal compilatore)
.sk:    ld a,(hl)
        cp ' '
        jr nz,.e
        inc hl
        jr .sk
.e:     cp '+'                  ; " +": il programma e' appena stato eseguito dalla compilazione di questo sorgente
        jr nz,.e2
        ld a,1
        ld (cmdok),a
        ret
.e2:    cp 'E'
        ret nz
        inc hl
        call .num
        ld (errline),de
.s2:    ld a,(hl)
        cp ' '
        jr nz,.c
        inc hl
        jr .s2
.c:     call .num
        ld a,e
        ld (errcode),a
        ret
.num:   ld de,0
.nl:    ld a,(hl)
        sub '0'
        cp 10
        ret nc
        push hl
        ld h,d
        ld l,e
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        pop hl
        inc hl
        jr .nl

startup_load:
        call d2_proj
        ld a,(fname)
        or a
        ret z
        call load_file
        ld a,(cmdok)
        ld (compiled),a
        ld hl,(errline)
        ld a,h
        or l
        ret z
        call goto_line          ; ritorno da un errore di compilazione: riga + messaggio
        jp err_message

mk_fcb:                         ; fname -> fcb (8.3 maiuscolo, unita' opzionale "A:")
        ld hl,fcb
        ld de,fcb+1
        ld bc,36
        ld (hl),0
        ldir
        ld hl,fcb+1
        ld de,fcb+2
        ld bc,10
        ld (hl),' '
        ldir
        ld hl,fname
        ld a,(hl)
        or a
        ret z
        inc hl
        ld a,(hl)
        dec hl
        cp ':'
        jr nz,.nm
        ld a,(hl)
        and 1Fh
        ld (fcb),a
        inc hl
        inc hl
.nm:    ld de,fcb+1
        ld b,8
        call .field
        ld a,(hl)
        cp '.'
        ret nz
        inc hl
        ld de,fcb+9
        ld b,3
.field: ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        cp 'a'
        jr c,.up
        cp 'z'+1
        jr nc,.up
        sub 20h
.up:    ld (de),a
        inc hl
        inc de
        djnz .field
.rest:  ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        inc hl
        jr .rest

fcb_rec1:                       ; dimensione record 1, posizione casuale 0
        ld hl,1
        ld (fcb+14),hl
        ld hl,0
        ld (fcb+33),hl
        ld (fcb+35),hl
        ret

; ---------------------------------------------------------------- caricamento
load_file:
        xor a
        ld (compiled),a
        ld (onfile),a
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.opened
        ld hl,m_notfound
        ld (msgptr),hl
        ret
.opened:
        call fcb_rec1
        call ed_reset
        xor a
        ld (lcol),a
        ld (ioerr),a
.rd:    ld de,iobuf
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,IOSZ
        ld c,F_BRD
        call BDOS               ; A = 0 completo, 1 = fine file; HL = byte letti
        ld (tmpb),a
        ld a,h
        or l
        jr z,.close
        ld b,h
        ld c,l
        ld hl,iobuf
        call load_chunk
        jr c,.close
        ld a,(tmpb)
        or a
        jr z,.rd
.close: ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,(len)
        ld (gs),hl
        ld (tmp1),hl
        ld de,(bufsz)
        ex de,hl
        or a
        sbc hl,de
        ld (gsz),hl
        call set_sentinel
        ld a,1
        ld (dirty),a
        xor a
        ld (modified),a
        inc a
        ld (onfile),a
        ld a,(ioerr)
        cp 2
        jr nz,.ok
        ld hl,m_toolarge
        ld (msgptr),hl
        ret
.ok:    ld hl,m_loaded
        jp mk_msg

load_chunk:                     ; HL = sorgente, BC = byte -> C se fine file o buffer pieno
.l:     ld a,b
        or c
        ret z
        ld a,(hl)
        inc hl
        dec bc
        cp 1Ah
        jr z,.stop
        cp 0Dh
        jr z,.l
        cp 0Ah
        jr z,.nl
        cp 09h
        jr z,.tab
        cp 32
        jr c,.q
        cp 127
        jr c,.put
.q:     ld a,'?'
.put:   call ld_put
        ret c
        ld a,(lcol)
        inc a
        ld (lcol),a
        jr .l
.nl:    ld a,LF
        call ld_put
        ret c
        xor a
        ld (lcol),a
        push hl
        ld hl,(nlines)
        inc hl
        ld (nlines),hl
        pop hl
        jr .l
.tab:   ld a,' '
        call ld_put
        ret c
        ld a,(lcol)
        inc a
        ld (lcol),a
        and 3
        jr nz,.tab
        jr .l
.stop:  scf
        ret

ld_put:                         ; A = byte da accodare al testo; C se il buffer e' pieno
        push hl
        push de
        ld hl,(len)
        ld de,(bufsz)
        dec de
        dec de
        or a
        sbc hl,de
        jr nc,.full
        ld hl,(len)
        ld de,BUF
        add hl,de
        ld (hl),a
        ld hl,(len)
        inc hl
        ld (len),hl
        pop de
        pop hl
        or a
        ret
.full:  ld a,2
        ld (ioerr),a
        pop de
        pop hl
        scf
        ret

; ---------------------------------------------------------------- salvataggio
save_file:                      ; -> C se errore (messaggio in msgptr)
        ld a,(modified)
        or a
        jr z,.ncl
        xor a
        ld (compiled),a        ; il testo e' cambiato dopo l'ultima compilazione
.ncl:   call mk_fcb
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
        ld hl,0
        ld (nbytes),hl
        ld hl,iobuf
        ld (iop),hl
        ld hl,BUF
        ld bc,(gs)
        call emit_seg
        ld hl,(len)
        ld de,(gs)
        or a
        sbc hl,de
        ld b,h
        ld c,l                  ; BC = byte dopo il gap
        ld hl,(gs)
        ld de,(gsz)
        add hl,de
        ld de,BUF
        add hl,de
        call emit_seg
        call flush_io
        ld a,(inplace)
        or a
        jr z,.cl
        ld hl,(nbytes)          ; sovrascrittura piu' corta del file di prima: ^Z dopo il testo (il resto si ignora)
        ld de,(oldsz)
        or a
        sbc hl,de
        jr nc,.cl               ; nuova dimensione >= vecchia
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
        ld (tmp1),hl
        ld hl,m_saved
        call mk_msg
        or a
        ret
.err:   ld hl,m_diskfull
        ld (msgptr),hl
        scf
        ret

emit_seg:                       ; HL = sorgente, BC = byte; LF -> CR LF
.l:     ld a,b
        or c
        ret z
        ld a,(hl)
        inc hl
        dec bc
        push hl
        push bc
        cp LF
        jr nz,.p
        ld a,0Dh
        call put_io
        ld a,LF
.p:     call put_io
        pop bc
        pop hl
        jr .l

put_io:                         ; A = byte da scrivere (buffer da IOSZ)
        ld hl,(iop)
        ld (hl),a
        inc hl
        ld (iop),hl
        ld de,iobuf+IOSZ
        or a
        sbc hl,de
        ret c
        jp flush_io

flush_io:
        ld hl,(iop)
        ld de,iobuf
        or a
        sbc hl,de
        ret z
        push hl
        ld de,iobuf
        ld c,F_DMA
        call BDOS
        pop hl
        push hl
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jr z,.ok
        ld a,1
        ld (ioerr),a
.ok:    pop hl
        ld de,(nbytes)
        add hl,de
        ld (nbytes),hl
        ld hl,iobuf
        ld (iop),hl
        ret

; ---------------------------------------------------------------- interfaccia
prompt_name:                    ; HL = prompt -> legge fname; C se annullato
        ld de,fname
        ld b,14
        ld c,0
        jp prompt_line

confirm_discard:                ; A = tasto; C = serve conferma (ripetere il tasto)
        ld b,a
        ld a,(modified)
        or a
        jr z,.ok
        ld a,(pendkey)
        cp b
        jr z,.ok
        ld a,b
        ld (pendkey),a
        ld hl,m_unsaved
        ld (msgptr),hl
        scf
        ret
.ok:    xor a
        ld (pendkey),a
        ret

k_new:
        ld a,0FDh               ; codice fittizio per la conferma
        call confirm_discard
        ret c
        call ed_reset
        xor a
        ld (fname),a
        ld (onfile),a
        ld (compiled),a
        ld a,1
        ld (dirty),a
        ld hl,m_newfile
        ld (msgptr),hl
        ret

k_save:
        ld a,(fname)
        or a
        jr z,k_saveas
        jp save_file
k_saveas:
        call prompt_spb
        ret c
        ld a,(fname)
        or a
        ret z
        jp save_file

; ---------------------------------------------------------------- MSX-DOS 2: SPBHOME (strumenti) e SPBPROJ (progetto)
d2_detect:                      ; isdos2; se manca, SPBHOME = directory corrente
        xor a
        ld (isdos2),a
        ld b,0
        ld c,6Fh                ; _DOSVER: solo il DOS 2 risponde con A=0 e B>=2
        call BDOS
        or a
        ret nz
        ld a,b
        cp 2
        ret c
        ld a,1
        ld (isdos2),a
        ld hl,s_envhome
        call env_get
        ld a,(iobuf)
        or a
        ret nz
        call cwd_abs
        ld hl,s_envhome
        jr env_set

cwd_abs:                        ; iobuf = "\percorso" della directory corrente
        ld a,5Ch
        ld (iobuf),a
        ld de,iobuf+1
        ld b,0
        ld c,59h                ; _GETCD
        jp BDOS

env_get:                        ; HL = nome -> iobuf = valore (vuoto se manca)
        ld de,iobuf
        xor a
        ld (de),a
        ld b,100
        ld c,6Bh                ; _GENV
        jp BDOS

env_set:                        ; HL = nome, iobuf = valore
        ld de,iobuf
        ld c,6Ch                ; _SENV
        jp BDOS

set_proj:                       ; SPBPROJ = directory corrente
        ld a,(isdos2)
        or a
        ret z
        call cwd_abs
        ld hl,s_envproj
        jr env_set

cd_home:                        ; CHDIR in SPBHOME
        ld a,(isdos2)
        or a
        ret z
        ld hl,s_envhome
cd_env:
        call env_get
        ld a,(iobuf)
        or a
        ret z
        ld de,iobuf
        ld c,5Ah                ; _CHDIR
        jp BDOS

d2_proj:                        ; ritorno dal compilatore o dal programma: si riprende il progetto (SPBPROJ)
        ld a,(isdos2)
        or a
        ret z
        ld a,(cmdok)
        ld hl,errcode
        or (hl)
        ret z                   ; avvio normale: la directory e' quella corrente
        ld hl,s_envproj
        jr cd_env

d2_path:                        ; HL = inizio del nome: con un percorso entra nella directory e HL punta al nome
        ld a,(isdos2)
        or a
        ret z
        push hl
        ld b,0
        ld c,0
.sc:    ld a,(hl)
        cp ' '
        jr z,.sd
        cp 0Dh
        jr z,.sd
        or a
        jr z,.sd
        inc hl
        inc b
        cp 5Ch
        jr nz,.sc
        ld c,b
        jr .sc
.sd:    pop hl
        ld a,c
        or a
        ret z                   ; nessun percorso
        push bc
        push hl
        ld de,iobuf
        ld b,c
        dec b
        jr z,.root
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .cp
        jr .z
.root:  ld a,5Ch
        ld (de),a
        inc de
.z:     xor a
        ld (de),a
        ld de,iobuf
        ld c,5Ah                ; _CHDIR
        call BDOS
        pop hl
        pop bc
        ld b,0
        add hl,bc
        ret

s_envhome: db "SPBHOME",0
s_envproj: db "SPBPROJ",0

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

; ---------------------------------------------------------------- Segment: cambia file in un progetto a segmenti (NOME000, NOME001...)
seg_chk:                        ; Z se fname = 5 caratteri + 3 cifre (+ estensione)
        ld hl,fname
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        cp '.'
        jr z,.e
        inc hl
        inc b
        jr .l
.e:     ld a,b
        cp 8
        jr nz,.no
        ld hl,fname+5
        ld b,3
.d:     ld a,(hl)
        sub '0'
        cp 10
        jr nc,.no
        inc hl
        djnz .d
        xor a
        ret
.no:    or 1
        ret

seg_digits:                     ; A = numero (0-255) -> 3 cifre in fname+5..7
        ld hl,fname+5
        ld d,'0'
.h:     sub 100
        jr c,.hd
        inc d
        jr .h
.hd:    add a,100
        ld (hl),d
        inc hl
        ld d,'0'
.t:     sub 10
        jr c,.td
        inc d
        jr .t
.td:    add a,10
        ld (hl),d
        inc hl
        add a,'0'
        ld (hl),a
        ret

k_segment:
        call seg_chk
        jr z,.ok
        ld hl,m_segsave
        ld a,(fname)
        or a
        jr z,.m
        ld hl,m_segname
.m:     ld (msgptr),hl
        ret
.ok:    ld hl,s_segp
        ld de,helpstr
        ld b,3
        ld c,0
        call prompt_line
        ret c
        ld hl,helpstr
        ld a,(hl)
        or a
        ret z                   ; vuoto: annulla
        ld de,0
.p:     ld a,(hl)
        or a
        jr z,.pd
        sub '0'
        cp 10
        ret nc                  ; non numerico: annulla
        push hl
        ld h,d
        ld l,e
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        jr .p
.pd:    ld a,d
        or a
        jr nz,.big
        ld a,e
        push af
        call seg_probe          ; il file corrente non cambia finche' il segmento non e' valido
        or a
        jr z,.none
        cp 2
        jr z,.bin
        ld a,(modified)
        or a
        jr z,.ns
        call save_file          ; il file corrente si salva prima di cambiare
        jr nc,.ns
        pop af
        ret
.ns:    pop af
        call seg_digits
        jp load_file
.none:  pop af
        ld hl,m_segnone
        jr .mm
.bin:   pop af
        ld hl,m_segbin
.mm:    ld (msgptr),hl
        ret
.big:   ld hl,m_segbig
        ld (msgptr),hl
        ret

seg_probe:                      ; A = numero -> A = 0 non esiste, 1 .SPB, 2 .BIN (fname resta invariato)
        push af
        ld hl,fname+5
        ld de,msgbuf
        ld bc,3
        ldir
        pop af
        call seg_digits
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        ld b,1
        or a
        jr z,.f
        call mk_fcb
        ld hl,s_binx
        ld de,fcb+9
        ld bc,3
        ldir
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        ld b,2
        or a
        jr z,.f
        jr .nn
.f:     ld a,b
        ld (tmpb),a             ; BDOS e ldir distruggono BC
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        jr .r
.nn:    xor a
        ld (tmpb),a
.r:     ld hl,msgbuf
        ld de,fname+5
        ld bc,3
        ldir
        ld a,(tmpb)
        ret

s_binx:    db "BIN"
s_segp:    db "Segment: ",0
m_segname: db "Not a segment file (5 chars+3 digits)",0
m_segsave: db "Save the file first",0
m_segnone: db "Segment file does not exist",0
m_segbin:  db "BIN segments cannot be opened",0
m_segbig:  db "Segment number 0-255",0

k_quit:
        ld a,11h
        call confirm_discard
        ret c
exit_program:
        call leave_screen
        BIOS INITXT
        jp 0

leave_screen:
        ld a,(csrsave)
        ld (CSRSW),a
        ld a,(m2flag)
        or a
        ret z                   ; MSX1: niente R#13
        xor a                   ; R#13 = 0: niente blink
        out (VDPC),a
        ld a,8Dh
        out (VDPC),a
        ret

s_open:      db "Open file: ",0
s_saveas:    db "Save as: ",0
m_loaded:    db "Loaded ",0
m_saved:     db "Saved ",0
m_notfound:  db "File not found - new file",0
m_toolarge:  db "File too large - truncated",0
m_unsaved:   db "Unsaved changes - repeat the command to discard",0
m_newfile:   db "New file",0
m_cantcreate: db "Cannot create file",0
m_diskfull:  db "Disk full or write error",0

; ---------------------------------------------------------------- F5: compila ed esegui
; Il DOS 1 non ha EXEC: si salva il sorgente, si prepara la riga di comando " NOME.BAS" e si
; carica QBC.COM a catena con il caricatore (ldr.bin) copiato a C000h.
k_run:
        ld a,(fname)
        or a
        jr nz,.ext
        call prompt_spb
        ret c
        ld a,(fname)
        or a
        ret z
.ext:   call set_proj
        ld hl,fname
.f:     ld a,(hl)
        or a
        jr z,.noext
        cp '.'
        jr z,.save
        inc hl
        jr .f
.noext: ex de,hl
        ld hl,s_bas
        ld bc,5
        ldir
.save:  ld a,(modified)
        or a
        jr nz,.dosave           ; testo cambiato: va salvato
        ld a,(onfile)
        or a
        jr z,.dosave            ; nessun file su disco: va salvato
        ld a,(compiled)
        or a
        jr z,.comp              ; invariato ma non compilato (o errore): si ricompila senza salvare
        call run_only           ; invariato e compilato: rilancia NOME.COM (ritorna solo se manca)
        jr .comp
.dosave: call save_file
        ret c
.comp:  call leave_screen
        call cd_home            ; DOS 2: QBC.COM e RT.BIN stanno nella directory degli strumenti
        ld hl,fname
        ld de,0082h
        ld bc,16
        ldir
        ld a,' '
        ld (0081h),a
        ld hl,0082h
        ld b,1
.n:     ld a,(hl)
        or a
        jr z,.d
        inc hl
        inc b
        jr .n
.d:     ld (hl),0Dh
        ld a,b
        inc a
        ld (0080h),a
        ld hl,ldr_img
        ld de,0C000h
        ld bc,ldr_size
        ldir
        ld hl,s_qbc             ; nome del programma da caricare (ldr_fn a C003h)
        ld de,0C003h
        ld bc,11
        ldir
        jp 0C000h
s_bas:  db ".SPB",0
s_qbc:  db "QBC     COM"

run_only:                       ; NOME.COM esiste? allora lo carica con il caricatore (non torna)
        call mk_fcb
        ld hl,s_com3
        ld de,fcb+9
        ld bc,3
        ldir
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        ret nz
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        call leave_screen
        ld a,1                  ; riga di comando non vuota: il programma sa di essere lanciato dall'editor e vi ritorna
        ld (0080h),a
        ld a,' '
        ld (0081h),a
        ld a,0Dh
        ld (0082h),a
        ld hl,ldr_img
        ld de,0C000h
        ld bc,ldr_size
        ldir
        ld hl,fcb+1             ; nome del programma da caricare (ldr_fn a C003h)
        ld de,0C003h
        ld bc,11
        ldir
        jp 0C000h
s_com3: db "COM"

goto_line:                      ; HL = riga (1..): cursore all'inizio della riga
        ld (tmp2),hl
        call gap_to_cur         ; il gap segue il cursore (goto_ofs lo richiede)
        ld de,0                 ; DE = offset, BC = riga corrente
        ld bc,1
.l:     push de
        ld hl,(tmp2)
        or a
        sbc hl,bc
        pop de
        jr z,.done
        jr c,.done
        ld hl,(len)
        or a
        sbc hl,de
        jr z,.done
        jr c,.done
        ld h,d
        ld l,e
        push de
        call getb
        pop de
        inc de
        cp LF
        jr nz,.l
        inc bc
        jr .l
.done:  call goto_ofs
        call upd_wantcol
        jp ensure_visible

err_message:                    ; "Line N: testo" dal codice di errore
        ld de,msgbuf
        ld hl,s_line
        call strcpy
        ld hl,(errline)
        call dec16
        ld a,':'
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        ld a,(errcode)
        or a
        jr z,.gen
        cp 21
        jr nc,.gen
        dec a
        add a,a
        ld l,a
        ld h,0
        ld bc,errtab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .cp
.gen:   ld hl,e_gen
.cp:    call strcpy
        xor a
        ld (de),a
        ld hl,msgbuf
        ld (msgptr),hl
        ret

s_line:  db "Line ",0
errtab:  dw e_1,e_2,e_3,e_4,e_5,e_6,e_7,e_8,e_9,e_10,e_11,e_12,e_13,e_14,e_15,e_16,e_17,e_18,e_19,e_20
e_gen:   db "Compile error",0
e_1:     db "Syntax error",0
e_2:     db "Undefined line number or label",0
e_3:     db "Not supported yet (strings, arrays, functions)",0
e_4:     db "Illegal character or unterminated string",0
e_5:     db "Block not closed (IF/FOR/WHILE)",0
e_6:     db "ELSE/END IF/NEXT/WEND without matching block",0
e_7:     db "Duplicate line number or label",0
e_8:     db "Too many variables, labels or nested blocks",0
e_9:     db "Program too large",0
e_10:    db "Source file too large",0
e_11:    db "Cannot read source file",0
e_12:    db "Cannot write output file",0
e_13:    db "Not allowed in this OPTION mode",0
e_14:    db "Type mismatch or array not DIMed",0
e_15:    db "Out of data memory",0
e_16:    db "Cannot read RT.BIN (runtime)",0
e_17:    db "Inline assembler: syntax error or bad operand",0
e_18:    db "Inline assembler: value or jump out of range",0
e_19:    db "Inline assembler: duplicate symbol or no __ENDASM",0
e_20:    db "Cannot read QASM.OVL (inline assembler)",0

ldr_img: INCBIN "../onmsx/build/ldr.bin"
ldr_size equ $-ldr_img

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
        call refresh            ; toglie il menu a tendina
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
        jp z,.nf
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
        call kw_reset
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
