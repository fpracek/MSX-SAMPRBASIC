' array
DIM a(10), n$(3)
FOR i = 0 TO 10
  a(i) = i * i
NEXT i
s = 0
FOR i = 0 TO 10 : s = s + a(i) : NEXT i
PRINT "sum"; s
a(3) = a(2) + a(4)
PRINT a(3); a(10)
n$(0) = "zero" : n$(1) = "one" : n$(2) = "two" : n$(3) = n$(1) + n$(2)
PRINT n$(0); " "; n$(3); LEN(n$(3))
k = 2
PRINT a(k + 1) * 2
