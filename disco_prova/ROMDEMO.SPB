' Cartuccia ASCII16 a 3 segmenti: compilala con F5 (produce ROMDEMO.ROM)
OPTION TARGET ASCII16
PRINT "Segmento 0 (fisso)"
CALL hello(7)
PRINT "doppio di 21 ="; twice(21)
END
SEGMENT 1
SUB hello(n)
  PRINT "ciao dal segmento 1:"; n
END SUB
SEGMENT 2
FUNCTION twice(x)
  twice = x * 2
END FUNCTION
