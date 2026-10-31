; ---------------------------------------------------------------- variabili locali e comando E (solo .COM)
        IFNDEF ROMMODE
dbg_findr:                      ; -> IY = record della routine che contiene la riga corrente; C se nessuna
        ld hl,(DBGT)
        ld a,h
        or l
        jr z,.no
        ld a,(hl)
        inc hl
        ex de,hl                ; DE = tabella + 1
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de               ; dopo i record delle globali: puntatore all'ultimo record delle locali
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.w:     ld a,h
        or l
        jr z,.no
        push hl
        pop iy
        ld ix,(DBGP)
        ld e,(iy+2)
        ld d,(iy+3)
        ld l,(ix+D_LINE)
        ld h,(ix+D_LINE+1)
        or a
        sbc hl,de               ; riga - inizio
        jr c,.nx
        ld e,(ix+D_LINE)
        ld d,(ix+D_LINE+1)
        ld l,(iy+4)
        ld h,(iy+5)
        or a
        sbc hl,de               ; fine - riga
        ret nc                  ; trovata
.nx:    ld l,(iy+0)
        ld h,(iy+1)
        jr .w
.no:    scf
        ret

dbg_laddr:                      ; IY = record locale -> HL = indirizzo del valore; C se non mostrabile (condivise, array)
        ld a,(iy+12)
        cp 2
        jr z,.no
        cp 5
        jr nc,.no
        ld ix,(DBGP)
        ld l,(ix+D_FR)
        ld h,(ix+D_FR+1)
        ld e,(iy+13)
        ld d,(iy+14)
        cp 1
        jr z,.o
        ld d,0                  ; scostamento a 8 bit con segno
        bit 7,e
        jr z,.o
        dec d
.o:     add hl,de
        ld a,(iy+12)
        cp 4
        jr nz,.ok
        ld e,(hl)               ; parametro stringa: il frame contiene il puntatore al buffer
        inc hl
        ld d,(hl)
        ex de,hl
.ok:    or a
        ret
.no:    scf
        ret

dbg_vlocals:                    ; righe delle variabili locali della routine corrente (prefisso '>')
        call dbg_findr
        ret c
        ld b,(iy+6)
        push iy
        pop hl
        ld de,7
        add hl,de
.r:     ld a,b
        or a
        ret z
        push bc
        push hl
        push hl
        pop iy
        call dbg_laddr
        jr c,.sk
        ld c,'>'
        call dbg_vline
.sk:    pop hl
        ld de,16
        add hl,de
        pop bc
        dec b
        jr .r

dbg_qbp:                        ; HL = buffer di testo del comando E (conserva DE)
        push de
        ld hl,(DBGP)
        ld de,D_QB
        add hl,de
        pop de
        ret

dbg_qread:                      ; legge il nome della variabile; C se annullato
        ld ix,(DBGP)
        xor a
        ld (ix+D_ND),a
        call dbg_qbp
        ld (hl),0
.show:  call dbg_lclr
        ld hl,t_qask
        call dbg_cat
        call dbg_qbp
        call dbg_cat
        ld a,20
        call dbg_row
.k:     call dbg_key
        cp 27
        jr z,.esc
        cp 13
        jr z,.done
        cp 8
        jr z,.bs
        cp 127
        jr z,.bs
        cp '_'
        jr z,.ok
        cp '$'
        jr z,.ok
        cp '('
        jr z,.ok
        cp ')'
        jr z,.ok
        cp '0'
        jr c,.k
        cp '9'+1
        jr c,.ok
        cp 'A'
        jr c,.k
        cp 'Z'+1
        jr nc,.k
.ok:    ld c,a
        ld ix,(DBGP)
        ld a,(ix+D_ND)
        cp 20
        jr nc,.k
        inc (ix+D_ND)
        ld e,a
        ld d,0
        call dbg_qbp
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),0
        jr .show
.bs:    ld ix,(DBGP)
        ld a,(ix+D_ND)
        or a
        jr z,.k
        dec a
        ld (ix+D_ND),a
        ld e,a
        ld d,0
        call dbg_qbp
        add hl,de
        ld (hl),0
        jr .show
.done:  ld ix,(DBGP)
        ld a,(ix+D_ND)
        or a
        jr z,.esc               ; testo vuoto: niente da cercare
        or a
        ret
.esc:   scf
        ret

dbg_qparse:                     ; testo "NOME[$][(n)]" -> modello di 12 byte (qbuf+24) e indice (D_QX)
        ld ix,(DBGP)
        xor a
        ld (ix+D_QX),a
        ld (ix+D_QX+1),a
        ld (ix+D_QX+2),a
        call dbg_qbp
        ld de,24
        add hl,de
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,11
        ldir                    ; modello = 12 zeri
        call dbg_qbp
        ld de,24
        add hl,de
        ex de,hl                ; DE = modello
        call dbg_qbp            ; HL = testo
        ld b,11
.pn:    ld a,(hl)
        or a
        jr z,.pe
        cp '('
        jr z,.pe
        cp '$'
        jr z,.sf
        inc hl
        ld c,a
        ld a,b
        or a
        jr z,.pn
        ld a,c
        ld (de),a
        inc de
        dec b
        jr .pn
