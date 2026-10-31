' file ad accesso casuale: OPEN ... LEN, FIELD, LSET, RSET, MKI$, CVI, PUT #, GET #, LOF
OPEN "R5.DAT" AS #1 LEN = 20
FIELD #1, 10 AS n$, 6 AS c$, 4 AS z$
FOR i = 1 TO 5
  LSET n$ = "name" + STR$(i)
  RSET c$ = STR$(i * 100)
  LSET z$ = MKI$(i * 1000)
  PUT #1, i
NEXT i
PRINT LOF(1)
GET #1, 3
PRINT n$; "|"; c$; "|"; CVI(z$)
GET #1, 5
PRINT n$; "|"; c$; "|"; CVI(z$)
LSET n$ = "changed"
PUT #1, 2
CLOSE #1
OPEN "R5.DAT" AS #2 LEN = 20
FIELD #2, 10 AS a$, 6 AS b$, 4 AS d$
GET #2, 2
PRINT a$; "|"; b$; "|"; CVI(d$)
GET #2
PRINT a$; "|"; b$
PRINT LOF(2)
CLOSE
KILL "R5.DAT"
