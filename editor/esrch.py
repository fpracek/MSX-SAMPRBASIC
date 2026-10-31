#!/usr/bin/env python3
"""Test di cerca / sostituisci (build ROM, NMS-8250): Ctrl+F, Ctrl+G (con giro intorno al testo),
maiuscole/minuscole dal menu, termine precedente riusato, Ctrl+T con conferma (Y/N/A),
sostituzione con testo vuoto, voci del menu Find."""
import sys

import etest
from esel import Model, parse_row, expect_row
from etest import Scenario, check, load

CTRL = (6, 0x02)
CTRL_F = (CTRL, (3, 0x08))
CTRL_G = (CTRL, (3, 0x10))
CTRL_T = (CTRL, (5, 0x02))
ESC = (7, 0x04)
RIGHT = (8, 0x80)
BS = (7, 0x20)


def chord(sc, *keys, gap=0.8):
    sc.do(' '.join(f'keymatrixdown {r} {m};' for r, m in keys) +
          ' after time 0.15 {' + ' '.join(f'keymatrixup {r} {m};' for r, m in keys) + '}', gap)


def bs(sc, n):
    sc.tap(BS[0], BS[1], n, 0.25)


def pos(m, off):
    for ln, s in enumerate(m.lines, 1):
        if off <= len(s):
            return ln, off
        off -= len(s) + 1
    raise ValueError(off)


def find_from(m, term, start, insens=True):
    """prossima occorrenza da start con giro intorno (come il programma: il giro cerca solo
    corrispondenze che finiscono prima del cursore). -> (offset, girato)"""
    text, t = m.text(), term
    if insens:
        text, t = text.lower(), term.lower()
    i = text.find(t, start)
    if i >= 0:
        return i, False
    i = text.find(t, 0)
    if 0 <= i and i + len(t) <= start:
        return i, True
    return None, False


def check_view(rows, m, topline, sel, label, first=1, last=22):
    bad = []
    for r in range(first, last + 1):
        ln = topline + r - 1
        exp = expect_row(m, ln, sel) if ln <= len(m.lines) else [(' ', False)] * 79
        if parse_row(rows[r]) != exp:
            bad.append(r)
    check(not bad, f'{label}: righe {first}-{last} (da riga {topline}) identiche al modello'
          + (f' (diverse: {bad[:3]})' if bad else ''))


def msg(rows):
    return rows[0].replace('~', '')[25:80].strip()


