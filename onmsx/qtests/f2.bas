count = 0
SUB bump(n)
  SHARED count
  local = n * 2
  count = count + local
END SUB
SUB showrev(s$)
  r$ = ""
  FOR i = LEN(s$) TO 1 STEP -1
    r$ = r$ + MID$(s$, i, 1)
  NEXT i
  PRINT r$
END SUB
FUNCTION firstneg(a)
  FOR k = 1 TO 10
    IF k * a > 20 THEN
      firstneg = k
      EXIT FUNCTION
    END IF
  NEXT k
  firstneg = -1
END FUNCTION
bump 3
bump 4
PRINT count
showrev "stressed"
PRINT firstneg(7); firstneg(1)
