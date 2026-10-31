; =====================================================================
; File sequenziali di testo (MSX-DOS 1/2, FCB + record casuali da 128 byte): OPEN, CLOSE, PRINT#, WRITE#,
; INPUT#, LINE INPUT#, EOF, KILL. Fino a 3 file (#1-#3), i descrittori stanno in cima allo heap.
; Descrittore (176 byte): +0 FCB (37), +37 modo (0 chiuso, 1 lettura, 2 scrittura, 3 aggiunta),
; +38 posizione nel buffer, +39 byte validi (lettura), +40 fine file, +41 colonna, +42 prossimo record (word), +48 buffer 128
; =====================================================================
FS_MODE equ 37
FS_POS  equ 38
FS_LEN  equ 39
FS_EOF  equ 40
FS_COL  equ 41
FS_REC  equ 42
FS_BUF  equ 48
FS_SIZE equ 176
FS_POOL equ 3*FS_SIZE

msg_fnf: db msg_fnf_e-msg_fnf-1,"Error: File not found"
msg_fnf_e:
msg_bfn: db msg_bfn_e-msg_bfn-1,"Error: Bad file number"
msg_bfn_e:
msg_dio: db msg_dio_e-msg_dio-1,"Error: Disk full or I/O error"
msg_dio_e:
msg_fao: db msg_fao_e-msg_fao-1,"Error: File already open"
msg_fao_e:
msg_pae: db msg_pae_e-msg_pae-1,"Error: Input past end"
msg_pae_e:
msg_bfm: db msg_bfm_e-msg_bfm-1,"Error: Bad file mode"
msg_bfm_e:

e_fnf:  ld hl,msg_fnf
        jp rt_fatal
e_bfn:  ld hl,msg_bfn
        jp rt_fatal
e_dio:  ld hl,msg_dio
        jp rt_fatal
e_bfm:  ld hl,msg_bfm
        jp rt_fatal
e_pae:  ld hl,msg_pae
        jp rt_fatal

bdos:                           ; C = funzione, DE = parametro (conserva IX)
        push ix
        call 0005h
        pop ix
        or a
        ret

ensure_pool:                    ; riserva i 3 descrittori (una volta sola)
        ld hl,(FILEP)
        ld a,h
        or l
        ret nz
        ld hl,(heapend)
        ld de,-FS_POOL
        add hl,de
        push hl
        ld de,(heapp)
        inc d
        inc d
        inc d
        inc d
        or a
        sbc hl,de
        pop hl
        jp c,rt_oom
        ld (heapend),hl
        ld (FILEP),hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,FS_POOL-1
        ldir
        ret

slotof:                         ; HL = numero (1-3) -> IX = descrittore
        ld a,h
        or a
        jp nz,e_bfn
        ld a,l
        or a
        jp z,e_bfn
        cp 4
        jp nc,e_bfn
        ld b,a
        ld hl,(FILEP)
        ld a,h
        or l
        jp z,e_bfn
        ld de,FS_SIZE
        dec b
        jr z,.d
.l:     add hl,de
        djnz .l
.d:     push hl
        pop ix
        ret

slot_open:                      ; come slotof, ma il file deve essere aperto
        call slotof
        ld a,(ix+FS_MODE)
        or a
        jp z,e_bfn
        ret

setdma:                         ; DMA = buffer del descrittore IX
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ex de,hl
        ld c,1Ah
        jp bdos

setrec:                         ; campo record casuale = FS_REC
        ld l,(ix+FS_REC)
        ld h,(ix+FS_REC+1)
        ld (ix+33),l
        ld (ix+34),h
        ld (ix+35),0
        ret

fcbde:  push ix
        pop de
        ret

rdrec:                          ; legge il record FS_REC nel buffer: Z = ok
        call setdma
        call fcbde
        ld a,(ix+FS_MODE)
        cp 1
        ld c,14h                ; lettura: sequenziale
        jr z,.go
        push de
        call setrec
        pop de
        ld c,21h                ; aggiunta: record casuale
.go:    jp bdos

wrrec:                          ; scrive il buffer nel record FS_REC e avanza
        call setdma
        call setrec
        call fcbde
        ld c,22h
        call bdos
        jp nz,e_dio
        inc (ix+FS_REC)
        ret nz
        inc (ix+FS_REC+1)
        ret

parsefn:                        ; HL = stringa (lunghezza, testo), IX = FCB da riempire
        push hl
        push ix
        pop hl
        ld (hl),0
        ld d,h
        ld e,l
        inc de
        ld bc,36
        ldir
        push ix
        pop hl
        inc hl
        ld b,11
        ld a,' '
.sp:    ld (hl),a
        inc hl
        djnz .sp
        pop hl
        ld b,(hl)
        inc hl
        ld a,b
        cp 2
        jr c,.nd
        inc hl
        ld a,(hl)
        dec hl
        cp ':'
        jr nz,.nd
        ld a,(hl)
        and 0DFh
        sub 'A'-1
        ld (ix+0),a
        inc hl
        inc hl
        dec b
        dec b
.nd:    push ix
        pop de
        inc de
        ld c,8
