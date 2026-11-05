# -*- coding: utf-8 -*-
"""Contents: graphics, sprites, sound, files, memory, cartridges, options."""
from topics_core import T

M2 = 'MSX2 only'

# ------------------------------------------------------------------ screen and graphics
C = 'Screen and graphics'
T('SCREEN', C, ["SCREEN mode [, sprite size]"],
  "Selects the video mode. MSX1: 0 (40-column text), 1 (32-column color text), 2 (256x192 graphics), 3 (64x48 blocks). MSX2 adds 4, 5 (256x212, 16 colors), "
  "6 (512x212, 4 colors), 7 (512x212, 16 colors), 8 (256x212, 256 colors) and, on MSX2+/turbo R, 10-12 (YJK colors). PSET, LINE, CIRCLE, PAINT, "
  "GET/PUT and COPY work in SCREEN 5-8 (PSET, POINT, LINE and CIRCLE also in SCREEN 3). The second parameter is the sprite size: "
  "0 = 8x8, 1 = 8x8 magnified, 2 = 16x16, 3 = 16x16 magnified. On MSX1 a mode above 3 gives \"Illegal function call\". "
  "Graphics modes keep a 768-byte copy of the text font at the top of the heap (for PRINT on graphics screens): with very large arrays or many strings there may be too little memory left and the program stops with \"Out of string space\". "
  "SCREEN 4 has no font in VRAM: to write text with VWRITE copy the glyphs from the text screen first (VREAD$) as the GEOMRUN example does.",
  'SCREEN 5\nCOLOR 15, 4\nCLS\nPSET (10, 10), 15\nLINE -(100, 80), 8', ['PSET', 'LINE', 'SPRITE', 'SET'], 'MSX1: modes 0-3; MSX2: 0-8 (10-12 on MSX2+)')
T(['PSET', 'PRESET'], C, ["PSET (x, y) [, color [, operation]]", "PRESET (x, y) [, color [, operation]]"],
  "Turns a point on (PSET) or off (PRESET, background color). Off-screen coordinates are clipped. The logical operation is PSET, PRESET, "
  "AND, OR, XOR or the same prefixed with T (transparent: color 0 does not write).",
  'SCREEN 5\nPSET (128, 100), 12\nPSET (128, 100), 3, XOR', ['POINT', 'LINE'], M2 + ' (including SCREEN 3)')
T('POINT', C, ["POINT(x, y)"], "Color of the point; -1 if off-screen.", 'SCREEN 5\nPSET (5, 5), 9\nPRINT POINT(5, 5)', ['PSET'], M2)
T('LINE', C, ["LINE [(x1, y1)] - (x2, y2) [, color [, B|BF [, operation]]]"],
  "Draws a line; without the first point it starts from the last graphics point. With B it draws a rectangle, with BF a filled rectangle. If the color is omitted "
  "the COLOR value is used. Not to be confused with LINE INPUT (which reads a line of text).",
  'SCREEN 5\nLINE (10, 10)-(100, 60), 15\nLINE (20, 80)-(120, 140), 9, BF', ['CIRCLE', 'PSET'], M2 + ' (including SCREEN 3)')
T('CIRCLE', C, ["CIRCLE (x, y), radius [, color]"], "Draws a circle.", 'SCREEN 5\nCIRCLE (128, 106), 50, 11', ['LINE', 'PAINT'], M2 + ' (including SCREEN 3)')
T('PAINT', C, ["PAINT (x, y) [, color [, border]]"],
  "Fills an area starting from the given point. In the 16-color and 4-color modes the border (the color that stops the fill) must be given "
  "if it differs from the fill color.",
  'SCREEN 5\nCIRCLE (128, 106), 50, 4\nPAINT (128, 106), 6, 4', ['CIRCLE', 'LINE'], M2)
T('DRAW', C, ["DRAW \"commands\""],
  "Draws with a command language: U D L R E F G H (move up, down, left, right and diagonally by n points), M x,y (move to; +/- relative), "
  "B before a command (move without drawing), N (draw and return), C color, S scale (in quarters). Example: `DRAW \"C7 R20 D10 L20 U10\"`.",
  'SCREEN 5\nPSET (100, 100)\nDRAW "C8 R40 D30 L40 U30"', ['LINE'], M2)
