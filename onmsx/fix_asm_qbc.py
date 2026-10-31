p = 'qbc.asm'
t = open(p, encoding='latin-1', newline='').read()
nl = '\r\n' if '\r\n' in t else '\n'
t = t.replace('\r\n', '\n')


def rep(a, b):
    global t
    assert t.count(a) == 1, (a[:70], t.count(a))
    t = t.replace(a, b)


# spazio: tabelle +100h
rep("SRC     equ 4B00h\nSRCMAX  equ 34FEh", "SRC     equ 4C00h\nSRCMAX  equ 33FEh")
rep("LABT    equ 3B00h", "LABT    equ 3C00h")
rep("VART    equ 4280h", "VART    equ 4380h")
rep("BLKS    equ 48C0h", "BLKS    equ 49C0h")
rep("FCBSV   equ 4A68h", "FCBSV   equ 4B68h")
rep("; Memoria: codice 0100h-3AFFh, tabelle 3B00h-4AFFh, sorgente 4B00h-7FFFh,", "; Memoria: codice 0100h-3BFFh, tabelle 3C00h-4BFFh, sorgente 4C00h-7FFFh,")
rep("usewin  equ ST+216 ", "asmbase equ ST+60               ; w  inizio del blocco di assembler in linea (indirizzo virtuale)\nusewin  equ ST+216 ")

# chiamata
rep("        IFNDEF ROMMODE\n        call chk_rom\n        ENDIF\n        call compile", "        IFNDEF ROMMODE\n        call chk_rom\n        ENDIF\n        call chk_asm\n        call compile")

# gancio del debugger: non dentro i blocchi '#', e HL conservato
rep(""".stmt:  ld a,(dbgf)
        or a
        call nz,emit_dbg
        call statement""", """.stmt:  ld a,(dbgf)
        or a
        jr z,.go
        ld a,(ttype)
        cp T_P
        jr nz,.hk
        ld a,(tval)
        cp '#'
        jr z,.go                ; dentro i blocchi di assembler in linea non si inseriscono ganci
.hk:    call emit_dbg
.go:    call statement""")
rep("""emit_dbg:                       ; OPTION DEBUG: ld hl,<riga> ; call RT_DBG
        ld a,21h
        call emit_a
        ld hl,(tline)
        call emit_w
        EM3 0CDh,low RT_DBG,high RT_DBG
        ret
""", """emit_dbg:                       ; OPTION DEBUG: push hl ; ld hl,<riga> ; call RT_DBG ; pop hl
        EM1 0E5h
        ld a,21h
        call emit_a
        ld hl,(tline)
        call emit_w
        EM3 0CDh,low RT_DBG,high RT_DBG
        EM1 0E1h
        ret
""")

# statement0: '#'
rep("""        ld a,(tval)
        cp '?'
        jp nz,err_syntax
        call next_tok
        jp st_print
.kw:""", """        ld a,(tval)
        cp '#'
        jr z,.asm
        cp '?'
        jp nz,err_syntax
        call next_tok
        jp st_print
.asm:   call next_tok
        jp st_asmb
.kw:""")

# st_asmb + chk_asm prima di st_option
rep("""s_debug: db "DEBUG",0
""", """s_debug: db "DEBUG",0

st_asmb:                        ; "# [*] elementi": byte preparati da QASM.OVL (assembler in linea)
        ld a,'*'
        call is_p
        jr nz,.l
        call get_pc
        ld (asmbase),hl
        call next_tok
.l:     ld a,(ttype)
        or a
        ret z
        cp T_NUM
        jr z,.num
        cp T_ID
        jr z,.var
        ld a,'+'
        call is_p
        jp nz,err_syntax
        call next_tok           ; +k: inizio del blocco + k
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld de,(asmbase)
        add hl,de
        call emit_w
        jr .nx
.num:   ld a,(tval)
        push af
        call next_tok
        ld a,':'
        call is_p
        jr nz,.byte
        call next_tok           ; n:NOME -> n + indirizzo dell'etichetta BASIC
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        pop af
        call label_jump
.nx:    call next_tok
        jr .sep
.byte:  pop af
        call emit_a
        jr .sep
.var:   call resolve_var        ; indirizzo di una variabile globale intera o stringa
        cp 2
        jp nc,err_type
        push hl
        call next_tok
        pop hl
        ld a,'+'
        call is_p
        jr nz,.vw
        push hl
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld de,(tval)
        pop hl
        add hl,de
        push hl
        call next_tok
        pop hl
.vw:    call emit_w
.sep:   ld a,(ttype)
        or a
        ret z
        ld a,','
        call expect_p
        jr st_asmb.l

chk_asm:                        ; il sorgente ha "__ASM": QASM.OVL (a 8000h) riscrive i blocchi
        ld hl,SRC
.l:     ld a,(hl)
        or a
        ret z
        cp '_'
        jr nz,.n
        push hl
        ld de,s_asmk
        call match_ci
        pop hl
        jr z,.go
.n:     inc hl
        jr .l
.go:    ld hl,s_ovl
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ld de,0
        ld (tline),de
        ERR 20
.o:     call fcb_rec1
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,3000h
        ld c,F_BRD
        call BDOS
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,SRC
        ld bc,SRCMAX
        call OUT0
        ret nc
        ld (tline),de
        jp error
s_asmk: db 7Fh,7Fh,"asm",0
s_ovl:  db "QASM.OVL",0
""")
open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))
print('ok')
