# SamPr Basic su MSX — compilatore Z80 (stadi 1, 2a, 2b)

Il compilatore BASIC gira **sull'MSX2** (MSX-DOS 1/2, nessun aiuto dal PC). Progetto completo e piano a stadi:
`../DESIGN-ONMSX.md`.

## Uso (su macchina)
Copia `dist\QB.COM` (editor) e `dist\QBC.COM` (compilatore) sul disco, poi `QB PROG.BAS`, **F5** (o menu Run).
F5 salva il sorgente, carica `QBC.COM` a catena, che genera `PROG.COM`, lo scrive su disco e lo avvia.
Alla fine il programma attende un tasto e ricarica l'editor. Se la compilazione fallisce l'editor si riapre sul
sorgente con il cursore sulla riga dell'errore e il messaggio nel titolo (`Line 4: Syntax error`).
Il DOS 1 non ha EXEC: la catena usa un caricatore di 135 byte (`ldr.asm`) copiato a C000h e la riga di comando
a 0080h come mailbox (`" NOME.BAS"`, in caso di errore `" NOME.BAS E<riga> <codice>"`).

## File
- `qbc.asm` — compilatore (4,8 KB): lexer, espressioni, istruzioni, emissione diretta di codice macchina.
- `rtcom.asm` — runtime per .COM (immagine a 0100h con tabella di JP, `rtabi.inc`), BIOS via CALSLT.
- `ldr.asm` — caricatore a catena. Build: `ldr.asm` → `rtcom.asm` → `qbc.asm` (`--raw`/SAVEBIN in `build/`).
- `zrun.py` — collaudo veloce senza emulatore MSX (emulatore Z80 in Python + BDOS/BIOS finti, RAM a caso).
- `qtest.py` — collaudo vero in openMSX/MSX-DOS 1 (compila ed esegue t1,t6,t7 di `../tests` + `qtests/`).
- `gtest.py` + `gtests/` — collaudo della grafica su openMSX (programmi .bas e controlli sui pixel .chk).
- `qtests/` — q1..q3 (IF a blocchi, cicli, operatori, hex/bin, LOCATE) ed e1..e5 (codici di errore).
- Test dell'editor con F5: `../editor/erun.py`.

