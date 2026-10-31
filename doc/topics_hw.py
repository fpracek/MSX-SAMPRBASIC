# -*- coding: utf-8 -*-
"""Contenuti: grafica, sprite, suono, file, memoria, cartucce, opzioni."""
from topics_core import T

M2 = 'Solo MSX2'

# ------------------------------------------------------------------ schermo e grafica
C = 'Schermo e grafica'
T('SCREEN', C, ["SCREEN modo [, dimensione sprite]"],
  "Sceglie il modo video. MSX1: 0 (testo 40 col), 1 (testo a colori 32 col), 2 (grafica 256x192), 3 (blocchi 64x48). MSX2 aggiunge 4, 5 (256x212, 16 colori), "
  "6 (512x212, 4 colori), 7 (512x212, 16 colori), 8 (256x212, 256 colori) e, su MSX2+/turbo R, 10-12 (colori YJK). Le istruzioni PSET, LINE, CIRCLE, PAINT, "
  "GET/PUT e COPY lavorano in SCREEN 5-8 (PSET, POINT, LINE e CIRCLE anche in SCREEN 3). Il secondo parametro è la dimensione degli sprite: "
  "0 = 8x8, 1 = 8x8 ingranditi, 2 = 16x16, 3 = 16x16 ingranditi. Su MSX1 un modo oltre il 3 dà \"Illegal function call\".",
  'SCREEN 5\nCOLOR 15, 4\nCLS\nPSET (10, 10), 15\nLINE -(100, 80), 8', ['PSET', 'LINE', 'SPRITE', 'SET'], 'MSX1: modi 0-3; MSX2: 0-8 (10-12 su MSX2+)')
T(['PSET', 'PRESET'], C, ["PSET (x, y) [, colore [, operazione]]", "PRESET (x, y) [, colore [, operazione]]"],
  "Accende (PSET) o spegne (PRESET, colore di sfondo) un punto. Le coordinate fuori schermo vengono ritagliate. L'operazione logica è PSET, PRESET, "
  "AND, OR, XOR oppure la stessa preceduta da T (trasparente: il colore 0 non scrive).",
  'SCREEN 5\nPSET (128, 100), 12\nPSET (128, 100), 3, XOR', ['POINT', 'LINE'], M2 + ' (SCREEN 3 compreso)')
T('POINT', C, ["POINT(x, y)"], "Colore del punto; -1 se fuori schermo.", 'SCREEN 5\nPSET (5, 5), 9\nPRINT POINT(5, 5)', ['PSET'], M2)
T('LINE', C, ["LINE [(x1, y1)] - (x2, y2) [, colore [, B|BF [, operazione]]]"],
  "Traccia una linea; senza il primo punto parte dall'ultimo punto grafico. Con B disegna un rettangolo, con BF un rettangolo pieno. Se manca il colore "
  "vale quello di COLOR. Non va confusa con LINE INPUT (che legge una riga di testo).",
  'SCREEN 5\nLINE (10, 10)-(100, 60), 15\nLINE (20, 80)-(120, 140), 9, BF', ['CIRCLE', 'PSET'], M2 + ' (SCREEN 3 compreso)')
T('CIRCLE', C, ["CIRCLE (x, y), raggio [, colore]"], "Disegna una circonferenza.", 'SCREEN 5\nCIRCLE (128, 106), 50, 11', ['LINE', 'PAINT'], M2 + ' (SCREEN 3 compreso)')
T('PAINT', C, ["PAINT (x, y) [, colore [, bordo]]"],
  "Riempie un'area partendo dal punto indicato. Nei modi a 16 colori e nei 4 colori il bordo (colore che ferma il riempimento) va indicato "
  "se diverso dal colore di riempimento.",
  'SCREEN 5\nCIRCLE (128, 106), 50, 4\nPAINT (128, 106), 6, 4', ['CIRCLE', 'LINE'], M2)
T('DRAW', C, ["DRAW \"comandi\""],
  "Disegna con un linguaggio a comandi: U D L R E F G H (muovi su, giù, sinistra, destra e diagonali di n punti), M x,y (vai a; +/- relativo), "
  "B davanti a un comando (muovi senza tracciare), N (traccia e torna), C colore, S scala (in quarti). Esempio: `DRAW \"C7 R20 D10 L20 U10\"`.",
  'SCREEN 5\nPSET (100, 100)\nDRAW "C8 R40 D30 L40 U30"', ['LINE'], M2)
