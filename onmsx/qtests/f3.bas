i = 0
DO
  i = i + 1
  IF i = 7 THEN EXIT DO
LOOP
PRINT i
j = 10
DO WHILE j > 0
  j = j - 3
LOOP
PRINT j
k = 0
DO UNTIL k >= 3
  k = k + 1
LOOP
PRINT k
n = 0
DO
  n = n + 1
LOOP WHILE n < 5
PRINT n
m = 0
DO
  m = m + 2
LOOP UNTIL m > 6
PRINT m
FOR v = 0 TO 8
  SELECT CASE v
    CASE 1
      PRINT "one";
    CASE 2, 3
      PRINT "two-three";
    CASE 4 TO 6
      PRINT "four-six";
    CASE IS >= 7
      PRINT "big";
    CASE ELSE
      PRINT "?";
  END SELECT
  PRINT v
NEXT v
