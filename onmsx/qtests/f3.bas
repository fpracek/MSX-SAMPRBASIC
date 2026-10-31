' file piu' lunghi di un record, copia tra due file, append su file lungo
OPEN "T3.TXT" FOR OUTPUT AS #1
FOR i = 1 TO 60
  PRINT #1, "line"; i
NEXT i
CLOSE #1
OPEN "T3.TXT" FOR INPUT AS #1
OPEN "T3B.TXT" FOR OUTPUT AS #2
n = 0
DO WHILE NOT EOF(1)
  LINE INPUT #1, a$
  PRINT #2, a$
  n = n + 1
LOOP
CLOSE
PRINT n; a$
OPEN "T3B.TXT" FOR APPEND AS #3
PRINT #3, "extra"
CLOSE #3
OPEN "T3B.TXT" FOR INPUT AS #1
n = 0
DO WHILE NOT EOF(1)
  INPUT #1, a$
  n = n + 1
  IF n = 30 THEN PRINT a$
LOOP
CLOSE
PRINT n; a$
KILL "T3.TXT"
KILL "T3B.TXT"