T(['GET', 'PUT'], C, ["GET (x1,y1)-(x2,y2), array", "PUT (x, y), array [, operation]"],
  "GET copies a screen rectangle into an integer array; PUT redraws it with an operation (PSET, PRESET, AND, OR, XOR). In graphics "
  "the rectangle must fit in an array dimensioned with DIM. Not to be confused with GET #n / PUT #n (random-access files) and PUT SPRITE.",
  'SCREEN 5\nDIM a(100)\nCIRCLE (20, 20), 8, 15\nGET (10, 10)-(30, 30), a\nPUT (100, 100), a, PSET', ['COPY', 'PUT SPRITE', 'OPEN'], M2)
T('COPY', C, ["COPY (x1,y1)-(x2,y2)[,page] TO (x3,y3)[,page] [, operation]"],
  "Copies a screen rectangle (also between pages) using the VDP command engine: very fast, ideal for software sprites and scrolling.",
  'SCREEN 5\nCIRCLE (30, 30), 20, 12\nCOPY (0, 0)-(60, 60) TO (150, 100)', ['GET', 'SET'], M2)
T(['SET', 'SET PAGE', 'SET SCROLL'], C, ["SET PAGE visible, active", "SET SCROLL x, y"],
  "SET PAGE selects the displayed page and the page being drawn on (SCREEN 5-8): draw off-screen and then show it, for flicker-free animation. "
  "SET SCROLL scrolls the screen smoothly (registers 23 and 18).",
  'SCREEN 5\nSET PAGE 0, 1\nCIRCLE (100, 100), 40, 15\nSET PAGE 1, 1', ['COPY', 'VBANK'], M2)
T(['VIEW', 'WINDOW'], C, ["VIEW [(x1,y1)-(x2,y2)]", "WINDOW [SCREEN] [(x1,y1)-(x2,y2)]"],
  "VIEW restricts drawing to a window of the screen (without arguments it cancels it); WINDOW redefines the coordinate system (WINDOW SCREEN: the y axis grows downward).",
  'SCREEN 5\nVIEW (50, 50)-(150, 150)\nLINE (0, 0)-(255, 211), 15\nVIEW', ['LINE'], M2)
T('PALETTE', C, ["PALETTE n, r, g, b", "PALETTE n, color", "COLOR = (n, r, g, b)", "COLOR = RESTORE"],
  "Redefines a palette color (r, g, b from 0 to 7); the two-number form assigns the given default color to color n. "
  "`COLOR = RESTORE` restores the factory palette.",
  'SCREEN 5\nPALETTE 1, 7, 0, 0\nLINE (10, 10)-(100, 60), 1, BF', ['COLOR'], M2)
T(['VPOKE', 'VPEEK'], C, ["VPOKE address, value", "VPEEK(address)"], "Writes/reads a byte of video memory. With VBANK the address extends to 17 bits (128 KB on MSX2).",
  'VPOKE 0, 65\nPRINT VPEEK(0)', ['VBANK', 'VFILL', 'VWRITE'])
T('VBANK', C, ["VBANK n"], "Selects the 16 KB VRAM block used by VPOKE, VPEEK, VFILL, VWRITE, VREAD$, BLOAD/BSAVE ... S (R#14 on MSX2).", 'VBANK 1\nVPOKE 0, 5', ['VPOKE'], M2)
T('VFILL', C, ["VFILL address, count, value"], "Fills a VRAM area with a byte.", 'VFILL 0, 768, 32', ['VWRITE'])
T('VWRITE', C, ["VWRITE address, string$"], "Writes the bytes of a string to VRAM.", 'VWRITE 0, "hello"', ['VREAD$', 'VCOPY'])
T('VREAD$', C, ["VREAD$(address, count)"], "Reads a VRAM area and returns it as a string.", 'PRINT VREAD$(0, 4)', ['VWRITE'])
T('BASE', C, ["BASE(n)"], "VRAM address of the tables of the current mode (n as in MSX BASIC: 0 names, 2 colors/patterns, ...).", 'PRINT BASE(0)', ['VDP'])
T('VDP', C, ["VDP(n)", "VDP(n) = value"], "Reads or writes VDP register n (reading gives the BIOS copy in RAM).", 'VDP(7) = 9\nPRINT VDP(7)', ['BASE', 'OUT'])
T('OUT', C, ["OUT port, value", "INP(port)"], "Writes a byte to an I/O port; INP reads one.", 'OUT 170, 3', ['INP', 'VDP'])
T('INP', C, ["INP(port)"], "Reads a byte from an I/O port.", 'PRINT INP(168)', ['OUT'])

