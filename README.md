# SamPr Basic

**A complete BASIC development environment that runs on the MSX itself: a full-screen editor, a compiler that produces real Z80 machine code, an inline assembler and a debugger — no PC required.**

Write your program, press **F5**: a few seconds later it runs at the speed of the machine. Built with games in mind (bitmap graphics, sprites, 3-voice sound, joysticks, mappers, cartridges), it works on **MSX1** (40-column editor) and **MSX2** (80 columns) under **MSX-DOS 1 and 2**.

*SamPr Basic 1.0 — © 2026 Fausto Pracek*

| Editor with colored keywords | Online help (F6 / F7) |
|:--:|:--:|
| ![Editor](doc/img/editor.png) | ![Help](doc/img/help_topic.png) |

| File browser with folders | Debugger with local variables |
|:--:|:--:|
| ![File browser](doc/img/browser.png) | ![Debugger](doc/img/debugger.png) |

## Why SamPr Basic

- **A real compiler, on the MSX.** Every BASIC statement becomes machine code: no interpreter. The compiler itself is a 15 KB Z80 program that runs under MSX-DOS.
- **A modern but small language.** 16-bit integers and strings; `SUB`/`FUNCTION` with parameters, local variables and recursion; `IF/ELSEIF`, `SELECT CASE`, `DO/LOOP`; labels **or** line numbers (your choice, via `OPTION`); case-insensitive. No floating point: for a game it would only cost speed and memory.
- **Everything a game needs is one statement:** `SCREEN 5-8` (also 10-12), `PSET/LINE/CIRCLE/PAINT/DRAW`, `COPY`, hardware pages and scrolling, `PALETTE`, 8x8/16x16 sprites with per-line colors, 3-voice MML `PLAY`, `SOUND`, `STICK/STRIG`, direct 17-bit VRAM access.
- **Inline Z80 assembler** with `__ASM … __ENDASM` (every documented instruction; BASIC variables and labels are visible from the block).
- **Step debugger** (`OPTION DEBUG`): breakpoints, global variables and **locals/parameters** (`>`), and an **E** command to inspect any variable (`V(3)`, `N$`…).
- **Three kinds of output from a single option** (`OPTION TARGET`), so there are no conflicting settings.
- **ROM cartridges from 16 KB to 2 MB** (ASCII8, ASCII16, Konami, SCC) with code split over several **segments**, one file each, plus precompiled `.BIN` segments for assembler code and data.
- **Disk files** (text and random access), **RAM mapper**, `BLOAD/BSAVE`, MSX-DOS 2 folders.
- **PDF manual** of over 40 pages and an online help covering every statement.

## Example

```basic
OPTION LABELS
CLS
FOR i = 1 TO 10
  PRINT "7 x"; i; "="; 7 * i
NEXT i
CALL greet("MSX")

SUB greet(n$)
  PRINT "Hello, "; n$
END SUB
```

## Quick start

1. Copy the files of the [`dist/`](dist) folder to your MSX-DOS disk: `SAMPRBAS.COM` (editor), `QBC.COM` (compiler), `RT.BIN` (runtime) and, as needed, `RTD.BIN` (debugger), `QASM.OVL` (assembler), `QBCR.COM`+`RTROM.BIN` (cartridges), `QBCB.COM`+`RTBIN.BIN` (BIN programs), `HELP.TXT`+`HELP.IDX` (online help).
2. Start `SAMPRBAS MYPROG` (it opens `MYPROG.SPB`, or creates it with that name). Under MSX-DOS 2 you can give a path: `SAMPRBAS \GAMES\MYPROG`.
3. Write your program and press **F5**. When the program ends the editor reopens; on a compile error the cursor is placed on the offending line.