def main():
    syms = etest.assemble()
    sc = Scenario(syms)
    m = Model()
    NUM = 'numero 3'

    # ---- Ctrl+F: prompt e prima ricerca
    chord(sc, *CTRL_F)
    sc.dump('f1_prompt')
    sc.text(NUM + '\\r', 1.5)
    sc.dump('f2_found', True)
    chord(sc, *CTRL_G)
    sc.dump('f3_next', True)
    for _ in range(9):
        chord(sc, *CTRL_G, gap=0.6)
    sc.dump('f4_line39')
    chord(sc, *CTRL_G)
    sc.dump('f5_wrap')
    # ---- maiuscole/minuscole ignorate: "NUMERO 5"
    chord(sc, *CTRL_F)
    sc.dump('f5b_prefilled')
    bs(sc, 8)
    sc.text('NUMERO 5\\r', 1.5)
    sc.dump('f6_case')
    # ---- menu Find > Match case
    sc.tap(*ESC, 1, 0.4)
    sc.tap(*RIGHT, 2, 0.4)
    sc.text('m', 0.8)
    sc.dump('f7_toggle')
    chord(sc, *CTRL_F)                  # termine precedente gia' scritto: Invio subito
    sc.text('\\r', 1.2)
    sc.dump('f8_notfound')
    sc.tap(*ESC, 1, 0.4)
    sc.tap(*RIGHT, 2, 0.4)
    sc.text('m', 0.8)                   # di nuovo senza distinzione
    chord(sc, *CTRL_F)
    sc.text('\\r', 1.5)
    sc.dump('f9_reuse')
    # ---- torno in cima cercando "001 riga" (gira intorno)
    chord(sc, *CTRL_F)
    bs(sc, 8)
    sc.text('001 riga\\r', 1.5)
    sc.dump('f10_top')
    # ---- Ctrl+T: sostituisci "riga" con "ROW", con conferma
    chord(sc, *CTRL_T)
    bs(sc, 8)
    sc.text('riga\\r', 0.8)
    sc.text('ROW\\r', 1.5)
    sc.dump('f11_ask1', True)
    sc.text('y', 1.2)
    sc.dump('f12_ask2')
    sc.text('n', 1.2)
    sc.text('y', 1.2)
    sc.dump('f12b_ask5')
    sc.text('a', 6.0)
    sc.dump('f13_done', True)
    # ---- "ROW" -> testo vuoto, da cima
    chord(sc, *CTRL_F)
    bs(sc, 4)                           # cancella 'riga'
    sc.text('001 \\r', 1.5)
    sc.dump('f14_top')
    chord(sc, *CTRL_T)
    bs(sc, 4)
    sc.text('ROW\\r', 0.8)
    bs(sc, 3)
    sc.text('\\r', 1.5)                 # sostituzione vuota
    sc.text('a', 6.0)
    sc.dump('f15_empty')
    # ---- Find... dal menu
    sc.tap(*ESC, 1, 0.4)
    sc.tap(*RIGHT, 2, 0.4)
    sc.text('f', 1.0)
    sc.dump('f16_menu_prompt')
    sc.tap(*ESC, 1, 0.6)

    etest.run(sc)
    for n in getattr(sc, 'shots', []):
        etest.render(n)

    def L(name):
        rows, vs, bl = load(name)
        return rows, vs

    print('--- f1 prompt')
    rows, vs = L('f1_prompt')
    check(rows[0].replace('~', '').startswith('Find: _') or 'Find: _' in rows[0].replace('~', ''), 'prompt: ' + rows[0].replace('~', '')[:20])

    print('--- f2 prima ricerca')
    off, _ = find_from(m, NUM, 0)
    (ln, col) = pos(m, off)
    rows, vs = L('f2_found')
    check(vs['selanc'] == off and vs['cur'] == off + 8, f'selanc={vs["selanc"]} cur={vs["cur"]} (atteso {off}, {off + 8}) riga {ln} col {col}')
    check(vs['curline'] == ln, f'curline={vs["curline"]}')
    check_view(rows, m, vs['topline'], ((ln, col), (ln, col + 8)), 'f2', 1, 6)

    print('--- f3 Ctrl+G: prossima occorrenza, riga centrata')
    cur = off + 8
    off2, w = find_from(m, NUM, cur)
    ln2, col2 = pos(m, off2)
    rows, vs = L('f3_next')
    check(vs['cur'] == off2 + 8 and vs['curline'] == ln2, f'cur={vs["cur"]} (atteso {off2 + 8}) curline={vs["curline"]} (atteso {ln2})')
    check(vs['topline'] == ln2 - 11, f'riga centrata: topline={vs["topline"]} (atteso {ln2 - 11})')
    check_view(rows, m, vs['topline'], ((ln2, col2), (ln2, col2 + 8)), 'f3 vista centrata')

    print('--- f4/f5 pressioni ripetute di Ctrl+G e giro intorno')
    cur = off2 + 8
    states = []
    for _ in range(10):
        o, w = find_from(m, NUM, cur)
        states.append((o, w))
        cur = o + 8
    o9, w9 = states[8]
    rows, vs = L('f4_line39')
    check(vs['cur'] == o9 + 8 and vs['curline'] == pos(m, o9)[0], f'dopo 9 pressioni: curline={vs["curline"]} (atteso {pos(m, o9)[0]}, girato={w9})')
    check(w9 == ('wrapped' in msg(rows)), 'messaggio di giro coerente con il modello: ' + msg(rows))
    o10, w10 = states[9]
    rows, vs = L('f5_wrap')
    check(vs['cur'] == o10 + 8 and vs['curline'] == pos(m, o10)[0], f'decima pressione: curline={vs["curline"]} (atteso {pos(m, o10)[0]})')
    check(any(w for _, w in states[:9]) or w10, 'il giro intorno e\' avvenuto')
    cur = o10 + 8
    # dopo il giro il cursore e' a riga 3; il file demo salta la riga 35 (cifre soltanto)
    check(not any('numero' in m.lines[34] for _ in [0]), 'riga 35 senza "numero" (spiega il giro alla nona pressione)')
    print('--- f5b/f6 ricerca senza distinzione di maiuscole')
    rows, vs = L('f5b_prefilled')
    check('Find: numero 3_' in rows[0].replace('~', ''), 'termine precedente precaricato: ' + rows[0].replace('~', '')[:24])
    o, w = find_from(m, 'NUMERO 5', cur)
    rows, vs = L('f6_case')
    check(vs['cur'] == o + 8 and vs['selanc'] == o, f'cur={vs["cur"]} (atteso {o + 8}) selanc={vs["selanc"]}')
    cur = o + 8

    print('--- f7/f8 Match case acceso: "NUMERO 5" non si trova')
    rows, vs = L('f7_toggle')
    check(vs['mcase'] == 1 and vs['menuopen'] == 0, f'mcase={vs["mcase"]}')
    rows, vs = L('f8_notfound')
    check('not found' in msg(rows), 'messaggio: ' + msg(rows))
    check(vs['cur'] == cur, f'cursore invariato: {vs["cur"]}')

    print('--- f9 termine riusato con Invio, di nuovo senza distinzione')
    o, w = find_from(m, 'NUMERO 5', cur)
    rows, vs = L('f9_reuse')
    check(vs['mcase'] == 0 and vs['cur'] == o + 8, f'mcase={vs["mcase"]} cur={vs["cur"]} (atteso {o + 8})')
    cur = o + 8

    print('--- f10 torno in cima')
    o, w = find_from(m, '001 riga', cur)
    rows, vs = L('f10_top')
    check(o == 0 and vs['selanc'] == 0 and vs['cur'] == 8 and vs['curline'] == 1, f'selanc={vs["selanc"]} cur={vs["cur"]} curline={vs["curline"]}')
    cur = 8

    print('--- f11-f13 sostituzione con conferma')
    rows, vs = L('f11_ask1')
    check('Replace?' in rows[0].replace('~', ''), 'richiesta di conferma: ' + rows[0].replace('~', '')[:30])
    o1, _ = find_from(m, 'riga', cur)
    (l1, c1) = pos(m, o1)
    check(l1 == 2 and vs['selanc'] == o1 and vs['cur'] == o1 + 4, f'prima corrispondenza: riga {l1} selanc={vs["selanc"]} cur={vs["cur"]}')
    check_view(rows, m, vs['topline'], ((l1, c1), (l1, c1 + 4)), 'f11', 1, 4)
    # modello: y su riga 2, n su riga 3, y su riga 4, a dalla riga 5
    count = 0
    for ln in range(2, 71):
        s = m.lines[ln - 1]
        if 'riga' not in s:
            continue
        if ln == 3:
            continue
        m.lines[ln - 1] = s.replace('riga', 'ROW', 1)
        count += 1
    rows, vs = L('f12_ask2')
    check('Replace?' in rows[0].replace('~', ''), 'seconda richiesta')
    check(vs['curline'] == 3, f'seconda corrispondenza alla riga 3: curline={vs["curline"]}')
    rows, vs = L('f12b_ask5')
    check(vs['curline'] == 5, f'dopo y/n/y: terza richiesta alla riga 5: curline={vs["curline"]}')
    rows, vs = L('f13_done')
    check(f'Replaced {count} occurrence(s)' == msg(rows), f'messaggio: {msg(rows)!r} (attesi {count})')
    check(vs['len'] == m.total() and vs['nlines'] == 71, f'len={vs["len"]} (atteso {m.total()}) nlines={vs["nlines"]}')
    check_view(rows, m, vs['topline'], None, 'f13')
    check(vs['selanc'] == 0xFFFF, 'selezione annullata')

    print('--- f14/f15 sostituzione con testo vuoto')
    rows, vs = L('f14_top')
    check(vs['selanc'] == 0 and vs['cur'] == 4, f'selanc={vs["selanc"]} cur={vs["cur"]}')
    count2 = 0
    for ln in range(2, 71):
        s = m.lines[ln - 1]
        if 'ROW' in s:
            m.lines[ln - 1] = s.replace('ROW', '', 1)
            count2 += 1
    rows, vs = L('f15_empty')
    check(f'Replaced {count2} occurrence(s)' == msg(rows), f'messaggio: {msg(rows)!r} (attesi {count2})')
    check(vs['len'] == m.total(), f'len={vs["len"]} (atteso {m.total()})')
    check_view(rows, m, vs['topline'], None, 'f15')

    print('--- f16 Find... dal menu')
    rows, vs = L('f16_menu_prompt')
    check('Find: ROW_' in rows[0].replace('~', ''), 'prompt aperto dal menu, con il termine precedente: ' + rows[0].replace('~', '')[:20])
    print('FALLITI:', etest.FAILS)
    sys.exit(1 if etest.FAILS else 0)


if __name__ == '__main__':
    main()
