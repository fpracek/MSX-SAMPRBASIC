g = 0
SUB suma(n)
  SHARED g
  g = n
  __ASM
          LD HL,(g)
          ADD HL,HL
          LD (g),HL
  __ENDASM
END SUB
CALL suma(21)
PRINT g
PRINT "ok"
END
