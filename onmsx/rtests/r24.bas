OPTION TARGET ROM_ASCII16
PRINT "main"
CALL FAR hello(3)
PRINT twice(21)
msg "ciao"
PRINT "end"
END
SEGMENT 1
SUB hello(n)
  PRINT "hello from seg1:"; n
  CALL inner(n)
END SUB
SUB inner(n)
  PRINT "inner"; n * 2
END SUB
SEGMENT 2
FUNCTION twice(x)
  twice = x * 2
END FUNCTION
SUB msg(s$)
  PRINT s$; "!"
END SUB
