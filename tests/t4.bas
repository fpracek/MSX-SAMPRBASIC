CONST MAXN = 3
x = 7
IF x < 5 THEN
  PRINT "a"
ELSEIF x < 10 THEN
  PRINT "b"
ELSE
  PRINT "c"
END IF
GOSUB sq
PRINT r
GOTO done
sq:
r = x * x
RETURN
done:
CALL loc("xy")
PRINT total(4)
FOR i = 1 TO 10
  IF i = 4 THEN EXIT FOR
NEXT i
PRINT i
PRINT 32767 + 1; 100 / 7; -7 \ 2; -7 MOD 3
d = 0
PRINT 5 \ d
PRINT "unreached"
SUB loc(p$)
  q$ = p$ + "-" + p$
  PRINT q$; MAXN
END SUB
FUNCTION total(n)
  FOR j = 1 TO n : total = total + j : NEXT j
END FUNCTION
