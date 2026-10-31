# SamPr Basic — toolchain running entirely on MSX2

Requirement: the user works **only on physical hardware** (editor → compiler → program), with no PC.
`qbc.py` remains the reference prototype: every stage of the Z80 compiler is verified against it.

## Architecture (MSX-DOS 1/2, no EXEC)
MSX-DOS 1 has no call to execute a child program, so the three programs are
**chain-loaded** into the TPA (0100h), handing work to each other through the command line at 0080h:

    SAMPRBAS.COM  (editor)  --F5-->  saves the source, loads QBC.COM, cmdline "NAME.BAS"
    QBC.COM (compiler)         reads NAME.BAS, generates NAME.COM, writes it to disk, launches it
    NAME.COM (program)         at the end: "Press any key", reloads SAMPRBAS.COM, cmdline "NAME.BAS"

Compilation error: QBC reloads SAMPRBAS.COM with cmdline `NAME.BAS E<line> <code>`; the editor
opens the file, moves the cursor to the line and shows the message.
The chain loader (open FCB + block reads into 0100h + `jp 0100h`) is copied to high RAM
(0D000h) before the TPA is overwritten.

## Z80 compiler
- Single pass, direct emission of **machine code** (there is no assembler on the MSX), same
  strategy as `qbc.py`: HL = accumulator, left operand on the stack.
- Source at 4000h (max 16 KB), generated code at 8000h with virtual addresses starting at 0100h
  (`vpc = outp - 7F00h`), symbol tables at 0C000h. Forward jumps: fixup chains inside the code itself.
- The runtime (`rtcom.asm` -> `RT.BIN`, ORG 0100h) is read from disk by the compiler and placed at the start of the output
  (it is no longer embedded in QBC.COM: this way it can grow, and per-target variants become possible): its entry points are a table of `jp` at fixed addresses
  (`rtabi.inc`), so the compiler emits `call RT_xxx` as constants.
- Integer variables from 0C000h upward (zeroed at startup), string heap above them.

## Language extensions for ROM and mappers (to be implemented in later stages)
Syntax decided now, implementation by stages:
- `OPTION TARGET COM | ROM16 | ROM32 | ASCII8 | ASCII16 | KONAMI | SCC`  (default COM)
  For ROM targets the compiler emits a cartridge (`NAME.ROM`) with an `AB` header, slot
  startup code (enables page 2) and the runtime in segment 0.
- `SEGMENT n` — from here on the code goes into segment n (16K for ASCII16, 8K for ASCII8/KONAMI/SCC);
  segment 0 is fixed. Routines in different segments are called with `CALL FAR name`: the
  compiler generates a trampoline in the fixed segment that switches bank, calls and restores.
- `BANK(n)` / `SETBANK page, n` — direct access to bank switching (register addresses depend on the target:
  ASCII8 6000/6800/7000/7800, ASCII16 6000/7000, KONAMI 6000/8000/A000, SCC 5000/7000/9000/B000).
- `DATA`/`INCBIN "file"` in a data segment (tiles, music).
- RAM mapper (`MAPPER`): `MAPPERSEGS` (number of segments, 0 if absent), `SETSEG page, n` (ports FCh–FFh),
  `MGET(seg, offs)` / `MPUT seg, offs, v`; `DIM x(n) MAPPER` places the array in mapper RAM if
  present. The compiler detects the mapper on the fly (writing/reading the ports, with
  fallback to the no-mapper behavior).

## Stages
1. **Stage 1** (this one): lexer, integer expressions, PRINT, assignments, IF/ELSEIF/ELSE,
   FOR/NEXT, WHILE/WEND, GOTO/GOSUB/RETURN (labels or numbers), CLS, LOCATE, F5 chain, errors reported on the source line.
2a. **Done**: strings, arrays (integer and string), INPUT, DIM, built-in functions, POKE.
2b. **Done**: SUB/FUNCTION (parameters, locals, recursion, SHARED, EXIT), CALL, DECLARE, DO/LOOP, SELECT CASE.
2c. **Done**: CONST, COLOR, RANDOMIZE, VPOKE/VPEEK, OUT/INP, SLEEP, STOP.
2d. **Done**: arrays as parameters (by reference) and UBOUND.
2e. **Done**: SELECT CASE on strings.
3a. **Done**: bitmap graphics SCREEN 5-8 (PSET/PRESET/POINT/LINE/CIRCLE).
3b. **Done**: PAINT, PRINT/INPUT/LOCATE/CLS in graphics modes, PALETTE.
3c. **Done**: sprites (mode 2, SPRITE$, PUT SPRITE, sizes).
3d. **Done**: GET/PUT of areas, DRAW, COLLISION.
3e. **Done**: SCREEN 2 (primitives, text, sprites), sprites in SCREEN 1-3, CIRCLE with arc/ellipse, VIEW. **Graphics chapter closed**
    (SCREEN 4 and full WINDOW were added later; SCREEN 3 and graphics in SCREEN 1/3 remain out).
3f. Sound and files.
4. **Done**: ROM target + `SEGMENT`/automatic far calls (ASCII8/16, Konami, SCC), `INCBIN`, `SETBANK`/`DATAWIN`, `VCOPY`; dedicated compiler QBCR.COM (same source, `-DROMMODE`).
5. **Done**: RAM mapper (MAPPERSEGS, MALLOC/MFREE, MGET/MPUT/MREAD/MWRITE, VARPTR); `DIM x(n) MAPPER` and BSAVE/BLOAD (stage 20).
