RTRAM   equ 0C090h
FA      equ RTRAM+210h
FB      equ RTRAM+216h
FT      equ RTRAM+21Ch
FS      equ RTRAM+228h
inbuf   equ RTRAM+20
        ORG 4000h
        INCLUDE "rtfloat.asm"
        INCLUDE "rtfunc.asm"
        INCLUDE "rtfconst.inc"
rt_fatal: halt
rt_ediv:  halt
rt_eifc:  halt
rt_sdup:  ret
