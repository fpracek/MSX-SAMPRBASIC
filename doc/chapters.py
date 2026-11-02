# -*- coding: utf-8 -*-
"""Narrative chapters of the manual. Each chapter: (title, [blocks]); block = ('p', text) | ('h', heading) | ('code', text) | ('ul', [items]) | ('table', [rows], [widths]) | ('img', file, caption)."""

CHAPTERS = []


def CH(title, blocks):
    CHAPTERS.append((title, blocks))


CH('Introduction', [
    ('p', "<b>SamPr Basic</b> is a complete development environment that runs <b>directly on an MSX computer</b>: a full-screen editor, a BASIC compiler "
          "that produces real Z80 machine code and a debugger, all without needing a PC. You write the program, press <b>F5</b> and after a few seconds "
          "the program runs at the speed of the machine."),
    ('h', 'What it offers'),
    ('ul', [
        "<b>A real compiler</b>: every BASIC statement becomes Z80 code; the result is a .COM file (MSX-DOS) or a .ROM cartridge.",
        "<b>Editor</b> with pull-down menus (also from the keyboard), mouse, selection, copy/paste, undo/redo, find and replace, keyword colors.",
        "<b>Structured language</b>: SUB and FUNCTION with parameters, local variables and recursion; IF/ELSEIF, SELECT CASE, DO/LOOP; labels or line numbers.",
        "<b>Built for games</b>: MSX2 bitmap graphics, sprites, direct VRAM access, scrolling, joystick, three-voice sound with the MML language.",
        "<b>Inline Z80 assembler</b> with <font face='Courier'>__ASM ... __ENDASM</font> for the critical parts.",
        "Step-by-step <b>debugger</b> with breakpoints and variables (<font face='Courier'>OPTION DEBUG</font>).",
        "<font face='Courier'>OPTION BREAK</font>: CTRL+STOP stops a program started from the editor and returns to it.",
        "<b>ROM cartridges</b> from 16 KB to 2 MB (ASCII8, ASCII16, KONAMI, SCC) with code spread over several segments and embedded data.",
        "<b>Disk files</b>, text and random access; <b>RAM mapper</b> for large amounts of data; BLOAD/BSAVE.",
        "<b>MSX1 and MSX2</b>: on MSX1 the editor works in 40 columns, on MSX2 in 80, chosen automatically.",
        "<b>Online help</b> (F6 on the word under the cursor, F7 for the index) with all statements documented.",
    ]),
    ('h', 'Philosophy'),
    ('p', "The language is a modern but deliberately small BASIC: 16-bit integers and strings, no floating-point numbers (which for video games "
          "would cost speed and memory without any benefit). Everything a game needs — sprites, scrolling, sound, joystick, mapper — is a "
          "statement or a function. Upper and lower case are equivalent everywhere."),
])

CH('Installation and start', [
    ('p', "You need an MSX (MSX1 with at least 64 KB of RAM, or MSX2) with a disk drive and MSX-DOS 1 or 2 (or Nextor). Copy the following files to the disk:"),
    ('table', [['File', 'Purpose'],
               ['SAMPRBAS.COM', "The editor: start it with <font face='Courier'>SAMPRBAS NAME.SPB</font>"],
               ['QBC.COM', 'The compiler (launched by F5)'],
               ['RT.BIN', 'The runtime of the compiled program'],
               ['RTD.BIN', 'Runtime with debugger (for OPTION DEBUG)'],
               ['QASM.OVL', 'The inline assembler (for __ASM)'],
               ['QBCR.COM, RTROM.BIN, RTROMD.BIN', 'To produce ROM cartridges'],
               ['QBCB.COM, RTBIN.BIN', 'To produce BIN programs for MSX-BASIC'],
               ['HELP.TXT, HELP.IDX', 'The online help (optional)']], [150, 330]),
    ('p', "Start the editor with <font face='Courier'>SAMPRBAS</font> (new program) or <font face='Courier'>SAMPRBAS TEST.SPB</font>. On MSX1 DOS asks for the date at startup: "
          "press Enter. On a PC you can try everything with the openMSX emulator: the project folder contains "
          "<font face='Courier'>start_nms8250.bat</font> (MSX2, 80 columns) and <font face='Courier'>start_hb75p.bat</font> (Sony HB-75P MSX1, 40 columns), which mount the test disk."),
    ('h', 'Program files: the .SPB extension'),
    ('p', "Source files have the extension <b>.SPB</b> (SamPr Basic). When you start <font face='Courier'>SAMPRBAS TEST</font> the editor opens TEST.SPB if it exists; "
          "otherwise it starts with a new file that already has that name (the .SPB extension is added automatically if missing). In <b>Save As</b> you type at most "
          "8 characters and the editor adds .SPB. The compiled program gets the same name with extension .COM (or .ROM for cartridges)."),
    ('h', 'First program'),
    ('code', 'PRINT "Hello MSX!"\nFOR i = 1 TO 5\n  PRINT i; " x 2 ="; i * 2\nNEXT i'),
    ('p', "Type the program in the editor and press <b>F5</b>. At the end the run waits for a key and returns to the editor (a NAME.COM that you launch yourself from the DOS prompt returns to the DOS prompt instead). If there is an error, the editor "
          "reopens with the cursor on the wrong line and the message in the title bar."),
])

