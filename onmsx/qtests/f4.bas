' chiusura automatica a fine programma, VAL da file, riga vuota, EOF su file vuoto
OPEN "T4.TXT" FOR OUTPUT AS #1
PRINT #1, "12"
PRINT #1, ""
PRINT #1, "  -5 , 3 "
CLOSE #1
OPEN "T4E.TXT" FOR OUTPUT AS #2
CLOSE #2
OPEN "T4E.TXT" FOR INPUT AS #2
PRINT EOF(2)
CLOSE #2
OPEN "T4.TXT" FOR INPUT AS #1
INPUT #1, a
LINE INPUT #1, e$
INPUT #1, b, c
PRINT a; LEN(e$); b; c; EOF(1)
OPEN "T4Z.TXT" FOR OUTPUT AS #3
PRINT #3, "bye"
