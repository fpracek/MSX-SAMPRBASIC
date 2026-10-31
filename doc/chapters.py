# -*- coding: utf-8 -*-
"""Capitoli narrativi del manuale. Ogni capitolo: (titolo, [blocchi]); blocco = ('p', testo) | ('h', sottotitolo) | ('code', testo) | ('ul', [voci]) | ('table', [righe], [larghezze]) | ('img', file, didascalia)."""

CHAPTERS = []


def CH(title, blocks):
    CHAPTERS.append((title, blocks))


CH('Presentazione', [
    ('p', "<b>SamPr Basic</b> è un ambiente di sviluppo completo che gira <b>direttamente su un computer MSX</b>: un editor a schermo intero, un compilatore BASIC "
          "che produce vero codice macchina Z80 e un debugger, tutto senza bisogno di un PC. Si scrive il programma, si preme <b>F5</b> e dopo pochi secondi "
          "il programma gira alla velocità della macchina."),
    ('h', 'Che cosa offre'),
    ('ul', [
        "<b>Compilatore vero</b>: ogni istruzione BASIC diventa codice Z80; il risultato è un file .COM (MSX-DOS) o una cartuccia .ROM.",
        "<b>Editor</b> con menu a tendina (anche da tastiera), mouse, selezione, copia/incolla, annulla/ripeti, ricerca e sostituzione, colori per le parole chiave.",
        "<b>Linguaggio strutturato</b>: SUB e FUNCTION con parametri, variabili locali e ricorsione; IF/ELSEIF, SELECT CASE, DO/LOOP; etichette o numeri di riga.",
        "<b>Pensato per i giochi</b>: grafica bitmap MSX2, sprite, accesso diretto alla VRAM, scorrimento, joystick, suono a tre voci con il linguaggio MML.",
        "<b>Assembler Z80 in linea</b> con <font face='Courier'>__ASM ... __ENDASM</font> per le parti critiche.",
        "<b>Debugger</b> passo-passo con breakpoint e variabili (<font face='Courier'>OPTION DEBUG</font>).",
        "<b>Cartucce ROM</b> da 16 KB a 2 MB (ASCII8, ASCII16, KONAMI, SCC) con codice su più segmenti e dati incorporati.",
        "<b>File su disco</b> di testo e ad accesso casuale; <b>mapper RAM</b> per grandi quantità di dati; BLOAD/BSAVE.",
        "<b>MSX1 e MSX2</b>: su MSX1 l'editor lavora a 40 colonne, su MSX2 a 80, scelta automatica.",
        "<b>Aiuto in linea</b> (F6 sulla parola sotto il cursore, F7 per l'indice) con tutte le istruzioni documentate.",
    ]),
    ('h', 'Filosofia'),
    ('p', "Il linguaggio è un BASIC moderno ma volutamente piccolo: interi a 16 bit e stringhe, nessun numero in virgola mobile (che per i videogiochi "
          "costerebbe velocità e memoria senza dare vantaggi). Tutto ciò che serve a un gioco — sprite, scroll, suono, joystick, mapper — è una "
          "istruzione o una funzione. Le maiuscole e le minuscole sono equivalenti ovunque."),
])

