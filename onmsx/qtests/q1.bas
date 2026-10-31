' blocchi IF e logica
FOR n = -2 TO 2
  IF n < 0 THEN
    PRINT "neg";
  ELSEIF n = 0 THEN
    PRINT "zero";
  ELSE
    PRINT "pos";
  END IF
  PRINT n
NEXT
a = 6 : b = 3
IF a > b AND b > 0 THEN PRINT "and ok"
IF a < b OR b = 3 THEN PRINT "or ok"
IF NOT (a = b) THEN PRINT "not ok"
PRINT 5 XOR 3; 12 AND 10; 12 OR 3; NOT 0
PRINT (a > b); (a < b); a <> b; a >= 6; a <= 5
