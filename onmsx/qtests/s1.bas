' stringhe
a$ = "Hello"
b$ = "World"
c$ = a$ + ", " + b$ + "!"
PRINT c$
PRINT LEN(c$); ASC("A"); VAL("  -42x")
PRINT LEFT$(c$, 5); "|"; RIGHT$(c$, 6); "|"; MID$(c$, 8, 5); "|"; MID$(c$, 8)
PRINT CHR$(72) + CHR$(105)
PRINT STR$(123); STR$(-7); "|"
IF a$ < b$ THEN PRINT "lt"
IF a$ = "Hello" THEN PRINT "eq"
IF a$ <> b$ AND LEN(a$) = 5 THEN PRINT "ne"
IF "abc" > "abd" THEN PRINT "bad" ELSE PRINT "gt-ok"
n$ = ""
FOR i = 1 TO 5
  n$ = n$ + CHR$(64 + i)
NEXT i
PRINT n$; LEN(n$)
