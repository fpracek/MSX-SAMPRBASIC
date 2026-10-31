FUNCTION rep$(s$, n)
  r$ = ""
  FOR i = 1 TO n
    r$ = r$ + s$
  NEXT i
  rep$ = r$
END FUNCTION
FUNCTION add3(a, b, c)
  a = a + 1
  add3 = a + b + c
END FUNCTION
FUNCTION fib(n)
  IF n < 2 THEN fib = n ELSE fib = fib(n - 1) + fib(n - 2)
END FUNCTION
PRINT rep$("ab", 3) + "|" + rep$("-", 2)
x = 5
PRINT add3(x, 10, add3(1, 2, 3)); x
PRINT fib(15)
FOR i = 1 TO 300
  t$ = rep$("xy", 5) + rep$("z", 3)
NEXT i
PRINT t$; LEN(t$)
