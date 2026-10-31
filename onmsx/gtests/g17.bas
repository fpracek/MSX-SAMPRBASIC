' sprite 16x16 in SCREEN 1
COLOR 15, 0
SCREEN 1, 2
s$ = ""
FOR i = 1 TO 32 : s$ = s$ + CHR$(i) : NEXT i
SPRITE$(1) = s$
PUT SPRITE 3, (100, 50), 9, 1
PUT SPRITE 4, (300, 20), 2, 1
