# MSXQB — prototipo cross (Python → Z80) — storico, sostituito da SamPr Basic

Ambiente stile QuickBASIC per MSX2: questo è il prototipo che fissa linguaggio, runtime
e convenzioni di codegen. Il compilatore è one-pass con emissione diretta (niente AST),
così da poter essere riscritto in Z80 per l'IDE vero.

    python build.py tests\t1.bas      # compila, assembla, esegue in openMSX (NMS-8250), confronta con t1.exp

File: `qbc.py` (compilatore), `runtime.asm` (runtime ~1 KB, ROM 16K a 4000h), `build.py` (harness),
`tests/t1..t5` (.bas + .exp, t5 usa `.keys` per digitare l'input).

## Linguaggio v0
- Tipi: INTEGER 16 bit con segno (default), STRING (`$`, max 255). Niente float: `/` è divisione intera.
- `PRINT` (`;` `,`, numeri con spazio/segno iniziale e spazio finale come QB), `INPUT ["p";] v`, `CLS`, `LOCATE r,c`, `COLOR f,b`
- `IF/ELSEIF/ELSE/END IF` (a blocchi e su riga singola), `FOR/NEXT` (STEP costante), `WHILE/WEND`,
  `DO [WHILE|UNTIL]/LOOP [WHILE|UNTIL]`, `SELECT CASE` (valori, `a TO b`, `IS op x`, `ELSE`), `EXIT FOR/DO/SUB/FUNCTION`
- `GOTO/GOSUB/RETURN` con label o numeri di riga, `END`, `STOP`
- `SUB/FUNCTION` con parametri per valore, locali, ricorsione, `SHARED`, `CALL`, `DECLARE` (ignorata: firme prescansionate)
- `DIM a(n)` (array globali di interi, con controllo dei limiti), `CONST`
- Operatori: `+ - * / \ MOD AND OR XOR NOT = <> < > <= >=` e concatenazione/confronto stringhe
- Funzioni: `LEN ASC VAL ABS SGN RND(n) CHR$ STR$ LEFT$ RIGHT$ MID$ INKEY$ TIMER PEEK VPEEK INP`
- Istruzioni MSX: `POKE VPOKE OUT SLEEP(frame) RANDOMIZE`

## Modalità di indirizzamento (scelta dell'utente)
Prima riga del sorgente (o impostazione dell'IDE, `qbc.py in out [mode]`):
- `OPTION NUMBERED` — stile BASIC classico: ogni riga ha il numero, le righe vengono ordinate per numero
  (duplicati = errore), `GOTO/GOSUB/THEN` solo con numeri, niente etichette.
- `OPTION LABELS` — stile QuickBASIC: `nome:` e `GOTO nome`; i numeri di riga sono errore.
- `OPTION MIXED` (default) — entrambi. In tutte le modalità un salto a una riga/etichetta inesistente è un errore di compilazione
  con la riga sorgente. `IF x THEN etichetta` è ammesso come in QB.
Test: `tests/t6` (numbered, righe fuori ordine), `tests/t7` (labels), `tests/negative.py` (9 errori attesi).

## Convenzioni di codegen
- Accumulatore HL; operando sinistro sullo stack, destro in HL, `pop de`. Booleani -1/0.
- Stringa = puntatore a `[len][dati]`. Variabili stringa = buffer fisso da 256 byte (globali in RAM, locali nel frame).
  Temporanei sullo heap a bump; ogni statement che ne crea salva/ripristina `heapp` (nessun GC necessario).
  Una FUNCTION stringa copia il risultato sullo heap in uscita.
- SUB/FUNCTION: argomenti sullo stack (primo più profondo), frame IX, 64 byte per i locali interi
  (max 30) + 256 per ogni locale stringa; pulizia a carico del chiamante.
- FOR: il limite resta sullo stack per tutto il ciclo; test in testa.

## Limiti noti v0
Niente float, array di stringhe, STEP variabile, parametri stringa modificabili, GOTO fuori da FOR/SELECT
lascia roba sullo stack, locali interi non azzerati all'ingresso, programma ≤ 16 KB (ROM).
