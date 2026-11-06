; =====================================================================
; MSXQB compilatore su MSX (QBC.COM) - stadio 1
; BASIC -> Z80 machine code (.COM program with the rtcom.asm runtime).
; Single pass, direct emission; HL = accumulator, left operand on the stack.
; Input: command line " NAME.SPB"  ->  writes NAME.COM and starts it.
; Error: reloads the editor with " NAME.SPB E<line> <code>".
; Memory: code 0100h-3EFFh, tables 3F00h-4EFFh, source 4F00h-7FFFh,
;          output 8000h-BEFFh (virtual addresses from 0100h: virt = physical - 7F00h).
; =====================================================================
        INCLUDE "rtabi.inc"
BDOS    equ 0005h
F_OPEN  equ 0Fh
F_CLOSE equ 10h
F_DEL   equ 13h
F_MAKE  equ 16h
F_DMA   equ 1Ah
F_BWR   equ 26h
F_BRD   equ 27h

        IFDEF ROMMODE
SRC     equ 4400h               ; the cartridge compiler has no OPTION NUMBERED: the tables live in high RAM
SRCMAX  equ 3BFEh
        ELSE
        IFDEF BINMODE
SRC     equ 4F00h
        ELSE
SRC     equ 4F00h
        ENDIF
        IFDEF BINMODE
SRCMAX  equ 30FEh
        ELSE
SRCMAX  equ 30FEh
        ENDIF
        ENDIF
OUT0    equ 8000h
        IFDEF ROMMODE
HDRB    equ OUT0+(RT_EMPTY-IMGBASE)     ; runtime header inside the buffer (the runtime is in the buffer)
        ELSE
HDRB    equ ST+232              ; .COM: the runtime is not in the buffer (copied from the RT.BIN file): the fields are kept here
        ENDIF
HDRNAME equ HDRB+(RT_NAME-RT_EMPTY)
HDRDSZ  equ HDRB+(RT_DSIZE-RT_EMPTY)
HDRDAT  equ HDRB+(RT_DATA0-RT_EMPTY)
HDRTGT  equ HDRB+(RT_TARGET-RT_EMPTY)
HDRLEN  equ RT_TARGET+1-RT_EMPTY
RTSTAMP equ 0C200h               ; 20 bytes: RT.BIN stamp (COM)
RTCHK   equ 0CA00h               ; first block of the existing NAME.COM (after compilation the NUMBERED index is no longer needed)
rtsz    equ ST+254              ; w  size of RT.BIN (.COM)
        IFDEF ROMMODE
IMGBASE equ 4000h               ; virtual address of the image start (cartridge in page 1)
        ELSE
        IFDEF BINMODE
IMGBASE equ 8400h               ; BIN: image loaded at 8400h with BLOAD
        ELSE
IMGBASE equ 0100h
        ENDIF
        ENDIF
OUTLIM  equ 0BFh                ; high byte: beyond BF00h the program is too large
LDR     equ 0C000h

        IFDEF ROMMODE
LABT    equ 0CA00h
        ELSE
        IFDEF BINMODE
LABT    equ 3F00h
        ELSE
LABT    equ 3F00h
        ENDIF
;              ; labels: 96 x 20 bytes
        ENDIF
LABREC  equ 20
MAXLAB  equ 96
        IFDEF ROMMODE
VART    equ 0D180h
        ELSE
        IFDEF BINMODE
VART    equ 4680h
        ELSE
VART    equ 4680h
        ENDIF
;               ; variables/arrays: 100 x 16 bytes
        ENDIF
VARREC  equ 16
MAXVAR  equ 100
        IFDEF ROMMODE
BLKS    equ 0D7C0h
        ELSE
        IFDEF BINMODE
BLKS    equ 4CC0h
        ELSE
BLKS    equ 4CC0h
        ENDIF
;               ; block stack: 24 x 10 bytes
        ENDIF
BLKREC  equ 10
MAXBLK  equ 24

ST      equ 0C100h
lp      equ ST+0                ; w  pointer into the source
lineno  equ ST+2                ; w  current line
tline   equ ST+4                ; w  line of the current token
ttype   equ ST+6                ; b
tval    equ ST+7                ; w
tlen    equ ST+9                ; b  string length
tsuf    equ ST+10               ; b  '$' suffix present
iseof   equ ST+11               ; b
tbuf    equ ST+12               ; 16 bytes: uppercase identifier (0-terminated)
LEXSZ   equ 28
lexsv   equ ST+32
outp    equ ST+64               ; w  physical emit pointer
nlab    equ ST+66
nvar    equ ST+67
nblk    equ ST+68
errcode equ ST+69
tmpv    equ ST+70               ; w
tmps    equ ST+72               ; w
namep   equ ST+74               ; w
fname   equ ST+80               ; 16 bytes
oname   equ ST+96               ; 16 bytes
fcb     equ ST+112              ; 37 bytes
mode    equ ST+150              ; b  0 mista, 1 NUMBERED, 2 LABELS
onel    equ ST+151              ; b  line_loop stops at end of line
entp    equ ST+152              ; w
entend  equ ST+154              ; w
en_num  equ ST+156              ; w
en_ptr  equ ST+158              ; w
en_ln   equ ST+160              ; w
en_pos  equ ST+162              ; w
etype   equ ST+164              ; b  type of the last expression (0 integer, 1 string)
tmpf    equ ST+165              ; b  the statement created temporary strings
dptr    equ ST+166              ; w  next free byte in the program's data area
dlim    equ ST+168              ; w  data area limit
nbuf    equ ST+170              ; 16 bytes: normalized name (for predefined functions)
vtyp    equ ST+186              ; b  type of the last variable looked up
fi_s    equ ST+188              ; w
voff    equ ST+220              ; w  physical - virtual (changes with the segment)
outlim  equ ST+222              ; b  high byte beyond which the output is too large
target  equ ST+223              ; b  cartridge type (0 COM)
curseg  equ ST+224              ; b  segment being compiled (0 = fixed)
pseg    equ ST+225              ; b  current segment during the pre-scan
nfar    equ ST+226              ; b  voci usate in FARTAB
romopen equ ST+227              ; b  the ROM file has already been created
        IFDEF ROMMODE
FARTABC equ 0C580h              ; high RAM (the code of the cartridge compiler reaches the source at 4400h): free space after LOCT
SEGT    equ 0C000h              ; the chain loader at C000h is not needed while compiling
FARX    equ 0C014h
FCBSV   equ 0C028h
FCBMAP  equ 0C04Dh              ; OPTION MAP: FCB of NAME.MAP
MAPBUF  equ 0C072h              ; 64-byte buffer of the map file
MAPPOS  equ 0C0B2h              ; 3 bytes: position in the file
MPFILL  equ 0C0B5h              ; bytes in MAPBUF
mpf     equ ST+214              ; OPTION MAP active
        ELSE
        IFDEF BINMODE
FARTABC equ 4AC0h
        ELSE
FARTABC equ 4AC0h
        ENDIF
;               ; FARTAB under construction: 32 x 4 bytes (bank, 0, address)
        IFDEF BINMODE
SEGT    equ 4B40h
        ELSE
SEGT    equ 4B40h
        ENDIF
;               ; segment of each SUB/FUNCTION (index in the record)
        IFDEF BINMODE
FCBSV   equ 4E68h
        ELSE
FCBSV   equ 4E68h
        ENDIF
;               ; copy of the output FCB during INCBIN
        IFDEF BINMODE
FARX    equ 4B54h
        ELSE
FARX    equ 4B54h
        ENDIF
;               ; FARTAB index of each SUB/FUNCTION (FFh = none)
        ENDIF