CH('Installazione e avvio', [
    ('p', "Servono un MSX (MSX1 con almeno 64 KB di RAM o MSX2) con unità a dischi e MSX-DOS 1 o 2 (o Nextor). Si copiano sul disco i file seguenti:"),
    ('table', [['File', 'Funzione'],
               ['SAMPRBAS.COM', "L'editor: si avvia con <font face='Courier'>SAMPRBAS NOME.SPB</font>"],
               ['QBC.COM', 'Il compilatore (lanciato da F5)'],
               ['RT.BIN', 'Il runtime del programma compilato'],
               ['RTD.BIN', 'Runtime con debugger (per OPTION DEBUG)'],
               ['QASM.OVL', "L'assemblatore in linea (per __ASM)"],
               ['QBCR.COM, RTROM.BIN, RTROMD.BIN', 'Per produrre cartucce ROM'],
               ['HELP.TXT, HELP.IDX', "L'aiuto in linea (facoltativi)"]], [150, 330]),
    ('p', "Avviare l'editor con <font face='Courier'>SAMPRBAS</font> (programma nuovo) oppure <font face='Courier'>SAMPRBAS PROVA.SPB</font>. Sull'MSX1 il DOS chiede la data all'avvio: "
          "premere Invio. Sul PC si può provare tutto con l'emulatore openMSX: nella cartella del progetto ci sono "
          "<font face='Courier'>avvia_nms8250.bat</font> (MSX2, 80 colonne) e <font face='Courier'>avvia_hb75p.bat</font> (Sony HB-75P MSX1, 40 colonne), che montano il disco di prova."),
    ('h', 'File dei programmi: estensione .SPB'),
    ('p', "I sorgenti hanno estensione <b>.SPB</b> (SamPr Basic). Avviando <font face='Courier'>SAMPRBAS PROVA</font> l'editor apre PROVA.SPB se esiste; "
          "altrimenti parte con un file nuovo che ha già quel nome (l'estensione .SPB si aggiunge da sola se manca). In <b>Save As</b> si digitano al massimo "
          "8 caratteri e l'editor aggiunge .SPB. Il programma compilato prende lo stesso nome con estensione .COM (o .ROM per le cartucce)."),
    ('h', 'Primo programma'),
    ('code', 'PRINT "Ciao MSX!"\nFOR i = 1 TO 5\n  PRINT i; " x 2 ="; i * 2\nNEXT i'),
    ('p', "Scrivere il programma nell'editor e premere <b>F5</b>. Alla fine l'esecuzione attende un tasto e riporta all'editor. Se c'è un errore, l'editor si "
          "riapre con il cursore sulla riga sbagliata e il messaggio nella barra del titolo."),
])

