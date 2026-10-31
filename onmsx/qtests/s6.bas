' SELECT CASE su stringhe
DIM w$(6)
w$(0) = "apple": w$(1) = "Banana": w$(2) = "kiwi": w$(3) = "melon"
w$(4) = "zebra": w$(5) = "": w$(6) = "aardvark"
FOR i = 0 TO 6
  SELECT CASE w$(i)
    CASE "apple"
      PRINT "A";
    CASE "kiwi", "melon"
      PRINT "KM";
    CASE "n" TO "zzz"
      PRINT "R";
    CASE IS < "a"
      PRINT "low";
    CASE ELSE
      PRINT "?";
  END SELECT
  PRINT i
NEXT i
PRINT kind$("x"); kind$("y")
END

FUNCTION kind$(s$)
  SELECT CASE s$
    CASE "x": kind$ = "ex"
    CASE ELSE
      kind$ = "other"
  END SELECT
END FUNCTION
