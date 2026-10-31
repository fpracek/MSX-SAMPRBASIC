#!/usr/bin/env python3
"""Nomi .SPB e finestra di apertura (build .COM, MSX-DOS 1 su NMS-8250; con DOS2=1 e GMACHINE=Panasonic_FS-A1ST anche cartelle).
Verifica: avvio con il solo nome (esistente / nuovo), estensione .SPB aggiunta, Open con la finestra, Save As a 8 caratteri."""
import os
import subprocess
import sys

import ecom
import etest
from etest import Scenario, check, load, BUILD, OPENMSX, MACHINE

DOS2 = os.environ.get('DOS2') == '1'
MACHINE = os.environ.get('GMACHINE', MACHINE)
ESC = (7, 0x04)
DOWN = (8, 0x40)
UP = (8, 0x20)
RIGHT = (8, 0x80)
ENTER = (7, 0x80)


def txt(rows, r):
    return rows[r].replace('~', '').replace('#', ' ')


def main():
    ecom.prepare_disk()
    d = ecom.DISK
    if DOS2:
        for f in ('COMMAND2.COM', 'MSXDOS2.SYS'):
            subprocess.run(['cmd', '/c', 'copy', '/Y', os.path.join(ecom.DOSDIR, f), d], capture_output=True)
        os.makedirs(os.path.join(d, 'GIOCHI'), exist_ok=True)
        open(os.path.join(d, 'GIOCHI', 'SUB1.SPB'), 'wb').write(b'PRINT 2\r\n')
        open(os.path.join(d, 'GIOCHI', 'SUB2.SPB'), 'wb').write(b'PRINT 3\r\n')
    for n, body in (('HELLO.SPB', b'PRINT 1\r\n'), ('ALFA.SPB', b'REM alfa\r\n'), ('ZULU.SPB', b'REM zulu\r\n'), ('OLD.BAS', b'REM old\r\n')):
        open(os.path.join(d, n), 'wb').write(body)
    syms = ecom.assemble_com()
    sc = Scenario(syms)
    sc.t = 30.0 if DOS2 else 20.0
    bs = chr(92)
    sc.text('ED HELLO' + bs + 'r', 8.0)
    sc.dump('b1_hello')
    sc.tap(*ESC, 1, 0.6)
    sc.text('o', 1.5)
    sc.dump('b2_browser')
    if DOS2:
        sc.tap(*ENTER, 1, 1.0)               # la prima voce e' la cartella GIOCHI
        sc.dump('b3b_sub')
        sc.tap(*ENTER, 1, 1.0)               # la prima voce di GIOCHI e' ".." : si torna alla radice
        sc.dump('b3c_root')
    sc.text('Z', 0.5)                        # la lettera iniziale porta la selezione su ZULU.SPB
    sc.dump('b3_sel')
    sc.tap(*ENTER, 1, 3.0)
    sc.dump('b4_opened')
    sc.tap(*ESC, 1, 0.6)
    sc.text('a', 1.0)
    sc.text('LONGNAMEXYZ.TXT' + bs + 'r', 4.0)
    sc.dump('b5_saved')
    ecom.chord(sc, *ecom.CTRL_Q, gap=2.0)
    sc.t += 1.0
    sc.do('set ::nopatch 1', 0.1)
    sc.text('ED NUOVO' + bs + 'r', 6.0)
    sc.dump('b6_new')
    tcl = os.path.join(BUILD, 'ebrowse.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('b') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', d, '-script', tcl], timeout=600)

    print('--- b1 avvio con il solo nome: HELLO -> HELLO.SPB')
    rows, vs, bl = load('b1_hello')
    check('Loaded' in txt(rows, 0), 'caricato: ' + txt(rows, 0)[:50])
    check(txt(rows, 1).startswith('PRINT 1'), 'contenuto: ' + txt(rows, 1)[:20])
    print('--- b2 finestra di apertura')
    rows, vs, bl = load('b2_browser')
    allt = ' '.join(txt(rows, r) for r in range(1, 23))
    check('Open:' in txt(rows, 0), 'titolo: ' + txt(rows, 0)[:40])
    check('ALFA.SPB' in allt and 'HELLO.SPB' in allt and 'ZULU.SPB' in allt, 'file .SPB elencati: ' + allt[:80])
    check('OLD.BAS' not in allt, 'i file .BAS non compaiono')
    if DOS2:
        check('[GIOCHI]' in allt, 'cartella elencata: ' + allt[:60])
    if DOS2:
        print('--- b3b dentro la cartella GIOCHI')
        rows, vs, bl = load('b3b_sub')
        allt = ' '.join(txt(rows, r) for r in range(1, 23))
        check('GIOCHI' in txt(rows, 0), 'percorso nel titolo: ' + txt(rows, 0)[:40])
        check('SUB1.SPB' in allt and 'SUB2.SPB' in allt and '[..]' in allt, 'contenuto della cartella: ' + allt[:80])
        check('HELLO.SPB' not in allt, 'i file della radice non compaiono')
        rows, vs, bl = load('b3c_root')
        allt = ' '.join(txt(rows, r) for r in range(1, 23))
        check('[GIOCHI]' in allt and 'HELLO.SPB' in allt, 'tornati alla radice con ..')
    print('--- b4 apertura dalla finestra')
    rows, vs, bl = load('b4_opened')
    check('Loaded' in txt(rows, 0), 'caricato dalla finestra: ' + txt(rows, 0)[:50])
    print('--- b5 Save As: 8 caratteri + .SPB')
    ok = os.path.exists(os.path.join(d, 'LONGNAME.SPB'))
    check(ok, 'LONGNAME.SPB creato su disco: %s' % sorted(os.listdir(d)))
    check(not os.path.exists(os.path.join(d, 'LONGNAMEXYZ.TXT')) and not os.path.exists(os.path.join(d, 'LONGNAME.TXT')), 'nessuna estensione digitata')
    print('--- b6 avvio con un nome nuovo')
    rows, vs, bl = load('b6_new')
    check('not found' in txt(rows, 0) or 'new file' in txt(rows, 0).lower(), 'file nuovo: ' + txt(rows, 0)[:50])
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