CH("L'editor", [
    ('p', "L'editor ha una barra dei menu in alto (<b>File Edit Find Help Run</b>), l'area di testo con i numeri di riga, la barra di scorrimento e una riga di stato "
          "con posizione del cursore e nome del file. Funziona con tastiera e con mouse (se presente)."),
    ('img', 'editor.png', "L'editor su MSX2 (80 colonne): le parole chiave sono evidenziate."),
    ('h', 'Menu da tastiera'),
    ('table', [['Tasto', 'Azione'],
               ['Esc', 'Apre il menu File; chiude un menu aperto'],
               ['F1 F2 F3 F4', 'Aprono File, Edit, Find, Help'],
               ['Sinistra / Destra', 'Con un menu aperto: passa al menu vicino'],
               ['Su / Giù, Invio', 'Scelgono la voce'],
               ['Lettera evidenziata', 'Attiva la voce (es. N = New, O = Open)'],
               ['F5', 'Compila ed esegue il programma'],
               ['F6', "Aiuto sulla parola sotto il cursore"],
               ['F7', "Indice dell'aiuto"]], [150, 330]),
    ('h', 'Modifica del testo'),
    ('table', [['Tasto', 'Azione'],
               ['Frecce, Home, End, PgUp, PgDn', 'Spostamento del cursore'],
               ['Shift + frecce', 'Selezione'],
               ['Ctrl+C / Ctrl+X / Ctrl+V', 'Copia, taglia, incolla'],
               ['Ctrl+Z / Ctrl+Y', 'Annulla / ripeti'],
               ['Ctrl+F / Ctrl+G / Ctrl+T', 'Cerca / cerca ancora / sostituisci'],
               ['Ctrl+S / Ctrl+W', 'Salva / salva con nome'],
               ['Ctrl+O / Ctrl+Q', 'Apri / esci']], [200, 280]),
    ('p', "Le parole chiave del BASIC sono evidenziate in giallo (solo su MSX2). Le righe lunghe scorrono orizzontalmente. Salvando, l'editor sovrascrive il file in "
          "posizione e non salva se il testo non è cambiato; F5 senza modifiche rilancia il programma senza ricompilare."),
    ('h', 'Aprire un file: la finestra dei file'),
    ('p', "File &gt; Open (Ctrl+O) mostra una finestra con tutti i file <b>.SPB</b> della directory corrente, in ordine alfabetico. Con MSX-DOS 2 compaiono anche le "
          "<b>cartelle</b> (fra parentesi quadre, <font face='Courier'>[GIOCHI]</font>, e <font face='Courier'>[..]</font> per salire) e si naviga fra di esse; il percorso corrente è "
          "nel titolo. Con MSX-DOS 1 non esistono cartelle e si vedono solo i file."),
    ('table', [['Tasto', 'Azione'],
               ['Frecce', 'Spostano la selezione (due colonne su MSX1, quattro su MSX2)'],
               ['PgUp / PgDn, Home', 'Pagina precedente / successiva, prima voce'],
               ['Una lettera', "Salta alla prima voce che inizia con quella lettera"],
               ['Invio', 'Apre il file o entra nella cartella'],
               ['Esc', 'Chiude la finestra senza aprire nulla']], [150, 330]),
    ('img', 'browser.png', "La finestra di apertura: tutti i file .SPB della directory, in ordine alfabetico."),
    ('h', 'Salvare con nome'),
    ('p', "File &gt; Save As (Ctrl+W) chiede il nome: <b>al massimo 8 caratteri</b>; l'estensione .SPB è aggiunta dall'editor (se si digita un'estensione viene sostituita). "
          "Anche F5 su un programma senza nome chiede il nome nello stesso modo."),
    ('img', 'menu_file.png', "Il menu File, con la voce Segment... (F8)."),
    ('h', 'Progetti a segmenti: File > Segment (F8)'),
    ('p', "Per le cartucce a segmenti (vedi il capitolo sulle cartucce) ogni segmento è un file <b>NOME000.SPB</b>, <b>NOME001.SPB</b>, ... "
          "(5 caratteri più 3 cifre). File &gt; Segment... (tasto <b>F8</b>) chiede il numero del segmento, anche senza zeri davanti (<font face='Courier'>7</font> equivale a 007): "
          "l'editor <b>salva il file corrente</b>, poi cerca e apre nella stessa directory il file con quel numero; se non esiste ne crea uno nuovo già con quel nome. "
          "Il nome del file corrente deve essere di 5 caratteri più 3 cifre."),
    ('h', 'Il menu Help'),
    ('ul', ["<b>Index (F7)</b>: l'elenco di tutti gli argomenti.",
            "<b>Topic...</b>: chiede il nome di un argomento (PRINT, ASM, DEBUG, OPTION...).",
            "<b>On word (F6)</b>: documenta la parola sotto il cursore.",
            "<b>Shortcuts</b>: riepilogo dei tasti.",
            "<b>About</b>: finestra centrata con la cornice dei menu, <i>SamPr Basic 1.0 — 2026 Fausto Pracek</i> e il tasto OK; si chiude con Invio, Esc o un clic su OK."]),
    ('img', 'menu_help.png', "Il menu Help."),
    ('img', 'help_topic.png', "L'aiuto sull'istruzione PRINT."),
    ('img', 'about.png', "La finestra About, con la cornice dei menu e il tasto OK."),
    ('p', "Nel visore dell'aiuto: frecce e PgUp/PgDn scorrono, Esc chiude. Il testo viene dai file HELP.TXT e HELP.IDX nella directory corrente: HELP.TXT è un normale "
          "file di testo ed è modificabile; HELP.IDX è l'indice (nome, posizione, lunghezza) rigenerato dallo strumento <font face='Courier'>doc/gen_help.py</font>."),
])

