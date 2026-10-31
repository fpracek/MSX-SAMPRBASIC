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
