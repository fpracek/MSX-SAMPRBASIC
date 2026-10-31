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
        ld hl,0
        ld (errline),hl
        xor a
        ld (errcode),a
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
.go:    ld de,fname
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
        jp parse_err
.none:  xor a
        ld (fname),a
        ret

parse_err:                      ; HL dopo il nome: " E<riga> <codice>" (ritorno dal compilatore)
.sk:    ld a,(hl)
        cp ' '
        jr nz,.e
        inc hl
        jr .sk
.e:     cp 'E'
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
        ld a,(fname)
        or a
        ret z
        call load_file
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
        call mk_fcb
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
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld a,(ioerr)
        or a
        jr nz,.err
        xor a
        ld (modified),a
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
        ld hl,s_saveas
        call prompt_name
        ret c
        jp save_file

k_open:
        ld a,0Fh
        call confirm_discard
        ret c
        ld hl,s_open
        call prompt_name
        ret c
        jp load_file

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
        ld hl,s_saveas
        call prompt_name
        ret c
        ld a,(fname)
        or a
        ret z
.ext:   ld hl,fname
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
.save:  call save_file
        ret c
        call leave_screen
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
s_bas:  db ".BAS",0
s_qbc:  db "QBC     COM"

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
        cp 16
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
errtab:  dw e_1,e_2,e_3,e_4,e_5,e_6,e_7,e_8,e_9,e_10,e_11,e_12,e_13,e_14,e_15
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

ldr_img: INCBIN "../onmsx/build/ldr.bin"
ldr_size equ $-ldr_img
