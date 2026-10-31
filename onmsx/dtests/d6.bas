OPTION DEBUG
DIM v(4), n$(2)
g = 7
v(2) = 42
n$(1) = "ciao"
SUB prova(p, s$)
  q = p * 2
  t$ = "loc"
  PRINT q; t$; s$
END SUB
CALL prova(g + 1, "arg")
PRINT g