.nm:    ld a,b
        or a
        ret z
        ld a,(hl)
        inc hl
        dec b
        cp '.'
        jr z,.ex
        push af
        ld a,c
        or a
        jr z,.s1
        dec c
        pop af
        call fupper
        ld (de),a
        inc de
        jr .nm
.s1:    pop af
        jr .nm
.ex:    push ix
        pop de
        ld a,e
        add a,9
        ld e,a
        jr nc,.x1
        inc d
.x1:    ld c,3
.e1:    ld a,b
        or a
        ret z
        ld a,(hl)
        inc hl
        dec b
        push af
        ld a,c
        or a
        jr z,.s2
        dec c
        pop af
        call fupper
        ld (de),a
        inc de
        jr .e1
.s2:    pop af
        jr .e1

fupper: cp 'a'
        ret c
        cp '{'
        ret nc
        sub 32
        ret

rt_open:                        ; OPEN HL = nome, GX1 = numero, GY1 = modo (1 lettura, 2 scrittura, 3 aggiunta)
        push hl
        call ensure_pool
        ld hl,(GX1)
        call slotof
        ld a,(ix+FS_MODE)
        or a
        jp nz,e_bfn
        pop hl
        call parsefn
        xor a
        ld (ix+FS_POS),a
        ld (ix+FS_LEN),a
        ld (ix+FS_EOF),a
        ld (ix+FS_COL),a
        ld (ix+FS_REC),a
        ld (ix+FS_REC+1),a
        ld a,(GY1)
        cp 1
        jr z,.in
        cp 2
        jr z,.out
        cp 3
        jp nz,e_bfm
        call fcbde              ; aggiunta: apre, altrimenti crea
        ld c,0Fh
        call bdos
        jr nz,.mk
        call fcbde
        ld c,23h                ; dimensione in record
        call bdos
        ld l,(ix+33)
        ld h,(ix+34)
        ld a,h
        or l
        jr z,.apdone
        dec hl                  ; ultimo record: va riletto e si riparte dal primo ^Z
        ld (ix+FS_REC),l
        ld (ix+FS_REC+1),h
        call rdrec
        jr nz,.apdone
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ld b,128
        ld c,0
.sz:    ld a,(hl)
        cp 1Ah
        jr z,.fz
        inc hl
        inc c
        djnz .sz
        ld l,(ix+FS_REC)        ; record pieno: si prosegue con il successivo
        ld h,(ix+FS_REC+1)
        inc hl
        ld (ix+FS_REC),l
        ld (ix+FS_REC+1),h
        jr .apdone
.fz:    ld (ix+FS_POS),c
.apdone:
        ld (ix+FS_MODE),3
        ret
.out:   call fcbde
        ld c,13h                ; cancella l'eventuale file precedente
        call bdos
.mk:    call fcbde
        ld c,16h
        call bdos
        jp nz,e_dio
        ld a,(GY1)
        ld (ix+FS_MODE),a
        ret
.in:    call fcbde
        ld c,0Fh
        call bdos
        jp nz,e_fnf
        ld (ix+FS_MODE),1
        ret

close_slot:                     ; IX = descrittore
        ld a,(ix+FS_MODE)
        or a
        ret z
        cp 1
        jr z,.cl
        ld a,(ix+FS_POS)        ; scritture: riempie il resto con ^Z e scrive
        or a
        jr z,.cl
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ld e,a
        ld d,0
        add hl,de
        ld b,128
        sub b
        neg
        ld b,a
.fz:    ld (hl),1Ah
        inc hl
        djnz .fz
        call wrrec
.cl:    call fcbde
        ld c,10h
        call bdos
        ld (ix+FS_MODE),0
        ret

rt_close:                       ; CLOSE HL = numero (0 = tutti)
        ld a,h
        or l
        jr z,files_close_all
        call slotof
        jp close_slot

files_close_all:
        ld hl,(FILEP)
        ld a,h
        or l
        ret z
        ld b,3
        push ix
.l:     push bc
        push hl
        push hl
        pop ix
        call close_slot
        pop hl
        ld de,FS_SIZE
        add hl,de
        pop bc
        djnz .l
        pop ix
        xor a
        ld (OUTSEL),a
        ret

rt_outsel:                      ; HL = numero del file di PRINT# (0 = schermo)
        ld a,h
        or l
        jr z,.set
        push hl
        call slotof
        pop hl
        ld a,(ix+FS_MODE)
        cp 2
        jr c,.bm
        cp 4
        jr nc,.bm
.set:   ld a,l
        ld (OUTSEL),a
        ret
.bm:    jp e_bfm

fputc:                          ; A = carattere, IX = descrittore (scrittura)
        push af
        push ix
        pop hl
        ld e,(ix+FS_POS)
        ld d,0
        add hl,de
        ld de,FS_BUF
        add hl,de
        pop af
        ld (hl),a
        cp 13
        jr nz,.nc
        ld (ix+FS_COL),0
        jr .ad
.nc:    cp 32
        jr c,.ad
        inc (ix+FS_COL)
