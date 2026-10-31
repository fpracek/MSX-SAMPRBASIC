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
FS_RLEN equ 44                  ; lunghezza del record (accesso casuale)
FS_NFLD equ 45                  ; campi FIELD definiti
FS_FOFS equ 46                  ; scostamento del prossimo campo
FS_FLD  equ 176                 ; tabella dei campi: 8 x (variabile, scostamento, larghezza)
FS_SIZE equ 208
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
        jp z,.in
        cp 2
        jp z,.out
        cp 4
        jp z,.rnd
        cp 3
        jp nz,e_bfm
        call fcbde              ; aggiunta: apre, altrimenti crea
        ld c,0Fh
        call bdos
        jp nz,.mk
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
.rnd:   ld hl,(GX2)             ; accesso casuale: lunghezza del record 1-128; si apre il file o lo si crea
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        or a
        jp z,rt_eifc
        cp 129
        jp nc,rt_eifc
        ld (ix+FS_RLEN),a
        ld (ix+FS_NFLD),0
        ld (ix+FS_FOFS),0
        call fcbde
        ld c,0Fh
        call bdos
        jr z,.ro
        call fcbde
        ld c,16h
        call bdos
        jp nz,e_dio
.ro:    call bfcb_rec
        ld hl,1                 ; prossimo record (da 1)
        ld (ix+FS_REC),l
        ld (ix+FS_REC+1),h
        ld (ix+FS_MODE),4
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
        cp 4
        jr z,.cl                ; accesso casuale: niente da scaricare
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

; --- BSAVE / BLOAD: formato binario MSX (FEh, inizio, fine, esecuzione) + dati; l'FCB e il buffer stanno in inbuf
BBUF    equ inbuf+40

bfcb_init:                      ; HL = nome: IX = FCB (inbuf), numero di record 0, record da 1 byte
        ld ix,inbuf
        jp parsefn

bfcb_rec:
        ld (ix+14),1
        ld (ix+15),0
        xor a
        ld (ix+33),a
        ld (ix+34),a
        ld (ix+35),a
        ret

rt_bsave:                       ; BSAVE HL = nome, GX1 = inizio, GY1 = lunghezza, GX2 = 1 se dalla VRAM
        push ix
        call bfcb_init
        ld de,inbuf
        ld c,13h
        call bdos
        ld de,inbuf
        ld c,16h
        call bdos
        jp nz,e_dio
        call bfcb_rec
        ld hl,BBUF
        ld (hl),0FEh
        inc hl
        ld de,(GX1)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld hl,(GX1)
        ld de,(GY1)
        add hl,de
        dec hl
        ex de,hl
        ld hl,BBUF+3
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(GX1)
        ld (hl),e
        inc hl
        ld (hl),d
        ld de,BBUF
        ld c,1Ah
        call bdos
        ld hl,7
        ld de,inbuf
        ld c,26h
        call bdos
        jp nz,e_dio
        ld a,(GX2)
        or a
        jr nz,.vram
        ld de,(GX1)
        ld c,1Ah
        call bdos
        ld hl,(GY1)
        ld a,h
        or l
        jr z,.cl
        ld de,inbuf
        ld c,26h
        call bdos
        jp nz,e_dio
        jr .cl
.vram:  ld hl,(GY1)
        ld a,h
        or l
        jr z,.cl
        ld de,128
        or a
        sbc hl,de
        jr nc,.full
        ld hl,(GY1)
        ld b,l
        ld hl,0
        ld (GY1),hl
        jr .rd
.full:  ld (GY1),hl
        ld b,128
.rd:    push bc
        call ubank_on
        ld hl,(GX1)
        xor a
        call vram_set
        ld hl,BBUF
        ld c,VDPD
        inir
        call ubank_off
        pop bc
        ld a,b
        ld hl,(GX1)
        ld e,b
        ld d,0
        add hl,de
        ld (GX1),hl
        push bc
        ld de,BBUF
        ld c,1Ah
        call bdos
        pop bc
        ld l,b
        ld h,0
        ld de,inbuf
        ld c,26h
        call bdos
        jp nz,e_dio
        jr .vram
.cl:    ld de,inbuf
        ld c,10h
        call bdos
        pop ix
        ret