dbgpa   equ ST+217              ; w  operand (physical) to be patched with the address of the variable table
dbgf    equ ST+219              ; b  OPTION DEBUG active
brkf    equ ST+231              ; b  OPTION BREAK active (.COM)
asmbase equ ST+60               ; w  start of the inline assembler block (virtual address)
usewin  equ ST+216              ; b  the source uses WINDOW: graphic coordinates are converted
nfunc   equ ST+192              ; b
npart   equ ST+193              ; b
nloc    equ ST+194              ; b
nint    equ ST+195              ; b  variabili intere locali create
nstr    equ ST+196              ; b  stringhe locali create
tmpk    equ ST+197              ; b  variable reference type (see emit_ldv)
ca_i    equ ST+198              ; b  call in progress: argument index
ca_paren equ ST+199             ; b  chiamata in corso: parentesi presente
mapf    equ ST+228              ; b  DIM ... MAPPER in corso
mapcnt  equ ST+229              ; w  number of array elements in the mapper
fcur    equ ST+200              ; w  record of the function being compiled (0 = main level)
fexit   equ ST+202              ; w  EXIT SUB/FUNCTION chain
fskiph  equ ST+204              ; w  chain of the jump that skips over the body
framep  equ ST+206              ; w  physical address of the frame operand
d2flag  equ 0C21Eh              ; b  1 = MSX-DOS 2 (directory, variabili d'ambiente)
PATHBUF equ 0C0C0h              ; 64 bytes: path read from the environment
mfile   equ 0C218h              ; b  ROM segmented across several files (NAME000, NAME001...)
mfcur   equ 0C219h              ; b  number of the file being compiled
mforig  equ 0C21Ah              ; 3 bytes: digits of the received name (if reduced to NAME000)
mfkind  equ 0C21Fh              ; b  type of the file found by mf_have: 0 none, 1 .SPB, 2 .BIN
mfbin   equ ST+231              ; b  1 = the current segment is a .BIN (no epilogue to emit)
mfred   equ 0C21Dh              ; b  1 = the received name was a segment other than 000
dbglast equ 0C214h             ; w  OPTION DEBUG: last local variables record emitted (0 = none)
dbgl    equ ST+215              ; ROM: OPTION DEBUG level 0 line only, 1 GLOBALS, 2 ALL
dbgd    equ ST+246              ; ROM: 3 bytes: descriptor of the variable table (bank, address)
dbglb   equ 0C21Eh              ; ROM: bank of the last local-variable record
DBGDESC equ 7F80h               ; ROM: descriptor in the fixed segment (read by the runtime)
dbgfs   equ 0C216h              ; w  OPTION DEBUG: first line of the body of the routine being compiled
ca_rec  equ ST+208              ; w  chiamata in corso: record
chfail  equ ST+210              ; w  chain for CASE a TO b
rf_rec  equ ST+212              ; w
ENT     equ 0CA00h              ; NUMBERED line index: 6 bytes (number, pointer, line) in high RAM
ENTMAX  equ 0D7F0h
FUNT    equ 0C220h              ; SUB/FUNCTION: 20 x 24 bytes (high RAM, only during compilation)
FUNREC  equ 24
MAXFUN  equ 20
PART    equ 0C600h               ; parameters: 64 x 16 bytes (name 12, type)
MAXPAR  equ 64
LOCT    equ 0C400h               ; locals/parameters of the function being compiled: 24 x 16 bytes
        IFDEF ROMMODE
MAXLOC  equ 24                  ; (the FARTAB table of the cartridge compiler follows LOCT)
        ELSE
MAXLOC  equ 32
        ENDIF

T_EOL   equ 0
T_NUM   equ 1
T_ID    equ 2
T_STR   equ 3
T_KW    equ 4
T_P     equ 5

K_PRINT equ 0
K_IF    equ 1
K_THEN  equ 2
K_ELSE  equ 3
K_ELSEIF equ 4
K_END   equ 5
K_FOR   equ 6
K_TO    equ 7
K_STEP  equ 8
K_NEXT  equ 9
K_WHILE equ 10
K_WEND  equ 11
K_GOTO  equ 12
K_GOSUB equ 13
K_RETURN equ 14
K_CLS   equ 15
K_LOCATE equ 16
K_AND   equ 17
K_OR    equ 18
K_XOR   equ 19
K_NOT   equ 20
K_MOD   equ 21
K_LET   equ 22
K_OPTION equ 23
K_INPUT equ 24
K_DIM   equ 25
K_POKE  equ 26
K_SUB   equ 27
K_FUNCTION equ 28
K_CALL  equ 29
K_DECLARE equ 30
K_SHARED equ 31
K_EXIT  equ 32
K_DO    equ 33
K_LOOP  equ 34
K_UNTIL equ 35
K_SELECT equ 36
K_CASE  equ 37
K_IS    equ 38
K_CONST equ 39
K_COLOR equ 40
K_RANDOMIZE equ 41
K_VPOKE equ 42
K_OUT   equ 43
K_SLEEP equ 44
K_STOP  equ 45
K_SCREEN equ 46
K_PSET  equ 47
K_PRESET equ 48
K_LINE  equ 49
K_CIRCLE equ 50
K_PALETTE equ 51
K_PAINT equ 52
K_PUT   equ 53
K_SPRITE equ 54
K_GET   equ 55
K_DRAW  equ 56
K_VIEW  equ 57
K_WINDOW equ 58
K_VBANK equ 59
K_VFILL equ 60
K_VWRITE equ 61
K_SET equ 62
K_COPY equ 63
K_DATA equ 64
K_READ equ 65
K_RESTORE equ 66
K_BEEP equ 67
K_SOUND equ 68
K_PLAY equ 69
K_OPEN equ 70
K_CLOSE equ 71
K_KILL equ 72
K_WRITE equ 73
K_SEGMENT equ 74
K_INCBIN equ 75
K_SETBANK equ 76
K_VCOPY equ 77
K_MPUT equ 78
K_MREAD equ 79
K_MWRITE equ 80
K_MFREE equ 81
K_BLOAD equ 82
K_BSAVE equ 83
K_FIELD equ 84
K_LSET equ 85
K_RSET equ 86

B_IF    equ 1
B_FOR   equ 2
B_WHILE equ 3
B_DO    equ 4
B_SEL   equ 5

E_SYNTAX equ 1
E_LABEL equ 2
E_UNSUP equ 3
E_CHAR  equ 4
E_OPEN  equ 5
E_MISM  equ 6
E_DUP   equ 7
E_MANY  equ 8
E_BIG   equ 9
E_SRCBIG equ 10
E_READ  equ 11
E_WRITE equ 12
E_MODE  equ 13
E_TYPE  equ 14
E_MEM   equ 15
E_RT    equ 16

        MACRO EM1 a
        call emit_i
        db 1,a
        ENDM
        MACRO EM2 a,b
        call emit_i
        db 2,a,b
        ENDM
        MACRO EM3 a,b,c
        call emit_i
        db 3,a,b,c
        ENDM
        MACRO EM4 a,b,c,d
        call emit_i
        db 4,a,b,c,d
        ENDM
        MACRO EM6 a,b,c,d,e,f
        call emit_i
        db 6,a,b,c,d,e,f
        ENDM
        MACRO EM7 a,b,c,d,e,f,g
        call emit_i
        db 7,a,b,c,d,e,f,g
        ENDM
        MACRO BRKCHK
        IFNDEF ROMMODE
        IFNDEF BINMODE
        call emit_brk
        ENDIF
        ENDIF
        ENDM
        MACRO ERR n
        ld a,n
        jp error
        ENDM

        DEVICE NOSLOT64K
        ORG 0100h
start:
        ld hl,(0006h)
        ld sp,hl
        xor a
        ld (mfred),a
        call d2_detect
        call cd_proj            ; DOS 2: work in the project directory
        call getname
        call read_source
        IFNDEF ROMMODE
        IFNDEF BINMODE
        call chk_rom
        ENDIF
        ENDIF
        call chk_asm
        call compile
        IFDEF ROMMODE
        call rom_finish
        jp rom_done
        ELSE
        call write_output
        IFDEF BINMODE
        jp bin_done
        ENDIF
        ENDIF
        ; starts the program from disk: the loader (at C000h) reads NAME.COM
        ld hl,oname
        ld (namep),hl
        call mk_fcb
        ld hl,ldr_img
        ld de,LDR
        ld bc,ldr_size
        ldir
        ld hl,fcb+1
        ld de,LDR+3
        ld bc,11
        ldir
        jp LDR

; ---------------------------------------------------------------- errori
error:                          ; A = code, (tline) = line
        ld (errcode),a
fail:   ld de,0081h
        ld a,' '
        ld (de),a
        inc de
        ld hl,fname
.n:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        jr .n
.e:     ld a,' '
        ld (de),a
        inc de
        ld a,'E'
        ld (de),a
        inc de
        ld hl,(tline)
        call dec_str
        ld a,' '
        ld (de),a
        inc de
        ld a,(errcode)
        ld l,a
        ld h,0
        call dec_str
        ld a,0Dh
        ld (de),a
        inc de
        ld hl,0081h
        ex de,hl
        or a
        sbc hl,de
        ld a,l
        ld (0080h),a
        call cd_home
        ld hl,ldr_img           ; reload the editor (ldr_fn = SAMPRBAS.COM by default)
        ld de,LDR
        ld bc,ldr_size
        ldir
        jp LDR

div10:                          ; HL / 10 (unsigned) -> HL, A = remainder
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

dec_str:                        ; HL = value -> ASCII digits at (DE), DE advances
        ld c,0
.d:     call div10
        add a,'0'
        push af
        inc c
        ld a,h
        or l
        jr nz,.d
.o:     pop af
        ld (de),a
        inc de
        dec c
        jr nz,.o
        ret

; ---------------------------------------------------------------- file
getname:                        ; command line -> fname (uppercase, ".SPB" if the extension is missing)
        ld hl,0081h
        ld a,(0080h)
        or a
        jr z,.none
        ld b,a
.sk:    ld a,(hl)
        cp ' '
        jr nz,.go
        inc hl
        djnz .sk
.none:  jp 0
.go:    ld de,fname
        ld c,0                  ; C = there is a dot
        ld b,12
.cp:    ld a,(hl)
        cp ' '
        jr z,.end
        cp 0Dh
        jr z,.end
        or a
        jr z,.end
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 20h
.u:     cp '.'
        jr nz,.st
        inc c
.st:    ld (de),a
        inc hl
        inc de
        djnz .cp
.end:   ld a,c
        or a
        jr nz,.z
        ld hl,s_bas
        ld bc,4
        ldir
.z:     xor a
        ld (de),a
        IFDEF BINMODE
        ret
        ELSE
        jp norm_seg
        ENDIF
s_bas:  db ".SPB"


; ---------------------------------------------------------------- MSX-DOS 2: project directory (SPBPROJ) and tools directory (SPBHOME)
d2_detect:
        xor a
        ld (d2flag),a
        ld bc,6Fh               ; _DOSVER: only DOS 2 answers with A=0 and B>=2
        call BDOS
        or a
        ret nz
        ld a,b
        cp 2
        ret c
        ld a,1
        ld (d2flag),a
        ret

cd_env:                         ; HL = environment variable name: CHDIR to the directory it contains (if any)
        ld a,(d2flag)
        or a
        ret z
        ld de,PATHBUF
        xor a
        ld (de),a
        ld bc,3C6Bh             ; _GENV, 60-byte buffer
        call BDOS
        ld a,(PATHBUF)
        or a
        ret z
        ld de,PATHBUF
        ld c,5Ah                ; _CHDIR
        jp BDOS

cd_home:
        ld hl,s_envhome
        jr cd_env
cd_proj:
        ld hl,s_envproj
        jr cd_env
s_envhome: db "SPBHOME",0
s_envproj: db "SPBPROJ",0

open_tool:                      ; DE = FCB of a tools file (RT.BIN, QASM.OVL): with DOS 2 it is opened from the installation directory
        ld a,(d2flag)
        or a
        jr z,.o
        push de
        call cd_home
        pop de
        ld c,F_OPEN
        call BDOS
        push af
        call cd_proj
        pop af
        ret
.o:     ld c,F_OPEN
        jp BDOS

        IFNDEF BINMODE
; ---------------------------------------------------------------- projects segmented across several files
seg_pat:                        ; Z if fname = 5 characters + 3 digits (+ extension)
        ld hl,fname
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        cp '.'
        jr z,.e
        inc hl
        inc b
        jr .l
.e:     ld a,b
        cp 8
        ret nz
        ld hl,fname+5
        ld b,3
.d:     ld a,(hl)
        sub '0'
        cp 10
        jr nc,.no
        inc hl
        djnz .d
        xor a
        ret
.no:    or 1
        ret

seg_zero:                       ; fname+5..7: Z if they are "000"
        ld hl,fname+5
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        cp '0'
        ret

mf_setname:                     ; A = number -> 3 digits in fname+5..7
        ld hl,fname+5
        ld d,'0'
.h:     sub 100
        jr c,.hd
        inc d
        jr .h
.hd:    add a,100
        ld (hl),d
        inc hl
        ld d,'0'
.t:     sub 10
        jr c,.td
        inc d
        jr .t
.td:    add a,10
        ld (hl),d
        inc hl
        add a,'0'
        ld (hl),a
        ret

mf_have:                        ; B = number: Z if NAMEnnn.SPB or NAMEnnn.BIN exists (mfkind = 1 / 2); the output FCB is preserved; fname keeps that number
        push bc
        ld hl,fcb
        ld de,FCBSV
        ld bc,37
        ldir
        pop bc
        push bc
        ld a,b
        call mf_setname
        xor a
        ld (mfkind),a
        ld hl,fname
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        ld a,1
        jr z,.ok
        IFDEF ROMMODE
        call mk_fcb
        ld hl,s_binx
        ld de,fcb+9
        ld bc,3
        ldir
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        ld a,2
        jr nz,.nf
        ELSE
        jr .nf
        ENDIF
.ok:    ld (mfkind),a
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
.nf:    ld hl,FCBSV
        ld de,fcb
        ld bc,37
        ldir
        ld a,(mfkind)
        or a
        ld a,0
        jr nz,.r
        inc a                   ; A = 1: does not exist (NZ)
.r:     or a
        pop bc
        ret
        IFDEF ROMMODE
s_binx: db "BIN"
        ENDIF

norm_seg:                       ; fname = XXXXXddd with ddd other than 000: if XXXXX000 exists, that one is used
        call seg_pat
        ret nz
        call seg_zero
        ret z
        ld hl,fname+5
        ld de,mforig
        ld bc,3
        ldir
        ld b,0
        call mf_have
        jr nz,.no
        ld a,(mfkind)
        cp 1
        jr nz,.no               ; the main file is always a .SPB source
        ld a,1
        ld (mfred),a
        ret
.no:    ld hl,mforig
        ld de,fname+5
        ld bc,3
        ldir
        ret

        IFDEF ROMMODE
mf_init:                        ; multi-file project if the name is XXXXX000 and XXXXX001 exists
        xor a
        ld (mfile),a
        ld (mfbin),a
        ld (mfcur),a
        call seg_pat
        ret nz
        call seg_zero
        ret nz
        ld b,1
        call mf_have
        push af
        xor a
        call mf_setname
        pop af
        ret nz
        ld a,1
        ld (mfile),a
        ret

mf_load:                        ; A = number: reads NAMEnnn into SRC (the ROM's FCB is preserved)
        push af
        ld hl,fcb
        ld de,FCBSV
        ld bc,37
        ldir
        pop af
        call mf_setname
        call read_source
        ld hl,FCBSV
        ld de,fcb
        ld bc,37
        ldir
        ld de,OUT0              ; read_source left the DMA on the source: the ROM writes start from OUT0
        ld c,F_DMA
        call BDOS
        ret

mf_prescan:                     ; SUB/FUNCTION signatures of all files (segment = file number)
        ld a,(mfile)
        or a
        ret z
        ld c,1
.k:     push bc
        ld b,c
        call mf_have
        pop bc
        jr nz,.done
        ld a,(mfkind)
        cp 2
        jr z,.nx                ; .BIN segment: no signatures to read
        push bc
        ld a,c
        ld (pseg),a
        call mf_load
        call prescan
        pop bc
.nx:    inc c
        jr .k
.done:  xor a
        ld (pseg),a
        call mf_load            ; the main file again
        ret

mf_loadbin:                     ; A = number: reads NAMEnnn.BIN as the content of the current segment (already compiled)
        push af
        ld hl,fcb
        ld de,FCBSV
        ld bc,37
        ldir
        pop af
        call mf_setname
        ld hl,fname
        ld (namep),hl
        call mk_fcb
        ld hl,s_binx
        ld de,fcb+9
        ld bc,3
        ldir
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_READ
.o:     call fcb_rec1
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        call segsz              ; DE = segment size
        ld h,d
        ld l,e
        ld de,fcb
        ld c,F_BRD
        call BDOS
        ld (tmpv),hl
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,FCBSV
        ld de,fcb
        ld bc,37
        ldir
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        ld hl,(tmpv)
        ld de,OUT0
        add hl,de
        ld (outp),hl
        ret

mf_advance:                     ; end of file: if the next one exists it moves to the following segment (NZ), otherwise Z
        ld a,(mfile)
        or a
        ret z
.next:  ld a,(mfcur)
        inc a
        ld b,a
        call mf_have
        jr z,.go
        xor a
        ret
.go:    ld a,(target)
        cp 3
        jp c,err_mode           ; only ASCII8, ASCII16, KONAMI, SCC
        ld a,b
        ld (mfcur),a
        ld a,(curseg)
        or a
        jr nz,.sw
        push bc                 ; leaving segment 0 the main flow ends
        ld hl,RT_END
        ld a,0C3h
        call emit_jabs
        pop bc
.sw:    push bc
        call seg_switch
        pop bc
        ld a,(mfkind)
        cp 2
        jr z,.bin
        xor a
        ld (mfbin),a
        ld a,b
        call mf_load
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        ld (tline),hl
        xor a
        ld (iseof),a
        call next_tok
        or 1
        ret
.bin:   ld a,1
        ld (mfbin),a
        ld a,b
        call mf_loadbin
        jr .next
        ENDIF

        ENDIF

mk_fcb:                         ; (namep) -> fcb (8.3 uppercase, optional drive "A:")
        ld hl,fcb
        ld de,fcb+1
        ld bc,36
        ld (hl),0
        ldir
        ld hl,fcb+1
        ld de,fcb+2
        ld bc,10
        ld (hl),' '
        ldir
        ld hl,(namep)
        ld a,(hl)
        or a
        ret z
        inc hl
        ld a,(hl)
        dec hl
        cp ':'
        jr nz,.nm
        ld a,(hl)
        and 1Fh
        ld (fcb),a
        inc hl
        inc hl
.nm:    ld de,fcb+1
        ld b,8
        call .field
        ld a,(hl)
        cp '.'
        ret nz
        inc hl
        ld de,fcb+9
        ld b,3
.field: ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        ld (de),a
        inc hl
        inc de
        djnz .field
.rest:  ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        inc hl
        jr .rest

fcb_rec1:
        ld hl,1
        ld (fcb+14),hl
        ld hl,0
        ld (fcb+33),hl
        ld (fcb+35),hl
        ret

read_source:
        ld hl,fname
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_READ
.o:     call fcb_rec1
        ld de,SRC
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,SRCMAX
        ld c,F_BRD
        call BDOS
        push af
        push hl
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        pop hl
        pop af
        ld de,0
        ld (tline),de
        or a
        jr nz,.ok
        ERR E_SRCBIG
.ok:    ld de,SRC
        add hl,de
        ld (hl),0
        ld hl,SRC
.z:     ld a,(hl)               ; ^Z: the rest of the file (leftover of a shorter in-place save) is ignored
        or a
        ret z
        cp 1Ah
        jr z,.cut
        inc hl
        jr .z
.cut:   ld (hl),0
        ret

        IFDEF ROMMODE
load_rt:                        ; RT.BIN -> OUT0 (runtime image); outp = end
        call rt_name_sel
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        call open_tool
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_RT
.o:     call fcb_rec1
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,3800h
        ld c,F_BRD
        call BDOS
        push hl
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        pop hl
        ld de,OUT0
        add hl,de
        ld (outp),hl
        ret
        ELSE
load_rt:                        ; .COM: size of RT.BIN (the file is copied whole in front of the code); the buffer starts empty
        call rt_name_sel
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        call open_tool
        or a
        jr z,.o
        ld hl,0
        ld (tline),hl
        ERR E_RT
.o:     call fcb_rec1
        ld de,PART              ; the size is a header word (RT_SIZE): the first block is enough
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,1024
        ld c,F_BRD
        call BDOS
        ld hl,(PART+RT_SIZE-IMGBASE)
        ld (rtsz),hl
        ld hl,PART+RT_STAMP-IMGBASE      ; build stamp: used to recognize an already-built NAME.COM
        ld de,RTSTAMP
        ld bc,RT_STAMPLEN
        ldir
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,OUT0
        ld (outp),hl
        ld hl,OUT0-IMGBASE      ; the code starts right after the runtime: virtual = physical - voff
        ld de,(rtsz)
        or a
        sbc hl,de
        ld (voff),hl
        ld hl,HDRB              ; header zeroed
        ld de,HDRB+1
        ld bc,HDRLEN-1
        ld (hl),0
        ldir
        ret
        ENDIF
rt_name_sel:                    ; -> HL = runtime name: with OPTION DEBUG the one with the debugger (RTD.BIN / RTROMD.BIN)
        IFDEF BINMODE
        ld hl,s_rtbin           ; BIN: a single runtime, without debugger
        ret
        ENDIF
        call chk_dbg
        ld hl,s_rtbin
        ret z
        ld hl,s_rtdbin
        ret
        IFDEF ROMMODE
s_rtbin: db "RTROM.BIN",0
s_rtdbin: db "RTROMD.BIN",0
        ELSE
        IFDEF BINMODE
s_rtbin: db "RTBIN.BIN",0
s_rtdbin: db "RTBIN.BIN",0
        ELSE
s_rtbin: db "RT.BIN",0
s_rtdbin: db "RTD.BIN",0
        ENDIF
        ENDIF

        IFNDEF ROMMODE
write_output:                   ; NAME.COM <- RT.BIN + code, with the runtime header corrected
        ld hl,fname
        ld de,oname
.c:     ld a,(hl)
        or a
        jr z,.x
        cp '.'
        jr z,.x
        ld (de),a
        inc hl
        inc de
        jr .c
.x:     IFDEF BINMODE
        ld hl,s_binext
        ELSE
        ld hl,s_com
        ENDIF
        ld bc,5
        ldir
        ld hl,oname
        ld (namep),hl
        call mk_fcb
        IFDEF BINMODE
        jr .new                 ; BIN: the file is always rewritten
        ENDIF
        ld de,fcb               ; does NAME.COM already exist with the same runtime? then only the code is rewritten
        ld c,F_OPEN
        call BDOS
        or a
        jr nz,.new
        call fcb_rec1
        ld de,RTCHK
        ld c,F_DMA
        call BDOS
        ld de,fcb
        ld hl,1024
        ld c,F_BRD
        call BDOS
        ld a,h
        cp 2
        jr c,.nomatch           ; file troppo corto
        ld hl,RTCHK+RT_STAMP-IMGBASE
        ld de,RTSTAMP
        ld b,RT_STAMPLEN
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.nomatch
        inc hl
        inc de
        djnz .cmp
        ld hl,fcb
        ld de,FCBSV
        ld bc,37
        ldir
        ld hl,(rtsz)            ; the code must be written after the runtime
        ld (FCBSV+33),hl
        xor a
        ld (FCBSV+35),a
        ld (FCBSV+36),a
        jp .cd
.nomatch:
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,oname
        ld (namep),hl
        call mk_fcb
.new:   ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr z,.m
.err:   ld hl,0
        ld (tline),hl
        ERR E_WRITE
.m:     call fcb_rec1
        ld hl,fcb               ; FCB of the output file -> FCBSV
        ld de,FCBSV
        ld bc,37
        ldir
        IFDEF BINMODE
        call bin_hdr            ; BLOAD header (7 bytes) in front of the image
        ENDIF
        call rt_name_sel        ; RT.BIN is opened in the main FCB
        ld (namep),hl
        call mk_fcb
        ld de,fcb
        call open_tool
        or a
        jr nz,.err
        call fcb_rec1
        ld de,PART              ; 4 KB copy buffer (the parameter table is no longer needed): few large blocks
        ld c,F_DMA
        call BDOS
.cp:    ld de,fcb
        ld hl,4096
        ld c,F_BRD
        call BDOS
        ld a,h
        or l
        jr z,.cd                ; no more data
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        jr .cp
.cd:    ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld de,OUT0              ; the generated code
        ld c,F_DMA
        call BDOS
        ld hl,(outp)
        ld de,-OUT0
        add hl,de
        ld a,h
        or l
        jr z,.hd
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        or a
        jr nz,.err
.hd:    ld de,HDRB              ; header: name, data size, DATA, target
        ld c,F_DMA
        call BDOS
        IFDEF BINMODE
        ld hl,RT_EMPTY-IMGBASE+7
        ELSE
        ld hl,RT_EMPTY-IMGBASE
        ENDIF
        ld (FCBSV+33),hl
        xor a
        ld (FCBSV+35),a
        ld hl,HDRLEN
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        or a
        jp nz,.err
        ld de,FCBSV
        ld c,F_CLOSE
        call BDOS
        ret
        ENDIF
        IFDEF BINMODE
s_binext: db ".BIN",0
msg_binw: db 13,10,"BIN written: $"
msg_bink: db 13,10,"Press any key...$"
bin_werr:
        ld hl,0
        ld (tline),hl
        ERR E_WRITE

bin_hdr:                        ; BLOAD: FEh, start, end, execution (7 bytes) -> output file (FCBSV)
        ld hl,RTCHK
        ld (hl),0FEh
        inc hl
        ld de,IMGBASE
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        ld hl,(outp)
        ld de,-OUT0
        add hl,de
        ld de,(rtsz)
        add hl,de
        ld de,IMGBASE-1
        add hl,de               ; end = start + runtime + code - 1
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,IMGBASE
        ld (hl),e
        inc hl
        ld (hl),d
        ld de,RTCHK
        ld c,F_DMA
        call BDOS
        ld hl,7
        ld de,FCBSV
        ld c,F_BWR
        call BDOS
        or a
        jr nz,bin_werr
        ret

bin_done:                       ; message, wait for a key and return to the editor
        ld de,msg_binw
        ld c,9
        call BDOS
        ld hl,oname
.p:     ld a,(hl)
        or a
        jr z,.pd
        push hl
        ld e,a
        ld c,2
        call BDOS
        pop hl
        inc hl
        jr .p
.pd:    ld de,msg_bink
        ld c,9
        call BDOS
        ld c,1
        call BDOS
        ld de,0081h
        ld a,' '
        ld (de),a
        inc de
        ld hl,fname
.n:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        jr .n
.e:     ld a,' '
        ld (de),a
        inc de
        ld a,'+'
        ld (de),a
        inc de
        ld a,0Dh
        ld (de),a
        inc de
        ld hl,0081h
        ex de,hl
        or a
        sbc hl,de
        ld a,l
        ld (0080h),a
        call cd_home
        ld hl,ldr_img
        ld de,LDR
        ld bc,ldr_size
        ldir
        jp LDR
        ENDIF
        IFDEF ROMMODE
rom_werr:
        ld hl,0
        ld (tline),hl
        ERR E_WRITE

build_oname:                    ; HL = extension (5 bytes): oname = NAME + extension, namep -> oname
        push hl
        ld hl,fname
        ld de,oname
.c:     ld a,(hl)
        or a
        jr z,.x
        cp '.'
        jr z,.x
        ld (de),a
        inc hl
        inc de
        jr .c
.x:     ld a,(mfile)
        or a
        jr z,.nm
        dec de
        dec de
        dec de
.nm:    pop hl
        ld bc,5
        ldir
        ld hl,oname
        ld (namep),hl
        ret

rom_create:                     ; NAME.ROM: creates the file (only once)
        ld hl,s_rom
        call build_oname
        call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        jr nz,rom_werr
        call fcb_rec1
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        ld a,1
        ld (romopen),a
        ret

        IFDEF ROMMODE
; ---------------------------------------------------------------- OPTION MAP: NAME.MAP for the debugger of the PC
; File: "SPBM" 1 <target>, then records: 'S' file seg addr line (a statement starts at addr), 'F' file seg name[12] entry line1 line2 end n locals[n*16]
; (a SUB/FUNCTION), 'G' n globals[n*16], 'E'. The ROM is the same as without the option.
map_open:                       ; creates NAME.MAP and writes the header
        ld hl,s_mapx
        call build_oname
        call mk_fcb
        ld de,fcb
        ld c,F_DEL
        call BDOS
        call mk_fcb
        ld de,fcb
        ld c,F_MAKE
        call BDOS
        or a
        ret nz                  ; cannot be created: no map
        ld hl,fcb
        ld de,FCBMAP
        ld bc,37
        ldir
        ld a,1                  ; record size: 1 byte
        ld (FCBMAP+14),a
        xor a
        ld (FCBMAP+15),a
        ld (MPFILL),a
        ld (MAPPOS),a
        ld (MAPPOS+1),a
        ld (MAPPOS+2),a
        inc a
        ld (mpf),a
        ld hl,s_maph
        ld b,5
.h:     ld a,(hl)
        call map_byte
        inc hl
        djnz .h
        ld a,(target)
        jr map_byte

map_byte:                       ; A -> map file (all registers are kept)
        push af
        push bc
        push de
        push hl
        ld b,a
        ld a,(MPFILL)
        ld e,a
        ld d,0
        ld hl,MAPBUF
        add hl,de
        ld (hl),b
        inc a
        ld (MPFILL),a
        cp 64
        call z,map_flush
        pop hl
        pop de
        pop bc
        pop af
        ret

map_word:                       ; HL -> map file
        ld a,l
        call map_byte
        ld a,h
        jr map_byte

map_flush:                      ; writes MAPBUF at the current position
        ld a,(MPFILL)
        or a
        ret z
        ld de,MAPBUF
        ld c,F_DMA
        call BDOS
        ld hl,(MAPPOS)
        ld (FCBMAP+33),hl
        ld a,(MAPPOS+2)
        ld (FCBMAP+35),a
        xor a
        ld (FCBMAP+36),a
        ld a,(MPFILL)
        ld l,a
        ld h,0
        push hl
        ld de,FCBMAP
        ld c,F_BWR
        call BDOS
        pop de
        ld hl,(MAPPOS)
        add hl,de
        ld (MAPPOS),hl
        jr nc,.nc
        ld hl,MAPPOS+2
        inc (hl)
.nc:    xor a
        ld (MPFILL),a
        ld de,OUT0              ; the DMA goes back to the ROM buffer
        ld c,F_DMA
        jp BDOS

map_stmt:                       ; a statement starts here (not inside inline assembler blocks)
        ld a,(mpf)
        or a
        ret z
        ld a,(ttype)
        cp T_P
        jr nz,.r
        ld a,(tval)
        cp '#'
        ret z
.r:     ld a,'S'
        call map_byte
        ld a,(mfcur)
        call map_byte
        ld a,(curseg)
        call map_byte
        call get_pc
        call map_word
        ld hl,(tline)
        jr map_word

map_func:                       ; end of a SUB/FUNCTION
        ld a,(mpf)
        or a
        ret z
        ld a,'F'
        call map_byte
        ld a,(mfcur)
        call map_byte
        ld a,(curseg)
        call map_byte
        ld hl,(fcur)
        ld b,12
.nm:    ld a,(hl)
        call map_byte
        inc hl
        djnz .nm
        ld hl,(fcur)
        ld de,17
        add hl,de
        ld a,(hl)
        call map_byte
        inc hl
        ld a,(hl)
        call map_byte
        ld hl,(dbgfs)
        call map_word
        ld hl,(lineno)
        call map_word
        call get_pc
        call map_word
        ld a,(nloc)
        call map_byte
        ld a,(nloc)
        or a
        ret z
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,LOCT
.lp:    ld a,(hl)
        call map_byte
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.lp
        ret

map_end:                        ; global variables, end mark, close
        ld a,(mpf)
        or a
        ret z
        ld a,'G'
        call map_byte
        ld a,(nvar)
        call map_byte
        ld a,(nvar)
        or a
        jr z,.e
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,VART
.lp:    ld a,(hl)
        call map_byte
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.lp
.e:     ld a,'E'
        call map_byte
        call map_flush
        ld de,FCBMAP
        ld c,F_CLOSE
        call BDOS
        xor a
        ld (mpf),a
        ret

s_mapx: db ".MAP",0
s_maph: db "SPBM",1
s_mapw: db "MAP",0
        ENDIF
segsz:                          ; -> DE = size of a switchable segment
        ld de,8192
        ld a,(target)
        cp 4
        ret nz
        ld de,16384
        ret

rom_flush:                      ; DE = segment size: writes the buffer and fills with zeros
        push de
        ld a,(romopen)
        or a
        call z,rom_create
        ld hl,(outp)
        ld de,-OUT0
        add hl,de
        push hl
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
        pop hl                  ; scritti
        pop de                  ; dimensione
        ex de,hl
        or a
        sbc hl,de               ; padding
        jp c,err_big
        ld a,h
        or l
        ret z
        ld (tmpv),hl
        ld hl,OUT0
        ld de,OUT0+1
        ld bc,16383
        ld (hl),0
        ldir
.z:     ld hl,(tmpv)
        ld a,h
        or l
        ret z
        ld de,16384
        or a
        sbc hl,de
        jr c,.last
        ld (tmpv),hl
        ld hl,16384
        jr .w
.last:  ld hl,(tmpv)
        ld de,0
        ld (tmpv),de
.w:     ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jr z,.z
        jp rom_werr

rom_finish:                     ; last segment, FARTAB and data size in the header, close
        call dbg_tables         ; OPTION DEBUG GLOBALS/ALL: variable table at the end of the last segment
        call map_end            ; OPTION MAP: globals and close of NAME.MAP
        ld a,(curseg)
        or a
        jr nz,.seg
        ld de,16384
        ld a,(target)
        cp 1
        jr z,.go
        ld de,32768
        jr .go
.seg:   call segsz
.go:    call rom_flush
        call dbg_patch          ; descriptor of the variable table
        ld a,(curseg)
        or a
        jr z,.close             ; a single segment: the header is already complete
        ld hl,7F00h-4000h       ; FARTAB is at 7F00h, i.e. at 3F00h in the file
        ld (fcb+33),hl
        xor a
        ld (fcb+35),a
        ld de,FARTABC
        ld c,F_DMA
        call BDOS
        ld hl,128
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
        ld hl,(dptr)
        ld de,-DATA_BASE
        add hl,de
        ld (tmpv),hl
        ld hl,RT_DSIZE-IMGBASE
        ld (fcb+33),hl
        xor a
        ld (fcb+35),a
        ld de,tmpv
        ld c,F_DMA
        call BDOS
        ld hl,2
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
.close: ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ret

dbg_bank:                       ; -> A = bank number of the current segment (0 = the fixed one)
        ld a,(curseg)
        or a
        ret z
        jp segbank

dbg_frec:                       ; ROM debugger: [prev w][prev bank][start line w][end line w][n][n 16-byte records] after a SUB/FUNCTION
        call get_pc
        push hl
        ld hl,(dbglast)
        call emit_w
        ld a,(dbglb)
        call emit_a
        ld hl,(dbgfs)
        call emit_w
        ld hl,(lineno)
        call emit_w
        ld a,(nloc)
        call emit_a
        ld a,(nloc)
        or a
        jr z,.dn
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,LOCT
.dl:    ld a,(hl)
        inc hl
        call emit_a
        dec bc
        ld a,b
        or c
        jr nz,.dl
.dn:    pop hl
        ld (dbglast),hl
        call dbg_bank
        ld (dbglb),a
        ret

dbg_tables:                     ; [n][n 16-byte VART records][last locals record w][its bank]
        ld a,(dbgf)
        or a
        ret z
        ld a,(dbgl)
        or a
        ret z
        ld a,(target)
        cp 3
        ret c                   ; only banked cartridges have the descriptor
        call dbg_bank
        ld (dbgd),a
        call get_pc
        ld (dbgd+1),hl
        ld a,(nvar)
        call emit_a
        ld a,(nvar)
        or a
        jr z,.nv
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,VART
.dt:    ld a,(hl)
        inc hl
        call emit_a
        dec bc
        ld a,b
        or c
        jr nz,.dt
.nv:    ld hl,(dbglast)
        call emit_w
        ld a,(dbglb)
        jp emit_a

dbg_patch:                      ; the descriptor goes to 7F80h of the fixed segment (file offset 3F80h)
        ld a,(dbgf)
        or a
        ret z
        ld a,(dbgl)
        or a
        ret z
        ld a,(target)
        cp 3
        ret c
        ld hl,DBGDESC-4000h
        ld (fcb+33),hl
        xor a
        ld (fcb+35),a
        ld (fcb+36),a
        ld de,dbgd
        ld c,F_DMA
        call BDOS
        ld hl,3
        ld de,fcb
        ld c,F_BWR
        call BDOS
        or a
        jp nz,rom_werr
        ret

rec_index:                      ; HL = record SUB/FUNCTION -> A = indice
        ld de,FUNT
        or a
        sbc hl,de
        ld de,FUNREC
        ld b,0
.l:     ld a,h
        or l
        jr z,.d
        or a
        sbc hl,de
        inc b
        jr .l
.d:     ld a,b
        ret

rec_far:                        ; HL = record -> A = FARTAB index if the routine is in another segment, otherwise FFh
        call rec_index
        ld e,a
        ld d,0
        ld hl,SEGT
        add hl,de
        ld a,(hl)
        or a
        jr z,.no
        ld b,a
        ld a,(curseg)
        cp b
        jr z,.no
        ld hl,FARX
        add hl,de
        ld a,(hl)
        ret
.no:    ld a,0FFh
        ret

rom_regfunc:                    ; new routine (index nfunc-1): pre-scan segment and FARTAB entry
        push hl
        push de
        ld a,(nfunc)
        dec a
        ld e,a
        ld d,0
        ld hl,SEGT
        add hl,de
        ld a,(pseg)
        ld (hl),a
        ld hl,FARX
        add hl,de
        ld (hl),0FFh
        ld a,(pseg)
        or a
        jr z,.d
        ld a,(nfar)
        cp 32
        jp nc,err_many
        ld (hl),a
        inc a
        ld (nfar),a
.d:     pop de
        pop hl
        ret

segbank:                        ; -> A = bank number of the current segment
        ld a,(curseg)
        ld b,a
        ld a,(target)
        cp 4
        ld a,b
        ret z
        inc a
        ret

rom_defsub:                     ; the routine (fcur) starts here: FARTAB entry (bank, address)
        ld a,(curseg)
        or a
        ret z
        ld hl,(fcur)
        call rec_index
        ld e,a
        ld d,0
        ld hl,FARX
        add hl,de
        ld a,(hl)
        cp 0FFh
        ret z
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,FARTABC
        add hl,de
        push hl
        call segbank
        pop hl
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        push hl
        call get_pc
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

err_many:
        ERR E_MANY

st_segment:                     ; SEGMENT n: from here the code goes into segment n (n = previous segment + 1)
        ld a,(target)
        cp 3
        jp c,err_syntax         ; only ASCII8, ASCII16, KONAMI, SCC
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld a,(curseg)
        inc a
        cp l
        jp nz,err_syntax
        ld a,h
        or a
        jp nz,err_syntax
        ld a,(mfile)
        or a
        jp nz,err_mode          ; with NAMEnnn files the segment is decided by the file name
        call seg_switch
        jp next_tok

seg_switch:                     ; closes the current segment (checks, write) and opens the next
        ld a,(fcur)
        ld hl,(fcur)
        ld a,h
        or l
        jp nz,err_syntax        ; not inside a SUB/FUNCTION
        ld a,(nblk)
        or a
        jp nz,err_syntax
        ld a,(nlab)             ; unresolved forward jumps cannot cross segments
        or a
        jr z,.nl
        ld b,a
        ld hl,LABT
.pl:    push hl
        ld de,14
        add hl,de
        ld a,(hl)
        or a
        jr nz,.ok
        inc hl
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.ok
        pop hl
        jp err_label
.ok:    pop hl
        ld de,LABREC
        add hl,de
        djnz .pl
.nl:    ld a,(curseg)
        or a
        ld de,16384
        jr z,.fl
        call segsz
.fl:    call rom_flush
        ld hl,OUT0
        ld (outp),hl
        ld hl,0
        ld (voff),hl            ; the switchable segment is at 8000h: physical = virtual
        ld a,(target)
        cp 4
        ld a,0BFh
        jr z,.l
        ld a,0A0h
.l:     ld (outlim),a
        ld a,(curseg)
        inc a
        ld (curseg),a
        ret
        ENDIF

        IFNDEF ROMMODE
st_segment:
        jp err_syntax
        ENDIF

st_setbank:                     ; SETBANK n: segment n appears in the data window (DATAWIN)
        call expr
        call want_int
        EM3 0CDh,low RT_SETBANK,high RT_SETBANK
        ret

st_vcopy:                       ; VCOPY memory, vram, count
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        EM3 0CDh,low RT_VCOPY,high RT_VCOPY
        ret

bi_mapsegs:                     ; MAPPERSEGS: 16 KB segments of the RAM mapper (0 = none)
        call next_tok
        EM3 0CDh,low RT_MAPSEGS,high RT_MAPSEGS
        xor a
        ld (etype),a
        ret

bi_malloc:                      ; MALLOC: free mapper segment
        call next_tok
        EM3 0CDh,low RT_MALLOC,high RT_MALLOC
        xor a
        ld (etype),a
        ret

st_mfree:                       ; MFREE segment
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        EM3 0CDh,low RT_MFREE,high RT_MFREE
        ret

bi_mget:                        ; MGET(segment, offset)
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        call close_paren
        EM3 0CDh,low RT_MGET,high RT_MGET
        xor a
        ld (etype),a
        ret

st_mput:                        ; MPUT segment, offset, value
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        EM3 0CDh,low RT_MPUT,high RT_MPUT
        ret

st_mread:                       ; MREAD segment, offset, address, count  (mapper -> memory)
        ld hl,RT_MREAD
        jr mblock
st_mwrite:                      ; MWRITE segment, offset, address, count (memory -> mapper)
        ld hl,RT_MWRITE
mblock: push hl
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY2
        call emit_st
        pop hl
        ld a,0CDh
        jp emit_jabs

bi_varptr:                      ; VARPTR(variable) or VARPTR(array(i)): address in memory
        call next_tok
        call open_paren
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call resolve_var
        cp 2
        jr nc,.loc
        push hl
        ld a,21h                ; global: ld hl,address
        call emit_a
        pop hl
        call emit_w
        jr .nx
.loc:   push hl                 ; local: push ix ; pop hl ; ld de,offset ; add hl,de
        EM3 0DDh,0E5h,0E1h
        ld a,11h
        call emit_a
        pop hl
        call emit_w
        EM1 19h
.nx:    call next_tok
        jr .end
.arr:   call restore_lex
        call arr_elem
.end:   call close_paren
        xor a
        ld (etype),a
        ret

arr_is_mapper:                  ; tbuf = array: NZ if it is in mapper RAM
        call find_arrparam
        jr nc,.no
        call find_rec
        jr c,.no
        ld de,15
        add hl,de
        ld a,(hl)
        and 80h
        ret
.no:    xor a
        ret

mapper_desc:                    ; tbuf = array in mapper -> DE = descriptor address
        call find_rec
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

mapper_read:                    ; x(i): ld de,descriptor ; call RT_MAGET (HL = index -> value)
        call mapper_desc
        push de
        call next_tok
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        pop hl
        ld a,11h
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_MAGET,high RT_MAGET
        xor a
        ld (etype),a
        ret

mapper_assign:                  ; x(i) = v: push indice ; v ; pop de ; ld bc,descrittore ; call RT_MAPUT
        call mapper_desc
        push de
        call next_tok
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        EM1 0E5h
        ld a,'='
        call expect_p
        call expr
        call want_int
        EM1 0D1h
        pop hl
        ld a,1
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_MAPUT,high RT_MAPUT
        ret

st_bload:                       ; BLOAD name$ [, S] [, offset]
        call expr
        call want_str
        EM1 0E5h
        call emit_i             ; GX1 = 0, GY1 = 0
        db 9,21h,0,0,22h,low GX1,high GX1,22h,low GY1,high GY1
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld hl,tbuf
        ld de,s_sw
        ld a,(ttype)
        cp T_ID
        jr nz,.off
        call str_eq
        jr nz,.off
        call emit_i             ; GY1 = 1
        db 6,21h,1,0,22h,low GY1,high GY1
        call next_tok
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
.off:   call expr
        call want_int
        ld hl,GX1
        call emit_st
.go:    EM1 0E1h
        EM3 0CDh,low RT_BLOAD,high RT_BLOAD
        ret

st_bsave:                       ; BSAVE name$, start, length [, S]
        call expr
        call want_str
        EM1 0E5h
        call emit_i             ; GX2 = 0
        db 6,21h,0,0,22h,low GX2,high GX2
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_sw
        call str_eq
        jp nz,err_syntax
        call emit_i
        db 6,21h,1,0,22h,low GX2,high GX2
        call next_tok
.go:    EM1 0E1h
        EM3 0CDh,low RT_BSAVE,high RT_BSAVE
        ret

st_fget:
        ld hl,RT_FGET
        jr fio
st_fput:
        ld hl,RT_FPUT
fio:    push hl
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call emit_i             ; record = 0 (the next one)
        db 6,21h,0,0,22h,low GY1,high GY1
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        call expr
        call want_int
        ld hl,GY1
        call emit_st
.go:    pop hl
        ld a,0CDh
        jp emit_jabs

st_field:                       ; FIELD [#]n, larghezza AS variabile$ [, larghezza AS variabile$ ...]
        ld a,'#'
        call is_p
        jr nz,.n
        call next_tok
.n:     call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,1
        ld (mapf),a             ; first field: clears the table
.l:     ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_as
        call str_eq
        jp nz,err_syntax
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        cp 1
        jp nz,err_type          ; global string variables only
        push hl
        ld a,21h                ; ld hl,first ; ld (GX2),hl
        call emit_a
        ld a,(mapf)
        ld l,a
        ld h,0
        call emit_w
        ld hl,GX2
        call emit_st
        xor a
        ld (mapf),a
        pop hl
        push hl
        ld a,21h                ; ld hl,variabile ; call RT_FIELD
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_FIELD,high RT_FIELD
        call next_tok
        ld a,','
        call is_p
        jr z,.l
        ret

st_lset:                        ; LSET v$ = expression: like an assignment (PUT pads with spaces)
        jp st_let

st_rset:                        ; RSET v$ = expression: right-aligned in the field width
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        cp 1
        jp nz,err_type
        push hl
        call next_tok
        ld a,'='
        call expect_p
        call expr
        call want_str
        pop hl
        ld a,11h                ; ld de,variabile ; call RT_RSET
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_RSET,high RT_RSET
        ret

bi_lof:                         ; LOF(n)
        call bi_arg_int
        EM3 0CDh,low RT_FLOF,high RT_FLOF
        ret

bi_mki:                         ; MKI$(n): integer in 2 bytes
        ld hl,RT_MKI
        ld c,1
        jp bi1i

bi_cvi:                         ; CVI(s$)
        ld hl,RT_CVI
        jp bi1s

bi_datawin:                     ; DATAWIN: address of the data window
        call next_tok
        EM3 0CDh,low RT_DATAWIN,high RT_DATAWIN
        xor a
        ld (etype),a
        ret

        IFDEF ROMMODE
st_incbin:                      ; INCBIN "file": the file's bytes go into the current segment
        ld a,(ttype)
        cp T_STR
        jp nz,err_syntax
        ld a,(tlen)
        cp 13
        jp nc,err_syntax
        ld c,a
        ld b,0
        ld hl,(tval)
        ld de,nbuf
        or a
        jr z,.e
        ldir
.e:     xor a
        ld (de),a
        ld hl,nbuf
        ld (namep),hl
        ld hl,fcb               ; the output file's FCB is saved
        ld de,FCBSV
        ld bc,37
        ldir
        call mk_fcb
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        jr z,.o
        ERR E_READ
.o:     call fcb_rec1
        ld de,(outp)
        ld c,F_DMA
        call BDOS
        ld a,(outlim)
        ld h,a
        ld l,0
        ld de,(outp)
        or a
        sbc hl,de
        push hl
        ld de,fcb
        ld c,F_BRD
        call BDOS
        ld (tmpv),hl
        pop de
        or a
        sbc hl,de
        push af
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        ld hl,FCBSV
        ld de,fcb
        ld bc,37
        ldir
        ld de,OUT0
        ld c,F_DMA
        call BDOS
        pop af
        jp z,err_big            ; fills all the space: too large
        ld hl,(outp)
        ld de,(tmpv)
        add hl,de
        ld (outp),hl
        jp next_tok
        ENDIF
        IFNDEF ROMMODE
st_incbin:
        jp err_syntax
        ENDIF

s_com:  db ".COM",0

; ---------------------------------------------------------------- emissione
emit_a:                         ; A -> output (clobbers only A)
        push hl
        ld hl,(outp)
        ld (hl),a
        inc hl
        ld (outp),hl
        ld a,h
        ld hl,outlim
        cp (hl)
        jp nc,err_big
        pop hl
        ret
err_big:
        ERR E_BIG

emit_w:                         ; HL -> output (little endian)
        push af
        ld a,l
        call emit_a
        ld a,h
        call emit_a
        pop af
        ret

emit_i:                         ; inline bytes: db n, b1..bn  (after the call)
        ex (sp),hl
        push bc
        ld b,(hl)
        inc hl
.l:     ld a,(hl)
        inc hl
        call emit_a
        djnz .l
        pop bc
        ex (sp),hl
        ret

get_pc:                         ; HL = current virtual address (clobbers DE)
        ld hl,(outp)
        ld de,(voff)
        or a
        sbc hl,de
        ret

emit_jchain:                    ; A = opcode, HL = &head: jp with operand = fixup chain
        push hl
        call emit_a
        pop hl
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call get_pc
        ex de,hl
        pop hl
        call emit_w
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

emit_jabs:                      ; A = opcode, HL = address
        push hl
        call emit_a
        pop hl
        jp emit_w

patch_chain:                    ; HL = &head: all the jumps in the chain point to the current pc
        ld e,(hl)
        inc hl
        ld d,(hl)
        xor a
        ld (hl),a
        dec hl
        ld (hl),a
        push de
        call get_pc
        ex de,hl
        pop hl
.l:     ld a,h
        or l
        ret z
        ld bc,(voff)
        add hl,bc
        ld c,(hl)
        ld (hl),e
        inc hl
        ld b,(hl)
        ld (hl),d
        ld h,b
        ld l,c
        jr .l

; ---------------------------------------------------------------- lexer
save_lex:
        ld hl,lp
        ld de,lexsv
        ld bc,LEXSZ
        ldir
        ret
restore_lex:
        ld hl,lexsv
        ld de,lp
        ld bc,LEXSZ
        ldir
        ret

next_tok:
        ld hl,(lp)
.ws:    ld a,(hl)
        cp ' '
        jr z,.sk
        cp 9
        jr z,.sk
        cp 0Dh
        jr nz,.go
.sk:    inc hl
        jr .ws
.go:    ld de,(lineno)
        ld (tline),de
        xor a
        ld (tsuf),a
        ld a,(hl)
        or a
        jr z,.eof
        cp 1Ah
        jr z,.eof
        cp 0Ah
        jr z,.eol
        cp 27h                  ; '
        jr z,.cmt
        cp '"'
        jp z,.str
        cp '&'
        jp z,.amp
        cp '0'
        jr c,.nd
        cp '9'+1
        jp c,.num
.nd:    cp '_'
        jp z,.id
        or 20h
        cp 'a'
        jr c,.pu
        cp 'z'+1
        jp c,.id
.pu:    ld a,(hl)
        jp .punct
.eof:   ld (lp),hl
        ld a,1
        ld (iseof),a
        xor a
        ld (ttype),a
        ret
.eol:   inc hl
        ld (lp),hl
        ld hl,(lineno)
        inc hl
        ld (lineno),hl
        xor a
        ld (ttype),a
        ret
.cmt:   inc hl
        ld a,(hl)
        cp 0Ah
        jr z,.go
        or a
        jr z,.go
        cp 1Ah
        jr nz,.cmt
        jr .go

.num:   ld de,0
.nl:    ld a,(hl)
        sub '0'
        cp 10
        jr nc,.ne
        push hl
        ld h,d
        ld l,e
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        pop hl
        inc hl
        jr .nl
.ne:    ld (tval),de
        ld (lp),hl
        ld a,T_NUM
        ld (ttype),a
        ret

.amp:   inc hl
        ld a,(hl)
        or 20h
        cp 'h'
        jr z,.hex
        cp 'b'
        jr z,.bin
        ERR E_CHAR
.hex:   inc hl
        ld de,0
        ld c,0                  ; cifre lette
.hl:    ld a,(hl)
        sub '0'
        cp 10
        jr c,.hd
        ld a,(hl)
        or 20h
        sub 'a'-10
        cp 10
        jr c,.he
        cp 16
        jr nc,.he
.hd:    ld b,a
        push hl
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        inc c
        jr .hl
.he:    ld a,c
        or a
        jr nz,.ne
        ERR E_CHAR
.bin:   inc hl
        ld de,0
        ld c,0
.bl:    ld a,(hl)
        sub '0'
        cp 2
        jr nc,.he
        ld b,a
        push hl
        ex de,hl
        add hl,hl
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        inc c
        jr .bl

.str:   inc hl
        ld (tval),hl
        ld c,0
.sl:    ld a,(hl)
        cp '"'
        jr z,.se
        or a
        jr z,.su
        cp 0Ah
        jr z,.su
        inc hl
        inc c
        jr nz,.sl
.su:    ERR E_CHAR
.se:    inc hl
        ld a,c
        ld (tlen),a
        ld (lp),hl
        ld a,T_STR
        ld (ttype),a
        ret

.id:    ld de,tbuf
        push hl
        ld hl,tbuf
        ld b,16
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        pop hl
        ld b,14
.il:    ld a,(hl)
        cp '_'
        jr z,.ic
        cp '0'
        jr c,.ie
        cp '9'+1
        jr c,.ic
        or 20h
        cp 'a'
        jr c,.ie
        cp 'z'+1
        jr nc,.ie
.ic:    ld a,(hl)
        cp 'a'
        jr c,.up
        cp 'z'+1
        jr nc,.up
        sub 20h
.up:    inc hl
        ld c,a
        ld a,b
        or a
        jr z,.il
        dec b
        ld a,c
        ld (de),a
        inc de
        jr .il
.ie:    ld a,(hl)
        cp '$'
        jr z,.sf
        cp '%'
        jr nz,.fin
        inc hl                  ; A% = A: the integer suffix is ignored
        jr .fin
.sf:    inc hl
        ld a,1
        ld (tsuf),a
        ld a,'$'
        ld (tbuf+11),a          ; A$ and A remain distinct names even for long names
.fin:   ld (lp),hl
        ld a,(tsuf)
        or a
        jr nz,.var
        ld hl,tbuf              ; REM = comment
        ld de,s_rem
        ld b,4
.rc:    ld a,(de)
        cp (hl)
        jr nz,.nrem
        inc hl
        inc de
        djnz .rc
        ld hl,(lp)
        jp .cmt
.nrem:  ld hl,kwtab
        ld de,tbuf
        call find_in
        jr c,.var
        ld (tval),a
        ld a,T_KW
        ld (ttype),a
        ret
.var:   ld a,T_ID
        ld (ttype),a
        ret

.punct: ld c,a
        inc hl
        cp '<'
        jr nz,.q1
        ld a,(hl)
        cp '>'
        jr z,.t1
        cp '='
        jr z,.t2
        jr .single
.q1:    cp '>'
        jr nz,.q2
        ld a,(hl)
        cp '='
        jr z,.t3
        jr .single
.q2:    cp '='
        jr nz,.single
        ld a,(hl)
        cp '<'
        jr z,.t2
        cp '>'
        jr z,.t3
.single:
        ld a,c
        push hl
        ld hl,puncts
        ld b,15
.pl:    cp (hl)
        jr z,.pv
        inc hl
        djnz .pl
        ERR E_CHAR
.pv:    pop hl
        jr .pfin
.t1:    ld c,1
        jr .t
.t2:    ld c,2
        jr .t
.t3:    ld c,3
.t:     inc hl
.pfin:  ld (lp),hl
        ld a,c
        ld (tval),a
        ld a,T_P
        ld (ttype),a
        ret
puncts: db "()+-*/",5Ch,"=<>,;:?#"
s_rem:  db "REM",0

find_in:                        ; HL = table of 0-terminated strings (end: byte 0), DE = name -> A = index, C if missing
        ld (fi_s),de
        ld c,0
.next:  ld a,(hl)
        or a
        jr z,.nf
        ld de,(fi_s)
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.skip
        or a
        jr z,.hit
        inc hl
        inc de
        jr .cmp
.skip:  ld a,(hl)
        inc hl
        or a
        jr nz,.skip
        inc c
        jr .next
.hit:   ld a,c
        or a
        ret
.nf:    scf
        ret

kwtab:  db "PRINT",0,"IF",0,"THEN",0,"ELSE",0,"ELSEIF",0,"END",0,"FOR",0,"TO",0
        db "STEP",0,"NEXT",0,"WHILE",0,"WEND",0,"GOTO",0,"GOSUB",0,"RETURN",0
        db "CLS",0,"LOCATE",0,"AND",0,"OR",0,"XOR",0,"NOT",0,"MOD",0,"LET",0
        db "OPTION",0,"INPUT",0,"DIM",0,"POKE",0,"SUB",0,"FUNCTION",0,"CALL",0,"DECLARE",0,"SHARED",0
        db "EXIT",0,"DO",0,"LOOP",0,"UNTIL",0,"SELECT",0,"CASE",0,"IS",0,"CONST",0,"COLOR",0,"RANDOMIZE",0,"VPOKE",0,"OUT",0,"SLEEP",0,"STOP",0,"SCREEN",0,"PSET",0,"PRESET",0,"LINE",0,"CIRCLE",0
        db "PALETTE",0,"PAINT",0,"PUT",0,"SPRITE",0,"GET",0,"DRAW",0,"VIEW",0,"WINDOW",0,"VBANK",0,"VFILL",0,"VWRITE",0,"SET",0,"COPY",0,"DATA",0,"READ",0,"RESTORE",0,"BEEP",0,"SOUND",0,"PLAY",0
        db "OPEN",0,"CLOSE",0,"KILL",0,"WRITE",0,"SEGMENT",0,"INCBIN",0
        db "SETBANK",0,"VCOPY",0,"MPUT",0,"MREAD",0,"MWRITE",0,"MFREE",0,"BLOAD",0,"BSAVE",0,"FIELD",0,"LSET",0,"RSET",0,0

; ---------------------------------------------------------------- parser helpers
is_p:                           ; A = character: Z if the token is that punctuation
        ld b,a
        ld a,(ttype)
        cp T_P
        ret nz
        ld a,(tval)
        cp b
        ret
is_kw:                          ; A = index: Z if the token is that keyword
        ld b,a
        ld a,(ttype)
        cp T_KW
        ret nz
        ld a,(tval)
        cp b
        ret
expect_p:
        call is_p
        jp nz,err_syntax
        jp next_tok
expect_kw:
        call is_kw
        jp nz,err_syntax
        jp next_tok
err_syntax:
        ERR E_SYNTAX
err_unsup:
        ERR E_UNSUP

at_send:                        ; Z if the token ends the statement (end of line, ':' or ELSE)
        ld a,(ttype)
        cp T_EOL
        ret z
        cp T_P
        jr z,.p
        cp T_KW
        jr z,.k
        or 1
        ret
.p:     ld a,(tval)
        cp ':'
        ret
.k:     ld a,(tval)
        cp K_ELSE
        ret

; ---------------------------------------------------------------- tabelle
name_eq:                        ; HL = record: Z if the first 12 bytes match tbuf
        push hl
        push bc
        ld de,tbuf
        ld b,12
.l:     ld a,(de)
        cp (hl)
        jr nz,.x
        inc hl
        inc de
        djnz .l
.x:     pop bc
        pop hl
        ret

find_label:                     ; tbuf -> HL = record (creates it)
        ld a,(nlab)
        ld b,a
        ld hl,LABT
        or a
        jr z,.new
.l:     call name_eq
        ret z
        ld de,LABREC
        add hl,de
        djnz .l
.new:   ld a,(nlab)
        cp MAXLAB
        jr c,.ok
        ERR E_MANY
.ok:    inc a
        ld (nlab),a
        push hl
        ex de,hl
        ld hl,tbuf
        ld bc,12
        ldir
        ex de,hl
        ld b,LABREC-12
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        pop hl
        ld de,(tline)
        push hl
        ld bc,17
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ret

define_label:                   ; tbuf = name: defines the label at the current pc
        call find_label
        push hl
        ld de,14
        add hl,de
        ld a,(hl)
        or a
        jr z,.ok
        ERR E_DUP
.ok:    ld (hl),1
        push hl
        ld de,5                 ; +19: label segment
        add hl,de
        ld a,(curseg)
        ld (hl),a
        pop hl
        pop hl
        push hl
        call get_pc
        ex de,hl
        pop hl
        push hl
        ld bc,12
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ld de,15
        add hl,de
        jp patch_chain

label_jump:                     ; A = opcode (C3 jp / CD call), tbuf = name
        push af
        call find_label
        ld de,14
        add hl,de
        ld a,(hl)
        or a
        jr nz,.def
        inc hl                  ; undefined: fixup chain in the head (rec+15)
        pop af
        jp emit_jchain
.def:   push hl
        ld de,5
        add hl,de
        ld a,(curseg)
        cp (hl)
        pop hl
        jp nz,err_label         ; label in another segment
        dec hl
        dec hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop af
        jp emit_jabs

num_to_name:                    ; tval = line number -> tbuf = decimal digits
        ld hl,tbuf
        ld b,16
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        ld hl,(tval)
        ld de,tbuf
        jp dec_str

find_rec:                       ; tbuf -> HL = record, NC if found; C if missing (HL = free slot)
        ld a,(tsuf)
        ld (vtyp),a
        ld a,(nvar)
        ld b,a
        ld hl,VART
        or a
        jr z,.nf
.l:     call name_eq
        jr z,.f
        ld de,VARREC
        add hl,de
        djnz .l
.nf:    scf
        ret
.f:     or a
        ret

alloc_data:                     ; BC = bytes -> HL = address (program data area)
        ld hl,(dptr)
        push hl
        add hl,bc
        jp c,err_mem
        ld de,(dlim)
        push hl
        or a
        sbc hl,de
        pop hl
        jp nc,err_mem
        ld (dptr),hl
        pop hl
        ret
err_mem:
        ERR E_MEM

new_rec:                        ; HL = place, BC = bytes, DE = number of elements (0 = scalar) -> HL = data address
        ld (tmps),de
        ld a,(nvar)
        cp MAXVAR
        jr c,.ok
        ERR E_MANY
.ok:    inc a
        ld (nvar),a
        push hl
        ex de,hl
        ld hl,tbuf
        push bc
        ld bc,12
        ldir
        pop bc
        push de
        call alloc_data
        pop de
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld bc,(tmps)
        ld (hl),c
        inc hl
        ld (hl),b
        pop hl
        ex de,hl
        ret

kind_type:                      ; A = reference type (emit_ldv) -> A = 0 integer, 1 string
        cp 1
        jr z,.s
        cp 3
        jr z,.s
        cp 4
        jr z,.s
        xor a
        ret
.s:     ld a,1
        ret

resolve_var:                    ; tbuf -> A = reference type, HL = address or offset from IX
        ld a,(tsuf)
        ld (vtyp),a
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.glob
        ld a,(nloc)
        ld hl,LOCT
        or a
        jr z,.new
        ld b,a
.l:     call name_eq
        jr z,.f
        ld de,16
        add hl,de
        djnz .l
        jr .new
.f:     ld de,12
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        cp 2
        jr z,.glob              ; SHARED
        or a
        jr z,.m2
        cp 1
        jr z,.m3
        cp 3
        jr z,.m2
        cp 4
        jp nz,err_type          ; array parameter used as a scalar
        ld a,4                  ; parametro stringa
        ret
.m2:    ld a,2
        ret
.m3:    ld a,3
        ret
.glob:  call find_var
        ld a,(vtyp)
        ret
.new:   ld a,(vtyp)             ; nuova variabile locale
        or a
        jr nz,.ns
        ld a,(nint)
        inc a
        cp 30
        jr c,.ni
        ERR E_MANY
.ni:    ld (nint),a
        inc a
        add a,a
        ld e,a
        ld d,0
        ld hl,0
        or a
        sbc hl,de               ; offset = -2*(n+1)
        ex de,hl
        xor a                   ; local type: integer
        push af
        jr .add
.ns:    ld a,(nstr)
        inc a
        ld (nstr),a
        ld h,a                  ; offset = -(64 + 256*n)
        ld l,0
        ld de,64
        add hl,de
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
        ld a,1
        push af
.add:   pop af
        push af
        push de
        call loct_add
        pop hl
        pop af
        or a
        ld a,2
        ret z
        ld a,3
        ret

loct_add:                       ; tbuf = name, A = type (0 int, 1 str, 2 shared, 3 int par., 4 str par.), DE = offset
        push af
        push de
        ld a,(nloc)
        cp MAXLOC
        jr c,.ok
        ERR E_MANY
.ok:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,LOCT
        add hl,de
        ld a,(nloc)
        inc a
        ld (nloc),a
        ex de,hl
        ld hl,tbuf
        ld bc,12
        ldir
        pop bc
        pop af
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        ret

emit_ldv:                       ; A = reference type, HL = address/offset: HL (program) = value or pointer
        or a
        jr nz,.k1
        ld a,2Ah                ; globale intero: ld hl,(nn)
        jr .abs
.k1:    dec a
        jr nz,.k2
        ld a,21h                ; globale stringa: ld hl,nn
.abs:   push hl
        call emit_a
        pop hl
        jp emit_w
.k2:    dec a
        jr z,.ix
        dec a
        jr z,.lstr
.ix:    ld c,l                  ; local integer or parameter (also string): ld l,(ix+d) ; ld h,(ix+d+1)
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        inc a
        jp emit_a
.lstr:  push hl                 ; local string buffer: push ix ; pop hl ; ld de,d ; add hl,de
        EM3 0DDh,0E5h,0E1h
        ld a,11h
        call emit_a
        pop hl
        call emit_w
        EM1 19h
        ret

emit_stv:                       ; A = reference type, HL = address/offset: stores the value in HL (program)
        or a
        jr nz,.n1
        ld a,22h                ; globale intero: ld (nn),hl
        push hl
        call emit_a
        pop hl
        jp emit_w
.n1:    dec a
        jr nz,.n2
        ld a,11h                ; globale stringa: ld de,buffer ; call rt_scopy
        push hl
        call emit_a
        pop hl
        call emit_w
        EM3 0CDh,low RT_SCOPY,high RT_SCOPY
        ret
.n2:    dec a
        jr nz,.n3
        ld c,l                  ; intero locale: ld (ix+d),l ; ld (ix+d+1),h
        ld a,0DDh
        call emit_a
        ld a,75h
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,74h
        call emit_a
        ld a,c
        inc a
        jp emit_a
.n3:    dec a
        jp nz,err_type          ; string parameter: not assignable
        push hl                 ; stringa locale: push hl ; (ix+d) -> HL ; ex de,hl ; pop hl ; call rt_scopy
        EM1 0E5h
        EM3 0DDh,0E5h,0E1h
        ld a,11h
        call emit_a
        pop hl
        call emit_w
        EM1 19h
        EM2 0EBh,0E1h
        EM3 0CDh,low RT_SCOPY,high RT_SCOPY
        ret

find_var:                       ; scalar variable (tbuf) -> HL = address; vtyp = type
        call find_rec
        jr c,.new
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,b
        or c
        jp nz,err_type          ; it is an array used without an index
        ex de,hl
        ret
.new:   ld a,(vtyp)
        ld bc,2
        or a
        jr z,.s
        ld bc,256
.s:     ld de,0
        jp new_rec

arr_elem:                       ; tbuf = array, token = name: emits the element address calculation in HL
        call find_arrparam
        jr c,.glob
        ld a,(tsuf)             ; array parameter: number of elements at (ix+d), base at (ix+d+2)
        push hl
        push af
        call next_tok
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        pop af
        ld (etype),a
        pop hl
        ld c,l
        ld a,0DDh               ; ld e,(ix+d) ; ld d,(ix+d+1) ; call rt_chk
        call emit_a
        ld a,5Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,56h
        call emit_a
        ld a,c
        inc a
        call emit_a
        EM3 0CDh,low RT_CHK,high RT_CHK
        ld a,(etype)
        or a
        jr nz,.pstr
        EM1 29h
        jr .pbase
.pstr:  EM3 65h,2Eh,0
.pbase: ld a,0DDh               ; ld e,(ix+d+2) ; ld d,(ix+d+3) ; add hl,de
        call emit_a
        ld a,5Eh
        call emit_a
        ld a,c
        add a,2
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,56h
        call emit_a
        ld a,c
        add a,3
        call emit_a
        EM1 19h
        ret
.glob:  call find_rec
        jp c,err_type           ; undeclared array
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        bit 7,b
        jp nz,err_type          ; array in the mapper: only x(i) for reading/assignment
        ld a,b
        or c
        jp z,err_type
        push de                 ; base
        push bc                 ; number of elements
        ld a,(vtyp)
        push af
        call next_tok           ; name
        ld a,'('
        call expect_p
        call expr
        call want_int
        ld a,')'
        call expect_p
        pop af
        ld (etype),a            ; element type
        pop bc
        pop de
        push de                 ; base
        ld a,11h                ; ld de,number
        call emit_a
        ld h,b
        ld l,c
        call emit_w
        EM3 0CDh,low RT_CHK,high RT_CHK
        ld a,(etype)
        or a
        jr nz,.str
        EM1 29h                 ; add hl,hl
        jr .base
.str:   EM3 65h,2Eh,0           ; ld h,l ; ld l,0   (indice * 256)
.base:  ld a,11h                ; ld de,base
        call emit_a
        pop hl
        call emit_w
        EM1 19h                 ; add hl,de
        ret

push_blk:                       ; A = type -> HL = record (fields zeroed)
        ld c,a
        ld a,(nblk)
        cp MAXBLK
        jr c,.ok
        ERR E_MANY
.ok:    inc a
        ld (nblk),a
        call blk_top
        ld (hl),c
        push hl
        inc hl
        ld b,BLKREC-1
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        pop hl
        ret

blk_top:                        ; HL = record in cima (nblk >= 1)
        ld a,(nblk)
        dec a
blk_addr:                       ; A = indice -> HL = record
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl               ; *8
        add hl,de
        add hl,de               ; *10
        ld de,BLKS
        add hl,de
        ret

find_blk:                       ; C = type -> HL = innermost block record of that type
        ld a,(nblk)
.l:     or a
        jr z,.bad
        dec a
        push af
        call blk_addr
        ld a,(hl)
        cp c
        jr z,.f
        pop af
        jr .l
.f:     pop af
        ret
.bad:   ERR E_MISM

need_blk:                       ; A = required type -> HL = record on top, otherwise error
        ld c,a
        ld a,(nblk)
        or a
        jr z,.bad
        call blk_top
        ld a,(hl)
        cp c
        ret z
.bad:   ERR E_MISM

; ---------------------------------------------------------------- compilation
compile:
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        ld (tline),hl
        xor a
        ld (iseof),a
        ld (nlab),a
        ld (nvar),a
        ld (nblk),a
        ld (onel),a
        ld (mode),a
        ld (tmpf),a
        ld (etype),a
        ld (usewin),a
        ld (dbgf),a
        ld (brkf),a
        ld (dbglast),a
        ld (dbglast+1),a
        ld (dbglb),a
        ld (dbgl),a
        ld (target),a
        ld (curseg),a
        ld (pseg),a
        ld (nfar),a
        ld (romopen),a
        IFDEF ROMMODE
        xor a
        ld (mpf),a              ; OPTION MAP off (ST may hold leftovers of the DOS compiler)
        ld hl,FARTABC
        ld de,FARTABC+1
        ld bc,127
        ld (hl),0
        ldir
        ld hl,SEGT              ; SEGT, FARX and FCBSV (where the chain loader was)
        ld de,SEGT+1
        ld bc,76
        ld (hl),0
        ldir
        ENDIF
        ld hl,OUT0-IMGBASE
        ld (voff),hl
        ld a,OUTLIM
        ld (outlim),a
        xor a
        ld h,a
        ld l,a
        ld (dlast),hl
        ld hl,DATA_BASE
        ld (dptr),hl
        IFDEF ROMMODE
        ld hl,0DC00h
        ELSE
        IFDEF BINMODE
        ld hl,0E800h
        ELSE
        ld hl,(0006h)
        ld de,-0C00h
        add hl,de
        ENDIF
        ENDIF
        ld (dlim),hl
        ld (nfunc),a
        ld (npart),a
        ld (nloc),a
        ld h,a
        ld l,a
        ld (fcur),hl
        ld (fexit),hl
        ld (fskiph),hl
        call load_rt            ; the runtime (RT.BIN) is the start of the output
        IFDEF BINMODE
        ld hl,(rtsz)            ; BIN: the code must not reach the runtime's RAM
        ld de,IMGBASE
        add hl,de
        ex de,hl
        ld hl,RTRAM
        or a
        sbc hl,de
        ld de,OUT0
        add hl,de
        ld a,h
        cp OUTLIM
        jr c,.ol
        ld a,OUTLIM
.ol:    ld (outlim),a
        ENDIF
        IFDEF ROMMODE
        call mf_init
        ENDIF
        call prescan            ; SUB/FUNCTION signatures (forward references)
        IFDEF ROMMODE
        call mf_prescan
        ENDIF
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        ld (tline),hl
        xor a
        ld (iseof),a
        ld hl,fname             ; source name in the image (for the return to the editor)
        ld de,HDRNAME
        ld bc,16
        ldir
        call next_tok
        ld a,K_OPTION           ; OPTION NUMBERED | LABELS | MIXED as the first statement
        call is_kw
        jr nz,.nopt
        call save_lex
        call next_tok
        ld a,(ttype)
        cp T_ID
        jr nz,.ropt
        ld hl,tbuf
        ld de,s_numbered
        call str_eq
        ld a,1
        jr z,.setm
        ld hl,tbuf
        ld de,s_labels
        call str_eq
        ld a,2
        jr z,.setm
        IFDEF ROMMODE
        ld hl,tbuf
        ld de,s_target
        call str_eq
        jr nz,.ropt
        call next_tok
        call parse_target
        ENDIF
.ropt:  xor a
.setm:  ld (mode),a
        call restore_lex
.nopt:
        IFDEF ROMMODE
        ld a,(target)
        or a
        jr nz,.tok
        ld a,2                  ; without OPTION TARGET: ROM32
        ld (target),a
        ld (HDRTGT),a
.tok:
        ENDIF
        ld a,(mode)
        cp 1
        jr nz,.plain
        IFDEF ROMMODE
        jp err_syntax           ; OPTION NUMBERED is not in the cartridge compiler
        ELSE
        call sort_lines         ; NUMBERED: lines are compiled in line-number order
        ld a,1
        ld (onel),a
        ld hl,ENT
        ld (entp),hl
.sl:    ld hl,(entp)
        ld de,(entend)
        or a
        sbc hl,de
        jr nc,.finish
        ld hl,(entp)
        ld e,(hl)
        inc hl
        ld d,(hl)               ; number (not needed)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lp),de              ; pointer to the line
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lineno),de
        ld (entp),hl
        xor a
        ld (iseof),a
        call next_tok
        call line_loop
        jr .sl
        ENDIF
.plain: call line_loop
        IFDEF ROMMODE
        call mf_advance
        jr nz,.plain
        ENDIF
.finish:
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.nf
        ld hl,(lineno)
        ld (tline),hl
        ERR E_OPEN
.nf:    ld a,(nfunc)            ; functions declared but never defined
        or a
        jr z,.nf2
        ld b,a
        ld hl,FUNT
.fl:    ld de,16
        add hl,de
        ld a,(hl)
        ld de,FUNREC-16
        add hl,de
        or a
        jr nz,.fn
        ld hl,0
        ld (tline),hl
        ERR E_LABEL
.fn:    djnz .fl
.nf2:   ld a,(nblk)
        or a
        jr z,.nb
        ld hl,(lineno)
        ld (tline),hl
        ERR E_OPEN
.nb:    ld a,(nlab)             ; labels without a definition
        or a
        jr z,.fin
        ld b,a
        ld hl,LABT
.ul:    ld de,14
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.nx
        push hl
        ld de,17
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (tline),de
        pop hl
        ERR E_LABEL
.nx:    ld de,LABREC
        add hl,de
        djnz .ul
.fin:   ld hl,(dptr)             ; size of the data in the runtime image
        ld de,-DATA_BASE
        add hl,de
        IFDEF ROMMODE
        ld a,(curseg)
        or a
        jr nz,.nods
        ENDIF
        ld (HDRDSZ),hl
.nods:
        IFDEF ROMMODE
        ld a,(mfbin)
        or a
        jr nz,.nofin            ; last .BIN segment: nothing is written after its bytes
        ENDIF
        ld hl,RT_END
        ld a,0C3h
        call emit_jabs
.nofin:
        IFNDEF ROMMODE
        ld a,(dbgf)             ; OPTION DEBUG: variable table after the code: n, then the VART records
        or a
        ret z
        call get_pc
        ex de,hl
        ld hl,(dbgpa)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(nvar)
        call emit_a
        ld a,(nvar)
        or a
        jr z,.nv
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,VART
.dt:    ld a,(hl)
        inc hl
        call emit_a
        dec bc
        ld a,b
        or c
        jr nz,.dt
.nv:    ld hl,(dbglast)         ; then the pointer to the last local-variable record
        call emit_w
        ENDIF
        ret


        IFDEF ROMMODE
s_target: db "TARGET",0
tgtnames: db "ROM16",0,1,"ROM32",0,2,"ASCII8",0,3,"ASCII16",0,4,"KONAMI",0,5,"SCC",0,6
        db "ROM_16",0,1,"ROM_32",0,2,"ROM_ASCII8",0,3,"ROM_ASCII16",0,4,"ROM_KONAMI",0,5,"ROM_SCC",0,6,"ROM_KONAMISCC",0,6,0

parse_target:                   ; token = cartridge type name
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld de,tgtnames
.nx:    ld a,(de)
        or a
        jp z,err_syntax
        push de
        ld hl,tbuf
        call str_eq
        jr z,.hit
        pop de
.sk:    ld a,(de)
        inc de
        or a
        jr nz,.sk
        inc de
        jr .nx
.hit:   pop hl
        inc de
        ld a,(de)
        ld (target),a
        ld (HDRTGT),a
        ret

s_rom:  db ".ROM",0
msg_romw: db 13,10,"ROM written: $"
msg_romk: db 13,10,"Press any key...$"

rom_done:                       ; message, wait for a key and return to the editor
        ld a,(mfile)
        or a
        jr z,.nm0
        xor a
        call mf_setname
.nm0:   ld a,(mfred)
        or a
        jr z,.nr0
        ld hl,mforig
        ld de,fname+5
        ld bc,3
        ldir
.nr0:
        ld de,msg_romw
        ld c,9
        call BDOS
        ld hl,oname
.p:     ld a,(hl)
        or a
        jr z,.pd
        push hl
        ld e,a
        ld c,2
        call BDOS
        pop hl
        inc hl
        jr .p
.pd:    ld de,msg_romk
        ld c,9
        call BDOS
        ld c,1
        call BDOS
        ld de,0081h
        ld a,' '
        ld (de),a
        inc de
        ld hl,fname
.n:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        jr .n
.e:     ld a,' '                ; " +": the editor knows we are returning from the compiler (project directory)
        ld (de),a
        inc de
        ld a,'+'
        ld (de),a
        inc de
        ld a,0Dh
        ld (de),a
        inc de
        ld hl,0081h
        ex de,hl
        or a
        sbc hl,de
        ld a,l
        ld (0080h),a
        call cd_home
        ld hl,ldr_img
        ld de,LDR
        ld bc,ldr_size
        ldir
        jp LDR
        ENDIF

        IFNDEF ROMMODE
chk_rom:                        ; the source has "OPTION TARGET <cartridge>": switch to the cartridge compiler
        ld hl,SRC
.l:     ld a,(hl)
        or a
        ret z
        or 20h
        cp 'o'
        jr nz,.n
        push hl
        ld de,s_optionl
        call match_ci
        jr nz,.f
        call skip_sp
        ld de,s_targetl
        call match_ci
        jr nz,.f
        call skip_sp
        ld a,(hl)
        or 20h
        cp 'c'
        jr z,.f                 ; TARGET COM: normal compilation
        cp 'd'
        jr z,.f                 ; TARGET DOS: idem
        pop hl
        ld de,s_qbcr
        cp 'b'
        jr nz,.ch
        ld de,s_qbcb            ; TARGET BIN: compiler for MSX-BASIC
.ch:    push de
        call cd_home
        ld hl,ldr_img           ; loads QBCR.COM / QBCB.COM with the same command line
        ld de,LDR
        ld bc,ldr_size
        ldir
        pop hl
        ld de,LDR+3
        ld bc,11
        ldir
        jp LDR
.f:     pop hl
.n:     inc hl
        jr .l
        ENDIF
match_ci:                       ; HL = text, DE = 0-terminated lowercase pattern: Z if it matches (HL advances)
.m:     ld a,(de)
        or a
        ret z
        ld b,a
        ld a,(hl)
        or 20h
        cp b
        ret nz
        inc hl
        inc de
        jr .m
skip_sp:
.s:     ld a,(hl)
        cp ' '
        jr z,.a
        cp 9
        ret nz
.a:     inc hl
        jr .s
s_optionl: db "option",0
s_debugl: db "debug",0
        IFNDEF ROMMODE
s_asml: db "asm",0
chk_opta:                       ; Z if the source has no "OPTION ASM" (the whole file is assembly)
        ld hl,SRC
.l:     ld a,(hl)
        or a
        ret z
        or 20h
        cp 'o'
        jr nz,.n
        push hl
        ld de,s_optionl
        call match_ci
        jr nz,.f
        call skip_sp
        ld de,s_asml
        call match_ci
        jr nz,.f
        pop hl
        or 1
        ret
.f:     pop hl
.n:     inc hl
        jr .l
        ENDIF
chk_dbg:                        ; Z if the source has no "OPTION DEBUG"
        ld hl,SRC
.l:     ld a,(hl)
        or a
        ret z
        or 20h
        cp 'o'
        jr nz,.n
        push hl
        ld de,s_optionl
        call match_ci
        jr nz,.f
        call skip_sp
        ld de,s_debugl
        call match_ci
        jr nz,.f
        pop hl
        or 1
        ret
.f:     pop hl
.n:     inc hl
        jr .l
        IFNDEF ROMMODE
s_targetl: db "target",0
s_qbcr: db "QBCR    COM"
s_qbcb: db "QBCB    COM"
        ENDIF

str_eq:                         ; HL = tbuf, DE = 0-terminated string: Z if equal
.l:     ld a,(de)
        cp (hl)
        ret nz
        or a
        ret z
        inc hl
        inc de
        jr .l
s_numbered: db "NUMBERED",0
s_labels:   db "LABELS",0

line_loop:
.line:  ld a,(ttype)
        or a                    ; T_EOL
        jr nz,.st
        ld a,(onel)
        or a
        ret nz                  ; single-line mode: end of line = return
        ld a,(iseof)
        or a
        ret nz
        call next_tok
        jr .line
.st:    cp T_NUM
        jr nz,.nonum
        ld a,(mode)
        cp 2
        jp z,err_mode
        call num_to_name        ; line number = label
        call define_label
        call next_tok
        jr .line
.nonum: cp T_ID
        jr nz,.stmt
        call save_lex
        call next_tok
        ld a,':'
        call is_p
        jr nz,.notlab
        ld a,(mode)
        cp 1
        jp z,err_mode
        call define_label       ; label "name:" (tbuf is still the identifier's)
        call next_tok
        jr .line
.notlab:
        call restore_lex
.stmt:
        IFDEF ROMMODE
        call map_stmt
        ENDIF
        ld a,(dbgf)
        or a
        jr z,.go
        ld a,(ttype)
        cp T_P
        jr nz,.hk
        ld a,(tval)
        cp '#'
        jr z,.go                ; no hooks are inserted inside inline assembler blocks
.hk:    call emit_dbg
.go:    call statement
        ld a,(ttype)
        or a
        jr z,.line
        ld a,':'
        call is_p
        jp nz,err_syntax
        call next_tok
        jr .line

err_mode:
        ERR E_MODE

        IFNDEF ROMMODE
; NUMBERED: index (number, pointer, line) of the lines, sorted by number
sort_lines:
        ld hl,ENT
        ld (entend),hl
        ld hl,SRC
        ld de,1                 ; DE = source line number
.ln:    ld a,(hl)
        cp ' '
        jr z,.sp
        cp 9
        jr z,.sp
        cp 0Dh
        jr nz,.go
.sp:    inc hl
        jr .ln
.go:    or a
        ret z                   ; end of source
        cp 1Ah
        ret z
        cp 0Ah
        jr z,.eol
        cp 27h
        jr z,.skip              ; comment
        cp '0'
        jr c,.nonum
        cp '9'+1
        jr nc,.nonum
        push de
        push hl
        ld bc,0                 ; BC = number
.nl:    ld a,(hl)
        sub '0'
        cp 10
        jr nc,.nd
        push hl
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ld c,a
        ld b,0
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        inc hl
        jr .nl
.nd:    pop hl                  ; HL = start of line
        pop de
        push hl
        push de
        push bc
        call ins_ent            ; inserisce (BC, HL, DE) in ordine
        pop bc
        pop de
        pop hl
        jr .skip
.nonum: ld (tline),de           ; line without a number: only OPTION is allowed
        push hl
        ld de,s_optionw
        ld b,6
.oc:    ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc de
        djnz .oc
        pop hl
        ld de,(tline)
        jr .skip
.bad:   pop hl
        ERR E_MODE
.skip:  ld a,(hl)
        or a
        ret z
        cp 1Ah
        ret z
        inc hl
        cp 0Ah
        jr z,.nxt
        jr .skip
.eol:   inc hl
.nxt:   inc de
        jr .ln
s_optionw: db "OPTION"

ins_ent:                        ; BC = number, HL = line pointer, DE = source line
        ld (en_num),bc
        ld (en_ptr),hl
        ld (en_ln),de
        ld (tline),de
        ld hl,(entend)
        ld de,ENTMAX
        or a
        sbc hl,de
        jp nc,err_big
        ld hl,(entend)
.up:    push hl
        ld de,ENT
        or a
        sbc hl,de
        pop hl
        jr z,.ins
        ld de,-6
        add hl,de               ; HL = record precedente
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = previous number
        ld hl,(en_num)
        or a
        sbc hl,de               ; nuovo - precedente
        pop hl
        jr z,.dup
        jr c,.up                ; new < previous: keep climbing
        ld de,6
        add hl,de               ; after the previous one
        jr .ins
.dup:   ERR E_DUP
.ins:   ld (en_pos),hl
        ld de,(entend)
        ex de,hl
        or a
        sbc hl,de               ; HL = byte to move
        ld a,h
        or l
        jr z,.wr
        ld b,h
        ld c,l
        ld hl,(entend)
        dec hl                  ; last source byte
        ld de,(entend)
        push hl
        ld hl,5
        add hl,de
        ex de,hl                ; DE = entend + 5
        pop hl
        lddr
.wr:    ld hl,(en_pos)
        ld de,(en_num)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(en_ptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(en_ln)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(entend)
        ld de,6
        add hl,de
        ld (entend),hl
        ret
        ENDIF

statement:
        call statement0
        ld a,(tmpf)
        or a
        ret z
        xor a
        ld (tmpf),a
        jp emit_reset

emit_reset:                     ; frees the temporary strings (clobbers DE in the program)
        ld hl,(fcur)
        ld a,h
        or l
        jr nz,.f
        call emit_i
        db 8,0EDh,5Bh,low HEAP0,high HEAP0,0EDh,53h,low HEAPP,high HEAPP
        ret
.f:     call emit_i             ; inside a function: heapp = value saved on entry (ix-2)
        db 8,0DDh,5Eh,0FEh,0DDh,56h,0FFh,0EDh,53h
        ld hl,HEAPP
        jp emit_w

statement0:
        ld a,(ttype)
        cp T_KW
        jr z,.kw
        cp T_ID
        jp z,st_idstmt
        cp T_P
        jp nz,err_syntax
        ld a,(tval)
        cp '#'
        jr z,.asm
        cp '?'
        jp nz,err_syntax
        call next_tok
        jp st_print
.asm:   call next_tok
        jp st_asmb
.kw:    ld a,(tval)
        add a,a
        ld e,a
        ld d,0
        ld hl,kwjump
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call next_tok
        pop hl
        jp (hl)

kwjump: dw st_print, st_if, err_syntax, st_else, st_elseif, st_end, st_for, err_syntax
        dw err_syntax, st_next, st_while, st_wend, st_goto, st_gosub, st_return, st_cls
        dw st_locate, err_syntax, err_syntax, err_syntax, err_syntax, err_syntax, st_let, st_option
        dw st_input, st_dim, st_poke, st_sub, st_function, st_call, st_skip, st_shared
        dw st_exit, st_do, st_loop, err_syntax, st_select, st_case, err_syntax
        dw st_const, st_color, st_randomize, st_vpoke, st_out, st_sleep, st_stop
        dw st_screen, st_pset, st_preset, st_line, st_circle, st_palette, st_paint, st_put, err_syntax, st_get, st_draw, st_view, st_window
        dw st_vbank, st_vfill, st_vwrite, st_set, st_copy, st_data, st_read, st_restore, st_beep, st_sound, st_play, st_open, st_close, st_kill, st_write, st_segment, st_incbin, st_setbank, st_vcopy, st_mput, st_mread, st_mwrite, st_mfree, st_bload, st_bsave, st_field, st_lset, st_rset

; ---------------------------------------------------------------- espressioni
want_int:
        ld a,(etype)
        or a
        ret z
err_type:
        ERR E_TYPE
want_str:
        ld a,(etype)
        cp 1
        ret z
        jr err_type

expr:   jp e_or

e_or:   call e_and
.l:     ld a,K_OR
        call is_kw
        ld bc,0B3B2h
        jr z,.go
        ld a,K_XOR
        call is_kw
        ret nz
        ld bc,0ABAAh
.go:    push bc
        call want_int
        call next_tok
        EM1 0E5h
        call e_and
        call want_int
        pop bc
        call emit_logic
        jr .l

e_and:  call e_not
.l:     ld a,K_AND
        call is_kw
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_not
        call want_int
        ld bc,0A3A2h
        call emit_logic
        jr .l

emit_logic:                     ; C = op with D, B = op with E
        EM2 0D1h,7Ch            ; pop de ; ld a,h
        ld a,c
        call emit_a
        EM2 67h,7Dh             ; ld h,a ; ld a,l
        ld a,b
        call emit_a
        EM1 6Fh                 ; ld l,a
        ret

e_not:  ld a,K_NOT
        call is_kw
        jp nz,e_cmp
        call next_tok
        call e_not
        call want_int
        EM6 7Ch,2Fh,67h,7Dh,2Fh,6Fh
        ret

e_cmp:  call e_add
.l:     ld a,(ttype)
        cp T_P
        ret nz
        ld a,(tval)
        ld b,6
        ld hl,cmptab
.f:     cp (hl)
        jr z,.hit
        inc hl
        inc hl
        inc hl
        djnz .f
        ret
.hit:   inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de                 ; integer routine
        ld a,(etype)
        push af                 ; type of the left operand
        call next_tok
        EM1 0E5h
        call e_add
        pop bc                  ; B = left type
        ld a,(etype)
        cp b
        jp nz,err_type
        ld c,a                  ; common type (emit_i clobbers A)
        EM1 0D1h
        ld a,c
        or a
        ld hl,RT_CMP
        jr z,.cp
        ld hl,RT_SCMP           ; stringhe
.cp:    ld a,0CDh
        call emit_jabs          ; call rt_cmp / rt_scmp
        pop hl                  ; routine booleana (b_eq ecc.)
        ld a,0CDh
        call emit_jabs
.res:   xor a
        ld (etype),a
        jr .l

cmptab: db '=':dw RT_BEQ
        db 1:dw RT_BNE
        db '<':dw RT_BLT
        db '>':dw RT_BGT
        db 2:dw RT_BLE
        db 3:dw RT_BGE

e_add:  call e_mod
.l:     ld a,'+'
        call is_p
        ld c,0
        jr z,.go
        ld a,'-'
        call is_p
        ret nz
        ld c,1
.go:    ld a,(etype)
        ld b,a                  ; left type
        push bc
        call next_tok
        EM1 0E5h
        call e_mod
        pop bc
        ld a,(etype)
        cp b
        jp nz,err_type
        ld a,b
        or a
        jr nz,.str
        EM1 0D1h
        ld a,c
        or a
        jr nz,.sub
        EM1 19h                 ; add hl,de
        jr .l
.sub:   EM4 0EBh,0B7h,0EDh,52h  ; ex de,hl ; or a ; sbc hl,de
        jr .l
.str:   ld a,c
        or a
        jp nz,err_type          ; '-' on strings
        EM1 0D1h
        EM3 0CDh,low RT_SCAT,high RT_SCAT
        ld a,1
        ld (tmpf),a
        jr .l

pow2_const:                     ; current token a number 2^k (2..128), B = k, NC (the token is kept)
        ld a,(ttype)
        cp T_NUM
        jr nz,.no
        ld hl,(tval)
        ld a,h
        or a
        jr nz,.no
        ld a,l
        cp 2
        jr c,.no
        ld b,0
.pw:    srl a
        jr c,.one
        inc b
        jr .pw
.one:   or a
        jr nz,.no               ; not a power of two
        ret
.no:    scf
        ret

e_mod:  call e_idiv
.l:     ld a,K_MOD
        call is_kw
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_idiv
        call want_int
        EM2 0D1h,0EBh
        EM3 0CDh,low RT_MOD,high RT_MOD
        jr .l

e_idiv: call e_mul
.l:     ld a,5Ch
        call is_p
        ret nz
        call want_int
        call next_tok
.gen:   EM1 0E5h
        call e_mul
        call want_int
        EM2 0D1h,0EBh
        EM3 0CDh,low RT_DIV,high RT_DIV
        jr .l

e_mul:  call e_unary
.l:     ld a,'*'
        call is_p
        jr z,.mul
        ld a,'/'
        call is_p
        ret nz
        call want_int
        call next_tok
        EM1 0E5h
        call e_unary
        call want_int
        EM2 0D1h,0EBh           ; '/' = integer division (no float)
        EM3 0CDh,low RT_DIV,high RT_DIV
        jr .l
.mul:   call want_int
        call next_tok
        call pow2_const         ; * 2^k: shifts
        jr c,.gen
.sl:    EM1 29h                 ; add hl,hl
        djnz .sl
        call next_tok
        xor a
        ld (etype),a
        jr .l
.gen:   EM1 0E5h
        call e_unary
        call want_int
        EM1 0D1h
        EM3 0CDh,low RT_MUL,high RT_MUL
        jr .l

e_unary:
        ld a,'-'
        call is_p
        jr nz,.nm
        call next_tok
        call e_unary
        call want_int
        EM7 0EBh,21h,0,0,0B7h,0EDh,52h   ; ex de,hl ; ld hl,0 ; or a ; sbc hl,de
        ret
.nm:    ld a,'+'
        call is_p
        jr nz,primary
        call next_tok
        jr e_unary

primary:
        ld a,(ttype)
        cp T_NUM
        jr nz,.nn
        ld a,21h                ; ld hl,nn
        call emit_a
        ld hl,(tval)
        call emit_w
        xor a
        ld (etype),a
        jp next_tok
.nn:    cp T_STR
        jr nz,.ns
        call emit_strlit
        ld a,1
        ld (etype),a
        jp next_tok
.ns:    cp T_ID
        jp nz,.ni
        call make_nbuf
        ld hl,bitab
        ld de,nbuf
        call find_in
        jr c,.var
        add a,a                 ; predefined function
        ld e,a
        ld d,0
        ld hl,bijump
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)
.var:   call find_func
        jr c,.nofn
        ld a,(hl)               ; (first byte of name) - unused; the type is at +12
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        pop hl
        cp 2
        jp nz,err_syntax        ; a SUB is not an expression
        ld de,(fcur)
        or a
        push hl
        sbc hl,de               ; current function?
        pop hl
        jr nz,.docall
        call save_lex           ; inside its own FUNCTION: without '(' it is the result variable
        call next_tok
        ld a,'('
        call is_p
        jr z,.cl2
        call restore_lex
        jr .nofn
.cl2:   call restore_lex
        call find_func
.docall:
        push hl
        call next_tok           ; name
        pop hl
        call emit_args
        push hl
        call emit_callrec
        pop hl
        call emit_cleanup
        ld a,1
        ld (tmpf),a             ; (the string result is on the heap)
        ld de,15
        add hl,de
        ld a,(hl)
        ld (etype),a
        or a
        ret nz
        xor a
        ld (tmpf),a
        ret
.nofn: call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call find_rec           ; CONST?
        jr c,.nc
        push hl
        ld de,14
        add hl,de
        ld a,(hl)
        inc hl
        and (hl)
        cp 0FFh
        pop hl
        jr nz,.nc
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,21h                ; ld hl,value
        push hl
        call emit_a
        pop hl
        call emit_w
        xor a
        ld (etype),a
        jp next_tok
.nc:    call resolve_var
        push hl
        push af
        call kind_type
        ld (etype),a
        pop af
        pop hl
        call emit_ldv
        jp next_tok
.arr:   call restore_lex
        call arr_is_mapper
        jp nz,mapper_read
        call arr_elem           ; HL = element address
        ld a,(etype)
        or a
        ret nz                  ; string: HL is already the pointer
        EM4 5Eh,23h,56h,0EBh    ; ld e,(hl) ; inc hl ; ld d,(hl) ; ex de,hl
        ret
.ni:    cp T_P
        jp nz,err_syntax
        ld a,'('
        call is_p
        jp nz,err_syntax
        call next_tok
        call expr
        ld a,')'
        jp expect_p

make_nbuf:                      ; tbuf -> nbuf (plain text, "CHR$" etc.)
        ld hl,tbuf
        ld de,nbuf
        ld b,11
.l:     ld a,(hl)
        or a
        jr z,.e
        ld (de),a
        inc hl
        inc de
        djnz .l
.e:     ld a,(tbuf+11)
        cp '$'
        jr nz,.z
        ld (de),a
        inc de
.z:     xor a
        ld (de),a
        ret

; --- built-in functions (the current token is the name)
bitab:  db "LEN",0,"ASC",0,"VAL",0,"ABS",0,"SGN",0,"RND",0,"PEEK",0,"CHR$",0,"STR$",0
        db "LEFT$",0,"RIGHT$",0,"MID$",0,"INKEY$",0,"TIMER",0,"VPEEK",0,"INP",0,"UBOUND",0,"POINT",0,"COLLISION",0,"BASE",0,"VDP",0,"STICK",0,"STRIG",0,"VREAD$",0,"EOF",0,"DATAWIN",0,"MAPPERSEGS",0,"MGET",0,"VARPTR",0
        db "MALLOC",0,"LOF",0
        db "MKI$",0,"CVI",0,0
bijump: dw bi_len, bi_asc, bi_val, bi_abs, bi_sgn, bi_rnd, bi_peek, bi_chr, bi_str
        dw bi_left, bi_right, bi_mid, bi_inkey, bi_timer, bi_vpeek, bi_inp, bi_ubound, bi_point, bi_coll
        dw bi_base, bi_vdp, bi_stick, bi_strig, bi_vread, bi_eof, bi_datawin, bi_mapsegs, bi_mget, bi_varptr, bi_malloc, bi_lof, bi_mki, bi_cvi

open_paren:
        ld a,'('
        jp expect_p
close_paren:
        ld a,')'
        jp expect_p

bi_len: ld hl,RT_LEN
        jr bi1s
bi_asc: ld hl,RT_ASC
        jr bi1s
bi_val: ld hl,RT_VAL
bi1s:   push hl                 ; a string argument -> integer
        call next_tok
        call open_paren
        call expr
        call want_str
        call close_paren
        pop hl
        ld a,0CDh
        call emit_jabs
        xor a
        ld (etype),a
        ret

bi_chr: ld hl,RT_CHR
        ld c,1
        jr bi1i
bi_str: ld hl,RT_STR
        ld c,1
        jr bi1i
bi_rnd: ld hl,RT_RND
        ld c,0
bi1i:   push bc                 ; an integer argument; C = result type
        push hl
        call next_tok
        call open_paren
        call expr
        call want_int
        call close_paren
        pop hl
        ld a,0CDh
        call emit_jabs
        pop bc
        ld a,c
        ld (etype),a
        or a
        ret z
        ld (tmpf),a
        ret

bi_abs: call bi_arg_int
        call emit_i
        db 7,0CBh,7Ch,28h,03h,0CDh,low RT_NEG,high RT_NEG   ; bit 7,h ; jr z,+3 ; call rt_neg
        ret
bi_sgn: call bi_arg_int
        call emit_i
        db 16,0CBh,7Ch,20h,09h,7Ch,0B5h,28h,08h,21h,1,0,18h,03h,21h,0FFh,0FFh
        ret
bi_peek:
        call bi_arg_int
        EM4 7Eh,6Fh,26h,0       ; ld a,(hl) ; ld l,a ; ld h,0
        ret
bi_arg_int:
        call next_tok
        call open_paren
        call expr
        call want_int
        jp close_paren

bi_timer:
        call next_tok
        ld a,'('
        call is_p
        jr nz,.nop
        call next_tok
        ld a,')'
        call expect_p
.nop:   EM3 2Ah,low 0FC9Eh,high 0FC9Eh     ; ld hl,(JIFFY)
        xor a
        ld (etype),a
        ret

bi_inkey:
        call next_tok
        ld a,'('
        call is_p
        jr nz,.nop
        call next_tok
        ld a,')'
        call expect_p
.nop:   EM3 0CDh,low RT_INKEY,high RT_INKEY
        ld a,1
        ld (etype),a
        ld (tmpf),a
        ret

bi_left:
        ld hl,RT_LEFT
        jr bi2
bi_right:
        ld hl,RT_RIGHT
bi2:    push hl                 ; (stringa, intero) -> stringa
        call next_tok
        call open_paren
        call expr
        call want_str
        ld a,','
        call expect_p
        EM1 0E5h
        call expr
        call want_int
        call close_paren
        EM1 0D1h
        pop hl
        ld a,0CDh
        call emit_jabs
        ld a,1
        ld (etype),a
        ld (tmpf),a
        ret

bi_mid: call next_tok
        call open_paren
        call expr
        call want_str
        ld a,','
        call expect_p
        EM1 0E5h
        call expr
        call want_int
        ld a,','
        call is_p
        jr nz,.two
        call next_tok
        EM1 0E5h
        call expr
        call want_int
        EM2 0D1h,0C1h           ; pop de (start) ; pop bc (string)
        jr .go
.two:   call emit_i
        db 5,0EBh,0C1h,21h,0FFh,0   ; ex de,hl ; pop bc ; ld hl,255
.go:    call close_paren
        EM3 0CDh,low RT_MID,high RT_MID
        ld a,1
        ld (etype),a
        ld (tmpf),a
        ret

; ---------------------------------------------------------------- statements
emit_dbg:                       ; OPTION DEBUG: push hl ; ld hl,<line> ; call RT_DBG ; pop hl
        EM1 0E5h
        ld a,21h
        call emit_a
        ld hl,(tline)
        call emit_w
        EM3 0CDh,low RT_DBG,high RT_DBG
        EM1 0E1h
        ret

emit_brk:                       ; OPTION BREAK: break-key check before a backward jump
        IFNDEF ROMMODE
        IFNDEF BINMODE
        ld a,(brkf)
        or a
        ret z
        ld a,(dbgf)             ; with OPTION DEBUG the debugger already checks every statement
        or a
        ret nz
        jp emit_dbg
        ENDIF
        ENDIF

s_debug: db "DEBUG",0
        IFNDEF ROMMODE
s_break: db "BREAK",0
        ENDIF

st_asmb:                        ; "# [*] items": bytes prepared by QASM.OVL (inline assembler)
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
        call next_tok           ; +k: start of block + k
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
        call next_tok           ; n:NAME -> n + address of the BASIC label
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
.var:   call resolve_var        ; address of a global integer or string variable
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
        jp st_asmb.l

chk_asm:                        ; the source has "__ASM" or "OPTION ASM": QASM.OVL (at 8000h) rewrites the blocks
        IFNDEF ROMMODE
        call chk_opta
        jr nz,.go
        ENDIF
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
        call open_tool
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

st_option:
        IFDEF ROMMODE
        ld a,(mfcur)
        or a
        jp nz,err_mode          ; the OPTIONs are only in the file NAME000
        ENDIF
        ld a,(ttype)
        cp T_ID
        jr nz,st_skip
        ld hl,tbuf
        ld de,s_debug
        call str_eq
        jr z,.dbg
        IFDEF ROMMODE
        ld hl,tbuf
        ld de,s_mapw
        call str_eq
        jr nz,st_skip
        call map_open           ; OPTION MAP: map file for the debugger of the PC
        ENDIF
        IFNDEF ROMMODE
        IFNDEF BINMODE
        ld hl,tbuf
        ld de,s_break
        call str_eq
        jr nz,st_skip
        ld a,80h                ; OPTION BREAK: bit 7 of the runtime type byte + checks on backward jumps
        ld (HDRTGT),a
        ld a,1
        ld (brkf),a
        ENDIF
        ENDIF
        jr st_skip
.dbg:   ld a,1
        ld (dbgf),a
        IFDEF ROMMODE
        call next_tok           ; OPTION DEBUG [GLOBALS | ALL]
        ld a,(ttype)
        cp T_ID
        jr nz,.nl
        ld a,(tbuf)             ; GLOBALS or ALL: the first letter tells
        ld b,1
        cp 'G'
        jr z,.sl
        inc b
        cp 'A'
        jr nz,.nl
.sl:    ld a,b
        ld (dbgl),a
.nl:
        ENDIF
        IFNDEF ROMMODE
        ld a,21h                ; ld hl,table ; ld (DBGT),hl  (the address is written at the end of compilation)
        call emit_a
        ld hl,(outp)
        ld (dbgpa),hl
        ld hl,0
        call emit_w
        ld hl,DBGT
        call emit_st
        ENDIF
st_skip:                        ; DECLARE and OPTION: rest of the line ignored
.l:     ld a,(ttype)
        or a
        ret z
        call next_tok
        jr .l

st_let: ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
st_idstmt:                      ; identifier at the start of the statement: SUB without CALL or assignment
        call make_nbuf
        ld hl,nbuf
        ld de,s_spritedol
        call str_eq
        jp z,st_sprdef
        ld hl,nbuf
        ld de,s_vdp
        call str_eq
        jp z,st_vdpset
        call find_func
        jr c,st_assign
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        pop hl
        cp 1
        jr nz,st_assign         ; FUNCTION: assignment to the result
        push hl
        call next_tok
        pop hl
        jp call_sub
st_assign:
        call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call resolve_var
        push hl
        push af
        call next_tok
        ld a,'='
        call expect_p
        call expr
        pop af
        pop hl                  ; A = reference type, HL = address/offset
        push af
        push hl
        call kind_type
        ld b,a
        ld a,(etype)
        cp b
        jp nz,err_type
        pop hl
        pop af
        jp emit_stv
.arr:   call restore_lex
        call arr_is_mapper
        jp nz,mapper_assign
        call arr_elem           ; HL = element address
        ld a,(etype)
        push af
        EM1 0E5h
        ld a,'='
        call expect_p
        call expr
        pop af
        ld b,a
        ld a,(etype)
        cp b
        jp nz,err_type
        EM1 0D1h                ; pop de = address
        ld a,(etype)
        or a
        jr nz,.astr
        call emit_i
        db 5,7Dh,12h,13h,7Ch,12h        ; ld a,l ; ld (de),a ; inc de ; ld a,h ; ld (de),a
        ret
.astr:  EM3 0CDh,low RT_SCOPY,high RT_SCOPY
        ret

st_print0:
        ld c,1                  ; C = a capo finale
.l:     push bc
        call at_send
        pop bc
        jr z,.end
        ld a,';'
        call is_p
        jr nz,.nsc
        ld c,0
        push bc
        call next_tok
        pop bc
        jr .l
.nsc:   ld a,','
        call is_p
        jr nz,.item
        ld c,0
        push bc
        EM3 0CDh,low RT_ZONE,high RT_ZONE
        call next_tok
        pop bc
        jr .l
.item:  ld c,1
.num:   push bc
        call expr
        ld a,(etype)
        or a
        jr nz,.ps
        EM3 0CDh,low RT_PINT,high RT_PINT
        jr .pd
.ps:    EM3 0CDh,low RT_PSTR,high RT_PSTR
.pd:    pop bc
        ld c,1
        jr .l
.end:   ld a,c
        or a
        ret z
        EM3 0CDh,low RT_PNL,high RT_PNL
        ret

emit_strlit:                    ; string token -> ld hl,<len> ; jp past ; db len,text
        ld a,(tlen)
        ld b,a
        ld hl,(tval)
emit_lit:                       ; HL = text, B = length
        push hl
        push bc
        call get_pc
        ld de,6
        add hl,de               ; address of the length byte = pc + 6
        ld a,21h
        call emit_a
        call emit_w
        pop bc
        push bc
        ld c,b
        ld b,0
        call get_pc
        ld de,4
        add hl,de
        add hl,bc               ; end of the data = pc + 4 + len (pc after the ld hl)
        ld a,0C3h
        call emit_jabs
        pop bc
        ld a,b
        call emit_a
        pop hl
        ld a,b
        or a
        ret z
.c:     ld a,(hl)
        inc hl
        call emit_a
        djnz .c
        ret

st_goto:
        ld a,0C3h
        jr jump_target
st_gosub:
        ld a,0CDh
jump_target:                    ; A = opcode; token = line number or label
        ld b,a
        ld a,(ttype)
        cp T_NUM
        jr nz,.id
        ld a,(mode)
        cp 2
        jp z,err_mode
        push bc
        call num_to_name
        pop bc
        jr .go
.id:    cp T_ID
        jp nz,err_syntax
        ld a,(mode)
        cp 1
        jp z,err_mode
.go:    ld a,b
        cp 0C3h
        jr nz,.nb
        push bc
        BRKCHK
        pop bc
        ld a,b
.nb:    call label_jump
        jp next_tok

st_return:
        EM1 0C9h
        ret

st_cls: EM3 0CDh,low RT_CLS,high RT_CLS
        ret

st_locate:
        call expr
        call want_int
        EM1 0E5h
        ld a,','
        call expect_p
        call expr
        call want_int
        EM1 0D1h
        EM3 0CDh,low RT_LOCATE,high RT_LOCATE
        ret

; --- IF
cond_expr:                      ; integer condition expression; releases temporaries; HL (program) != 0 if true
        call expr
        call want_int
        ld a,(tmpf)
        or a
        jr z,.nt
        xor a
        ld (tmpf),a
        call emit_reset
.nt:    EM2 7Ch,0B5h            ; ld a,h ; or l
        ret

cond_jz:                        ; condition -> jump if false to the chain (HL)
        push hl
        call cond_expr
        pop hl
        ld a,0CAh               ; jp z
        jp emit_jchain

st_if:  ld a,B_IF
        call push_blk
        inc hl                  ; campo a = catena dell'else
        call cond_jz
        ld a,K_THEN
        call is_kw
        jp nz,err_syntax
        call next_tok
        ld a,(ttype)
        or a
        ret z                   ; block form: the block stays open
        call one_line           ; single-line form
        ld a,K_ELSE
        call is_kw
        jr nz,.noelse
        call next_tok
        ld a,B_IF
        call need_blk
        inc hl
        inc hl
        inc hl                  ; field b = chain of the end
        ld a,0C3h
        call emit_jchain
        ld a,B_IF
        call need_blk
        inc hl
        call patch_chain
        call one_line
        jr .fin
.noelse:
        ld a,B_IF
        call need_blk
        inc hl
        call patch_chain
.fin:   ld a,B_IF
        call need_blk
        inc hl
        inc hl
        inc hl
        call patch_chain
        ld hl,nblk
        dec (hl)
        ret

one_line:                       ; after THEN/ELSE: jump to line/label or statements
        ld a,(ttype)
        cp T_NUM
        jr z,.goto
        cp T_ID
        jr nz,.stm
        call save_lex
        call next_tok
        ld a,(ttype)
        or a
        jr z,.lab
        ld a,(ttype)
        cp T_KW
        jr nz,.ntk
        ld a,(tval)
        cp K_ELSE
        jr z,.lab
.ntk:   ld a,':'
        call is_p
        jr z,.lab
        call restore_lex
        jr .stm
.lab:   call restore_lex
.goto:  ld a,0C3h
        jp jump_target
.stm:
.sl:    call statement
        ld a,':'
        call is_p
        ret nz
        call next_tok
        jr .sl

st_elseif:
        ld a,B_IF
        call need_blk
        push hl
        inc hl
        inc hl
        inc hl
        ld a,0C3h
        call emit_jchain
        pop hl
        inc hl
        push hl
        call patch_chain
        pop hl
        call cond_jz
        ld a,K_THEN
        jp expect_kw

st_else:
        ld a,B_IF
        call need_blk
        push hl
        inc hl
        inc hl
        inc hl
        ld a,0C3h
        call emit_jchain
        pop hl
        inc hl
        jp patch_chain

st_end: ld a,K_IF
        call is_kw
        jr z,.endif
        ld a,K_SUB
        call is_kw
        jr z,.esub
        ld a,K_FUNCTION
        call is_kw
        jr z,.efun
        ld a,K_SELECT
        call is_kw
        jr z,.esel
        ld a,0C3h
        ld hl,RT_END
        jp emit_jabs
.esub:  ld c,1
        jr .endf
.efun:  ld c,2
.endf:  push bc
        call next_tok
        pop bc
        jp end_func
.esel:  call next_tok
        ld a,B_SEL
        call need_blk
        push hl
        inc hl
        call patch_chain        ; CASE with no matches -> here
        pop hl
        inc hl
        inc hl
        inc hl
        call patch_chain        ; end of the CASEs
        ld a,B_SEL
        call need_blk
        ld de,9
        add hl,de
        ld a,(hl)
        or a
        jr nz,.sstr
        EM1 0D1h                ; pop de (discard the SELECT value)
        jr .sdone
.sstr:  call emit_i             ; frees the 256-byte copy: ld hl,256 ; add hl,sp ; ld sp,hl
        db 5,21h,0,1,39h,0F9h
.sdone:
        ld hl,nblk
        dec (hl)
        ret
.endif: call next_tok
        ld a,B_IF
        call need_blk
        push hl
        inc hl
        call patch_chain
        pop hl
        inc hl
        inc hl
        inc hl
        call patch_chain
        ld hl,nblk
        dec (hl)
        ret

; --- FOR / NEXT
st_for: ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call kind_type
        or a
        jp nz,err_type
        call next_tok
        ld a,'='
        call expect_p
        call expr
        call want_int
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv           ; var = initial value
        ld a,K_TO
        call expect_kw
        call expr
        call want_int
        EM1 0E5h                ; push hl (limite)
        ld hl,1
        ld (tmps),hl
        ld a,K_STEP
        call is_kw
        jr nz,.nstep
        call next_tok
        ld a,'-'
        call is_p
        jr nz,.pos
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld de,0
        ex de,hl
        or a
        sbc hl,de
        ld (tmps),hl
        jr .stp
.pos:   ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld hl,(tval)
        ld (tmps),hl
.stp:   call next_tok
.nstep: ld a,B_FOR
        call push_blk
        ld a,(tmpk)
        ld de,9
        add hl,de
        ld (hl),a               ; +9 = reference type
        ld de,-8
        add hl,de               ; +1
        ld de,(tmpv)
        ld (hl),e
        inc hl
        ld (hl),d               ; a = variabile
        inc hl
        ld de,(tmps)
        ld (hl),e
        inc hl
        ld (hl),d               ; b = passo
        inc hl
        push hl
        call get_pc
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d               ; c = start of the loop
        EM2 0D1h,0D5h           ; pop de ; push de
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_ldv           ; ld hl,var
        EM1 0EBh
        EM3 0CDh,low RT_CMP,high RT_CMP
        ld a,(tmps+1)
        bit 7,a
        push af
        ld a,B_FOR
        call need_blk
        ld de,7
        add hl,de               ; HL = &catena d'uscita
        pop af
        jr nz,.neg
        EM2 38h,03h             ; jr c,+3
        ld a,0C2h               ; jp nz,uscita
        jp emit_jchain
.neg:   ld a,0DAh               ; jp c,uscita
        jp emit_jchain

st_next:
        ld a,B_FOR
        call need_blk
        ld a,(ttype)
        cp T_ID
        jr nz,.nn
        push hl
        call next_tok
        pop hl
.nn:    push hl
        ld de,9
        add hl,de
        ld a,(hl)
        ld (tmpk),a
        pop hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tmpv),de            ; variabile
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (tmps),bc            ; passo
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = start of the loop
        push de
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_ldv           ; ld hl,var
        ld a,11h
        call emit_a
        ld hl,(tmps)
        call emit_w             ; ld de,passo
        EM1 19h                 ; add hl,de
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv           ; var = hl
        BRKCHK
        pop hl
        ld a,0C3h
        call emit_jabs          ; jp start
        ld a,B_FOR
        call need_blk
        ld de,7
        add hl,de
        call patch_chain        ; uscita
        EM1 0D1h                ; pop de (discard the limit)
        ld hl,nblk
        dec (hl)
        ret

; --- WHILE / WEND
st_while:
        ld a,B_WHILE
        call push_blk
        push hl
        call get_pc
        ex de,hl
        pop hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d               ; a = start
        inc hl                  ; b = catena d'uscita
        call cond_jz
        ret

st_poke:
        call expr
        call want_int
        EM1 0E5h
        ld a,','
        call expect_p
        call expr
        call want_int
        EM3 0D1h,7Dh,12h        ; pop de ; ld a,l ; ld (de),a
        ret

st_input:
        ld a,'#'
        call is_p
        jp z,st_finput
        ld c,1                  ; C = stampa "? "
        ld a,(ttype)
        cp T_STR
        jr nz,.q
        call emit_strlit
        EM3 0CDh,low RT_PSTR,high RT_PSTR
        call next_tok
        ld a,','
        call is_p
        jr nz,.semi
        ld c,0
        call next_tok
        jr .q
.semi:  ld a,';'
        call expect_p
.q:     ld a,c
        or a
        jr z,.var
        ld b,2
        ld hl,s_qm
        call emit_lit
        EM3 0CDh,low RT_PSTR,high RT_PSTR
.var:   ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 0CDh,low RT_INPUT,high RT_INPUT
        ld a,(tmpk)
        call kind_type
        or a
        jr nz,.istr
        EM3 0CDh,low RT_VAL,high RT_VAL
.istr:  ld a,(tmpk)
        ld hl,(tmpv)
        jp emit_stv
s_qm:   db "? "

st_dim:
        ld hl,(fcur)
        ld a,h
        or l
        jp nz,err_syntax        ; DIM only at main level
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_rec
        jp nc,.dup
        ld a,(vtyp)
        push af
        push hl                 ; room for the new record
        ld hl,tbuf              ; the array name must be saved: reading a CONST overwrites tbuf
        ld de,nbuf
        ld bc,16
        ldir
        call next_tok
        ld a,'('
        call expect_p
        call num_or_const
        inc de                  ; elements = max index + 1
        push de
        call next_tok
        ld a,')'
        call expect_p
        xor a
        ld (mapf),a
        ld a,(ttype)
        cp T_ID
        jr nz,.nmp
        ld hl,tbuf
        ld de,s_mapper
        call str_eq
        jr nz,.nmp
        ld a,1                  ; DIM x(n) MAPPER: the array lives in the mapper RAM segments
        ld (mapf),a
        call next_tok
.nmp:   pop de
        pop hl
        pop af
        push hl
        ld h,d
        ld l,e
        or a
        jr z,.int
        ld a,(mapf)
        or a
        jp nz,err_type          ; integer arrays only
        ld a,d                  ; strings: at most 255 elements of 256 bytes
        or a
        jp nz,err_mem
        ld b,e
        ld c,0
        jr .go
.int:   add hl,hl
        ld b,h
        ld c,l
.go:    push de                 ; number of elements
        ld hl,nbuf              ; restore the name
        ld de,tbuf
        push bc
        ld bc,16
        ldir
        pop bc
        pop de
        pop hl
        ld a,(mapf)
        or a
        jr nz,.map
        call new_rec
.cm:    ld a,','
        call is_p
        ret nz
        call next_tok
        jp .l
.map:   ld (mapcnt),de          ; descriptor (6 bytes) in the data; the record remembers the number of elements with bit 15 set
        set 7,d
        ld bc,6
        call new_rec
        push hl
        ld a,21h                ; ld hl,descriptor ; ld de,number ; call RT_MDIM
        call emit_a
        pop hl
        call emit_w
        ld a,11h
        call emit_a
        ld hl,(mapcnt)
        call emit_w
        EM3 0CDh,low RT_MDIM,high RT_MDIM
        xor a
        ld (mapf),a
        jr .cm
.dup:   ERR E_DUP

; --- function table
find_func:                      ; tbuf -> HL = record, NC if found; C if missing
        ld a,(nfunc)
        or a
        jr z,.nf
        ld b,a
        ld hl,FUNT
.l:     call name_eq
        jr z,.f
        ld de,FUNREC
        add hl,de
        djnz .l
.nf:    scf
        ret
.f:     or a
        ret

prescan:                        ; records the SUB/FUNCTION signatures of the whole source
        ld hl,SRC
        ld (lp),hl
        ld hl,1
        ld (lineno),hl
        xor a
        ld (iseof),a
        call next_tok
.t:     ld a,(ttype)
        or a
        jr nz,.nz
        ld a,(iseof)
        or a
        ret nz
        call next_tok
        jr .t
.nz:    cp T_NUM
        jr nz,.k
        call next_tok
        jr .t
.k:     cp T_KW
        jr nz,.skip
        ld a,(tval)
        cp K_SUB
        jr z,.reg
        cp K_FUNCTION
        jr nz,.skip
.reg:   call reg_func
.skip:  ld a,(ttype)
        or a
        jr z,.t
        cp T_KW
        jr nz,.adv
        ld a,(tval)
        cp K_WINDOW
        jr nz,.nw
        ld a,1
        ld (usewin),a           ; the program uses WINDOW
        jr .adv
.nw:    IFDEF ROMMODE
        cp K_SEGMENT
        jr nz,.adv
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jr nz,.skip
        ld a,(tval)
        ld (pseg),a
        ENDIF
.adv:   call next_tok
        jr .skip

reg_func:                       ; token = SUB/FUNCTION: creates the record with name and parameters
        ld a,(tval)
        sub K_SUB
        inc a                   ; 1 = SUB, 2 = FUNCTION
        push af
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_func
        jp nc,err_dup2
        ld a,(nfunc)
        cp MAXFUN
        jr c,.ok
        ERR E_MANY
.ok:    ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl
        add hl,hl               ; *24
        ld de,FUNT
        add hl,de
        ld (rf_rec),hl
        ld a,(nfunc)
        inc a
        ld (nfunc),a
        IFDEF ROMMODE
        call rom_regfunc
        ENDIF
        ex de,hl
        ld hl,tbuf
        ld bc,12
        ldir                    ; name
        pop af
        ld (de),a               ; +12 type
        inc de
        xor a
        ld (de),a               ; +13 number of parameters
        inc de
        ld a,(npart)
        ld (de),a               ; +14 first parameter
        inc de
        ld a,(tsuf)
        ld (de),a               ; +15 result type
        inc de
        xor a
        ld b,8
.z:     ld (de),a               ; +16 defined, +17 +18 address, +19 +20 chain, +21 mask, +22 +23
        inc de
        djnz .z
        call next_tok
        ld a,'('
        call is_p
        jp nz,.done
        call next_tok
.pl:    ld a,')'
        call is_p
        jp z,.close
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(npart)
        cp MAXPAR
        jr c,.pok
        ERR E_MANY
.pok:   call save_lex           ; array parameter: name followed by "()"
        call next_tok
        ld a,'('
        call is_p
        ld a,0
        jr nz,.na
        inc a
.na:    ld (tmpk),a
        call restore_lex
        ld hl,(rf_rec)
        ld de,13
        add hl,de
        ld a,(hl)
        cp 8
        jr c,.p8
        ERR E_MANY
.p8:    inc a
        ld (hl),a               ; number of parameters
        dec a
        ld c,a                  ; parameter index
        ld a,(npart)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PART
        add hl,de
        ex de,hl
        ld hl,tbuf
        push bc
        ld bc,12
        ldir
        pop bc
        ld a,(tsuf)
        ld (de),a               ; parameter type
        inc de
        ld a,(tmpk)
        ld (de),a               ; +13 = 1 if array
        ld a,(npart)
        inc a
        ld (npart),a
        ld a,(tsuf)
        or a
        jr z,.nms
        ld e,21                 ; mask of the string types
        push bc
        call rf_bit
        pop bc
.nms:   ld a,(tmpk)
        or a
        jr z,.nma
        ld e,22                 ; mask of the array parameters
        push bc
        call rf_bit
        pop bc
.nma:   ld hl,(rf_rec)          ; words on the stack: 1 (scalar) or 2 (array: base and number of elements)
        ld de,23
        add hl,de
        ld a,(tmpk)
        inc a
        add a,(hl)
        ld (hl),a
.nm:    call next_tok
        ld a,(tmpk)
        or a
        jr z,.nn
        ld a,'('
        call is_p
        jp nz,err_syntax
        call next_tok
        ld a,')'
        call is_p
        jp nz,err_syntax
        call next_tok
.nn:    ld a,','
        call is_p
        jp nz,.pl
        call next_tok
        jp .pl
.close: call next_tok
.done:  ret
err_dup2:
        ERR E_DUP

rf_bit:                         ; C = index, E = offset in the record: sets the bit
        ld b,c
        ld a,1
        inc b
.sh:    dec b
        jr z,.sd
        add a,a
        jr .sh
.sd:    ld c,a
        ld hl,(rf_rec)
        ld d,0
        add hl,de
        ld a,(hl)
        or c
        ld (hl),a
        ret

ca_bit:                         ; DE = offset of a mask in the record -> A = bit of the current argument
        ld hl,(ca_rec)
        add hl,de
        ld b,(hl)
        ld a,(ca_i)
        ld c,a
        ld a,b
        inc c
.s:     dec c
        jr z,.d
        rrca
        jr .s
.d:     and 1
        ret

emit_args:                      ; HL = record; reads the arguments (also in parentheses) and emits the pushes; returns HL = record
        ld de,(ca_rec)
        push de
        ld a,(ca_i)
        ld d,a
        ld a,(ca_paren)
        ld e,a
        push de
        ld (ca_rec),hl
        xor a
        ld (ca_i),a
        ld (ca_paren),a
        ld a,'('
        call is_p
        jr nz,.l
        ld a,1
        ld (ca_paren),a
        call next_tok
.l:     ld hl,(ca_rec)
        ld de,13
        add hl,de
        ld a,(ca_i)
        cp (hl)
        jp nc,.done
        or a
        jr z,.first
        ld a,','
        call expect_p
.first: ld de,22
        call ca_bit
        or a
        jr z,.sc
        call emit_arrarg        ; array parameter: name (with or without "()")
        jr .nx
.sc:    call expr
        ld de,21
        call ca_bit
        ld b,a
        ld a,(etype)
        cp b
        jp nz,err_type
        IFDEF ROMMODE
        ld a,(etype)
        or a
        jr z,.pp
        ld hl,(ca_rec)          ; string to another segment: copy to the heap (literals live in the caller's segment)
        call rec_far
        cp 0FFh
        jr z,.pp
        EM3 0CDh,low RT_SDUP,high RT_SDUP
.pp:
        ENDIF
        EM1 0E5h                ; push hl
.nx:    ld a,(ca_i)
        inc a
        ld (ca_i),a
        jp .l
.done:  ld a,(ca_paren)
        or a
        jr z,.np
        ld a,')'
        call expect_p
.np:    ld hl,(ca_rec)
        pop de
        ld a,e
        ld (ca_paren),a
        ld a,d
        ld (ca_i),a
        pop de
        ld (ca_rec),de
        ret

emit_arrarg:                    ; array argument: emits push base ; push number of elements
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld de,21
        call ca_bit
        ld b,a
        ld a,(tsuf)
        cp b
        jp nz,err_type          ; element type differs from the parameter type
emit_arrref:                    ; token = name: emits push base ; push number of elements (global array or parameter)
        call find_arrparam
        jr c,.glob
        ld c,l                  ; array parameter of this function: copies the pair from the frame
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        add a,2
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        add a,3
        call emit_a
        EM1 0E5h                ; push base
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        inc a
        call emit_a
        EM1 0E5h                ; push number of elements
        jr .end
.glob:  call find_rec
        jp c,err_type
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        bit 7,b
        jp nz,err_type
        ld a,b
        or c
        jp z,err_type           ; not an array
        ld a,b
        and c
        inc a
        jp z,err_type           ; it is a CONST
        push bc
        ex de,hl
        ld a,21h                ; ld hl,base ; push hl
        push hl
        call emit_a
        pop hl
        call emit_w
        EM1 0E5h
        pop hl
        ld a,21h                ; ld hl,number ; push hl
        push hl
        call emit_a
        pop hl
        call emit_w
        EM1 0E5h
.end:   call next_tok           ; name
        ld a,'('
        call is_p
        ret nz
        call next_tok
        ld a,')'
        jp expect_p

find_arrparam:                  ; tbuf = name: NC if it is an array parameter of the current function (A = type, HL = offset)
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.no
        ld a,(nloc)
        or a
        jr z,.no
        ld b,a
        ld hl,LOCT
.l:     call name_eq
        jr z,.f
        ld de,16
        add hl,de
        djnz .l
.no:    scf
        ret
.f:     ld de,12
        add hl,de
        ld a,(hl)
        cp 5
        jr c,.no
        cp 7
        jr nc,.no
        push af
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop af
        or a
        ret

emit_callrec:                   ; HL = record: call of the routine (or fixup chain if not yet defined)
        IFDEF ROMMODE
        push hl
        call rec_far
        pop hl
        cp 0FFh
        jr z,.direct
        push af                 ; routine in another segment: ld a,index ; call RT_FARCALL
        ld a,3Eh
        call emit_a
        pop af
        call emit_a
        ld hl,RT_FARCALL
        ld a,0CDh
        jp emit_jabs
.direct:
        ENDIF
        ld de,16
        add hl,de
        ld a,(hl)
        or a
        jr z,.fwd
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,0CDh
        jp emit_jabs
.fwd:   ld de,3
        add hl,de               ; +19 = head of the chain
        ld a,0CDh
        jp emit_jchain

emit_cleanup:                   ; HL = record: removes the arguments from the stack (preserves the program's HL)
        push hl
        ld de,23
        add hl,de
        ld a,(hl)               ; parole sullo stack
        pop hl
        or a
        ret z
        push hl
        add a,a
        ld c,a                  ; bytes to release
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        jr nz,.sub
        EM1 0EBh                ; ex de,hl (keeps the result)
.sub:   ld a,21h
        call emit_a
        ld l,c
        ld h,0
        call emit_w             ; ld hl,2n
        EM2 39h,0F9h            ; add hl,sp ; ld sp,hl
        pop hl
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        jr nz,.end
        EM1 0EBh
.end:   pop hl
        ret

st_call:
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf              ; CALL FAR name: FAR is optional (the cross-segment call is automatic)
        ld de,s_far
        call str_eq
        jr nz,.nf
        call next_tok
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
.nf:
        call find_func
        jp c,err_label
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        pop hl
        cp 1
        jp nz,err_syntax
        push hl
        call next_tok
        pop hl
call_sub:                       ; HL = record SUB
        call emit_args
        push hl
        call emit_callrec
        pop hl
        jp emit_cleanup
err_label:
        ERR E_LABEL

st_sub: ld c,1
        call begin_func
        jp st_skip              ; parameters already recorded by the prescan
st_function:
        ld c,2
        call begin_func
        jp st_skip
begin_func:                     ; token = name; C = 1 SUB / 2 FUNCTION
        ld hl,(fcur)
        ld a,h
        or l
        jp nz,err_syntax        ; cannot be nested
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_func
        jp c,err_label
        ld (fcur),hl
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        cp c
        jp nz,err_syntax
        pop hl
        ld hl,0
        ld (fexit),hl
        xor a
        ld (nloc),a
        ld (nint),a
        ld (nstr),a
        ld hl,(lineno)
        inc hl
        ld (dbgfs),hl
        ld hl,fskiph            ; normal flow skips over the body
        ld a,0C3h
        call emit_jchain
        ld hl,(fcur)            ; definisce l'ingresso
        push hl
        call get_pc
        ex de,hl
        pop hl
        push hl
        ld bc,16
        add hl,bc
        ld (hl),1
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl                  ; +19 chain of the previous calls
        call patch_chain
        pop hl
        IFDEF ROMMODE
        call rom_defsub
        ENDIF
        call emit_i             ; push ix ; ld ix,0 ; add ix,sp ; ld hl,-FRAME ; add hl,sp ; ld sp,hl
        db 8,0DDh,0E5h,0DDh,21h,0,0,0DDh,39h
        ld a,21h
        call emit_a
        ld hl,(outp)
        ld (framep),hl          ; operand to be patched at the end of the function
        ld hl,0
        call emit_w
        EM2 39h,0F9h
        call emit_i             ; saves heapp: ld hl,(heapp) ; ld (ix-2),l ; ld (ix-1),h
        db 9,2Ah,low HEAPP,high HEAPP,0DDh,75h,0FEh,0DDh,74h,0FFh
        ; parameters as variables: type 3 (integer) / 4 (string) / 5, 6 (integer / string arrays)
        ld hl,(fcur)
        ld de,13
        add hl,de
        ld a,(hl)
        or a
        jr z,.np
        ld c,a                  ; C = index (counts down from the last: the first argument is the deepest)
        ld hl,4
        ld (tmps),hl            ; current offset
.pl:    dec c
        push bc
        ld hl,(fcur)
        ld de,14
        add hl,de
        ld a,(hl)
        add a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PART
        add hl,de
        push hl
        ld de,tbuf              ; parameter name -> tbuf
        ld bc,12
        ldir
        pop hl
        ld de,12
        add hl,de
        ld b,(hl)               ; type (0 int / 1 str)
        inc hl
        ld a,(hl)               ; 1 = array
        or a
        ld a,3
        jr z,.k
        ld a,5
.k:     add a,b
        ld (tmpk),a
        ld de,(tmps)
        call loct_add
        ld a,(tmpk)
        ld de,2
        cp 5
        jr c,.s1
        ld de,4
.s1:    ld hl,(tmps)
        add hl,de
        ld (tmps),hl
        pop bc
        ld a,c
        or a
        jr nz,.pl
.np:    ld hl,(fcur)            ; result variable of the FUNCTIONs
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        ret nz
        ld hl,(fcur)
        ld de,tbuf
        ld bc,12
        ldir                    ; the function name is the result name
        ld a,(tbuf+11)
        cp '$'
        ld a,0
        jr nz,.r
        inc a
.r:     ld (tsuf),a
        call resolve_var        ; creates the local result variable
        ld (tmpk),a
        ld (tmpv),hl
        cp 3
        jr z,.rs
        ld a,(tmpk)             ; integer: ld hl,0 ; save
        EM3 21h,0,0
        ld a,(tmpk)
        ld hl,(tmpv)
        jp emit_stv
.rs:    ld a,(tmpk)             ; string: starts empty
        ld hl,(tmpv)
        call emit_ldv
        EM2 36h,0               ; ld (hl),0
        ret

end_func:                       ; C = 1 SUB / 2 FUNCTION
        ld hl,(fcur)
        ld a,h
        or l
        jp z,err_syntax
        push hl
        ld de,12
        add hl,de
        ld a,(hl)
        cp c
        jp nz,err_syntax
        pop hl
        ld a,(nblk)
        or a
        jp nz,err_open2
        ld hl,fexit
        call patch_chain
        ld hl,(fcur)
        ld de,12
        add hl,de
        ld a,(hl)
        cp 2
        jr nz,.ret
        ld hl,(fcur)            ; result: recalls the local variable
        ld de,tbuf
        ld bc,12
        ldir
        ld a,(tbuf+11)
        cp '$'
        ld a,0
        jr nz,.r
        inc a
.r:     ld (tsuf),a
        push af
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        pop af
        or a
        jr nz,.str
        ld a,(tmpk)             ; intero
        ld hl,(tmpv)
        call emit_ldv
        call emit_i             ; restores heapp (uses DE)
        db 8,0DDh,5Eh,0FEh,0DDh,56h,0FFh,0EDh,53h
        ld hl,HEAPP
        call emit_w
        jr .ret
.str:   call emit_i             ; heapp restored, then copy of the result onto the heap
        db 8,0DDh,5Eh,0FEh,0DDh,56h,0FFh,0EDh,53h
        ld hl,HEAPP
        call emit_w
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_ldv
        EM3 0CDh,low RT_SDUP,high RT_SDUP
.ret:   call emit_i             ; ld sp,ix ; pop ix ; ret
        db 5,0DDh,0F9h,0DDh,0E1h,0C9h
        ld a,(nstr)             ; frame size: 64 + 256 * local strings (operand = -frame)
        ld h,a
        ld l,64
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
        ld hl,(framep)
        ld (hl),e
        inc hl
        ld (hl),d
        IFNDEF ROMMODE
        ld a,(dbgf)             ; OPTION DEBUG: [prev w][start line w][end line w][n][n 16-byte LOCT records]
        or a
        jr z,.nodbg
        call get_pc
        push hl
        ld hl,(dbglast)
        call emit_w
        ld hl,(dbgfs)
        call emit_w
        ld hl,(lineno)
        call emit_w
        ld a,(nloc)
        call emit_a
        ld a,(nloc)
        or a
        jr z,.dn
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,LOCT
.dl:    ld a,(hl)
        inc hl
        call emit_a
        dec bc
        ld a,b
        or c
        jr nz,.dl
.dn:    pop hl
        ld (dbglast),hl
.nodbg:
        ENDIF
        IFDEF ROMMODE
        ld a,(dbgl)
        cp 2
        call z,dbg_frec         ; OPTION DEBUG ALL: record of the local variables
        call map_func           ; OPTION MAP: record of the SUB/FUNCTION
        ENDIF
        ld hl,fskiph
        call patch_chain
        ld hl,0
        ld (fcur),hl
        ret
err_open2:
        ERR E_OPEN

st_shared:                      ; SHARED a, b$: the names stay global inside the SUB/FUNCTION
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,(fcur)
        ld a,h
        or l
        jr z,.nx
        ld a,2
        ld de,0
        call loct_add
.nx:    call next_tok
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_exit:
        ld a,(ttype)
        cp T_KW
        jp nz,err_syntax
        ld a,(tval)
        cp K_SUB
        jr z,.fn
        cp K_FUNCTION
        jr z,.fn
        ld c,B_FOR
        cp K_FOR
        jr z,.blk
        ld c,B_DO
        cp K_DO
        jr z,.blk
        ld c,B_WHILE
        cp K_WHILE
        jr z,.blk
        jp err_syntax
.fn:    ld hl,(fcur)
        ld a,h
        or l
        jp z,err_syntax
        call next_tok
        ld hl,fexit
        ld a,0C3h
        jp emit_jchain
.blk:   push bc
        call next_tok
        pop bc
        call find_blk
        ld a,c
        cp B_FOR
        ld de,7
        jr z,.o
        ld de,3
.o:     add hl,de
        ld a,0C3h
        jp emit_jchain

; --- DO / LOOP
st_do:  ld a,B_DO
        call push_blk
        push hl
        call get_pc
        ex de,hl
        pop hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d               ; a = start
        ld a,K_WHILE
        call is_kw
        jr z,.w
        ld a,K_UNTIL
        call is_kw
        ret nz
        call next_tok           ; DO UNTIL cond: exits if true
        call cond_expr
        ld a,B_DO
        call need_blk
        ld de,3
        add hl,de
        ld a,0C2h               ; jp nz,uscita
        jp emit_jchain
.w:     call next_tok           ; DO WHILE cond: exits if false
        ld a,B_DO
        call need_blk
        ld de,3
        add hl,de
        jp cond_jz

st_loop:
        ld a,B_DO
        call need_blk
        push hl
        ld a,K_WHILE
        call is_kw
        ld c,0C2h               ; LOOP WHILE: back to the start if true
        jr z,.c
        ld a,K_UNTIL
        call is_kw
        ld c,0CAh               ; LOOP UNTIL: back to the start if false
        jr z,.c
        pop hl
        jr .plain
.c:     push bc
        BRKCHK
        call next_tok
        call cond_expr
        pop bc
        pop hl
        push hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,c
        call emit_jabs
        pop hl
        jr .fin
.plain: push hl
        BRKCHK
        pop hl
        push hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,0C3h
        call emit_jabs
        pop hl
.fin:   inc hl
        inc hl
        inc hl
        call patch_chain        ; uscita
        ld hl,nblk
        dec (hl)
        ret

; --- SELECT CASE (interi)
st_select:
        ld a,K_CASE
        call expect_kw
        call expr
        ld a,(etype)
        ld (tmpk),a             ; 0 = selettore intero, 1 = stringa
        or a
        jr z,.tmp
        call emit_i             ; string: 256-byte copy on the stack (stays valid for the whole block)
        db 7,0EBh,21h,0,0FFh,39h,0F9h,0EBh
        EM3 0CDh,low RT_SCOPY,high RT_SCOPY
.tmp:   ld a,(tmpf)
        or a
        jr z,.nt
        xor a
        ld (tmpf),a
        call emit_reset
.nt:    ld a,(tmpk)
        or a
        jr nz,.blk
        EM1 0E5h                ; integer: push hl (the value stays on the stack for the whole block)
.blk:   ld a,B_SEL
        call push_blk
        ld de,9
        add hl,de
        ld a,(tmpk)
        ld (hl),a               ; +9 = selector type
        ret

want_sel:                       ; the CASE value must have the selector's type
        ld a,B_SEL
        call need_blk
        ld de,9
        add hl,de
        ld b,(hl)
        ld a,(etype)
        cp b
        ret z
        jp err_type

emit_seltest:                   ; compares selector (on the stack) with HL (CASE value): flags as rt_cmp/rt_scmp
        ld a,B_SEL
        call need_blk
        ld de,9
        add hl,de
        ld a,(hl)
        or a
        jr nz,.s
        EM2 0D1h,0D5h           ; pop de ; push de
        EM3 0CDh,low RT_CMP,high RT_CMP
        ret
.s:     call emit_i             ; DE = copy of the selector (SP), HL = CASE value
        db 6,0EBh,21h,0,0,39h,0EBh
        EM3 0CDh,low RT_SCMP,high RT_SCMP
        ret

st_case:
        ld a,B_SEL
        call need_blk
        push hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,.first
        pop hl                  ; previous CASE: its body jumps to the end
        push hl
        inc hl
        inc hl
        inc hl
        ld a,0C3h
        call emit_jchain
        pop hl
        push hl
        inc hl
        call patch_chain        ; i test falliti arrivano qui
.first: pop hl
        ld a,K_ELSE
        call is_kw
        jr nz,.tests
        jp next_tok             ; CASE ELSE
.tests: ld hl,0
        ld (chfail),hl
.tl:    ld a,K_IS
        call is_kw
        jr nz,.val
        call next_tok           ; IS op expr
        ld a,(ttype)
        cp T_P
        jp nz,err_syntax
        ld a,(tval)
        ld b,6
        ld hl,cmptab
.f:     cp (hl)
        jr z,.hit
        inc hl
        inc hl
        inc hl
        djnz .f
        jp err_syntax
.hit:   inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        call next_tok
        call expr
        call want_sel
        call emit_seltest
        pop hl
        ld a,0CDh
        call emit_jabs          ; call b_xx
        EM2 7Ch,0B5h
        ld a,B_SEL
        call need_blk
        ld de,5
        add hl,de               ; c = body chain
        ld a,0C2h               ; jp nz,corpo
        call emit_jchain
        jr .more
.val:   call expr
        call want_sel
        ld a,K_TO
        call is_kw
        jr z,.range
        call emit_seltest
        ld a,B_SEL
        call need_blk
        ld de,5
        add hl,de
        ld a,0CAh               ; jp z,corpo
        call emit_jchain
        jr .more
.range: call next_tok
        call emit_seltest
        ld hl,chfail
        ld a,0DAh               ; jp c,failed (value < start)
        call emit_jchain
        call expr
        call want_sel
        call emit_seltest
        ld a,B_SEL
        call need_blk
        ld de,5
        add hl,de
        push hl
        ld a,0CAh               ; jp z,corpo
        call emit_jchain
        pop hl
        ld a,0DAh               ; jp c,corpo
        call emit_jchain
        ld hl,chfail
        call patch_chain
.more:  ld a,','
        call is_p
        jr nz,.end
        call next_tok
        jp .tl
.end:   ld a,B_SEL
        call need_blk
        push hl
        inc hl
        ld a,0C3h
        call emit_jchain        ; no match: go to next CASE
        pop hl
        ld de,5
        add hl,de
        jp patch_chain          ; the body starts here

num_or_const:                    ; number or CONST -> DE = value (the token is not consumed)
        ld a,(ttype)
        cp T_NUM
        jr nz,.id
        ld de,(tval)
        ret
.id:    cp T_ID
        jp nz,err_syntax
        call find_rec
        jp c,err_syntax
        push hl
        ld de,14
        add hl,de
        ld a,(hl)
        inc hl
        and (hl)
        cp 0FFh
        pop hl
        jp nz,err_syntax
        ld de,12
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

; --- CONST name = [-]number {, ...}: record with count FFFFh and the value in place of the address
st_const:
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(tsuf)
        or a
        jp nz,err_type
        call find_rec
        jp nc,err_dup2
        ld (tmpv),hl            ; room for the record
        call next_tok
        ld a,'='
        call expect_p
        ld hl,0
        ld a,'-'
        call is_p
        jr nz,.pos
        ld hl,1
        call next_tok
.pos:   ld (chfail),hl          ; segno (1 = negativo)
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        ld de,(tval)
        ld hl,(chfail)
        ld a,l
        or a
        jr z,.val
        ld hl,0
        or a
        sbc hl,de
        ex de,hl
.val:   ld (chfail),de          ; value
        ld hl,(tmpv)
        ld bc,0
        ld de,0FFFFh
        call new_rec
        ld hl,(tmpv)
        ld de,12
        add hl,de
        ld de,(chfail)
        ld (hl),e
        inc hl
        ld (hl),d
        call next_tok
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_stop:
        ld a,0C3h
        ld hl,RT_END
        jp emit_jabs

st_randomize:
        call expr
        call want_int
        call emit_i             ; ld a,h ; or l ; jr nz,+1 ; inc hl ; ld (rndseed),hl
        db 8,7Ch,0B5h,20h,01h,23h,22h,low (RTRAM+2),high (RTRAM+2)
        ret

st_sleep:
        call expr
        call want_int
        EM3 0CDh,low RT_WAIT,high RT_WAIT
        ret

two_ints:                       ; a, b -> DE = a, HL = b
        call expr
        call want_int
        EM1 0E5h
        ld a,','
        call expect_p
        call expr
        call want_int
        EM1 0D1h
        ret

st_vpoke:
        call two_ints
        EM3 0CDh,low RT_VPOKE,high RT_VPOKE
        ret

st_out: call two_ints
        EM4 4Bh,7Dh,0EDh,79h    ; ld c,e ; ld a,l ; out (c),a
        ret

st_color:
        ld a,'='
        call is_p
        jp z,st_colpal
        ld a,K_SPRITE
        call is_kw
        jp z,st_colspr
        ld a,(ttype)
        cp T_ID
        jr nz,.n
        call make_nbuf
        ld hl,nbuf
        ld de,s_spritedol
        call str_eq
        jp z,st_colsprs
.n:     call expr
        call want_int
        EM1 0E5h
        ld a,','
        call is_p
        jr nz,.nobg
        call next_tok
        call expr
        call want_int
        ld a,','
        call is_p
        jr nz,.go
        call next_tok           ; third value: border color (H = border + 1)
        EM1 0E5h
        call expr
        call want_int
        call emit_i             ; ld a,l ; inc a ; pop hl ; ld h,a
        db 4,7Dh,3Ch,0E1h,67h
        jr .go
.nobg:  call emit_i             ; sfondo invariato: ld a,(BAKCLR) ; ld l,a ; ld h,0
        db 6,3Ah,low 0F3EAh,high 0F3EAh,6Fh,26h,0
.go:    EM1 0D1h
        EM3 0CDh,low RT_COLOR,high RT_COLOR
        ret

st_colpal:                      ; COLOR = (n, r, g, b)  or  COLOR = RESTORE
        call next_tok
        ld a,'('
        call is_p
        jr nz,.rs
        call next_tok
        call st_palette
        jp close_paren
.rs:    call next_tok
        EM3 0CDh,low RT_PALINIT,high RT_PALINIT
        ret

colspr_head:                    ; (n) = : piano in GX1
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call close_paren
        ld a,'='
        jp expect_p

st_colspr:                      ; COLOR SPRITE(n) = colore
        call colspr_head
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        EM3 0CDh,low RT_SPRCOL,high RT_SPRCOL
        ret

st_colsprs:                     ; COLOR SPRITE$(n) = colors per line
        call colspr_head
        call expr
        call want_str
        EM3 0CDh,low RT_SPRCOLS,high RT_SPRCOLS
        ret

st_vbank:
        call expr
        call want_int
        EM3 0CDh,low RT_VBANK,high RT_VBANK
        ret

st_vfill:                       ; VFILL address, count, value
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        EM3 0CDh,low RT_VFILL,high RT_VFILL
        ret

st_vwrite:                      ; VWRITE address, string
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_str
        EM3 0CDh,low RT_VWRITE,high RT_VWRITE
        ret

st_vdpset:                      ; VDP(n) = value
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call close_paren
        ld a,'='
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        EM3 0CDh,low RT_VDPSET,high RT_VDPSET
        ret

bi_base: ld hl,RT_BASE
        jr bi_one
bi_vdp: ld hl,RT_VDP
        jr bi_one
bi_stick: ld hl,RT_STICK
        jr bi_one
bi_strig: ld hl,RT_STRIG
bi_one: push hl
        call bi_arg_int
        pop hl
        ld a,0CDh
        call emit_jabs
        xor a
        ld (etype),a
        ret

bi_vread:                       ; VREAD$(address, count)
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        call close_paren
        EM3 0CDh,low RT_VREAD,high RT_VREAD
        ld a,1
        ld (etype),a
        ret

bi_ubound:                      ; UBOUND(array): maximum index (also for an array parameter)
        call next_tok
        call open_paren
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call find_arrparam
        jr c,.glob
        ld c,l                  ; ld l,(ix+d) ; ld h,(ix+d+1) ; dec hl
        ld a,0DDh
        call emit_a
        ld a,6Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,0DDh
        call emit_a
        ld a,66h
        call emit_a
        ld a,c
        inc a
        call emit_a
        EM1 2Bh
        jr .done
.glob:  call find_rec
        jp c,err_type
        ld de,14
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        res 7,d                 ; (array in the mapper: bit 15 = flag)
        ld a,d
        or e
        jp z,err_type
        ld a,d
        and e
        inc a
        jp z,err_type
        dec de
        ld a,21h
        call emit_a
        ex de,hl
        call emit_w
.done:  call next_tok
        call close_paren
        xor a
        ld (etype),a
        ret

bi_vpeek:
        call bi_arg_int
        EM3 0CDh,low RT_VPEEK,high RT_VPEEK
        ret
bi_inp: call bi_arg_int
        call emit_i             ; ld c,l ; in a,(c) ; ld l,a ; ld h,0
        db 6,4Dh,0EDh,78h,6Fh,26h,0
        ret

; --- grafica
emit_st:                        ; HL = address: emits ld (nn),hl
        ld a,22h
        push hl
        call emit_a
        pop hl
        jp emit_w

emit_xy:                        ; "(x, y)" with WINDOW conversion (if the source uses it): into (DE) and (BC)
        push de
        push bc
        call emit_xy_raw
        pop bc
        pop de
        ld a,(usewin)
        or a
        ret z
        push bc
        ld h,d
        ld l,e
        ld de,RT_WX
        call emit_map
        pop hl
        ld de,RT_WY
        jp emit_map

emit_map:                       ; HL = &variabile, DE = routine: emette ld hl,(var) ; call routine ; ld (var),hl
        ld (tmpv),hl
        ld (tmps),de
        ld a,2Ah
        call emit_a
        ld hl,(tmpv)
        call emit_w
        ld a,0CDh
        call emit_a
        ld hl,(tmps)
        call emit_w
        ld a,22h
        call emit_a
        ld hl,(tmpv)
        jp emit_w

emit_xy_raw:                    ; "(x, y)" without conversion: evaluates and stores into (DE) and (BC)
        push bc
        push de
        ld a,'('
        call expect_p
        call expr
        call want_int
        pop hl
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        pop hl
        call emit_st
        ld a,')'
        jp expect_p

emit_defcol:                    ; GCOL = -1 (colore corrente)
        call emit_i
        db 6,21h,0FFh,0FFh,22h,low GCOL,high GCOL
        ret

emit_optcol:                    ; ", colore" facoltativo -> GCOL
        ld a,','
        call is_p
        ret nz
        call next_tok
        call expr
        call want_int
        ld hl,GCOL
        jp emit_st

emit_gopclr:                    ; xor a ; ld (GOP),a
        call emit_i
        db 4,0AFh,32h,low GOP,high GOP
        ret

parse_op:                       ; operatore logico -> ld a,n ; ld (GOP),a  (PSET PRESET AND OR XOR e le versioni T...)
        ld a,(ttype)
        cp T_KW
        jr nz,.id
        ld a,(tval)
        ld c,0
        cp K_PSET
        jr z,.ok
        ld c,4
        cp K_PRESET
        jr z,.ok
        ld c,1
        cp K_AND
        jr z,.ok
        ld c,2
        cp K_OR
        jr z,.ok
        ld c,3
        cp K_XOR
        jp nz,err_syntax
        jr .ok
.id:    cp T_ID
        jp nz,err_syntax
        ld de,opnames
.nx:    ld a,(de)
        or a
        jp z,err_syntax
        push de
        ld hl,tbuf
        call str_eq
        jr z,.hit
        pop de
.sk:    ld a,(de)
        inc de
        or a
        jr nz,.sk
        inc de                  ; skips the code
        jr .nx
.hit:   pop hl
        inc de
        ld a,(de)
        ld c,a
.ok:    ld a,3Eh
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GOP
        call emit_w
        jp next_tok

opnames: db "TPSET",0,8,"TPRESET",0,12,"TAND",0,9,"TOR",0,10,"TXOR",0,11,0

st_data:                        ; DATA items: block in the code (jp past, items, 2, link)
        ld a,(curseg)
        or a
        jp nz,err_syntax        ; DATA only in the fixed segment
        call get_pc
        push hl                 ; block address
        ld a,0C3h
        call emit_a
        ld hl,0
        call emit_w
        ld hl,(dlast)           ; links the previous block (or the start of the data for the first)
        ld a,h
        or l
        jr nz,.lk
        pop hl
        push hl
        inc hl
        inc hl
        inc hl
        ld (HDRDAT),hl
        jr .it
.lk:    pop de
        push de
        inc de
        inc de
        inc de
        ld bc,(voff)
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
.it:    ld a,(ttype)
        cp T_STR
        jr z,.str
        ld a,'-'
        call is_p
        jr nz,.num
        call next_tok
        ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        xor a
        call emit_a
        ld hl,(tval)
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        call emit_w
        jr .nx
.num:   ld a,(ttype)
        cp T_NUM
        jp nz,err_syntax
        xor a
        call emit_a
        ld hl,(tval)
        call emit_w
        jr .nx
.str:   ld a,1
        call emit_a
        ld a,(tlen)
        call emit_a
        ld a,(tlen)
        ld b,a
        ld hl,(tval)
.cp:    ld a,b
        or a
        jr z,.nx
        ld a,(hl)
        push hl
        push bc
        call emit_a
        pop bc
        pop hl
        inc hl
        dec b
        jr .cp
.nx:    call next_tok
        ld a,','
        call is_p
        jr nz,.end
        call next_tok
        jr .it
.end:   ld a,2
        call emit_a
        call get_pc
        ld (dlast),hl
        ld hl,0
        call emit_w
        call get_pc             ; patch of the jp: past the block
        pop de
        inc de
        ex de,hl
        ld bc,(voff)
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ret

st_read:                        ; READ variabile[, variabile...]
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call save_lex
        call next_tok
        ld a,'('
        call is_p
        jr z,.arr
        call restore_lex
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        ld a,(tmpk)
        call kind_type
        call emit_read
        ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv
        jr .more
.arr:   call restore_lex
        call arr_elem
        ld a,(etype)
        push af
        EM1 0E5h
        pop af
        push af
        call emit_read
        EM1 0D1h
        pop af
        or a
        jr nz,.astr
        call emit_i
        db 5,7Dh,12h,13h,7Ch,12h
        jr .more
.astr:  EM3 0CDh,low RT_SCOPY,high RT_SCOPY
.more:  ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

emit_read:                      ; A = 0/1: ld a,n ; call RT_READ
        push af
        ld a,3Eh
        call emit_a
        pop af
        call emit_a
        EM3 0CDh,low RT_READ,high RT_READ
        ret

st_restore:                     ; RESTORE [etichetta]
        call at_send
        jr nz,.lab
        call emit_i
        db 3,21h,0,0
        jr .go
.lab:   ld a,21h
        call jump_target
        EM3 0CDh,low RT_RESTORE,high RT_RESTORE
        ret
.go:    EM3 0CDh,low RT_RESTORE,high RT_RESTORE
        ret

st_beep:
        EM3 0CDh,low RT_BEEP,high RT_BEEP
        ret

st_sound:                       ; SOUND register, value
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        EM3 0CDh,low RT_SOUND,high RT_SOUND
        ret

st_play:                        ; PLAY voce1$[, voce2$[, voce3$]]
        call emit_i
        db 12,21h,0,0,22h,low PLV,high PLV,22h,low PLV+2,high PLV+2,22h,low PLV+4,high PLV+4
        ld hl,PLV
.l:     push hl
        call expr
        call want_str
        pop hl
        push hl
        call emit_st
        pop hl
        inc hl
        inc hl
        ld a,','
        call is_p
        jr nz,.go
        push hl
        call next_tok
        pop hl
        ld de,PLV+6
        or a
        sbc hl,de
        add hl,de
        jp z,err_syntax
        jr .l
.go:    EM3 0CDh,low RT_PLAY,high RT_PLAY
        ret

st_print:                       ; PRINT [#n,] items
        ld a,'#'
        call is_p
        jp nz,st_print0
        call sel_file
        call st_print0
        jp emit_outreset

sel_file:                       ; "#n," -> RT_OUTSEL
        call next_tok
        call expr
        call want_int
        EM3 0CDh,low RT_OUTSEL,high RT_OUTSEL
        ld a,','
        jp expect_p

emit_outreset:                  ; ld hl,0 ; call RT_OUTSEL
        call emit_i
        db 6,21h,0,0,0CDh,low RT_OUTSEL,high RT_OUTSEL
        ret

st_write:                       ; WRITE [#n,] items
        ld a,'#'
        call is_p
        jr nz,.nf
        call sel_file
.nf:    call at_send
        jr z,.end
.l:     call expr
        ld a,(etype)
        or a
        jr nz,.s
        EM3 0CDh,low RT_WINT,high RT_WINT
        jr .nx
.s:     EM3 0CDh,low RT_WSTR,high RT_WSTR
.nx:    ld a,','
        call is_p
        jr nz,.end
        ld b,1
        ld hl,s_comma
        call emit_lit
        EM3 0CDh,low RT_PSTR,high RT_PSTR
        call next_tok
        jr .l
.end:   EM3 0CDh,low RT_PNL,high RT_PNL
        jp emit_outreset
s_comma: db ","

st_open:                        ; OPEN name$ FOR INPUT|OUTPUT|APPEND AS [#]n
        call expr
        call want_str
        EM1 0E5h
        call emit_i             ; record length = 128
        db 6,21h,80h,0,22h,low GX2,high GX2
        ld a,K_FOR
        call is_kw
        jr z,.for
        ld c,4                  ; without FOR: random access
        jp .m2
.for:   call next_tok
        ld c,1
        ld a,K_INPUT
        call is_kw
        jr z,.m
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_output
        call str_eq
        ld c,2
        jr z,.m
        ld hl,tbuf
        ld de,s_random
        call str_eq
        ld c,4
        jr z,.m
        ld hl,tbuf
        ld de,s_append
        call str_eq
        jp nz,err_syntax
        ld c,3
.m:     push bc
        call next_tok
        pop bc
.m2:    ld a,21h                ; ld hl,modo ; ld (GY1),hl
        call emit_a
        ld l,c
        ld h,0
        call emit_w
        ld hl,GY1
        call emit_st
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_as
        call str_eq
        jp nz,err_syntax
        call next_tok
        ld a,'#'
        call is_p
        jr nz,.n
        call next_tok
.n:     call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,(ttype)            ; LEN = record length
        cp T_ID
        jr nz,.nl
        ld hl,tbuf
        ld de,s_len
        call str_eq
        jr nz,.nl
        call next_tok
        ld a,'='
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
.nl:    EM1 0E1h
        EM3 0CDh,low RT_OPEN,high RT_OPEN
        ret
s_len:  db "LEN",0
s_random: db "RANDOM",0
s_output: db "OUTPUT",0
s_append: db "APPEND",0
s_as:   db "AS",0

st_close:                       ; CLOSE [[#]n[, [#]m...]]
        call at_send
        jr nz,.l
        call emit_i
        db 6,21h,0,0,0CDh,low RT_CLOSE,high RT_CLOSE
        ret
.l:     ld a,'#'
        call is_p
        jr nz,.e
        call next_tok
.e:     call expr
        call want_int
        EM3 0CDh,low RT_CLOSE,high RT_CLOSE
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_kill:
        call expr
        call want_str
        EM3 0CDh,low RT_KILL,high RT_KILL
        ret

bi_eof:                         ; EOF(n)
        call bi_arg_int
        EM3 0CDh,low RT_FEOF,high RT_FEOF
        ret

st_finput:                      ; INPUT #n, var[, var...]
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
.l:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 2Ah,low GX1,high GX1
        EM3 0CDh,low RT_FINPUT,high RT_FINPUT
        ld a,(tmpk)
        call kind_type
        or a
        jr nz,.s
        EM3 0CDh,low RT_VAL,high RT_VAL
.s:     ld a,(tmpk)
        ld hl,(tmpv)
        call emit_stv
        ld a,','
        call is_p
        ret nz
        call next_tok
        jr .l

st_lineinput:                   ; LINE INPUT [#n,] var$
        call next_tok
        ld a,'#'
        call is_p
        jr nz,.kb
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 2Ah,low GX1,high GX1
        EM3 0CDh,low RT_FLINE,high RT_FLINE
        jr .st
.kb:    ld a,(ttype)
        cp T_STR
        jr nz,.v
        call emit_strlit        ; prompt facoltativo
        EM3 0CDh,low RT_PSTR,high RT_PSTR
        call next_tok
        ld a,';'
        call expect_p
.v:     ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        call resolve_var
        ld (tmpk),a
        ld (tmpv),hl
        call next_tok
        EM3 0CDh,low RT_INPUT,high RT_INPUT
.st:    ld a,(tmpk)
        call kind_type
        or a
        jp nz,.ok
        jp err_type
.ok:    ld a,(tmpk)
        ld hl,(tmpv)
        jp emit_stv

st_set:                         ; SET PAGE visibile[, attiva]  |  SET SCROLL x, y
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld hl,tbuf
        ld de,s_page
        call str_eq
        jr z,.page
        ld hl,tbuf
        ld de,s_scroll
        call str_eq
        jp nz,err_syntax
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        EM3 0CDh,low RT_SCROLL,high RT_SCROLL
        ret
.page:  call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call is_p
        jr nz,.same
        call next_tok
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        jr .go
.same:  call emit_i             ; pagina attiva = visibile
        db 6,2Ah,low GX1,high GX1,22h,low GY1,high GY1
.go:    EM3 0CDh,low RT_SETPAGE,high RT_SETPAGE
        ret
s_page: db "PAGE",0
dlast:  dw 0
s_scroll: db "SCROLL",0

st_copy:                        ; COPY (x1,y1)-(x2,y2)[, pagina] TO (x3,y3)[, pagina][, operatore]
        ld de,GX1
        ld bc,GY1
        call emit_xy_raw
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        call emit_i             ; pagine = -1 (attiva)
        db 9,21h,0FFh,0FFh,22h,low CSP,high CSP,22h,low CDP,high CDP
        ld a,','
        call is_p
        jr nz,.to
        call next_tok
        call expr
        call want_int
        ld hl,CSP
        call emit_st
.to:    ld a,K_TO
        call expect_kw
        ld de,CDX
        ld bc,CDY
        call emit_xy_raw
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.op                ; pagina omessa
        call expr
        call want_int
        ld hl,CDP
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.op:    call next_tok
        call parse_op
        EM3 0CDh,low RT_COPY,high RT_COPY
        jp emit_gopclr
.go:    EM3 0CDh,low RT_COPY,high RT_COPY
        ret

st_screen:
        call expr
        call want_int
        EM3 0CDh,low RT_SCREEN,high RT_SCREEN
        ld a,','
        call is_p
        ret nz
        call next_tok           ; SCREEN modo, dimensione sprite (0 8x8, 1 8x8 x2, 2 16x16, 3 16x16 x2)
        call expr
        call want_int
        EM3 0CDh,low RT_SPRSIZE,high RT_SPRSIZE
        ret

st_pset:
        ld hl,RT_GPSET
        jr pset_common
st_preset:
        ld hl,RT_GPRESET
pset_common:
        push hl
        ld de,GX1
        ld bc,GY1
        call emit_xy
        call emit_defcol
        call emit_optcol
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        call parse_op
        pop hl
        ld a,0CDh
        call emit_jabs
        jp emit_gopclr
.go:    pop hl
        ld a,0CDh
        jp emit_jabs

st_circle:                      ; CIRCLE (x,y), r[, color[, start[, end[, aspect]]]]  (degrees, aspect in %)
        ld de,GX1
        ld bc,GY1
        call emit_xy
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        ld a,(usewin)
        or a
        jr z,.nw
        ld hl,GX2
        ld de,RT_WR
        call emit_map
.nw:    call emit_defcol
        call emit_i             ; start = 0, end = 360, aspect = 100, GFLG = 0
        db 22,21h,0,0,22h,low GY2,high GY2,21h,68h,1,22h,low CEND,high CEND,21h,64h,0,22h,low CASP,high CASP,0AFh,32h,low GFLG,high GFLG
        ld a,','
        call is_p
        jp nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.arc               ; colore omesso
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        ld a,','
        call is_p
        jp nz,.go
.arc:   call emit_i             ; GFLG = 1 (arco/ellisse)
        db 5,3Eh,1,32h,low GFLG,high GFLG
        call next_tok
        ld a,','
        call is_p
        jr z,.end               ; start omitted
        call expr
        call want_int
        ld hl,GY2
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.end:   call next_tok
        ld a,','
        call is_p
        jr z,.asp               ; end omitted
        call expr
        call want_int
        ld hl,CEND
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.asp:   call next_tok
        call expr
        call want_int
        ld hl,CASP
        call emit_st
.go:    EM3 0CDh,low RT_GCIRCLE,high RT_GCIRCLE
        ret

st_line:                        ; LINE [(x1,y1)]-(x2,y2)[, colore[, B|BF]]  |  LINE INPUT [#n,] var$
        ld a,K_INPUT
        call is_kw
        jp z,st_lineinput
        ld a,'('
        call is_p
        jr nz,.cur
        ld de,GX1
        ld bc,GY1
        call emit_xy
        jr .dash
.cur:   call emit_i             ; without a first point: from the last graphic point
        db 12,2Ah,low LASTX,high LASTX,22h,low GX1,high GX1,2Ah,low LASTY,high LASTY,22h,low GY1,high GY1
.dash:  ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy
        call emit_defcol
        call emit_i             ; GFLG = 0
        db 4,0AFh,32h,low GFLG,high GFLG
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.flag              ; colore omesso: ", , B"
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.flag:  call next_tok
        ld a,','
        call is_p
        jr z,.op                ; ", colore, , operatore"
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(tbuf)
        cp 'B'
        jp nz,err_syntax
        ld c,1                  ; B
        ld a,(tbuf+1)
        or a
        jr z,.setf
        cp 'F'
        jp nz,err_syntax
        ld a,(tbuf+2)
        or a
        jp nz,err_syntax
        ld c,2                  ; BF
.setf:  ld a,3Eh                ; ld a,n ; ld (GFLG),a
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GFLG
        call emit_w
        call next_tok
        ld a,','
        call is_p
        jr nz,.go
.op:    call next_tok
        call parse_op
        EM3 0CDh,low RT_GLINE,high RT_GLINE
        jp emit_gopclr
.go:    EM3 0CDh,low RT_GLINE,high RT_GLINE
        ret

st_paint:                       ; PAINT (x,y)[, colore[, bordo]]
        ld de,GX1
        ld bc,GY1
        call emit_xy
        call emit_defcol
        call emit_i             ; border = -1 (like the color)
        db 6,21h,0FFh,0FFh,22h,low GX2,high GX2
        call emit_optcol
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        call expr
        call want_int
        ld hl,GX2
        call emit_st
.go:    EM3 0CDh,low RT_PAINT,high RT_PAINT
        ret

s_spritedol: db "SPRITE$",0
s_vdp:  db "VDP",0
s_far:  db "FAR",0
s_mapper: db "MAPPER",0
s_sw:   db "S",0

arr_ref_stmt:                   ; integer array (with or without "()") -> ARRB, ARRC
        ld a,(ttype)
        cp T_ID
        jp nz,err_syntax
        ld a,(tsuf)
        or a
        jp nz,err_type
        call emit_arrref
        call emit_i             ; pop hl ; ld (ARRC),hl ; pop hl ; ld (ARRB),hl
        db 8,0E1h,22h,low ARRC,high ARRC,0E1h,22h,low ARRB,high ARRB
        ret

st_get:                         ; GET (x1,y1)-(x2,y2), array   |   GET #n [, record]
        ld a,'#'
        call is_p
        jp z,st_fget
        ld de,GX1
        ld bc,GY1
        call emit_xy
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy
        ld a,','
        call expect_p
        call arr_ref_stmt
        EM3 0CDh,low RT_GGET,high RT_GGET
        ret

st_gput:                        ; PUT (x,y), array[, PSET|PRESET|AND|OR|XOR]
        ld de,GX1
        ld bc,GY1
        call emit_xy
        ld a,','
        call expect_p
        call arr_ref_stmt
        call emit_i             ; default action XOR
        db 5,3Eh,4,32h,low GFLG,high GFLG
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,(ttype)
        cp T_KW
        jp nz,err_syntax
        ld a,(tval)
        ld c,0
        cp K_PSET
        jr z,.set
        inc c
        cp K_PRESET
        jr z,.set
        inc c
        cp K_AND
        jr z,.set
        inc c
        cp K_OR
        jr z,.set
        inc c
        cp K_XOR
        jp nz,err_syntax
.set:   ld a,3Eh                ; ld a,n ; ld (GFLG),a
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GFLG
        call emit_w
        call next_tok
.go:    EM3 0CDh,low RT_GPUT,high RT_GPUT
        ret

st_view:                        ; VIEW (x1,y1)-(x2,y2)  or  VIEW (window = full screen)
        call at_send
        jr nz,.args
        EM3 0CDh,low RT_VIEWR,high RT_VIEWR
        ret
.args:  ld de,GX1
        ld bc,GY1
        call emit_xy_raw
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        EM3 0CDh,low RT_VIEW,high RT_VIEW
        ret

st_window:                      ; WINDOW [SCREEN] (x1,y1)-(x2,y2)  or  WINDOW (coordinates = pixels)
        call at_send
        jr nz,.args
        EM3 0CDh,low RT_WINRES,high RT_WINRES
        ret
.args:  ld c,0                  ; 1 with SCREEN: y axis downward
        ld a,K_SCREEN
        call is_kw
        jr nz,.n1
        ld c,1
        push bc
        call next_tok
        pop bc
.n1:    ld a,3Eh                ; ld a,n ; ld (GFLG),a
        call emit_a
        ld a,c
        call emit_a
        ld a,32h
        call emit_a
        ld hl,GFLG
        call emit_w
        ld de,GX1
        ld bc,GY1
        call emit_xy_raw
        ld a,'-'
        call expect_p
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
        EM3 0CDh,low RT_WINDOW,high RT_WINDOW
        ret

st_draw:                        ; DRAW "comandi"
        call expr
        call want_str
        EM3 0CDh,low RT_DRAW,high RT_DRAW
        ret

bi_coll:                        ; COLLISION: -1 if two sprites have touched
        call next_tok
        ld a,'('
        call is_p
        jr nz,.nop
        call next_tok
        ld a,')'
        call expect_p
.nop:   EM3 0CDh,low RT_COLL,high RT_COLL
        xor a
        ld (etype),a
        ret

st_sprdef:                      ; SPRITE$(n) = pattern
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        call close_paren
        ld a,'='
        call expect_p
        call expr
        call want_str
        EM3 0CDh,low RT_SPRDEF,high RT_SPRDEF
        ret

st_put:                         ; PUT SPRITE plane, (x,y)[, color[, pattern]]  or  PUT (x,y), array[, action]  |  PUT #n [, record]
        ld a,'#'
        call is_p
        jp z,st_fput
        ld a,K_SPRITE
        call is_kw
        jp nz,st_gput
        call next_tok
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call is_p
        jr z,.pt
        call emit_i             ; PUT SPRITE plane: the sprite is hidden at (0,214), outside 192 and 212 lines
        db 6,21h,0,0,22h,low GX2,high GX2
        call emit_i
        db 6,21h,214,0,22h,low GY2,high GY2
        jr .def
.pt:    call next_tok
        ld de,GX2
        ld bc,GY2
        call emit_xy_raw
.def:   call emit_defcol
        call emit_i             ; pattern = -1 (like the plane number)
        db 6,21h,0FFh,0FFh,22h,low GY1,high GY1
        ld a,','
        call is_p
        jr nz,.go
        call next_tok
        ld a,','
        call is_p
        jr z,.pat               ; colore omesso
        call expr
        call want_int
        ld hl,GCOL
        call emit_st
        ld a,','
        call is_p
        jr nz,.go
.pat:   call next_tok
        call expr
        call want_int
        ld hl,GY1
        call emit_st
.go:    EM3 0CDh,low RT_SPRPUT,high RT_SPRPUT
        ret

st_palette:                     ; PALETTE [n, rosso, verde, blu]
        call at_send
        jr nz,.args
        EM3 0CDh,low RT_PALINIT,high RT_PALINIT
        ret
.args:  call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GX2
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY2
        call emit_st
        EM3 0CDh,low RT_PALETTE,high RT_PALETTE
        ret

bi_point:                       ; POINT(x, y) -> color (-1 outside the screen)
        call next_tok
        call open_paren
        call expr
        call want_int
        ld hl,GX1
        call emit_st
        ld a,','
        call expect_p
        call expr
        call want_int
        ld hl,GY1
        call emit_st
        call close_paren
        ld a,(usewin)
        or a
        jr z,.nw
        ld hl,GX1
        ld de,RT_WX
        call emit_map
        ld hl,GY1
        ld de,RT_WY
        call emit_map
.nw:    EM3 0CDh,low RT_GPOINT,high RT_GPOINT
        xor a
        ld (etype),a
        ret

st_wend:
        ld a,B_WHILE
        call need_blk
        push hl
        BRKCHK
        pop hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,0C3h
        call emit_jabs
        ld a,B_WHILE
        call need_blk
        inc hl
        inc hl
        inc hl
        call patch_chain
        ld hl,nblk
        dec (hl)
        ret

; ---------------------------------------------------------------- runtime e caricatore inclusi
ldr_img: INCBIN "build/ldr.bin"
ldr_size equ $-ldr_img
comend:
        IFDEF ROMMODE
        ASSERT comend <= SRC
        ELSE
        ASSERT comend < LABT
        ENDIF
        IFDEF ROMMODE
        SAVEBIN "build/qbcr.com",0100h,comend-0100h
        ELSE
        IFDEF BINMODE
        SAVEBIN "build/qbcb.com",0100h,comend-0100h
        ELSE
        SAVEBIN "build/qbc.com",0100h,comend-0100h
        ENDIF
        ENDIF
