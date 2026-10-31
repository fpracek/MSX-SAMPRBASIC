' cicli annidati, STEP negativo, WHILE, GOSUB
FOR i = 10 TO 1 STEP -3
  PRINT i;
NEXT i
PRINT
t = 0
FOR i = 1 TO 3
  FOR j = 1 TO i
    t = t + 1
  NEXT j
NEXT i
PRINT "t="; t
k = 0
WHILE k < 5
  k = k + 2
  IF k = 4 THEN GOSUB hit
WEND
PRINT "k="; k
FOR z = 5 TO 1
  PRINT "never"
NEXT
PRINT "done"
END
hit:
  PRINT "hit4"
  RETURN
