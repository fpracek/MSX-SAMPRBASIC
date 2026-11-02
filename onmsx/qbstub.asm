; test SAMPRBAS.COM: prints the command line received (for compiler tests)
        ORG 0100h
        ld hl,0081h
        ld a,(0080h)
        ld b,a
        ld de,msg
        ld c,9
        push hl
        push bc
        call 5
        pop bc
        pop hl
.l:     ld a,b
        or a
        jr z,.d
        ld a,(hl)
        cp 0Dh
        jr z,.d
        ld e,a
        push hl
        push bc
        ld c,2
        call 5
        pop bc
        pop hl
        inc hl
        djnz .l
.d:     ld de,fin
        ld c,9
        call 5
.h:     jr .h
msg:    db "QBSTUB:$"
fin:    db "<end>$"
