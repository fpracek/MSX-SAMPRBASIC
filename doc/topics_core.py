# -*- coding: utf-8 -*-
"""Contents: core language (structure, flow, data, text, functions). Each entry: T(names, category, syntax, description, example, see, availability)."""

TOPICS = []


def T(names, cat, syn, desc, ex=None, see=None, avail=None):
    if isinstance(names, str):
        names = [names]
    TOPICS.append(dict(names=names, cat=cat, syn=syn if isinstance(syn, list) else [syn], desc=desc.strip(), ex=ex.strip('\n') if ex else None,
                       see=see or [], avail=avail or 'MSX1 and MSX2'))


# ------------------------------------------------------------------ program structure
C = 'Program structure'
T(['REM', "'"], C, ["REM comment", "' comment"],
  "Comment: the rest of the line is ignored. The apostrophe can also be placed after a statement, on the same line.",
  'REM this is a comment\nPRINT "hello"   \' so is this', ['PRINT'])
T(['LABELS', 'LINENUMBERS'], C, ["name:", "10 PRINT \"x\""],
  "A program can use labels (`name:` alone on a line or in front of a statement) and/or line numbers. GOTO, GOSUB and the "
  "RESTORE reset accept either. The mode is chosen with OPTION: NUMBERED (numbers only, sorted by number), "
  "LABELS (labels only) or MIXED (default, both). Label names follow the same rules as variable names. "
  "Several statements on the same line are separated by colons.",
  'start:\n  PRINT "a" : PRINT "b"\n  GOTO done\n  PRINT "never"\ndone:\n  PRINT "end"', ['OPTION', 'GOTO', 'GOSUB'])
T(['TYPES', 'VARIABLES', 'NAMES'], C, ["a   a$   a(10)   a$(10)"],
  "There are two types: signed 16-bit integers (-32768 to 32767) and strings (up to 255 characters). The name of a string variable "
  "ends with `$`; `A` and `A$` are distinct variables. The `%` suffix is accepted and ignored (`A%` is `A`). Names are not case "
  "sensitive; the first 11 characters plus the suffix are significant. Undeclared variables are 0 or the "
  "empty string. Numeric values: decimal, hexadecimal `&H1F`, binary `&B101`. The \"true\" value of a comparison is -1, \"false\" is 0.",
  'n = &HFF\nb = &B1010\nPRINT n; b\nPRINT 3 > 2; 3 < 2', ['DIM', 'CONST', 'OPERATORS'])
T(['OPERATORS', 'AND', 'OR', 'XOR', 'NOT', 'MOD'], C, ["+  -  *  /  \\  MOD", "=  <>  <  >  <=  >=", "NOT  AND  OR  XOR"],
  "Arithmetic: `+ - * /` and `\\` (integer division, `/` between integers too) and `MOD` (remainder). Comparisons: `= <> < > <= >=` (also between strings, "
  "in alphabetical order). Bitwise logical operators on integers: `NOT AND OR XOR`. `+` concatenates strings. When in doubt about "
  "precedence use parentheses: arithmetic operators come first, then comparisons, then logical ones. Speed: a multiplication by a constant power of two (`x * 8`) compiles to shifts (a few microseconds), any other `*` costs about 350 us and `\` or `/` about 630 us: in time-critical loops use shifts, additions or lookup tables.",
  'PRINT 7 \\ 2; 7 MOD 2\nPRINT 5 AND 3; 5 OR 3; 5 XOR 3\nPRINT "ab" + "cd"; "a" < "b"', ['TYPES'])
T('CONST', C, ["CONST name = [-]number {, name = number}"],
  "Defines numeric constants. They can be used in expressions and as the size in DIM; assigning a value to a constant is an error.",
  'CONST max = 5, base = 100\nDIM a(max)\na(max) = base + 1\nPRINT a(5)', ['DIM'])
