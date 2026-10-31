; =====================================================================
; Mapper RAM (MSX2): segmenti da 16 KB visti attraverso la pagina 2 (8000h-BFFF, porta FEh).
; MAPPERSEGS, MGET, MPUT, MREAD, MWRITE. Nei .COM la pagina 2 e' la RAM del mapper (si accede direttamente e si
; ripristina il segmento di prima); nelle cartucce la pagina 2 e' la ROM e si usano RDSLT/WRSLT sullo slot RAM.
; Gli indirizzi di memoria dei blocchi non devono cadere in 8000h-BFFFh.
; =====================================================================
MAPFE   equ 0FEh
RAMAD2  equ 0F343h
RDSLTB  equ 000Ch
WRSLTB  equ 0014h
MPROBE  equ 9000h               ; byte di prova (offset 1000h del segmento)

mp_rd:                          ; HL = indirizzo (pagina 2) -> A
        IFDEF ROMMODE
        push bc
        push de
        push hl
        ld a,(RAMSL)
        call RDSLTB
        pop hl
        pop de
        pop bc
        ELSE
        ld a,(hl)
        ENDIF
        ret

mp_wr:                          ; HL = indirizzo (pagina 2), A = valore
        IFDEF ROMMODE
        push bc
        push de
        push hl
        ld e,a
        ld a,(RAMSL)
        call WRSLTB
        pop hl
        pop de
        pop bc
        ELSE
        ld (hl),a
        ENDIF
        ret

mp_sel:                         ; A = segmento: si ricorda quello attuale
        push af
        in a,(MAPFE)
        ld (MSAVE),a
        pop af
        out (MAPFE),a
        ret

mp_rest:
        ld a,(MSAVE)
        out (MAPFE),a
        ret

mp_probe:                       ; B = n: NZ se il segmento n e' lo stesso di 0 (alias: il mapper non arriva a n)
        ld a,b
        ld (MTB),a
        xor a
        out (MAPFE),a
        ld hl,MPROBE
        call mp_rd
        ld (MT0),a
        ld a,(MTB)
        out (MAPFE),a
        ld hl,MPROBE
        call mp_rd
        ld (MTN),a
        cpl
        ld hl,MPROBE
        call mp_wr
        xor a
        out (MAPFE),a
        ld hl,MPROBE
        call mp_rd
        ld hl,MT0
        cp (hl)
        push af
        ld a,(MTB)
        out (MAPFE),a
        ld a,(MTN)
        ld hl,MPROBE
        call mp_wr
        pop af
        ret

mp_detect:                      ; -> HL = numero di segmenti (0 = niente mapper)
        ld a,(MAPK)
        or a
        jr z,.do
        ld hl,(MAPN)
        ret
.do:    di
        in a,(MAPFE)
        ld (MSAVE),a
        ld b,1
.l:     push bc
        call mp_probe
        pop bc
        jr nz,.al
        sla b
        jp m,.big
        jr .l
.al:    ld l,b
        ld h,0
        jr .r
.big:   ld hl,256               ; nessun alias fino a 128: 256 segmenti
.r:     ld a,l
        cp 4
        jr nc,.ok
        ld a,h
        or a
        jr nz,.ok
        ld hl,0                 ; meno di 4 segmenti: niente mapper
.ok:    ld (MAPN),hl
        ld a,1
        ld (MAPK),a
        call mp_rest
        ei
        ret

rt_mapsegs:
        jp mp_detect

rt_mget:                        ; MGET(GX1 = segmento, HL = offset) -> HL = byte
        push hl
        call mp_chk
        pop hl
        ld a,h
        and 0C0h
        jp nz,rt_eifc
        ld de,8000h
        add hl,de
        di
        ld a,(GX1)
        call mp_sel
        call mp_rd
        push af
        call mp_rest
        pop af
        ei
        ld l,a
        ld h,0
        ret

rt_mput:                        ; MPUT GX1 = segmento, GY1 = offset, GX2 = valore
        call mp_chk
        ld hl,(GY1)
        ld a,h
        and 0C0h
        jp nz,rt_eifc
        ld de,8000h
        add hl,de
        di
        ld a,(GX1)
        push hl
        call mp_sel
        pop hl
        ld a,(GX2)
        call mp_wr
        call mp_rest
        ei
        ret

