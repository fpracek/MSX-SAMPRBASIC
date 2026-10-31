' funzioni numeriche e di stringa varie
PRINT ABS(-5); ABS(7); SGN(-9); SGN(0); SGN(12)
POKE 49392, 77
PRINT PEEK(49392)
r = RND(10)
IF r >= 0 AND r < 10 THEN PRINT "rnd ok"
x$ = MID$("abcdef", 3, 2) + MID$("abcdef", 5) + LEFT$("xyz", 0) + RIGHT$("xyz", 9)
PRINT x$
t = TIMER
PRINT "t ok"
