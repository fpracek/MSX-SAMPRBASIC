' SamPr Basic - grafica
COLOR 15, 1
SCREEN 5
CLS
FOR i = 0 TO 15
  LINE (i * 16, 0)-(i * 16 + 15, 40), i, BF
NEXT i
CIRCLE (128, 120), 60, 15
LINE (20, 200)-(236, 100), 10
PSET (128, 120), 4
