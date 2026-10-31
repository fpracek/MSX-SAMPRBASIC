OPTION DEBUG
A = 1
__ASM
        LD HL,(A)
        ADD HL,HL
        LD (A),HL
__ENDASM
B = A + 5
PRINT B
END