# ------------------------------------------------------------------ sprites
C = 'Sprites'
T('SPRITE', C, ["SPRITE$(n) = string$", "PUT SPRITE plane, (x, y), color, pattern", "PUT SPRITE plane", "COLOR SPRITE(plane) = color", "COLLISION"],
  "Sprites are 32 hardware objects. SPRITE$(n) = string$ defines pattern n: 8 bytes for an 8x8 (32 for a 16x16), one bit per dot. "
  "PUT SPRITE plane,(x,y),color,pattern shows the sprite; with just PUT SPRITE plane it is hidden. The size (8x8 or 16x16, "
  "normal or magnified) is chosen with the second parameter of SCREEN. COLOR SPRITE(n) = c changes the color of a plane; "
  "COLOR SPRITE$(n) = string$ gives one color per line (MSX2, sprite mode 2): note that PUT SPRITE with coordinates sets all the lines of the plane to its color, "
  "so a multicolor sprite that moves is better positioned by writing the attribute table with VPOKE (see the GEOMRUN example: SCREEN 4, attributes at VRAM 7680, "
  "y-1, x, pattern*4) and layering several planes for more colors. COLLISION is -1 if two sprites have touched.",
  'SCREEN 2, 0\nSPRITE$(0) = CHR$(255)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(255)\nPUT SPRITE 0, (100, 90), 8, 0',
  ['SCREEN', 'COLLISION', 'STICK'], 'MSX1 and MSX2 (SCREEN 1-8)')
T('PUT SPRITE', C, ["PUT SPRITE plane, (x, y), color, pattern", "PUT SPRITE plane"], "Shows a sprite (or hides it when only the plane is given). See SPRITE.",
  'SCREEN 2, 0\nSPRITE$(0) = CHR$(255)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(255)\nPUT SPRITE 0, (50, 50), 15, 0', ['SPRITE'])
T('COLLISION', C, ["COLLISION"], "Is -1 if two sprites have overlapped since the last read (read from the VDP status), 0 otherwise.",
  'IF COLLISION THEN PRINT "hit"', ['SPRITE'])
T('STICK', C, ["STICK(n)"], "Direction of joystick n (0 = cursor keys, 1 and 2 = ports). Values from 0 (centered) to 8: 1 is up, then clockwise.",
  'd = STICK(0)\nIF d = 3 THEN PRINT "right"', ['STRIG', 'INKEY$'])
T('STRIG', C, ["STRIG(n)"], "Fire button: n = 0 space bar, 1 and 2 A buttons of joysticks 1 and 2, 3 and 4 B buttons. Is -1 if pressed.",
  'IF STRIG(0) THEN PRINT "fire"', ['STICK'])

# ------------------------------------------------------------------ sound
C = 'Sound'
T('BEEP', C, ["BEEP"], "Emits the system beep.", 'BEEP', ['SOUND', 'PLAY'])
T('SOUND', C, ["SOUND register, value"], "Writes directly to a register (0-13) of the AY-3-8910 PSG sound generator: tones, noise, mixer, volumes, envelope.",
  'SOUND 7, 62\nSOUND 8, 12\nSOUND 0, 254\nSOUND 1, 0', ['PLAY', 'BEEP'])