CH('Il linguaggio in breve', [
    ('p', "Un programma è una sequenza di istruzioni, una per riga (o più, separate da <font face='Courier'>:</font>). I commenti iniziano con "
          "<font face='Courier'>REM</font> o con l'apostrofo."),
    ('h', 'Tipi e variabili'),
    ('p', "Interi a 16 bit con segno e stringhe fino a 255 caratteri. Le variabili non vanno dichiarate: valgono 0 o stringa vuota. Gli array si dichiarano con DIM."),
    ('code', 'n = 12 : m = &HFF : b = &B101\nnome$ = "Sam"\nDIM v(10), t$(5)\nv(3) = n * 2\nt$(1) = nome$ + "!"'),
    ('h', 'Strutture di controllo'),
    ('code', 'IF n > 10 THEN PRINT "grande" ELSE PRINT "piccolo"\n\nFOR i = 1 TO 10 STEP 2 : PRINT i; : NEXT i\n\nSELECT CASE n\n  CASE 1 TO 5 : PRINT "basso"\n  CASE ELSE : PRINT "alto"\nEND SELECT'),
    ('h', 'Routine'),
    ('code', 'FUNCTION fatt(n)\n  IF n <= 1 THEN\n    fatt = 1\n  ELSE\n    fatt = n * fatt(n - 1)\n  END IF\nEND FUNCTION\n\nPRINT fatt(7)'),
    ('h', 'Etichette o numeri'),
    ('p', "Il programma può usare etichette (<font face='Courier'>inizio:</font>) o numeri di riga; la direttiva OPTION sceglie il modo: NUMBERED, LABELS o MIXED (predefinita)."),
])

CH('Assembler in linea', [
    ('p', "Per le parti che devono essere velocissime si può scrivere direttamente in assembler Z80, fra le righe <b>__ASM</b> e <b>__ENDASM</b>. "
          "Il compilatore carica un piccolo assemblatore (QASM.OVL) che traduce il blocco in codice macchina inserito nel programma."),
    ('code', '__ASM\n  ld hl,(conta)    ; la variabile BASIC "conta"\n  inc hl\n  ld (conta),hl\n  jp fine          ; salta all\'etichetta BASIC "fine"\n__ENDASM'),
    ('h', 'Regole'),
    ('ul', ["Tutte le istruzioni Z80 documentate; commenti con <font face='Courier'>;</font>.",
            "Numeri: <font face='Courier'>123, $7F, 0x7F, 7FH, %101, 101B, 'a'</font>; <font face='Courier'>$</font> è l'indirizzo corrente.",
            "Direttive: DB/DEFB, DW/DEFW, DS/DEFS, EQU.",
            "Un nome non definito nel blocco è una <b>variabile BASIC globale</b> (anche stringa) o, nei salti, un'<b>etichetta BASIC</b>.",
            "JR e DJNZ solo verso etichette locali.",
            "Si possono modificare tutti i registri tranne <b>IX</b> (frame delle routine); lo stack va lasciato in pari.",
            "Il debugger non si ferma dentro i blocchi. Funziona anche nelle cartucce.",
            "Errori 17-20: sintassi, valore fuori campo, simbolo doppio / __ENDASM mancante, QASM.OVL non trovato."]),
])

CH('Il debugger', [
    ('p', "Aggiungere <font face='Courier'>OPTION DEBUG</font> in testa al programma e premere F5. Il compilatore usa il runtime con debugger: il programma parte "
          "<b>fermo sulla prima istruzione</b> e si controlla con la tastiera. Un programma senza OPTION DEBUG non paga nulla."),
    ('img', 'debugger.png', "Il debugger fermo dentro una SUB: parametri e locali (con >), poi le globali."),
    ('table', [['Tasto', 'Azione'],
               ['Spazio, S, Invio', 'Esegue una istruzione'],
               ['R', 'Esegue fino al prossimo breakpoint'],
               ['B numero Invio', 'Mette o toglie un breakpoint (solo Invio = riga corrente; 0 = li toglie tutti)'],
               ['C', 'Toglie tutti i breakpoint'],
               ['E', 'Chiede il nome di una variabile (anche locale, parametro, elemento di array come V(3), stringa come N$) e ne mostra il valore'],
               ['V', 'Pagina successiva delle variabili'],
               ['Q', 'Termina il programma'],
               ['Ctrl-Stop', 'Durante l\'esecuzione, rientra nel debugger']], [130, 350]),
    ('p', "La schermata mostra la riga corrente, le variabili con il loro valore e l'elenco dei breakpoint. Dentro una SUB o FUNCTION compaiono per prime le <b>variabili locali e i parametri</b>, contrassegnati da <font face='Courier'>&gt;</font>, poi le variabili globali scalari. Per qualsiasi altra variabile si usa il comando <b>E</b>: si digita il nome (cerca prima fra le locali, poi fra le globali); per un array si scrive l'elemento, ad esempio <font face='Courier'>V(2)</font> o <font face='Courier'>N$(1)</font>, e senza indice si ottiene il numero di elementi. Si segnalano nome inesistente, indice fuori dai limiti e array nel mapper. Lo schermo del programma viene salvato e ripristinato: il debug funziona anche negli schermi grafici. Nelle cartucce il debugger gira ma non mostra le variabili."),
])