rt_bload:                       ; BLOAD HL = nome, GX1 = scostamento, GY1 = 1 se verso la VRAM
        push ix
        call bfcb_init
        ld de,inbuf
        ld c,0Fh
        call bdos
        jp nz,e_fnf
        call bfcb_rec
        ld de,BBUF
        ld c,1Ah
        call bdos
        ld hl,7
        ld de,inbuf
        ld c,27h
        call bdos
        ld a,(BBUF)
        cp 0FEh
        jp nz,e_bfm
        ld hl,(BBUF+3)          ; lunghezza = fine - inizio + 1
        ld de,(BBUF+1)
        or a
        sbc hl,de
        inc hl
        push hl
        ex de,hl
        ld hl,(BBUF+1)          ; destinazione = inizio + scostamento
        ld de,(GX1)
        add hl,de
        ld (GX1),hl
        pop hl                  ; HL = lunghezza
        ld (GY2),hl
        ld a,(GY1)
        or a
        jr nz,.vram
        ld de,(GX1)
        ld c,1Ah
        call bdos
        ld hl,(GY2)
        ld a,h
        or l
        jr z,.cl
        ld de,inbuf
        ld c,27h
        call bdos
        jr .cl
.vram:  ld hl,(GY2)
        ld a,h
        or l
        jr z,.cl
        ld de,128
        or a
        sbc hl,de
        jr nc,.full
        ld hl,(GY2)
        ld b,l
        ld hl,0
        ld (GY2),hl
        jr .rd
.full:  ld (GY2),hl
        ld b,128
.rd:    push bc
        ld de,BBUF
        ld c,1Ah
        call bdos
        pop bc
        push bc
        ld l,b
        ld h,0
        ld de,inbuf
        ld c,27h
        call bdos
        call ubank_on
        ld hl,(GX1)
        ld a,40h
        call vram_set
        pop bc
        push bc
        ld hl,BBUF
        ld c,VDPD
        otir
        call ubank_off
        pop bc
        ld hl,(GX1)
        ld e,b
        ld d,0
        add hl,de
        ld (GX1),hl
        jr .vram
.cl:    ld de,inbuf
        ld c,10h
        call bdos
        pop ix
        ret

