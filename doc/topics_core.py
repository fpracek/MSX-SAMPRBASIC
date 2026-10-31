# -*- coding: utf-8 -*-
"""Contenuti: linguaggio di base (struttura, flusso, dati, testo, funzioni). Ogni voce: T(nomi, categoria, sintassi, descrizione, esempio, vedi, disponibilita')."""

TOPICS = []


def T(names, cat, syn, desc, ex=None, see=None, avail=None):
    if isinstance(names, str):
        names = [names]
    TOPICS.append(dict(names=names, cat=cat, syn=syn if isinstance(syn, list) else [syn], desc=desc.strip(), ex=ex.strip('\n') if ex else None,
                       see=see or [], avail=avail or 'MSX1 e MSX2'))


# ------------------------------------------------------------------ struttura del programma
C = 'Struttura del programma'
T(['REM', "'"], C, ["REM commento", "' commento"],
  "Commento: tutto il resto della riga viene ignorato. L'apostrofo si può mettere anche dopo un'istruzione, sulla stessa riga.",
  'REM questo e\' un commento\nPRINT "ciao"   \' anche questo', ['PRINT'])
T(['ETICHETTE', 'LABELS', 'LINEE'], C, ["nome:", "10 PRINT \"x\""],
  "Un programma può usare etichette (`nome:` da solo su una riga o davanti a un'istruzione) e/o numeri di riga. GOTO, GOSUB e il "
  "ripristino con RESTORE accettano l'una o l'altro. Il modo si sceglie con OPTION: NUMBERED (solo numeri, ordinati per numero), "
  "LABELS (solo etichette) o MIXED (predefinito, entrambi). I nomi delle etichette seguono le regole dei nomi di variabile. "
  "Più istruzioni sulla stessa riga si separano con i due punti.",
  'inizio:\n  PRINT "a" : PRINT "b"\n  GOTO fine\n  PRINT "mai"\nfine:\n  PRINT "fine"', ['OPTION', 'GOTO', 'GOSUB'])
T(['TIPI', 'VARIABILI', 'NOMI'], C, ["a   a$   a(10)   a$(10)"],
  "Esistono due tipi: interi a 16 bit con segno (da -32768 a 32767) e stringhe (fino a 255 caratteri). Il nome di una variabile stringa "
  "termina con `$`; `A` e `A$` sono variabili distinte. Il suffisso `%` si accetta e si ignora (`A%` è `A`). I nomi non distinguono "
  "maiuscole e minuscole; sono significativi i primi 11 caratteri più il suffisso. Le variabili non dichiarate valgono 0 o la "
  "stringa vuota. Valori numerici: decimali, esadecimali `&H1F`, binari `&B101`. Il valore \"vero\" di un confronto è -1, il \"falso\" 0.",
  'n = &HFF\nb = &B1010\nPRINT n; b\nPRINT 3 > 2; 3 < 2', ['DIM', 'CONST', 'OPERATORI'])
T(['OPERATORI', 'AND', 'OR', 'XOR', 'NOT', 'MOD'], C, ["+  -  *  /  \\  MOD", "=  <>  <  >  <=  >=", "NOT  AND  OR  XOR"],
  "Aritmetici: `+ - * /` e `\\` (divisione intera, anche `/` fra interi) e `MOD` (resto). Confronti: `= <> < > <= >=` (anche fra stringhe, "
  "in ordine alfabetico). Logici bit a bit sugli interi: `NOT AND OR XOR`. Il `+` concatena le stringhe. In caso di dubbio sulla "
  "precedenza usare le parentesi: prima gli operatori aritmetici, poi i confronti, poi quelli logici.",
  'PRINT 7 \\ 2; 7 MOD 2\nPRINT 5 AND 3; 5 OR 3; 5 XOR 3\nPRINT "ab" + "cd"; "a" < "b"', ['TIPI'])
T('CONST', C, ["CONST nome = [-]numero {, nome = numero}"],
  "Definisce costanti numeriche. Si usano nelle espressioni e come dimensione di DIM; assegnare un valore a una costante è un errore.",
  'CONST max = 5, base = 100\nDIM a(max)\na(max) = base + 1\nPRINT a(5)', ['DIM'])