CH('Cartucce ROM, segmenti e mapper', [
    ('p', "Con <font face='Courier'>OPTION TARGET</font> come prima riga il compilatore produce una cartuccia <b>NOME.ROM</b> al posto del .COM: ROM16, ROM32, ASCII8, "
          "ASCII16, KONAMI, SCC. A fine programma si attende un tasto e la macchina si riavvia. Nelle cartucce non ci sono file né BLOAD/BSAVE."),
    ('p', "Con i mapper a banchi il codice può occupare più <b>segmenti</b>: <font face='Courier'>SEGMENT n</font> sposta il codice che segue nel segmento n. "
          "Le routine di altri segmenti si chiamano normalmente (il compilatore cambia banco e lo ripristina). I dati si includono con "
          "<font face='Courier'>INCBIN \"file\"</font> e si leggono con <font face='Courier'>SETBANK</font> e <font face='Courier'>DATAWIN</font>."),
    ('h', 'Una cartuccia su più file'),
    ('p', "Un programma grande si scrive in <b>un file per segmento</b>. Con una OPTION TARGET a segmenti (ASCII8, ASCII16, KONAMI, SCC) i file si chiamano "
          "<font face='Courier'>NOME000.SPB</font> (segmento 0, quello fisso con il runtime) e <font face='Courier'>NOME001.SPB</font>, "
          "<font face='Courier'>NOME002.SPB</font>, ... (5 caratteri di nome più tre cifre). Il numero parte da <b>0</b>: il segmento 0 è il primo blocco della cartuccia (la "
          "BIOS è un'altra ROM, non c'entra), gli altri sono i blocchi commutabili."),
    ('ul', ["Le <b>OPTION</b> (TARGET, DEBUG, LABELS...) stanno <b>solo nel file 000</b>; in un altro file danno errore 13.",
            "<b>SEGMENT</b> non si scrive: il segmento lo decide il nome del file (con i file separati l'istruzione dà errore 13).",
            "Il compilatore legge tutti i file in sequenza finché trova i successivi (001, 002, ...), registra le routine di ogni segmento e le <b>collega in un'unica ROM</b> NOME.ROM (senza le tre cifre).",
            "Si può premere F5 da <b>qualunque</b> file del progetto: il compilatore parte sempre dal 000. Gli errori riportano il file e la riga giusti e l'editor apre quel file.",
            "Una SUB o FUNCTION di un altro segmento si chiama come al solito; GOTO e GOSUB non attraversano i segmenti; ogni file arriva a circa 15 KB di sorgente.",
            "Si passa da un file all'altro con File &gt; Segment (F8)."]),
    ('p', "Un programma piccolo resta in un solo file e può ancora usare l'istruzione <font face='Courier'>SEGMENT n</font>. I file senza le tre cifre finali non sono segmenti."),
    ('p', "Il <b>mapper RAM</b> (se presente) offre segmenti da 16 KB: MAPPERSEGS, MALLOC, MFREE, MGET, MPUT, MREAD, MWRITE, VARPTR e gli array "
          "<font face='Courier'>DIM x(n) MAPPER</font> fino a 32768 interi."),
])

