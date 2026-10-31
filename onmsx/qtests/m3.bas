' DIM x(n) MAPPER: array di interi nel mapper RAM
DIM x(20000) MAPPER
DIM y(9)
FOR i = 0 TO 20000 STEP 1000
  x(i) = i / 10
NEXT i
s = 0
FOR i = 0 TO 20000 STEP 1000
  s = s + x(i)
NEXT i
PRINT s; UBOUND(x)
x(8191) = 111
x(8192) = 222
x(16384) = 333
PRINT x(8191); x(8192); x(16384)
y(3) = x(8192) + 1
PRINT y(3); x(5)
x(20001) = 1
PRINT "never"
