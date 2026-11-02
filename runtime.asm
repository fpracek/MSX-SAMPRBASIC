; =====================================================================
; MSXQB runtime - 16K ROM at 4000h, MSX2, SCREEN 0 80-column text
; Conventions: signed 16-bit integers in HL; strings = pointer to
; [len][data...], max 255. Shared empty string = rt_empty.
; =====================================================================
CHPUT   equ 00A2h
CHGET   equ 009Fh
CHSNS   equ 009Ch
INITXT  equ 006Ch
CLS     equ 00C3h
POSIT   equ 00C6h
ERAFNK  equ 00CCh
CHGCLR  equ 0062h
RDVRM   equ 004Ah
WRTVRM  equ 004Dh
LINL40  equ 0F3AEh
LINLEN  equ 0F3B0h
CSRX    equ 0F3DDh
JIFFY   equ 0FC9Eh
FORCLR  equ 0F3E9h
BAKCLR  equ 0F3EAh
BDRCLR  equ 0F3EBh

; --- Runtime RAM (page 3) ---
heapp   equ 0C000h
rndseed equ 0C002h
sc_a    equ 0C004h
sc_b    equ 0C006h
numbuf  equ 0C008h          ; 8 bytes
inbuf   equ 0C010h          ; 256 bytes
DATA_BASE equ 0C110h        ; program variables start here
HEAPEND equ 0E800h

        DEVICE NOSLOT64K
        ORG 4000h
        db "AB"
        dw rt_start
        dw 0,0,0
        ds 6

rt_start:
        di
        ld sp,0F380h
        ei
        ld a,80
        ld (LINL40),a
        ld (LINLEN),a
        call INITXT
        call ERAFNK
        xor a
        call CLS
        ld hl,DATA_BASE             ; clears the program's variables and arrays
        ld de,DATA_BASE+1
        ld bc,HEAPBASE-DATA_BASE-1
        ld (hl),0
        ldir
        ld hl,HEAPBASE
        ld (heapp),hl
        ld hl,(JIFFY)
        set 0,l
        ld (rndseed),hl
        jp main_start

rt_end:
        halt
        jr rt_end

; ---------------------------------------------------------------- errori
rt_ediv: ld hl,msg_div
        jr rt_fatal
rt_oom: ld hl,msg_oom
        jr rt_fatal
rt_esub: ld hl,msg_sub
rt_fatal:
        push hl
        call rt_pnl
        ld hl,msg_err
        call rt_pstr
        pop hl
        call rt_pstr
        jr rt_end

msg_err: db 7,"Error: "
msg_div: db 16,"Division by zero"
msg_oom: db 19,"Out of string space"
msg_sub: db 22,"Subscript out of range"
rt_empty: db 0

; ---------------------------------------------------------------- output
rt_putc:
        push hl
        push de
        push bc
        call CHPUT
        pop bc
        pop de
        pop hl
        ret

rt_pstr:                    ; HL = stringa
        ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
.l:     ld a,(hl)
        call rt_putc
        inc hl
        djnz .l
        ret

rt_pnl:
        ld a,0Dh
        call rt_putc
        ld a,0Ah
        jp rt_putc

rt_zone:                    ; comma in PRINT: next 14-column zone
.l:     ld a,' '
        call rt_putc
        ld a,(CSRX)
        dec a
.m:     sub 14
        ret z
        jr nc,.m
        jr .l

rt_pint:                    ; stampa HL: segno/spazio, cifre, spazio
        bit 7,h
        jr z,.pos
        ld a,'-'
        call rt_putc
        call rt_neghl
        jr .dig
.pos:   ld a,' '
        call rt_putc
.dig:   call rt_udec
        ld a,' '
        jp rt_putc

rt_udec:                    ; HL unsigned
        ld c,0
        ld de,10000
        call .dg
        ld de,1000
        call .dg
        ld de,100
        call .dg
        ld de,10
        call .dg
        ld a,l
        add a,'0'
        jp rt_putc
.dg:    ld a,'0'-1
.l:     inc a
        or a
        sbc hl,de
        jr nc,.l
        add hl,de
        cp '0'
        jr nz,.pr
        bit 0,c
        ret z
.pr:    set 0,c
        jp rt_putc

rt_cls:
        xor a
        jp CLS

rt_color:                   ; E = foreground, L = background
        ld a,e
        ld (FORCLR),a
        ld a,l
        ld (BAKCLR),a
        ld (BDRCLR),a
        jp CHGCLR

rt_wait:                    ; HL = frame da attendere
.l:     ld a,h
        or l
        ret z
        ld a,(JIFFY)
        ld b,a
.w:     ld a,(JIFFY)
        cp b
        jr z,.w
        dec hl
        jr .l

; ---------------------------------------------------------------- aritmetica
rt_neghl:
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ret
rt_negde:
        ld a,e
        cpl
        ld e,a
        ld a,d
        cpl
        ld d,a
        inc de
        ret

