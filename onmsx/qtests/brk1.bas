OPTION BREAK
FOR i = 1 TO 3 : n = n + 1 : NEXT i
DO : n = n + 1 : LOOP UNTIL n > 5
WHILE n < 9 : n = n + 1 : WEND
GOTO fin
n = 0
fin:
PRINT n