T(['GET', 'PUT'], C, ["GET (x1,y1)-(x2,y2), array", "PUT (x, y), array [, operazione]"],
  "GET copia un rettangolo dello schermo in un array di interi; PUT lo ridisegna con un'operazione (PSET, PRESET, AND, OR, XOR). In grafica "
  "il rettangolo dev'essere contenuto in un array dimensionato con DIM. Non vanno confusi con GET #n / PUT #n (file ad accesso casuale) e PUT SPRITE.",
  'SCREEN 5\nDIM a(100)\nCIRCLE (20, 20), 8, 15\nGET (10, 10)-(30, 30), a\nPUT (100, 100), a, PSET', ['COPY', 'PUT SPRITE', 'OPEN'], M2)
T('COPY', C, ["COPY (x1,y1)-(x2,y2)[,pagina] TO (x3,y3)[,pagina] [, operazione]"],
  "Copia un rettangolo di schermo (anche fra pagine) con il motore comandi del VDP: velocissimo, ideale per sprite software e scorrimenti.",
  'SCREEN 5\nCIRCLE (30, 30), 20, 12\nCOPY (0, 0)-(60, 60) TO (150, 100)', ['GET', 'SET'], M2)
T(['SET', 'SET PAGE', 'SET SCROLL'], C, ["SET PAGE visibile, attiva", "SET SCROLL x, y"],
  "SET PAGE sceglie la pagina mostrata e quella su cui si disegna (SCREEN 5-8): si disegna fuori vista e poi si mostra, per animazioni senza sfarfallio. "
  "SET SCROLL scorre lo schermo in modo morbido (registri 23 e 18).",
  'SCREEN 5\nSET PAGE 0, 1\nCIRCLE (100, 100), 40, 15\nSET PAGE 1, 1', ['COPY', 'VBANK'], M2)
T(['VIEW', 'WINDOW'], C, ["VIEW [(x1,y1)-(x2,y2)]", "WINDOW [SCREEN] [(x1,y1)-(x2,y2)]"],
  "VIEW limita il disegno a una finestra dello schermo (senza argomenti la annulla); WINDOW ridefinisce il sistema di coordinate (WINDOW SCREEN: l'asse y cresce verso il basso).",
  'SCREEN 5\nVIEW (50, 50)-(150, 150)\nLINE (0, 0)-(255, 211), 15\nVIEW', ['LINE'], M2)
T('PALETTE', C, ["PALETTE n, r, g, b", "PALETTE n, colore", "COLOR = (n, r, g, b)", "COLOR = RESTORE"],
  "Ridefinisce un colore della tavolozza (r, g, b da 0 a 7); la forma con due numeri assegna al colore n il colore predefinito indicato. "
  "`COLOR = RESTORE` ripristina la palette di fabbrica.",
  'SCREEN 5\nPALETTE 1, 7, 0, 0\nLINE (10, 10)-(100, 60), 1, BF', ['COLOR'], M2)
T(['VPOKE', 'VPEEK'], C, ["VPOKE indirizzo, valore", "VPEEK(indirizzo)"], "Scrive/legge un byte della memoria video. Con VBANK l'indirizzo arriva a 17 bit (128 KB su MSX2).",
  'VPOKE 0, 65\nPRINT VPEEK(0)', ['VBANK', 'VFILL', 'VWRITE'])
T('VBANK', C, ["VBANK n"], "Sceglie il blocco da 16 KB della VRAM usato da VPOKE, VPEEK, VFILL, VWRITE, VREAD$, BLOAD/BSAVE ... S (R#14 su MSX2).", 'VBANK 1\nVPOKE 0, 5', ['VPOKE'], M2)
T('VFILL', C, ["VFILL indirizzo, quanti, valore"], "Riempie un'area di VRAM con un byte.", 'VFILL 0, 768, 32', ['VWRITE'])
T('VWRITE', C, ["VWRITE indirizzo, stringa$"], "Scrive in VRAM i byte di una stringa.", 'VWRITE 0, "ciao"', ['VREAD$', 'VCOPY'])
T('VREAD$', C, ["VREAD$(indirizzo, quanti)"], "Legge un'area di VRAM e la restituisce come stringa.", 'PRINT VREAD$(0, 4)', ['VWRITE'])
T('BASE', C, ["BASE(n)"], "Indirizzo di VRAM delle tabelle del modo corrente (n come nel BASIC MSX: 0 nomi, 2 colori/motivi, ...).", 'PRINT BASE(0)', ['VDP'])
T('VDP', C, ["VDP(n)", "VDP(n) = valore"], "Legge o scrive il registro n del VDP (la lettura dà la copia in RAM del BIOS).", 'VDP(7) = 9\nPRINT VDP(7)', ['BASE', 'OUT'])
T('OUT', C, ["OUT porta, valore", "INP(porta)"], "Scrive un byte su una porta di I/O; INP ne legge uno.", 'OUT 170, 3', ['INP', 'VDP'])
T('INP', C, ["INP(porta)"], "Legge un byte da una porta di I/O.", 'PRINT INP(168)', ['OUT'])

