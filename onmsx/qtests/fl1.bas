' virgola mobile
a! = 3.5
b! = 2
PRINT a! + b!
PRINT a! * b!
PRINT a! / b!
PRINT a! - 10
PRINT a! ^ 2
PRINT -a!
x = a! * 2
PRINT x
c! = x / 4
PRINT c!
PRINT 1 / 3
PRINT 1 / 3.0
PRINT SQR(2)
PRINT SIN(1); COS(1)
PRINT ATN(1) * 4
PRINT LOG(10); EXP(1)
PRINT INT(-2.5); FIX(-2.5); CINT(2.5)
PRINT STR$(1.25) + "x"
PRINT VAL!("2.5E2")
DIM v!(5)
FOR i = 0 TO 5
  v!(i) = i * 0.5
NEXT i
PRINT v!(3)
IF a! > b! THEN PRINT "gt"
IF a! = 3.5 THEN PRINT "eq"
PRINT 1E10; 1.5E-5
PRINT ABS(-2.5); SGN(-2.5); SGN(0)
