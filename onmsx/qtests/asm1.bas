CONTA = 0
NOME$ = "ab"
__ASM
; incrementa CONTA di 2 e poi conta 5 giri
        LD HL,(CONTA)
        INC HL
        INC HL
        LD (CONTA),HL
        LD B,5
loop:   LD HL,(CONTA)
        INC HL
        LD (CONTA),HL
        DJNZ loop
        LD HL,NOME$
        LD (HL),1       ; lunghezza 1
        INC HL
        LD (HL),'Z'
        JP fine
        LD HL,0         ; saltato
        LD (CONTA),HL
__ENDASM
PRINT "mai"
fine:
PRINT CONTA
PRINT NOME$
END
