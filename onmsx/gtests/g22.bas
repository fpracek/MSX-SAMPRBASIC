' SCREEN 4 (grafica 3 dell'MSX2): primitive come lo SCREEN 2, sprite in modo 2, palette
COLOR 15, 0
SCREEN 4, 0
CLS
PALETTE 3, 7, 0, 7
LINE (10, 10)-(60, 10), 5
LINE (20, 30)-(40, 50), 6, BF
CIRCLE (128, 100), 30, 9
LOCATE 20, 2
PRINT "Hi";
SPRITE$(1) = CHR$(255) + CHR$(129) + CHR$(129) + CHR$(129) + CHR$(129) + CHR$(129) + CHR$(129) + CHR$(255)
PUT SPRITE 2, (100, 60), 7, 1
