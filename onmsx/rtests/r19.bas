OPTION TARGET ROM32
x = 5
__ASM
        LD HL,(x)
        ADD HL,HL
        LD (x),HL
        LD B,3
again:  LD HL,(x)
        INC HL
        LD (x),HL
        DJNZ again
__ENDASM
PRINT x
