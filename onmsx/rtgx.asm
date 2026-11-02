; =====================================================================
; GET/PUT of areas, DRAW and COLLISION (SCREEN 5-8)
; GET (x1,y1)-(x2,y2), array   -> array: [width][height] then one byte per pixel (2 pixels per element)
; PUT (x,y), array[, action]   -> action 0 PSET, 1 PRESET, 2 AND, 3 OR, 4 XOR (default)
; =====================================================================
STATFL  equ 0F3E7h
H_TIMI  equ 0FD9Fh

ensure_rowbuf:                  ; pixel line at the top of the heap
        ld hl,(heapend)
        ld de,-256
        add hl,de
        ld (ROWPTR),hl
        ret

rowaddr:                        ; HL = y -> HL = VRAM address of the line, B = bytes per line (0 = 256)
        call gstride
        or a
        ld a,l
        ld h,a                  ; y * 256
        ld l,0
        ld b,0
        jr z,.ap
        srl h                   ; y * 128
        rr l
        ld b,128
.ap:    ld de,(APLO)            ; pagina attiva
        add hl,de
        ret

rowwrite:                       ; HL = y: writes ROWBUF to line y
        call rowaddr
        push bc
        ld a,40h
        call vram_set
        pop bc
        ld hl,(ROWPTR)
        ld c,VDPD
        otir
        ret

rb_setpix:                      ; HL = x, A = value: sets the pixel in the line in ROWBUF
        ld b,a
        ld a,(GBPP)
        cp 8
        jr z,.m8
        cp 2
        jr z,.m2
        ld a,l                  ; 4 bits per pixel
        and 1
        ld c,a
        srl h
        rr l
        ld de,(ROWPTR)
        add hl,de
        ld a,(hl)
        bit 0,c
        jr nz,.lo
        and 0Fh
        ld e,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        or e
        ld (hl),a
        ret
.lo:    and 0F0h
        ld e,a
        ld a,b
        and 0Fh
        or e
        ld (hl),a
        ret
.m2:    ld a,l
        and 3
        ld c,a
        srl h
        rr l
        srl h
        rr l
        ld de,(ROWPTR)
        add hl,de
        ld a,3
        sub c
        add a,a
        ld d,a                  ; D = pixel position (bit)
        ld e,3                  ; E = maschera
        ld a,b
        and 3
        ld b,a
        inc d
.s2:    dec d
        jr z,.d2
        sla e
        sla b
        jr .s2
.d2:    ld a,e
        cpl
        ld c,a
        ld a,(hl)
        and c
        or b
        ld (hl),a
        ret
.m8:    ld de,(ROWPTR)
        add hl,de
        ld (hl),b
        ret

grect:                          ; GX1,GY1,GX2,GY2 -> S1..S4 sorted, S5 = width, S6 = height; error if off-screen
        ld hl,(GX1)
        ld (S1),hl
        ld hl,(GY1)
        ld (S2),hl
        ld hl,(GX2)
        ld (S3),hl
        ld hl,(GY2)
        ld (S4),hl
        ld hl,S1
        ld de,S3
        call sortp
        ld hl,S2
        ld de,S4
        call sortp
        ld hl,(S1)
        ld de,(S2)
        call in_range
        jp nc,rt_eifc
        ld hl,(S3)
        ld de,(S4)
        call in_range
        jp nc,rt_eifc
        ld hl,(S3)
        ld de,(S1)
        or a
        sbc hl,de
        inc hl
        ld (S5),hl
        ld hl,(S4)
        ld de,(S2)
        or a
        sbc hl,de
        inc hl
        ld (S6),hl
        ret

elems:                          ; width S5, height S6 -> HL = array elements (2 + (w*h+1)/2)
        ld hl,(S5)
        ld de,(S6)
        call rt_mul
        inc hl
        srl h
        rr l
        inc hl
        inc hl
        ret

rt_gget:                        ; GET: GX1,GY1,GX2,GY2 e array (ARRB, ARRC)
        call chk_gfx_nm
        call grect
        call elems
        ex de,hl
        ld hl,(ARRC)
        or a
        sbc hl,de
        jp c,rt_eifc            ; array troppo piccolo
        ld hl,(ARRB)
        ld de,(S5)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(S6)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (S7),hl              ; pointer to the pixels
        ld a,(SCRMODE)
        cp 2
        jp z,gget2
        call ensure_rowbuf
        ld hl,(S2)
        ld (S8),hl
.row:   ld hl,(S8)
        call rowread
        ld hl,(S1)
        ld (PX),hl
.px:    ld hl,(PX)
        call rb_pix
        ld hl,(S7)
        ld (hl),a
        inc hl
        ld (S7),hl
        ld hl,(PX)
        ld de,(S3)
        or a
        sbc hl,de
        jr z,.nr
        ld hl,(PX)
        inc hl
        ld (PX),hl
        jr .px
.nr:    ld hl,(S8)
        ld de,(S4)
        or a
        sbc hl,de
        ret z
        ld hl,(S8)
        inc hl
        ld (S8),hl
        jr .row

rt_gput:                        ; PUT: (GX1,GY1) = top-left corner, array (ARRB, ARRC), action in GFLG
        call chk_gfx_nm
        ld hl,(ARRB)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (S5),de              ; larghezza
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (S6),de              ; altezza
        ld (S7),hl              ; pointer to the pixels
        ld hl,(S5)
        ld a,h
        or l
        jp z,rt_eifc
        ld hl,(S6)
        ld a,h
        or l
        jp z,rt_eifc
        call elems
        ex de,hl
        ld hl,(ARRC)
        or a
        sbc hl,de
        jp c,rt_eifc            ; the array does not hold a complete image
        ld hl,(GX1)             ; angolo opposto = (x + w - 1, y + h - 1)
        ld de,(S5)
        add hl,de
        dec hl
        ld (S3),hl
        ld hl,(GY1)
        ld de,(S6)
        add hl,de
        dec hl
        ld (S4),hl
        ld hl,(GX1)
        ld de,(GY1)
        call in_range
        jp nc,rt_eifc
        ld hl,(S3)
        ld de,(S4)
        call in_range
        jp nc,rt_eifc
        ld a,(SCRMODE)
        cp 2
        jp z,gput2
        call ensure_rowbuf
        ld hl,(GY1)
        ld (S8),hl
.row:   ld hl,(S8)
        call rowread
        ld hl,(GX1)
        ld (PX),hl
.px:    ld hl,(S7)
        ld b,(hl)               ; B = pixel sorgente
        inc hl
        ld (S7),hl
        ld hl,(PX)
        push hl
        push bc
        call rb_pix             ; A = destination pixel
        pop bc
        ld c,a
        ld a,(GFLG)
        or a
        ld a,b                  ; 0 PSET
        jr z,.res
        ld a,(GFLG)
        cp 1
        jr nz,.n1
        ld a,b                  ; 1 PRESET: complement
        cpl
        jr .res
.n1:    cp 2
        jr nz,.n2
        ld a,b                  ; 2 AND
        and c
        jr .res
.n2:    cp 3
        jr nz,.n3
        ld a,b                  ; 3 OR
        or c
        jr .res
.n3:    ld a,b                  ; 4 XOR
        xor c
.res:   ld b,a
        ld a,(GONES)
        and b
        pop hl
        call rb_setpix
        ld hl,(PX)
        ld de,(S3)
        or a
        sbc hl,de
        jr z,.nr
        ld hl,(PX)
        inc hl
        ld (PX),hl
        jr .px
.nr:    ld hl,(S8)
        call rowwrite
        ld hl,(S8)
        ld de,(S4)
        or a
        sbc hl,de
        ret z
        ld hl,(S8)
        inc hl
        ld (S8),hl
        jp .row

; ---------------------------------------------------------------- DRAW
dget:                           ; -> A = next significant character (uppercase), Z if finished
.l:     ld a,(DLEN)
        or a
        ret z
        ld hl,(DPOS)
        ld a,(hl)
        inc hl
        ld (DPOS),hl
        ld hl,DLEN
        dec (hl)
        cp ' '
        jr z,.l
        cp ';'
        jr z,.l
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 20h
.u:     or a
        ret

