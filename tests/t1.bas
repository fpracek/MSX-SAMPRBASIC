PRINT "Hello MSX2"
a = 5 : b = 7
PRINT a + b * 2; a - b; b \ 2; 17 MOD 5; -a
FOR i = 1 TO 5
  s = s + i
NEXT i
PRINT "sum"; s
IF s > 10 THEN PRINT "big" ELSE PRINT "small"
PRINT "end"
