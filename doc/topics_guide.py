# -*- coding: utf-8 -*-
"""General topics: ASM, DEBUG, editor, errors, limits, MSX1/MSX2."""
from topics_core import T

C = 'Guide'
T(['ASM', '__ASM', '__ENDASM', 'ASSEMBLER'], C, ["__ASM", "  Z80 instructions", "__ENDASM"],
  "An __ASM ... __ENDASM block (each on its own line, upper or lower case) contains documented Z80 code, written as in any assembler. "
  "Comments with `;`. Local labels `name:` (also `name EQU value`). Numbers: decimal, `$1F`, `0x1F`, `1FH`, `%101`, `101B`, `'x'`; `$` is the current address. "
  "Directives: DB/DEFB (also strings), DW/DEFW, DS/DEFS. A name that is not a local label is a global BASIC variable (`LD HL,(COUNT)`, `LD HL,NOME$`) "
  "or, in a jump, a BASIC label (`JP DONE`, `JP NZ,DONE`). JR and DJNZ only to local labels. Every register can be changed except IX "
  "(frame of SUB/FUNCTION) and the stack must be left balanced. The debugger does not stop inside the blocks. It also works in cartridges, in every file of a multi-file cartridge; code that must be always reachable (an interrupt routine) goes in file 000, the fixed segment. "
  "OPTION ASM as the first line makes the WHOLE file assembly (an assembler editor): the block ends at the end of the file, or at an optional __ENDASM; there are no BASIC variables or labels, the program starts at the first line and ends when the code runs off the end (or with `JP`/`RET` tricks of your own); DOS programs only, not cartridges. "
  "Errors: 17 syntax/operand, 18 value or jump out of range, 19 duplicate symbol or missing __ENDASM, 20 QASM.OVL not found.",
  "count = 0\n__ASM\n  ld hl,(count)\n  inc hl\n  ld (count),hl\n__ENDASM\nPRINT count", ['VARPTR', 'OPTION'])
T(['DEBUG', 'DEBUGGER'], C, ["OPTION DEBUG"],
  "Write `OPTION DEBUG` in the source and press F5: the program starts stopped at the first statement, in a text screen showing the current line, "
  "the global scalar variables with their value and the list of breakpoints. Keys: SPACE (or S, ENTER) runs one statement; R runs to the next "
  "breakpoint; B number ENTER sets or clears a breakpoint (ENTER alone = current line, 0 = clear them all); C clears all breakpoints; V next "
  "page of variables; E asks for a variable name (local, parameter, global, array element such as V(3) or N$) and shows its value; "
  "Q ends the program. Inside a SUB the local variables and parameters appear first with the > prefix. CTRL-STOP while running re-enters the debugger. "
  "The program screen stays intact. In cartridges `OPTION DEBUG` alone follows the lines only; `OPTION DEBUG GLOBALS` also shows the global variables and `OPTION DEBUG ALL` the local variables and parameters too (banked cartridges: ASCII8, ASCII16, KONAMI, SCC; the E command is not available). "
  "The tables go in the last segment, and the debugger takes about 2 KB of the fixed segment 0, so place `OPTION DEBUG` after the part of file 000 you do not need to follow: hooks are inserted only from that point and in all the other segments. Normal programs (without OPTION DEBUG) pay nothing.",
  "OPTION DEBUG\ns = 0\nFOR i = 1 TO 3\n  s = s + i\nNEXT i\nPRINT s", ['OPTION DEBUG'])
T(['EDITOR', 'MENU', 'KEYS'], C, ["Esc = menu, arrows, F1-F4"],
  "Start it with `SAMPRBAS name` (also with a path, on MSX-DOS 2). Keyboard menu: Esc opens the File menu; F1 File, F2 Edit, F3 Find, F4 Help; Run is on the right; left/right arrows change menu, up/down the items, Enter "
  "selects, a highlighted letter activates the item, Esc closes. Shortcuts: F5 compiles and runs, F6 Help on the word under the cursor, F7 help index, F8 File > Segment (changes segment). "
  "Keywords are colored (on MSX2); on MSX1 the editor has 40 columns, on MSX2 80, automatically. If nothing has changed F5 reruns the program immediately.",
  None, ['HELP'])
T(['SEGMENTS', 'MULTIFILE', 'ROMFILE', 'NAME000'], C, ["NAME000.SPB, NAME001.SPB ...", "File > Segment... (F8)"],
  "A segmented cartridge (ASCII8, ASCII16, KONAMI, SCC) is written as one file per segment: NAME000.SPB (segment 0, fixed, with the OPTIONs) and NAME001, NAME002... "
  "(5 characters + 3 digits). The compiler reads them in sequence and links them into NAME.ROM; you compile from any file with F5. The OPTIONs go only in file 000; "
  "SEGMENT is not written. A file NAMEnnn.BIN (assembler, sprites, font, data) is an already compiled segment: it is inserted as is. "
  "F8 (File > Segment...) saves the current file and opens the segment whose number you type (also without zeros); if the file does not exist, or is a .BIN, it says why and the active file does not change. "
  "Numbering starts at 0: it is the first block of the cartridge, not the BIOS.",
  None, ['SEGMENT', 'OPTION TARGET', 'EDITOR'])
