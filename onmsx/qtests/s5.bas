' i temporanei si rilasciano; confronti fra stringhe
FOR i = 1 TO 2000
  a$ = STR$(i) + "-" + CHR$(65)
  IF LEN(a$ + a$) > 100 THEN PRINT "leak?"
NEXT i
k = 0
WHILE LEN(STR$(k) + "x") < 5
  k = k + 1
WEND
PRINT a$; k
x$ = "b"
PRINT (x$ = "b"); (x$ <> "b"); (x$ < "c"); (x$ > "a"); (x$ <= "b"); (x$ >= "c")
