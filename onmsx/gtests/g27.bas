' pagina 1 con SCREEN 7 (64 KB per pagina): grafica, testo, PAINT e GET/PUT sulla pagina attiva
DIM a(40)
COLOR 15, 0
SCREEN 7
SET PAGE 0, 1
CLS
PSET (10, 10), 9
LINE (100, 50)-(140, 90), 4, B
PAINT (120, 70), 6, 4
LOCATE 21, 3
PRINT "AB";
GET (100, 50)-(110, 52), a
PUT (300, 150), a
SET PAGE 0, 0
PSET (10, 10), 3
