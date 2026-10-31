# -*- coding: utf-8 -*-
"""Argomenti generali: ASM, DEBUG, editor, errori, limiti, MSX1/MSX2."""
from topics_core import T

C = 'Guide'
T(['ASM', '__ASM', '__ENDASM', 'ASSEMBLER'], C, ["__ASM", "  istruzioni Z80", "__ENDASM"],
  "Un blocco __ASM ... __ENDASM (ciascuno su una riga propria, maiuscole o minuscole) contiene codice Z80 documentato, scritto come in un qualsiasi assemblatore. "
  "Commenti con `;`. Etichette locali `nome:` (anche `nome EQU valore`). Numeri: decimali, `$1F`, `0x1F`, `1FH`, `%101`, `101B`, `'x'`; `$` è l'indirizzo corrente. "
  "Direttive: DB/DEFB (anche stringhe), DW/DEFW, DS/DEFS. Un nome che non è etichetta locale è una variabile BASIC globale (`LD HL,(CONTA)`, `LD HL,NOME$`) "
  "oppure, in un salto, un'etichetta BASIC (`JP FINE`, `JP NZ,FINE`). JR e DJNZ solo verso etichette locali. Si può cambiare ogni registro tranne IX "
  "(frame delle SUB/FUNCTION) e lo stack va lasciato in pari. Il debugger non si ferma dentro i blocchi. Funziona anche nelle cartucce. "
  "Errori: 17 sintassi/operando, 18 valore o salto fuori campo, 19 simbolo doppio o __ENDASM mancante, 20 QASM.OVL non trovato.",
  "conta = 0\n__ASM\n  ld hl,(conta)\n  inc hl\n  ld (conta),hl\n__ENDASM\nPRINT conta", ['VARPTR', 'OPTION'])
T(['DEBUG', 'DEBUGGER'], C, ["OPTION DEBUG"],
  "Si scrive `OPTION DEBUG` nel sorgente e si preme F5: il programma parte fermo sulla prima istruzione, in una schermata testo con la riga corrente, "
  "le variabili globali scalari con il loro valore e l'elenco dei breakpoint. Tasti: SPAZIO (o S, INVIO) esegue un'istruzione; R esegue fino al prossimo "
  "breakpoint; B numero INVIO mette o toglie un breakpoint (solo INVIO = riga corrente, 0 = li toglie tutti); C toglie tutti i breakpoint; V pagina "
  "successiva delle variabili; Q termina il programma. CTRL-STOP durante l'esecuzione rientra nel debugger. Lo schermo del programma resta intatto. "
  "Nelle cartucce il debugger funziona ma non mostra le variabili. I programmi normali (senza OPTION DEBUG) non pagano nulla.",
  "OPTION DEBUG\ns = 0\nFOR i = 1 TO 3\n  s = s + i\nNEXT i\nPRINT s", ['OPTION DEBUG'])
T(['EDITOR', 'MENU', 'TASTI'], C, ["Esc = menu, frecce, F1-F4"],
  "Si avvia con `SAMPRBAS nome`. Menu da tastiera: Esc apre il menu File; F1 File, F2 Edit, F3 Find, F4 Help; Run è a destra; frecce sinistra/destra cambiano menu, su/giù le voci, Invio "
  "sceglie, una lettera evidenziata attiva la voce, Esc chiude. Scorciatoie: F5 compila ed esegue, F6 Help sulla parola sotto il cursore, F7 indice dell'aiuto. "
  "Le parole chiave sono colorate (su MSX2); su MSX1 l'editor ha 40 colonne, su MSX2 80, in automatico. Se non cambia nulla F5 rilancia subito il programma.",
  None, ['HELP'])
