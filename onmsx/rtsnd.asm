; =====================================================================
; Suono: BEEP, SOUND reg,val e PLAY (MML a 3 voci, bloccante, tempo dal JIFFY)
; Stato delle voci (12 byte): +0 puntatore, +2 caratteri rimasti, +3 ottava, +4 lunghezza, +5 volume,
; +6 tick rimasti (word), +8 numero della voce, +9 1 = nota in corso
; =====================================================================
PSGA    equ 0A0h
PSGD    equ 0A1h
BEEPB   equ 00C0h
SV_SIZE equ 12

psg_w:                          ; A = registro, E = valore
        di
        out (PSGA),a
        ld a,e
        out (PSGD),a
        ei
        ret

rt_beep:
        push ix
        ld ix,BEEPB
        call rt_bios
        pop ix
        ret

rt_sound:                       ; SOUND GX1 = registro, GY1 = valore
        ld hl,(GX1)
        ld a,h
        or a
        jp nz,rt_eifc
        ld a,l
        cp 16
        jp nc,rt_eifc
        ld a,(GY1)
        ld e,a
        ld a,l
        jp psg_w

getc:                           ; -> A = carattere maiuscolo, avanza (conserva HL)
        push hl
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(hl)
        inc hl
        ld (ix+0),l
        ld (ix+1),h
        dec (ix+2)
        pop hl
        cp 'a'
        ret c
        cp '{'
        ret nc
        sub 32
        ret

peekc:                          ; -> A = prossimo carattere (0 alla fine), senza avanzare
        ld a,(ix+2)
        or a
        ret z
        push hl
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(hl)
        pop hl
        ret

getnum:                         ; -> HL = numero decimale; Z se non c'era nessuna cifra
        ld hl,0
        ld b,0
.g:     call peekc
        sub '0'
        cp 10
        jr nc,.e
        ld e,a
        ld d,0
        push de
        call getc
        pop de
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        pop de
        add hl,de
        inc b
        jr .g
.e:     ld a,b
        or a
        ret

div16:                          ; HL / DE -> HL
        ld bc,0
        ld a,16
.l:     add hl,hl
        rl c
        rl b
        push hl
        ld h,b
        ld l,c
        or a
        sbc hl,de
        jr c,.no
        ld b,h
        ld c,l
        pop hl
        inc l
        jr .nx
.no:    pop hl
.nx:    dec a
        jr nz,.l
        ret

ticks_for:                      ; HL = lunghezza (1-64) -> HL = tick (JIFFY)
        ld b,l
        ld de,(PTEMPO)
        ld hl,0
.m:     add hl,de
        djnz .m
        ex de,hl
        ld hl,(PHZ)
        jp div16

getlen:                         ; lunghezza facoltativa + punti -> HL = tick (almeno 1)
        call getnum
        jr nz,.has
        ld l,(ix+4)
        ld h,0
.has:   ld a,h
        or a
        jr nz,.bad
        ld a,l
        or a
        jr z,.bad
        cp 65
        jr c,.ok
.bad:   ld l,(ix+4)
        ld h,0
.ok:    call ticks_for
        ld d,h
        ld e,l
.dot:   call peekc
        cp '.'
        jr nz,.done
        call getc
        srl d
        rr e
        add hl,de
        jr .dot
.done:  ld a,h
        or l
        ret nz
        ld hl,1
        ret

clampnum:                       ; HL = valore, B = massimo, C = minimo -> A
        ld a,h
        or a
        ld a,b
        ret nz
        ld a,l
        cp c
        jr nc,.l
        ld a,c
.l:     cp b
        ret c
        ld a,b
        ret

silence:                        ; spegne la voce IX
        ld a,(ix+8)
        add a,8
        ld e,0
        jp psg_w

setnote:                        ; C = semitono (-1..12), B = ottava
        ld a,c
        bit 7,a
        jr z,.p1
        add a,12
        dec b
.p1:    cp 12
        jr c,.p2
        sub 12
        inc b
.p2:    ld c,a
        ld a,b                  ; ottava 1-8
        or a
        jr nz,.p3
        inc b
.p3:    ld a,b
        cp 9
        jr c,.p4
        ld b,8
.p4:    ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,pertab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        dec b
        jr z,.sh
.s:     srl h
        rr l
        djnz .s
.sh:    ld a,(ix+8)
        add a,a
        ld e,l
        push hl
        call psg_w
        pop hl
        ld a,(ix+8)
        add a,a
        inc a
        ld e,h
        call psg_w
        ld a,(ix+8)
        add a,8
        ld e,(ix+5)
        call psg_w
        ld (ix+9),1
        ret

pertab: dw 1710,1614,1523,1438,1357,1281,1209,1141,1077,1017,960,906
notebase: db 9,11,0,2,4,5,7