CH('Directory di lavoro (MSX-DOS 2)', [
    ('p', "Con MSX-DOS 2 (e Nextor) i programmi stanno in cartelle. La regola è semplice: <b>la directory di lavoro è sempre quella del file aperto</b>, per i programmi "
          "normali e per le cartucce. Il sorgente, il programma compilato (.COM, .ROM) e i file letti o scritti dal programma vivono nella cartella del progetto; gli strumenti "
          "(SAMPRBAS.COM, QBC.COM, RT.BIN, QASM.OVL...) restano nella loro cartella e vengono trovati da soli."),
    ('ul', ["Dalla riga di comando si può dare un percorso: <font face='Courier'>SAMPRBAS \\GIOCHI\\PROVA</font> entra in GIOCHI e apre PROVA.SPB (o lo crea).",
            "File &gt; Open mostra le cartelle e vi si naviga; aprendo un file la directory di lavoro è quella del file.",
            "F5 compila e fa girare il programma nella cartella del progetto, e al ritorno l'editor è ancora lì.",
            "Le due directory sono memorizzate nelle variabili d'ambiente <b>SPBHOME</b> (strumenti) e <b>SPBPROJ</b> (progetto). SPBHOME vale la directory da cui si "
            "avvia l'editor la prima volta: conviene avviarlo dalla cartella degli strumenti, oppure impostarla prima con <font face='Courier'>SET SPBHOME=\\STRUMENTI</font>.",
            "Con MSX-DOS 1 non esistono cartelle e nulla di tutto questo si applica."]),
])

CH('MSX1 e MSX2', [
    ('table', [['Funzione', 'MSX1', 'MSX2'],
               ['Editor', '40 colonne, senza colori', '80 colonne, parole chiave colorate'],
               ['SCREEN', '0-3', '0-8 (10-12 su MSX2+)'],
               ['Grafica bitmap (PSET, LINE, CIRCLE, PAINT, GET/PUT)', 'SCREEN 2-3', 'SCREEN 3, 5-8'],
               ['PALETTE, COPY, SET PAGE, SET SCROLL, VBANK', 'no', 'sì'],
               ['Sprite', 'sì', 'sì'],
               ['Suono (PLAY, SOUND, BEEP)', 'sì', 'sì'],
               ['Mapper RAM', 'no', 'se presente']], [220, 120, 140]),
    ('p', "Il sistema riconosce la macchina da solo. Provato con Sony HB-75P (MSX1) e MSX2 con MSX-DOS 1 e 2."),
])

CH('Errori e limiti', [
    ('table', [['N.', 'Significato'],
               ['1', 'Errore di sintassi'], ['2', 'Etichetta o numero di riga inesistente'], ['3', 'Non ancora supportato'],
               ['4', 'Carattere illegale'], ['5', 'Blocco non chiuso'], ['6', 'ELSE / END IF / NEXT / WEND senza blocco'],
               ['7', 'Nome duplicato'], ['8', 'Troppe variabili, etichette o blocchi'], ['9', 'Programma troppo grande'],
               ['10', 'Sorgente troppo grande'], ['11', 'Errore di lettura'], ['12', 'Errore di scrittura'],
               ['13', "Non ammesso con l'OPTION scelta"], ['14', 'Tipi incompatibili o array non dichiarato'],
               ['15', 'Dati del programma troppo grandi'], ['16', 'RT.BIN non trovato'],
               ['17', 'Assembler: sintassi o operando'], ['18', 'Assembler: valore o salto fuori campo'],
               ['19', 'Assembler: simbolo doppio o __ENDASM mancante'], ['20', 'QASM.OVL non trovato']], [40, 440]),
    ('h', 'Limiti'),
    ('ul', ["Sorgente: circa 12,5 KB per file (15 KB per le cartucce). Programma compilato: 16 KB; per le cartucce più segmenti, ciascuno con il suo file.",
            "96 etichette; 100 variabili e array; 20 SUB/FUNCTION (8 parametri ciascuna); 24 blocchi annidati.",
            "Nomi significativi su 11 caratteri; stringhe di 255 caratteri; interi da -32768 a 32767.",
            "In OPTION NUMBERED circa 590 righe; tre file aperti contemporaneamente."]),
])
