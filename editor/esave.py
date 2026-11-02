#!/usr/bin/env python3
"""In-place save (.COM, MS-DOS 1): a longer file is overwritten without deleting it; if the new text is shorter
^Z is written after the text and the rest of the file is ignored (the editor ignores it on load)."""
import os
import sys

import etest
import ecom
from ecom import chord, CTRL_S, CTRL_O, title
from etest import Scenario, check, load, BUILD


BS = chr(92)


def main():
    ecom.prepare_disk()
    syms = ecom.assemble_com()
    sc = Scenario(syms)
    sc.t = 20.0
    sc.text('ED HELLO.SPB' + BS + 'r', 8.0)
    sc.text('ABCDEFGHIJ', 1.0)
    chord(sc, *CTRL_S, gap=5.0)                       # longer: extended in place
    sc.dump('v0_longer')
    sc.tap(7, 0x20, 10, 0.4)                          # Backspace x10
    chord(sc, *CTRL_S, gap=5.0)                       # shorter: ^Z + leftover
    sc.dump('v1_shorter')
    chord(sc, *CTRL_O, gap=0.8)
    sc.text('H', 0.5)
    sc.tap(7, 0x80, 1, 5.0)
    sc.dump('v2_reloaded')
    tcl = os.path.join(BUILD, 'esave.tcl')
    open(tcl, 'w').write(sc.script())
    for f in os.listdir(BUILD):
        if f.startswith('v') and f[1:2].isdigit() and f.endswith('.txt'):
            os.remove(os.path.join(BUILD, f))
    import subprocess
    subprocess.run([etest.OPENMSX, '-machine', etest.MACHINE, '-diska', ecom.DISK, '-script', tcl], timeout=600)
    data = open(os.path.join(ecom.DISK, 'HELLO.SPB'), 'rb').read()
    exp = b'Hello MSX\r\n    indented line\r\nthird line\r\n'
    rows, vs, bl = load('v0_longer')
    check('Saved' in title(rows), 'primo salvataggio: ' + title(rows)[:40].strip())
    rows, vs, bl = load('v1_shorter')
    check('Saved' in title(rows), 'secondo salvataggio: ' + title(rows)[:40].strip())
    check(data.startswith(exp + b'\x1a') and len(data) == len(exp) + 10, f'file su disco: testo + ^Z + residuo ({len(data)} byte, ^Z in {data.find(bytes([26]))})')
    rows, vs, bl = load('v2_reloaded')
    check(rows[1][:9] == 'Hello MSX' and rows[3][:10] == 'third line' and rows[4][:78].strip() == '', f'ricaricato senza residuo: {rows[1][:12]!r} {rows[4][:12]!r}')
    check(vs['len'] == 39, f'len={vs["len"]}')
    print('FALLITI:', etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