T('LET', C, ["[LET] variabile = espressione", "[LET] array(i) = espressione"],
  "Assegna un valore a una variabile o a un elemento di array. La parola LET è facoltativa. Il tipo dell'espressione deve coincidere con quello "
  "della variabile (altrimenti errore 14: tipi incompatibili).",
  'LET a = 5\nb$ = "ciao"\nc = a * 2\nPRINT b$; c', ['DIM'])
T(['END', 'STOP'], C, ["END", "STOP"],
  "Termina il programma. In un programma .COM mostra \"Press any key..\" e attende un tasto (poi torna all'editor); in una cartuccia attende un "
  "tasto e riavvia la macchina. Alla fine del sorgente il programma termina da solo. In un programma STOP equivale a END (non c'è il "
  "debugger interattivo: per questo vedi OPTION DEBUG). Con un secondo termine END chiude anche i blocchi: END IF, END SUB, END FUNCTION, END SELECT.",
  'PRINT "inizio"\nEND\nPRINT "mai"', ['DEBUG'])
T('DECLARE', C, ["DECLARE SUB nome(...)", "DECLARE FUNCTION nome(...)"],
  "Accettata per compatibilità e ignorata: le firme di SUB e FUNCTION si leggono con una pre-scansione del sorgente, quindi una routine si può "
  "chiamare prima di essere definita.", None, ['SUB', 'FUNCTION'])

# ------------------------------------------------------------------ flusso
C = 'Controllo del flusso'
T(['IF', 'THEN', 'ELSE', 'ELSEIF', 'END IF'], C,
  ["IF condizione THEN istruzione [ELSE istruzione]", "IF condizione THEN", "  ...", "[ELSEIF condizione THEN", "  ...]", "[ELSE", "  ...]", "END IF"],
  "Esegue istruzioni in base a una condizione (vera se diversa da zero). Forma su una riga: `IF a > 3 THEN PRINT \"si\" ELSE PRINT \"no\"`. "
  "Forma a blocchi: `IF ... THEN` a fine riga, un numero qualsiasi di `ELSEIF`, un `ELSE` facoltativo e `END IF`. I blocchi si possono annidare.",
  'n = 5\nIF n > 9 THEN\n  PRINT "grande"\nELSEIF n > 3 THEN\n  PRINT "medio"\nELSE\n  PRINT "piccolo"\nEND IF', ['SELECT CASE', 'OPERATORI'])
T(['FOR', 'NEXT', 'TO', 'STEP'], C, ["FOR variabile = inizio TO fine [STEP passo]", "  ...", "NEXT [variabile]"],
  "Ciclo con contatore. STEP è una costante intera, anche negativa; se omesso vale 1. Il ciclo non viene eseguito se il valore iniziale supera "
  "già il finale. `EXIT FOR` esce dal ciclo. I cicli si possono annidare.",
  'FOR i = 1 TO 10 STEP 3\n  PRINT i;\nNEXT i\nPRINT\nFOR j = 3 TO 1 STEP -1\n  PRINT j;\nNEXT j', ['EXIT'])
T(['WHILE', 'WEND'], C, ["WHILE condizione", "  ...", "WEND"],
  "Ripete il blocco finché la condizione è vera (controllo all'inizio). `EXIT WHILE` esce dal ciclo.",
  'n = 3\nWHILE n > 0\n  PRINT n;\n  n = n - 1\nWEND', ['DO', 'EXIT'])
T(['DO', 'LOOP', 'UNTIL'], C, ["DO [WHILE|UNTIL condizione]", "  ...", "LOOP [WHILE|UNTIL condizione]"],
  "Ciclo con controllo all'inizio (condizione dopo DO) o alla fine (dopo LOOP), oppure senza condizione (ciclo infinito, da interrompere con "
  "`EXIT DO`). UNTIL ripete fino a quando la condizione diventa vera.",
  'n = 0\nDO\n  n = n + 1\nLOOP UNTIL n >= 4\nPRINT n', ['WHILE', 'EXIT'])
T('EXIT', C, ["EXIT FOR | EXIT WHILE | EXIT DO", "EXIT SUB | EXIT FUNCTION"],
  "Esce subito dal ciclo (FOR, WHILE, DO) o dalla routine (SUB, FUNCTION) in corso.",
  'FOR i = 1 TO 100\n  IF i * i > 50 THEN EXIT FOR\nNEXT i\nPRINT i', ['FOR', 'DO'])