CH("The editor", [
    ('p', "The editor has a menu bar at the top (<b>File Edit Find Help Run</b>), the text area with line numbers, the scroll bar and a status line "
          "with cursor position and file name. It works with the keyboard and with the mouse (if present)."),
    ('img', 'editor.png', "The editor on MSX2 (80 columns): keywords are highlighted."),
    ('h', 'Keyboard menus'),
    ('table', [['Key', 'Action'],
               ['Esc', 'Opens the File menu; closes an open menu'],
               ['F1 F2 F3 F4', 'Open File, Edit, Find, Help'],
               ['Left / Right', 'With a menu open: switches to the adjacent menu'],
               ['Up / Down, Enter', 'Choose the item'],
               ['Highlighted letter', 'Activates the item (e.g. N = New, O = Open)'],
               ['F5', 'Compiles and runs the program'],
               ['F6', "Help on the word under the cursor"],
               ['F7', "Help index"]], [150, 330]),
    ('h', 'Editing text'),
    ('table', [['Key', 'Action'],
               ['Arrows, Home, End, PgUp, PgDn', 'Cursor movement'],
               ['Shift + arrows', 'Selection'],
               ['Ctrl+C / Ctrl+X / Ctrl+V', 'Copy, cut, paste'],
               ['Ctrl+Z / Ctrl+Y', 'Undo / redo'],
               ['Ctrl+F / Ctrl+G / Ctrl+T', 'Find / find again / replace'],
               ['Ctrl+S / Ctrl+W', 'Save / save as'],
               ['Ctrl+O / Ctrl+Q', 'Open / quit']], [200, 280]),
    ('p', "BASIC keywords are highlighted in yellow (MSX2 only). Long lines scroll horizontally. When saving, the editor overwrites the file in "
          "place and does not save if the text has not changed; F5 without changes reruns the program without recompiling."),
    ('h', 'Opening a file: the file window'),
    ('p', "File &gt; Open... (Ctrl+O) shows a window with all the <b>.SPB</b> files of the current directory, in alphabetical order. With MSX-DOS 2 the "
          "<b>folders</b> also appear (in square brackets, <font face='Courier'>[GAMES]</font>, and <font face='Courier'>[..]</font> to go up) and you can navigate among them; the current path is "
          "in the title. With MSX-DOS 1 there are no folders and only files are shown."),
    ('table', [['Key', 'Action'],
               ['Arrows', 'Move the selection (two columns on MSX1, four on MSX2)'],
               ['PgUp / PgDn, Home', 'Previous / next page, first entry'],
               ['A letter', "Jumps to the first entry starting with that letter"],
               ['Enter', 'Opens the file or enters the folder'],
               ['Esc', 'Closes the window without opening anything']], [150, 330]),
    ('img', 'browser.png', "The open window: all the .SPB files of the directory, in alphabetical order."),
    ('h', 'Saving with a name'),
    ('p', "File &gt; Save As... (Ctrl+W) asks for the name: <b>at most 8 characters</b>; the .SPB extension is added by the editor (if you type an extension it is replaced). "
          "F5 on an unnamed program also asks for the name in the same way."),
    ('img', 'menu_file.png', "The File menu, with the Segment... item (F8)."),
    ('h', 'Segment projects: File > Segment (F8)'),
    ('p', "For segmented cartridges (see the chapter on cartridges) each segment is a file <b>NAME000.SPB</b>, <b>NAME001.SPB</b>, ... "
          "(5 characters plus 3 digits). File &gt; Segment... (key <b>F8</b>) asks for the segment number, even without leading zeros (<font face='Courier'>7</font> is the same as 007): "
          "the editor <b>saves the current file</b>, then looks for and opens the file with that number in the same directory. If the file does not exist, or is a <b>.BIN</b> segment (which cannot be opened), the editor says so with a message and the active file stays the previous one. The item cannot be used if the current file has no name yet or if the name is not 5 characters plus 3 digits: in that case you are not working with segments. A new segment is created with File &gt; New and Save As... (NAME005, ...)."),
    ('h', 'The Help menu'),
    ('ul', ["<b>Index (F7)</b>: the list of all topics.",
            "<b>Topic...</b>: asks for a topic name (PRINT, ASM, DEBUG, OPTION...).",
            "<b>On word (F6)</b>: documents the word under the cursor.",
            "<b>Shortcuts</b>: summary of the keys.",
            "<b>About</b>: a centered window with the menu frame, <i>SamPr Basic 1.0 — 2026 Fausto Pracek</i> and the OK button; it closes with Enter, Esc or a click on OK."]),
    ('img', 'menu_help.png', "The Help menu."),
    ('img', 'help_topic.png', "Help on the PRINT statement."),
    ('img', 'about.png', "The About window, with the menu frame and the OK button."),
    ('p', "In the help viewer: arrows and PgUp/PgDn scroll, Esc closes. The text comes from the files HELP.TXT and HELP.IDX in the current directory: HELP.TXT is a plain "
          "text file and can be edited; HELP.IDX is the index (name, position, length) regenerated by the <font face='Courier'>doc/gen_help.py</font> tool."),
])

