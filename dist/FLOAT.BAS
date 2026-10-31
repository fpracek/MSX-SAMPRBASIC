' Virgola mobile: potenze, trigonometria, formattazione
r! = 2.5
PRINT "area ="; 3.14159 * r! ^ 2
PRINT "SQR(2) ="; SQR(2)
FOR a = 0 TO 90 STEP 30
  PRINT a; SIN(a * 3.14159 / 180)
NEXT a
PRINT "e ="; EXP(1); " ln10 ="; LOG(10)
DIM v!(3)
FOR i = 0 TO 3
  v!(i) = i / 3.0
  PRINT v!(i);
NEXT i
PRINT
PRINT STR$(1E10); " "; VAL!("1.5E-3")