T('PLAY', C, ["PLAY voice1$ [, voice2$ [, voice3$]]"],
  "Plays a melody on 1-3 voices using the MML language and waits for the end. Commands: A-G (note, with # or + for sharp, - for flat; followed by a number for the length and by dots), "
  "R rest, O octave (1-8), L default length (1-64), T tempo (32-255), V volume (0-15), N n (numeric note), < and > octave down/up, "
  "M and S (modulation/envelope shape as in MSX BASIC).",
  'PLAY "T120 O4 L8 CDEFGAB>C"\nPLAY "O3 C2", "O4 E2", "O4 G2"', ['SOUND', 'BEEP'])

# ------------------------------------------------------------------ files
C = 'Disk files'
T('OPEN', C, ["OPEN name$ FOR INPUT|OUTPUT|APPEND AS [#]n", "OPEN name$ [FOR RANDOM] AS [#]n LEN = k"],
  "Opens a file (.COM programs only, not cartridges). n from 1 to 3. INPUT: read; OUTPUT: create/truncate; APPEND: write at the end; RANDOM: random-access file "
  "with records of k bytes (1-128). Open files are closed automatically at the end of the program.",
  'OPEN "TEST.TXT" FOR OUTPUT AS #1\nPRINT #1, "line one"\nCLOSE #1\nOPEN "TEST.TXT" FOR INPUT AS #1\nLINE INPUT #1, a$\nCLOSE #1\nPRINT a$',
  ['CLOSE', 'PRINT', 'INPUT', 'EOF', 'FIELD'], 'DOS programs only (.COM)')
T('CLOSE', C, ["CLOSE [#n {, #n}]"], "Closes the given files (all of them, if no arguments).", 'CLOSE #1', ['OPEN'], 'DOS programs only (.COM)')
T('WRITE', C, ["WRITE #n, expression {, expression}"], "Writes values to the file separated by commas, with strings in quotes.", 'WRITE #1, 5, "ab"', ['PRINT', 'OPEN'], 'DOS programs only (.COM)')
T('EOF', C, ["EOF(n)"], "Is -1 when file n has ended.", 'WHILE NOT EOF(1)\n  LINE INPUT #1, a$\n  PRINT a$\nWEND', ['OPEN'], 'DOS programs only (.COM)')
T('KILL', C, ["KILL name$"], "Deletes a file from the disk.", 'KILL "TEST.TXT"', ['OPEN'], 'DOS programs only (.COM)')
T(['FIELD', 'LSET', 'RSET'], C, ["FIELD #n, width AS var$ {, width AS var$}", "LSET var$ = text$", "RSET var$ = text$"],
  "Random-access files: FIELD splits the record into fields tied to string variables (up to 8); LSET/RSET fill the field aligning left or right "
  "(padding with spaces); PUT #n,r writes record r, GET #n,r reads it (records start at 1). LOF(n) gives the number of records.",
  'OPEN "R.DAT" AS #1 LEN = 20\nFIELD #1, 10 AS n$, 10 AS c$\nLSET n$ = "Mario"\nLSET c$ = "Rossi"\nPUT #1, 1\nGET #1, 1\nPRINT n$; c$\nCLOSE #1',
  ['OPEN', 'MKI$', 'LOF'], 'DOS programs only (.COM)')
T('LOF', C, ["LOF(n)"], "Number of records of random-access file n.", 'PRINT LOF(1)', ['FIELD'], 'DOS programs only (.COM)')
T(['BLOAD', 'BSAVE'], C, ["BSAVE name$, start, length [, S]", "BLOAD name$ [, S] [, offset]"],
  "Saves/loads a memory block in the MSX binary format. With S the data goes from/to VRAM (VBANK applies).",
  'BSAVE "SCREEN.BIN", 0, 6144, S\nBLOAD "SCREEN.BIN", S', ['VBANK', 'OPEN'], 'DOS programs only (.COM)')

# ------------------------------------------------------------------ cartridges
C = 'ROM cartridges, segments and mappers'
T('SEGMENT', C, ["SEGMENT n"], "In a multi-bank cartridge, moves the following code into segment n (previous + 1). Segment 0 contains the runtime. "
  "A SUB/FUNCTION in another segment is called normally; GOTO and GOSUB do not cross segments. For large projects each segment can live in its own file NAME000, NAME001...: see SEGMENTS.",
  'OPTION TARGET ASCII8\nSEGMENT 1\nSUB bis()\n  PRINT "in segment 1"\nEND SUB', ['OPTION', 'INCBIN', 'CALL'], 'ASCII8/ASCII16/Konami/SCC cartridges')
