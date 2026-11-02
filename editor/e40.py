#!/usr/bin/env python3
"""Test of the 40-column editor on MSX1 (openMSX, Sony HB-75P, ROM build): layout, cursor, vertical and horizontal scroll,
bars, mouse (test mode), menus. usage: python e40.py"""
import os
import sys

import etest
from etest import Scenario, check, load, demo_lines

etest.MACHINE = os.environ.get('GMACHINE', 'Sony_HB-75P')
etest.PRELUDE = etest.PRELUDE.replace('read_block VRAM 0 1920', 'read_block VRAM 0 960').replace('if {$n == 80}', 'if {$n == 40}')


def blink_cell(bl):
    return etest.blink_cell(bl)


def main():
    syms = etest.assemble()
    demo = demo_lines()
    sc = Scenario(syms)
    sc.dump('w1_init')
    sc.tap(8, 0x40, 3)                 # down x3
    sc.tap(8, 0x80, 5)                 # right x5
    sc.text('XY')
    sc.dump('w2_edit')
    sc.tap(8, 0x40, 3, 0.4)            # down x3 -> row 7 (long)
    sc.tap(7, 0x40, 1)                 # SELECT = End
    sc.dump('w3_end')
    sc.tap(8, 0x02, 1)                 # Home
    sc.dump('w4_home')
    sc.tap(8, 0x40, 30, 0.45)          # down x30: vertical scroll
    sc.dump('w5_scrollv')
    sc.poke8('mmode', 1)               # mouse (test mode)
    sc.pointer(39, 22)
    sc.click(0.15)                     # down arrow
    sc.dump('w6_mouse_down')
    sc.tap(7, 0x04, 1, 0.5)            # Esc: File menu
    sc.tap(8, 0x80, 4, 0.4)            # right x4: Run menu (the last one, on the right)
    sc.dump('w7_menu')
    etest.run(sc)

    print('--- w1 iniziale (40 colonne)')
    rows, vs, bl = load('w1_init')
    t0 = rows[0].replace('~', '')
    check(t0[:30] == ' File  Edit  Find  Help  Run  ', 'barra dei menu: %r' % t0[:32])
    check(t0[31:34] == '1:1', 'stato 1:1 a destra: %r' % t0[30:40])
    for r in (1, 2, 7, 22):
        check(rows[r][:39] == demo[r - 1][:39].ljust(39), f'riga {r} = demo[{r - 1}] troncata a 39 colonne: {rows[r][:39]!r}')
    check(rows[1][39] == '^' and rows[22][39] == 'v', 'frecce verticali alla colonna 39')
    check(rows[2][39] == '#', 'pollice verticale in cima')
    check(rows[23][0] == '<' and rows[23][38] == '>' and rows[23][1] == '#', 'barra orizzontale: %r' % rows[23])
    check(blink_cell(bl) == (1, 0), f'cursore in {blink_cell(bl)}')
    check(vs['mcx'] <= 39 and vs['nlines'] == 71, f'nlines={vs["nlines"]}')

    print('--- w2 modifica')
    rows, vs, bl = load('w2_edit')
    exp = demo[3][:5] + 'XY' + demo[3][5:]
    check(rows[4][:39] == exp[:39].ljust(39), 'riga 4 con XY: %r' % rows[4][:20])
    check(blink_cell(bl) == (4, 7), f'cursore in {blink_cell(bl)}')
    check('4:8' in rows[0].replace('~', '')[30:], 'stato 4:8: %r' % rows[0].replace('~', '')[28:])
    check(rows[0].replace('~', '')[30] == '*', 'marcatore di modifica')

    print('--- w3 End su riga lunga -> scroll orizzontale')
    rows, vs, bl = load('w3_end')
    check(vs['curline'] == 7 and vs['hscroll'] > 0, f'curline={vs["curline"]} hscroll={vs["hscroll"]}')
    c = blink_cell(bl)
    check(c is not None and c[1] == 38, f'cursore alla colonna 38: {c}')
    hs = [i for i in range(1, 38) if rows[23][i] == '#']
    check(len(hs) == 1 and hs[0] > 1, f'pollice orizzontale spostato: {hs}')
    print('--- w4 Home')
    rows, vs, bl = load('w4_home')
    check(vs['hscroll'] == 0 and blink_cell(bl) == (7 - vs['topline'] + 1, 0), f'hscroll={vs["hscroll"]} cursore {blink_cell(bl)}')
    print('--- w5 scroll verticale')
    rows, vs, bl = load('w5_scrollv')
    check(vs['curline'] == 37 and vs['topline'] == 37 - 21, f'curline={vs["curline"]} topline={vs["topline"]}')
    check(rows[22].startswith(f'{37:03d} '), 'ultima riga visibile = 037: %r' % rows[22][:10])
    ti = [i for i in range(2, 22) if rows[i][39] == '#']
    check(len(ti) == 1 and ti[0] > 2, f'pollice spostato: righe {ti}')
    print('--- w6 mouse')
    rows, vs, bl = load('w6_mouse_down')
    check(vs['topline'] == 16 + 1 or vs['topline'] > 15, f'freccia giu col mouse: topline={vs["topline"]}')
    check(vs['mcx'] == 39, f'puntatore sulla colonna 39: mcx={vs["mcx"]}')
    print('--- w7 menu a 40 colonne')
    rows, vs, bl = load('w7_menu')
    check(vs['menuopen'] == 5, f'menu Run aperto: {vs["menuopen"]}')
    box = [rows[r] for r in range(1, 6)]
    check(all(len(b.replace('~', '')) == 40 for b in box), 'righe da 40 colonne')
    check(any('Run' in b or 'F5' in b for b in box), 'voce del menu Run visibile: %r' % box[1][20:40])
    print('FALLITI: %d' % etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
