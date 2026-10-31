; =====================================================================
; Accesso diretto alla VRAM e al VDP, joystick, colori degli sprite
; VPOKE/VPEEK/VFILL/VWRITE/VREAD$ (VBANK sceglie i 64 KB bassi o alti della VRAM da 128 KB),
; BASE(n), VDP(n), STICK, STRIG, COLOR SPRITE
; =====================================================================
GTSTCK  equ 00D5h
GTTRIG  equ 00D8h
RG0SAV  equ 0F3DFh
RG8SAV  equ 0FFE7h

ubank_on:                       ; i comandi utente usano il banco scelto con VBANK
        ld a,(UBANK)
        ld (VA16),a
        ret
ubank_off:
        xor a
        ld (VA16),a
        ret

rt_vbank:                       ; HL = 0 (primi 64 KB) o 1 (secondi 64 KB)
        ld a,l
        and 1
        ld (UBANK),a
        ret

rt_vpoke:                       ; DE = indirizzo, HL = valore
        call ubank_on
        ld a,l
        push af
        ex de,hl
        ld a,40h
        call vram_set
        pop af
        out (VDPD),a
        jr ubank_off

rt_vpeek:                       ; HL = indirizzo -> HL = byte
        call ubank_on
        xor a
        call vram_set
        in a,(VDPD)
        ld l,a
        ld h,0
        jr ubank_off

rt_vfill:                       ; VFILL GX1 = indirizzo, GY1 = quanti byte, GX2 = valore
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

rt_vwrite:                      ; VWRITE GX1 = indirizzo, HL = stringa
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

rt_vread:                       ; VREAD$(GX1 = indirizzo, HL = quanti byte 0-255) -> stringa temporanea
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        or a
        jr nz,.n
        ld hl,rt_empty
        ret
.n:     call rt_alloc           ; A = lunghezza -> HL = stringa
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

rt_base:                        ; BASE(n) 0-44: indirizzo delle tabelle del VDP per lo schermo n/5, tabella n mod 5
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 45
        jp nc,rt_eifc
        cp 20
        jr nc,.m2
        add a,a                 ; schermi 0-3: variabili del BIOS (TXTNAM ecc.), 5 parole per schermo
        ld l,a
        ld h,0
        ld de,0F3B3h
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret
.m2:    sub 20                  ; schermi 4-8: valori predefiniti del BASIC
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

basetab: dw 1800h,2000h,0000h,1E00h,3800h      ; schermo 4: nomi, colori, pattern, attributi sprite, pattern sprite
        dw 0000h,0000h,0000h,7600h,7800h       ; schermo 5
        dw 0000h,0000h,0000h,7600h,7800h       ; schermo 6
        dw 0000h,0000h,0000h,0FA00h,0F000h     ; schermo 7
        dw 0000h,0000h,0000h,0FA00h,0F000h     ; schermo 8

vdp_status:                     ; A = numero del registro di stato -> A = valore (legge e ripristina S#0)
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

rt_vdp:                         ; VDP(n): 0-7 = R#0-7, 8 = S#0, 9-24 = R#8-23 (valori salvati dal BIOS), -1..-9 = S#1-9
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
.lo:    ld c,a                  ; C = registro
        ld hl,RG0SAV
        cp 8
        jr c,.sv
        ld hl,RG8SAV-8
.sv:    ld e,c
        ld d,0
        add hl,de
        ld a,(GY1)
        ld (hl),a               ; copia del BIOS
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

rt_strig:                       ; STRIG(n): 0 = spazio, 1-4 = pulsanti -> -1 se premuto
        ld a,l
        push ix
        ld ix,GTTRIG
        call rt_bios
        pop ix
        ld l,a
        ld h,a
        ret

; ---------------------------------------------------------------- colori degli sprite
rt_sprcol:                      ; COLOR SPRITE(n) = c: GX1 = piano, GCOL = colore (tutte le righe)
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
        ld a,(S1)               ; modo sprite 1: il colore e' il 4o byte dell'attributo (EC si conserva)
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
.m2:    ld de,-200h             ; modo sprite 2: 16 righe nella tabella dei colori
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

rt_sprcols:                     ; COLOR SPRITE$(n) = stringa: GX1 = piano, HL = stringa (fino a 16 colori, uno per riga)
        push hl
        call chk_spr
        ld a,(SCRREAL)
        cp 4
        jp c,rt_eifc            ; solo modo sprite 2 (schermi 4-8)
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
