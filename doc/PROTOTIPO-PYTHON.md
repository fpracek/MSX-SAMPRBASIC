# MSXQB - cross prototype (Python -> Z80) - historical, superseded by SamPr Basic

QuickBASIC-style environment for MSX2: this is the prototype that fixes the language, runtime
and codegen conventions. The compiler is one-pass with direct emission (no AST),
so that it can be rewritten in Z80 for the real IDE.

    python build.py tests\t1.bas      # compiles, assembles, runs in openMSX (NMS-8250), compares with t1.exp

Files: `qbc.py` (compiler), `runtime.asm` (runtime ~1 KB, 16K ROM at 4000h), `build.py` (harness),
`tests/t1..t5` (.bas + .exp, t5 uses `.keys` to type the input).

## Language v0
- Types: 16-bit signed INTEGER (default), STRING (`$`, max 255). No floats: `/` is integer division.
- `PRINT` (`;` `,`, numbers with leading space/sign and trailing space as in QB), `INPUT ["p";] v`, `CLS`, `LOCATE r,c`, `COLOR f,b`
- `IF/ELSEIF/ELSE/END IF` (block and single-line), `FOR/NEXT` (constant STEP), `WHILE/WEND`,
  `DO [WHILE|UNTIL]/LOOP [WHILE|UNTIL]`, `SELECT CASE` (values, `a TO b`, `IS op x`, `ELSE`), `EXIT FOR/DO/SUB/FUNCTION`
- `GOTO/GOSUB/RETURN` with labels or line numbers, `END`, `STOP`
- `SUB/FUNCTION` with by-value parameters, locals, recursion, `SHARED`, `CALL`, `DECLARE` (ignored: signatures are prescanned)
- `DIM a(n)` (global integer arrays, with bounds checking), `CONST`
- Operators: `+ - * / \ MOD AND OR XOR NOT = <> < > <= >=` and string concatenation/comparison
- Functions: `LEN ASC VAL ABS SGN RND(n) CHR$ STR$ LEFT$ RIGHT$ MID$ INKEY$ TIMER PEEK VPEEK INP`
- MSX statements: `POKE VPOKE OUT SLEEP(frames) RANDOMIZE`

## Addressing modes (user's choice)
First line of the source (or IDE setting, `qbc.py in out [mode]`):
- `OPTION NUMBERED` — classic BASIC style: every line has a number, lines are sorted by number
  (duplicates = error), `GOTO/GOSUB/THEN` only with numbers, no labels.
- `OPTION LABELS` — QuickBASIC style: `name:` and `GOTO name`; line numbers are an error.
- `OPTION MIXED` (default) — both. In all modes a jump to a nonexistent line/label is a compile error
  reported with the source line. `IF x THEN label` is allowed as in QB.
Tests: `tests/t6` (numbered, out-of-order lines), `tests/t7` (labels), `tests/negative.py` (9 expected errors).

## Codegen conventions
- HL accumulator; left operand on the stack, right in HL, `pop de`. Booleans -1/0.
- String = pointer to `[len][data]`. String variables = fixed 256-byte buffers (globals in RAM, locals in the frame).
  Temporaries on a bump heap; every statement that creates any saves/restores `heapp` (no GC needed).
  A string FUNCTION copies its result to the heap on exit.
- SUB/FUNCTION: arguments on the stack (first one deepest), IX frame, 64 bytes for integer locals
  (max 30) + 256 for each string local; cleanup is the caller's responsibility.
- FOR: the limit stays on the stack for the whole loop; test at the top.

## Known limits v0
No floats, string arrays, variable STEP, modifiable string parameters; GOTO out of FOR/SELECT
leaves stuff on the stack, integer locals are not zeroed on entry, program ≤ 16 KB (ROM).
