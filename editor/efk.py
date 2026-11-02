#!/usr/bin/env python3
"""Keys F1-F4 for the menus (ROM build, NMS-8250): F1 File, F2 Edit, F3 Find, F4 Help; with a menu open they switch to the chosen menu; Esc closes."""
import sys
import etest
from etest import Scenario, check, load

F = {1: (6, 0x20), 2: (6, 0x40), 3: (6, 0x80), 4: (7, 0x01)}


def main():
    syms = etest.assemble()
    sc = Scenario(syms)
    for k in (1, 2, 4):
        sc.tap(F[k][0], F[k][1], 1, 0.6)
        sc.dump('f%d' % k)
        sc.tap(7, 0x04, 1, 0.6)                 # Esc
    sc.tap(*F[2], 1, 0.6)                       # F2 opens Edit
    sc.tap(*F[3], 1, 0.6)                       # with the menu open F3 switches to Find
    sc.dump('f2_3')
    sc.tap(7, 0x04, 1, 0.6)
    sc.dump('f_closed')
    etest.run(sc)
    for k, want in ((1, 1), (2, 2), (4, 4)):
        rows, vs, bl = load('f%d' % k)
        check(vs['menuopen'] == want, f'F{k} apre il menu {want}: menuopen={vs["menuopen"]}')
    rows, vs, bl = load('f2_3')
    check(vs['menuopen'] == 3, f'F3 con il menu Edit aperto passa a Find: menuopen={vs["menuopen"]}')
    rows, vs, bl = load('f_closed')
    check(vs['menuopen'] == 0, 'Esc chiude il menu')
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