CH('The language at a glance', [
    ('p', "A program is a sequence of statements, one per line (or several, separated by <font face='Courier'>:</font>). Comments start with "
          "<font face='Courier'>REM</font> or with an apostrophe."),
    ('h', 'Types and variables'),
    ('p', "Signed 16-bit integers and strings up to 255 characters. Variables do not need to be declared: they are 0 or the empty string. Arrays are declared with DIM."),
    ('code', 'n = 12 : m = &HFF : b = &B101\nname$ = "Sam"\nDIM v(10), t$(5)\nv(3) = n * 2\nt$(1) = name$ + "!"'),
    ('h', 'Control structures'),
    ('code', 'IF n > 10 THEN PRINT "big" ELSE PRINT "small"\n\nFOR i = 1 TO 10 STEP 2 : PRINT i; : NEXT i\n\nSELECT CASE n\n  CASE 1 TO 5 : PRINT "low"\n  CASE ELSE : PRINT "high"\nEND SELECT'),
    ('h', 'Routines'),
    ('code', 'FUNCTION fact(n)\n  IF n <= 1 THEN\n    fact = 1\n  ELSE\n    fact = n * fact(n - 1)\n  END IF\nEND FUNCTION\n\nPRINT fact(7)'),
    ('h', 'Labels or numbers'),
    ('p', "The program can use labels (<font face='Courier'>start:</font>) or line numbers; the OPTION directive chooses the mode: NUMBERED, LABELS or MIXED (default)."),
])

CH('Inline assembler', [
    ('p', "For the parts that must be very fast you can write Z80 assembler directly, between the lines <b>__ASM</b> and <b>__ENDASM</b>. "
          "The compiler loads a small assembler (QASM.OVL) that translates the block into machine code inserted into the program."),
    ('code', '__ASM\n  ld hl,(count)    ; the BASIC variable "count"\n  inc hl\n  ld (count),hl\n  jp done          ; jump to the BASIC label "done"\n__ENDASM'),
    ('p', "<b>Assembler-only files:</b> if the first line is <font face='Courier'>OPTION ASM</font> the whole file is assembly: there is no BASIC at all, the code starts at the first line and the program ends when it runs off the end of the file. "
          "Use it as an assembler editor: the editor already has Tab (it inserts spaces up to the next multiple of 4) and F5 compiles and runs. DOS (.COM) programs only. From assembly you can call the DOS functions with <font face='Courier'>CALL 5</font> (e.g. C=9, DE=text ending in $)."),
    ('h', 'Rules'),
    ('ul', ["All documented Z80 instructions; comments with <font face='Courier'>;</font>.",
            "Numbers: <font face='Courier'>123, $7F, 0x7F, 7FH, %101, 101B, 'a'</font>; <font face='Courier'>$</font> is the current address.",
            "Directives: DB/DEFB, DW/DEFW, DS/DEFS, EQU.",
            "A name not defined in the block is a <b>global BASIC variable</b> (also a string) or, in jumps, a <b>BASIC label</b>.",
            "JR and DJNZ only to local labels.",
            "All registers may be modified except <b>IX</b> (routine frame); the stack must be left balanced.",
            "The debugger does not stop inside the blocks. It also works in cartridges.",
            "Errors 17-20: syntax, value out of range, duplicate symbol / missing __ENDASM, QASM.OVL not found."]),
])

