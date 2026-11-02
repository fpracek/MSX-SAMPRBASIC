; BINMODE runtime: no DOS (files = error), WRITE
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