T(['SELECT CASE', 'SELECT', 'CASE', 'END SELECT'], C,
  ["SELECT CASE espressione", "  CASE valore {, valore | da TO a}", "  CASE IS operatore valore", "  CASE ELSE", "END SELECT"],
  "Sceglie fra più alternative in base a un valore intero o a una stringa. Un CASE può elencare valori (`CASE 2, 3`), intervalli "
  "(`CASE 4 TO 6`), confronti (`CASE IS >= 7`); con le stringhe anche `CASE \"a\", \"b\" TO \"m\"`. Il tipo dei valori deve coincidere con quello "
  "del selettore. `CASE ELSE` raccoglie il resto.",
  'n = 5\nSELECT CASE n\n  CASE 1, 2\n    PRINT "poco"\n  CASE 3 TO 6\n    PRINT "medio"\n  CASE IS > 6\n    PRINT "tanto"\n  CASE ELSE\n    PRINT "zero"\nEND SELECT', ['IF'])
T('GOTO', C, ["GOTO etichetta | numero"], "Salta all'etichetta o al numero di riga indicato. In una cartuccia a più segmenti la destinazione deve stare nello stesso segmento.",
  'i = 0\ngiro:\n  i = i + 1\n  PRINT i;\n  IF i < 3 THEN GOTO giro', ['GOSUB', 'ETICHETTE'])
T(['GOSUB', 'RETURN'], C, ["GOSUB etichetta | numero", "RETURN"],
  "GOSUB chiama una subroutine che inizia all'etichetta (o al numero di riga) e RETURN torna all'istruzione dopo la chiamata. Per routine con "
  "parametri e variabili locali usare SUB e FUNCTION.",
  'GOSUB saluta\nPRINT "fine"\nEND\nsaluta:\n  PRINT "ciao"\n  RETURN', ['SUB', 'CALL'])
T(['SUB', 'END SUB'], C, ["SUB nome [(parametro {, parametro})]", "  ...", "END SUB"],
  "Definisce una procedura. I parametri si passano per valore (interi o stringhe, con `$`); un array si passa per riferimento scrivendo "
  "`a()`. Le variabili usate dentro la SUB sono locali, salvo quelle dichiarate con SHARED. Si può chiamare con CALL o direttamente per nome. "
  "La ricorsione è consentita. Massimo 20 routine, 8 parametri ciascuna.",
  'SUB somma(a, b)\n  PRINT a + b\nEND SUB\nCALL somma(3, 4)\nsomma 5, 6', ['FUNCTION', 'CALL', 'SHARED'])
T(['FUNCTION', 'END FUNCTION'], C, ["FUNCTION nome[$] [(parametri)]", "  ...", "  nome = valore", "END FUNCTION"],
  "Come una SUB ma restituisce un valore: si assegna al nome della funzione (`nome = ...` oppure `nome$ = ...` per le stringhe). Si usa "
  "dentro le espressioni. Ricorsione consentita.",
  'FUNCTION doppio(n)\n  doppio = n * 2\nEND FUNCTION\nPRINT doppio(21)', ['SUB', 'CALL'])
T('CALL', C, ["CALL nome [(argomenti)]", "CALL FAR nome [(argomenti)]"],
  "Chiama una SUB. Le parentesi sono facoltative. `CALL FAR` forza la chiamata fra segmenti di una cartuccia (di norma il compilatore la "
  "riconosce da solo). CALL chiama una SUB, non un'etichetta: per le etichette usare GOSUB.",
  'SUB p(x$)\n  PRINT x$\nEND SUB\nCALL p("ciao")', ['SUB', 'SEGMENT'])
T('SHARED', C, ["SHARED variabile {, variabile}"],
  "Dentro una SUB o FUNCTION dichiara che i nomi indicati sono le variabili globali (e non variabili locali con lo stesso nome).",
  'totale = 0\nSUB aggiungi(n)\n  SHARED totale\n  totale = totale + n\nEND SUB\naggiungi 5\naggiungi 7\nPRINT totale', ['SUB', 'DIM'])