# ------------------------------------------------------------------ sprite
C = 'Sprite'
T('SPRITE', C, ["SPRITE$(n) = stringa$", "PUT SPRITE piano, (x, y), colore, motivo", "PUT SPRITE piano", "COLOR SPRITE(piano) = colore", "COLLISION"],
  "Gli sprite sono 32 oggetti hardware. SPRITE$(n) = stringa$ definisce il motivo n: 8 byte per un 8x8 (32 per un 16x16), un bit per punto. "
  "PUT SPRITE piano,(x,y),colore,motivo mostra lo sprite; con le sole parole PUT SPRITE piano lo si nasconde. Le dimensioni (8x8 o 16x16, "
  "normale o ingrandito) si scelgono con il secondo parametro di SCREEN. COLOR SPRITE(n) = c cambia il colore di un piano; "
  "COLOR SPRITE$(n) = stringa$ dà un colore per riga (MSX2, sprite modo 2). COLLISION vale -1 se due sprite si sono toccati.",
  'SCREEN 2, 0\nSPRITE$(0) = CHR$(255)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(255)\nPUT SPRITE 0, (100, 90), 8, 0',
  ['SCREEN', 'COLLISION', 'STICK'], 'MSX1 e MSX2 (SCREEN 1-8)')
T('PUT SPRITE', C, ["PUT SPRITE piano, (x, y), colore, motivo", "PUT SPRITE piano"], "Mostra (o con il solo piano nasconde) uno sprite. Vedi SPRITE.",
  'SCREEN 2, 0\nSPRITE$(0) = CHR$(255)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(129)+CHR$(255)\nPUT SPRITE 0, (50, 50), 15, 0', ['SPRITE'])
T('COLLISION', C, ["COLLISION"], "Vale -1 se due sprite si sono sovrapposti dopo l'ultima lettura (letto dallo stato del VDP), 0 altrimenti.",
  'IF COLLISION THEN PRINT "urto"', ['SPRITE'])
T('STICK', C, ["STICK(n)"], "Direzione del joystick n (0 = tasti cursore, 1 e 2 = porte). Valori da 0 (fermo) a 8: 1 su, poi in senso orario.",
  'd = STICK(0)\nIF d = 3 THEN PRINT "destra"', ['STRIG', 'INKEY$'])
T('STRIG', C, ["STRIG(n)"], "Pulsante di fuoco: n = 0 barra spaziatrice, 1 e 2 pulsanti A di joystick 1 e 2, 3 e 4 pulsanti B. Vale -1 se premuto.",
  'IF STRIG(0) THEN PRINT "fuoco"', ['STICK'])

# ------------------------------------------------------------------ suono
C = 'Suono'
T('BEEP', C, ["BEEP"], "Emette il beep di sistema.", 'BEEP', ['SOUND', 'PLAY'])
T('SOUND', C, ["SOUND registro, valore"], "Scrive direttamente un registro (0-13) del generatore sonoro PSG AY-3-8910: toni, rumore, mixer, volumi, inviluppo.",
  'SOUND 7, 62\nSOUND 8, 12\nSOUND 0, 254\nSOUND 1, 0', ['PLAY', 'BEEP'])
T('PLAY', C, ["PLAY voce1$ [, voce2$ [, voce3$]]"],
  "Suona una melodia su 1-3 voci con il linguaggio MML e attende la fine. Comandi: A-G (nota, con # o + diesis, - bemolle; seguite da un numero per la durata e da punti), "
  "R pausa, O ottava (1-8), L durata di default (1-64), T tempo (32-255), V volume (0-15), N n (nota numerica), < e > ottava giù/su, "
  "M e S (modulazione/forma d'inviluppo come nel BASIC MSX).",
  'PLAY "T120 O4 L8 CDEFGAB>C"\nPLAY "O3 C2", "O4 E2", "O4 G2"', ['SOUND', 'BEEP'])