T('LET', C, ["[LET] variable = expression", "[LET] array(i) = expression"],
  "Assigns a value to a variable or to an array element. The word LET is optional. The type of the expression must match that "
  "of the variable (otherwise error 14: type mismatch).",
  'LET a = 5\nb$ = "hello"\nc = a * 2\nPRINT b$; c', ['DIM'])
T(['END', 'STOP'], C, ["END", "STOP"],
  "Ends the program. In a .COM program it shows \"Press any key..\" and waits for a key (then returns to the editor if it was started from it, to the DOS prompt if you ran NAME.COM yourself); in a cartridge it waits for a "
  "key and restarts the machine. At the end of the source the program ends by itself. In a program STOP is the same as END (there is no "
  "interactive debugger: see OPTION DEBUG). With a second word, END also closes blocks: END IF, END SUB, END FUNCTION, END SELECT.",
  'PRINT "start"\nEND\nPRINT "never"', ['DEBUG'])
T('DECLARE', C, ["DECLARE SUB name(...)", "DECLARE FUNCTION name(...)"],
  "Accepted for compatibility and ignored: SUB and FUNCTION signatures are read by a pre-scan of the source, so a routine can be "
  "called before it is defined.", None, ['SUB', 'FUNCTION'])

# ------------------------------------------------------------------ flow
C = 'Flow control'
T(['IF', 'THEN', 'ELSE', 'ELSEIF', 'END IF'], C,
  ["IF condition THEN statement [ELSE statement]", "IF condition THEN", "  ...", "[ELSEIF condition THEN", "  ...]", "[ELSE", "  ...]", "END IF"],
  "Executes statements depending on a condition (true if nonzero). Single-line form: `IF a > 3 THEN PRINT \"yes\" ELSE PRINT \"no\"`. "
  "Block form: `IF ... THEN` at the end of a line, any number of `ELSEIF`, an optional `ELSE` and `END IF`. Blocks can be nested.",
  'n = 5\nIF n > 9 THEN\n  PRINT "big"\nELSEIF n > 3 THEN\n  PRINT "medium"\nELSE\n  PRINT "small"\nEND IF', ['SELECT CASE', 'OPERATORS'])
T(['FOR', 'NEXT', 'TO', 'STEP'], C, ["FOR variable = start TO end [STEP step]", "  ...", "NEXT [variable]"],
  "Counting loop. STEP is an integer constant, possibly negative; if omitted it is 1. The loop is not executed if the initial value already "
  "exceeds the final one. `EXIT FOR` leaves the loop. Loops can be nested.",
  'FOR i = 1 TO 10 STEP 3\n  PRINT i;\nNEXT i\nPRINT\nFOR j = 3 TO 1 STEP -1\n  PRINT j;\nNEXT j', ['EXIT'])
T(['WHILE', 'WEND'], C, ["WHILE condition", "  ...", "WEND"],
  "Repeats the block as long as the condition is true (tested at the start). `EXIT WHILE` leaves the loop.",
  'n = 3\nWHILE n > 0\n  PRINT n;\n  n = n - 1\nWEND', ['DO', 'EXIT'])
T(['DO', 'LOOP', 'UNTIL'], C, ["DO [WHILE|UNTIL condition]", "  ...", "LOOP [WHILE|UNTIL condition]"],
  "Loop with the test at the start (condition after DO) or at the end (after LOOP), or without a condition (infinite loop, to be left with "
  "`EXIT DO`). UNTIL repeats until the condition becomes true.",
  'n = 0\nDO\n  n = n + 1\nLOOP UNTIL n >= 4\nPRINT n', ['WHILE', 'EXIT'])
T('EXIT', C, ["EXIT FOR | EXIT WHILE | EXIT DO", "EXIT SUB | EXIT FUNCTION"],
  "Immediately leaves the current loop (FOR, WHILE, DO) or routine (SUB, FUNCTION).",
  'FOR i = 1 TO 100\n  IF i * i > 50 THEN EXIT FOR\nNEXT i\nPRINT i', ['FOR', 'DO'])
