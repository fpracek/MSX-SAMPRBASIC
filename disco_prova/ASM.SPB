' Assembler Z80 in linea: __ASM ... __ENDASM
CONTA = 0
NOME$ = "ab"
__ASM
; incrementa CONTA di 2, poi di altre 5 volte
        LD HL,(CONTA)
        INC HL
        INC HL
        LD (CONTA),HL
        LD B,5
giro:   LD HL,(CONTA)
        INC HL
        LD (CONTA),HL
        DJNZ giro
        LD HL,NOME$     ; la variabile stringa e' [lunghezza][caratteri]
        LD (HL),1
        INC HL
        LD (HL),'Z'
__ENDASM
PRINT CONTA
PRINT NOME$
END
