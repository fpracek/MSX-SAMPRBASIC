; =====================================================================
; Sequential text files (MSX-DOS 1/2, FCB + 128-byte random records): OPEN, CLOSE, PRINT#, WRITE#,
; INPUT#, LINE INPUT#, EOF, KILL. Up to 3 files (#1-#3), descriptors sit at the top of the heap.
; Descriptor (176 bytes): +0 FCB (37), +37 mode (0 closed, 1 read, 2 write, 3 append),
; +38 position in buffer, +39 valid bytes (read), +40 end of file, +41 column, +42 next record (word), +48 buffer 128
; =====================================================================
FS_MODE equ 37
FS_POS  equ 38
FS_LEN  equ 39
FS_EOF  equ 40
FS_COL  equ 41
FS_REC  equ 42
FS_BUF  equ 48
FS_RLEN equ 44                  ; record length (random access)
FS_NFLD equ 45                  ; campi FIELD definiti
FS_FOFS equ 46                  ; offset of the next field
FS_FLD  equ 176                 ; field table: 8 x (variable, offset, width)
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

bdos:                           ; C = function, DE = parameter (preserves IX)
        push ix
        call 0005h
        pop ix
        or a
        ret

ensure_pool:                    ; reserves the 3 descriptors (only once)
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

slotof:                         ; HL = number (1-3) -> IX = descriptor
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

slot_open:                      ; like slotof, but the file must be open
        call slotof
        ld a,(ix+FS_MODE)
        or a
        jp z,e_bfn
        ret

setdma:                         ; DMA = buffer of descriptor IX
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

rdrec:                          ; reads record FS_REC into the buffer: Z = ok
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

wrrec:                          ; writes the buffer to record FS_REC and advances
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

parsefn:                        ; HL = string (length, text), IX = FCB to fill
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

rt_open:                        ; OPEN HL = name, GX1 = number, GY1 = mode (1 read, 2 write, 3 append)
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
        call fcbde              ; append: open, otherwise create
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
        dec hl                  ; last record: must be re-read and we restart from the first ^Z
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
        ld l,(ix+FS_REC)        ; record full: continue with the next one
        ld h,(ix+FS_REC+1)
        inc hl
        ld (ix+FS_REC),l
        ld (ix+FS_REC+1),h
        jr .apdone
.fz:    ld (ix+FS_POS),c
.apdone:
        ld (ix+FS_MODE),3
        ret
.rnd:   ld hl,(GX2)             ; random access: record length 1-128; the file is opened or created
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
        jr z,.cl                ; random access: nothing to flush
        ld a,(ix+FS_POS)        ; writes: fills the rest with ^Z and writes
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

rt_close:                       ; CLOSE HL = number (0 = all)
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

rt_outsel:                      ; HL = PRINT# file number (0 = screen)
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

fput_sel:                       ; rt_putc character to the selected file
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

curcol:                         ; -> A = column (0 = start of line) of the current output
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

fgetc:                          ; IX = descriptor -> A = character, C = end of file (preserves BC and HL)
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

funget:                         ; puts back the last character read
        dec (ix+FS_POS)
        ret

rt_feof:                        ; EOF(n) -> HL = -1 if end of file
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

fin_start:                      ; HL = number: IX = file open for reading
        call slot_open
        ld a,(ix+FS_MODE)
        cp 1
        jp nz,e_bfm
        ret

fin_done:                       ; B = length collected in inbuf -> temporary string
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

rt_finput:                      ; INPUT # (one field) -> HL = string
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
.u:     ld c,a                  ; unquoted field: up to comma or end of line
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
.q:     call fgetc              ; quoted field
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
.qe:    call fgetc              ; after the closing quote: discard up to the separator
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

rt_kill:                        ; KILL HL = name
        push ix
        ld ix,inbuf
        call parsefn
        ld de,inbuf
        ld c,13h
        call bdos
        pop ix
        jp nz,e_fnf
        ret

rt_wint:                        ; WRITE: integer without spaces
        bit 7,h
        jr z,.p
        ld a,'-'
        push hl
        call rt_putc
        pop hl
        call rt_neghl
.p:     jp rt_udec

rt_wstr:                        ; WRITE: quoted string
        push hl
        ld a,'"'
        call rt_putc
        pop hl
        call rt_pstr
        ld a,'"'
        jp rt_putc

; --- BSAVE / BLOAD: MSX binary format (FEh, start, end, execution) + data; the FCB and the buffer live in inbuf
BBUF    equ inbuf+40

bfcb_init:                      ; HL = name: IX = FCB (inbuf), record number 0, 1-byte records
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

rt_bsave:                       ; BSAVE HL = name, GX1 = start, GY1 = length, GX2 = 1 if from VRAM
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

rt_bload:                       ; BLOAD HL = name, GX1 = offset, GY1 = 1 if to VRAM
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
        ld hl,(BBUF+3)          ; length = end - start + 1
        ld de,(BBUF+1)
        or a
        sbc hl,de
        inc hl
        push hl
        ex de,hl
        ld hl,(BBUF+1)          ; destination = start + offset
        ld de,(GX1)
        add hl,de
        ld (GX1),hl
        pop hl                  ; HL = length
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

; --- random access: records of 1-128 bytes; FIELD fields are copied into the string variables after GET and from the variables
; into the buffer before PUT (LSET is a plain assignment: PUT pads with spaces)
rt_field:                       ; HL = string variable, GX1 = file, GY1 = width, GX2 = 1 for the first field
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
        jp nc,rt_eifc           ; fields cannot exceed the record
        ld (ix+FS_FOFS),a
        inc (ix+FS_NFLD)
        ret

rec_pos:                        ; -> FCB: byte position of GY1 (0 = next record); HL = record length
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

fld_ptr:                        ; B = field index -> HL = entry
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
        call rec_pos            ; HL = record length
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
        ldir                    ; the buffer is cleared (record beyond end of file)
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
        ld a,(ix+FS_NFLD)       ; buffer -> field variables
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
        ld a,(hl)               ; offset
        inc hl
        ld c,(hl)               ; larghezza
        push de
        push ix
        pop hl
        ld de,FS_BUF
        add hl,de
        ld e,a
        ld d,0
        add hl,de               ; HL = source in the buffer
        pop de
        ld a,c
        ld (de),a               ; length = width
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
        ld a,(ix+FS_NFLD)       ; field variables -> buffer (with trailing spaces)
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
        ld a,(hl)               ; offset
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
        ex de,hl                ; DE = destination
        pop hl                  ; HL = variable (length, text)
        ld a,(hl)
        inc hl
        cp c
        jr c,.sh
        ld a,c
.sh:    ld b,a                  ; B = bytes to copy
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

rt_flof:                        ; LOF(n) -> HL = number of records (size in the FCB / record length, rounded up)
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

div8:                           ; A = remainder, D = next byte, C = divisor (< 129) -> A = new remainder, E = quotient
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

rt_rset:                        ; RSET: HL = string, DE = variable: right-aligned within the width of its FIELD field
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
