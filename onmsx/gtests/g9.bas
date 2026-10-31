' sprite 16x16 (modo sprite 2)
COLOR 15, 0
SCREEN 5, 2
s$ = ""
FOR i = 1 TO 32 : s$ = s$ + CHR$(i) : NEXT i
SPRITE$(1) = s$
PUT SPRITE 3, (100, 50), 9, 1
PUT SPRITE 4, (-10, 20), 5, 1
PUT SPRITE 5, (300, 20), 2, 1
PUT SPRITE 6, (20, 30)
