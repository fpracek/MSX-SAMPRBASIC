def rw(p, f):
    t = open(p, encoding='latin-1', newline='').read()
    nl = '\r\n' if '\r\n' in t else '\n'
    t = f(t.replace('\r\n', '\n'))
    open(p, 'w', encoding='latin-1', newline='').write(t.replace('\n', nl))


def rep(t, a, b):
    assert t.count(a) == 1, (a[:70], t.count(a))
    return t.replace(a, b)


rw('editor.asm', lambda t: rep(t, "kwnext  equ RAMB+0423h ",
    "compiled equ RAMB+0424h             ; b  NOME.COM e' la compilazione del testo attuale (marcatore \" +\" dal programma)\nonfile  equ RAMB+0425h              ; b  il testo corrisponde a un file su disco (caricato o salvato)\ncmdok   equ RAMB+0426h              ; b  la riga di comando aveva il marcatore \" +\"\nkwnext  equ RAMB+0423h "))


def f(t):
    # getcmd: azzera il marcatore
    t = rep(t, "getcmd:                         ; riga di comando (0080h: lunghezza + testo) -> fname\n        ld hl,0\n        ld (errline),hl\n        xor a\n        ld (errcode),a\n",
            "getcmd:                         ; riga di comando (0080h: lunghezza + testo) -> fname\n        ld hl,0\n        ld (errline),hl\n        xor a\n        ld (errcode),a\n        ld (cmdok),a\n        ld (compiled),a\n        ld (onfile),a\n")
    t = rep(t, ".e:     cp 'E'\n        ret nz\n        inc hl\n        call .num",
            ".e:     cp '+'                  ; \" +\": il programma e' appena stato eseguito dalla compilazione di questo sorgente\n        jr nz,.e2\n        ld a,1\n        ld (cmdok),a\n        ret\n.e2:    cp 'E'\n        ret nz\n        inc hl\n        call .num")
    t = rep(t, "startup_load:\n        ld a,(fname)\n        or a\n        ret z\n        call load_file\n",
            "startup_load:\n        ld a,(fname)\n        or a\n        ret z\n        call load_file\n        ld a,(cmdok)\n        ld (compiled),a\n")
    # load_file: azzera, poi onfile alla fine con successo
    t = rep(t, "load_file:\n        call mk_fcb\n", "load_file:\n        xor a\n        ld (compiled),a\n        ld (onfile),a\n        call mk_fcb\n")
    t = rep(t, "        xor a\n        ld (modified),a\n        ld a,(ioerr)\n        cp 2\n        jr nz,.ok",
            "        xor a\n        ld (modified),a\n        inc a\n        ld (onfile),a\n        ld a,(ioerr)\n        cp 2\n        jr nz,.ok")
    # save_file: se il testo e' cambiato la compilazione non vale piu'; a salvataggio riuscito il testo e' su disco
    t = rep(t, "save_file:                      ; -> C se errore (messaggio in msgptr)\n        call mk_fcb\n",
            "save_file:                      ; -> C se errore (messaggio in msgptr)\n        ld a,(modified)\n        or a\n        jr z,.ncl\n        xor a\n        ld (compiled),a        ; il testo e' cambiato dopo l'ultima compilazione\n.ncl:   call mk_fcb\n")
    t = rep(t, "        jr nz,.err\n        xor a\n        ld (modified),a\n        ld hl,(nbytes)",
            "        jr nz,.err\n        xor a\n        ld (modified),a\n        inc a\n        ld (onfile),a\n        ld hl,(nbytes)")
    # k_new: nessun file
    t = rep(t, "        call ed_reset\n        xor a\n        ld (fname),a\n        ld a,1\n        ld (dirty),a\n        ld hl,m_newfile",
            "        call ed_reset\n        xor a\n        ld (fname),a\n        ld (onfile),a\n        ld (compiled),a\n        ld a,1\n        ld (dirty),a\n        ld hl,m_newfile")
    # k_run: salta il salvataggio se il testo e' invariato; rilancia NOME.COM se la compilazione e' valida
    t = rep(t, ".save:  call save_file\n        ret c\n        call leave_screen\n",
            """.save:  ld a,(modified)
        or a
        jr nz,.dosave           ; testo cambiato: va salvato
        ld a,(onfile)
        or a
        jr z,.dosave            ; nessun file su disco: va salvato
        ld a,(compiled)
        or a
        jr z,.comp              ; invariato ma non compilato (o errore): si ricompila senza salvare
        call run_only           ; invariato e compilato: rilancia NOME.COM (ritorna solo se manca)
        jr .comp
.dosave: call save_file
        ret c
.comp:  call leave_screen
""")
    t = rep(t, "s_bas:  db \".BAS\",0\ns_qbc:  db \"QBC     COM\"\n",
            """s_bas:  db ".BAS",0
s_qbc:  db "QBC     COM"

run_only:                       ; NOME.COM esiste? allora lo carica con il caricatore (non torna)
        call mk_fcb
        ld hl,s_com3
        ld de,fcb+9
        ld bc,3
        ldir
        ld de,fcb
        ld c,F_OPEN
        call BDOS
        or a
        ret nz
        ld de,fcb
        ld c,F_CLOSE
        call BDOS
        call leave_screen
        ld hl,ldr_img
        ld de,0C000h
        ld bc,ldr_size
        ldir
        ld hl,fcb+1             ; nome del programma da caricare (ldr_fn a C003h)
        ld de,0C003h
        ld bc,11
        ldir
        jp 0C000h
s_com3: db "COM"
""")
    return t


rw('fileio.asm', f)
print('ok')
