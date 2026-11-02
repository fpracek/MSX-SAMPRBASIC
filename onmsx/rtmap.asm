; =====================================================================
; Mapper RAM (MSX2): 16 KB segments seen through page 2 (8000h-BFFF, port FEh).
; MAPPERSEGS, MGET, MPUT, MREAD, MWRITE. In .COM files page 2 is the mapper RAM (accessed directly and it is
; restores the previous segment); in cartridges page 2 is the ROM and RDSLT/WRSLT are used on the RAM slot.
; The memory addresses of the blocks must not fall in 8000h-BFFFh.
; =====================================================================
MAPFE   equ 0FEh
RAMAD2  equ 0F343h
RDSLTB  equ 000Ch
WRSLTB  equ 0014h
MPROBE  equ 9000h               ; test byte (offset 1000h of the segment)

mp_rd:                          ; HL = address (page 2) -> A
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

mp_wr:                          ; HL = address (page 2), A = value
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

mp_sel:                         ; A = segment: remembers the current one
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

mp_probe:                       ; B = n: NZ if segment n is the same as 0 (alias: the mapper does not reach n)
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

mp_detect:                      ; -> HL = number of segments (0 = no mapper)
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
.big:   ld hl,256               ; no aliasing up to 128: 256 segments
.r:     ld a,l
        cp 4
        jr nc,.ok
        ld a,h
        or a
        jr nz,.ok
        ld hl,0                 ; fewer than 4 segments: no mapper
.ok:    ld (MAPN),hl
        ld a,1
        ld (MAPK),a
        call mp_rest
        ei
        ret

rt_mapsegs:
        jp mp_detect

rt_mget:                        ; MGET(GX1 = segment, HL = offset) -> HL = byte
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

rt_mput:                        ; MPUT GX1 = segment, GY1 = offset, GX2 = value
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

mp_chk:                         ; segment GX1 must exist
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
        ret nz                  ; 256 segments: any 8-bit value
        ld a,e
        cp l
        ret c
        jp rt_eifc

mp_range:                       ; GY1 = offset, GY2 = count, GX2 = address: common checks -> HL = 8000h + offset, DE = address, BC = count
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
        ld a,d                  ; the memory cannot lie in 8000h-BFFFh
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

rt_mread:                       ; MREAD segment, offset, address, count: mapper -> memory
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

rt_mwrite:                      ; MWRITE segment, offset, address, count: memory -> mapper
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
        ex de,hl                ; HL = memory, DE = mapper
        ldir
        ENDIF
        call mp_rest
        ei
        ret

; --- segment allocation: with MSX-DOS 2 the mapper support routines (EXTBIO) are used, otherwise
; segments are taken from the top down (DOS 1 and cartridges do not use them)
EXTBIO  equ 0FFCAh

mp_jt:                          ; -> HL = mapper routine table (0 = no support)
        IFDEF ROMMODE
        ld hl,0
        ret
        ELSE
        ld hl,0
        ld de,0402h
        call EXTBIO
        ret
        ENDIF

rt_malloc:                      ; MALLOC -> HL = number of a free segment
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
        ld hl,(MJT)             ; ALL_SEG: A = 0 (user segment), B = 0 (primary mapper) -> A = segment
        di
        call .call
        ei
        jp c,rt_eifc
        ld l,a
        ld h,0
        ret
.call:  jp (hl)
.fb:    pop hl                  ; without support: from the top
        ld a,(MALN)
        inc a
        ld b,a
        ld a,l
        sub b
        jp c,rt_eifc
        cp 4
        jp c,rt_eifc            ; the first segments belong to the system
        ld c,a
        ld a,b
        ld (MALN),a
        ld l,c
        ld h,0
        ret

rt_mfree:                       ; MFREE HL = segment
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

; --- integer arrays in the mapper: descriptor = number of elements (word) + up to 4 segments (bytes)
mp_zero:                        ; A = segment: clears it
        di
        call mp_sel
        IFDEF ROMMODE
        ld hl,8000h
        ld bc,16384
.z:     xor a
        call mp_wr
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.z
        ELSE
        ld hl,8000h
        ld de,8001h
        ld bc,16383
        ld (hl),0
        ldir
        ENDIF
        call mp_rest
        ei
        ret

rt_mdim:                        ; HL = descriptor, DE = number of elements
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        ex de,hl
        ld de,8191
        add hl,de
        ld a,h
        rlca
        rlca
        rlca
        and 7
        jp z,rt_eifc
        cp 5
        jp nc,rt_eifc
        ld b,a
.l:     push bc
        call rt_malloc
        ld a,l
        pop bc
        pop hl
        ld (hl),a
        inc hl
        push hl
        push bc
        call mp_zero
        pop bc
        djnz .l
        pop hl
        ret

mp_elem:                        ; HL = index, DE = descriptor -> HL = address in page 2, A = segment
        ex de,hl                ; HL = descrittore, DE = indice
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl                  ; BC = number of elements, HL = &segments
        push hl
        ld h,d
        ld l,e
        or a
        sbc hl,bc
        pop hl
        jp nc,rt_esub
        ld a,d
        rlca
        rlca
        rlca
        and 3                   ; indice / 8192
        ld c,a
        ld b,0
        add hl,bc
        ld a,(hl)
        ld (MTB),a
        ld a,d
        and 1Fh
        ld h,a
        ld l,e
        add hl,hl
        ld de,8000h
        add hl,de
        ld a,(MTB)
        ret

rt_maget:                       ; HL = index, DE = descriptor -> HL = value
        call mp_elem
        di
        push hl
        call mp_sel
        pop hl
        call mp_rd
        push af
        inc hl
        call mp_rd
        ld d,a
        pop af
        ld e,a
        push de
        call mp_rest
        pop hl
        ei
        ret

rt_maput:                       ; HL = value, DE = index, BC = descriptor
        push hl
        ld h,b
        ld l,c
        ex de,hl
        call mp_elem
        pop de
        di
        push hl
        push de
        call mp_sel
        pop de
        pop hl
        ld a,e
        call mp_wr
        inc hl
        ld a,d
        call mp_wr
        call mp_rest
        ei
        ret

rt_mki:                         ; MKI$(HL) -> 2-byte string (little endian)
        push hl
        ld a,2
        call rt_alloc
        pop de
        push hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ret

rt_cvi:                         ; CVI(HL = string of at least 2 bytes) -> integer
        ld a,(hl)
        cp 2
        jp c,rt_eifc
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret
