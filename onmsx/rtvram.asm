; =====================================================================
; Direct access to VRAM and the VDP, joystick, sprite colors
; VPOKE/VPEEK/VFILL/VWRITE/VREAD$ (VBANK selects the low or high 64 KB of the 128 KB VRAM),
; BASE(n), VDP(n), STICK, STRIG, COLOR SPRITE
; =====================================================================
GTSTCK  equ 00D5h
GTTRIG  equ 00D8h
RG0SAV  equ 0F3DFh
RG8SAV  equ 0FFE7h

ubank_on:                       ; user commands use the bank selected with VBANK
        ld a,(UBANK)
        ld (VA16),a
        ret
ubank_off:                      ; back to the active page (A16 for graphics commands)
        ld a,(APHI)
        ld (VA16),a
        ret

rt_vbank:                       ; HL = 0 (primi 64 KB) o 1 (secondi 64 KB)
        ld a,l
        and 1
        ld (UBANK),a
        ret

rt_vpoke:                       ; DE = address, HL = value
        call ubank_on
        ld a,l
        push af
        ex de,hl
        ld a,40h
        call vram_set
        pop af
        out (VDPD),a
        jr ubank_off

rt_vpeek:                       ; HL = address -> HL = byte
        call ubank_on
        xor a
        call vram_set
        in a,(VDPD)
        ld l,a
        ld h,0
        jr ubank_off

rt_vfill:                       ; VFILL GX1 = address, GY1 = byte count, GX2 = value
        call ubank_on
        ld hl,(GX1)
        ld a,40h
        call vram_set
        ld bc,(GY1)
        ld a,(GX2)
        ld d,a
.l:     ld a,b
        or c
        jr z,ubank_off
        ld a,d
        out (VDPD),a
        dec bc
        jr .l

rt_vwrite:                      ; VWRITE GX1 = address, HL = string
        push hl
        call ubank_on
        ld hl,(GX1)
        ld a,40h
        call vram_set
        pop hl
        ld a,(hl)
        or a
        jr z,ubank_off
        ld b,a
        inc hl
        ld c,VDPD
        otir
        jr ubank_off

rt_vread:                       ; VREAD$(GX1 = address, HL = byte count 0-255) -> temporary string
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        or a
        jr nz,.n
        ld hl,rt_empty
        ret
.n:     call rt_alloc           ; A = length -> HL = string
        push hl
        call ubank_on
        ld hl,(GX1)
        xor a
        call vram_set
        pop hl
        push hl
        ld b,(hl)
        inc hl
        ld c,VDPD
        inir
        call ubank_off
        pop hl
        ret

rt_base:                        ; BASE(n) 0-44: address of the VDP tables for screen n/5, table n mod 5
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 45
        jp nc,rt_eifc
        cp 20
        jr nc,.m2
        add a,a                 ; screens 0-3: BIOS variables (TXTNAM etc.), 5 words per screen
        ld l,a
        ld h,0
        ld de,0F3B3h
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret
.m2:    sub 20                  ; screens 4-8: BASIC defaults
        ld l,a
        ld h,0
        add hl,hl
        ld de,basetab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

basetab: dw 1800h,2000h,0000h,1E00h,3800h      ; screen 4: names, colors, patterns, sprite attributes, sprite patterns
        dw 0000h,0000h,0000h,7600h,7800h       ; screen 5
        dw 0000h,0000h,0000h,7600h,7800h       ; screen 6
        dw 0000h,0000h,0000h,0FA00h,0F000h     ; screen 7
        dw 0000h,0000h,0000h,0FA00h,0F000h     ; screen 8

vdp_status:                     ; A = status register number -> A = value (reads and restores S#0)
        di
        out (VDPC),a
        ld a,8Fh
        out (VDPC),a
        in a,(VDPC)
        push af
        xor a
        out (VDPC),a
        ld a,8Fh
        out (VDPC),a
        pop af
        ei
        ret

rt_vdp:                         ; VDP(n): 0-7 = R#0-7, 8 = S#0, 9-24 = R#8-23 (values saved by the BIOS), -1..-9 = S#1-9
        bit 7,h
        jr z,.pos
        ld a,l                  ; negativo: -k = S#k
        neg
        cp 10
        jp nc,rt_eifc
        call vdp_status
        ld l,a
        ld h,0
        ret
.pos:   ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 8
        jr c,.r07
        jr z,.s0
        cp 25
        jp nc,rt_eifc
        sub 9                   ; 9-24 -> R#8-23
        ld l,a
        ld h,0
        ld de,RG8SAV
        add hl,de
        ld l,(hl)
        ld h,0
        ret
.r07:   ld l,a
        ld h,0
        ld de,RG0SAV
        add hl,de
        ld l,(hl)
        ld h,0
        ret
.s0:    xor a
        call vdp_status
        ld l,a
        ld h,0
        ret

rt_vdpset:                      ; VDP(n) = v: GX1 = n (0-7, 9-24), GY1 = v
        ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 8
        jp z,rt_eifc
        cp 25
        jp nc,rt_eifc
        cp 9
        jr c,.lo
        dec a                   ; 9-24 -> R#8-23
.lo:    ld c,a                  ; C = register
        ld hl,RG0SAV
        cp 8
        jr c,.sv
        ld hl,RG8SAV-8
.sv:    ld e,c
        ld d,0
        add hl,de
        ld a,(GY1)
        ld (hl),a               ; BIOS copy
        di
        out (VDPC),a
        ld a,c
        or 80h
        out (VDPC),a
        ei
        ret

rt_stick:                       ; STICK(n): 0 = cursori, 1-2 = joystick -> 0..8
        ld a,l
        push ix
        ld ix,GTSTCK
        call rt_bios
        pop ix
        ld l,a
        ld h,0
        ret

rt_strig:                       ; STRIG(n): 0 = space, 1-4 = buttons -> -1 if pressed
        ld a,l
        push ix
        ld ix,GTTRIG
        call rt_bios
        pop ix
        ld l,a
        ld h,a
        ret

; ---------------------------------------------------------------- sprite colors
rt_sprcol:                      ; COLOR SPRITE(n) = c: GX1 = plane, GCOL = color (all lines)
        call chk_spr
        ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 32
        jp nc,rt_eifc
        ld (S1),a
        ld a,(GCOL)
        and 0Fh
        ld (S2),a
        call spr_attr
        ld a,(SCRREAL)
        cp 4
        jr nc,.m2
        ld a,(S1)               ; sprite mode 1: the color is the 4th byte of the attribute (EC is preserved)
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        add hl,de
        inc hl
        inc hl
        inc hl
        push hl
        xor a
        call vram_set
        in a,(VDPD)
        and 80h
        ld hl,S2
        or (hl)
        ld b,a
        pop hl
        ld a,40h
        call vram_set
        ld a,b
        out (VDPD),a
        ret
.m2:    ld de,-200h             ; sprite mode 2: 16 lines in the color table
        add hl,de
        ld a,(S1)
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        add hl,de
        ld a,40h
        call vram_set
        ld a,(S2)
        ld b,16
.c:     out (VDPD),a
        djnz .c
        ret

rt_sprcols:                     ; COLOR SPRITE$(n) = string: GX1 = plane, HL = string (up to 16 colors, one per line)
        push hl
        call chk_spr
        ld a,(SCRREAL)
        cp 4
        jp c,rt_eifc            ; sprite mode 2 only (screens 4-8)
        ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 32
        jp nc,rt_eifc
        ld (S1),a
        call spr_attr
        ld de,-200h
        add hl,de
        ld a,(S1)
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        add hl,de
        ld a,40h
        call vram_set
        pop hl
        ld a,(hl)
        or a
        ret z
        cp 17
        jr c,.l
        ld a,16
.l:     ld b,a
        inc hl
        ld c,VDPD
        otir
        ret

; ---------------------------------------------------------------- pages, COPY, scrolling
pgy:                            ; HL = pagina (< 0 = attiva) -> HL = pagina * 256
        bit 7,h
        jr z,.p
        ld a,(APAGE)
        ld l,a
.p:     ld h,l
        ld l,0
        ret

rt_setpage:                     ; SET PAGE GX1 = pagina visibile, GY1 = pagina attiva (schermi 5-8)
        ld a,(SCRMODE)
        cp 5
        jp c,rt_egfx
        ld c,4                  ; pagine: 4 (schermi 5-6), 2 (schermi 7-8)
        cp 7
        jr c,.n
        ld c,2
.n:     ld hl,(GX1)
        ld de,(GY1)
        ld a,h
        or d
        jp nz,rt_eifc
        ld a,l
        cp c
        jp nc,rt_eifc
        ld a,e
        cp c
        jp nc,rt_eifc
        ld a,l                  ; R#2 = pagina << 5 (schermi 5-6) o << 6 (7-8), | 1Fh
        rrca
        rrca
        ld b,a
        ld a,(SCRMODE)
        cp 7
        ld a,b
        jr nc,.r2
        rrca
.r2:    or 1Fh
        ld (0F3E1h),a
        di
        out (VDPC),a
        ld a,82h
        out (VDPC),a
        ei
        ld a,e
        ld (APAGE),a
        ld h,a                  ; APY = pagina * 256
        ld l,0
        ld (APY),hl
        ld a,(SCRMODE)
        cp 7
        ld a,e
        jr nc,.hi
        and 1                   ; screens 5-6: 32 KB per page
        rrca
        ld h,a
        ld l,0
        ld (APLO),hl
        ld a,e
        srl a
        jr .set
.hi:    ld hl,0                 ; screens 7-8: 64 KB per page
        ld (APLO),hl
.set:   ld (APHI),a
        ld (VA16),a
        ret

rt_copy:                        ; COPY (GX1,GY1)-(GX2,GY2),CSP TO (CDX,CDY),CDP with operator GOP
        ld a,(SCRMODE)
        cp 5
        jp c,rt_egfx
        ld hl,GX1
        ld de,GX2
        call sortp
        ld hl,GY1
        ld de,GY2
        call sortp
        ld hl,(GX2)
        ld de,(GX1)
        or a
        sbc hl,de
        inc hl
        ld (GCMD+4),hl
        ld hl,(GY2)
        ld de,(GY1)
        or a
        sbc hl,de
        inc hl
        ld (GCMD+6),hl
        ld hl,(CSP)
        call pgy
        ld de,(GY1)
        add hl,de
        ld (S2),hl              ; SY assoluto
        ld hl,(CDP)
        call pgy
        ld de,(CDY)
        add hl,de
        ld (S4),hl              ; DY assoluto
        ld de,(APY)
        or a
        sbc hl,de
        ld (GCMD+2),hl          ; relative DY (vdp_cmd adds the active page back)
        ld hl,(GX1)
        ld (S1),hl
        ld hl,(CDX)
        ld (GCMD),hl
        xor a
        ld (GCMD+8),a
        ld (GCMD+9),a
        ld hl,(S4)
        ld de,(S2)
        or a
        sbc hl,de
        jr z,.same
        jr c,.go                ; destination higher up: from the top
        ld a,8                  ; lower down: from the bottom (DIY)
        ld (GCMD+9),a
        ld hl,(GCMD+6)
        dec hl
        ld de,(S2)
        add hl,de
        ld (S2),hl
        ld hl,(GCMD+6)
        dec hl
        ld de,(GCMD+2)
        add hl,de
        ld (GCMD+2),hl
        jr .go
.same:  ld hl,(CDX)             ; same lines: if the destination is to the right, copy from the right (DIX)
        ld de,(S1)
        or a
        sbc hl,de
        jr z,.go
        jr c,.go
        ld a,4
        ld (GCMD+9),a
        ld hl,(GCMD+4)
        dec hl
        ld de,(S1)
        add hl,de
        ld (S1),hl
        ld hl,(GCMD+4)
        dec hl
        ld de,(GCMD)
        add hl,de
        ld (GCMD),hl
.go:    call vdp_wait
        ld hl,(S1)
        ld de,(S2)
        call vdp_setsrc_raw
        ld a,90h                ; LMMM
        ld (GCMD+10),a
        jp vdp_cmd

rt_scroll:                      ; SET SCROLL GX1 = x, GY1 = y: R#23 (verticale), R#26/R#27 (orizzontale, V9958)
        ld hl,(GX1)
        ld a,(GY1)
        ld (RG8SAV+15),a        ; BIOS copy of R#23 (the debugger restores it)
        di
        out (VDPC),a
        ld a,80h+23
        out (VDPC),a
        ld a,l
        and 7
        neg
        and 7                   ; R#27 = (8 - x mod 8) mod 8
        ld b,a
        ld de,7
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        and 3Fh                 ; R#26 = (x + 7) / 8
        out (VDPC),a
        ld a,80h+26
        out (VDPC),a
        ld a,b
        out (VDPC),a
        ld a,80h+27
        out (VDPC),a
        ei
        ret

; ---------------------------------------------------------------- DATA / READ / RESTORE
; Blocks in the code: jp past, then elements (0,word = integer | 1,len,text = string), 2, word = next block (0 = last)
rt_read:                        ; A = 0 integer / 1 string -> HL = value (or pointer to the string)
        ld c,a
        ld hl,(DPTR)
.f:     ld a,h
        or l
        jr z,.eod
        ld a,(hl)
        cp 2
        jr nz,.it
        inc hl                  ; end of block: follow the link
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jr .f
.it:    cp c
        jr nz,.tm
        inc hl
        or a
        jr nz,.s
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (DPTR),hl
        ex de,hl
        ret
.s:     push hl
        ld a,(hl)
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld (DPTR),hl
        pop hl
        ret
.eod:   ld hl,msg_eod
        jp rt_fatal
.tm:    ld hl,msg_tmm
        jp rt_fatal

rt_restore:                     ; HL = 0: from the start; otherwise address of a label placed right before a DATA
        ld a,h
        or l
        jr nz,.l
        ld hl,(rt_data0)
        ld (DPTR),hl
        ret
.l:     ld a,(hl)
        cp 0C3h
        jp nz,rt_eifc
        inc hl
        inc hl
        inc hl
        ld (DPTR),hl
        ret

rt_vcopy:                       ; VCOPY GX1 = memory address, GY1 = VRAM address, GX2 = byte count
        call ubank_on
        ld hl,(GY1)
        ld a,40h
        call vram_set
        ld hl,(GX1)
        ld bc,(GX2)
.l:     ld a,b
        or c
        jp z,ubank_off
        ld a,(hl)
        out (VDPD),a
        inc hl
        dec bc
        jr .l
