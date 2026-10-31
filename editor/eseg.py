#!/usr/bin/env python3
"""File > Segment... (F8): salva il file corrente e apre NOMEnnn nella stessa directory (build .COM, MSX-DOS 1 su NMS-8250)."""
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
    syms = ecom.assemble_com()
    sc = Scenario(syms)
    sc.t = 20.0
    bs = chr(92)
    sc.text('ED FAUST000' + bs + 'r', 8.0)
    sc.text('X', 0.5)                                   # modifica: Segment deve salvare prima di cambiare
    sc.tap(*ESC, 1, 0.6)
    sc.text('g', 1.5)
    sc.text('1' + bs + 'r', 5.0)
    sc.dump('s1_seg1')
    sc.tap(*ESC, 1, 0.6)
    sc.text('g', 1.5)
    sc.text('007' + bs + 'r', 4.0)
    sc.dump('s2_new7')
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
    print('--- s2 Segment 007 (manca): file nuovo con il nome')
    rows, vs, bl = load('s2_new7')
    check('not found' in txt(rows, 0).lower() or 'new file' in txt(rows, 0).lower(), 'nuovo: ' + txt(rows, 0)[:50])
    print('--- s3 Segment 0: torna al principale')
    rows, vs, bl = load('s3_back0')
    check(txt(rows, 1).startswith('XREM main'), 'FAUST000 riaperto: ' + txt(rows, 1)[:12])
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
