' WINDOW: coordinate logiche con origine al centro e asse y verso l'alto (SCREEN 5)
COLOR 15, 0
SCREEN 5
CLS
WINDOW (-100, -100)-(100, 100)
PSET (0, 0), 7
LINE (-100, -100)-(100, -100), 5
LINE (-100, 100)-(100, 100), 6
CIRCLE (0, 0), 50, 9
x = POINT(0, 0)
IF x = 7 THEN PSET (-90, 90), 11
WINDOW
PSET (10, 10), 12