# ------------------------------------------------------------------ file
C = 'File su disco'
T('OPEN', C, ["OPEN nome$ FOR INPUT|OUTPUT|APPEND AS [#]n", "OPEN nome$ [FOR RANDOM] AS [#]n LEN = k"],
  "Apre un file (solo programmi .COM, non cartucce). n da 1 a 3. INPUT: lettura; OUTPUT: crea/azzera; APPEND: scrive in coda; RANDOM: file ad accesso "
  "casuale con record di k byte (1-128). I file aperti si chiudono da soli alla fine del programma.",
  'OPEN "PROVA.TXT" FOR OUTPUT AS #1\nPRINT #1, "riga uno"\nCLOSE #1\nOPEN "PROVA.TXT" FOR INPUT AS #1\nLINE INPUT #1, a$\nCLOSE #1\nPRINT a$',
  ['CLOSE', 'PRINT', 'INPUT', 'EOF', 'FIELD'], 'Solo .COM')
T('CLOSE', C, ["CLOSE [#n {, #n}]"], "Chiude i file indicati (tutti, se senza argomenti).", 'CLOSE #1', ['OPEN'], 'Solo .COM')
T('WRITE', C, ["WRITE #n, espressione {, espressione}"], "Scrive valori nel file separati da virgole, con le stringhe fra virgolette.", 'WRITE #1, 5, "ab"', ['PRINT', 'OPEN'], 'Solo .COM')
T('EOF', C, ["EOF(n)"], "Vale -1 quando il file n è finito.", 'WHILE NOT EOF(1)\n  LINE INPUT #1, a$\n  PRINT a$\nWEND', ['OPEN'], 'Solo .COM')
T('KILL', C, ["KILL nome$"], "Cancella un file dal disco.", 'KILL "PROVA.TXT"', ['OPEN'], 'Solo .COM')
T(['FIELD', 'LSET', 'RSET'], C, ["FIELD #n, larghezza AS var$ {, larghezza AS var$}", "LSET var$ = testo$", "RSET var$ = testo$"],
  "File ad accesso casuale: FIELD divide il record in campi associati a variabili stringa (fino a 8); LSET/RSET riempiono il campo allineando a sinistra o a destra "
  "(completando con spazi); PUT #n,r scrive il record r, GET #n,r lo legge (record da 1). LOF(n) dà il numero di record.",
  'OPEN "R.DAT" AS #1 LEN = 20\nFIELD #1, 10 AS n$, 10 AS c$\nLSET n$ = "Mario"\nLSET c$ = "Rossi"\nPUT #1, 1\nGET #1, 1\nPRINT n$; c$\nCLOSE #1',
  ['OPEN', 'MKI$', 'LOF'], 'Solo .COM')
T('LOF', C, ["LOF(n)"], "Numero di record del file ad accesso casuale n.", 'PRINT LOF(1)', ['FIELD'], 'Solo .COM')
T(['BLOAD', 'BSAVE'], C, ["BSAVE nome$, inizio, lunghezza [, S]", "BLOAD nome$ [, S] [, scostamento]"],
  "Salva/carica un blocco di memoria nel formato binario MSX. Con S i dati vanno da/verso la VRAM (VBANK vale).",
  'BSAVE "SCHERMO.BIN", 0, 6144, S\nBLOAD "SCHERMO.BIN", S', ['VBANK', 'OPEN'], 'Solo .COM')

# ------------------------------------------------------------------ cartucce
C = 'Cartucce ROM, segmenti e mapper'
T('SEGMENT', C, ["SEGMENT n"], "In una cartuccia a più banchi sposta il codice che segue nel segmento n (precedente + 1). Il segmento 0 contiene il runtime. "
  "Una SUB/FUNCTION di un altro segmento si chiama normalmente; GOTO e GOSUB non attraversano i segmenti.",
  'OPTION TARGET ASCII8\nSEGMENT 1\nSUB bis()\n  PRINT "nel segmento 1"\nEND SUB', ['OPTION', 'INCBIN', 'CALL'], 'Cartucce ASCII8/ASCII16/KONAMI/SCC')
T('INCBIN', C, ["INCBIN \"file\""], "Include i byte di un file nel segmento corrente (grafica, musica, tabelle).", 'SEGMENT 2\nINCBIN "SPRITES.BIN"', ['SETBANK', 'SEGMENT'], 'Cartucce multisegmento')
T(['SETBANK', 'DATAWIN'], C, ["SETBANK n", "DATAWIN"], "SETBANK mappa il segmento n nella finestra dati; DATAWIN è l'indirizzo della finestra (A000h per i banchi da 8 KB, 8000h per ASCII16).",
  'SETBANK 2\nVCOPY DATAWIN, 0, 256', ['INCBIN', 'VCOPY'], 'Cartucce multisegmento')
