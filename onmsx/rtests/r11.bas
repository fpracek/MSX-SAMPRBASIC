OPTION TARGET ASCII8
DIM a(5)
PRINT "start"
a(1) = fibo(10)
PRINT a(1)
PRINT ping$(3)
FOR i = 1 TO 3
  PRINT bounce(i);
NEXT i
PRINT
END
SEGMENT 1
FUNCTION fibo(n)
  IF n < 2 THEN
    fibo = n
  ELSE
    fibo = fibo(n - 1) + fibo(n - 2)
  END IF
END FUNCTION
FUNCTION bounce(n)
  bounce = pong(n) + 100
END FUNCTION
SEGMENT 2
FUNCTION pong(n)
  pong = n * 10
END FUNCTION
FUNCTION ping$(n)
  ping$ = "ping" + STR$(n)
END FUNCTION
