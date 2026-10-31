s=open('patch_rand.py').read()
i=s.index("rt_rset:                        ; RSET:")
j=s.index('""".replace(\'\n\', nl)\nopen(\'rtfile.asm\'', i)
new = '''rt_rset:                        ; RSET: HL = stringa, DE = variabile: allineata a destra nella larghezza del suo campo FIELD
        ld (S1),de
        push hl
        ld hl,0
        ld (S2),hl
        ld de,(FILEP)
        ld a,d
        or e
        jr z,.go
        ld b,3
.sl:    push bc
        push de
        push de
        pop ix
        ld a,(ix+FS_MODE)
        cp 4
        jr nz,.nx
        ld a,(ix+FS_NFLD)
        or a
        jr z,.nx
        ld b,a
        push ix
        pop hl
        ld de,FS_FLD
        add hl,de
.fl:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(S1)
        or a
        sbc hl,de
        pop hl
        jr nz,.ne
        inc hl
        ld a,(hl)
        ld (S2),a
        pop de
        pop bc
        jr .go
.ne:    inc hl
        inc hl
        djnz .fl
.nx:    pop de
        ld hl,FS_SIZE
        add hl,de
        ex de,hl
        pop bc
        djnz .sl
.go:    pop hl
        ld a,(S2)
        or a
        jr nz,.pad
        ld de,(S1)
        jp rt_scopy
.pad:   ld c,a
        ld a,(hl)
        inc hl
        cp c
        jr c,.sh
        ld a,c
.sh:    ld b,a
        ld a,c
        ld (inbuf),a
        sub b
        ld de,inbuf+1
        jr z,.cp
        push bc
        ld b,a
.sp:    ld a,' '
        ld (de),a
        inc de
        djnz .sp
        pop bc
.cp:    ld a,b
        or a
        jr z,.fin
        ld c,b
        ld b,0
        ldir
.fin:   ld hl,inbuf
        ld de,(S1)
        jp rt_scopy
'''
s=s[:i]+new+s[j:]
s=s.replace("        ld de,BBUFF\n","")
open('patch_rand.py','w').write(s)