dpeek:                          ; -> A = next character without consuming it (0 if finished)
        ld a,(DLEN)
        or a
        ret z
        ld hl,(DPOS)
        ld a,(hl)
        ret

dget_raw:                       ; consumes a character
        ld hl,(DPOS)
        inc hl
        ld (DPOS),hl
        ld hl,DLEN
        dec (hl)
        ret

dnum:                           ; decimal number with optional sign -> HL = value (1 if missing), A = 1 if there was a sign
        xor a
        ld (S4),a               ; segno presente
        ld (S3),a               ; negativo
        call dpeek
        cp '+'
        jr z,.sg
        cp '-'
        jr nz,.dg
        ld a,1
        ld (S3),a
.sg:    ld a,1
        ld (S4),a
        call dget_raw
.dg:    ld hl,0
        ld c,0                  ; C = cifre lette
.l:     push hl
        call dpeek
        pop hl
        sub '0'
        cp 10
        jr nc,.end
        push af
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        pop af
        ld e,a
        ld d,0
        add hl,de
        inc c
        push hl
        push bc
        call dget_raw
        pop bc
        pop hl
        jr .l
.end:   ld a,c
        or a
        jr nz,.has
        ld hl,1                 ; no digits: value 1
.has:   ld a,(S3)
        or a
        jr z,.pos
        call rt_neghl
.pos:   ld a,(S4)
        ret

dmove:                          ; (S1,S2) = new position: draws or moves (prefixes B and N)
        ld hl,(LASTX)
        ld (S5),hl
        ld hl,(LASTY)
        ld (S6),hl
        ld a,(DB)
        or a
        jr nz,.blank
        ld hl,(LASTX)           ; line from the last point to the new position
        ld (GX1),hl
        ld hl,(LASTY)
        ld (GY1),hl
        ld hl,(S1)
        ld (GX2),hl
        ld hl,(S2)
        ld (GY2),hl
        ld a,(DCOL)
        ld l,a
        ld h,0
        ld (GCOL),hl
        xor a
        ld (GFLG),a
        call rt_gline
        jr .nn
.blank: ld hl,(S1)
        ld (LASTX),hl
        ld hl,(S2)
        ld (LASTY),hl
.nn:    ld a,(DN)
        or a
        jr z,.fin
        ld hl,(S5)
        ld (LASTX),hl
        ld hl,(S6)
        ld (LASTY),hl
.fin:   xor a
        ld (DB),a
        ld (DN),a
        ret

rt_draw:                        ; HL = command string (U D L R E F G H M B N C S)
        push hl
        call chk_gfx
        pop hl
        ld a,(hl)
        ld (DLEN),a
        inc hl
        ld (DPOS),hl
        ld a,4
        ld (DSC),a
        ld a,(FORCLR)
        ld (DCOL),a
        xor a
        ld (DB),a
        ld (DN),a
.next:  call dget
        ret z
        cp 'B'
        jr nz,.nb
        ld a,1
        ld (DB),a
        jr .next
.nb:    cp 'N'
        jr nz,.nn
        ld a,1
        ld (DN),a
        jr .next
.nn:    cp 'C'
        jr nz,.nc
        call dnum
        ld a,l
        ld (DCOL),a
        jr .next
.nc:    cp 'S'
        jr nz,.ns
        call dnum
        ld a,l
        or a
        jr nz,.sk
        ld a,4
.sk:    ld (DSC),a
        jr .next
.ns:    cp 'M'
        jr nz,.nm
        call dnum               ; M x,y: absolute, relative if x has a sign
        push af
        push hl
        call dpeek
        cp ','
        jr nz,.my
        call dget_raw
.my:    call dnum
        ex de,hl                ; DE = y
        pop hl                  ; HL = x
        pop af
        or a
        jr z,.abs
        push de
        ld de,(LASTX)
        add hl,de
        pop de
        push hl
        ld hl,(LASTY)
        add hl,de
        ex de,hl
        pop hl
.abs:   ld (S1),hl
        ld (S2),de
        call dmove
        jp .next
.nm:    ld c,a                  ; U D L R E F G H: direction -> (dx, dy)
        ld hl,dirs
.f:     ld a,(hl)
        or a
        jp z,rt_eifc
        cp c
        jr z,.hit
        inc hl
        inc hl
        inc hl
        jr .f