T('VCOPY', C, ["VCOPY indirizzo_memoria, indirizzo_vram, quanti"], "Copia byte dalla memoria alla VRAM.", 'VCOPY DATAWIN, 0, 2048', ['SETBANK', 'VWRITE'])
T(['MALLOC', 'MFREE', 'MAPPERSEGS'], C, ["MAPPERSEGS", "MALLOC", "MFREE segmento"], "Mapper RAM: MAPPERSEGS dà il numero di segmenti da 16 KB (0 se manca il mapper); "
  "MALLOC ne assegna uno e ne dà il numero; MFREE lo restituisce.",
  's = MALLOC\nPRINT MAPPERSEGS; s\nMFREE s', ['MGET', 'MPUT', 'DIM'], 'Con mapper RAM')
T(['MGET', 'MPUT', 'MREAD', 'MWRITE', 'VARPTR'], C, ["MGET(segmento, offset)", "MPUT segmento, offset, valore", "MREAD segmento, offset, indirizzo, quanti", "MWRITE segmento, offset, indirizzo, quanti", "VARPTR(variabile)"],
  "Accesso al mapper RAM: MGET legge un byte, MPUT lo scrive, MREAD copia dal mapper in memoria, MWRITE da memoria al mapper. VARPTR dà l'indirizzo di una variabile "
  "(o di un elemento di array) da passare a MREAD/MWRITE. Gli indirizzi di memoria dei blocchi non devono cadere in 8000h-BFFFh.",
  's = MALLOC\nMPUT s, 0, 123\nPRINT MGET(s, 0)\nMFREE s', ['MALLOC', 'VARPTR', 'DIM'], 'Con mapper RAM')

# ------------------------------------------------------------------ OPTION
C = 'Opzioni (OPTION)'
T('OPTION', C, ["OPTION NUMBERED | LABELS | MIXED", "OPTION TARGET tipo", "OPTION DEBUG"],
  "Direttive di compilazione, da mettere all'inizio del sorgente. NUMBERED: il programma ha numeri di riga e nessuna etichetta; LABELS: solo etichette; "
  "MIXED (predefinita): entrambe. TARGET sceglie il formato di uscita (vedi OPTION TARGET). DEBUG attiva il debugger (vedi DEBUG).",
  'OPTION LABELS\nPRINT "ok"', ['OPTION TARGET', 'OPTION DEBUG', 'ETICHETTE'])
T(['OPTION TARGET','TARGET'], C, ["OPTION TARGET ROM16 | ROM32 | ASCII8 | ASCII16 | KONAMI | SCC"],
  "Se è la prima riga, il compilatore produce una cartuccia NOME.ROM invece di un NOME.COM. ROM16: 16 KB; ROM32: 32 KB; ASCII8, ASCII16, KONAMI (senza SCC) e SCC: "
  "cartucce a banchi, con SEGMENT. La cartuccia al termine attende un tasto e riavvia la macchina. Nelle cartucce non ci sono file né BLOAD/BSAVE né il debugger "
  "completo; l'assembler in linea funziona.",
  'OPTION TARGET ROM16\nPRINT "Sono una cartuccia"', ['SEGMENT', 'OPTION'])
T(['OPTION NUMBERED','NUMBERED'], C, ["OPTION NUMBERED"], "Righe con numero (ordinate per numero, solo numeri, niente etichette). Circa 590 righe di programma.", '10 PRINT "a"\n20 GOTO 10', ['OPTION', 'ETICHETTE'])
T(['OPTION LABELS','OPT LABELS'], C, ["OPTION LABELS"], "Solo etichette, nessun numero di riga.", 'OPTION LABELS\nciclo:\n  PRINT "x";\n  GOTO ciclo', ['OPTION'])
T(['OPTION MIXED','MIXED'], C, ["OPTION MIXED"], "Numeri di riga ed etichette insieme (predefinita).", 'OPTION MIXED', ['OPTION'])
T(['OPTION DEBUG','OPT DEBUG'], C, ["OPTION DEBUG"], "Compila con il debugger incorporato: il programma parte fermo sulla prima istruzione. Vedi DEBUG.", 'OPTION DEBUG\na = 1\nb = a + 1', ['DEBUG'])
