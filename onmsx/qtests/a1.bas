' array come parametri e UBOUND
DIM v(5), w$(2)
FOR i = 0 TO 5 : v(i) = (i + 1) * 10 : NEXT i
w$(0) = "x" : w$(1) = "yy" : w$(2) = "zzz"
PRINT sum(v(), 6)
fill v(), 7
PRINT v(0); v(5)
PRINT cat$(w$())
PRINT top(v())
CALL show(v())
PRINT UBOUND(v); UBOUND(w$)
END

FUNCTION sum(a(), n)
  s = 0
  FOR i = 0 TO n - 1
    s = s + a(i)
  NEXT i
  sum = s
END FUNCTION

SUB fill(a(), vv)
  FOR i = 0 TO UBOUND(a)
    a(i) = vv
  NEXT i
END SUB

FUNCTION cat$(a$())
  r$ = ""
  FOR i = 0 TO UBOUND(a$)
    r$ = r$ + a$(i)
  NEXT i
  cat$ = r$
END FUNCTION

FUNCTION top(a())
  top = UBOUND(a) + inner(a())
END FUNCTION

FUNCTION inner(b())
  inner = b(2)
END FUNCTION

SUB show(a())
  PRINT "n="; UBOUND(a) + 1; "first="; a(0)
END SUB
