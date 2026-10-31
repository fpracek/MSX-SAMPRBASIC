' SCREEN 2 (MSX1): primitive, riempimento e testo
COLOR 15, 0
SCREEN 2
CLS
PSET (10, 10), 7
LINE (0, 0)-(100, 0), 5
LINE (20, 30)-(40, 50), 6, BF
LINE (60, 30)-(80, 50), 9, B
CIRCLE (128, 100), 30, 9
PRESET (10, 10)
x = POINT(30, 40)
IF x = 6 THEN PSET (200, 10), 11
LOCATE 20, 2
PRINT "Hi";