T('INCBIN', C, ["INCBIN \"file\""], "Includes the bytes of a file in the current segment (graphics, music, tables).", 'SEGMENT 2\nINCBIN "SPRITES.BIN"', ['SETBANK', 'SEGMENT'], 'Multi-segment cartridges')
T(['SETBANK', 'DATAWIN'], C, ["SETBANK n", "DATAWIN"], "SETBANK maps segment n into the data window; DATAWIN is the address of the window (A000h for 8 KB banks, 8000h for ASCII16).",
  'SETBANK 2\nVCOPY DATAWIN, 0, 256', ['INCBIN', 'VCOPY'], 'Multi-segment cartridges')
T('VCOPY', C, ["VCOPY memory_address, vram_address, count"], "Copies bytes from memory to VRAM.", 'VCOPY DATAWIN, 0, 2048', ['SETBANK', 'VWRITE'])
T(['MALLOC', 'MFREE', 'MAPPERSEGS'], C, ["MAPPERSEGS", "MALLOC", "MFREE segment"], "RAM mapper: MAPPERSEGS gives the number of 16 KB segments (0 if there is no mapper); "
  "MALLOC allocates one and returns its number; MFREE releases it.",
  's = MALLOC\nPRINT MAPPERSEGS; s\nMFREE s', ['MGET', 'MPUT', 'DIM'], 'With RAM mapper')
T(['MGET', 'MPUT', 'MREAD', 'MWRITE', 'VARPTR'], C, ["MGET(segment, offset)", "MPUT segment, offset, value", "MREAD segment, offset, address, count", "MWRITE segment, offset, address, count", "VARPTR(variable)"],
  "RAM mapper access: MGET reads a byte, MPUT writes it, MREAD copies from the mapper to memory, MWRITE from memory to the mapper. VARPTR gives the address of a variable "
  "(or array element) to pass to MREAD/MWRITE. The memory addresses of the blocks must not fall in 8000h-BFFFh.",
  's = MALLOC\nMPUT s, 0, 123\nPRINT MGET(s, 0)\nMFREE s', ['MALLOC', 'VARPTR', 'DIM'], 'With RAM mapper')

# ------------------------------------------------------------------ OPTION
C = 'Options (OPTION)'
T('OPTION', C, ["OPTION NUMBERED | LABELS | MIXED", "OPTION TARGET type", "OPTION DEBUG", "OPTION BREAK", "OPTION MAP"],
  "Compilation directives, to be placed at the start of the source. NUMBERED: the program has line numbers and no labels; LABELS: labels only; "
  "MIXED (default): both. TARGET selects the output format (see OPTION TARGET). DEBUG enables the debugger (see DEBUG). BREAK lets CTRL+STOP stop a program started from the editor (see OPTION BREAK). MAP (cartridges) writes the map file used by the Visual Studio Code debugger (see OPTION MAP).",
  'OPTION LABELS\nPRINT "ok"', ['OPTION TARGET', 'OPTION DEBUG', 'LABELS'])
T(['OPTION TARGET','TARGET'], C, ["OPTION TARGET DOS | BIN", "OPTION TARGET ROM_16 | ROM_32 | ROM_ASCII8 | ROM_ASCII16 | ROM_KONAMI | ROM_KONAMISCC"],
  "When it is the first line, it selects what the compiler produces. DOS (default, also COM): NAME.COM program for MSX-DOS. BIN: NAME.BIN program for MSX-BASIC, "
  "without DOS (see BIN). ROM_16 and ROM_32: plain 16 or 32 KB cartridge. ROM_ASCII8, ROM_ASCII16, ROM_KONAMI and ROM_KONAMISCC (also ROM_SCC): banked cartridges, with segments "
  "(see SEGMENT and SEGMENTS). The old names ROM16, ROM32, ASCII8, ASCII16, KONAMI, SCC remain valid. A cartridge waits for a key at the end and restarts the machine; cartridges "
  "have no files, no BLOAD/BSAVE and no on-screen debugger (the Visual Studio Code extension can debug them, see OPTION MAP); the inline assembler works.",
  'OPTION TARGET ROM_16\nPRINT "I am a cartridge"', ['BIN', 'DOS', 'SEGMENT', 'OPTION'])
