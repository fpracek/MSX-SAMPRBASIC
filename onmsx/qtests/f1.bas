' file di testo: PRINT#, WRITE#, LINE INPUT#, INPUT#, EOF, APPEND, KILL
OPEN "T1.TXT" FOR OUTPUT AS #1
PRINT #1, "hello"; 42
PRINT #1, "a", "b"
WRITE #1, "x,y", 7, -3
CLOSE #1
OPEN "T1.TXT" FOR INPUT AS #1
LINE INPUT #1, a$
PRINT "["; a$; "]"
LINE INPUT #1, b$
PRINT "["; b$; "]"
INPUT #1, s$, n, m
PRINT s$; n; m
PRINT EOF(1)
CLOSE #1
OPEN "T1.TXT" FOR APPEND AS #2
PRINT #2, "tail"
CLOSE
OPEN "T1.TXT" FOR INPUT AS #1
c = 0
DO WHILE NOT EOF(1)
  LINE INPUT #1, a$
  c = c + 1
  l$ = a$
LOOP
CLOSE #1
PRINT c; l$
KILL "T1.TXT"
