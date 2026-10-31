; raccordi per il compilatore
rt_frnd:                        ; FA -> HL arrotondato
        ld a,1
        jp fp_ftoi
rt_ftrunc:                      ; FA -> HL troncato
        xor a
        jp fp_ftoi
rt_pflt:                        ; stampa FA come i numeri interi: segno o spazio, cifre, spazio
        call rt_fstr
        call rt_pstr
        ld a,' '
        jp rt_putc
rt_flit:                        ; HL = pozzetto (flag + 4 byte), DE = testo della costante: la prima volta si converte
        ld a,(hl)
        or a
        jr z,.p
        inc hl
        jp fp_load
.p:     push hl
        ex de,hl
        call rt_fval
        pop hl
        ld (hl),1
        inc hl
        jp fp_st
