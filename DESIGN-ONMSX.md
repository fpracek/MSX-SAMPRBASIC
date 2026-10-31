# SamPr Basic — toolchain interamente su MSX2

Requisito: l'utente lavora **solo su macchina fisica** (editor → compilatore → programma), senza PC.
`qbc.py` resta il prototipo di riferimento: ogni stadio del compilatore Z80 si verifica contro di esso.

## Architettura (MSX-DOS 1/2, nessuna EXEC)
MSX-DOS 1 non ha la chiamata di esecuzione di un programma figlio, quindi i tre programmi si
**caricano a catena** nella TPA (0100h), passandosi il lavoro nella riga di comando a 0080h:

    QB.COM  (editor)  --F5-->  salva il sorgente, carica QBC.COM, cmdline "NOME.BAS"
    QBC.COM (compilatore)      legge NOME.BAS, genera NOME.COM, lo scrive su disco, lo avvia
    NOME.COM (programma)       alla fine: "Press any key", ricarica QB.COM, cmdline "NOME.BAS"

Errore di compilazione: QBC ricarica QB.COM con cmdline `NOME.BAS E<riga> <codice>`; l'editor
apre il file, porta il cursore sulla riga e mostra il messaggio.
Il caricatore a catena (open FCB + lettura a blocchi in 0100h + `jp 0100h`) è copiato in RAM alta
(0D000h) prima di sovrascrivere la TPA.

## Compilatore Z80
- Una passata, emissione diretta di **codice macchina** (non c'è assembler sull'MSX), stessa
  strategia di `qbc.py`: HL = accumulatore, operando sinistro sullo stack.
- Sorgente a 4000h (max 16 KB), codice generato a 8000h con indirizzi virtuali da 0100h
  (`vpc = outp - 7F00h`), tabelle simboli a 0C000h. Salti in avanti: catene di fixup nel codice stesso.
- Il runtime (`rtcom.asm` -> `RT.BIN`, ORG 0100h) viene letto dal disco dal compilatore e messo in testa all'output
  (non e' piu' incorporato in QBC.COM: cosi' puo' crescere, e si potranno avere varianti per target): i suoi punti d'ingresso sono una tabella di `jp` a indirizzi fissi
  (`rtabi.inc`), così il compilatore emette `call RT_xxx` come costanti.
- Variabili intere a 0C000h in poi (azzerate all'avvio), heap stringhe sopra.

## Estensioni del linguaggio per ROM e mapper (da realizzare negli stadi successivi)
Sintassi decisa ora, implementazione per stadi:
- `OPTION TARGET COM | ROM16 | ROM32 | ASCII8 | ASCII16 | KONAMI | SCC`  (default COM)
  Per i target ROM il compilatore emette un cartuccia (`NOME.ROM`) con header `AB`, startup di slot
  (abilita la pagina 2) e il runtime nel segmento 0.
- `SEGMENT n` — da qui in poi il codice va nel segmento n (16K per ASCII16, 8K per ASCII8/KONAMI/SCC);
  il segmento 0 è fisso. Le routine in segmenti diversi si chiamano con `CALL FAR nome`: il
  compilatore genera un trampolino nel segmento fisso che cambia banco, chiama e ripristina.
- `BANK(n)` / `SETBANK page, n` — accesso diretto alla commutazione (indirizzi dei registri dal target:
  ASCII8 6000/6800/7000/7800, ASCII16 6000/7000, KONAMI 6000/8000/A000, SCC 5000/7000/9000/B000).
- `DATA`/`INCBIN "file"` in un segmento per dati (tile, musica).
- Mapper RAM (`MAPPER`): `MAPPERSEGS` (numero segmenti, 0 se assente), `SETSEG page, n` (porte FCh–FFh),
  `MGET(seg, offs)` / `MPUT seg, offs, v`; `DIM x(n) MAPPER` pone l'array nella RAM mapper se
  presente. Il compilatore rileva il mapper al volo (scrittura/lettura sulle porte, con
  fallback al comportamento senza mapper).

## Stadi
1. **Stadio 1** (questo): lexer, espressioni intere, PRINT, assegnamenti, IF/ELSEIF/ELSE,
   FOR/NEXT, WHILE/WEND, GOTO/GOSUB/RETURN (etichette o numeri), CLS, LOCATE, catena F5, errori su riga.
2a. **Fatto**: stringhe, array (interi e stringhe), INPUT, DIM, funzioni predefinite, POKE.
2b. **Fatto**: SUB/FUNCTION (parametri, locali, ricorsione, SHARED, EXIT), CALL, DECLARE, DO/LOOP, SELECT CASE.
2c. **Fatto**: CONST, COLOR, RANDOMIZE, VPOKE/VPEEK, OUT/INP, SLEEP, STOP.
2d. **Fatto**: array come parametri (per riferimento) e UBOUND.
2e. **Fatto**: SELECT CASE su stringhe.
3a. **Fatto**: grafica bitmap SCREEN 5-8 (PSET/PRESET/POINT/LINE/CIRCLE).
3b. **Fatto**: PAINT, PRINT/INPUT/LOCATE/CLS in grafica, PALETTE.
3c. **Fatto**: sprite (modo 2, SPRITE$, PUT SPRITE, dimensioni).
3d. **Fatto**: GET/PUT di aree, DRAW, COLLISION.
3e. **Fatto**: SCREEN 2 (primitive, testo, sprite), sprite in SCREEN 1-3, CIRCLE ad arco/ellisse, VIEW. **Capitolo grafica chiuso**
    (SCREEN 4 e WINDOW intero aggiunti dopo; fuori restano SCREEN 3 e la grafica in SCREEN 1/3).
3f. Suono e file.
4. **Fatto**: target ROM + `SEGMENT`/chiamate far automatiche (ASCII8/16, Konami, SCC), `INCBIN`, `SETBANK`/`DATAWIN`, `VCOPY`; compilatore dedicato QBCR.COM (stesso sorgente, `-DROMMODE`).
5. Mapper RAM.