T(['DIRECTORY', 'SPBHOME', 'SPBPROJ', 'FOLDERS'], C, ["SAMPRBAS \\DIR\\NAME", "SET SPBHOME=\\TOOLS"],
  "With MSX-DOS 2 the working directory is always that of the open file: source, .COM/.ROM and the program's files live in the project folder, the tools "
  "in theirs. You can give a path on the command line; File > Open navigates between folders. Environment variables: SPBHOME (tools, the folder the "
  "editor is first started from) and SPBPROJ (project). With MSX-DOS 1 there are no folders.",
  None, ['SPB', 'EDITOR'])
T(['SPB', 'FILE SPB', 'SAVE', 'OPENFILE'], C, ["SAMPRBAS name", "File > Open, File > Save As"],
  "Programs have the .SPB extension (SamPr Basic). `SAMPRBAS TEST` opens PROVA.SPB if it exists, otherwise starts with a new file already named PROVA.SPB. "
  "Open (Ctrl+O) shows a window with the .SPB files (and, with MSX-DOS 2, the folders): arrows, Enter, a letter to jump, Esc to exit. "
  "Save As (Ctrl+W) accepts at most 8 characters and adds .SPB. The compiled program is NAME.COM (or NAME.ROM).",
  None, ['EDITOR', 'COMPILING'])
T(['HELP', 'INDEX'], C, ["Help menu: Index (F7), Topic..., On word (F6), Shortcuts, About"],
  "Help reads the HELP.TXT and HELP.IDX files in the current directory. Index (F7) shows the list of topics; Topic... asks for a name (e.g. PRINT, ASM, DEBUG, "
  "OPTION); On word (F6) shows the topic for the word under the cursor. In the viewer: arrows and PgUp/PgDn scroll, Esc closes. HELP.TXT is a plain text file "
  "(38-column lines): it can be read and extended; HELP.IDX is the index generated by the gen_docs.py tool.",
  None, ['EDITOR'])
T(['ERRORS'], C, ["Error codes"],
  "1 syntax; 2 nonexistent label or line; 3 not yet supported; 4 illegal character; 5 unclosed block; 6 ELSE/END IF/NEXT/WEND without block; "
  "7 duplicate name; 8 too many variables, labels or blocks; 9 program too large; 10 source too large; 11 read error; 12 write error; "
  "13 not allowed with the chosen OPTION; 14 incompatible types or undeclared array; 15 program data too large; 16 RT.BIN not found; "
  "17-20 inline assembler. The editor reopens with the cursor on the error line.",
  None, ['LIMITS'])
T(['LIMITS'], C, ["Compiler limits"],
  "Source about 12.5 KB per file (15 KB in cartridges); program 16 KB; 96 labels; 100 variables and arrays; 20 SUB/FUNCTION (8 parameters each, 64 in total); 29 local integers (24 names in a cartridge, shared variables included) and 256 bytes per "
  "local string; 24 nested blocks; names significant to 11 characters; about 590 lines in OPTION NUMBERED; strings of 255 characters; integers from -32768 to 32767; "
  "open files: 3.",
  None, ['ERRORS'])
T(['MSX1', 'MSX2', 'COMPATIBILITY'], C, ["MSX1 / MSX2"],
  "The system detects the machine. MSX1: editor and text at 40 columns, SCREEN 0-3, no keyword colors, no graphics 5-12, palette, pages, mapper. "
  "MSX2: 80 columns, SCREEN up to 8 (10-12 on MSX2+), PALETTE, COPY, SET PAGE, 17-bit VBANK, RAM mapper. Tested with a Sony HB-75P and an MSX2 with MSX-DOS 1 and 2.",
  None, ['SCREEN'])
T(['COM', 'ROM', 'COMPILING', 'F5'], C, ["F5, QBC.COM, NAME.COM / NAME.ROM"],
  "F5 saves the source, starts the QBC.COM compiler which writes NAME.COM, and runs it; at the end of the program you return to the editor. With OPTION TARGET you get "
  "a NAME.ROM cartridge instead. Files needed on the disk: SAMPRBAS.COM, QBC.COM, RT.BIN (and RTD.BIN for debugging, QBCR.COM and RTROM.BIN for cartridges, QASM.OVL for __ASM).",
  None, ['OPTION TARGET'])