T(['SPB', 'FILE SPB', 'SALVA', 'APRI'], C, ["SAMPRBAS nome", "File > Open, File > Save As"],
  "I programmi hanno estensione .SPB (SamPr Basic). `SAMPRBAS PROVA` apre PROVA.SPB se esiste, altrimenti parte con un file nuovo già chiamato PROVA.SPB. "
  "Open (Ctrl+O) mostra una finestra con i file .SPB (e, con MSX-DOS 2, le cartelle): frecce, Invio, una lettera per saltare, Esc per uscire. "
  "Save As (Ctrl+W) accetta al massimo 8 caratteri e aggiunge .SPB. Il programma compilato è NOME.COM (o NOME.ROM).",
  None, ['EDITOR', 'COMPILAZIONE'])
T(['HELP', 'AIUTO', 'INDEX', 'INDICE'], C, ["menu Help: Index (F7), Topic..., On word (F6), Shortcuts, About"],
  "L'aiuto legge i file HELP.TXT e HELP.IDX nella directory corrente. Index (F7) mostra l'elenco degli argomenti; Topic... chiede un nome (es. PRINT, ASM, DEBUG, "
  "OPTION); On word (F6) mostra l'argomento della parola sotto il cursore. Nel visore: frecce e PgUp/PgDn scorrono, Esc chiude. HELP.TXT è un normale file di testo "
  "(righe di 38 colonne): si può leggere e ampliare; HELP.IDX è l'indice generato dallo strumento gen_docs.py.",
  None, ['EDITOR'])
T(['ERRORI', 'ERRORS'], C, ["Codici di errore"],
  "1 sintassi; 2 etichetta o riga inesistente; 3 non ancora supportato; 4 carattere illegale; 5 blocco non chiuso; 6 ELSE/END IF/NEXT/WEND senza blocco; "
  "7 nome duplicato; 8 troppe variabili, etichette o blocchi; 9 programma troppo grande; 10 sorgente troppo grande; 11 errore di lettura; 12 errore di scrittura; "
  "13 non ammesso con l'OPTION scelta; 14 tipi incompatibili o array non dichiarato; 15 dati del programma troppo grandi; 16 RT.BIN non trovato; "
  "17-20 assembler in linea. L'editor si riapre con il cursore sulla riga dell'errore.",
  None, ['LIMITI'])
T(['LIMITI', 'LIMITS'], C, ["Limiti del compilatore"],
  "Sorgente circa 13 KB; programma 16 KB; 96 etichette; 100 variabili e array; 20 SUB/FUNCTION (8 parametri ciascuna, 64 in totale); 29 interi locali e 256 byte per "
  "stringa locale; 24 blocchi annidati; nomi significativi su 11 caratteri; circa 590 righe in OPTION NUMBERED; stringhe di 255 caratteri; interi da -32768 a 32767; "
  "file aperti: 3.",
  None, ['ERRORI'])
T(['MSX1', 'MSX2', 'COMPATIBILITA'], C, ["MSX1 / MSX2"],
  "Il sistema riconosce la macchina. MSX1: editor e testo a 40 colonne, SCREEN 0-3, niente colori delle parole chiave, niente grafica 5-12, palette, pagine, mapper. "
  "MSX2: 80 colonne, SCREEN fino a 8 (10-12 su MSX2+), PALETTE, COPY, SET PAGE, VBANK 17 bit, mapper RAM. Provato con Sony HB-75P e un MSX2 con MSX-DOS 1 e 2.",
  None, ['SCREEN'])
T(['COM', 'ROM', 'COMPILAZIONE', 'F5'], C, ["F5, QBC.COM, NOME.COM / NOME.ROM"],
  "F5 salva il sorgente, avvia il compilatore QBC.COM che scrive NOME.COM e lo esegue; a fine programma si torna all'editor. Con OPTION TARGET si ottiene invece "
  "una cartuccia NOME.ROM. File necessari sul disco: SAMPRBAS.COM, QBC.COM, RT.BIN (e RTD.BIN per il debug, QBCR.COM e RTROM.BIN per le cartucce, QASM.OVL per __ASM).",
  None, ['OPTION TARGET'])