T(['BIN'], C, ["OPTION TARGET BIN"],
  "Produces NAME.BIN, a machine-language program for MSX-BASIC, without MSX-DOS. The file is in BLOAD format and starts at address 8400h. From MSX-BASIC: "
  "`CLEAR 200,&H83FF` and then `BLOAD \"NAME.BIN\",R`. At the end of the program it waits for a key and returns to the BASIC prompt. Disk files "
  "(OPEN, BLOAD, BSAVE...), the RAM mapper and the debugger are not available; everything else (graphics, sprites, sound, strings, arrays, SUB/FUNCTION, inline assembler) works as in DOS programs. "
  "The code can reach about 12 KB beyond the runtime; data and heap sit from D000h upward.",
  'OPTION TARGET BIN\nPRINT "Hello from MSX-BASIC"', ['DOS', 'OPTION TARGET', 'ASM'], 'MSX1 and MSX2, no DOS')
T(['DOS', 'COM'], C, ["OPTION TARGET DOS"],
  "Default value: produces NAME.COM for MSX-DOS (1 or 2) with access to disk files. Equivalent to writing no OPTION TARGET. DOS programs start at 0100h.",
  None, ['BIN', 'OPTION TARGET'])
T(['OPTION NUMBERED','NUMBERED'], C, ["OPTION NUMBERED"], "Numbered lines (sorted by number, numbers only, no labels). About 590 program lines.", '10 PRINT "a"\n20 GOTO 10', ['OPTION', 'LABELS'])
T(['OPTION LABELS','OPT LABELS'], C, ["OPTION LABELS"], "Labels only, no line numbers.", 'OPTION LABELS\nciclo:\n  PRINT "x";\n  GOTO again', ['OPTION'])
T(['OPTION MIXED','MIXED'], C, ["OPTION MIXED"], "Line numbers and labels together (default).", 'OPTION MIXED', ['OPTION'])
T(['OPTION BREAK','OPT BREAK','BREAK'], C, ["OPTION BREAK"],
  "Lets you interrupt the program with CTRL+STOP and go back to the editor, but only when the program was started from the editor (F5): "
  "a .COM launched from the DOS prompt ignores the option and runs normally. The compiler adds a check of the keyboard at every backward jump "
  "(NEXT, LOOP, WEND, GOTO), so any loop can be interrupted at the cost of a few microseconds per iteration; a program that never loops back cannot be stopped. "
  "On openMSX the STOP key is Pause: press CTRL+Pause. DOS programs only (not BIN or cartridges); with OPTION DEBUG the debugger is used instead.",
  'OPTION BREAK\nPRINT "CTRL+STOP returns to the editor"\nDO\n  n = n + 1\nLOOP', ['OPTION', 'OPTION DEBUG'])
T(['OPTION MAP','OPT MAP','MAP FILE'], C, ["OPTION MAP"],
  "Cartridges only. The compiler also writes NAME.MAP next to NAME.ROM: for every statement the segment and the address of its code, for every SUB/FUNCTION its range and its local variables, "
  "and the global variables. The cartridge itself is byte for byte the one you would get without the option (no hooks, no extra code), so what you debug is what you ship. "
  "The map is what lets the Visual Studio Code extension debug a multi-segment cartridge: breakpoints and stepping in any segment (the active segment is recognized from the ROM contents), "
  "call stack, local and global variables. You never write this option yourself: the extension adds it to a temporary copy of the project when you start the debugger.",
  None, ['OPTION', 'OPTION TARGET', 'OPTION DEBUG'])
T(['OPTION DEBUG','OPT DEBUG'], C, ["OPTION DEBUG"], "Compiles with the built-in debugger: the program starts stopped at the first statement. See DEBUG.", 'OPTION DEBUG\na = 1\nb = a + 1', ['DEBUG'])
