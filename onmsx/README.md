# SamPr Basic su MSX — compilatore Z80 (stadi 1, 2a, 2b)

Il compilatore BASIC gira **sull'MSX2** (MSX-DOS 1/2, nessun aiuto dal PC). Progetto completo e piano a stadi:
`../DESIGN-ONMSX.md`.

## Uso (su macchina)
Copia `dist\QB.COM` (editor), `dist\QBC.COM` (compilatore) e `dist\RT.BIN` (runtime) sul disco, poi `QB PROG.BAS`, **F5** (o menu Run).
F5 salva il sorgente, carica `QBC.COM` a catena, che genera `PROG.COM`, lo scrive su disco e lo avvia.
Alla fine il programma attende un tasto e ricarica l'editor. Se la compilazione fallisce l'editor si riapre sul
sorgente con il cursore sulla riga dell'errore e il messaggio nel titolo (`Line 4: Syntax error`).
Il DOS 1 non ha EXEC: la catena usa un caricatore di 135 byte (`ldr.asm`) copiato a C000h e la riga di comando
a 0080h come mailbox (`" NOME.BAS"`, in caso di errore `" NOME.BAS E<riga> <codice>"`).

## File
- `qbc.asm` — compilatore (circa 10 KB; il runtime NON e' incorporato ma si legge da `RT.BIN` all'avvio della compilazione): lexer, espressioni, istruzioni, emissione diretta di codice macchina.
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
Limiti: sorgente 14 KB (tabelle spostate a 3800h), programma 16 KB, 96 etichette, 100 variabili/array, 20 SUB/FUNCTION (max 8 parametri, 64 in totale), 32 nomi locali per funzione, circa 590 righe in OPTION NUMBERED, 24 blocchi annidati, nomi significativi su 12 caratteri, dati del programma fino a (0006h)-0C00h.

## Codici di errore (tail dell'editor)
1 sintassi · 2 etichetta/riga inesistente · 3 non ancora supportato (stringhe, array, funzioni) · 4 carattere illegale
· 5 blocco non chiuso · 6 ELSE/END IF/NEXT/WEND senza blocco · 7 duplicato · 8 troppe variabili/etichette/blocchi
· 9 programma troppo grande · 10 sorgente troppo grande · 11 lettura · 12 scrittura · 13 non ammesso con l'OPTION scelta · 14 tipi incompatibili o array non dichiarato · 15 dati del programma troppo grandi.

## Risultati
`zrun.py` 47/47 (anche con RAM iniziale casuale), `qtest.py` 47/47 (openMSX), `gtest.py` 23/23 (grafica: pixel, palette e testo letti dalla VRAM) (openMSX; INPUT con tasti battuti dal test),
`../editor/erun.py` 12/12, `ecom.py` 25/25.
Grafica per i giochi (stadio 14): `VBANK`, `VPOKE`/`VPEEK` a 17 bit, `VFILL`, `VWRITE`, `VREAD$`, `BASE(n)`, `VDP(n)` / `VDP(n)=v`, `STICK`, `STRIG`, `COLOR=(n,r,g,b)`, `COLOR=RESTORE`, `COLOR SPRITE(n)=c`, `COLOR SPRITE$(n)=colori` (gtest 250 controlli).
Stadio 15: `PSET/LINE ...,op` (PSET PRESET AND OR XOR e T...), `COPY (..)-(..),pag TO (..),pag,op`, `SET PAGE vis,att` (SCREEN 5-8, anche CLS/testo/PAINT/GET/PUT sulla pagina attiva), `SET SCROLL x,y`, `DATA`/`READ`/`RESTORE [etichetta subito prima di un DATA]`, SCREEN 3 (PSET/POINT/LINE/CIRCLE; non PAINT/GET/PUT/testo), SCREEN 10-12 (solo MSX2+: CHGMOD 8 + R#25 YJK/YAE; collaudati su openMSX FS-A1ST con `GMACHINE=Panasonic_FS-A1ST python gtest.py`, test `p*.bas`). Tutta la catena (compilatore + gtest) gira anche sull'FS-A1ST (turbo R, DOS2).
Stadio 16 (suono): `BEEP`, `SOUND reg,val`, `PLAY v1$[,v2$[,v3$]]` (MML bloccante a 3 voci: A-G # + -, R, O, L, T, V, N, < >, punti; tempo a risoluzione di 1 JIFFY; collaudo `stest.py` che campiona i registri del PSG). Memoria: RAM runtime a C090h, tabelle del compilatore a 3400h, sorgente fino a 15 KB.
Stadio 17 (file di testo): `OPEN nome$ FOR INPUT|OUTPUT|APPEND AS [#]n` (n = 1-3), `CLOSE [#n,...]`, `PRINT #n,` (anche con `,` a zone), `WRITE #n,`, `INPUT #n, var,...`, `LINE INPUT [#n,] var$`, `EOF(n)`, `KILL`; i file aperti si chiudono a fine programma. FCB + record casuali da 128 byte, righe CRLF e ^Z finale; collaudato su MSX2/DOS1 e su FS-A1ST/DOS2 (`qtests/f*.bas`). Il suono e' collaudato in ogni comando (BEEP, V, L, M/S, punti, T).
Stadio 18 (cartucce ROM, compilatore `QBCR.COM` + runtime `RTROM.BIN`): `OPTION TARGET ROM16 | ROM32 | ASCII8 | ASCII16 | KONAMI | SCC` come prima riga; QBC.COM lo riconosce e passa a QBCR.COM (stessa riga di comando). Il risultato e' `NOME.ROM` (header AB, INIT che abilita la pagina 2 e inizializza i registri di banco; file di 16 KB per ROM16, 32 KB o piu' per gli altri); a fine programma, dopo un tasto, la macchina si riavvia. I file (OPEN...) non ci sono nelle cartucce (errore).
Multisegmento (ASCII8/ASCII16/KONAMI/SCC): `SEGMENT n` (n = precedente + 1) sposta il codice nel segmento n (finestra a 8000h; 16 KB per ASCII16, 8 KB per gli altri; il segmento 0 e' fisso a 4000h-7FFFh con il runtime). Una SUB/FUNCTION di un altro segmento si chiama come al solito (o `CALL FAR nome`): il compilatore emette `ld a,k / call RT_FARCALL`, la routine cambia banco con una pila software e ripristina il banco al ritorno (argomenti e risultato passano normalmente; le stringhe passate vengono copiate nello heap). Le etichette e i DATA restano nel proprio segmento (GOTO fra segmenti = errore). Dati: `INCBIN "file"` mette i byte nel segmento corrente (in genere un segmento tutto per lui), `SETBANK n` mappa il segmento n nella finestra dati (`DATAWIN` = A000h per i banchi da 8 KB, 8000h per ASCII16, dove coincide con la finestra del codice), `VCOPY memoria, vram, quanti` copia nella VRAM (anche nei .COM). Collaudo: `rtest.py` (compila su openMSX/DOS e avvia le ROM con -cart) e `qtests/e30-e34`.
Non ancora supportati: float, file ad accesso casuale/binari (BLOAD/BSAVE), mapper RAM.
Non provato su MSX reale (disco fisico, Nextor/DOS2).
