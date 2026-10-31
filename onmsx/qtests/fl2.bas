DIM v!(5)
v!(2) = 1.5
v!(3) = 2
k = 4
v!(k) = 2.25
FOR i = 0 TO 5
  PRINT v!(i);
NEXT i
PRINT
FOR i = 0 TO 5
  v!(i) = i * 0.5
NEXT i
FOR i = 0 TO 5
  PRINT v!(i);
NEXT i