# ------------------------------------------------------------------ dati
C = 'Dati e array'
T('DIM', C, ["DIM nome(n) [, nome$(m) ...]", "DIM nome(n) MAPPER"],
  "Dichiara array di interi o di stringhe con indici da 0 a n (quindi n+1 elementi). Gli indici sono controllati: fuori limite il programma si "
  "ferma con un errore. `UBOUND(a)` dà l'ultimo indice. Gli array si passano a SUB e FUNCTION scrivendo `a()`. Con MAPPER (solo `.COM` e "
  "cartucce con mapper RAM) un array di interi sta nel mapper RAM, fino a 32768 elementi.",
  'DIM a(4), n$(2)\nFOR i = 0 TO 4\n  a(i) = i * i\nNEXT i\nn$(1) = "uno"\nPRINT a(3); n$(1); UBOUND(a)', ['UBOUND', 'MALLOC'])
T('UBOUND', C, ["UBOUND(array)"], "Restituisce il massimo indice di un array (anche quando è un parametro di una routine).",
  'DIM v(9)\nPRINT UBOUND(v)', ['DIM'])
T(['DATA', 'READ', 'RESTORE'], C, ["DATA valore {, valore}", "READ variabile {, variabile}", "RESTORE [etichetta]"],
  "DATA contiene valori (interi o stringhe fra virgolette); READ li legge in ordine nelle variabili indicate; RESTORE riporta la lettura al "
  "primo DATA oppure a quello che segue immediatamente l'etichetta indicata. Leggere oltre l'ultimo DATA è un errore.",
  'DATA 10, -20, "ciao"\nREAD a, b, s$\nPRINT a; b; s$\nRESTORE\nREAD c\nPRINT c', ['DIM'])
T(['MKI$', 'CVI'], C, ["MKI$(n)", "CVI(stringa$)"],
  "MKI$ converte un intero in una stringa di 2 byte; CVI fa l'operazione inversa. Servono con i file ad accesso casuale (campi FIELD).",
  'a$ = MKI$(1000)\nPRINT LEN(a$); CVI(a$)', ['FIELD'])

# ------------------------------------------------------------------ testo
C = 'Testo e tastiera'
T(['PRINT', '?'], C, ["PRINT [espressione {; | , espressione}] [;]", "? espressione", "PRINT #n, ..."],
  "Scrive sullo schermo. Il punto e virgola lascia il cursore subito dopo l'ultimo elemento; la virgola avanza alla zona di tabulazione "
  "successiva (colonne multiple di 14). Senza punto e virgola finale va a capo. I numeri sono preceduti da un segno (spazio se positivi) e "
  "seguiti da uno spazio; le stringhe si scrivono così come sono. `?` è un'abbreviazione di PRINT. Con `#n,` scrive nel file aperto.",
  'PRINT "somma:"; 3 + 4\nPRINT 1, 2, 3\nPRINT "a";\nPRINT "b"', ['LOCATE', 'INPUT', 'OPEN'])
T('INPUT', C, ['INPUT ["testo" ;|,] variabile', "INPUT #n, variabile {, variabile}"],
  "Legge una riga dalla tastiera nella variabile (intera o stringa). Con il testo e il punto e virgola il testo è seguito da \"? \"; con la "
  "virgola no. Si conferma con Invio; Backspace cancella. Un valore non numerico in una variabile intera dà 0. Con `#n,` legge dal file.",
  'INPUT "Nome"; n$\nINPUT "Eta", e\nPRINT "Ciao "; n$; e + 1', ['LINE INPUT', 'INKEY$'])
T('LINE INPUT', C, ["LINE INPUT [#n,] variabile$"],
  "Legge una riga intera (spazi e virgole compresi) in una variabile stringa; da tastiera o, con `#n,`, da un file.",
  'LINE INPUT a$\nPRINT "[" ; a$ ; "]"', ['INPUT'])
T('CLS', C, ["CLS"], "Cancella lo schermo e porta il cursore in alto a sinistra (nella pagina attiva in SCREEN 5-8).", 'CLS\nPRINT "pulito"', ['LOCATE'])
T('LOCATE', C, ["LOCATE riga, colonna"], "Posiziona il cursore del testo. Riga e colonna partono da 1.",
  'CLS\nLOCATE 5, 10\nPRINT "qui"', ['PRINT', 'CLS'])
