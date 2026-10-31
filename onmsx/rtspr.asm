; =====================================================================
; Sprite (SCREEN 5-8: modo sprite 2 del V9938: 32 sprite, colore per riga, 8x8 o 16x16)
; Indirizzi delle tabelle dai registri salvati dal BIOS (R#5, R#6, R#11), solo indirizzi a 16 bit.
; =====================================================================
RG1SAV  equ 0F3E0h
RG5SAV  equ 0F3E4h
RG6SAV  equ 0F3E5h
RG11SAV equ 0FFEAh

spr_attr:                       ; -> HL = tabella degli attributi (negli schermi 5-8 la tabella dei colori sta 200h prima)
        ld a,(SCRREAL)
        cp 4
        jr nc,.reg
        cp 2
        ld hl,(GRPATR)
        ret z
        cp 3
        ld hl,(MLTATR)
        ret z
        ld hl,(T32ATR)
        ret
.reg:   ld a,(RG5SAV)
        and 0FCh
        ld h,a
        ld l,0
        srl h                   ; (R#5 & FCh) << 7
        rr l
        ld a,(RG11SAV)
        rrca
        and 80h
        or h
        ld h,a
        ret

spr_gen:                        ; -> DE = generatore dei pattern
        ld a,(SCRREAL)
        cp 4
        jr nc,.reg
        cp 2
        ld de,(GRPPAT)
        ret z
        cp 3
        ld de,(MLTPAT)
        ret z
        ld de,(T32PAT)
        ret
.reg:   ld a,(RG6SAV)           ; (R#6 & 1Fh) << 11
        and 1Fh
        ld d,a
        ld e,0
        sla d
        sla d
        sla d
        ret

spr_big:                        ; Z se i sprite sono 8x8, NZ se 16x16
        ld a,(RG1SAV)
        and 2
        ret

rt_sprsize:                     ; HL = 0..3: bit 1 = 16x16, bit 0 = ingrandimento (registro R#1)
        call chk_spr
        ld a,l
        and 3
        ld b,a
        ld a,(RG1SAV)
        and 0FCh
        or b
        ld (RG1SAV),a
        di
        out (VDPC),a
        ld a,81h
        out (VDPC),a
        ei
        ret

rt_sprdef:                      ; HL = stringa del pattern (8 o 32 byte), GX1 = numero del pattern
        push hl
        call chk_spr
        ld b,3                  ; 8x8: n * 8
        ld c,8
        call spr_big
        jr z,.sz
        ld b,5                  ; 16x16: n * 32
        ld c,32
.sz:    ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,c
        cp 32
        jr nz,.n8
        ld a,l
        cp 64
        jp nc,rt_eifc
.n8:    add hl,hl
        djnz .n8
        push hl
        call spr_gen
        pop hl
        add hl,de
        push bc
        ld a,40h
        call vram_set
        pop bc
        pop de                  ; stringa
        ld a,(de)               ; lunghezza
        inc de
        cp c
        jr c,.cp
        ld a,c
.cp:    ld b,a                  ; byte da copiare
        ld a,c
        sub b
        ld c,a                  ; byte di riempimento
        ld a,b
        or a
        jr z,.pad
.o:     ld a,(de)
        out (VDPD),a
        inc de
        djnz .o
.pad:   ld a,c
        or a
        ret z
        ld b,c
        xor a
.z:     out (VDPD),a
        djnz .z
        ret

rt_sprput:                      ; GX1 = piano (0-31), GX2 = x, GY2 = y, GCOL = colore (< 0: FORCLR), GY1 = pattern (< 0: = piano)
        call chk_spr
        ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 32
        jp nc,rt_eifc
        ld (S1),a               ; piano
        ld hl,(GY1)
        bit 7,h
        jr z,.p
        ld hl,(GX1)
.p:     ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        call spr_big
        ld a,l
        jr z,.pn
        cp 64
        jp nc,rt_eifc
        add a,a
        add a,a                 ; 16x16: numero di pattern * 4
.pn:    ld (S2),a
        call gcolor
        and 0Fh
        ld (S3),a
        ld c,0                  ; C = bit EC (sprite parzialmente a sinistra)
        ld hl,(GX2)
        bit 7,h
        jr z,.xp
        ld de,32
        add hl,de
        bit 7,h
        jr nz,.hide
        ld c,80h
.xp:    ld a,h
        or a
        jr nz,.hide
        ld a,l
        ld (S4),a
        ld hl,(GY2)
        dec hl
        ld a,l
        jr .go
.hide:  xor a
        ld (S4),a
        ld a,217                ; fuori dallo schermo
.go:    ld (S5),a               ; Y - 1
        ld a,c
        ld (S6),a
        call spr_attr
        push hl
        ld a,(S1)
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        add hl,de               ; + piano * 4
        ld a,40h
        call vram_set
        ld a,(S5)
        out (VDPD),a
        ld a,(S4)
        out (VDPD),a
        ld a,(S2)
        out (VDPD),a
        ld a,(SCRREAL)
        cp 4
        jr nc,.m2
        ld a,(S3)               ; modo sprite 1: il colore (con EC) e' nell'attributo
        ld hl,S6
        or (hl)
        out (VDPD),a
        pop hl
        ret
.m2:    xor a
        out (VDPD),a
        pop hl                  ; tabella dei colori: attributi - 200h + piano * 16
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
        ld a,(S3)
        ld hl,S6
        or (hl)
        ld b,16
.col:   out (VDPD),a
        djnz .col
        ret