To try everything on a PC with [openMSX](https://openmsx.org): `start_nms8250.bat` (MSX2, 80 columns) or `start_hb75p.bat` (Sony HB-75P, MSX1, 40 columns) mount the sample disk [`sample_disk/`](sample_disk) (with the example `.SPB` programs; `MSXDOS.SYS` and `COMMAND.COM` are also needed and are not included).

## What it produces: `OPTION TARGET`

| Value | Result |
|---|---|
| `DOS` (default) | `NAME.COM` for MSX-DOS, with disk files |
| `BIN` | `NAME.BIN` for MSX-BASIC: `CLEAR 200,&H83FF` then `BLOAD "NAME.BIN",R`, no DOS |
| `ROM_16`, `ROM_32` | plain 16 or 32 KB cartridge |
| `ROM_ASCII8`, `ROM_ASCII16` | ASCII bank-switched cartridge |
| `ROM_KONAMI`, `ROM_KONAMISCC` | Konami bank-switched cartridge (without or with SCC) |

### Multi-file cartridges

A large program is written with one file per segment: `NAME000.SPB` (main, holds the `OPTION`s) and `NAME001.SPB`, `NAME002.SPB`… (5 characters + 3 digits). The compiler reads them all and links them into one `NAME.ROM`; press F5 from any file. A `NAMEnnn.BIN` is an already compiled segment (assembler code, sprites, fonts) and is inserted as it is. In the editor, **File ▸ Segment… (F8)** saves the current file and switches to the requested segment.

## Editor

Drop-down menus from the keyboard (**Esc**, **F1–F4**) and with the mouse; selection, copy/paste, undo/redo, find/replace; a file window with folders (DOS 2) and jump-by-first-letter; **F5** compiles and runs; **F6** help on the word under the cursor; **F7** help index; **F8** change segment. Sources use the **`.SPB`** extension (*SamPr Basic*); *Save As* accepts up to 8 characters.

## Documentation

- **[User manual and reference (PDF)](dist/SamPrBasic-Manual.pdf)**: cover, installation, editor, language, every statement with syntax and example, assembler, debugger, cartridges, BIN, errors and limits.
- Online help in the editor (Help menu).
- Implementation notes: [`onmsx/README.md`](onmsx/README.md) (compiler and runtime, stages 1–28), [`editor/README.md`](editor/README.md) (editor), [`DESIGN-ONMSX.md`](DESIGN-ONMSX.md) (design).
- The PDF and `HELP.TXT`/`HELP.IDX` are generated from the same source: [`doc/`](doc) (`gen_pdf.py`, `gen_help.py`).

## Compatibility and testing

MSX1 and MSX2/2+/turbo R; MSX-DOS 1.03 and 2 (Nextor). Tested on [openMSX](https://openmsx.org) with the Philips NMS 8250, Sony HB-75P (+ disk interface) and Panasonic FS-A1ST: hundreds of automatic checks on screens, VRAM pixels, PSG registers and the bytes of the ROMs produced. **It has not been tried on real MSX hardware.**

Main suites (they need openMSX, [sjasmplus](https://github.com/z00m128/sjasmplus) and Python 3, with `reportlab`/`Pillow` for the documents):

```
cd onmsx  && python qtest.py        # compiler (DOS programs)
cd onmsx  && python rtest.py        # ROM cartridges, every mapper
cd onmsx  && python mtest.py        # multi-file cartridges, .BIN segments
cd onmsx  && python btest.py        # BIN programs (compiled under DOS, run from MSX-BASIC)
cd onmsx  && python gtest.py        # graphics, sprites, palette
cd editor && python etest.py        # editor (and many more: esel, emenu, ecom, ehelp, ebrowse, eseg, edir…)
```

## Layout

| Folder | Contents |
|---|---|
| [`onmsx/`](onmsx) | compiler (`qbc.asm`), runtime (`rtcom.asm` and modules), inline assembler, debugger, tests |
| [`editor/`](editor) | editor (`editor.asm`, `fileio.asm`), help, file window, tests |
| [`doc/`](doc) | PDF manual, online help, screenshots, generators |
| [`dist/`](dist), [`sample_disk/`](sample_disk) | files to copy to the MSX disk, example programs |

## Known limits

16-bit integers only (no floating point; an experimental implementation lives in the git tag `float-archive`). Source of about 12.5 KB per file (15 KB for cartridges), compiled program up to 16 KB (cartridges have several segments). BIN programs have no files, RAM mapper or debugger.

---

*The project started as a cross prototype Python → Z80: the old README is kept in [`doc/PROTOTIPO-PYTHON.md`](doc/PROTOTIPO-PYTHON.md).*
