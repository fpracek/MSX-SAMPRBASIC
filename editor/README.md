# SamPr Basic text editor (prototype, Z80)

`editor.asm` — 16K ROM for MSX2, SCREEN 0 at 80 columns. Test: `python etest.py [--shots]`
(assembles with a 71-line demo text, runs in openMSX NMS-8250, 41 checks; `--shots`
rebuilds PNGs from the saved VRAM into `build\*.png`).

## Screen
Row 0 title (inverse, `Ln row/total  Col n`) · rows 1-22 text (columns 0-78) ·
column 79 vertical bar (▲ track ▼) · row 23 horizontal bar (◄ track ►).
Inverse video = characters 128-255 (negated copies of the BIOS font), glyphs 1-5 redefined,
cursor = inverse glyph (bit 7) of the cell with software blinking (32 frames), mouse pointer = XOR 80h on the cell;
the VDP blink table (R#12/R#13, 10 bytes per row) is used for the keyword colors (see below).

## Keyboard
Arrows, Home, SELECT (= End), Ctrl+P / Ctrl+N (page up/down), Enter, BS, DEL, TAB (to 4),
ASCII characters 32-126. Lines up to 254 columns. The view follows the cursor only after a key press:
scrolling with the mouse leaves the cursor where it is, and on the first key press the view returns to it.

## Mouse
Click on the text = move the cursor · bar arrows = 1 row/column (with repeat) ·
click on the track = page (stops under the pointer) · dragging the thumb = scrolls
proportionally (`scale`: 16-bit x*y/z, with a rounding correction so the thumb stays under the pointer).
Hardware: BIOS `GTTRIG(1)` for the button, `GTPAD(12..14)` for movements (port 1; `MPAD`=16 for port 2).
Test: with `mmode`=1 movement/buttons come from `tm_dx/tm_dy/tm_btn` (openMSX does not allow injecting mouse events).

## Data
Gap buffer in RAM C100h-EFFFh (≈12 KB), logical offsets, LF = end of line. A 0 byte at the start of the gap
and at the end of the buffer acts as a sentinel: redraw reads memory without checking the gap character
by character (22 rows in a few ms). `nlines`, `curline`, `topline` are maintained incrementally.

## Not done yet / not verified
- Real mouse: not verified on hardware (sign and scale of `GTPAD` to be checked; if the axes are inverted, just negate in `mouse_read`).
- File load/save (requires MSX-DOS/Nextor), selection/copy/paste, search, undo, right button.
- Buffer ≈12 KB; it can be extended with the mapper. A line longer than 254 columns cannot be entered.
- Redraw is always complete (whole text) when the view scrolls or the text changes.

## Load / save (`.COM` build, MSX-DOS)
`sjasmplus -DCOM editor.asm` produces `ed.com` (≈4.5 KB); `python ecom.py` tests it on MSX-DOS 1.03
(NMS-8250, host folder as drive A:, 20 checks, verifies the bytes of the files saved on the PC).
The ROM build (`etest.py`, 41 checks) remains for tests without DOS: same source, `IFDEF COM`.

Usage: `ED [file]`. Keys: **Ctrl+S** saves (asks for the name if missing) · **Ctrl+W** saves as ·
**Ctrl+O** opens · **Ctrl+Q** exits to DOS. The name is typed on the title bar (Enter, Esc, BS).
With unsaved changes Ctrl+O / Ctrl+Q warn: press the same key again to discard them.
The title shows `MSXQB Editor NAME*` (`*` = modified) or the last message (until the next key press).

- FCB API (open/make/close/delete + random block read/write with 1-byte records):
  compatible with MSX-DOS 1 and, for backward compatibility, with Nextor/MSX-DOS 2. Not yet tried on Nextor.
- On disk CR LF, in memory LF. On load: CRs discarded, TABs expanded to multiples of 4, non-printable bytes → `?`,
  stops at 1Ah. Saving does not write the final 1Ah.
- Buffer 2000h-BFFFh (≈40 KB). Larger files: loaded truncated, with the warning "File too large - truncated".
- Variables at C000h (page 3): in page 0 the debugger reads the BIOS ROM during interrupts.
- 8.3 file name (with optional `A:`), no paths or wildcards.

## Selection and clipboard
Test: `python esel.py` (ROM build, 30 checks with a Python model of the text); `ecom.py` also tests cut/paste/save under DOS.
- **Keyboard**: Shift + arrows / Home / SELECT(End) / Ctrl+P / Ctrl+N extend the selection; a movement without Shift cancels it.
  Shift is read from the keyboard matrix (BIOS `SNSMAT`): `CHGET` gives the same code with and without Shift.
- **Mouse**: dragging selects; Shift+click extends; with the pointer on the top/bottom edge of the text the view scrolls by itself.
- **Commands**: Ctrl+C or Ctrl+Ins copies · Ctrl+X or Shift+Del cuts · Ctrl+V or Shift+Ins pastes · Ctrl+A selects all.
  Typing, Enter, Tab, BS and Del replace / delete the selection. (Ctrl+X and SELECT both give code 18h: they are told apart via the matrix.)
- **Drawing**: selected characters use the inverse glyphs (128-255); a selected line break is also an inverse block at the end of the line.
  During drawing the selection becomes a range of physical addresses, compared against a per-character `selmark`.
- **Clipboard**: in RAM above the variables (C400h up to 768 bytes below the BDOS in the `.COM`; 2.5 KB at E600h in the ROM build).
  Larger selections: "Selection too big for the clipboard". Pasting with no space: "No room to paste".
- No in-place modification of the anchor: after every text change the anchor is reset (the logical offsets would change).
- Not done: undo, word/line selection (double/triple click), clipboard shared between sessions, right button.

## Menu bar
Test: `python emenu.py` (ROM build, 34 checks); `ecom.py` also tests File > New and File > Open... from the menu under DOS.
- **Row 0**: ` File  Edit  Help ` (columns 0-17, 6 per title) · file name (or `(untitled)`) with `*` if modified, at column 19 ·
  `Ln row/total  Col n` at column 48. A status message replaces name and state until the next key press; the titles stay.
- **Opening**: ESC (opens File) or click on a title. The title of the open menu is in normal video (the rest of the bar is inverse).
- **Keyboard**: ←/→ change menu (wrapping) · ↑/↓ change item (wrapping) · Enter executes ·
  letter = item hotkey (N/O/S/A/X in File, T/C/P/D/A in Edit, S/A in Help) · ESC closes.
- **Mouse**: moving the pointer highlights the item; clicking an item executes it; clicking another title changes menu,
  clicking the same title or outside the box closes (without passing the click to the text).
- **Items**: File: New, Open..., Save, Save As..., Exit · Edit: Cut, Copy, Paste, Delete, Select all · Help: Shortcuts, About.
  In the ROM build (without DOS) the File items show "No disk access in this build".
- **Drawing**: box in inverse video with a frame of custom glyphs (codes 6-12: lines and corners, with the inverse copies at 134-140);
  with the menu open the cursor is hidden; on closing or changing menu the text underneath is redrawn.
- **File > New** asks for confirmation if there are changes (same mechanism as Open/Exit: the command is repeated).
- Not done: separators and disabled (grayed) items, submenus, View/Search menus, Alt/GRAPH to open the menus.

## Find / replace
Test: `python esrch.py` (ROM build, 34 checks with a Python model); all suites: `etest` 41 · `esel` 30 · `emenu` 34 · `esrch` 34 · `ecom` 22.
- **Commands**: Ctrl+F find · Ctrl+G find again · Ctrl+T replace · **Find** menu (Find..., Find next, Replace..., Match case: off/on).
  The menu now has 4 titles (` File  Edit  Find  Help `); file name and messages start at column 25.
- **Line prompt** (`prompt_line`, also used for file names): on the title bar, spaces allowed, up to 30 characters,
  starts from the previous term (edit it with BS or accept it with Enter), Esc cancels.
- **Search**: from the cursor to the end, then from the beginning to the cursor ("Search wrapped around" message);
  "Text not found" if there is none. The match found becomes the selection (same inverse-video highlighting),
  the cursor goes to the end of the match and the line is centered if it was not visible.
  By default it is case-insensitive; "Match case" in the Find menu makes it case-sensitive.
- **Replace**: asks for the term and the replacement text (can be empty) and then, for each match from the cursor to the end,
  `Y` replaces · `N` skips · `A` replaces all the remaining ones without asking · `Esc` stops.
  At the end "Replaced N occurrence(s)". The inserted text is not searched again (no infinite loop).
- **Implementation**: the gap stays on the cursor, so the text after the cursor is contiguous in memory (and so is the text before it):
  the scan is a loop with a first-character filter (`or mask`) and a full comparison only on candidates;
  for this reason matches straddling the cursor in the wrap-around pass are not found. Replacements reuse `ins_block`
  (the same code as paste) and `sel_delete`, with a cost proportional to the distance between matches.
- The `.COM` now has the text buffer at 2800h-BFFFh (about 38 KB); `ed.com` is 7.9 KB.
- Not done: backward search, whole word, highlighting all occurrences, selected text as default term.

## Undo / redo
Test: `python eundo.py` (ROM build, 42 checks with a Python model); `ecom.py` also tests undo/redo under DOS and the history reset after Open.
All suites: `etest` 41 · `esel` 30 · `emenu` 34 · `esrch` 34 · `eundo` 42 · `ecom` 25.
- **Commands**: Ctrl+Z undo · Ctrl+Y redo · Undo / Redo items at the top of the Edit menu (hotkeys U / R). Messages: "Nothing to undo" / "Nothing to redo".
- **One undo step = one group**: a series of key presses of the same kind (characters, Enter and Tab; Backspace; Del) is a single group;
  any other key, click or menu command closes it. Cut, paste (which replaces a selection) and global replace
  (also with Y/N/A confirmation) are one step each.
- **After an undo** the cursor goes where the change was undone (after the restored text for a deletion,
  at the start for an insertion); a new change discards the redo tail; Open and New reset the history.
- **Log** (`UNDO`): record = type (1 insertion, 2 deletion; bit 7 = merged with the previous group), offset, length, data,
  and at the end the record size (to read backwards). Contiguous text key presses merge into a single record (up to 200 bytes).
  Capacity: 3 KB in the `.COM` (C400h-CFFFh, the clipboard starts at D000h), 2 KB in the ROM build. When the log is full the oldest
  groups are discarded (and the log is compacted); if a single change is larger than the whole log, the history is reset with
  "Edit too large to undo - history cleared".
- **Known limit**: a very long series of Backspaces (8-byte records) fills the log and, being a single group, loses the oldest records
  (the last ~256 deleted characters can be undone). It is not remembered which version corresponds to the saved file: after an undo the text counts as "modified".

## Notes on the tests
- The tests now run with `set renderer none` (no openMSX window): previously the window opened in the foreground on every run
  and seemed to receive real keystrokes from the PC keyboard (repeats of a single letter appeared in the prompts or in the text,
  about 2 times out of 40). Without the window: 0 failures in 60 + 140 runs.
- The `.COM` now has the text buffer at 3300h-BFFFh (~35 KB); `ed.com` is 12.4 KB.


## Run (F5) — link to the compiler
**Run** menu (last on the bar) or **F5**: saves the source (asks for the name if missing, appends `.BAS` if there is no
extension), chain-loads `QBC.COM`, compiles and runs; at the end the program reloads the editor (`SAMPRBAS.COM`).
On error the editor restarts with the cursor on the line and the message `Line N: ...` in the title.
F5 is an MSX function key: at startup the editor sets the F5 string to a single byte (15h) and handles it as a command.
The file must be named `SAMPRBAS.COM` on the disk (the compiler reloads it by name). See `../onmsx/README.md`.
Test: `python erun.py` (uses `../onmsx/qbc.asm`).

## Keyword colors (stage 24)
The BASIC keywords (statements, functions, `REM`, `__ASM`/`__ENDASM`, `TARGET`...: 143 words, table generated by `gen_kw.py`
from `../onmsx/qbc.asm`) appear in light yellow on blue, the rest in white. In SCREEN 0 at 80 columns there are only two colors
(R#7 and R#12), but the blink table assigns one of the two to each cell: with R#13 = 10h the cells with the bit set always stay in the color of R#12
(KWCOL = 0B4h). Rules (same as the Python model in `ekw.py`): words of 2-10 characters made of letters, digits, `_` and `$`, not within quotes
and not starting with a digit; an apostrophe or `REM` ends the coloring on the line; upper and lower case are equivalent.
The computation does not slow down typing: after every redraw the colors are cleared and recomputed in idle time (two rows per frame,
reading the text from VRAM), so they appear a fraction of a second after the text; with a key waiting nothing is computed.
The cursor, which previously used the hardware blink, is now the inverse glyph of the cell (same blinking: 32 frames).
Test: `python ekw.py` (the Python model compares the flags of all 22 rows, also after scrolling); the other tests read the cursor cell
from `blx`/`bly`/`curch`. Note: the ROM test build (with the demo text) now has only ~90 free bytes in the 16 KB.

## Faster F5
- If the text has not changed since the last load/save (`modified` = 0 and `onfile` = 1) F5 does not save the source (saves ~3 s of disk time).
- If in addition the program has just been run from this compilation (`compiled` = 1: the editor was reopened from NAME.COM with the command line `NAME.BAS +`)
  F5 does not recompile: it directly loads NAME.COM with the loader (`run_only`; if the file is missing, it recompiles). `compiled` is cleared when the text changes
  (at save time with `modified` = 1), with Open and with New. Test: `erun.py` (F5 without changes within 12 s).
- **In-place save**: if the file exists and is not much longer than the text, `save_file` opens it and overwrites it (without deleting and recreating it: 1.3 s instead of 3.1 s on DOS 1);
  if the new text is shorter it writes ^Z after the text and the rest stays as residue (loading stops at ^Z; the compiler truncates the source at ^Z).
  If the file is longer than the text by more than 1 KB (or exceeds 64 KB) it is deleted and recreated as before. Test: `python esave.py`.

## MSX1: 40 columns (stage 25)
At startup the editor reads the MSX version (byte 002Dh): on MSX1 it uses 40-column text (TEXT 1, pattern table at 0800h), on MSX2 and later
the 80 columns as before (TEXT 2, patterns at 1000h). All the geometry is in variables computed by `width_init` (`sw` = 80/40, `swm1` = column of the vertical
bar, `thv` = cells of the horizontal track, `hmaxw` = maximum horizontal scroll = 256 - sw, `pattb`, `mxmax` = sw*8 for the mouse, ...);
`cell_addr` multiplies the row by `sw`. At 40 columns: the menu bar occupies columns 0-29, on the right there is the compact `row:column` status
(with `*` if the text is modified) and a message takes up the whole bar; the menu boxes shift left so as not to go off screen
(`menu_info`). The following do not exist on MSX1 (TMS9918): the blink table and therefore the keyword colors, R#12, R#13 and R#14 (never written: register
number 12-14 would overlap R#4-R#6 and break the screen); the cursor is still the inverse glyph.
Test: `python e40.py` (ROM build on MSX1, openMSX `Sony_HB-75P`: layout, cursor, vertical and horizontal scrolling, bars, mouse, Run menu); the other tests
remain on MSX2. The `.COM` (with DOS) has not yet been tried on MSX1: in openMSX the MSX1 with the AVT disk interface boots into Disk BASIC.

## Keyboard menus
- **Esc** opens the File menu; **F1, F2, F3, F4** directly open File, Edit, Find, Help (at startup the editor redefines the function key strings F1-F4 to a single
  control character: 02h, 04h, 05h, 0Ah); **F5** runs (Run). With a menu open: F1-F4 switch to that menu, **←/→** to the adjacent menu, **↑/↓** choose the item,
  **Enter** executes it, the underlined letter of each item executes it directly, **Esc** closes; F5 closes the menu and launches the program.
- At startup the keyboard buffer is discarded (`KILBUF`), so keys left over from the previous launch do not restart F5; the runtime does the same before waiting for the
  key at the end of the program ("Press any key.."). Test: `python efk.py`.
- **Key still held on return**: the key pressed to exit from "Press any key.." may still be down while the editor reloads (with the emulator at full speed
  many emulated seconds pass during disk access) and the MSX keyboard repeats it: the editor received dozens of Enters and `cls` dropped to row 17 with the text "modified".
  Now the runtime (`rt_keyup`, after the end-of-program key) and the editor (`keys_up`, at startup) wait until no key is pressed (SNSMAT on rows 0-8, at most
  ~10 s) before proceeding.

## .SPB files, open window, Help and About (version 1.0)
- The editor executable is called `SAMPRBAS.COM` (the chain loader reloads it by name, `ldr_fn` in `onmsx/ldr.asm`).
- Sources have the extension `.SPB` (SamPr Basic). `SAMPRBAS name` opens `NAME.SPB` if it exists, otherwise starts with a new file
  already named `NAME.SPB`; the extension is added only if missing (`ensure_spb`). The compiler (`QBC.COM`) uses the same default.
- Save As (Ctrl+W, and F5 on an unnamed text) asks for at most 8 characters and always appends `.SPB` (`prompt_spb`, `spb_force`).
- File > Open is a full-screen window (`k_open`, `bw_*` in `fileio.asm`, source in `browser.inc`): sorted `.SPB` files, two columns at 40
  columns / four at 80; with MSX-DOS 2 also folders (`[NAME]`, `[..]`, functions 40h/41h/5Ah/59h; DOS 2 is recognized by `_DOSVER`
  B>=2), with DOS 1 only files (FCB search 11h/12h). Keys: arrows, PgUp/PgDn, Home, a letter to jump, Enter, Esc. The state lives
  in the gap (2 KB, requires `gsz` >= 2048). The text buffer now starts at `BUF equ 3E00h` (about 24 KB).
- Help menu: Index (F7), Topic..., On word (F6), Shortcuts, About ("SamPr Basic 1.0 / 2026 Fausto Pracek"). Help reads `HELP.TXT`/`HELP.IDX`
  (generated by `../doc/gen_help.py`) with block BDOS reads into the gap area.
- Testing: `ebrowse.py` (DOS 1; with `DOS2=1 GMACHINE=Panasonic_FS-A1ST` also folders and `..`), `ehelp.py` (help and About), `emenu.py`.

## About with frame, Segment (F8), working directory on DOS 2
- About (`k_about`): centered 24-column window with the menu borders (`mrow_*`), OK button in normal video; closes with Enter, Esc or a click on the
  button. The `modal` flag (RAMB+0447h) diverts mouse clicks to `modal_click` (button coordinates in `hlptop`/`hlpbeg`, result in `hlpbeg+1`).
- File > Segment... (F8, `k_segment` in `fileio.asm`): the current file name must be 5 characters + 3 digits; type the number (zeros optional),
  the current file is saved if modified and `NAMEnnn.SPB` is opened in the same directory (new, with that name, if missing).
- MSX-DOS 2: `isdos2` (RAMB+045Eh); `d2_detect` (`_DOSVER`), `d2_path` (path `A:\DIR\NAME` on the command line: CHDIR and name), `d2_proj` (on return from the
  compiler or the program, i.e. with the `+` or `E` marker, CHDIR to `SPBPROJ`), `set_proj` (F5: `SPBPROJ` = current directory), `cd_home` (before
  loading QBC.COM: CHDIR to `SPBHOME`, which is the startup directory if not already set). `BUF equ 3F00h` (text buffer of about 24 KB).
- Testing: `eseg.py`, `edir.py` (DOS 2: path, compilation from the tools, return to the folder), `ebrowse.py`, `emenu.py`.