CH('The debugger', [
    ('p', "Add <font face='Courier'>OPTION DEBUG</font> at the top of the program and press F5. The compiler uses the runtime with debugger: the program starts "
          "<b>stopped on the first statement</b> and is controlled from the keyboard. A program without OPTION DEBUG pays no cost."),
    ('img', 'debugger.png', "The debugger stopped inside a SUB: parameters and locals (marked with >), then the globals."),
    ('table', [['Key', 'Action'],
               ['Space, S, Enter', 'Executes one statement'],
               ['R', 'Runs to the next breakpoint'],
               ['B number Enter', 'Sets or clears a breakpoint (Enter alone = current line; 0 = clears them all)'],
               ['C', 'Clears all breakpoints'],
               ['E', 'Asks for a variable name (also a local, a parameter, an array element such as V(3), a string such as N$) and shows its value'],
               ['V', 'Next page of variables'],
               ['Q', 'Ends the program'],
               ['Ctrl-Stop', 'While running, re-enters the debugger']], [130, 350]),
    ('p', "The screen shows the current line, the variables with their values and the list of breakpoints. Inside a SUB or FUNCTION the <b>local variables and parameters</b> come first, marked with <font face='Courier'>&gt;</font>, then the scalar global variables. For any other variable use the <b>E</b> command: type the name (it looks first among the locals, then among the globals); for an array type the element, for example <font face='Courier'>V(2)</font> or <font face='Courier'>N$(1)</font>, and without an index you get the number of elements. Nonexistent names, out-of-range indexes and arrays in the mapper are reported. The program's screen is saved and restored: debugging also works in the graphics screens. In cartridges the debugger runs but does not show the variables."),
])

CH('ROM cartridges, segments and mappers', [
    ('p', "With <font face='Courier'>OPTION TARGET</font> as the first line you choose what the compiler produces. A single option, to avoid conflicting settings:"),
    ('table', [['Value', 'Result'],
               ['DOS (default)', 'NAME.COM for MSX-DOS, with disk files'],
               ['BIN', 'NAME.BIN for MSX-BASIC (BLOAD), without DOS'],
               ['ROM_16, ROM_32', 'plain 16 or 32 KB cartridge'],
               ['ROM_ASCII8, ROM_ASCII16', 'ASCII banked cartridge with 8 or 16 KB banks'],
               ['ROM_KONAMI, ROM_KONAMISCC', 'Konami banked cartridge (without or with SCC)']], [150, 330]),
    ('p', "The old names ROM16, ROM32, ASCII8, ASCII16, KONAMI and SCC remain valid. At the end of the program, cartridges wait for a key and reboot the machine; they have no files or BLOAD/BSAVE."),
    ('p', "With banked mappers the code can occupy several <b>segments</b>: <font face='Courier'>SEGMENT n</font> moves the code that follows into segment n. "
          "Routines in other segments are called normally (the compiler switches bank and restores it). Data is included with "
          "<font face='Courier'>INCBIN \"file\"</font> and read with <font face='Courier'>SETBANK</font> and <font face='Courier'>DATAWIN</font>."),
    ('h', 'A cartridge in several files'),
    ('p', "A large program is written in <b>one file per segment</b>. With a segmented OPTION TARGET (ASCII8, ASCII16, KONAMI, SCC) the files are named "
          "<font face='Courier'>NAME000.SPB</font> (segment 0, the fixed one with the runtime) and <font face='Courier'>NAME001.SPB</font>, "
          "<font face='Courier'>NAME002.SPB</font>, ... (5 characters of name plus three digits). Numbering starts from <b>0</b>: segment 0 is the first block of the cartridge (the "
          "BIOS is another ROM, unrelated), the others are the switchable blocks."),
    ('ul', ["The <b>OPTION</b>s (TARGET, DEBUG, LABELS...) go <b>only in file 000</b>; in any other file they give error 13.",
            "<b>SEGMENT</b> is not written: the segment is decided by the file name (with separate files the statement gives error 13).",
            "The compiler reads all the files in sequence as long as it finds the next ones (001, 002, ...), records the routines of each segment and <b>links them into a single ROM</b> NAME.ROM (without the three digits).",
            "You can press F5 from <b>any</b> file of the project: the compiler always starts from 000. Errors report the right file and line and the editor opens that file.",
            "A SUB or FUNCTION in another segment is called as usual; GOTO and GOSUB do not cross segments; each file holds about 15 KB of source.",
            "You switch from one file to another with File &gt; Segment... (F8)."]),
    ('h', '.BIN files: precompiled segments'),
    ('p', "In the same folder and with the same root there can be <font face='Courier'>NAMEnnn.BIN</font> files: they are <b>already compiled</b> segments and the compiler inserts them into the ROM as they are, without reading them as source (only segment 0 must be source). They are used for assembler functions, sprites, fonts, music and other data. The .BIN segment fills its own window (8 or 16 KB, the rest is zeroed). Data is read from the program with <font face='Courier'>SETBANK n</font> and <font face='Courier'>DATAWIN</font>; code is called from an <font face='Courier'>__ASM</font> block after selecting the bank. If both .SPB and .BIN exist for the same number, the source wins. The scheme is the same as the \"raw files\" of MSXgl projects: segment 0 is the first block of the cartridge and the following blocks are numbered consecutively."),
    ('p', "A small program stays in a single file and can still use the <font face='Courier'>SEGMENT n</font> statement. Files without the final three digits are not segments."),
    ('p', "The <b>RAM mapper</b> (if present) offers 16 KB segments: MAPPERSEGS, MALLOC, MFREE, MGET, MPUT, MREAD, MWRITE, VARPTR and the "
          "<font face='Courier'>DIM x(n) MAPPER</font> arrays of up to 32768 integers."),
])