.sf:    inc hl
        push hl
        call dbg_qbp
        ld de,24+11
        add hl,de
        ld (hl),'$'
        pop hl
.pe:    ld a,(hl)
        cp '('
        ret nz
        inc hl
        ld de,0
.pd:    ld a,(hl)
        sub '0'
        cp 10
        jr nc,.pf
        push hl
        ld h,d
        ld l,e
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; x10
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        jr .pd
.pf:    ld ix,(DBGP)
        ld (ix+D_QX),1
        ld (ix+D_QX+1),e
        ld (ix+D_QX+2),d
        ret

dbg_cmpn:                       ; IY = record: Z se il nome coincide con il modello
        call dbg_qbp
        ld de,24
        add hl,de               ; HL = modello
        push iy
        pop de                  ; DE = record
        ld b,11
.l:     ld a,(de)
        cp (hl)
        ret nz
        or a
        jr z,.sx
        inc hl
        inc de
        djnz .l
.sx:    call dbg_qbp
        ld de,24+11
        add hl,de
        ld a,(hl)
        cp '$'
        ld a,0
        jr nz,.a
        inc a
.a:     ld c,a
        ld a,(iy+11)
        cp '$'
        ld a,0
        jr nz,.b
        inc a
.b:     cp c
        ret

dbg_qfind:                      ; -> NC: A = 0 scalare (IY record, HL indirizzo) o A = 1 array globale (IY record); C se non trovata
        call dbg_findr
        jr c,.glob
        ld b,(iy+6)
        push iy
        pop hl
        ld de,7
        add hl,de
.lr:    ld a,b
        or a
        jr z,.glob
        push bc
        push hl
        push hl
        pop iy
        call dbg_cmpn
        jr nz,.ln
        call dbg_laddr
        jr c,.ln
        pop de
        pop bc
        xor a
        ret                     ; xor a lascia NC
.ln:    pop hl
        ld de,16
        add hl,de
        pop bc
        dec b
        jr .lr
.glob:  ld hl,(DBGT)
        ld a,h
        or l
        jr z,.nf
        ld b,(hl)
        inc hl
.gr:    ld a,b
        or a
        jr z,.nf
        push bc
        push hl
        push hl
        pop iy
        call dbg_cmpn
        jr nz,.gn
        pop hl
        pop bc
        ld a,(iy+14)
        or (iy+15)
        jr nz,.ga
        ld l,(iy+12)
        ld h,(iy+13)
        xor a
        ret
.ga:    ld a,1
        or a
        ret
.gn:    pop hl
        ld de,16
        add hl,de
        pop bc
        dec b
        jr .gr
.nf:    scf
        ret

dbg_qmsg:                       ; HL = messaggio -> riga 21
        push hl
        call dbg_lclr
        pop hl
        call dbg_cat
        ld a,21
        jp dbg_row

dbg_query:                      ; comando E: nome della variabile (anche A(3), N$) -> valore
        call dbg_qread
        ret c
        call dbg_qparse
        call dbg_qfind
        jp c,.nf
        or a
        jr nz,.arr
        ld ix,(DBGP)            ; scalare
        ld (ix+D_QX),0
        ld (ix+D_VS),0
        ld (ix+D_VR),21
        ld (ix+D_VM),22
        ld c,0
        call dbg_vline
        jr .wait
.arr:   ld a,(iy+15)
        bit 7,a
        jr nz,.map
        ld ix,(DBGP)
        ld a,(ix+D_QX)
        or a
        jr z,.cnt
        ld l,(ix+D_QX+1)
        ld h,(ix+D_QX+2)
        ld e,(iy+14)
        ld d,(iy+15)
        or a
        sbc hl,de
        jr nc,.rng
        ld l,(ix+D_QX+1)
        ld h,(ix+D_QX+2)
        ld a,(iy+11)
        cp '$'
        jr z,.es
        add hl,hl               ; interi: 2 byte per elemento
        jr .ea
.es:    ld h,l                  ; stringhe: 256 byte per elemento
        ld l,0
.ea:    ld e,(iy+12)
        ld d,(iy+13)
        add hl,de
        ld (ix+D_VS),0
        ld (ix+D_VR),21
        ld (ix+D_VM),22
        ld c,0
        call dbg_vline
        jr .wait
.cnt:   call dbg_lclr
        ld hl,t_qarr
        call dbg_cat
        ld l,(iy+14)
        ld h,(iy+15)
        call dbg_udec
        ld a,21
        call dbg_row
        jr .wait
.map:   ld hl,t_qmap
        jr .m
.rng:   ld hl,t_qrng
        jr .m
.nf:    ld hl,t_qnf
.m:     call dbg_qmsg
.wait:  call dbg_lclr
        ld hl,t_qkey
        call dbg_cat
        ld a,22
        call dbg_row
        call dbg_key
        ld ix,(DBGP)
        xor a
        ld (ix+D_QX),a
        ret
        ELSE
dbg_vlocals:
        ret
dbg_query:
        ret
        ENDIF