T(['SELECT CASE', 'SELECT', 'CASE', 'END SELECT'], C,
  ["SELECT CASE expression", "  CASE value {, value | from TO to}", "  CASE IS operator value", "  CASE ELSE", "END SELECT"],
  "Chooses among several alternatives based on an integer or string value. A CASE can list values (`CASE 2, 3`), ranges "
  "(`CASE 4 TO 6`), comparisons (`CASE IS >= 7`); with strings also `CASE \"a\", \"b\" TO \"m\"`. The type of the values must match that "
  "of the selector. `CASE ELSE` catches the rest.",
  'n = 5\nSELECT CASE n\n  CASE 1, 2\n    PRINT "few"\n  CASE 3 TO 6\n    PRINT "medium"\n  CASE IS > 6\n    PRINT "many"\n  CASE ELSE\n    PRINT "zero"\nEND SELECT', ['IF'])
T('GOTO', C, ["GOTO label | number"], "Jumps to the given label or line number. In a multi-segment cartridge the target must be in the same segment.",
  'i = 0\nagain:\n  i = i + 1\n  PRINT i;\n  IF i < 3 THEN GOTO again', ['GOSUB', 'LABELS'])
T(['GOSUB', 'RETURN'], C, ["GOSUB label | number", "RETURN"],
  "GOSUB calls a subroutine that starts at the label (or line number) and RETURN goes back to the statement after the call. For routines with "
  "parameters and local variables use SUB and FUNCTION.",
  'GOSUB greet\nPRINT "end"\nEND\ngreet:\n  PRINT "hello"\n  RETURN', ['SUB', 'CALL'])
T(['SUB', 'END SUB'], C, ["SUB name [(parameter {, parameter})]", "  ...", "END SUB"],
  "Defines a procedure. Parameters are passed by value (integers or strings, with `$`); an array is passed by reference by writing "
  "`a()`. Variables used inside the SUB are local, except those declared with SHARED. It can be called with CALL or directly by name. "
  "Recursion is allowed. At most 20 routines, 8 parameters each.",
  'SUB addup(a, b)\n  PRINT a + b\nEND SUB\nCALL addup(3, 4)\naddup 5, 6', ['FUNCTION', 'CALL', 'SHARED'])
T(['FUNCTION', 'END FUNCTION'], C, ["FUNCTION name[$] [(parameters)]", "  ...", "  name = value", "END FUNCTION"],
  "Like a SUB but returns a value: it is assigned to the function name (`name = ...` or `name$ = ...` for strings). It is used "
  "inside expressions. Recursion allowed.",
  'FUNCTION twice(n)\n  twice = n * 2\nEND FUNCTION\nPRINT twice(21)', ['SUB', 'CALL'])
T('CALL', C, ["CALL name [(arguments)]", "CALL FAR name [(arguments)]"],
  "Calls a SUB. The parentheses are optional. `CALL FAR` forces a call between segments of a cartridge (normally the compiler "
  "recognizes this by itself). CALL calls a SUB, not a label: for labels use GOSUB.",
  'SUB p(x$)\n  PRINT x$\nEND SUB\nCALL p("hello")', ['SUB', 'SEGMENT'])
T('SHARED', C, ["SHARED variable {, variable}"],
  "Inside a SUB or FUNCTION, declares that the given names are the global variables (and not local variables with the same name).",
  'total = 0\nSUB addto(n)\n  SHARED total\n  total = total + n\nEND SUB\naddto 5\naddto 7\nPRINT total', ['SUB', 'DIM'])

