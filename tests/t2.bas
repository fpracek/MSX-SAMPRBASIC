a$ = "Hello"
b$ = "World"
c$ = a$ + ", " + b$ + "!"
PRINT c$
PRINT LEN(c$); LEFT$(c$, 3); RIGHT$(c$, 4); MID$(c$, 8, 5)
PRINT STR$(42) + "|" + STR$(-7)
PRINT VAL("123") + VAL(" -45")
PRINT CHR$(65) + CHR$(66); ASC("A")
IF a$ < b$ THEN PRINT "lt"
IF a$ = "Hello" THEN PRINT "eq"
FOR i = 1 TO 1000
  t$ = a$ + STR$(i)
NEXT i
PRINT t$