CH('Programs for MSX-BASIC (BIN)', [
    ('p', "With <font face='Courier'>OPTION TARGET BIN</font> the compiler (QBCB.COM, chosen automatically) produces <b>NAME.BIN</b>: a file in BLOAD format, without MSX-DOS, meant to be loaded from the MSX-BASIC window. Unlike DOS programs (which start at 0100h and can call DOS) the BIN is loaded at <b>8400h</b> and never uses DOS."),
    ('code', 'CLEAR 200,&H83FF\nBLOAD "NAME.BIN",R'),
    ('p', "<font face='Courier'>CLEAR</font> reserves the RAM from 8400h upwards. At the end of the program, after a key, you return to the BASIC prompt. Available: graphics, sprites, sound, text, strings, arrays, SUB and FUNCTION, inline assembler, PEEK/POKE, VDP. Not available: disk files, BLOAD/BSAVE, RAM mapper and debugger (statements that require DOS give the error \"Files need MSX-DOS\" at runtime). The runtime and code occupy the image from 8400h; the data RAM and heap are at D000h; the stack starts at F000h and at exit the BASIC one is restored."),
])

CH('Working directory (MSX-DOS 2)', [
    ('p', "With MSX-DOS 2 (and Nextor) programs live in folders. The rule is simple: <b>the working directory is always that of the open file</b>, for normal programs "
          "and for cartridges. The source, the compiled program (.COM, .ROM) and the files read or written by the program live in the project folder; the tools "
          "(SAMPRBAS.COM, QBC.COM, RT.BIN, QASM.OVL...) stay in their own folder and are found automatically."),
    ('ul', ["From the command line you can give a path: <font face='Courier'>SAMPRBAS \\GAMES\\TEST</font> enters GAMES and opens TEST.SPB (or creates it).",
            "File &gt; Open... shows the folders and you navigate through them; when you open a file the working directory is that of the file.",
            "F5 compiles and runs the program in the project folder, and on return the editor is still there.",
            "The two directories are stored in the environment variables <b>SPBHOME</b> (tools) and <b>SPBPROJ</b> (project). SPBHOME is the directory from which the editor "
            "is first started: it is best to start it from the tools folder, or to set it beforehand with <font face='Courier'>SET SPBHOME=\\TOOLS</font>.",
            "With MSX-DOS 1 there are no folders and none of this applies."]),
])

