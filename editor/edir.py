#!/usr/bin/env python3
r"""MSX-DOS 2 (turbo R, openMSX): la directory di lavoro e' quella del file aperto. Strumenti (SAMPRBAS, QBC, RT.BIN) nella radice,
progetto in \GIOCHI: percorso sulla riga di comando, F5 (compilatore dalla radice, sorgente e .COM nella cartella), ritorno nella cartella."""
import os
import shutil
import subprocess
import sys

import ecom
import etest
from etest import Scenario, check, load, BUILD, OPENMSX

ONMSX = os.path.join(ecom.HERE, '..', 'onmsx')
BS = chr(92)
MACHINE = os.environ.get('GMACHINE', 'Panasonic_FS-A1ST')


def txt(rows, r):
    return rows[r].replace('~', '').replace('#', ' ')


def main():
    ecom.prepare_disk()
    d = ecom.DISK
    for f in ('COMMAND2.COM', 'MSXDOS2.SYS'):
        shutil.copy(os.path.join(ecom.DOSDIR, f), d)
    syms = ecom.assemble_com()
    shutil.copy(os.path.join(ONMSX, 'build', 'qbc.com'), os.path.join(d, 'QBC.COM'))
    shutil.copy(os.path.join(ONMSX, 'build', 'rt.bin'), os.path.join(d, 'RT.BIN'))
    shutil.copy(os.path.join(ecom.HERE, 'ed.com'), os.path.join(d, 'SAMPRBAS.COM'))
    os.makedirs(os.path.join(d, 'GIOCHI'), exist_ok=True)
    open(os.path.join(d, 'GIOCHI', 'HELLO.SPB'), 'wb').write(b'PRINT "dir ok"' + bytes([13, 10]))
    sc = Scenario(syms)
    sc.t = 30.0
    sc.text('SAMPRBAS ' + BS + BS + 'GIOCHI' + BS + BS + 'HELLO' + BS + 'r', 12.0)
    sc.dump('d1_open')
    sc.tap(7, 0x02, 1, 0.5)                          # F5
    sc.t += 80.0
    sc.do('set ::nopatch 1', 0.1)
    sc.dump('d2_ran')
    sc.tap(8, 0x01, 1, 0.5)                          # space: the program ends and reloads the editor
    sc.t += 40.0
    sc.do('unset ::nopatch', 0.1)
    sc.dump('d3_back')
    ecom.chord(sc, *ecom.CTRL_O, gap=1.5)            # the open dialog shows the current directory
    sc.dump('d4_browser')
    tcl = os.path.join(BUILD, 'edir.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('d') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', d, '-script', tcl], timeout=1500)
    print('--- d1 percorso sulla riga di comando')
    rows, vs, bl = load('d1_open')
    check('Loaded' in txt(rows, 0), 'caricato: ' + txt(rows, 0)[:50])
    check(txt(rows, 1).startswith('PRINT "dir ok"'), 'contenuto: ' + txt(rows, 1)[:20])
    print('--- d2 F5: compilazione dalla radice, programma in esecuzione nella cartella')
    rows, vs, bl = load('d2_ran')
    allt = ' '.join(txt(rows, r) for r in range(0, 6))
    check('dir ok' in allt, 'il programma ha stampato: ' + allt[:60])
    names = sorted(os.listdir(os.path.join(d, 'GIOCHI')))
    check(any(n.lower() == 'hello.com' for n in names), 'HELLO.COM creato nella cartella del progetto: %s' % names)
    check(not any(n.lower() == 'hello.com' for n in os.listdir(d)), 'nessun HELLO.COM nella radice')
    print('--- d3 ritorno nell\'editor, nella cartella del progetto')
    rows, vs, bl = load('d3_back')
    check('Loaded' in txt(rows, 0) and txt(rows, 1).startswith('PRINT "dir ok"'), 'editor riaperto con il sorgente: ' + txt(rows, 0)[:50] + ' | ' + txt(rows, 1)[:16])
    rows, vs, bl = load('d4_browser')
    check('GIOCHI' in txt(rows, 0), 'directory corrente = progetto: ' + txt(rows, 0)[:40])
    check('HELLO.SPB' in ' '.join(txt(rows, r) for r in range(1, 5)), 'file del progetto elencati')
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
