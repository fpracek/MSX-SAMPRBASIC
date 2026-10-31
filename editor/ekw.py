#!/usr/bin/env python3
"""Test dei colori delle parole chiave (build ROM, NMS-8250): scrive del BASIC, aspetta i tempi morti e
confronta i flag della tabella di blink (VRAM 800h, 10 byte per riga) con un modello Python."""
import os
import re
import sys

import etest
from etest import Scenario, check, BUILD

HERE = os.path.dirname(os.path.abspath(__file__))
WORDS = set(re.findall(r'"([A-Z0-9_$]+)"', open(os.path.join(HERE, 'kwtab.inc')).read()))
LINES = [
    'PRINT "FOR" : FOR I=1 TO 10',
    'rem FOR NEXT PRINT',
    'print chr$(65); fortune; mid$(a$,1)',
    "IF x THEN GOTO 10 ' PRINT",
    'x=1:y=2:locate 1,2:__asm',
    'a1 = abcdefghijkl + 2PRINT + vpoke',
]


def model(text):
    """flag di colore per una riga (79 colonne) come li calcola l'editor"""
    flags = [0] * 79
    text = text[:79].ljust(79)
    q = False
    i = 0
    while i < 79:
        ch = text[i]
        if ch == '"':
            q = not q
            i += 1
        elif ch == "'":
            break
        elif re.match(r'[A-Za-z0-9_$]', ch):
            j = i
            while j < 79 and re.match(r'[A-Za-z0-9_$]', text[j]):
                j += 1
            w = text[i:j]
            if not q and 2 <= len(w) <= 10 and not re.match(r'[0-9$]', w[0]) and w.upper() in WORDS:
                for k in range(i, j):
                    flags[k] = 1
                if w.upper() == 'REM':
                    break
            i = j
        else:
            i += 1
    return flags


def main():
    syms = etest.assemble()
    sc = Scenario(syms)
    sc.dump('k0_init')
    for ln in LINES:
        sc.do('type "%s\\r"' % ln.replace('"', '\\"').replace('$', '\\$'), 0.2)
    sc.wait(sum(len(x) + 1 for x in LINES) * 0.5 + 4.0)   # la digitazione e' lenta; poi i tempi morti (2 righe per quadro)
    sc.dump('k1_typed')
    sc.tap(8, 0x20, 3, 0.4)              # Su x3 (scorre, ridisegna)
    sc.wait(2.0)
    sc.dump('k2_up')
    etest.run(sc)
    for name in ('k1_typed', 'k2_up'):
        print('---', name)
        rows = {}
        bl = {}
        for ln in open(os.path.join(BUILD, name + '.txt'), encoding='latin-1'):
            p = ln.rstrip('\n').split(' ', 2)
            if p[0] == 'ROW':
                rows[int(p[1])] = p[2].replace('~', '')
            elif p[0] == 'BLINK':
                q = ln.split()
                bl[(int(q[1]), int(q[2]))] = int(q[3])
        bad = []
        for r in range(1, 23):
            exp = model(rows[r][:79])
            got = [1 if bl.get((r, (c // 8) * 8), 0) & (0x80 >> (c % 8)) else 0 for c in range(79)]
            if exp != got:
                bad.append(r)
                print('   riga %d: %r' % (r, rows[r][:60]))
                print('     exp', ''.join('K' if x else '.' for x in exp[:60]))
                print('     got', ''.join('K' if x else '.' for x in got[:60]))
        check(not bad, f'{name}: colori delle 22 righe uguali al modello (errate: {bad})')
        if name == 'k1_typed':
            check(any(model(rows[r]).count(1) for r in range(1, 7)), 'nelle righe scritte ci sono parole chiave colorate')
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
