; =====================================================================
; Runtime for ROM cartridges (ROMMODE): started from the BIOS INIT, mapper, files unavailable (no DOS)
; =====================================================================
rom_init:
        call 0138h              ; RSLREG: page 1 slot (where the cartridge is) -> page 2
        rrca
        rrca
        and 3
        ld c,a
        ld b,0
        ld hl,0FCC1h            ; EXPTBL
        add hl,bc
        ld a,(hl)
        and 80h
        or c
        ld c,a
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)               ; SLTTBL
        and 0Ch
        or c
        ld h,80h
        call 0024h              ; ENASLT
        ld a,(rt_target)
        sub 3
        jr c,.go                ; ROM16 / ROM32: no bank register
        add a,a
        ld e,a
        ld d,0
        ld hl,maptabs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
.mw:    ld e,(hl)               ; pairs (register address, value), 0 = end
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.go
        ld a,(hl)
        inc hl
        ld (de),a
        jr .mw
.go:    ei
        jp rt_start

maptabs: dw map_a8, map_a16, map_kon, map_scc
map_a8:  dw 6000h
         db 0
         dw 6800h
         db 1
         dw 7000h
         db 2
         dw 7800h
         db 3
         dw 0
map_a16: dw 6000h
         db 0
         dw 7000h
         db 1
         dw 0
map_kon: dw 6000h
         db 1
         dw 8000h
         db 2
         dw 0A000h
         db 3
         dw 0
map_scc: dw 5000h
         db 0
         dw 7000h
         db 1
         dw 9000h
         db 2
         dw 0B000h
         db 3
         dw 0