rt_mul:                     ; HL = HL*DE
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     add hl,hl
        sla e
        rl d
        jr nc,.n
        add hl,bc
.n:     dec a
        jr nz,.l
        ret

rt_div:                     ; HL = HL\DE (signed), DE = remainder
        ld a,d
        or e
        jp z,rt_ediv
        ld a,h
        xor d
        push af             ; segno quoziente
        ld a,h
        push af             ; segno resto
        bit 7,h
        jr z,.p1
        call rt_neghl
.p1:    bit 7,d
        jr z,.p2
        call rt_negde
.p2:    ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     sla c
        rl b
        adc hl,hl
        or a
        sbc hl,de
        jr nc,.set
        add hl,de
        jr .n
.set:   inc c
.n:     dec a
        jr nz,.l
        ld d,h
        ld e,l
        ld h,b
        ld l,c
        pop af
        bit 7,a
        jr z,.r
        call rt_negde
.r:     pop af
        bit 7,a
        ret z
        jp rt_neghl

rt_mod:                     ; HL = HL MOD DE
        call rt_div
        ex de,hl
        ret

rt_div10:                   ; HL/10 unsigned -> HL, A = remainder
        xor a
        ld b,16
.l:     add hl,hl
        rla
        cp 10
        jr c,.n
        sub 10
        inc l
.n:     djnz .l
        ret

; signed compare: DE = left, HL = right -> Z equal, C if DE<HL
rt_cmp:
        ld a,d
        xor h
        jp m,.diff
        ex de,hl
        or a
        sbc hl,de
        ret
.diff:  ld a,d
        rla
        ld a,1
        inc a
        ret

; da flag a booleano (-1/0)
b_eq:   ld hl,0
        ret nz
        dec hl
        ret
b_ne:   ld hl,0
        ret z
        dec hl
        ret
b_lt:   ld hl,0
        ret nc
        dec hl
        ret
b_ge:   ld hl,0
        ret c
        dec hl
        ret
b_gt:   ld hl,0
        ret c
        ret z
        dec hl
        ret
b_le:   ld hl,-1
        ret c
        ret z
        inc hl
        ret

rt_chk:                     ; HL = index, DE = number of elements
        or a
        sbc hl,de
        jp nc,rt_esub
        add hl,de
        ret

rt_rnd16:
        ld hl,(rndseed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rndseed),hl
        ret

rt_rnd:                     ; HL = n -> 0..n-1
        ex de,hl
        bit 7,d
        jr nz,.z
        ld a,d
        or e
        jr z,.z
        push de
        call rt_rnd16
        res 7,h
        pop de
        call rt_div
        ex de,hl
        ret
.z:     ld hl,0
        ret

; ---------------------------------------------------------------- stringhe
rt_alloc:                   ; A = length -> HL = new string (len set)
        push de
        push bc
        ld hl,(heapp)
        push hl
        ld c,a
        ld b,0
        inc bc
        add hl,bc
        jp c,rt_oom
        push hl
        ld de,HEAPEND
        or a
        sbc hl,de
        pop hl
        jp nc,rt_oom
        ld (heapp),hl
        pop hl
        ld a,c              ; C = len+1 (inc bc): the real length is C-1
        dec a
        ld (hl),a
        pop bc
        pop de
        ret

rt_scopy:                   ; HL = source, DE = destination buffer
        ld c,(hl)
        ld b,0
        inc bc
        ldir
        ret

rt_sdup:                    ; HL = string -> temporary copy
        ld a,(hl)
        or a
        jr nz,.n
        ld hl,rt_empty
        ret
.n:     ld c,a
        ld b,0
        ex de,hl
        call rt_alloc
        push hl
        inc hl
        ex de,hl
        inc hl
        ldir
        pop hl
        ret

rt_scat:                    ; DE = a, HL = b -> a+b
        ld (sc_a),de
        ld (sc_b),hl
        ld a,(de)
        ld b,a
        ld a,(hl)
        ld c,a
        add a,b
        jr nc,.ok
        ld a,255
        sub b
        ld c,a
.ok:    ld a,b
        add a,c
        call rt_alloc
        push hl
        inc hl
        ex de,hl
        ld hl,(sc_a)
        inc hl
        ld a,b
        or a
        jr z,.s1
        push bc
        ld c,b
        ld b,0
        ldir
        pop bc
.s1:    ld hl,(sc_b)
        inc hl
        ld a,c
        or a
        jr z,.s2
        ld b,0
        ldir
.s2:    pop hl
        ret

rt_substr:                  ; A = conteggio, B = offset, DE = sorgente
        or a
        jr nz,.nz
        ld hl,rt_empty
        ret
.nz:    ld c,a
        call rt_alloc
        push hl
        inc hl
        ex de,hl
        inc hl
        ld a,l
        add a,b
        ld l,a
        jr nc,.k
        inc h
.k:     ld b,0
        ldir
        pop hl
        ret

rt_left:                    ; DE = s, HL = n
        bit 7,h
        jr z,.a
        ld hl,0
