; ROMMODE runtime: file stubs (no DOS) and WRITE
; --- files require MSX-DOS: in cartridges they are errors
msg_nodos: db msg_nodos_e-msg_nodos-1,"Error: Files need MSX-DOS"
msg_nodos_e:
e_nodos: ld hl,msg_nodos
        jp rt_fatal
rt_open:
rt_close:
rt_outsel:
rt_finput:
rt_fline:
rt_feof:
rt_kill:
rt_bload:
rt_bsave:
rt_field:
rt_fget:
rt_fput:
rt_flof:
rt_rset:
        jp e_nodos
fput_sel:
files_close_all:
        ret
curcol:
        ld a,(CSRX)
        dec a
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

; --- calls between segments: A = index into the FARTAB table (4 bytes: bank, 0, address)
; The return state is kept in a software stack (address + bank) at C000h-C08Fh, so the stack frame
; as seen by the called routine remains [return][arguments]
FARTAB  equ 7F00h
FSTK    equ 0C000h
rt_farcall:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,FARTAB
        add hl,de
        ld c,(hl)               ; C = destination bank
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = address
        di
        exx
        pop de                  ; DE' = caller's return
        ld hl,(FARSP)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(CURBANK)
        ld (hl),a
        inc hl
        ld (FARSP),hl
        exx
        ld hl,far_ret
        push hl
        ld a,c
        ld hl,(CWREG)
        ld (CURBANK),a
        ld (hl),a
        ex de,hl
        ei
        jp (hl)
far_ret:
        di
        exx
        ld hl,(FARSP)
        dec hl
        ld a,(hl)
        dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        ld (FARSP),hl
        ld hl,(CWREG)
        ld (CURBANK),a
        ld (hl),a
        push de
        exx
        ei
        ret

rom_vars:                       ; after clearing RAM: call stack, code window register
        in a,(0A8h)             ; page 3 slot (RAM, mapper): needed by MGET/MPUT/...
        rlca
        rlca
        and 3
        ld c,a
        ld b,0
        ld hl,0FCC1h
        add hl,bc
        ld a,(hl)
        and 80h
        or c
        ld c,a
        jp p,.ns
        ld a,(0FFFFh)
        cpl
        and 0C0h
        rrca
        rrca
        rrca
        rrca
        and 0Ch
        or c
        ld c,a
.ns:    ld a,c
        ld (RAMSL),a
        ld hl,FSTK
        ld (FARSP),hl
        ld a,(rt_target)
        sub 3
        ret c
        add a,a
        ld e,a
        ld d,0
        ld hl,cwregs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (CWREG),de
        ld hl,dwregs
        ld e,a
        ld a,(rt_target)
        sub 3
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (DWREG),de
        ld a,(rt_target)
        cp 4
        ld a,2                  ; 8 KB banks: the code window starts at bank 2
        jr nz,.b
        ld a,1                  ; ASCII16: banco 1
.b:     ld (CURBANK),a
        ret
cwregs: dw 7000h, 7000h, 8000h, 9000h

dwregs: dw 7800h, 7000h, 0A000h, 0B000h

rt_setbank:                     ; SETBANK n: segment n appears in the data window
        ld a,(rt_target)
        cp 3
        jp c,rt_eifc
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        or a
        jp z,rt_eifc
        ld b,a
        ld a,(rt_target)
        cp 4
        ld a,b
        jr z,.w                 ; ASCII16: bank = segment, in the same window as the code
        inc a                   ; 8 KB banks: segment n is bank n+1
.w:     ld hl,(DWREG)
        ld (hl),a
        ld hl,(CWREG)
        ld de,(DWREG)
        or a
        sbc hl,de
        ret nz
        ld (CURBANK),a          ; same window: the current bank changes
        ret

rt_datawin:                     ; DATAWIN -> address of the data window (8000h for ASCII16, A000h for the others)
        ld hl,8000h
        ld a,(rt_target)
        cp 4
        ret z
        ld hl,0A000h
        ret
