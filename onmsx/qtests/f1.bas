' SUB e FUNCTION: chiamate in avanti, ricorsione, stringhe
DECLARE FUNCTION fact(n)
DECLARE SUB greet(name$, times)
PRINT fact(5); fact(1)
CALL greet("Ann", 2)
greet "Bob", 1
PRINT sq(3) + sq(4)
PRINT twice$("ab"); LEN(twice$("xyz"))
END

FUNCTION fact(n)
  IF n <= 1 THEN
    fact = 1
  ELSE
    fact = n * fact(n - 1)
  END IF
END FUNCTION

SUB greet(name$, times)
  FOR i = 1 TO times
    PRINT "Hi "; name$
  NEXT i
END SUB

FUNCTION sq(x)
  sq = x * x
END FUNCTION

FUNCTION twice$(s$)
  twice$ = s$ + s$
END FUNCTION