.a:     ld a,h
        or a
        jr nz,.cap
        ld a,(de)
        cp l
        jr c,.cap
        ld a,l
        jr .go
.cap:   ld a,(de)
.go:    ld b,0
        jp rt_substr

rt_right:                   ; DE = s, HL = n
        bit 7,h
        jr z,.a
        ld hl,0
.a:     ld a,h
        or a
        jr nz,.cap
        ld a,(de)
        cp l
        jr c,.cap
        ld a,l
        jr .go
.cap:   ld a,(de)
.go:    ld c,a
        ld a,(de)
        sub c
        ld b,a
        ld a,c
        jp rt_substr

rt_mid:                     ; BC = s, DE = start (1..), HL = len
        bit 7,h
        jr z,.l1
        ld hl,0
.l1:    ld a,h
        or a
        jr z,.l2
        ld l,255
.l2:    bit 7,d
        jr nz,.s0
        ld a,d
        or a
        jr nz,.empty
        ld a,e
        or a
        jr z,.s0
        dec a
        jr .s1
.s0:    xor a
.s1:    ld h,a
        ld a,(bc)
        sub h
        jr z,.empty
        jr c,.empty
        cp l
        jr c,.go
        ld a,l
.go:    ld d,b
        ld e,c
        ld b,h
        jp rt_substr
.empty: ld hl,rt_empty
        ret

rt_len: ld l,(hl)
        ld h,0
        ret

rt_asc: ld a,(hl)
        or a
        jr z,.e
        inc hl
        ld l,(hl)
        ld h,0
        ret
.e:     ld hl,0
        ret

rt_chr: ld e,l
        ld a,1
        call rt_alloc
        inc hl
        ld (hl),e
        dec hl
        ret

rt_str:                     ; HL = intero -> stringa (spazio/segno + cifre)
        ld c,' '
        bit 7,h
        jr z,.p
        ld c,'-'
        call rt_neghl
.p:     ld de,numbuf+8
.d:     push de
        call rt_div10
        pop de
        add a,'0'
        dec de
        ld (de),a
        ld a,h
        or l
        jr nz,.d
        dec de
        ld a,c
        ld (de),a
        ld hl,numbuf+8
        or a
        sbc hl,de
        ld c,l
        ld b,0
        ld a,l
        call rt_alloc
        push hl
        inc hl
        ex de,hl
        ldir
        pop hl
        ret

rt_val:                     ; HL = stringa -> intero
        ex de,hl
        ld a,(de)
        ld b,a
        inc de
        ld hl,0
        ld c,0
.sp:    ld a,b
        or a
        jr z,.end
        ld a,(de)
        cp ' '
        jr nz,.sg
        inc de
        dec b
        jr .sp
.sg:    cp '-'
        jr nz,.pl
        ld c,1
        inc de
        dec b
        jr .dg
.pl:    cp '+'
        jr nz,.dg
        inc de
        dec b
.dg:    ld a,b
        or a
        jr z,.end
        ld a,(de)
        sub '0'
        jr c,.end
        cp 10
        jr nc,.end
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld e,a
        ld d,0
        add hl,de
        pop de
        inc de
        dec b
        jr .dg
.end:   bit 0,c
        ret z
        jp rt_neghl

; string compare: DE = left, HL = right -> Z equal, C if DE<HL
rt_scmp:
        ld a,(de)
        ld b,a
        ld a,(hl)
        ld c,a
        inc de
        inc hl
        push bc
        ld a,b
        cp c
        jr c,.m
        ld b,c
.m:     ld a,b
        or a
        jr z,.len
.l:     ld a,(de)
        cp (hl)
        jr nz,.done
        inc de
        inc hl
        djnz .l
.len:   pop bc
        ld a,b
        cp c
        ret
.done:  pop bc
        ret

; ---------------------------------------------------------------- input
rt_inkey:
        call CHSNS
        ld hl,rt_empty
        ret z
        call CHGET
        ld e,a
        ld a,1
        call rt_alloc
        inc hl
        ld (hl),e
        dec hl
        ret

rt_input:                   ; reads a line -> temporary string
        ld hl,inbuf+1
        ld b,0
.k:     push hl
        push bc
        call CHGET
        pop bc
        pop hl
        cp 0Dh
        jr z,.done
        cp 08h
        jr z,.bs
        cp 7Fh
        jr z,.bs
        cp 32
        jr c,.k
        ld c,a
        ld a,b
        cp 250
        jr nc,.k
        ld a,c
        ld (hl),a
        inc hl
        inc b
        call rt_putc
        jr .k
.bs:    ld a,b
        or a
        jr z,.k
        dec hl
        dec b
        ld a,1Dh
        call rt_putc
        ld a,' '
        call rt_putc
        ld a,1Dh
        call rt_putc
        jr .k
.done:  ld a,b
        ld (inbuf),a
        call rt_pnl
        ld hl,inbuf
        jp rt_sdup