## Linguaggio (stadi 1, 2a-2d, 3a-3b: grafica)
Interi 16 bit e stringhe (max 255). `PRINT` (`;` `,` `?`), assegnamenti (`LET` opzionale), `IF/THEN/ELSE` su riga,
`IF/ELSEIF/ELSE/END IF`, `FOR/NEXT` (STEP costante, anche negativo), `WHILE/WEND`, `GOTO/GOSUB/RETURN`, `CLS`,
`LOCATE r,c`, `END`, `REM` e `'`, `INPUT ["testo";|,] var` (intera o stringa), `DIM a(n), b$(m)` (array di interi e di
stringhe, indici 0..n, controllo dei limiti), `POKE`.
Operatori `+ - * / \ MOD AND OR XOR NOT = <> < > <= >=` (anche fra stringhe; `+` concatena), costanti `&H`/`&B`.
Funzioni: `LEN ASC VAL ABS SGN RND PEEK TIMER CHR$ STR$ LEFT$ RIGHT$ MID$ INKEY$`.
`SUB`/`FUNCTION` con parametri per valore (interi e stringhe), variabili locali, ricorsione, `CALL`, chiamata di SUB senza
`CALL`, `DECLARE` (ignorata: le firme si leggono con una pre-scansione, quindi si puo' chiamare prima della definizione),
`SHARED`, `EXIT SUB/FUNCTION`, risultato di FUNCTION assegnando al suo nome (`f = ...`, `f$ = ...`).
`DO/LOOP` (`DO WHILE|UNTIL`, `LOOP WHILE|UNTIL`), `EXIT DO/FOR/WHILE`, `SELECT CASE` intero o stringa (`CASE 1`, `CASE 2, 3`,
`CASE 4 TO 6`, `CASE IS >= 7`, `CASE "a", "b" TO "m"`, `CASE IS < "a"`, `CASE ELSE`; il valore dei CASE deve avere il
tipo del selettore). Il selettore stringa si copia sullo stack (256 byte) per tutto il blocco: ricorsione sicura.
Frame IX: parametri sullo stack (il primo piu' in profondita'), salvataggio di heapp in (ix-2), 29 interi locali, 256 byte per
ogni stringa locale; i temporanei delle stringhe si liberano a fine istruzione fino al valore salvato all'ingresso.
**Array come parametri**: nella firma `SUB f(a(), n)` / `FUNCTION g$(s$())`, nella chiamata `f v(), 6` o `g$(w$())`;
l'array passa per riferimento (base e numero di elementi: due parole sullo stack), si puo' leggere e scrivere `a(i)` con
controllo dei limiti, si puo' ripassare ad altre routine, e `UBOUND(a)` da' il massimo indice (anche per array globali).
Il tipo degli elementi deve coincidere; un array parametro usato senza indice e' un errore di tipo.
**Grafica bitmap MSX2** (`SCREEN 5` 256x212x16, `6` 512x212x4, `7` 512x212x16, `8` 256x212x256; gli altri modi 0-4 si
possono selezionare ma le primitive grafiche danno "Graphics needs SCREEN 5-8"): `SCREEN n`, `PSET (x,y)[,c]`, `PRESET (x,y)[,c]`
(colore di sfondo), `POINT(x,y)` (-1 fuori schermo), `LINE [(x1,y1)]-(x2,y2)[,c[,B|BF]]` (senza primo punto parte dall'ultimo punto
grafico; `B` riquadro, `BF` riquadro pieno; colore omesso = quello di `COLOR`), `CIRCLE (x,y),r[,c]`.
Le coordinate fuori schermo sono ritagliate (le linee che escono usano Bresenham punto per punto), i colori sono il valore grezzo del
modo (0-15, 0-3, 0-255). Le primitive usano il motore comandi del VDP (LINE, LMMV, PSET, POINT). Non ancora: `PAINT`, testo in grafica,
sprite, `PALETTE`. In grafica a fine programma si attende un tasto senza messaggio.
`CONST nome = [-]numero {, ...}` (usabile in espressioni e come dimensione di `DIM`; assegnarla e' un errore),
`COLOR fg[, bg]`, `RANDOMIZE n`, `SLEEP frame`, `STOP`, `VPOKE addr, v` / `VPEEK(addr)` (VRAM 0-16383 via BIOS),
`OUT porta, v` / `INP(porta)`.
La BIOS (CALSLT) distrugge IX: il runtime lo salva attorno a ogni chiamata BIOS.
Stringhe: ogni variabile e' un buffer fisso da 256 byte; i temporanei stanno su uno heap a bump rilasciato a fine
istruzione (e dopo le condizioni di IF/WHILE). Nomi `A$` e `A` distinti; `A%` = `A`.
`OPTION NUMBERED` (righe ordinate per numero, solo numeri), `OPTION LABELS` (solo etichette), `OPTION MIXED` (default).
Limiti: sorgente 14 KB, programma 16 KB, 96 etichette, 100 variabili/array, 20 SUB/FUNCTION (max 8 parametri, 64 in totale), 32 nomi locali per funzione, circa 590 righe in OPTION NUMBERED, 24 blocchi annidati, nomi significativi su 12 caratteri, dati del programma fino a (0006h)-0C00h.

## Codici di errore (tail dell'editor)
1 sintassi · 2 etichetta/riga inesistente · 3 non ancora supportato (stringhe, array, funzioni) · 4 carattere illegale
· 5 blocco non chiuso · 6 ELSE/END IF/NEXT/WEND senza blocco · 7 duplicato · 8 troppe variabili/etichette/blocchi
· 9 programma troppo grande · 10 sorgente troppo grande · 11 lettura · 12 scrittura · 13 non ammesso con l'OPTION scelta · 14 tipi incompatibili o array non dichiarato · 15 dati del programma troppo grandi.

## Risultati
`zrun.py` 42/42 (anche con RAM iniziale casuale), `qtest.py` 42/42 (openMSX), `gtest.py` 8/8 (grafica: pixel, palette e testo letti dalla VRAM) (openMSX; INPUT con tasti battuti dal test),
`../editor/erun.py` 12/12, `ecom.py` 25/25.
Non ancora supportati: float, sprite, suono, file.
Non provato su MSX reale (disco fisico, Nextor/DOS2).