.hit:   inc hl
        ld b,(hl)               ; dx (-1, 0, 1)
        inc hl
        ld c,(hl)               ; dy
        push bc
        call dnum               ; distanza in unita'
        ld a,(DSC)
        ld e,a
        ld d,0
        call rt_mul             ; * scala
        srl h
        rr l
        srl h
        rr l                    ; / 4
        pop bc
        ld (S7),hl              ; distanza
        ld de,(LASTX)
        ld a,b
        or a
        jr z,.dx
        ld hl,(S7)
        bit 7,a
        jr z,.px1
        call rt_neghl
.px1:   add hl,de
        ex de,hl
.dx:    ld (S1),de              ; nuova x
        ld de,(LASTY)
        ld a,c
        or a
        jr z,.dy
        ld hl,(S7)
        bit 7,a
        jr z,.py1
        call rt_neghl
.py1:   add hl,de
        ex de,hl
.dy:    ld (S2),de
        call dmove
        jp .next

dirs:   db 'U',0,-1,'D',0,1,'L',-1,0,'R',1,0,'E',1,-1,'F',1,1,'G',-1,1,'H',-1,-1,0

; ---------------------------------------------------------------- COLLISION
; The BIOS handles sprite collision as an "ON SPRITE" event: with the event table entry
; (TRPTBL) enabled (bit 0), on collision the BIOS raises bit 2 (pending event).
TRPSPR  equ 0FC6Dh              ; TRPTBL (FC4Ch) + 11 * 3: sprite entry

rt_trpon:                       ; enables the sprite collision event
        ld a,1
        ld (TRPSPR),a
        ret

rt_coll:                        ; COLLISION -> -1 if two sprites touched since the last read
        ld hl,0
        ld a,(TRPSPR)
        bit 2,a
        ret z
        res 2,a
        ld (TRPSPR),a
        dec hl
        ret

; ---------------------------------------------------------------- GET/PUT in SCREEN 2 (point by point)
gget2:
        ld hl,(S2)
        ld (S8),hl
.row:   ld hl,(S1)
        ld (PX),hl
.px:    ld hl,(PX)
        ld de,(S8)
        call getpix2
        ld hl,(S7)
        ld (hl),a
        inc hl
        ld (S7),hl
        ld hl,(PX)
        ld de,(S3)
        or a
        sbc hl,de
        jr z,.nr
        ld hl,(PX)
        inc hl
        ld (PX),hl
        jr .px
.nr:    ld hl,(S8)
        ld de,(S4)
        or a
        sbc hl,de
        ret z
        ld hl,(S8)
        inc hl
        ld (S8),hl
        jr .row

gput2:
        ld hl,(GY1)
        ld (S8),hl
.row:   ld hl,(GX1)
        ld (PX),hl
.px:    ld hl,(S7)
        ld b,(hl)               ; B = pixel sorgente
        inc hl
        ld (S7),hl
        ld hl,(PX)
        ld de,(S8)
        push bc
        call getpix2            ; A = destination pixel
        pop bc
        ld c,a
        ld a,(GFLG)
        or a
        ld a,b                  ; 0 PSET
        jr z,.res
        ld a,(GFLG)
        cp 1
        jr nz,.n1
        ld a,b                  ; 1 PRESET
        cpl
        jr .res
.n1:    cp 2
        jr nz,.n2
        ld a,b                  ; 2 AND
        and c
        jr .res
.n2:    cp 3
        jr nz,.n3
        ld a,b                  ; 3 OR
        or c
        jr .res
.n3:    ld a,b                  ; 4 XOR
        xor c
.res:   and 0Fh
        ld (GCMD+8),a
        ld hl,(PX)
        ld de,(S8)
        call plot2
        ld hl,(PX)
        ld de,(S3)
        or a
        sbc hl,de
        jr z,.nr
        ld hl,(PX)
        inc hl
        ld (PX),hl
        jr .px
.nr:    ld hl,(S8)
        ld de,(S4)
        or a
        sbc hl,de
        ret z
        ld hl,(S8)
        inc hl
        ld (S8),hl
        jp .row
