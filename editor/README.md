# Editor di testo SamPr Basic (prototipo, Z80)

`editor.asm` — ROM 16K per MSX2, SCREEN 0 a 80 colonne. Prova: `python etest.py [--shots]`
(assembla con un testo demo di 71 righe, esegue in openMSX NMS-8250, 41 controlli; `--shots`
ricostruisce PNG dalla VRAM salvata in `build\*.png`).

## Schermo
Riga 0 titolo (inverso, `Ln riga/totale  Col n`) · righe 1-22 testo (colonne 0-78) ·
colonna 79 barra verticale (▲ binario ▼) · riga 23 barra orizzontale (◄ binario ►).
Video inverso = caratteri 128-255 (copie negate del font BIOS), glifi 1-5 ridefiniti,
cursore = glifo inverso (bit 7) della cella con lampeggio a software (32 quadri), puntatore del mouse = XOR 80h sulla cella;
la tabella di blink del VDP (R#12/R#13, 10 byte per riga) serve ai colori delle parole chiave (vedi sotto).

## Tastiera
Frecce, Home, SELECT (= Fine), Ctrl+P / Ctrl+N (pagina su/giù), Invio, BS, DEL, TAB (a 4),
caratteri ASCII 32-126. Righe fino a 254 colonne. La vista segue il cursore solo dopo un tasto:
lo scorrimento con il mouse lascia il cursore dov'è, e al primo tasto la vista torna a lui.

## Mouse
Clic sul testo = sposta il cursore · frecce delle barre = 1 riga/colonna (con ripetizione) ·
clic sul binario = pagina (si ferma sotto il puntatore) · trascinamento del pollice = scorre in
proporzione (`scale`: x*y/z a 16 bit, con correzione di arrotondamento perché il pollice stia sotto il puntatore).
Hardware: BIOS `GTTRIG(1)` per il pulsante, `GTPAD(12..14)` per i movimenti (porta 1; `MPAD`=16 per la porta 2).
Test: con `mmode`=1 movimento/pulsanti arrivano da `tm_dx/tm_dy/tm_btn` (openMSX non permette di iniettare eventi mouse).

## Dati
Gap buffer in RAM C100h-EFFFh (≈12 KB), offset logici, LF = fine riga. Un byte 0 all'inizio del gap
e in fondo al buffer fa da sentinella: il ridisegno legge la memoria senza controllare il gap carattere
per carattere (22 righe in pochi ms). `nlines`, `curline`, `topline` sono mantenute in modo incrementale.

## Non ancora fatto / non verificato
- Mouse reale: non verificato su hardware (segno e scala di `GTPAD` da controllare; se gli assi sono invertiti basta negare in `mouse_read`).
- Caricamento/salvataggio file (serve MSX-DOS/Nextor), selezione/copia/incolla, cerca, undo, tasto destro.
- Buffer ≈12 KB; con il mapper si può estendere. Una riga più lunga di 254 colonne non si può inserire.
- Il ridisegno è sempre completo (testo intero) quando la vista scorre o il testo cambia.

## Carica / salva (build `.COM`, MSX-DOS)
`sjasmplus -DCOM editor.asm` produce `ed.com` (≈4,5 KB); `python ecom.py` lo prova su MSX-DOS 1.03
(NMS-8250, cartella host come disco A:, 20 controlli, verifica i byte dei file salvati sul PC).
La build ROM (`etest.py`, 41 controlli) resta per i test senza DOS: stesso sorgente, `IFDEF COM`.

Uso: `ED [file]`. Tasti: **Ctrl+S** salva (chiede il nome se manca) · **Ctrl+W** salva con nome ·
**Ctrl+O** apre · **Ctrl+Q** esce al DOS. Il nome si digita sulla barra del titolo (Invio, Esc, BS).
Con modifiche non salvate Ctrl+O / Ctrl+Q avvisano: si ripete lo stesso tasto per scartarle.
Il titolo mostra `MSXQB Editor NOME*` (`*` = modificato) oppure l'ultimo messaggio (fino al tasto successivo).

- API a FCB (open/make/close/delete + lettura/scrittura a blocchi casuali con record da 1 byte):
  compatibile con MSX-DOS 1 e, per retrocompatibilità, con Nextor/MSX-DOS 2. Su Nextor non ancora provato.
- Su disco CR LF, in memoria LF. Al caricamento: CR scartati, TAB espansi a multipli di 4, byte non stampabili → `?`,
  ferma a 1Ah. Il salvataggio non scrive il 1Ah finale.
- Buffer 2000h-BFFFh (≈40 KB). File più grandi: caricati troncati, con avviso «File too large - truncated».
- Variabili in C000h (pagina 3): in pagina 0 il debugger legge la ROM del BIOS durante le interruzioni.
- Nome file 8.3 (con `A:` opzionale), niente percorsi né caratteri jolly.

## Selezione e clipboard
Test: `python esel.py` (build ROM, 30 controlli con un modello Python del testo); `ecom.py` prova taglia/incolla/salva anche sotto DOS.
- **Tastiera**: Shift + frecce / Home / SELECT(Fine) / Ctrl+P / Ctrl+N estendono la selezione; un movimento senza Shift la annulla.
  Lo Shift si legge dalla matrice tastiera (BIOS `SNSMAT`): `CHGET` dà lo stesso codice con e senza Shift.
- **Mouse**: il trascinamento seleziona; Shift+clic estende; col puntatore sul bordo alto/basso del testo la vista scorre da sola.
- **Comandi**: Ctrl+C o Ctrl+Ins copia · Ctrl+X o Shift+Canc taglia · Ctrl+V o Shift+Ins incolla · Ctrl+A seleziona tutto.
  Digitare, Invio, Tab, BS e Canc sostituiscono / eliminano la selezione. (Ctrl+X e SELECT danno entrambi il codice 18h: si distinguono dalla matrice.)
- **Disegno**: i caratteri selezionati usano i glifi inversi (128-255); anche l'a-capo selezionato è un blocco inverso a fine riga.
  Durante il disegno la selezione diventa un intervallo di indirizzi fisici, confrontato con un `selmark` per carattere.
- **Clipboard**: in RAM sopra le variabili (C400h fino a 768 byte sotto il BDOS nel `.COM`; 2,5 KB in E600h nella build ROM).
  Selezioni più grandi: «Selection too big for the clipboard». Con l'incolla senza spazio: «No room to paste».
- Nessuna modifica in-place dell'ancora: dopo ogni modifica del testo l'ancora si azzera (gli offset logici cambierebbero).
- Non fatto: undo, selezione a parole/righe (doppio/triplo clic), clipboard condivisa tra sessioni, tasto destro.

## Barra dei menu
Test: `python emenu.py` (build ROM, 34 controlli); `ecom.py` prova anche File > New e File > Open... dal menu sotto DOS.
- **Riga 0**: ` File  Edit  Help ` (colonne 0-17, 6 per titolo) · nome file (o `(untitled)`) con `*` se modificato, a colonna 19 ·
  `Ln riga/totale  Col n` a colonna 48. Un messaggio di stato sostituisce nome e stato fino al tasto successivo; i titoli restano.
- **Apertura**: ESC (apre File) o clic su un titolo. Il titolo del menu aperto è in video normale (il resto della barra è inverso).
- **Tastiera**: ←/→ cambiano menu (con avvolgimento) · ↑/↓ cambiano voce (con avvolgimento) · Invio esegue ·
  lettera = tasto rapido della voce (N/O/S/A/X in File, T/C/P/D/A in Edit, S/A in Help) · ESC chiude.
- **Mouse**: il passaggio del puntatore evidenzia la voce; clic su una voce la esegue; clic su un altro titolo cambia menu,
  sullo stesso titolo o fuori dal riquadro chiude (senza passare il clic al testo).
- **Voci**: File: New, Open..., Save, Save As..., Exit · Edit: Cut, Copy, Paste, Delete, Select all · Help: Shortcuts, About.
  Nella build ROM (senza DOS) le voci di File mostrano «No disk access in this build».
- **Disegno**: riquadro in video inverso con cornice di glifi propri (codici 6-12: linee e angoli, con le copie inverse a 134-140);
  con il menu aperto il cursore è nascosto; alla chiusura o al cambio di menu il testo sotto viene ridisegnato.
- **File > New** chiede conferma se ci sono modifiche (stesso meccanismo di Open/Exit: si ripete il comando).
- Non fatto: separatori e voci disattivate (grigie), sottomenu, menu View/Search, Alt/GRAPH per aprire i menu.

## Cerca / sostituisci
Test: `python esrch.py` (build ROM, 34 controlli con un modello Python); tutte le suite: `etest` 41 · `esel` 30 · `emenu` 34 · `esrch` 34 · `ecom` 22.
- **Comandi**: Ctrl+F cerca · Ctrl+G cerca ancora · Ctrl+T sostituisci · menu **Find** (Find..., Find next, Replace..., Match case: off/on).
  Il menu ora ha 4 titoli (` File  Edit  Find  Help `); nome file e messaggi partono da colonna 25.
- **Prompt di riga** (`prompt_line`, usato anche per i nomi file): sulla barra del titolo, spazi ammessi, fino a 30 caratteri,
  parte dal termine precedente (lo si edita con BS o lo si accetta con Invio), Esc annulla.
- **Ricerca**: dal cursore verso la fine, poi dall'inizio fino al cursore (messaggio «Search wrapped around»);
  «Text not found» se non c'è. La corrispondenza trovata diventa la selezione (stessa evidenziazione in video inverso),
  il cursore va in fondo alla corrispondenza e la riga viene centrata se non era visibile.
  Di default non distingue maiuscole/minuscole; «Match case» nel menu Find le distingue.
- **Sostituzione**: chiede termine e testo sostitutivo (può essere vuoto) e poi, per ogni corrispondenza dal cursore alla fine,
  `Y` sostituisce · `N` salta · `A` sostituisce tutte le restanti senza chiedere · `Esc` si ferma.
  Alla fine «Replaced N occurrence(s)». Il testo inserito non viene cercato di nuovo (nessun ciclo infinito).
- **Implementazione**: il gap resta sul cursore, quindi il testo dopo il cursore è contiguo in memoria (e quello prima pure):
  la scansione è un ciclo con filtro sul primo carattere (`or maschera`) e confronto completo solo sui candidati;
  per questo le corrispondenze a cavallo del cursore nel giro intorno non vengono trovate. Le sostituzioni riusano `ins_block`
  (lo stesso codice dell'incolla) e `sel_delete`, con costo proporzionale alla distanza tra le corrispondenze.
- Il `.COM` ora ha il buffer testo a 2800h-BFFFh (circa 38 KB); `ed.com` è 7,9 KB.
- Non fatto: ricerca all'indietro, parola intera, evidenziazione di tutte le occorrenze, testo selezionato come termine predefinito.

## Annulla / ripeti (undo / redo)
Test: `python eundo.py` (build ROM, 42 controlli con modello Python); `ecom.py` prova undo/redo anche sotto DOS e l'azzeramento della cronologia dopo Open.
Tutte le suite: `etest` 41 · `esel` 30 · `emenu` 34 · `esrch` 34 · `eundo` 42 · `ecom` 25.
- **Comandi**: Ctrl+Z annulla · Ctrl+Y ripete · voci Undo / Redo in cima al menu Edit (tasti rapidi U / R). Messaggi: «Nothing to undo» / «Nothing to redo».
- **Un passo di undo = un gruppo**: una serie di battute dello stesso tipo (caratteri, Invio e Tab; Backspace; Canc) è un solo gruppo;
  qualunque altro tasto, clic o comando di menu lo chiude. Taglia, incolla (che sostituisce una selezione) e la sostituzione globale
  (anche con conferma Y/N/A) sono un solo passo ciascuno.
- **Dopo l'annullamento** il cursore va dove la modifica è stata annullata (dopo il testo ripristinato per una cancellazione,
  all'inizio per un inserimento); una nuova modifica scarta la coda di redo; Open e New azzerano la cronologia.
- **Registro** (`UNDO`): record = tipo (1 inserimento, 2 cancellazione; bit 7 = unito al gruppo precedente), offset, lunghezza, dati,
  e in coda la dimensione del record (per leggere all'indietro). Le battute di testo contigue si fondono in un solo record (fino a 200 byte).
  Capienza: 3 KB nel `.COM` (C400h-CFFFh, la clipboard parte da D000h), 2 KB nella build ROM. A registro pieno si scartano i gruppi
  più vecchi (e il registro si compatta); se una sola modifica è più grande di tutto il registro, la cronologia si azzera con
  «Edit too large to undo - history cleared».
- **Limite noto**: una serie lunghissima di Backspace (record da 8 byte) riempie il registro e, essendo un unico gruppo, perde i record più vecchi
  (si possono annullare gli ultimi ~256 caratteri cancellati). Non si ricorda quale versione corrisponde al file salvato: dopo un undo il testo risulta «modificato».

## Note sui test
- I test girano ora con `set renderer none` (nessuna finestra di openMSX): prima la finestra si apriva in primo piano ad ogni prova
  e sembrava ricevere tasti veri della tastiera del PC (comparivano ripetizioni di una sola lettera nei prompt o nel testo,
  circa 2 volte su 40). Senza finestra: 0 fallimenti in 60 + 140 esecuzioni.
- Il `.COM` ora ha il buffer testo a 3300h-BFFFh (~35 KB); `ed.com` è 12,4 KB.


## Run (F5) — collegamento al compilatore
Menu **Run** (ultimo della barra) o **F5**: salva il sorgente (chiede il nome se manca, aggiunge `.BAS` se non c'e'
estensione), carica `QBC.COM` a catena, compila ed esegue; alla fine il programma ricarica l'editor (`QB.COM`).
In caso di errore l'editor riparte con il cursore sulla riga e il messaggio `Line N: ...` nel titolo.
F5 e' un tasto funzione MSX: all'avvio l'editor imposta la stringa di F5 a un solo byte (15h) e lo gestisce come comando.
Il file deve chiamarsi `QB.COM` sul disco (il compilatore lo ricarica per nome). Vedi `../onmsx/README.md`.
Test: `python erun.py` (usa `../onmsx/qbc.asm`).

## Colori delle parole chiave (stadio 24)
Le parole chiave del BASIC (istruzioni, funzioni, `REM`, `__ASM`/`__ENDASM`, `TARGET`...: 143 parole, tabella generata da `gen_kw.py`
a partire da `../onmsx/qbc.asm`) appaiono in giallo chiaro su blu, il resto in bianco. Nello SCREEN 0 a 80 colonne i colori sono solo due
(R#7 e R#12), ma la tabella di blink assegna a ogni cella uno dei due: con R#13 = 10h le celle col bit acceso restano sempre nel colore di R#12
(KWCOL = 0B4h). Regole (stesse del modello Python di `ekw.py`): parole di 2-10 caratteri fatte di lettere, cifre, `_` e `$`, non fra virgolette
e non iniziate da una cifra; un apostrofo o `REM` fanno finire la colorazione sulla riga; maiuscole e minuscole sono equivalenti.
Il calcolo non rallenta la digitazione: dopo ogni ridisegno i colori si azzerano e si ricalcolano nei tempi morti (due righe per quadro,
leggendo il testo dalla VRAM), quindi appaiono una frazione di secondo dopo il testo; con un tasto in attesa non si calcola nulla.
Il cursore, che prima usava il blink hardware, ora e' il glifo inverso della cella (stesso lampeggio: 32 quadri).
Test: `python ekw.py` (il modello Python confronta i flag di tutte le 22 righe, anche dopo lo scorrimento); gli altri test leggono la cella del cursore
da `blx`/`bly`/`curch`. Attenzione: la build ROM dei test (con il testo demo) ha ora solo ~90 byte liberi nei 16 KB.

## F5 piu' rapido
- Se il testo non e' cambiato dall'ultimo caricamento/salvataggio (`modified` = 0 e `onfile` = 1) F5 non salva il sorgente (risparmia ~3 s di disco).
- Se in piu' il programma e' appena stato eseguito da questa compilazione (`compiled` = 1: l'editor e' stato riaperto da NOME.COM con la riga di comando `NOME.BAS +`)
  F5 non ricompila: carica direttamente NOME.COM col caricatore (`run_only`; se il file manca, ricompila). `compiled` si azzera quando il testo cambia
  (all'atto del salvataggio con `modified` = 1), con Open e con New. Test: `erun.py` (F5 senza modifiche entro 12 s).
- **Salvataggio in posto**: se il file esiste e non e' molto piu' lungo del testo, `save_file` lo apre e lo sovrascrive (senza cancellarlo e ricrearlo: 1,3 s invece di 3,1 s su DOS 1);
  se il testo nuovo e' piu' corto scrive ^Z dopo il testo e il resto resta come residuo (il caricamento si ferma al ^Z; il compilatore tronca il sorgente al ^Z).
  Se il file e' piu' lungo del testo di oltre 1 KB (o supera 64 KB) si cancella e ricrea come prima. Test: `python esave.py`.

## MSX1: 40 colonne (stadio 25)
All'avvio l'editor legge la versione MSX (byte 002Dh): su MSX1 usa il testo a 40 colonne (TEXT 1, tabella dei pattern a 0800h), su MSX2 e superiori
l'80 colonne di prima (TEXT 2, pattern a 1000h). Tutta la geometria e' in variabili calcolate da `width_init` (`sw` = 80/40, `swm1` = colonna della barra
verticale, `thv` = celle del binario orizzontale, `hmaxw` = massimo scroll orizzontale = 256 - sw, `pattb`, `mxmax` = sw*8 per il mouse, ...);
`cell_addr` moltiplica la riga per `sw`. A 40 colonne: la barra dei menu occupa le colonne 0-29, a destra c'e' lo stato compatto `riga:colonna`
(con `*` se il testo e' modificato) e un messaggio occupa tutta la barra; i riquadri dei menu si spostano a sinistra per non uscire dallo schermo
(`menu_info`). Non esistono su MSX1 (TMS9918): la tabella di blink e quindi i colori delle parole chiave, R#12, R#13 e R#14 (non si scrivono mai: il
numero di registro 12-14 si sovrapporrebbe a R#4-R#6 e romperebbe lo schermo); il cursore e' comunque il glifo inverso.
Test: `python e40.py` (build ROM su MSX1, openMSX `Sony_HB-75P`: layout, cursore, scroll verticale e orizzontale, barre, mouse, menu Run); gli altri test
restano su MSX2. Il `.COM` (con il DOS) non e' ancora stato provato su MSX1: in openMSX l'MSX1 con interfaccia disco AVT parte in Disk BASIC.

## Menu da tastiera
- **Esc** apre il menu File; **F1, F2, F3, F4** aprono direttamente File, Edit, Find, Help (all'avvio l'editor ridefinisce le stringhe dei tasti funzione F1-F4 a un solo
  carattere di controllo: 02h, 04h, 05h, 0Ah); **F5** esegue (Run). Con un menu aperto: F1-F4 passano a quel menu, **←/→** al menu vicino, **↑/↓** scelgono la voce,
  **Invio** la esegue, la lettera sottolineata di ogni voce la esegue direttamente, **Esc** chiude; F5 chiude il menu e lancia il programma.
- All'avvio si scarta il buffer di tastiera (`KILBUF`), cosi' i tasti rimasti dal lancio precedente non fanno ripartire F5; lo stesso fa il runtime prima di attendere il
  tasto a fine programma («Press any key..»). Test: `python efk.py`.