parse:                          ; legge i comandi MML finche' non produce una nota o una pausa
.nx:    ld a,(ix+2)
        or a
        jp z,.end
        call getc
        cp '>'
        jp z,.up
        cp '<'
        jp z,.dn
        cp 'A'
        jr c,.nx
        cp 'H'
        jp c,.note
        cp 'R'
        jp z,.rest
        cp 'O'
        jr z,.o
        cp 'L'
        jr z,.l
        cp 'T'
        jr z,.t
        cp 'V'
        jr z,.v
        cp 'N'
        jp z,.n
        cp 'M'
        jr z,.skip
        cp 'S'
        jr z,.skip
        cp '>'
        jr z,.up
        cp '<'
        jr z,.dn
        jr .nx
.skip:  call getnum
        jr .nx
.up:    ld a,(ix+3)
        cp 8
        jr nc,.nx
        inc (ix+3)
        jr .nx
.dn:    ld a,(ix+3)
        cp 2
        jr c,.nx
        dec (ix+3)
        jr .nx
.o:     call getnum
        ld b,8
        ld c,1
        call clampnum
        ld (ix+3),a
        jr .nx
.l:     call getnum
        ld b,64
        ld c,1
        call clampnum
        ld (ix+4),a
        jp .nx
.t:     call getnum
        ld a,h
        or a
        jr nz,.t2
        ld a,l
        cp 32
        jr nc,.t4
.t2:    ld hl,120
.t4:    ld (PTEMPO),hl
        jp .nx
.v:     call getnum
        ld b,15
        ld c,0
        call clampnum
        ld (ix+5),a
        jp .nx
.n:     call getnum             ; N0 = pausa, N1-N96 = nota assoluta
        ld a,h
        or a
        jr nz,.rest0
        ld a,l
        or a
        jr z,.rest0
        cp 97
        jr nc,.rest0
        dec a
        ld b,1
.n1:    cp 12
        jr c,.n2
        sub 12
        inc b
        jr .n1
.n2:    ld c,a
        push bc
        ld l,(ix+4)
        ld h,0
        call ticks_for
        ld (ix+6),l
        ld (ix+7),h
        pop bc
        jp setnote
.rest0: ld l,(ix+4)
        ld h,0
        call ticks_for
        jr .rst
.rest:  call getlen
.rst:   ld (ix+6),l
        ld (ix+7),h
        ld (ix+9),0
        jp silence
.note:  sub 'A'
        ld e,a
        ld d,0
        ld hl,notebase
        add hl,de
        ld c,(hl)
        call peekc
        cp '#'
        jr z,.sh
        cp '+'
        jr z,.sh
        cp '-'
        jr nz,.acc
        call getc
        dec c
        jr .acc
.sh:    call getc
        inc c
.acc:   push bc
        call getlen
        ld (ix+6),l
        ld (ix+7),h
        pop bc
        ld b,(ix+3)
        jp setnote
.end:   ld (ix+9),0
        jp silence

rt_play:
        push ix
        ld a,(0FFE8h)           ; RG9SAV: bit 1 = 50 Hz
        ld hl,14400             ; 60 Hz: 60*240
        bit 1,a
        jr z,.hz
        ld hl,12000
.hz:    ld (PHZ),hl
        ld hl,120
        ld (PTEMPO),hl
        ld a,7
        ld e,0B8h               ; toni A,B,C accesi, rumore spento
        call psg_w
        ld ix,PVOICE
        ld hl,PLV
        ld b,3
.iv:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld a,d
        or e
        jr z,.nov
        ex de,hl
        ld a,(hl)
        inc hl
        ld (ix+0),l
        ld (ix+1),h
        jr .ivc
.nov:   xor a
.ivc:   ld (ix+2),a
        ld (ix+3),4
        ld (ix+4),4
        ld (ix+5),8
        ld (ix+6),0
        ld (ix+7),0
        ld (ix+9),0
        ld a,3
        sub b
        ld (ix+8),a
        ld de,SV_SIZE
        add ix,de
        pop hl
        djnz .iv
.main:  xor a
        ld (PANY),a
        ld ix,PVOICE
        ld b,3
.v:     ld a,(ix+6)
        or (ix+7)
        jr nz,.act
        ld a,(ix+2)
        or a
        jr z,.next
        push bc
        call parse
        pop bc
        ld a,(ix+6)
        or (ix+7)
        jr z,.next
.act:   ld a,1
        ld (PANY),a
.next:  ld de,SV_SIZE
        add ix,de
        djnz .v
        ld a,(PANY)
        or a
        jr z,.fin
        ei
        ld a,(JIFFY)
        ld c,a
.w:     ld a,(JIFFY)
        cp c
        jr z,.w
        ld ix,PVOICE
        ld b,3
.d1:    ld l,(ix+6)
        ld h,(ix+7)
        ld a,h
        or l
        jr z,.d2
        dec hl
        ld (ix+6),l
        ld (ix+7),h
        ld a,h
        or a
        jr nz,.d2
        ld a,l
        cp 1
        jr nz,.d2
        ld a,(ix+9)             ; ultimo tick di una nota: breve stacco
        or a
        jr z,.d2
        call silence
.d2:    ld de,SV_SIZE
        add ix,de
        djnz .d1
        jr .main
.fin:   ld a,8
        ld e,0
        call psg_w
        ld a,9
        ld e,0
        call psg_w
        ld a,10
        ld e,0
        call psg_w
        pop ix
        ret