.ad:    inc (ix+FS_POS)
        ld a,(ix+FS_POS)
        cp 128
        ret nz
        call wrrec
        ld (ix+FS_POS),0
        ret

fput_sel:                       ; carattere di rt_putc verso il file selezionato
        push hl
        push de
        push bc
        push ix
        push af
        ld a,(OUTSEL)
        ld l,a
        ld h,0
        call slotof
        pop af
        call fputc
        pop ix
        pop bc
        pop de
        pop hl
        ret

curcol:                         ; -> A = colonna (0 = inizio riga) dell'uscita corrente
        ld a,(OUTSEL)
        or a
        jr nz,.f
        ld a,(CSRX)
        dec a
        ret
.f:     push ix
        push hl
        ld l,a
        ld h,0
        call slotof
        ld a,(ix+FS_COL)
        pop hl
        pop ix
        ret

fgetc:                          ; IX = descrittore -> A = carattere, C = fine file (conserva BC e HL)
        push bc
        push hl
        call fgetc0
        pop hl
        pop bc
        ret

fgetc0:
        ld a,(ix+FS_EOF)
        or a
        jr nz,.eof
.again: ld a,(ix+FS_POS)
        ld b,(ix+FS_LEN)
        cp b
        jr c,.have
        call rdrec
        jr nz,.se
        ld (ix+FS_POS),0
        ld (ix+FS_LEN),128
        inc (ix+FS_REC)
        jr nz,.again
        inc (ix+FS_REC+1)
        jr .again
.have:  push ix
        pop hl
        ld e,a
        ld d,0
        add hl,de
        ld de,FS_BUF
        add hl,de
        ld a,(hl)
        inc (ix+FS_POS)
        cp 1Ah
        jr nz,.ok
.se:    ld (ix+FS_EOF),1
.eof:   scf
        ret
.ok:    or a
        ret

funget:                         ; rimette indietro l'ultimo carattere letto
        dec (ix+FS_POS)
        ret

rt_feof:                        ; EOF(n) -> HL = -1 se fine file
        call slot_open
        ld hl,-1
        ld a,(ix+FS_MODE)
        cp 1
        ret nz
        call fgetc
        ret c
        call funget
        ld hl,0
        ret

fin_start:                      ; HL = numero: IX = file in lettura
        call slot_open
        ld a,(ix+FS_MODE)
        cp 1
        jp nz,e_bfm
        ret

fin_done:                       ; B = lunghezza raccolta in inbuf -> stringa temporanea
        ld a,b
        ld (inbuf),a
        ld hl,inbuf
        jp rt_sdup

rt_fline:                       ; LINE INPUT # -> HL = stringa
        call fin_start
        ld hl,inbuf+1
        ld b,0
        call fgetc
        jp c,e_pae
.l:     cp 13
        jr z,.cr
        cp 10
        jr z,.end
        ld c,a
        ld a,b
        cp 250
        jr nc,.n
        ld a,c
        ld (hl),a
        inc hl
        inc b
.n:     call fgetc
        jr nc,.l
        jr .end
.cr:    call fgetc
        jr c,.end
        cp 10
        jr z,.end
        call funget
.end:   jp fin_done

rt_finput:                      ; INPUT # (un campo) -> HL = stringa
        call fin_start
        ld hl,inbuf+1
        ld b,0
.sk:    call fgetc
        jp c,e_pae
        cp ' '
        jr z,.sk
        cp 9
        jr z,.sk
        cp 13
        jr z,.cr
        cp 10
        jr z,.end
        cp '"'
        jr z,.q
.u:     ld c,a                  ; campo senza virgolette: fino a virgola o fine riga
        ld a,b
        cp 250
        jr nc,.un
        ld a,c
        ld (hl),a
        inc hl
        inc b
.un:    call fgetc
        jr c,.end
        cp ','
        jr z,.end
        cp 13
        jr z,.cr
        cp 10
        jr z,.end
        jr .u
.q:     call fgetc              ; campo tra virgolette
        jr c,.end
        cp '"'
        jr z,.qe
        ld c,a
        ld a,b
        cp 250
        jr nc,.q
        ld a,c
        ld (hl),a
        inc hl
        inc b
        jr .q
.qe:    call fgetc              ; dopo la chiusura: si scarta fino al separatore
        jr c,.end
        cp ','
        jr z,.end
        cp 13
        jr z,.cr
        cp 10
        jr z,.end
        jr .qe
.cr:    call fgetc
        jr c,.end
        cp 10
        jr z,.end
        call funget
.end:   jp fin_done

rt_kill:                        ; KILL HL = nome
        push ix
        ld ix,inbuf
        call parsefn
        ld de,inbuf
        ld c,13h
        call bdos
        pop ix
        jp nz,e_fnf
        ret

rt_wint:                        ; WRITE: intero senza spazi
        bit 7,h
        jr z,.p
        ld a,'-'
        push hl
        call rt_putc
        pop hl
        call rt_neghl
.p:     jp rt_udec

rt_wstr:                        ; WRITE: stringa tra virgolette
        push hl
        ld a,'"'
        call rt_putc
        pop hl
        call rt_pstr
        ld a,'"'
        jp rt_putc
