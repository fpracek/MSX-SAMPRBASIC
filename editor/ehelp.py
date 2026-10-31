#!/usr/bin/env python3
"""Aiuto e About dell'editor .COM (NMS-8250, MSX-DOS 1): F7 indice, F6 su parola, Help>Topic, About, argomento mancante.
HELP.TXT/HELP.IDX sono generati da ../doc/gen_help.py."""
import os
import subprocess
import sys

import ecom
import etest
from etest import Scenario, check, load, BUILD, OPENMSX, MACHINE

sys.path.insert(0, os.path.join(ecom.HERE, '..', 'doc'))
import gen_help

SHIFT = (6, 0x01)
F6 = (SHIFT, (6, 0x20))
F7 = (SHIFT, (6, 0x40))
ESC = (7, 0x04)


def main():
    ecom.prepare_disk()
    data, idx, n = gen_help.build()
    open(os.path.join(ecom.DISK, 'HELP.TXT'), 'wb').write(data)
    open(os.path.join(ecom.DISK, 'HELP.IDX'), 'wb').write(idx)
    open(os.path.join(ecom.DISK, 'P.BAS'), 'wb').write(b'CLS\r\nPRINT 5\r\n')
    syms = ecom.assemble_com()
    sc = Scenario(syms)
    sc.t = 20.0
    sc.text('ED P.BAS' + chr(92) + 'r', 8.0)
    ecom.chord(sc, *F7, gap=3.0)
    sc.dump('h1_index')
    sc.tap(*ESC, 1, 1.0)
    sc.dump('h2_closed')
    sc.tap(8, 0x40, 1, 0.4)                     # riga 2: PRINT 5
    ecom.chord(sc, *F6, gap=3.0)                # F6 con il cursore a inizio riga: parola PRINT
    sc.dump('h3_word')
    sc.tap(*ESC, 1, 1.0)
    sc.tap(7, 0x01, 1, 0.8)                     # F4: menu Help
    sc.text('t', 1.0)
    sc.tap(7, 0x20, 5, 0.2)                     # cancella la parola proposta
    sc.text('chr$' + chr(92) + 'r', 3.0)
    sc.dump('h4_topic')
    sc.tap(*ESC, 1, 1.0)
    sc.tap(7, 0x01, 1, 0.8)
    sc.text('a', 1.0)
    sc.dump('h5_about')
    sc.tap(8, 0x01, 1, 0.5)                     # un tasto qualsiasi chiude
    sc.dump('h5b_after')
    sc.tap(7, 0x01, 1, 0.8)
    sc.text('t', 1.0)
    sc.tap(7, 0x20, 5, 0.2)
    sc.text('zzzz' + chr(92) + 'r', 2.0)
    sc.dump('h6_nohelp')
    tcl = os.path.join(BUILD, 'ehelp.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('h') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', ecom.DISK, '-script', tcl], timeout=600)
    for nm in ('h1_index', 'h2_closed', 'h3_word', 'h4_topic', 'h5_about', 'h5b_after', 'h6_nohelp'):
        print('---', nm)
        try:
            rows, vs, bl = load(nm)
        except Exception as e:
            check(False, 'dump mancante: %s' % e)
            continue
        for i in range(14):
            r = rows[i]
            print('   |' + r.replace('~', '')[:60])
    print('FALLITI: %d' % etest.FAILS)


if __name__ == '__main__':
    main()
