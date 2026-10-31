; Runtime ROMMODE: stub dei file (nessun DOS) e WRITE
; --- i file richiedono MSX-DOS: nelle cartucce sono errori
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
        jp e_nodos
fput_sel:
files_close_all:
        ret
curcol:
        ld a,(CSRX)
        dec a
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

; --- chiamate fra segmenti: A = indice nella tabella FARTAB (4 byte: banco, 0, indirizzo)
; Lo stato di ritorno sta in una pila software (indirizzo + banco) in C000h-C08Fh, cosi' il frame dello stack
; vista dalla routine chiamata resta [ritorno][argomenti]
FARTAB  equ 7F00h
FSTK    equ 0C000h
rt_farcall:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,FARTAB
        add hl,de
        ld c,(hl)               ; C = banco di destinazione
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = indirizzo
        di
        exx
        pop de                  ; DE' = ritorno del chiamante
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

rom_vars:                       ; dopo l'azzeramento della RAM: pila delle chiamate, registro della finestra di codice
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
        ld a,2                  ; banchi da 8 KB: la finestra di codice parte dal banco 2
        jr nz,.b
        ld a,1                  ; ASCII16: banco 1
.b:     ld (CURBANK),a
        ret
cwregs: dw 7000h, 7000h, 8000h, 9000h

dwregs: dw 7800h, 7000h, 0A000h, 0B000h

rt_setbank:                     ; SETBANK n: il segmento n compare nella finestra dati
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
        jr z,.w                 ; ASCII16: banco = segmento, nella stessa finestra del codice
        inc a                   ; banchi da 8 KB: il segmento n e' il banco n+1
.w:     ld hl,(DWREG)
        ld (hl),a
        ld hl,(CWREG)
        ld de,(DWREG)
        or a
        sbc hl,de
        ret nz
        ld (CURBANK),a          ; stessa finestra: il banco corrente cambia
        ret

rt_datawin:                     ; DATAWIN -> indirizzo della finestra dati (8000h per ASCII16, A000h per gli altri)
        ld hl,8000h
        ld a,(rt_target)
        cp 4
        ret z
        ld hl,0A000h
        ret
