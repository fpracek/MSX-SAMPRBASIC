#!/usr/bin/env python3
"""File > Segment... (F8): saves the current file and opens NAMEnnn in the same directory (.COM build, MSX-DOS 1 on NMS-8250)."""
import os
import subprocess
import sys

import ecom
import etest
from etest import Scenario, check, load, BUILD, OPENMSX, MACHINE

ESC = (7, 0x04)
ENTER = (7, 0x80)


def txt(rows, r):
    return rows[r].replace('~', '').replace('#', ' ')


def main():
    ecom.prepare_disk()
    d = ecom.DISK
    open(os.path.join(d, 'FAUST000.SPB'), 'wb').write(b'REM main' + bytes([13, 10]) + b'PRINT 1' + bytes([13, 10]))
    open(os.path.join(d, 'FAUST001.SPB'), 'wb').write(b'SUB uno' + bytes([13, 10]) + b'END SUB' + bytes([13, 10]))
    open(os.path.join(d, 'FAUST003.BIN'), 'wb').write(bytes([1, 2, 3]))
    syms = ecom.assemble_com()
    sc = Scenario(syms)
    sc.t = 20.0
    bs = chr(92)
    sc.text('ED FAUST000' + bs + 'r', 8.0)
    sc.text('X', 0.5)                                   # edit: Segment must save before switching
    sc.tap(*ESC, 1, 0.6)
    sc.text('g', 1.5)
    sc.text('1' + bs + 'r', 5.0)
    sc.dump('s1_seg1')
    sc.tap(*ESC, 1, 0.6)
    sc.text('g', 1.5)
    sc.text('007' + bs + 'r', 2.0)
    sc.dump('s2_new7')
    sc.tap(*ESC, 1, 0.6)
    sc.text('g', 1.5)
    sc.text('3' + bs + 'r', 2.0)
    sc.dump('s2b_bin')
    sc.tap(*ESC, 1, 0.6)
    sc.text('g', 1.5)
    sc.text('0' + bs + 'r', 4.0)
    sc.dump('s3_back0')
    tcl = os.path.join(BUILD, 'eseg.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('s') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    subprocess.run([OPENMSX, '-machine', MACHINE, '-diska', d, '-script', tcl], timeout=600)
    print('--- s1 Segment 1: salva FAUST000 e apre FAUST001')
    saved = open(os.path.join(d, 'FAUST000.SPB'), 'rb').read()
    check(saved.startswith(b'XREM main'), 'FAUST000.SPB salvato con la modifica: %r' % saved[:12])
    rows, vs, bl = load('s1_seg1')
    check('Loaded' in txt(rows, 0), 'FAUST001 caricato: ' + txt(rows, 0)[:50])
    check(txt(rows, 1).startswith('SUB uno'), 'contenuto: ' + txt(rows, 1)[:12])
    print('--- s2 Segment 007 (manca): messaggio, il file corrente resta')
    rows, vs, bl = load('s2_new7')
    check('does not exist' in txt(rows, 0), 'messaggio: ' + txt(rows, 0)[:50])
    check(txt(rows, 1).startswith('SUB uno'), 'il file attivo e ancora FAUST001: ' + txt(rows, 1)[:12])
    print('--- s2b Segment 3 (.BIN): non si apre')
    rows, vs, bl = load('s2b_bin')
    check('BIN' in txt(rows, 0) and 'cannot' in txt(rows, 0), 'messaggio: ' + txt(rows, 0)[:50])
    check(txt(rows, 1).startswith('SUB uno'), 'il file attivo non cambia: ' + txt(rows, 1)[:12])
    print('--- s3 Segment 0: torna al principale')
    rows, vs, bl = load('s3_back0')
    check(txt(rows, 1).startswith('XREM main'), 'FAUST000 riaperto: ' + txt(rows, 1)[:12])
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