# ------------------------------------------------------------------ data
C = 'Data and arrays'
T('DIM', C, ["DIM name(n) [, name$(m) ...]", "DIM name(n) MAPPER"],
  "Declares arrays of integers or strings with indexes from 0 to n (so n+1 elements). Indexes are checked: out of range the program "
  "stops with an error. `UBOUND(a)` gives the last index. Arrays are passed to SUB and FUNCTION by writing `a()`. With MAPPER (only `.COM` and "
  "cartridges with a RAM mapper) an integer array lives in the RAM mapper, up to 32768 elements.",
  'DIM a(4), n$(2)\nFOR i = 0 TO 4\n  a(i) = i * i\nNEXT i\nn$(1) = "one"\nPRINT a(3); n$(1); UBOUND(a)', ['UBOUND', 'MALLOC'])
T('UBOUND', C, ["UBOUND(array)"], "Returns the maximum index of an array (even when it is a routine parameter).",
  'DIM v(9)\nPRINT UBOUND(v)', ['DIM'])
T(['DATA', 'READ', 'RESTORE'], C, ["DATA value {, value}", "READ variable {, variable}", "RESTORE [label]"],
  "DATA holds values (integers or strings in quotes); READ reads them in order into the given variables; RESTORE moves reading back to the "
  "first DATA or to the one immediately following the given label. Reading past the last DATA is an error.",
  'DATA 10, -20, "hello"\nREAD a, b, s$\nPRINT a; b; s$\nRESTORE\nREAD c\nPRINT c', ['DIM'])
T(['MKI$', 'CVI'], C, ["MKI$(n)", "CVI(string$)"],
  "MKI$ converts an integer into a 2-byte string; CVI does the opposite. They are used with random-access files (FIELD fields).",
  'a$ = MKI$(1000)\nPRINT LEN(a$); CVI(a$)', ['FIELD'])

# ------------------------------------------------------------------ text
C = 'Text and keyboard'
T(['PRINT', '?'], C, ["PRINT [expression {; | , expression}] [;]", "? expression", "PRINT #n, ..."],
  "Writes to the screen. The semicolon leaves the cursor right after the last item; the comma advances to the next tab zone "
  "(columns that are multiples of 14). Without a trailing semicolon it moves to a new line. Numbers are preceded by a sign (a space if positive) and "
  "followed by a space; strings are written as they are. `?` is an abbreviation of PRINT. With `#n,` it writes to the open file.",
  'PRINT "sum:"; 3 + 4\nPRINT 1, 2, 3\nPRINT "a";\nPRINT "b"', ['LOCATE', 'INPUT', 'OPEN'])
T('INPUT', C, ['INPUT ["text" ;|,] variable', "INPUT #n, variable {, variable}"],
  "Reads a line from the keyboard into the variable (integer or string). With the text and the semicolon the text is followed by \"? \"; with the "
  "comma it is not. Confirm with Enter; Backspace deletes. A non-numeric value in an integer variable gives 0. With `#n,` it reads from the file.",
  'INPUT "Name"; n$\nINPUT "Age", e\nPRINT "Hello "; n$; e + 1', ['LINE INPUT', 'INKEY$'])
T('LINE INPUT', C, ["LINE INPUT [#n,] variable$"],
  "Reads a whole line (spaces and commas included) into a string variable; from the keyboard or, with `#n,`, from a file.",
  'LINE INPUT a$\nPRINT "[" ; a$ ; "]"', ['INPUT'])
T('CLS', C, ["CLS"], "Clears the screen and moves the cursor to the top left (on the active page in SCREEN 5-8).", 'CLS\nPRINT "clean"', ['LOCATE'])
T('LOCATE', C, ["LOCATE row, column"], "Positions the text cursor. Row and column start at 1.",
  'CLS\nLOCATE 5, 10\nPRINT "here"', ['PRINT', 'CLS'])