T('COLOR', C, ["COLOR primo piano[, sfondo]", "COLOR = (n, r, g, b)", "COLOR = RESTORE", "COLOR SPRITE(n) = colore", "COLOR SPRITE$(n) = colori$"],
  "Imposta i colori del testo (e il bordo) con numeri da 0 a 15 (in SCREEN 8 il valore grezzo 0-255). `COLOR = (n,r,g,b)` ridefinisce un "
  "colore della palette (r, g, b da 0 a 7; MSX2) e `COLOR = RESTORE` ripristina la palette predefinita. COLOR SPRITE vedi gli sprite.",
  'COLOR 15, 4\nCLS\nPRINT "bianco su blu"', ['PALETTE', 'SCREEN'])
T('INKEY$', C, ["INKEY$"], "Restituisce il carattere del tasto premuto, oppure la stringa vuota se non ce n'è: non attende.",
  'DO\n  k$ = INKEY$\nLOOP WHILE k$ = ""\nPRINT "tasto:"; ASC(k$)', ['INPUT', 'STICK'])

# ------------------------------------------------------------------ funzioni
C = 'Funzioni numeriche e stringhe'
T('LEN', C, ["LEN(stringa$)"], "Lunghezza di una stringa.", 'PRINT LEN("ciao")', ['MID$'])
T('ASC', C, ["ASC(stringa$)"], "Codice del primo carattere della stringa (0 se è vuota).", 'PRINT ASC("A")', ['CHR$'])
T('CHR$', C, ["CHR$(codice)"], "Stringa di un carattere con il codice dato (0-255).", 'PRINT CHR$(72); CHR$(105)', ['ASC'])
T('VAL', C, ["VAL(stringa$)"], "Valore numerico di una stringa; si ferma al primo carattere non valido, 0 se non inizia con un numero.",
  'PRINT VAL("42") + 1', ['STR$'])
T('STR$', C, ["STR$(numero)"], "Rappresentazione decimale del numero come stringa (con lo spazio iniziale per i positivi).",
  'a$ = STR$(7)\nPRINT LEN(a$); a$', ['VAL'])
T('LEFT$', C, ["LEFT$(stringa$, n)"], "I primi n caratteri della stringa.", 'PRINT LEFT$("abcdef", 3)', ['RIGHT$', 'MID$'])
T('RIGHT$', C, ["RIGHT$(stringa$, n)"], "Gli ultimi n caratteri della stringa.", 'PRINT RIGHT$("abcdef", 2)', ['LEFT$', 'MID$'])
T('MID$', C, ["MID$(stringa$, inizio [, n])"], "Sottostringa: parte dal carattere `inizio` (il primo è 1) e prende n caratteri (fino alla fine se manca n).",
  'PRINT MID$("abcdef", 2, 3)\nPRINT MID$("abcdef", 4)', ['LEFT$', 'RIGHT$', 'LEN'])
T('ABS', C, ["ABS(n)"], "Valore assoluto.", 'PRINT ABS(-7)', ['SGN'])
T('SGN', C, ["SGN(n)"], "Segno: -1, 0 oppure 1.", 'PRINT SGN(-9); SGN(0); SGN(4)', ['ABS'])
T(['RND', 'RANDOMIZE'], C, ["RND(n)", "RANDOMIZE seme"],
  "RND(n) restituisce un numero pseudocasuale da 0 a n-1. RANDOMIZE imposta il seme della sequenza: lo stesso seme dà la stessa sequenza.",
  'RANDOMIZE 7\nFOR i = 1 TO 5\n  PRINT RND(100);\nNEXT i', ['TIMER'])
T('TIMER', C, ["TIMER"], "Contatore dei quadri video (1/50 o 1/60 di secondo) letto da JIFFY; a 16 bit, riparte da zero.",
  't = TIMER\nSLEEP 25\nPRINT TIMER - t', ['SLEEP'])
T('PEEK', C, ["PEEK(indirizzo)", "POKE indirizzo, valore"], "PEEK legge un byte della memoria; POKE lo scrive. Indirizzi a 16 bit (da 0 a 65535, anche con valori negativi equivalenti).",
  'POKE 50000, 77\nPRINT PEEK(50000)', ['VARPTR'])
T('POKE', C, ["POKE indirizzo, valore"], "Scrive un byte in memoria. Vedi PEEK.", 'POKE 50000, 12\nPRINT PEEK(50000)', ['PEEK'])
T('SLEEP', C, ["SLEEP quadri"], "Attende il numero di quadri video indicato (50 o 60 al secondo secondo lo standard della macchina).",
  'PRINT "aspetta"\nSLEEP 50\nPRINT "fatto"', ['TIMER'])