mp_chk:                         ; il segmento GX1 deve esistere
        call mp_detect
        ld a,h
        or l
        jp z,rt_eifc
        ld de,(GX1)
        ld a,d
        or a
        jp nz,rt_eifc
        ld a,h
        or a
        ret nz                  ; 256 segmenti: qualsiasi valore a 8 bit
        ld a,e
        cp l
        ret c
        jp rt_eifc

mp_range:                       ; GY1 = offset, GY2 = quanti, GX2 = indirizzo: controlli comuni -> HL = 8000h + offset, DE = indirizzo, BC = quanti
        call mp_chk
        ld hl,(GY1)
        ld bc,(GY2)
        ld a,h
        and 0C0h
        jp nz,rt_eifc
        push hl
        add hl,bc
        ld a,h
        cp 41h                  ; offset + quanti <= 4000h
        jp nc,rt_eifc
        cp 40h
        jr c,.ok
        ld a,l
        or a
        jp nz,rt_eifc
.ok:    pop hl
        ld de,8000h
        add hl,de
        ld de,(GX2)
        ld a,d                  ; la memoria non puo' stare in 8000h-BFFFh
        and 0C0h
        cp 80h
        jp z,rt_eifc
        push hl
        ld hl,(GX2)
        add hl,bc
        dec hl
        ld a,h
        and 0C0h
        cp 80h
        jp z,rt_eifc
        pop hl
        ret

rt_mread:                       ; MREAD segmento, offset, indirizzo, quanti: mapper -> memoria
        call mp_range
        ld a,b
        or c
        ret z
        di
        ld a,(GX1)
        push hl
        push de
        push bc
        call mp_sel
        pop bc
        pop de
        pop hl
        IFDEF ROMMODE
.l:     call mp_rd
        ld (de),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.l
        ELSE
        ldir
        ENDIF
        call mp_rest
        ei
        ret

rt_mwrite:                      ; MWRITE segmento, offset, indirizzo, quanti: memoria -> mapper
        call mp_range
        ld a,b
        or c
        ret z
        di
        ld a,(GX1)
        push hl
        push de
        push bc
        call mp_sel
        pop bc
        pop de
        pop hl
        IFDEF ROMMODE
.w:     ld a,(de)
        call mp_wr
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.w
        ELSE
        ex de,hl                ; HL = memoria, DE = mapper
        ldir
        ENDIF
        call mp_rest
        ei
        ret

; --- allocazione dei segmenti: con MSX-DOS 2 si usano le routine di supporto del mapper (EXTBIO), altrimenti
; si prendono i segmenti dall'alto verso il basso (DOS 1 e cartucce non li usano)
EXTBIO  equ 0FFCAh

mp_jt:                          ; -> HL = tabella delle routine del mapper (0 = nessun supporto)
        IFDEF ROMMODE
        ld hl,0
        ret
        ELSE
        ld hl,0
        ld de,0402h
        call EXTBIO
        ret
        ENDIF

rt_malloc:                      ; MALLOC -> HL = numero di un segmento libero
        call mp_detect
        ld a,h
        or l
        jp z,rt_eifc
        push hl
        call mp_jt
        ld a,h
        or l
        jr z,.fb
        pop de
        ld (MJT),hl
        xor a
        ld b,a
        ld hl,(MJT)             ; ALL_SEG: A = 0 (segmento utente), B = 0 (mapper primario) -> A = segmento
        di
        call .call
        ei
        jp c,rt_eifc
        ld l,a
        ld h,0
        ret
.call:  jp (hl)
.fb:    pop hl                  ; senza supporto: dall'alto
        ld a,(MALN)
        inc a
        ld b,a
        ld a,l
        sub b
        jp c,rt_eifc
        cp 4
        jp c,rt_eifc            ; i primi segmenti sono del sistema
        ld c,a
        ld a,b
        ld (MALN),a
        ld l,c
        ld h,0
        ret

rt_mfree:                       ; MFREE HL = segmento
        call mp_jt
        ld a,h
        or l
        jr z,.fb
        ld (MJT),hl
        ld de,(GX1)
        ld a,e
        ld b,0
        ld hl,(MJT)
        inc hl
        inc hl
        inc hl                  ; FRE_SEG
        di
        call .call
        ei
        ret
.call:  jp (hl)
.fb:    ld a,(MALN)
        or a
        ret z
        dec a
        ld (MALN),a
        ret
