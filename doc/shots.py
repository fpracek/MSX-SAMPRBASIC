#!/usr/bin/env python3
"""Cattura schermate di openMSX (editor, aiuto, About, menu) per il manuale -> doc/img/. Va eseguito in primo piano."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ED = os.path.join(HERE, '..', 'editor')
sys.path.insert(0, ED)
os.chdir(ED)
import ecom
import etest
from etest import Scenario, BUILD, OPENMSX, MACHINE

IMG = os.path.join(HERE, 'img')
os.makedirs(IMG, exist_ok=True)
sys.path.insert(0, HERE)
import gen_help

SHIFT = (6, 0x01)
F6 = (SHIFT, (6, 0x20))
F7 = (SHIFT, (6, 0x40))
ESC = (7, 0x04)
PROG = ('OPTION LABELS\r\nREM Tabellina del sette\r\nCLS\r\nFOR i = 1 TO 10\r\n  PRINT "7 x"; i; "="; 7 * i\r\nNEXT i\r\n'
        'SUB saluta(n$)\r\n  PRINT "Ciao, "; n$\r\nEND SUB\r\nCALL saluta("MSX")\r\n')


def shot(sc, name):
    sc.do('screenshot "%s/%s.png"' % (IMG.replace(chr(92), '/'), name), 1.0)


def main():
    ecom.prepare_disk()
    data, idx, n = gen_help.build()
    open(os.path.join(ecom.DISK, 'HELP.TXT'), 'wb').write(data)
    open(os.path.join(ecom.DISK, 'HELP.IDX'), 'wb').write(idx)
    open(os.path.join(ecom.DISK, 'TAB.SPB'), 'wb').write(PROG.encode())
    for n in ('ASTEROID', 'LABIRINT', 'SNAKE', 'TETRIS'):
        open(os.path.join(ecom.DISK, n + '.SPB'), 'wb').write(b'REM ' + n.encode() + bytes([13, 10]))
    syms = ecom.assemble_com()
    sc = Scenario(syms)
    sc.t = 20.0
    sc.do('set throttle on', 0.2)
    sc.do('screenshot "%s/dummy.png"' % IMG.replace(chr(92), '/'), 0.5)
    sc.text('ED TAB' + chr(92) + 'r', 8.0)
    shot(sc, 'editor')
    sc.tap(*ESC, 1, 0.6)
    sc.text('o', 1.5)
    shot(sc, 'browser')
    sc.tap(*ESC, 1, 0.8)
    sc.tap(7, 0x01, 1, 0.8)
    shot(sc, 'menu_help')
    sc.tap(*ESC, 1, 0.6)
    ecom.chord(sc, *F7, gap=3.0)
    shot(sc, 'help_index')
    sc.tap(*ESC, 1, 1.0)
    sc.tap(8, 0x40, 4, 0.4)
    sc.tap(8, 0x80, 4, 0.3)
    ecom.chord(sc, *F6, gap=3.0)
    shot(sc, 'help_topic')
    sc.tap(*ESC, 1, 1.0)
    sc.tap(7, 0x01, 1, 0.8)
    sc.tap(8, 0x40, 4, 0.3)
    sc.tap(7, 0x80, 1, 1.0)
    shot(sc, 'about')
    tcl = os.path.join(BUILD, 'shots.tcl')
    open(tcl, 'w').write(sc.script().replace('catch {set renderer none}', 'catch {set renderer SDL}'))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', ecom.DISK, '-script', tcl], timeout=600)
    print(sorted(os.listdir(IMG)))


if __name__ == '__main__':
    main()