T('COLOR', C, ["COLOR foreground[, background[, border]]", "COLOR = (n, r, g, b)", "COLOR = RESTORE", "COLOR SPRITE(n) = color", "COLOR SPRITE$(n) = colors$"],
  "Sets the foreground, background and border colors with numbers from 0 to 15 (in SCREEN 8 the raw value 0-255). Without the third value the border takes the background color. `COLOR = (n,r,g,b)` redefines a "
  "palette color (r, g, b from 0 to 7; MSX2) and `COLOR = RESTORE` restores the default palette. For COLOR SPRITE see sprites.",
  'COLOR 15, 4\nCLS\nPRINT "white on blue"', ['PALETTE', 'SCREEN'])
T('INKEY$', C, ["INKEY$"], "Returns the character of the key pressed, or the empty string if there is none: it does not wait.",
  'DO\n  k$ = INKEY$\nLOOP WHILE k$ = ""\nPRINT "key:"; ASC(k$)', ['INPUT', 'STICK'])

# ------------------------------------------------------------------ functions
C = 'Numeric and string functions'
T('LEN', C, ["LEN(string$)"], "Length of a string.", 'PRINT LEN("hello")', ['MID$'])
T('ASC', C, ["ASC(string$)"], "Code of the first character of the string (0 if it is empty).", 'PRINT ASC("A")', ['CHR$'])
T('CHR$', C, ["CHR$(code)"], "One-character string with the given code (0-255).", 'PRINT CHR$(72); CHR$(105)', ['ASC'])
T('VAL', C, ["VAL(string$)"], "Numeric value of a string; stops at the first invalid character, 0 if it does not start with a number.",
  'PRINT VAL("42") + 1', ['STR$'])
T('STR$', C, ["STR$(number)"], "Decimal representation of the number as a string (with a leading space for positive numbers).",
  'a$ = STR$(7)\nPRINT LEN(a$); a$', ['VAL'])
T('LEFT$', C, ["LEFT$(string$, n)"], "The first n characters of the string.", 'PRINT LEFT$("abcdef", 3)', ['RIGHT$', 'MID$'])
T('RIGHT$', C, ["RIGHT$(string$, n)"], "The last n characters of the string.", 'PRINT RIGHT$("abcdef", 2)', ['LEFT$', 'MID$'])
T('MID$', C, ["MID$(string$, start [, n])"], "Substring: starts at character `start` (the first is 1) and takes n characters (up to the end if n is missing).",
  'PRINT MID$("abcdef", 2, 3)\nPRINT MID$("abcdef", 4)', ['LEFT$', 'RIGHT$', 'LEN'])
T('ABS', C, ["ABS(n)"], "Absolute value.", 'PRINT ABS(-7)', ['SGN'])
T('SGN', C, ["SGN(n)"], "Sign: -1, 0 or 1.", 'PRINT SGN(-9); SGN(0); SGN(4)', ['ABS'])
T(['RND', 'RANDOMIZE'], C, ["RND(n)", "RANDOMIZE seed"],
  "RND(n) returns a pseudo-random number from 0 to n-1. RANDOMIZE sets the seed of the sequence: the same seed gives the same sequence.",
  'RANDOMIZE 7\nFOR i = 1 TO 5\n  PRINT RND(100);\nNEXT i', ['TIMER'])
T('TIMER', C, ["TIMER"], "Video frame counter (1/50 or 1/60 of a second) read from JIFFY; 16-bit, wraps around to zero.",
  't = TIMER\nSLEEP 25\nPRINT TIMER - t', ['SLEEP'])
T('PEEK', C, ["PEEK(address)", "POKE address, value"], "PEEK reads a byte of memory; POKE writes it. 16-bit addresses (0 to 65535, also with equivalent negative values).",
  'POKE 50000, 77\nPRINT PEEK(50000)', ['VARPTR'])
T('POKE', C, ["POKE address, value"], "Writes a byte to memory. See PEEK.", 'POKE 50000, 12\nPRINT PEEK(50000)', ['PEEK'])
T('SLEEP', C, ["SLEEP frames"], "Waits for the given number of video frames (50 or 60 per second depending on the machine's standard).",
  'PRINT "wait"\nSLEEP 50\nPRINT "done"', ['TIMER'])
