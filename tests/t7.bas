OPTION LABELS
x = 0
IF x = 0 THEN saltato ELSE ancora
PRINT "no"
saltato:
PRINT "si"
GOSUB sotto
GOTO fine
sotto:
PRINT "sotto"
RETURN
ancora:
fine:
PRINT "fine"
