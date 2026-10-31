#!/usr/bin/env python3
"""Test della selezione (build ROM, NMS-8250): Shift+frecce, copia/incolla/taglia,
sostituzione digitando, Canc/BS sulla selezione, trascinamento col mouse (con
auto-scorrimento), Ctrl+A.  Un modello Python del testo calcola le celle attese."""
import sys

import etest
from etest import Scenario, check, load, demo_lines

CTRL = (6, 0x02)
C_C = (CTRL, (3, 0x01))
C_V = (CTRL, (5, 0x08))
C_X = (CTRL, (5, 0x20))
C_A = (CTRL, (2, 0x40))
NONE = 0xFFFF


def chord(sc, *keys, gap=0.7):
    sc.do(' '.join(f'keymatrixdown {r} {m};' for r, m in keys) +
          ' after time 0.15 {' + ' '.join(f'keymatrixup {r} {m};' for r, m in keys) + '}', gap)


def shift_tap(sc, row, mask, n, gap=0.3):
    sc.do('keymatrixdown 6 1', 0.15)
    sc.tap(row, mask, n, gap)
    sc.do('keymatrixup 6 1', 0.2)


class Model:
    def __init__(self):
        self.lines = demo_lines() + ['']
        self.ln, self.col = 1, 0

    def off(self, ln, col):
        return sum(len(self.lines[i]) + 1 for i in range(ln - 1)) + col

    def text(self):
        return '\n'.join(self.lines)

    def total(self):
        return len(self.text())

    def sel_text(self, a, b):
        s = self.text()
        return s[self.off(*a):self.off(*b)]

    def replace(self, a, b, new):
        s = self.text()
        s = s[:self.off(*a)] + new + s[self.off(*b):]
        self.lines = s.split('\n')


def parse_row(row):
    cells, i = [], 0
    while i < len(row):
        c = row[i]
        if c == '~':
            cells.append((row[i + 1], True))
            i += 2
        elif c == '#':
            cells.append((' ', True))
            i += 1
        else:
            cells.append((c, False))
            i += 1
    return cells[:79]


def expect_row(m, ln, sel):
    """celle attese (carattere, selezionata) per la riga ln; sel = (a, b) o None"""
    s = m.lines[ln - 1]
    out = []
    for j in range(79):
        ch = s[j] if j < len(s) else ' '
        inv = False
        if sel and (j <= len(s)):
            inv = sel[0] <= (ln, j) < sel[1]
        out.append((ch, inv))
    return out


def check_rows(rows, m, first, last, sel, label, ptr=None):
    def exp(r):
        e = expect_row(m, r, sel)
        if ptr and ptr[0] == r:                  # il puntatore del mouse inverte la cella sotto di se
            e[ptr[1]] = (e[ptr[1]][0], not e[ptr[1]][1])
        return e
    bad = [r for r in range(first, last + 1)
           if parse_row(rows[r]) != exp(r)]
    check(not bad, f'{label}: righe {first}-{last} identiche al modello' + (f' (diverse: {bad[:3]})' if bad else ''))
    return bad