; --- accesso casuale: record di 1-128 byte; i campi FIELD si copiano nelle variabili stringa dopo GET e dalle variabili
; nel buffer prima di PUT (LSET e' un semplice assegnamento: PUT completa con spazi)
rt_field:                       ; HL = variabile stringa, GX1 = file, GY1 = larghezza, GX2 = 1 per il primo campo
        push hl
        ld hl,(GX1)
        call slot_open
        ld a,(ix+FS_MODE)
        cp 4
        jp nz,e_bfm
        ld a,(GX2)
        or a
        jr z,.nr
        xor a
        ld (ix+FS_NFLD),a
        ld (ix+FS_FOFS),a
.nr:    ld a,(ix+FS_NFLD)
        cp 8
        jp nc,rt_eifc
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        push ix
        pop hl
        ld bc,FS_FLD
        add hl,bc
        add hl,de
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(ix+FS_FOFS)
        ld (hl),a
        inc hl
        ld a,(GY1)
        ld (hl),a
        add a,(ix+FS_FOFS)
        jp c,rt_eifc
        cp 129
        jp nc,rt_eifc
        ld b,(ix+FS_RLEN)
        inc b
        cp b
        jp nc,rt_eifc           ; i campi non possono superare il record
        ld (ix+FS_FOFS),a
        inc (ix+FS_NFLD)
        ret

rec_pos:                        ; -> FCB: posizione in byte di GY1 (0 = prossimo record); HL = lunghezza del record
        ld l,(ix+FS_REC)
        ld h,(ix+FS_REC+1)
        ld de,(GY1)
        ld a,d
        or e
        jr z,.nx
        ex de,hl
.nx:    ld a,h
        or l
        jp z,rt_eifc            ; i record partono da 1
        push hl
        inc hl
        ld (ix+FS_REC),l
        ld (ix+FS_REC+1),h
        pop hl
        dec hl
        ex de,hl                ; DE = record - 1
        ld c,0
        ld hl,0
        ld a,(ix+FS_RLEN)
        ld b,8
.m:     add hl,hl
        rl c
        rlca
        jr nc,.n
        add hl,de
        jr nc,.n
        inc c
.n:     djnz .m
        ld (ix+33),l
        ld (ix+34),h
        ld (ix+35),c
        ld l,(ix+FS_RLEN)
        ld h,0
        ret

fld_ptr:                        ; B = indice del campo -> HL = voce
        ld a,b
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        push ix
        pop hl
        ld bc,FS_FLD
        add hl,bc
        add hl,de
        ret

rt_fget:                        ; GET #n [, record]
        ld hl,(GX1)
        call slot_open
        ld a,(ix+FS_MODE)
        cp 4
        jp nz,e_bfm
        call rec_pos            ; HL = lunghezza del record
        push hl
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,127
        ldir                    ; il buffer si azzera (record oltre la fine del file)
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ex de,hl
        ld c,1Ah
        call bdos
        pop hl
        call fcbde
        ld c,27h
        call bdos
        ld a,(ix+FS_NFLD)       ; buffer -> variabili dei campi
        or a
        ret z
        ld b,a
        ld c,0
.f:     push bc
        ld b,c
        call fld_ptr
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = variabile
        inc hl
        ld a,(hl)               ; scostamento
        inc hl
        ld c,(hl)               ; larghezza
        push de
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ld e,a
        ld d,0
        add hl,de               ; HL = origine nel buffer
        pop de
        ld a,c
        ld (de),a               ; lunghezza = larghezza
        inc de
        ld b,0
        ldir
        pop bc
        inc c
        djnz .f
        ret

rt_fput:                        ; PUT #n [, record]
        ld hl,(GX1)
        call slot_open
        ld a,(ix+FS_MODE)
        cp 4
        jp nz,e_bfm
        ld a,(ix+FS_NFLD)       ; variabili dei campi -> buffer (con spazi in coda)
        or a
        jr z,.go
        ld b,a
        ld c,0
.f:     push bc
        ld b,c
        call fld_ptr
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = variabile
        inc hl
        ld a,(hl)               ; scostamento
        inc hl
        ld c,(hl)               ; larghezza
        push de
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ld e,a
        ld d,0
        add hl,de
        ex de,hl                ; DE = destinazione
        pop hl                  ; HL = variabile (lunghezza, testo)
        ld a,(hl)
        inc hl
        cp c
        jr c,.sh
        ld a,c
.sh:    ld b,a                  ; B = byte da copiare
        ld a,c
        sub b
        ld c,a                  ; C = spazi in coda
        ld a,b
        or a
        jr z,.pad
        ld b,0
        push bc
        ld c,a
        ldir
        pop bc
.pad:   ld a,c
        or a
        jr z,.nx
        ld b,a
.sp:    ld a,' '
        ld (de),a
        inc de
        djnz .sp
.nx:    pop bc
        inc c
        djnz .f
.go:    call rec_pos
        push hl
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ex de,hl
        ld c,1Ah
        call bdos
        pop hl
        call fcbde
        ld c,26h
        call bdos
        jp nz,e_dio
        ret

rt_flof:                        ; LOF(n) -> HL = numero di record (dimensione nell'FCB / lunghezza del record, per eccesso)
        call slot_open
        ld a,(ix+FS_MODE)
        cp 4
        jp nz,e_bfm
        ld c,(ix+FS_RLEN)
        xor a
        ld d,(ix+18)
        call div8
        ld d,(ix+17)
        call div8
        ld h,e
        ld d,(ix+16)
        call div8
        ld l,e
        or a
        ret z                   ; nessun resto
        inc hl
        ret

div8:                           ; A = resto, D = byte seguente, C = divisore (< 129) -> A = nuovo resto, E = quoziente
        ld b,8
        ld e,0
.l:     sla d
        rla
        cp c
        jr c,.z
        sub c
        sla e
        inc e
        jr .nx
.z:     sla e
.nx:    djnz .l
        ret

rt_rset:                        ; RSET: HL = stringa, DE = variabile: allineata a destra nella larghezza del suo campo FIELD
        ld (S1),de
        push hl
        ld hl,0
        ld (S2),hl
        ld de,(FILEP)
        ld a,d
        or e
        jr z,.go
        ld b,3
.sl:    push bc
        push de
        push de
        pop ix
        ld a,(ix+FS_MODE)
        cp 4
        jr nz,.nx
        ld a,(ix+FS_NFLD)
        or a
        jr z,.nx
        ld b,a
        push ix
        pop hl
        ld de,FS_FLD
        add hl,de
.fl:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(S1)
        or a
        sbc hl,de
        pop hl
        jr nz,.ne
        inc hl
        ld a,(hl)
        ld (S2),a
        pop de
        pop bc
        jr .go
.ne:    inc hl
        inc hl
        djnz .fl
.nx:    pop de
        ld hl,FS_SIZE
        add hl,de
        ex de,hl
        pop bc
        djnz .sl
.go:    pop hl
        ld a,(S2)
        or a
        jr nz,.pad
        ld de,(S1)
        jp rt_scopy
.pad:   ld c,a
        ld a,(hl)
        inc hl
        cp c
        jr c,.sh
        ld a,c
.sh:    ld b,a
        ld a,c
        ld (inbuf),a
        sub b
        ld de,inbuf+1
        jr z,.cp
        push bc
        ld b,a
.sp:    ld a,' '
        ld (de),a
        inc de
        djnz .sp
        pop bc
.cp:    ld a,b
        or a
        jr z,.fin
        ld c,b
        ld b,0
        ldir
.fin:   ld hl,inbuf
        ld de,(S1)
        jp rt_scopy
