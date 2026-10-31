DECLARE FUNCTION fact(n)
DIM a(5)
FOR i = 0 TO 5 : a(i) = i * i : NEXT i
PRINT a(3); a(5)
PRINT fact(5)
PRINT fib(10)
CALL greet("Fausto")
x = 3
SELECT CASE x
CASE 1
  PRINT "one"
CASE 2 TO 4
  PRINT "two-four"
CASE ELSE
  PRINT "other"
END SELECT
n = 0
DO
  n = n + 1
LOOP UNTIL n >= 5
PRINT n
WHILE n > 0
  n = n - 2
WEND
PRINT n
PRINT dbl$("ab")
FOR k = 10 TO 1 STEP -4 : PRINT k; : NEXT k
PRINT
END

FUNCTION fact(n)
  IF n <= 1 THEN
    fact = 1
  ELSE
    fact = n * fact(n - 1)
  END IF
END FUNCTION
FUNCTION fib(n)
  IF n < 2 THEN fib = n ELSE fib = fib(n - 1) + fib(n - 2)
END FUNCTION
SUB greet(nm$)
  PRINT "Hi, " + nm$ + "!"
END SUB
FUNCTION dbl$(s$)
  dbl$ = s$ + s$
END FUNCTION