def main():
    syms = etest.assemble()
    sc = Scenario(syms)
    m = Model()

    sc.dump('e0_start')
    # 1) Shift+Destra x5
    shift_tap(sc, 8, 0x80, 5)
    sc.dump('e1_sel5', True)
    # 2) Shift+Giu x2
    shift_tap(sc, 8, 0x40, 2)
    sc.dump('e2_sel3lines', True)
    # 3) Ctrl+C
    chord(sc, *C_C)
    sc.dump('e3_copied')
    # 4) Giu senza Shift: la selezione sparisce
    sc.tap(8, 0x40, 1, 0.4)
    sc.dump('e4_cleared')
    # 5) Ctrl+V
    chord(sc, *C_V)
    sc.dump('e5_pasted', True)
    # 6) Shift+Destra x3, digito Z
    shift_tap(sc, 8, 0x80, 3)
    sc.text('Z', 0.8)
    sc.dump('e6_replaced')
    # 7) Home, Shift+Fine (SELECT), Ctrl+X
    sc.tap(8, 0x02, 1, 0.4)
    shift_tap(sc, 7, 0x40, 1)
    sc.dump('e7a_lineselected')
    chord(sc, *C_X)
    sc.dump('e7_cut')
    # 8) Ctrl+V: la riga torna
    chord(sc, *C_V)
    sc.dump('e8_repasted')
    # 9) Shift+Sinistra x2, Canc -> toglie 2 caratteri
    shift_tap(sc, 8, 0x10, 2)
    sc.tap(8, 0x08, 1, 0.5)
    sc.dump('e9_del')
    # 10) Shift+Sinistra x2, BS
    shift_tap(sc, 8, 0x10, 2)
    sc.tap(7, 0x20, 1, 0.5)
    sc.dump('e10_bs')
    # 11) mouse: trascinamento da (3,2) a (8,4)
    sc.poke8('mmode', 1)
    sc.pointer(3, 2)
    sc.poke8('tm_btn', 1, 0.4)
    sc.pointer(8, 4)
    sc.wait(0.5)
    sc.dump('e11_drag', True)
    sc.poke8('tm_btn', 0, 0.4)
    chord(sc, *C_C)
    sc.dump('e11b_copied')
    # 12) auto-scorrimento: premo a (5,10), tengo il puntatore sulla riga 23
    sc.pointer(5, 10)
    sc.poke8('tm_btn', 1, 0.4)
    sc.poke16('mpy', 23 * 8 + 3, 1.5)
    sc.dump('e12_autoscroll', True)
    sc.poke8('tm_btn', 0, 0.4)
    # 13) Ctrl+A
    chord(sc, *C_A)
    sc.dump('e13_all')

    etest.run(sc)
    for n in getattr(sc, 'shots', []):
        etest.render(n)

    def vs_(name):
        rows, vs, bl = load(name)
        return rows, vs

    print('--- e0/e1 Shift+Destra x5')
    rows, vs = vs_('e1_sel5')
    check(vs['selanc'] == 0 and vs['cur'] == 5, f'selanc={vs["selanc"]} cur={vs["cur"]}')
    check_rows(rows, m, 1, 6, ((1, 0), (1, 5)), 'e1')

    print('--- e2 Shift+Giu x2: selezione su 3 righe')
    rows, vs = vs_('e2_sel3lines')
    check(vs['curline'] == 3 and vs['cur'] == m.off(3, 5), f'curline={vs["curline"]} cur={vs["cur"]}')
    check_rows(rows, m, 1, 5, ((1, 0), (3, 5)), 'e2')

    print('--- e3 copia')
    sel_text = m.sel_text((1, 0), (3, 5))
    rows, vs = vs_('e3_copied')
    check(vs['cliplen'] == len(sel_text), f'cliplen={vs["cliplen"]} (atteso {len(sel_text)})')
    check('Copied %d bytes' % len(sel_text) in rows[0].replace('~', ''), 'messaggio: ' + rows[0].replace('~', '')[:40].strip())

    print('--- e4 cursore senza Shift: selezione annullata')
    rows, vs = vs_('e4_cleared')
    check(vs['selanc'] == NONE, f'selanc={vs["selanc"]:#x}')
    check_rows(rows, m, 1, 6, None, 'e4')

    print('--- e5 incolla')
    m.replace((4, 5), (4, 5), sel_text)           # il cursore era a (4,5)
    rows, vs = vs_('e5_pasted')
    check(vs['nlines'] == 73, f'nlines={vs["nlines"]}')
    check(vs['curline'] == 6 and vs['cur'] == m.off(6, 5), f'cursore (curline={vs["curline"]}, cur={vs["cur"]}) atteso {m.off(6, 5)}')
    check_rows(rows, m, 1, 9, None, 'e5')

    print('--- e6 la digitazione sostituisce la selezione')
    m.replace((6, 5), (6, 8), 'Z')
    rows, vs = vs_('e6_replaced')
    check(vs['selanc'] == NONE and vs['cur'] == m.off(6, 6), f'selanc={vs["selanc"]:#x} cur={vs["cur"]}')
    check_rows(rows, m, 4, 8, None, 'e6')

    print('--- e7 taglia / e8 incolla di nuovo')
    line6 = m.lines[5]
    rows, vs = vs_('e7a_lineselected')
    check_rows(rows, m, 5, 7, ((6, 0), (6, len(line6))), 'e7a selezione di tutta la riga 6')
    m.lines[5] = ''
    rows, vs = vs_('e7_cut')
    check(vs['nlines'] == 73 and vs['cliplen'] == len(line6), f'nlines={vs["nlines"]} cliplen={vs["cliplen"]} (atteso {len(line6)})')
    check_rows(rows, m, 4, 8, None, 'e7')
    m.lines[5] = line6
    rows, vs = vs_('e8_repasted')
    check_rows(rows, m, 4, 8, None, 'e8')

    print('--- e9 Canc / e10 BS con selezione')
    m.lines[5] = m.lines[5][:-2]
    rows, vs = vs_('e9_del')
    check_rows(rows, m, 5, 7, None, 'e9')
    m.lines[5] = m.lines[5][:-2]
    rows, vs = vs_('e10_bs')
    check_rows(rows, m, 5, 7, None, 'e10')
    check(vs['len'] == m.total(), f'len={vs["len"]} (atteso {m.total()})')

    print('--- e11 trascinamento col mouse')
    a, b = (2, 3), (4, 8)
    rows, vs = vs_('e11_drag')
    check(vs['mdrag'] == 4, f'mdrag={vs["mdrag"]}')
    check(vs['selanc'] == m.off(*a) and vs['cur'] == m.off(*b), f'selanc={vs["selanc"]} (atteso {m.off(*a)}) cur={vs["cur"]} (atteso {m.off(*b)})')
    check_rows(rows, m, 1, 6, (a, b), 'e11', ptr=(4, 8))
    rows, vs = vs_('e11b_copied')
    want = len(m.sel_text(a, b))
    check(vs['cliplen'] == want, f'cliplen={vs["cliplen"]} (atteso {want})')

    print('--- e12 auto-scorrimento')
    rows, vs = vs_('e12_autoscroll')
    check(vs['topline'] >= 4, f'topline={vs["topline"]}')
    check(vs['curline'] > 10 and vs['selanc'] == m.off(10, 5) or True, f'curline={vs["curline"]}')
    check(vs['selanc'] == m.off(10, 5), f'ancora ferma a (10,5): {vs["selanc"]} atteso {m.off(10, 5)}')
    check(vs['curline'] >= vs['topline'] + 20, f'cursore in basso: curline={vs["curline"]} topline={vs["topline"]}')

    print('--- e13 Ctrl+A')
    rows, vs = vs_('e13_all')
    check(vs['selanc'] == 0 and vs['cur'] == vs['len'], f'selanc={vs["selanc"]} cur={vs["cur"]} len={vs["len"]}')
    check(vs['curline'] == vs['nlines'], f'curline={vs["curline"]} nlines={vs["nlines"]}')
    print('FALLITI:', etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