CH('VS Code extension', [
    ('p', "The <b>SamPr Basic for MSX</b> extension lets you work on the PC with the same workflow, the same shortcuts and the <b>same files</b> as the editor on the MSX: a project (NAME.SPB, "
          "NAME000.SPB..., NAMEnnn.BIN) can be copied between a real machine, an SD card or disk image and the PC with no conversion."),
    ('ul', ["<b>The real compiler</b> runs inside VS Code: the extension executes the very same QBC.COM, QBCR.COM and QBCB.COM inside a Z80 emulator with a simulated MSX-DOS. The result is identical to the one produced on the machine and takes a few milliseconds.",
            "<b>Errors as you type</b>, with the compiler's own messages, on the right file and line (unsaved text too, and multi-file cartridges).",
            "<b>Same keys:</b> F5 compile and run, F6 help on the word, F7 help index, F8 go to a segment.",
            "<b>Same look:</b> the <i>SamPr Basic MSX</i> color theme (white on blue, yellow keywords) and an 80-column ruler.",
            "Hover help for every statement, outline of SUB/FUNCTION/labels, snippets, highlighting of __ASM blocks.",
            "<b>Run in openMSX</b> for the three outputs: DOS programs, MSX-BASIC BIN files and ROM cartridges (settings: openMSX path, folder with MSXDOS.SYS and COMMAND.COM, machine).",
            "<b>Source-level debugger</b> on openMSX (<i>Run &gt; Start Debugging</i>, Ctrl+F5): breakpoints on any line, step over / into / out, call stack (SUB names), local variables and parameters, globals, arrays, and expressions such as V(2) or N$ in Watch and Debug Console. Works for DOS and BIN programs; the extension compiles a temporary copy with OPTION DEBUG, so your source is never modified."]),
    ('p', "Install the .vsix file from the release (<i>Extensions &gt; ... &gt; Install from VSIX</i>). In the debugger, set a breakpoint in the gutter and press Ctrl+F5."),
])

CH('MSX1 and MSX2', [
    ('table', [['Feature', 'MSX1', 'MSX2'],
               ['Editor', '40 columns, no colors', '80 columns, colored keywords'],
               ['SCREEN', '0-3', '0-8 (10-12 on MSX2+)'],
               ['Bitmap graphics (PSET, LINE, CIRCLE, PAINT, GET/PUT)', 'SCREEN 2-3', 'SCREEN 3, 5-8'],
               ['PALETTE, COPY, SET PAGE, SET SCROLL, VBANK', 'no', 'yes'],
               ['Sprites', 'yes', 'yes'],
               ['Sound (PLAY, SOUND, BEEP)', 'yes', 'yes'],
               ['RAM mapper', 'no', 'if present']], [220, 120, 140]),
    ('p', "The system recognizes the machine automatically. Tested with a Sony HB-75P (MSX1) and an MSX2 with MSX-DOS 1 and 2."),
])

CH('Errors and limits', [
    ('table', [['No.', 'Meaning'],
               ['1', 'Syntax error'], ['2', 'Nonexistent label or line number'], ['3', 'Not yet supported'],
               ['4', 'Illegal character'], ['5', 'Unclosed block'], ['6', 'ELSE / END IF / NEXT / WEND without a block'],
               ['7', 'Duplicate name'], ['8', 'Too many variables, labels or blocks'], ['9', 'Program too large'],
               ['10', 'Source too large'], ['11', 'Read error'], ['12', 'Write error'],
               ['13', "Not allowed with the chosen OPTION"], ['14', 'Incompatible types or undeclared array'],
               ['15', 'Program data too large'], ['16', 'RT.BIN not found'],
               ['17', 'Assembler: syntax or operand'], ['18', 'Assembler: value or jump out of range'],
               ['19', 'Assembler: duplicate symbol or missing __ENDASM'], ['20', 'QASM.OVL not found']], [40, 440]),
    ('h', 'Limits'),
    ('ul', ["Source: about 12.5 KB per file (15 KB for cartridges). Compiled program: 16 KB; for cartridges, several segments, each with its own file.",
            "96 labels; 100 variables and arrays; 20 SUB/FUNCTION (8 parameters each); 24 nested blocks.",
            "Names significant to 11 characters; strings of 255 characters; integers from -32768 to 32767.",
            "In OPTION NUMBERED about 590 lines; three files open at the same time."]),
])
