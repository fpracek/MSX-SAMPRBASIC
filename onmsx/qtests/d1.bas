' DATA / READ / RESTORE
DIM v(3)
DATA 10, -20, "hello"
DATA 5, "w o"
READ a, b, s$
PRINT a; b; s$
READ c, t$
PRINT c; t$
RESTORE
READ a
PRINT a
RESTORE second
READ z$, n
PRINT z$; n
READ v(1), v(2)
PRINT v(1) + v(2)
GOTO fine
second:
DATA "X", 7, 100, 200
fine:
PRINT "done"
